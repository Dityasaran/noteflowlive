import Foundation
import CryptoKit

public struct SHA256Helper {
    /// Computes the SHA256 hash of the contents of a file at the given URL.
    public static func hash(fileAt url: URL) -> String? {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { handle.closeFile() }
            
            var hasher = SHA256()
            while let chunk = try handle.read(upToCount: 1024 * 64), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
            
            let digest = hasher.finalize()
            return digest.map { String(format: "%02hhx", $0) }.joined()
        } catch {
            print("Error hashing file \(url.path): \(error)")
            return nil
        }
    }
    
    /// Computes the SHA256 hash of a string.
    public static func hash(string: String) -> String {
        let data = Data(string.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
