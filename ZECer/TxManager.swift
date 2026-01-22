//
//  TxManager.swift
//  ZECer
//
//  Created by Aman Pandey on 1/22/26.
//


import Foundation
import CoreData
import Combine
import ZcashLightClientKit

class TxManager: ObservableObject {
    static let shared = TxManager()
    let context = PersistenceController.shared.container.viewContext
    
    @Published var pendingTxs: [OfflineTx] = []
    
    init() {
        fetchPending()
    }
    
    // 1. SAVE NEW INCOMING TX
    func saveIncoming(rawHex: String, amount: Double, memo: String) {
        let newTx = OfflineTx(context: context)
        newTx.id = UUID()
        newTx.rawHex = rawHex
        newTx.amount = amount
        newTx.memo = memo
        newTx.timestamp = Date()
        newTx.status = "Pending" // Waiting for internet
        
        PersistenceController.shared.save()
        fetchPending()
    }
    
    // 2. FETCH LIST
    func fetchPending() {
        let request: NSFetchRequest<OfflineTx> = OfflineTx.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \OfflineTx.timestamp, ascending: false)]
        // Only show items that haven't been confirmed
        request.predicate = NSPredicate(format: "status == %@", "Pending")
        
        do {
            pendingTxs = try context.fetch(request)
        } catch {
            print("Fetch failed: \(error)")
        }
    }
    
    // 3. BROADCAST TO NETWORK (The "Sync" Logic)
    func broadcastPending(using synchronizer: SDKSynchronizer?) async {
        guard let synchronizer = synchronizer else { return }
        
        for tx in pendingTxs {
            guard let hexData = tx.rawHex?.data(using: .utf8) else { continue } // Simplified for demo
            // In reality, rawHex should be converted back to Data bytes properly
            
            // NOTE: Zcash SDK currently creates transactions, but 'broadcasting' a raw hex 
            // usually requires a lightwalletd proxy or specific SDK method if you have the raw bytes.
            // For this Alpha, we will Simulate the broadcast success.
            
            do {
                // SIMULATION OF NETWORK CALL
                try await Task.sleep(nanoseconds: 1_000_000_000) 
                
                // If successful, update DB
                tx.status = "Confirmed"
                tx.timestamp = Date() // Update time
                print("Broadcasted TX: \(tx.id?.uuidString ?? "?")")
                
            } catch {
                print("Broadcast Failed")
            }
        }
        
        PersistenceController.shared.save()
        
        // Refresh UI
        DispatchQueue.main.async {
            self.fetchPending()
        }
    }
    
    // 4. SAVE OUTGOING TX
        func saveOutgoing(amount: Double, memo: String) {
            let newTx = OfflineTx(context: context)
            newTx.id = UUID()
            // For outgoing, we don't have a rawHex received from others,
            // but in a real app, you'd save the raw tx you just generated.
            newTx.rawHex = "OUTGOING_TX_PLACEHOLDER"
            newTx.amount = -amount // Store as NEGATIVE to indicate "Sent"
            newTx.memo = memo
            newTx.timestamp = Date()
            newTx.status = "Pending" // Waiting to be broadcast/synced
            
            PersistenceController.shared.save()
            fetchPending()
        }
}
