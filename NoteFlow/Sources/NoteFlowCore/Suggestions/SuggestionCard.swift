import Foundation

public struct SuggestionCard: Identifiable, Equatable, Codable {
    public let id: UUID
    public let text: String
    public let sourceFile: String
    public let sourceBreadcrumb: String
    public let triggeredAt: Date
    
    public init(id: UUID = UUID(), text: String, sourceFile: String, sourceBreadcrumb: String, triggeredAt: Date = Date()) {
        self.id = id
        self.text = text
        self.sourceFile = sourceFile
        self.sourceBreadcrumb = sourceBreadcrumb
        self.triggeredAt = triggeredAt
    }
}
