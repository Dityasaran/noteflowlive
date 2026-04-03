import Foundation
import NoteFlowCore

let args = ProcessInfo.processInfo.arguments
guard args.count > 1 else {
    print("Usage: swift set_gemini_key.swift YOUR_GEMINI_API_KEY")
    exit(1)
}

let key = args[1]
do {
    try KeychainHelper.save(key.data(using: .utf8)!, service: "NoteFlow", account: "GEMINI_API_KEY")
    print("Gemini API Key saved to Keychain successfully ✓")
} catch {
    print("Failed to save key: \(error)")
    exit(1)
}
