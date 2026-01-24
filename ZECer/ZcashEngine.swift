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

class ZcashEngine: ObservableObject {
    @Published var balance: Double = 0.0
    @Published var isSynced: Bool = false
    @Published var syncStatus: String = "Stopped"
    @Published var transparentBalance: Zatoshi = .zero
    
    private var sessionSeed: [UInt8]?
    var synchronizer: SDKSynchronizer?
    var cancellables = Set<AnyCancellable>()
    
    let network = ZcashNetworkBuilder.network(for: .mainnet)
    
    // 🏆 OFFICIAL ECC NODE
    // Only works if "Private Relay" is OFF and VPN DNS is working.
    // Timeout set to 60s to handle VPN latency.
    let endpoint = LightWalletEndpoint(
        address: "mainnet.lightwalletd.com",
        port: 443,
        secure: true,
        singleCallTimeoutInMillis: 60000,     // 60s Timeout
        streamingCallTimeoutInMillis: 120000  // 2m Timeout
    )
    
    func startEngine(seedPhrase: String) {
        let fileManager = FileManager.default
        let docsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: "/tmp")
        
        let fsBlockDbRoot = docsUrl.appendingPathComponent("fs_cache")
        let dataDbURL = docsUrl.appendingPathComponent("data.db")
        let generalStorageURL = docsUrl.appendingPathComponent("general_storage")
        let torDirURL = docsUrl.appendingPathComponent("tor_config")
        let spendParamsURL = docsUrl.appendingPathComponent("sapling-spend.params")
        let outputParamsURL = docsUrl.appendingPathComponent("sapling-output.params")
        
        guard let seedBytes = try? Mnemonic.deterministicSeedBytes(from: seedPhrase) else { return }
        self.sessionSeed = seedBytes
        
        // SAFE BIRTHDAY
        let birthday = BlockHeight(2500000)
        
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
            isTorEnabled: false,
            isExchangeRateEnabled: false
        )
        
        Task {
            do {
                self.synchronizer = try SDKSynchronizer(initializer: initializer)
                _ = try await self.synchronizer?.prepare(with: seedBytes, walletBirthday: birthday, for: .existingWallet, name: "ZECer", keySource: nil)
                try await self.synchronizer?.start(retry: true)
                print("✅ ENGINE STARTED from Block \(birthday)")
                await self.monitorWallet()
            } catch {
                print("💥 Engine Start Error: \(error)")
            }
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
    
    func createProposal(amount: Double, toAddress: String) async throws -> Data {
        guard let sync = synchronizer, let seedBytes = self.sessionSeed else { throw NSError(domain: "Locked", code: 401) }
        let amountZat = Zatoshi(Int64(amount * 100_000_000))
        let recipient = try Recipient(toAddress, network: self.network.networkType)
        guard let account = try? await sync.listAccounts().first else { throw NSError(domain: "No Account", code: 1) }
        
        let proposal = try await sync.proposeTransfer(accountUUID: account.id, recipient: recipient, amount: amountZat, memo: try Memo(string: "ZECer"))
        let tool = DerivationTool(networkType: network.networkType)
        guard let usk = try? tool.deriveUnifiedSpendingKey(seed: seedBytes, accountIndex: Zip32AccountIndex(0)) else { throw NSError(domain: "Key Error", code: 2) }
        
        let stream = try await sync.createProposedTransactions(proposal: proposal, spendingKey: usk)
        var transactionData = "MOCK_FAIL_SAFE".data(using: .utf8)!
        
        for try await txResult in stream {
            if case .success(let txId) = txResult {
                print("TX Created: \(txId)")
                transactionData = "TX_CREATED".data(using: .utf8)!
            }
            break
        }
        return transactionData
    }
    
    func testConnection() {
        guard let url = URL(string: "https://mainnet.lightwalletd.com/") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Server Reachable: \(httpResponse.statusCode)")
            } else {
                print("❌ Server Unreachable")
            }
        }.resume()
    }
}
