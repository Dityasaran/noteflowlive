import Foundation

public class RerankManager {
    public init() {}
    
    public func rerank(query: String, chunks: [ChunkResult], topK: Int = 3) async -> [ChunkResult] {
        guard !chunks.isEmpty else { return [] }
        
        // Take top 5 for reranking
        let top5 = Array(chunks.prefix(5))
        
        guard let apiKey = try? String(data: KeychainHelper.read(service: "NoteFlow", account: "GEMINI_API_KEY"), encoding: .utf8) else {
            print("Gemini API key not found for reranking.")
            return Array(top5.prefix(topK))
        }
        
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)")!
        
        let chunksNumberedList = top5.enumerated().map { (index, chunk) in
            "\(index). \(chunk.body)"
        }.joined(separator: "\n\n")
        
        let promptText = """
        You are a relevance ranking assistant.

        The user is in a live meeting. The other person just said:
        "\(query)"

        Here are \(top5.count) knowledge base chunks. Rank them by relevance 
        to what was just said. Return ONLY a JSON array of indices 
        (0-based) from most to least relevant. Example: [2, 0, 4, 1, 3]

        Chunks:
        \(chunksNumberedList)
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                ["role": "user", "parts": [["text": promptText]]]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 300
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 5.0 // 5-second timeout as requested
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               var responseText = parts.first?["text"] as? String {
                
                // Cleanup JSON if Gemini wrapped it in markdown
                responseText = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
                if responseText.hasPrefix("```json") {
                    responseText = responseText.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                } else if responseText.hasPrefix("```") {
                    responseText = responseText.replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                if let jsonData = responseText.data(using: .utf8),
                   let indices = try? JSONDecoder().decode([Int].self, from: jsonData) {
                    
                    var reranked: [ChunkResult] = []
                    for index in indices {
                        if index >= 0 && index < top5.count {
                            reranked.append(top5[index])
                        }
                    }
                    
                    // Fallback to topK original order if reranking failed to produce valid indices
                    if reranked.isEmpty {
                        return Array(top5.prefix(topK))
                    }
                    
                    return Array(reranked.prefix(topK))
                }
            }
        } catch {
            print("Failed to rerank chunks or timeout: \(error)")
        }
        
        // Fallback to original order
        return Array(top5.prefix(topK))
    }
}
