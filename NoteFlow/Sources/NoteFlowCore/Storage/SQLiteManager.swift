import Foundation
import SQLite3

public class SQLiteManager {
    private var db: OpaquePointer?
    
    public init?(path: String) {
        // Ensure directory exists
        let url = URL(fileURLWithPath: path)
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        
        if sqlite3_open(path, &db) != SQLITE_OK {
            print("Error opening database")
            return nil
        }
        
        createTable()
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS chunks (
          id TEXT PRIMARY KEY,
          file_path TEXT,
          heading_breadcrumb TEXT,
          body TEXT,
          embedding BLOB,
          file_hash TEXT,
          updated_at INTEGER
        );
        """
        var error: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &error) != SQLITE_OK {
            let msg = String(cString: error!)
            print("SQLite error: \(msg)")
            sqlite3_free(error)
        }
    }
    
    public func insertChunk(id: String, filePath: String, breadcrumb: String, body: String, embedding: [Float], fileHash: String) {
        let sql = "INSERT OR REPLACE INTO chunks (id, file_path, heading_breadcrumb, body, embedding, file_hash, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (filePath as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (breadcrumb as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (body as NSString).utf8String, -1, nil)
            
            // Bind embedding as BLOB
            let byteCount = embedding.count * MemoryLayout<Float>.size
            sqlite3_bind_blob(stmt, 5, embedding, Int32(byteCount), nil)
            
            sqlite3_bind_text(stmt, 6, (fileHash as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 7, Int64(Date().timeIntervalSince1970))
            
            if sqlite3_step(stmt) != SQLITE_DONE {
                print("Error inserting chunk")
            }
        }
        sqlite3_finalize(stmt)
    }
    
    public func getFileHashes() -> [String: String] {
        var hashes: [String: String] = [:]
        let sql = "SELECT DISTINCT file_path, file_hash FROM chunks;"
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let path = String(cString: sqlite3_column_text(stmt, 0))
                let hash = String(cString: sqlite3_column_text(stmt, 1))
                hashes[path] = hash
            }
        }
        sqlite3_finalize(stmt)
        return hashes
    }
    
    public func deleteChunksForFile(path: String) {
        let sql = "DELETE FROM chunks WHERE file_path = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (path as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }
    
    public struct ChunkData {
        public let id: String
        public let filePath: String
        public let breadcrumb: String
        public let body: String
        public let embedding: [Float]
    }
    
    public func getAllChunks() -> [ChunkData] {
        var results: [ChunkData] = []
        let sql = "SELECT id, file_path, heading_breadcrumb, body, embedding FROM chunks;"
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let path = String(cString: sqlite3_column_text(stmt, 1))
                let breadcrumb = String(cString: sqlite3_column_text(stmt, 2))
                let body = String(cString: sqlite3_column_text(stmt, 3))
                
                let blob = sqlite3_column_blob(stmt, 4)
                let blobSize = sqlite3_column_bytes(stmt, 4)
                let count = Int(blobSize) / MemoryLayout<Float>.size
                
                if let ptr = blob?.assumingMemoryBound(to: Float.self) {
                    let embedding = Array(UnsafeBufferPointer(start: ptr, count: count))
                    results.append(ChunkData(id: id, filePath: path, breadcrumb: breadcrumb, body: body, embedding: embedding))
                }
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
}
