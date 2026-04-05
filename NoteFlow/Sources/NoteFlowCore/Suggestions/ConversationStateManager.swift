import Foundation
import Combine

public struct ConversationState: Codable {
    public var topic: String
    public var summary: String
    public var openQuestions: [String]
    public var tensions: [String]
    public var recentDecisions: [String]
    public var goals: [String]
    public var lastUpdatedAt: Date
    public var confidence: String // "high", "medium", "low"
    
    public static var initial: ConversationState {
        ConversationState(
            topic: "Initial",
            summary: "Conversation just started.",
            openQuestions: [],
            tensions: [],
            recentDecisions: [],
            goals: [],
            lastUpdatedAt: Date(),
            confidence: "medium"
        )
    }
}

public class ConversationStateManager: ObservableObject {
    @Published public var state: ConversationState = .initial
    private var themUtteranceCount = 0
    
    public init() {}
    
    public func processUtterance(speaker: String, text: String, recentTranscript: [TranscriptSegment]) async {
        guard speaker != "you" else { return }
        
        themUtteranceCount += 1
        
        if themUtteranceCount % 4 == 0 {
            await updateState(latestUtterance: text, recentTranscript: recentTranscript)
        }
    }
    
    private func updateState(latestUtterance: String, recentTranscript: [TranscriptSegment]) async {
        guard let apiKey = try? String(data: KeychainHelper.read(service: "NoteFlow", account: "GEMINI_API_KEY"), encoding: .utf8) else {
            print("Gemini API key not found for state update.")
            return
        }
        
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)")!
        
        let last8 = recentTranscript.suffix(8).map { "\($0.speaker): \($0.text)" }.joined(separator: "\n")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let currentStateJSON = (try? encoder.encode(state)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        
        let promptText = """
        You are tracking the state of a live conversation.

        Previous state:
        \(currentStateJSON)

        Recent transcript (last 8 lines):
        \(last8)

        Latest utterance from them:
        "\(latestUtterance)"

        Update the conversation state JSON. Return ONLY valid JSON, no markdown:
        {
          "topic": "...",
          "summary": "...",
          "openQuestions": [...],
          "tensions": [...],
          "recentDecisions": [...],
          "goals": [...],
          "confidence": "high/medium/low"
        }
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                ["role": "user", "parts": [["text": promptText]]]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "maxOutputTokens": 1000
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 15.0
        
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
                    responseText = String(responseText.dropFirst(7).dropLast(3))
                } else if responseText.hasPrefix("```") {
                    responseText = String(responseText.dropFirst(3).dropLast(3))
                }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                if let jsonData = responseText.data(using: .utf8),
                   var newState = try? decoder.decode(ConversationState.self, from: jsonData) {
                    newState.lastUpdatedAt = Date()
                    await MainActor.run {
                        self.state = newState
                    }
                }
            }
        } catch {
            print("Failed to update conversation state: \(error)")
        }
    }
}
