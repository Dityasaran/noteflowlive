import Foundation
import NoteFlowCore

@MainActor
func runPhase6Verification() async {
    print("--- NoteFlow Phase 6: PERSISTENCE VERIFICATION ---")
    
    let persistenceManager = PersistenceManager()
    let sessionID = "TEST-SESSION-\(Int.random(in: 1000...9999))"
    print("Starting Session: \(sessionID)")
    
    persistenceManager.startSession(id: sessionID)
    
    // Simulate segments
    let segments = [
        TranscriptSegment(id: UUID(), speaker: "you", text: "Hello everyone, let's start the architecture review.", timestamp: Date().addingTimeInterval(-60)),
        TranscriptSegment(id: UUID(), speaker: "guest", text: "I'm concerned about WebSocket manager scalability under load.", timestamp: Date().addingTimeInterval(-30)),
        TranscriptSegment(id: UUID(), speaker: "you", text: "Good point. We have a local vector search but the embeddings are on GCP.", timestamp: Date())
    ]
    
    let suggestions = [
        SuggestionCard(text: "Mention the Accelerate framework for local search optimization.", sourceFile: "specs.md", sourceBreadcrumb: "specs.md > Component Deep Dive")
    ]
    
    print("Updating persistence manager with \(segments.count) segments and \(suggestions.count) suggestion...")
    persistenceManager.update(segments: segments, suggestions: suggestions)
    
    // End session and get folder
    print("Ending session...")
    if let folderURL = await persistenceManager.endSession() {
        print("SUCCESS! Session saved to: \(folderURL.path)")
        
        let transcriptURL = folderURL.appendingPathComponent("transcript.txt")
        let jsonURL = folderURL.appendingPathComponent("session.json")
        
        print("\n--- [CONTENTS: transcript.txt] ---")
        if let txt = try? String(contentsOf: transcriptURL) {
            print(txt)
        } else {
            print("FAILED to read transcript.txt")
        }
        
        print("\n--- [CONTENTS: session.json (truncated)] ---")
        if let json = try? String(contentsOf: jsonURL) {
            print(json.prefix(500) + "...")
        } else {
            print("FAILED to read session.json")
        }
        
        print("\n--- Phase 6 Verification Complete ---")
    } else {
        print("FAILED: PersistenceManager did not return a folder URL.")
    }
}

await runPhase6Verification()
