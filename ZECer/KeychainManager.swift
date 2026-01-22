//
//  KeychainManager.swift
//  ZECer
//
//  Created by Aman Pandey on 1/22/26.
//


import Foundation
import Security
import LocalAuthentication

class KeychainManager {
    static let shared = KeychainManager()
    private let service = "com.zecer.wallet.service"
    private let account = "user_seed_phrase"
    
    // MARK: - Save Securely
    func save(seedPhrase: String) throws {
        let data = Data(seedPhrase.utf8)
        
        // Define query to check if item exists
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        // Delete existing item if any (to update)
        SecItemDelete(query as CFDictionary)
        
        // Define attributes for new item
        // Note: We require device unlock to access this
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }
    
    // MARK: - Retrieve with FaceID
    func retrieve() async throws -> String? {
        // 1. Authenticate User First
        let context = LAContext()
        var error: NSError?
        
        // Check if biometrics are available
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Unlock your ZECer Wallet"
            
            // Request FaceID/TouchID
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            guard success else { throw KeychainError.authenticationFailed }
        }
        
        // 2. Fetch Data from Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess,
              let data = item as? Data,
              let seedPhrase = String(data: data, encoding: .utf8) else {
            throw KeychainError.readFailed(status: status)
        }
        
        return seedPhrase
    }
    
    // MARK: - Reset/Delete
    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: Error {
    case saveFailed(status: OSStatus)
    case readFailed(status: OSStatus)
    case authenticationFailed
}