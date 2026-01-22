//
//  HardwareSigner.swift
//  ZECer
//
//  Created by Aman Pandey on 1/21/26.
//

import Foundation
import LocalAuthentication
import CryptoKit
import Security

class HardwareSigner {
    static let shared = HardwareSigner()
    private let keyLabel = "com.zecer.key.handle"
    
    // 1. Get or Create Key
    func getSecureKey() throws -> SecureEnclave.P256.Signing.PrivateKey {
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyLabel,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess, let data = item as? Data {
            return try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: data)
        }
        
        // Create new
        let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            nil
        )!
        
        let newKey = try SecureEnclave.P256.Signing.PrivateKey(accessControl: accessControl)
        
        // Save
        let saveQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyLabel,
            kSecValueData as String: newKey.dataRepresentation
        ]
        
        SecItemDelete(saveQuery as CFDictionary)
        SecItemAdd(saveQuery as CFDictionary, nil)
        
        return newKey
    }
    
    // 2. Sign Data
    func signPayload(data: Data) async throws -> Data {
        let key = try getSecureKey()
        
        // FIX: Use .derRepresentation to get the Raw Data signature
        let signature = try key.signature(for: data).derRepresentation
        
        return signature
    }
}
