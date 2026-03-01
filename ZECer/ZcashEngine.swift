//
//  ZcashEngine.swift
//  ZECer
//
//  Created by Aman Pandey on 1/21/26.
//  FINAL VERIFIED CONFIGURATION
//

import Foundation
import SwiftUI
import Combine
import ZcashLightClientKit
import MnemonicSwift
import SQLite3

// MARK: - Data Hex Helpers (module-wide)
extension Data {
    var hexString: String { map { String(format: "%02x", $0) }.joined() }

    init?(hexEncoded s: String) {
        guard s.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(s.count / 2)
        var idx = s.startIndex
        while idx < s.endIndex {
            let nextIdx = s.index(idx, offsetBy: 2)
            guard let byte = UInt8(s[idx..<nextIdx], radix: 16) else { return nil }
            bytes.append(byte)
            idx = nextIdx
        }
        self.init(bytes)
    }
}

class ZcashEngine: ObservableObject {
    @Published var balance: Double = 0.0
    @Published var isSynced: Bool = false
    @Published var syncStatus: String = "Stopped"
    @Published var transparentBalance: Zatoshi = .zero

    @Published var currentEndpointDescription: String = ""
    @Published var lastError: String = ""

    private var sessionSeed: [UInt8]?
    var synchronizer: SDKSynchronizer?
    var cancellables = Set<AnyCancellable>()

    let network = ZcashNetworkBuilder.network(for: .mainnet)
    // Tor disabled — 5.9.61.233 cert mismatch (dhmosvolos.gr) kills every attempt
    private let useTor: Bool = false

    // Candidate endpoints tried in waterfall order (first success wins)
    private let endpointCandidates: [(host: String, port: Int, secure: Bool)] = [
        ("mainnet.lightwalletd.com", 443, true),  // ECC/ZF official
        ("lwd.nubis.cash",           443, true),  // Nighthawk
        ("mainnet.zec.rocks",        443, true)   // ZEC.rocks
    ]

    // Build a LightWalletEndpoint with extended timeouts
    private func makeEndpoint(host: String, port: Int, secure: Bool) -> LightWalletEndpoint {
        LightWalletEndpoint(
            address: host,
            port: port,
            secure: secure,
            singleCallTimeoutInMillis: 120_000,
            streamingCallTimeoutInMillis: 120_000
        )
    }

