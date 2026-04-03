import Foundation
import Security

/// Simple Keychain helper for NoteFlow.
public struct KeychainHelper {
    public enum Error: Swift.Error {
        case duplicateItem
        case unexpectedStatus(OSStatus)
        case notFound
    }
    
    public static func save(_ data: Data, service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            throw Error.duplicateItem
        }
        
        if status != errSecSuccess {
            throw Error.unexpectedStatus(status)
        }
    }
    
    public static func read(service: String, account: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            throw Error.notFound
        }
        
        if status != errSecSuccess {
            throw Error.unexpectedStatus(status)
        }
        
        return result as! Data
    }
    
    public static func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw Error.unexpectedStatus(status)
        }
    }
}
