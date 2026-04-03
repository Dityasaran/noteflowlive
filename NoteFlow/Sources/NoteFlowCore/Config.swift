import Foundation

/// Central configuration for the NoteFlow macOS application.
public struct Config {
    /// Placeholder GCP Project ID — set this via environment variable or in deployment.
    public static let gcpProjectID = "GCP_PROJECT_ID"
    
    /// Default values for the backend endpoints.
    /// These should be stored in the Keychain for production use.
    public struct Default {
        public static let wsURL = "wss://noteflow-backend-xxxxx.a.run.app/ws/transcribe"
        public static let restBaseURL = "https://noteflow-backend-xxxxx.a.run.app"
    }
    
    /// Endpoint paths
    public struct Endpoints {
        public static let transcription = "/ws/transcribe"
        public static let embeddings = "/v1/embeddings"
        public static let rerank = "/v1/rerank"
    }
    
    /// Audio Configuration
    public struct Audio {
        public static let sampleRate: Double = 16000.0
        public static let channelCount: UInt32 = 1 // Mono for transcription
        public static let blackHoleDriverName = "BlackHole 2ch"
        public static let blackHoleSetupURL = URL(string: "https://existential.audio/blackhole")!
    }
}
