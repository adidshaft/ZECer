//
//  WalletOnboardingView.swift
//  ZECer
//
//  Created by Aman Pandey on 1/22/26.
//


import SwiftUI

struct WalletOnboardingView: View {
    @Binding var isLoggedIn: Bool
    @State private var seedInput: String = ""
    @State private var showImport = false
    @State private var errorMessage: String?
    @State private var isProcessing = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // Logo Section
                VStack(spacing: 15) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.yellow) // Zcash Gold
                        .shadow(color: .orange, radius: 10)
                    
                    Text("ZECer")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Offline Shielded Payments")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.top, 50)
                
                Spacer()
                
                if showImport {
                    // Import Flow
                    VStack(spacing: 20) {
                        Text("Enter your 24-word Secret Phrase")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        TextEditor(text: $seedInput)
                            .frame(height: 150)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray, lineWidth: 1))
                            .autocapitalization(.none)
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        Button(action: importWallet) {
                            HStack {
                                if isProcessing { ProgressView() }
                                Text("Import Wallet")
                            }
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.yellow)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                        }
                        
                        Button("Cancel") {
                            withAnimation { showImport = false }
                        }
                        .foregroundColor(.gray)
                    }
                    .transition(.move(edge: .bottom))
                    
                } else {
                    // Main Menu
                    VStack(spacing: 15) {
                        Button(action: { withAnimation { showImport = true } }) {
                            Text("I have a Secret Phrase")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        
                        Button(action: { /* Navigate to Create Flow (Phase 1.5) */ }) {
                            Text("Create New Wallet")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.yellow)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    func importWallet() {
        guard !seedInput.isEmpty else { return }
        isProcessing = true
        
        // Basic Validation (Simple word count check)
        let wordCount = seedInput.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ").count
        if wordCount < 12 { // Standard Zcash is 24, allowing 12 for testing flexibility
            errorMessage = "Invalid phrase. Expecting 24 words."
            isProcessing = false
            return
        }
        
        // Save to Keychain
        do {
            try KeychainManager.shared.save(seedPhrase: seedInput)
            // Trigger Success
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                isLoggedIn = true // This flips the switch in the main app
            }
        } catch {
            errorMessage = "Failed to save secure key: \(error.localizedDescription)"
            isProcessing = false
        }
    }
}