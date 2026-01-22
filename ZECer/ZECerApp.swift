//
//  ZECerApp.swift
//  ZECer
//
//  Created by Aman Pandey on 1/21/26.
//

// ZECerApp.swift

import SwiftUI
import CoreData  // <--- ADDED THIS IMPORT

@main
struct ZECerApp: App {
    @State private var isLoggedIn = false
    @State private var seedPhrase: String?
    @State private var isCheckingAuth = true
    
    // 1. Initialize Persistence Controller
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLoggedIn, let seed = seedPhrase {
                    // Show the Main App
                    ContentView()
                        .environment(\.seedPhraseContext, seed)
                        // 2. Inject Database Context (Now works because CoreData is imported)
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    
                } else if !isCheckingAuth {
                    // Show Onboarding
                    WalletOnboardingView(isLoggedIn: $isLoggedIn)
                } else {
                    // Loading / Biometric Check Screen
                    Color.black.edgesIgnoringSafeArea(.all)
                    ProgressView().tint(.yellow)
                }
            }
            .onAppear(perform: checkLoginStatus)
            .onChange(of: isLoggedIn) { newValue in
                if newValue { checkLoginStatus() }
            }
        }
    }
    
    func checkLoginStatus() {
        Task {
            do {
                if let savedSeed = try await KeychainManager.shared.retrieve() {
                    self.seedPhrase = savedSeed
                    self.isLoggedIn = true
                } else {
                    self.isLoggedIn = false
                }
            } catch {
                print("Auth Error: \(error)")
                self.isLoggedIn = false
            }
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