    private func prepareDirectoriesAndParams(fsBlockDbRoot: URL, generalStorageURL: URL, torDirURL: URL, spendParamsURL: URL, outputParamsURL: URL) {
        let fm = FileManager.default
        // Ensure directories exist
        [fsBlockDbRoot, generalStorageURL, torDirURL].forEach { url in
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        // Copy sapling params from bundle if present and missing
        let bundle = Bundle.main
        if !fm.fileExists(atPath: spendParamsURL.path), let src = bundle.url(forResource: "sapling-spend", withExtension: "params") {
            try? fm.copyItem(at: src, to: spendParamsURL)
        }
        if !fm.fileExists(atPath: outputParamsURL.path), let src = bundle.url(forResource: "sapling-output", withExtension: "params") {
            try? fm.copyItem(at: src, to: outputParamsURL)
        }
    }

    func startEngine(seedPhrase: String) {
        let fileManager = FileManager.default
        let docsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: "/tmp")

        let fsBlockDbRoot = docsUrl.appendingPathComponent("fs_cache")
        let dataDbURL = docsUrl.appendingPathComponent("data.db")
        let generalStorageURL = docsUrl.appendingPathComponent("general_storage")
        let torDirURL = docsUrl.appendingPathComponent("tor_config")
        let spendParamsURL = docsUrl.appendingPathComponent("sapling-spend.params")
        let outputParamsURL = docsUrl.appendingPathComponent("sapling-output.params")

        prepareDirectoriesAndParams(fsBlockDbRoot: fsBlockDbRoot, generalStorageURL: generalStorageURL, torDirURL: torDirURL, spendParamsURL: spendParamsURL, outputParamsURL: outputParamsURL)

        guard let seedBytes = try? Mnemonic.deterministicSeedBytes(from: seedPhrase) else { return }
        self.sessionSeed = seedBytes

        // SAFE BIRTHDAY
        let birthday = BlockHeight(2_750_000)
        if useTor { print("🧅 Tor mode enabled (SDK)") }

        Task {
            for candidate in endpointCandidates {
                let endpoint = makeEndpoint(host: candidate.host, port: candidate.port, secure: candidate.secure)
                self.currentEndpointDescription = "\(candidate.host):\(candidate.port)" + (useTor ? " [Tor]" : "")
                do {
                    let initializer = Initializer(
                        cacheDbURL: nil,
                        fsBlockDbRoot: fsBlockDbRoot,
                        generalStorageURL: generalStorageURL,
                        dataDbURL: dataDbURL,
                        torDirURL: torDirURL,
                        endpoint: endpoint,
                        network: network,
                        spendParamsURL: spendParamsURL,
                        outputParamsURL: outputParamsURL,
                        saplingParamsSourceURL: SaplingParamsSourceURL.default,
                        alias: .default,
                        isTorEnabled: useTor,
                        isExchangeRateEnabled: false
                    )
                    self.synchronizer = try SDKSynchronizer(initializer: initializer)
                    _ = try await self.synchronizer?.prepare(with: seedBytes, walletBirthday: birthday, for: .existingWallet, name: "ZECer", keySource: nil)

                    try await self.synchronizer?.start(retry: true)
                    print("✅ ENGINE STARTED via \(self.currentEndpointDescription) from Block \(birthday)")
                    await self.monitorWallet()
                    return
                } catch {
                    let err = String(describing: error)
                    self.lastError = err
                    print("💥 Engine Start Error on \(self.currentEndpointDescription): \(err)")
                    // Try next endpoint after a short delay
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
            print("❌ All endpoints failed. Last error: \(self.lastError)")
        }
    }

    @MainActor
    func monitorWallet() async {
        guard let sync = synchronizer else { return }
        sync.stateStream
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] state in
                self?.syncStatus = "\(state.syncStatus)"
                self?.isSynced = (state.syncStatus == .upToDate)
                if state.syncStatus == .upToDate { self?.fetchBalance() }
                print("State: \(String(describing: state.syncStatus)) - endpoint: \(self?.currentEndpointDescription ?? "")")
            })
            .store(in: &cancellables)

