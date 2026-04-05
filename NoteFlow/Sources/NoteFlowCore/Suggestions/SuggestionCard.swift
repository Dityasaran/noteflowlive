import Foundation

public struct SuggestionCard: Identifiable, Equatable, Codable {
    public let id: UUID
    public let text: String
    public let sourceFile: String
    public let sourceBreadcrumb: String
    public let score: Float
    public let triggeredAt: Date
    
    public init(id: UUID = UUID(), text: String, sourceFile: String, sourceBreadcrumb: String, score: Float, triggeredAt: Date = Date()) {
        self.id = id
        self.text = text
        self.sourceFile = sourceFile
        self.sourceBreadcrumb = sourceBreadcrumb
        self.score = score
        self.triggeredAt = triggeredAt
    }
}
