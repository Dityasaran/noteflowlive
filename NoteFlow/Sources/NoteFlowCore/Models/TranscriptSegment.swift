import Foundation

public struct TranscriptSegment: Identifiable, Codable {
    public let id: UUID
    public let speaker: String // "you" or "them"
    public let text: String
    public let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case type, speaker, text, timestamp
    }
    
    public init(id: UUID = UUID(), speaker: String, text: String, timestamp: Date) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.timestamp = timestamp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.speaker = try container.decodeIfPresent(String.self, forKey: .speaker) ?? "unknown"
        self.text = try container.decode(String.self, forKey: .text)
        let tsInt = try container.decodeIfPresent(Int.self, forKey: .timestamp) ?? Int(Date().timeIntervalSince1970 * 1000)
        self.timestamp = Date(timeIntervalSince1970: TimeInterval(tsInt) / 1000.0)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(speaker, forKey: .speaker)
        try container.encode(text, forKey: .text)
        try container.encode(Int(timestamp.timeIntervalSince1970 * 1000), forKey: .timestamp)
    }
}
