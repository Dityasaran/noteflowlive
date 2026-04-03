import Foundation
import Combine

@MainActor
public final class KnowledgeBaseManager: ObservableObject {
    @Published public var isIndexing = false
    @Published public var progressText = ""
    @Published public var totalFiles = 0
    @Published public var indexedFiles = 0
    @Published public var totalChunks = 0
    
    private let db: SQLiteManager
    private var watchPath: String?
    private var fileWatcher: DispatchSourceFileSystemObject?
    
    public init(dbPath: String) {
        self.db = SQLiteManager(path: dbPath)!
    }
    
    public func startWatching(path: String) {
        self.watchPath = path
        let url = URL(fileURLWithPath: path)
        
        // Initial index
        Task { await indexKB(url: url) }
        
        // Setup watcher
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                await self?.indexKB(url: url)
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.fileWatcher = source
    }
    
    @MainActor
    private func indexKB(url: URL) async {
        guard !isIndexing else { return }
        isIndexing = true
        progressText = "Scanning KB folder..."
        
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        
        var filesToIndex: [URL] = []
        while let fileURL = enumerator?.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "md" || ext == "txt" {
                filesToIndex.append(fileURL)
            }
        }
        
        totalFiles = filesToIndex.count
        indexedFiles = 0
        let existingHashes = db.getFileHashes()
        
        var allNewChunks: [KBChunk] = []
        
        for fileURL in filesToIndex {
            let path = fileURL.path
            let currentHash = SHA256Helper.hash(fileAt: fileURL) ?? ""
            
            if existingHashes[path] != currentHash {
                // Remove old chunks
                db.deleteChunksForFile(path: path)
                
                // Chunk new file
                let chunks = Chunker.chunk(fileURL: fileURL)
                // We need to associate the hash with the chunks for the DB
                var hashedChunks = chunks
                allNewChunks.append(contentsOf: hashedChunks)
            }
            indexedFiles += 1
            progressText = "Scanning... \(indexedFiles)/\(totalFiles) files"
        }
        
        if !allNewChunks.isEmpty {
            progressText = "Embedding \(allNewChunks.count) new chunks..."
            await processEmbeddingBatches(chunks: allNewChunks, existingHashes: existingHashes, folderURL: url)
        }
        
        let finalChunks = db.getAllChunks()
        totalChunks = finalChunks.count
        progressText = "KB ready — \(totalFiles) files, \(totalChunks) chunks"
        isIndexing = false
    }
    
    private func processEmbeddingBatches(chunks: [KBChunk], existingHashes: [String: String], folderURL: URL) async {
        let batchSize = 32
        var currentBatch: [KBChunk] = []
        
        for chunk in chunks {
            currentBatch.append(chunk)
            if currentBatch.count >= batchSize {
                await embedAndStore(batch: currentBatch)
                currentBatch.removeAll()
            }
        }
        
        if !currentBatch.isEmpty {
            await embedAndStore(batch: currentBatch)
        }
    }
    
    private func embedAndStore(batch: [KBChunk]) async {
        let texts = batch.map { "[\($0.breadcrumb)] \($0.body)" }
        
        // Request embeddings from GCP
        guard let urlString = try? String(data: KeychainHelper.read(service: "NoteFlow", account: "REST_URL"), encoding: .utf8),
              let url = URL(string: "\(urlString)/v1/embeddings") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["input": texts, "model": "nomic-embed-text"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArray = json["data"] as? [[String: Any]] {
                
                for (i, item) in dataArray.enumerated() {
                    if let vector = item["embedding"] as? [Float] {
                        let chunk = batch[i]
                        let fileHash = SHA256Helper.hash(fileAt: URL(fileURLWithPath: chunk.filePath)) ?? ""
                        db.insertChunk(id: chunk.id, filePath: chunk.filePath, breadcrumb: chunk.breadcrumb, body: chunk.body, embedding: vector, fileHash: fileHash)
                    }
                }
            }
        } catch {
            print("Embedding batch failed: \(error)")
            // Future requirement: Mark as pending and retry
        }
    }
}
