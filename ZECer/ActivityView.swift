//
//  ActivityView.swift
//  ZECer
//
//  Created by Aman Pandey on 1/22/26.
//


import SwiftUI
import CoreData

struct ActivityView: View {
    @Environment(\.presentationMode) var presentationMode
    
    // Connect directly to CoreData
    @FetchRequest(
        entity: OfflineTx.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \OfflineTx.timestamp, ascending: false)],
        animation: .default
    ) var transactions: FetchedResults<OfflineTx>
    
    @StateObject var txManager = TxManager.shared
    @ObservedObject var zcashEngine: ZcashEngine
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.darkSlate.edgesIgnoringSafeArea(.all)
                
                if transactions.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.1))
                        Text("No Transactions Yet")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.3))
                    }
                } else {
                    // The Ledger List
                    List {
                        ForEach(transactions) { tx in
                            TransactionRow(tx: tx)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteTx)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Manual Sync Button
                    if hasPending {
                        Button(action: {
                            Task { await txManager.broadcastPending(using: zcashEngine.synchronizer) }
                        }) {
                            HStack(spacing: 4) {
                                Text("Sync Now")
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            .font(.caption.bold())
                            .foregroundColor(.neonGreen)
                            .padding(6)
                            .background(Color.neonGreen.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        // Force Dark Mode for this view
        .preferredColorScheme(.dark)
    }
    
    var hasPending: Bool {
        transactions.contains { $0.status == "Pending" }
    }
    
    func deleteTx(at offsets: IndexSet) {
        for index in offsets {
            let tx = transactions[index]
            PersistenceController.shared.container.viewContext.delete(tx)
        }
        PersistenceController.shared.save()
    }
}

// MARK: - Subview: Transaction Row
struct TransactionRow: View {
    @ObservedObject var tx: OfflineTx
    
    var body: some View {
        HStack(spacing: 15) {
            // Icon Badge
            ZStack {
                Circle()
                    .fill(themeColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(themeColor)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(tx.memo ?? "Unknown")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(tx.timestamp ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                // Show absolute value (no minus sign), color indicates direction
                Text("\(abs(tx.amount), specifier: "%.3f") ZEC")
                    .font(.system(.callout, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(themeColor)
                
                Text(tx.status?.uppercased() ?? "UNKNOWN")
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tx.status == "Pending" ? Color.orange.opacity(0.2) : themeColor.opacity(0.2))
                    .foregroundColor(tx.status == "Pending" ? .orange : themeColor)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // HELPERS
    var isSent: Bool { tx.amount < 0 }
    
    var themeColor: Color {
        // Red for Sent, Green for Received
        isSent ? Color(red: 1.0, green: 0.4, blue: 0.4) : Color.neonGreen
    }
    
    var iconName: String {
        // Up arrow for Sent, Down arrow for Received
        isSent ? "arrow.up.right" : "arrow.down.left"
    }
}