        Timer.publish(every: 15, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.checkForTransparentBalance() }
            .store(in: &cancellables)
    }

    func fetchBalance() {
        Task {
            guard let sync = synchronizer else { return }
            guard let account = try? await sync.listAccounts().first else { return }

            if let uAddress = try? await sync.getUnifiedAddress(accountUUID: account.id) {
                print("📍 My Address: \(uAddress.stringEncoded)")
            }

            if let balances = try? await sync.getAccountsBalances(),
               let myBalance = balances[account.id] {
                DispatchQueue.main.async {
                    self.balance = Double(myBalance.saplingBalance.total().amount) / 100_000_000.0
                }
            }
        }
    }

    func checkForTransparentBalance() {
        Task {
            guard let sync = synchronizer, let account = try? await sync.listAccounts().first else { return }
            if let balances = try? await sync.getAccountsBalances(), let myBalance = balances[account.id] {
                DispatchQueue.main.async {
                    self.transparentBalance = myBalance.unshielded
                    if myBalance.unshielded.amount > 0 { print("🔍 Unshielded: \(myBalance.unshielded.amount)") }
                }
            }
        }
    }

    func shieldFunds() async {
        guard let sync = synchronizer, let seed = self.sessionSeed else { return }
        do {
            let derivationTool = DerivationTool(networkType: network.networkType)
            let usk = try derivationTool.deriveUnifiedSpendingKey(seed: seed, accountIndex: Zip32AccountIndex(0))
            guard let account = try? await sync.listAccounts().first else { return }
            let uAddr = try await sync.getUnifiedAddress(accountUUID: account.id)
            let tAddr = try uAddr.transparentReceiver()

            guard let proposal = try await sync.proposeShielding(
                accountUUID: account.id,
                shieldingThreshold: Zatoshi(10000),
                memo: try Memo(string: "Shielding"),
                transparentReceiver: tAddr
            ) else { return }

            let stream = try await sync.createProposedTransactions(proposal: proposal, spendingKey: usk)
            for try await txResult in stream {
                if case .success(let txId) = txResult { print("✅ Shielding TX: \(txId)") }
            }
        } catch { print("💥 Shielding Failed: \(error)") }
    }

    // MARK: - Offline Transaction Creation

    func createProposal(amount: Double, toAddress: String) async throws -> Data {
        guard let sync = synchronizer, let seedBytes = self.sessionSeed else {
            throw NSError(domain: "Locked", code: 401)
        }
        let amountZat = Zatoshi(Int64(amount * 100_000_000))
        let recipient = try Recipient(toAddress, network: self.network.networkType)
        guard let account = try? await sync.listAccounts().first else {
            throw NSError(domain: "No Account", code: 1)
        }

        // a. Propose the transfer (reads local DB only — offline safe)
        let proposal = try await sync.proposeTransfer(
            accountUUID: account.id,
            recipient: recipient,
            amount: amountZat,
            memo: try Memo(string: "ZECer Offline")
        )

        // b. Derive software spending key (NOT SecureEnclave)
        let tool = DerivationTool(networkType: network.networkType)
        let usk = try tool.deriveUnifiedSpendingKey(seed: seedBytes, accountIndex: Zip32AccountIndex(0))

        // c. Create ZKP via Rust FFI; captures txId regardless of gRPC outcome
        let stream = try await sync.createProposedTransactions(proposal: proposal, spendingKey: usk)
        var capturedTxId: Data? = nil

        do {
            for try await txResult in stream {
                switch txResult {
                case .success(let txId):
                    capturedTxId = txId
                case .grpcFailure(let txId, _):
                    capturedTxId = txId
                case .submitFailure(let txId, _, _):
                    capturedTxId = txId
                case .notAttempted(let txId):
                    capturedTxId = txId
                }
            }
        } catch {
            // Offline: gRPC submission fails but the tx is already stored in data.db
            print("createProposedTransactions error (expected offline): \(error)")
        }

        guard let txId = capturedTxId else {
            throw NSError(domain: "No TxId captured", code: 3)
        }

        // d. Extract raw transaction bytes from data.db via SQLite
        let docsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: "/tmp")
        let dataDbURL = docsUrl.appendingPathComponent("data.db")

        guard let rawTx = extractRawTransaction(txId: txId, from: dataDbURL) else {
            throw NSError(domain: "Raw TX Not Found in data.db", code: 4)
        }

        // e. Return UTF-8 payload: "amount|||ZECer Offline|||txHex"
        let txHex = rawTx.hexString
        let payload = "\(amount)|||ZECer Offline|||\(txHex)"
        return payload.data(using: .utf8)!
    }

    // MARK: - SQLite Raw Transaction Extractor

    private func extractRawTransaction(txId: Data, from dbURL: URL) -> Data? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            print("SQLite open failed for \(dbURL.lastPathComponent)")
            return nil
        }
        defer { sqlite3_close(db) }

        let sql = "SELECT raw FROM transactions WHERE txid = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("SQLite prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        var result: Data? = nil
        // Bind and step inside withUnsafeBytes to keep pointer valid (SQLITE_STATIC safe pattern)
        txId.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            sqlite3_bind_blob(stmt, 1, ptr.baseAddress, Int32(txId.count), nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let blob = sqlite3_column_blob(stmt, 0) {
                    let size = Int(sqlite3_column_bytes(stmt, 0))
                    result = Data(bytes: blob, count: size)
                }
            }
        }

        if result == nil {
            print("Raw transaction not found for txId: \(txId.hexString)")
        }
        return result
    }

    // MARK: - Broadcast Helper

    func broadcastRawHex(_ hex: String) async throws {
        try await NetworkBroadcaster.shared.broadcast(rawTxHex: hex)
    }

    func testConnection() {
        let host = currentEndpointDescription.isEmpty ? "mainnet.zec.rocks:443" : currentEndpointDescription
        let urlString = host.contains(":") ? "https://\(host)/" : "https://\(host):443/"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Server Reachable: \(httpResponse.statusCode) for \(urlString)")
            } else {
                print("❌ Server Unreachable for \(urlString)")
            }
        }.resume()
    }
}
