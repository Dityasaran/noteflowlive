import SwiftUI
import NoteFlowUI
import NoteFlowCore

@main
struct NoteFlowApp: App {
    @StateObject private var kbManager = KnowledgeBaseManager()
    
    init() {}
    
    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .onAppear {
                    configureWindowSecurity()
                }
        }
        .windowResizability(.contentSize)
        
        Settings {
            SettingsView(kbManager: kbManager)
        }
    }
    
    private func configureWindowSecurity() {
        // NSWindow.sharingType = .none prevents the window from being seen in screen captures/shares.
        // We delay slightly to ensure the window is attached.
        DispatchQueue.main.async {
            NSApplication.shared.windows.forEach { window in
                window.sharingType = .none
                window.title = "NoteFlow"
                // Although windowResizability is set to .contentSize, we set a minSize for safety.
                window.minSize = NSSize(width: 400, height: 600)
            }
        }
    }
}
