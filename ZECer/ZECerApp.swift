//
//  ZECerApp.swift
//  ZECer
//
//  Created by Aman Pandey on 1/21/26.
//

// ZECerApp.swift

import SwiftUI
import CoreData

@main
struct ZECerApp: App {
    @State private var isLoggedIn = false
    @State private var seedPhrase: String?
    @State private var isCheckingAuth = true
    
    let persistenceController = PersistenceController.shared
    
//  [Comment out when not in Use] temporary command to force-wipe the Keychain the moment the app launches.
    init() {
            print("☢️ MAINNET PREP: STARTING DATA WIPE ☢️")
            
            // 1. Wipe Keys (FaceID/Passcode items)
            KeychainManager.shared.delete()
            
            // 2. Wipe ALL Database Files
            let fileManager = FileManager.default
            if let docsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                 let files = [
                    "data.db",
                    "fs_cache",
                    "sapling-spend.params",
                    "sapling-output.params",
                    "general_storage",
                    "simulated_wallet.db" // Just in case
                 ]
                 
                 for f in files {
                     let fileUrl = docsUrl.appendingPathComponent(f)
                     if fileManager.fileExists(atPath: fileUrl.path) {
                         try? fileManager.removeItem(at: fileUrl)
                         print("🗑 Deleted: \(f)")
                     }
                 }
            }
            print("✅ WIPE COMPLETE. READY FOR MAINNET.")
        }
//    Nuclear block ends
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLoggedIn, let seed = seedPhrase {
                    // ✅ SUCCESS: Main App
                    ContentView()
                        .environment(\.seedPhraseContext, seed)
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    
                } else if !isCheckingAuth {
                    // 📝 LOGIN: Onboarding Screen
                    WalletOnboardingView(isLoggedIn: $isLoggedIn)
                    
                } else {
                    // ⏳ LOADING: Checking Keychain
                    Color.black.edgesIgnoringSafeArea(.all)
                    VStack(spacing: 20) {
                        ProgressView().tint(.yellow)
                        Text("Verifying Security...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .onAppear(perform: checkLoginStatus)
            .onChange(of: isLoggedIn) { newValue in
                if newValue {
                    print("✅ User logged in. Re-verifying...")
                    checkLoginStatus()
                }
            }
        }
    }
    
    func checkLoginStatus() {
        print("🔐 Checking Login Status...")
        Task {
            do {
                // Try to get key from Keychain
                if let savedSeed = try await KeychainManager.shared.retrieve() {
                    print("🔓 Key found! Logging in.")
                    
                    // Add a tiny delay to ensure UI is ready
                    try await Task.sleep(nanoseconds: 500_000_000)
                    
                    self.seedPhrase = savedSeed
                    self.isLoggedIn = true
                } else {
                    print("❌ No key found in Keychain. Showing Onboarding.")
                    self.isLoggedIn = false
                }
            } catch {
                print("⚠️ Auth Error: \(error)")
                self.isLoggedIn = false
            }
            
            // ALWAYS turn off the loading spinner
            print("🏁 Auth Check Complete.")
            self.isCheckingAuth = false
        }
    }
}

// Helper to pass the seed down safely
struct SeedPhraseKey: EnvironmentKey {
    static let defaultValue: String = ""
}

extension EnvironmentValues {
    var seedPhraseContext: String {
        get { self[SeedPhraseKey.self] }
        set { self[SeedPhraseKey.self] = newValue }
    }
}
