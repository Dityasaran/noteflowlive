import SwiftUI
import NoteFlowCore

public struct SettingsView: View {
    @State private var wsURL: String = ""
    @State private var restURL: String = ""
    @State private var geminiKey: String = ""
    @State private var kbPath: String = ""
    @State private var isShowingKey = false
    
    @ObservedObject var kbManager: KnowledgeBaseManager
    
    public init(kbManager: KnowledgeBaseManager) {
        self.kbManager = kbManager
    }
    
    public var body: some View {
        Form {
            Section("GCP Backend") {
                TextField("WebSocket URL", text: $wsURL)
                    .textFieldStyle(.roundedBorder)
                
                TextField("REST API URL", text: $restURL)
                    .textFieldStyle(.roundedBorder)
                
                if wsURL.isEmpty || restURL.isEmpty {
                    Text("Required to go live")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Section("AI Intelligence") {
                HStack {
                    if isShowingKey {
                        TextField("Gemini API Key", text: $geminiKey)
                    } else {
                        SecureField("Gemini API Key", text: $geminiKey)
                    }
                    Button { isShowingKey.toggle() } label: {
                        Image(systemName: isShowingKey ? "eye.slash" : "eye")
                    }
                }
                .textFieldStyle(.roundedBorder)
            }
            
            Section("Knowledge Base") {
                HStack {
                    TextField("Folder Path", text: $kbPath)
                        .disabled(true)
                    Button("Select...") {
                        selectFolder()
                    }
                }
                
                Button("Re-index KB now") {
                    kbManager.startWatching(path: kbPath)
                }
                .disabled(kbPath.isEmpty || kbManager.isIndexing)
                
                if kbManager.isIndexing {
                    ProgressView(kbManager.progressText)
                        .progressViewStyle(.linear)
                } else if kbManager.totalChunks > 0 {
                    Text("Indexed: \(kbManager.totalFiles) files, \(kbManager.totalChunks) chunks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(width: 450)
        .onAppear {
            loadKeychainValues()
        }
        .onDisappear {
            saveKeychainValues()
        }
    }
    
    private func loadKeychainValues() {
        if let data = try? KeychainHelper.read(service: "NoteFlow", account: "WS_URL"), let s = String(data: data, encoding: .utf8) { wsURL = s }
        if let data = try? KeychainHelper.read(service: "NoteFlow", account: "REST_URL"), let s = String(data: data, encoding: .utf8) { restURL = s }
        if let data = try? KeychainHelper.read(service: "NoteFlow", account: "GEMINI_API_KEY"), let s = String(data: data, encoding: .utf8) { geminiKey = s }
        if let data = try? KeychainHelper.read(service: "NoteFlow", account: "KB_FOLDER"), let s = String(data: data, encoding: .utf8) { kbPath = s }
    }
    
    private func saveKeychainValues() {
        try? KeychainHelper.save(wsURL.data(using: .utf8)!, service: "NoteFlow", account: "WS_URL")
        try? KeychainHelper.save(restURL.data(using: .utf8)!, service: "NoteFlow", account: "REST_URL")
        try? KeychainHelper.save(geminiKey.data(using: .utf8)!, service: "NoteFlow", account: "GEMINI_API_KEY")
        try? KeychainHelper.save(kbPath.data(using: .utf8)!, service: "NoteFlow", account: "KB_FOLDER")
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            self.kbPath = panel.url?.path ?? ""
            saveKeychainValues()
        }
    }
}
