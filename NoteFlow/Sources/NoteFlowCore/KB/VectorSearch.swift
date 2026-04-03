import Foundation
import Accelerate

public struct ChunkResult {
    public let body: String
    public let source: String
    public let score: Float
}

public class VectorSearch {
    private var chunks: [SQLiteManager.ChunkData] = []
    
    public init() {}
    
    /// Loads all chunks from SQLite into memory for fast searching.
    public func load(from db: SQLiteManager) {
        self.chunks = db.getAllChunks()
    }
    
    /// Performs a cosine similarity search against loaded chunks.
    /// Note: Assumes both query and stored embeddings are normalized (as nomic-embed-text does).
    /// If normalized, cosine similarity = dot product.
    public func search(query: [Float], topK: Int = 5) -> [ChunkResult] {
        var scoredResults: [(index: Int, score: Float)] = []
        
        for (i, chunk) in chunks.enumerated() {
            guard chunk.embedding.count == query.count else { continue }
            
            var dotProduct: Float = 0
            vDSP_dotpr(query, 1, chunk.embedding, 1, &dotProduct, vDSP_Length(query.count))
            
            scoredResults.append((i, dotProduct))
        }
        
        // Sort by score descending
        scoredResults.sort { $0.score > $1.score }
        
        // Take top K
        let topResults = scoredResults.prefix(topK)
        
        return topResults.map { res in
            let chunk = chunks[res.index]
            return ChunkResult(body: chunk.body, source: chunk.breadcrumb, score: res.score)
        }
    }
}
