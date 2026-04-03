import Foundation

public struct KBChunk {
    public let id: String
    public let filePath: String
    public let breadcrumb: String
    public let body: String
    public var embedding: [Float]?
}

public class Chunker {
    private static let minWordCount = 50
    private static let maxWordCount = 400
    
    public static func chunk(fileURL: URL) -> [KBChunk] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        let fileName = fileURL.lastPathComponent
        let ext = fileURL.pathExtension.lowercased()
        
        if ext == "md" {
            return chunkMarkdown(content: content, fileName: fileName, filePath: fileURL.path)
        } else {
            return chunkText(content: content, fileName: fileName, filePath: fileURL.path)
        }
    }
    
    private static func chunkMarkdown(content: String, fileName: String, filePath: String) -> [KBChunk] {
        var chunks: [KBChunk] = []
        let lines = content.components(separatedBy: .newlines)
        
        var currentHeading = "General"
        var currentBody = ""
        
        for line in lines {
            if line.hasPrefix("#") {
                // If we have an existing chunk, save it
                if let chunk = createChunk(fileName: fileName, heading: currentHeading, body: currentBody, filePath: filePath) {
                    chunks.append(chunk)
                }
                
                // Start a new heading
                currentHeading = line.trimmingCharacters(in: .init(charactersIn: "# ")).trimmingCharacters(in: .whitespaces)
                currentBody = ""
            } else {
                currentBody += line + "\n"
            }
        }
        
        // Save the final chunk
        if let chunk = createChunk(fileName: fileName, heading: currentHeading, body: currentBody, filePath: filePath) {
            chunks.append(chunk)
        }
        
        return chunks
    }
    
    private static func chunkText(content: String, fileName: String, filePath: String) -> [KBChunk] {
        var chunks: [KBChunk] = []
        let paragraphs = content.components(separatedBy: "\n\n")
        
        for (i, p) in paragraphs.enumerated() {
            let body = p.trimmingCharacters(in: .whitespacesAndNewlines)
            if let chunk = createChunk(fileName: fileName, heading: "Part \(i+1)", body: body, filePath: filePath) {
                chunks.append(chunk)
            }
        }
        
        return chunks
    }
    
    private static func createChunk(fileName: String, heading: String, body: String, filePath: String) -> KBChunk? {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBody.isEmpty { return nil }
        
        let words = trimmedBody.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if words.count < minWordCount { return nil }
        
        // If it's too long, split further (basic)
        if words.count > maxWordCount {
            // we could split it more gracefully but for now just take the first 400
            let truncatedBody = words.prefix(maxWordCount).joined(separator: " ")
            let id = SHA256Helper.hash(string: "\(filePath):\(heading):\(truncatedBody)")
            return KBChunk(id: id, filePath: filePath, breadcrumb: "\(fileName) > \(heading)", body: truncatedBody)
        }
        
        let id = SHA256Helper.hash(string: "\(filePath):\(heading):\(trimmedBody)")
        return KBChunk(id: id, filePath: filePath, breadcrumb: "\(fileName) > \(heading)", body: trimmedBody)
    }
}
