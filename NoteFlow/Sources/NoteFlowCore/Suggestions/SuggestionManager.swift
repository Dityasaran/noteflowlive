import Foundation
import Combine

public class SuggestionManager: ObservableObject {
    @Published public var suggestions: [SuggestionCard] = []
    @Published public var isThinking = false
    
    private var lastSuggestionTime: Date = .distantPast
    private var lastSourceBreadcrumb: String? = nil
    private let suggestionCooldown: TimeInterval = 90
    private let maxSuggestions = 3
    private let autoDismissSec: TimeInterval = 300 // 5 minutes
    
    private var cleanupTask: Task<Void, Never>?
    
    public init() {}
    
    @MainActor
    public func startCleanupTimer() {
        guard cleanupTask == nil else { return }
        cleanupTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                self.dismissOldSuggestions()
            }
        }
    }
    
    deinit {
        cleanupTask?.cancel()
    }
    
    @MainActor
    public func processNewSegment(segment: TranscriptSegment, contextLines: [TranscriptSegment], kbResults: [ChunkResult]) async {
        // --- Surfacing Gate ---
        
        // 1. "Them" utterance 8+ words
        guard segment.speaker != "you" else { return }
        let wordCount = segment.text.components(separatedBy: CharacterSet.whitespaces).count
        guard wordCount >= 8 else { return }
        
        // 2. Search score > 0.72
        guard let topResult = kbResults.first, topResult.score > 0.72 else { return }
        
        // 3. 90-second cooldown
        let now = Date()
        guard now.timeIntervalSince(lastSuggestionTime) >= suggestionCooldown else { return }
        
        // 4. Not the same source as last suggestion
        guard topResult.source != lastSourceBreadcrumb else { return }
        
        // --- End Gate ---
        
        self.isThinking = true
        
        // Pre-Gemini state updates
        lastSuggestionTime = now
        lastSourceBreadcrumb = topResult.source
        
        // Call Gemini
        if let suggestionText = await getGeminiSuggestion(latestUtterance: segment.text, context: contextLines, kbChunks: kbResults) {
            if suggestionText != "SKIP" {
                addSuggestion(text: suggestionText, source: topResult.source)
            }
        }
        
        self.isThinking = false
    }
    
    @MainActor
    private func addSuggestion(text: String, source: String) {
        let card = SuggestionCard(text: text, sourceFile: source.components(separatedBy: " > ").first ?? source, sourceBreadcrumb: source)
        
        self.suggestions.insert(card, at: 0)
        if self.suggestions.count > self.maxSuggestions {
            self.suggestions.removeLast()
        }
    }
    
    @MainActor
    private func dismissOldSuggestions() {
        let now = Date()
        self.suggestions.removeAll { now.timeIntervalSince($0.triggeredAt) >= autoDismissSec }
    }
    
    @MainActor
    public func dismiss(suggestionID: UUID) {
        self.suggestions.removeAll { $0.id == suggestionID }
    }
    
    @MainActor
    private func getGeminiSuggestion(latestUtterance: String, context: [TranscriptSegment], kbChunks: [ChunkResult]) async -> String? {
        guard let apiKey = try? String(data: KeychainHelper.read(service: "NoteFlow", account: "GEMINI_API_KEY"), encoding: .utf8) else {
            print("Gemini API key not found in Keychain.")
            return nil
        }
        
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)")!
        
        // Format prompt
        let recentConv = context.suffix(4).map { "\($0.speaker): \($0.text)" }.joined(separator: "\n")
        let kbText = kbChunks.prefix(3).map { "Source: \($0.source)\nContent: \($0.body)" }.joined(separator: "\n\n")
        
        let promptText = """
        You are a silent meeting assistant. The person you are helping is on a live call.

        What the other person just said:
        "\(latestUtterance)"

        Recent conversation:
        \(recentConv)

        Relevant notes from their knowledge base:
        \(kbText)

        Based only on the notes above, suggest 1 short, specific talking point they could make right now.
        - Max 2 sentences
        - Be direct, no preamble like "You could say..." or "Consider mentioning..."
        - If the notes aren't relevant enough, respond with exactly: SKIP
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                ["role": "user", "parts": [["text": promptText]]]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 300
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 10.0 // 10 second timeout as requested
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                
                let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                // Basic cleanup of markdown formatting
                let plainText = cleaned.replacingOccurrences(of: "*", with: "").replacingOccurrences(of: "`", with: "")
                return plainText
            }
        } catch {
            print("Gemini API call failed or timed out: \(error)")
        }
        
        return nil
    }
}
