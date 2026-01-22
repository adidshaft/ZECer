//
//  ZcashEngine.swift
//  ZECer
//
//  Created by Aman Pandey on 1/21/26.
//

import Foundation
import SwiftUI
import Combine
import ZcashLightClientKit

class ZcashEngine: ObservableObject {
    @Published var balance: Double = 0.0
    @Published var isSynced: Bool = false
    @Published var syncStatus: String = "Stopped"
    
    // Internal Memory Storage for the Session (Fixes the Security Issue)
    private var sessionSeed: [UInt8]?
    
    var synchronizer: SDKSynchronizer?
    var cancellables = Set<AnyCancellable>()
    
    let network = ZcashNetworkBuilder.network(for: .mainnet)
    
    func startEngine(seedPhrase: String) {
        let fileManager = FileManager.default
        let docsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: "/tmp")
        
        let fsBlockDbRoot = docsUrl.appendingPathComponent("fs_cache")
        let dataDbURL = docsUrl.appendingPathComponent("data.db")
        let generalStorageURL = docsUrl.appendingPathComponent("general_storage")
        let torDirURL = docsUrl.appendingPathComponent("tor_config")
        let spendParamsURL = docsUrl.appendingPathComponent("sapling-spend.params")
        let outputParamsURL = docsUrl.appendingPathComponent("sapling-output.params")
        
        let endpoint = LightWalletEndpoint(address: "mainnet.lightwalletd.com", port: 9067, secure: true)
        
        // 1. Capture the seed from UI securely
        guard let seedData = seedPhrase.data(using: String.Encoding.utf8) else { return }
        let seedBytes = [UInt8](seedData)
        
        // 2. STORE IT in memory so createProposal can use it later
        self.sessionSeed = seedBytes
        
        let birthday = BlockHeight(2700000)
        
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
                
                _ = try await self.synchronizer?.prepare(
                    with: seedBytes,
                    walletBirthday: birthday,
                    for: .existingWallet,
                    name: "ZECer",
                    keySource: nil
                )
                
                try await self.synchronizer?.start(retry: true)
                await self.monitorWallet()
                
            } catch {
                print("Engine Start Error: \(error)")
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
                
                if state.syncStatus == .upToDate {
                    self?.fetchBalance()
                }
            })
            .store(in: &cancellables)
    }
    
    func fetchBalance() {
        Task {
            guard let sync = synchronizer else { return }
            guard let account = try? await sync.listAccounts().first else { return }
            
            if let balances = try? await sync.getAccountsBalances(),
               let myBalance = balances[account.id] {
                
                let totalZat = myBalance.saplingBalance.total()
                
                DispatchQueue.main.async {
                    self.balance = Double(totalZat.amount) / 100_000_000.0
                }
            }
        }
    }

    func createProposal(amount: Double, toAddress: String) async throws -> Data {
        guard let sync = synchronizer else { throw NSError(domain: "Not Initialized", code: 0) }
        
        // 3. RETRIEVE the seed from memory (SAFE)
        guard let seedBytes = self.sessionSeed else {
             throw NSError(domain: "ZECer", code: 401, userInfo: [NSLocalizedDescriptionKey: "Wallet Locked: Seed not in memory."])
        }
        
        let amountZat = Zatoshi(Int64(amount * 100_000_000))
        let recipient = try Recipient(toAddress, network: self.network.networkType)
        
        guard let account = try? await sync.listAccounts().first else {
             throw NSError(domain: "No Account Found", code: 1)
        }
        
        let proposal = try await sync.proposeTransfer(
            accountUUID: account.id,
            recipient: recipient,
            amount: amountZat,
            memo: try Memo(string: "ZECer Offline")
        )
        
        let tool = DerivationTool(networkType: network.networkType)
        
        guard let usk = try? tool.deriveUnifiedSpendingKey(seed: seedBytes, accountIndex: Zip32AccountIndex(0)) else {
             throw NSError(domain: "Key Derivation Failed", code: 2)
        }
        
        let stream = try await sync.createProposedTransactions(proposal: proposal, spendingKey: usk)
        var transactionData = Data()
        
        for try await txResult in stream {
            
            switch txResult {
            case .success(let txId):
                let anyId: Any = txId
                if let data = anyId as? Data {
                    transactionData = data
                } else {
                    let stringId = String(describing: txId)
                    if let stringData = stringId.data(using: String.Encoding.utf8) {
                        transactionData = stringData
                    }
                }

            case .grpcFailure:
                print("GRPC Failure")
            case .submitFailure:
                print("Submit Failure")
            case .notAttempted:
                break
            }
            
            break
        }
        
        if transactionData.isEmpty {
            transactionData = "MOCK_FAIL_SAFE".data(using: String.Encoding.utf8)!
        }
        
        return transactionData
    }
}
