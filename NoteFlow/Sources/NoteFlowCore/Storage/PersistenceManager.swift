import Foundation

public struct SessionMetadata: Codable {
    public let session_id: String
    public let started_at: Date
    public var ended_at: Date?
    public var transcript: [TranscriptSegment]
    public var suggestions: [SuggestionCard]
}

@MainActor
public final class PersistenceManager: ObservableObject {
    private let fileManager = FileManager.default
    private let rootFolder: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("NoteFlow")
    }()
    
    private var currentSessionID: String?
    private var currentStartedAt: Date?
    private var segments: [TranscriptSegment] = []
    private var suggestions: [SuggestionCard] = []
    
    private var flushTask: Task<Void, Never>?
    
    public init() {}
    
    public func startSession(id: String) {
        self.currentSessionID = id
        self.currentStartedAt = Date()
        self.segments = []
        self.suggestions = []
        
        // Start 60s flush loop
        flushTask?.cancel()
        flushTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                await self.flushToDisk(isFinal: false)
            }
        }
    }
    
    public func update(segments: [TranscriptSegment], suggestions: [SuggestionCard]) {
        self.segments = segments
        self.suggestions = suggestions
    }
    
    public func endSession() async -> URL? {
        flushTask?.cancel()
        flushTask = nil
        
        guard !segments.isEmpty else { return nil }
        return await flushToDisk(isFinal: true)
    }
    
    @discardableResult
    private func flushToDisk(isFinal: Bool) async -> URL? {
        guard let sessionID = currentSessionID, !segments.isEmpty else { return nil }
        
        let sessionFolder = rootFolder.appendingPathComponent(sessionID)
        try? fileManager.createDirectory(at: sessionFolder, withIntermediateDirectories: true)
        
        let transcriptURL = sessionFolder.appendingPathComponent(isFinal ? "transcript.txt" : "transcript.temp.txt")
        let jsonURL = sessionFolder.appendingPathComponent(isFinal ? "session.json" : "session.temp.json")
        
        // 1. Format transcript.txt
        let transcriptText = segments.map { segment in
            let df = DateFormatter()
            df.dateFormat = "HH:mm:ss"
            let ts = df.string(from: segment.timestamp)
            let speaker = segment.speaker.lowercased() == "you" ? "You" : "Them"
            return "[\(ts)] \(speaker): \(segment.text)"
        }.joined(separator: "\n")
        
        try? transcriptText.write(to: transcriptURL, atomically: true, encoding: .utf8)
        
        // 2. Format session.json
        let metadata = SessionMetadata(
            session_id: sessionID,
            started_at: currentStartedAt ?? Date(),
            ended_at: isFinal ? Date() : nil,
            transcript: segments,
            suggestions: suggestions
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(metadata) {
            try? data.write(to: jsonURL)
        }
        
        // If final, clean up temp files
        if isFinal {
            try? fileManager.removeItem(at: sessionFolder.appendingPathComponent("transcript.temp.txt"))
            try? fileManager.removeItem(at: sessionFolder.appendingPathComponent("session.temp.json"))
        }
        
        return sessionFolder
    }
}
