import SwiftUI
import NoteFlowCore

public struct MainWindowView: View {
    @StateObject private var wsManager = WebSocketManager()
    @StateObject private var suggestionManager = SuggestionManager()
    @StateObject private var persistenceManager = PersistenceManager()
    
    @State private var isBlackHoleInstalled: Bool = true
    @State private var isLive = false
    @State private var currentSessionID: String?
    
    // Timer state
    @State private var sessionSeconds = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // UI Toast & Banners
    @State private var showSaveToast = false
    @State private var lastFolderURL: URL?
    
    // Auto-scroll state
    @State private var userIsScrolling = false
    
    // Audio engine
    private let captureEngine = AudioCaptureEngine()
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // --- TOP PANEL: AI Suggestions ---
                SuggestionPanel(manager: suggestionManager)
                    .frame(height: 120)
                
                Divider()
                
                // --- MAIN CONTENT: Transcript & Status ---
                VStack(spacing: 0) {
                    if !isBlackHoleInstalled {
                        setupBanner
                    }
                    
                    if let error = wsManager.lastError {
                        errorBanner(message: error)
                    }
                    
                    // Connection Lost Billboard
                    if wsManager.state == .reconnecting {
                        HStack {
                            Image(systemName: "wifi.exclamationmark")
                            Text("Connection lost — reconnecting…")
                        }
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(6)
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                    }
                    
                    statusHeader
                    
                    transcriptView
                }
                .onChange(of: wsManager.transcriptSegments) { segments in
                    persistenceManager.update(segments: segments, suggestions: suggestionManager.suggestions)
                }
                
                Divider()
                
                // --- BOTTOM BAR: Controls ---
                HStack {
                    controlButton
                    
                    if isLive {
                        Text(formatDuration(sessionSeconds))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    }
                    
                    Spacer()
                    
                    Button("Clear") {
                        wsManager.transcriptSegments.removeAll()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                .padding()
            }
            .background(.ultraThinMaterial)
            
            // --- Toast Layer ---
            if showSaveToast {
                SaveToastView(folderURL: lastFolderURL) {
                    showSaveToast = false
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 20)
                .zIndex(999)
            }
        }
        .frame(minWidth: 400, minHeight: 600)
        .onAppear {
            isBlackHoleInstalled = AudioDeviceManager.shared.isBlackHoleInstalled()
            suggestionManager.startCleanupTimer()
        }
        .onReceive(timer) { _ in
            if isLive && wsManager.state == .connected {
                sessionSeconds += 1
            }
        }
    }
    
    private var statusHeader: some View {
        HStack {
            Group {
                if wsManager.state == .connecting || wsManager.state == .reconnecting {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .opacity(0.6)
                        .scaleEffect(1.2)
                        .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                } else {
                    Circle()
                        .fill(wsManager.state == .connected ? Color.green : Color.secondary)
                        .frame(width: 8, height: 8)
                }
            }
            
            Text(wsManager.state.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if let sessionID = currentSessionID {
                Text("ID: \(sessionID.prefix(8))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if wsManager.transcriptSegments.isEmpty {
                        Text("Ready to listen...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    
                    ForEach(wsManager.transcriptSegments) { segment in
                        HStack(alignment: .top) {
                            Text(segment.speaker.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(segment.speaker == "you" ? .blue : .purple)
                                .frame(width: 40, alignment: .leading)
                            
                            Text(segment.text)
                                .font(.body)
                        }
                        .id(segment.id)
                        .padding(.horizontal)
                    }
                    
                    Color.clear.frame(height: 1).id("bottom")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical)
            }
            .onChange(of: wsManager.transcriptSegments) { _ in
                if !userIsScrolling {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var controlButton: some View {
        Button(isLive ? "Stop Session" : "Go Live") {
            toggleLive()
        }
        .buttonStyle(.borderedProminent)
        .tint(isLive ? .red : .green)
        .controlSize(.large)
        .disabled(wsManager.state == .connecting || wsManager.state == .reconnecting)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
    
    private func toggleLive() {
        if isLive {
            isLive = false
            captureEngine.stop()
            wsManager.disconnect()
            
            Task {
                if let folderURL = await persistenceManager.endSession() {
                    self.lastFolderURL = folderURL
                    withAnimation {
                        self.showSaveToast = true
                    }
                }
                currentSessionID = nil
                sessionSeconds = 0
            }
        } else {
            isLive = true
            sessionSeconds = 0
            let sessionID = UUID().uuidString
            currentSessionID = sessionID
            
            persistenceManager.startSession(id: sessionID)
            wsManager.connect(sessionID: sessionID)
            
            // Wire search results to SuggestionManager
            wsManager.onSearchResult = { segment, context, kbResults in
                Task { @MainActor in
                    await suggestionManager.processNewSegment(segment: segment, contextLines: context, kbResults: kbResults)
                }
            }
            
            let stream = captureEngine.startCapturing(useBlackHole: isBlackHoleInstalled)
            Task {
                for await buffer in stream {
                    guard isLive else { break }
                    wsManager.sendAudio(buffer: buffer, speaker: "you", sessionID: sessionID)
                }
            }
        }
    }
    
    private var setupBanner: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Speakers not tracked")
                    .fontWeight(.bold)
            }
            Text("Install BlackHole 2ch to capture meeting guests.")
                .font(.caption)
        }
        .padding(10)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(8)
        .padding()
    }
    
    private func errorBanner(message: String) -> some View {
        HStack {
            Image(systemName: "xmark.octagon.fill")
            Text(message).font(.caption)
            Spacer()
            Button(action: { wsManager.lastError = nil }) {
                Image(systemName: "xmark")
            }.buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.red.opacity(0.15))
        .foregroundColor(.red)
        .cornerRadius(8)
        .padding(.horizontal)
    }
}
