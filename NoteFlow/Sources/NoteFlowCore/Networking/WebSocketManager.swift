import Foundation
import AppKit
@preconcurrency import AVFoundation
import NoteFlowCore

public enum WebSocketState: String {
    case disconnected = "Disconnected"
    case connecting = "Connecting..."
    case connected = "Connected"
    case reconnecting = "Reconnecting..."
}

@MainActor
public final class WebSocketManager: ObservableObject {
    @Published public var state: WebSocketState = .disconnected
    @Published public var transcriptSegments: [TranscriptSegment] = []
    @Published public var lastError: String?
    
    private let db: SQLiteManager? = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent("NoteFlow")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return SQLiteManager(path: folder.appendingPathComponent("kb_cache.sqlite").path)
    }()
    
    public var onSearchResult: ((TranscriptSegment, [TranscriptSegment], [ChunkResult]) -> Void)?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let urlSession = URLSession(configuration: .default)
    
    private var currentSessionID: String?
    private var reconnectAttempt = 0
    private let maxReconnectAttempts = 5
    
    private var lastSearchTime: Date = .distantPast
    private let searchCooldown: TimeInterval = 90
    private let vectorSearch = VectorSearch()
    
    public init() {
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.disconnect()
        }
    }
    
    public func connect(sessionID: String) {
        self.currentSessionID = sessionID
        
        guard let urlString = try? String(data: KeychainHelper.read(service: "NoteFlow", account: "WS_URL"), encoding: .utf8),
              let url = URL(string: "\(urlString)/ws/transcribe") else {
            self.lastError = "WebSocket URL not found in Keychain. Please set it in Settings."
            return
        }
        
        disconnect()
        self.state = reconnectAttempt > 0 ? .reconnecting : .connecting
        
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Mock success for connection logic
        self.state = .connected
        self.reconnectAttempt = 0
        self.listen()
    }
    
    public func disconnect() {
        sendEndSession()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        self.state = .disconnected
    }
    
    private func sendEndSession() {
        guard let sessionID = currentSessionID, state == .connected else { return }
        let endFrame = ["type": "end_session", "session_id": sessionID]
        if let data = try? JSONSerialization.data(withJSONObject: endFrame),
           let text = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(text)) { _ in }
        }
    }
    
    public func sendAudio(buffer: AVAudioPCMBuffer, speaker: String, sessionID: String) {
        guard state == .connected else { return }
        // Header frame
        let header: [String: Any] = ["type": "audio", "speaker": speaker, "session_id": sessionID]
        if let headerData = try? JSONSerialization.data(withJSONObject: header),
           let headerString = String(data: headerData, encoding: .utf8) {
            webSocketTask?.send(.string(headerString)) { _ in }
        }
        
        // Binary audio
        if let float32Data = buffer.float32Pointer {
            let byteCount = Int(buffer.frameLength) * MemoryLayout<Float>.size
            let data = Data(bytes: float32Data, count: byteCount)
            webSocketTask?.send(.data(data)) { _ in }
        }
    }
    
    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                print("WebSocket error: \(error)")
                Task { @MainActor in self.handleDisconnect() }
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        Task { @MainActor in self.handleIncomingMessage(data: data) }
                    }
                case .data(let data):
                    Task { @MainActor in self.handleIncomingMessage(data: data) }
                @unknown default: break
                }
                Task { @MainActor in self.listen() }
            }
        }
    }
    
    private func handleIncomingMessage(data: Data) {
        if let segment = try? JSONDecoder().decode(TranscriptSegment.self, from: data) {
            self.transcriptSegments.append(segment)
            if segment.speaker != "you" && segment.text.components(separatedBy: .whitespaces).count > 8 {
                self.triggerKBSearch(text: segment.text, segment: segment)
            }
        }
    }
    
    private func handleDisconnect() {
        self.state = .disconnected
        if reconnectAttempt < maxReconnectAttempts {
            reconnectAttempt += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if let id = self.currentSessionID { self.connect(sessionID: id) }
            }
        }
    }
    
    private func triggerKBSearch(text: String, segment: TranscriptSegment) {
        let now = Date()
        guard now.timeIntervalSince(lastSearchTime) >= searchCooldown else { return }
        lastSearchTime = now
        
        Task {
            guard let urlString = try? String(data: KeychainHelper.read(service: "NoteFlow", account: "REST_URL"), encoding: .utf8),
                  let url = URL(string: "\(urlString)/v1/embeddings") else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["input": [text], "model": "nomic-embed-text"])
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataArray = json["data"] as? [[String: Any]],
                   let vector = dataArray.first?["embedding"] as? [Float] {
                    
                    if let db = self.db {
                        self.vectorSearch.load(from: db)
                        let results = self.vectorSearch.search(query: vector, topK: 5)
                        self.onSearchResult?(segment, Array(self.transcriptSegments.suffix(5)), results)
                    }
                }
            } catch {
                print("KB Search Embedding failed: \(error)")
            }
        }
    }
}
