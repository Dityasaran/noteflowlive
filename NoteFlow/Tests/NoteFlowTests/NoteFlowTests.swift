import XCTest
import AVFoundation
@testable import NoteFlowCore

final class NoteFlowTests: XCTestCase {
    func testWebSocketLoopback() async throws {
        // Set test URL
        let testURL = "ws://127.0.0.1:8080/ws/transcribe"
        try? KeychainHelper.save(testURL.data(using: .utf8)!, service: "NoteFlow", account: "WS_URL")
        
        let wsm = await WebSocketManager()
        let sessionID = UUID().uuidString
        await wsm.connect(sessionID: sessionID)
        
        // Wait till connected
        var connected = false
        for _ in 0..<20 {
            if await wsm.state == .connected {
                connected = true
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertTrue(connected, "Failed to connect to WebSocket server")
        
        // Generate robust 3s audio (16kHz, Float32) sine wave (440Hz)
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let capacity = AVAudioFrameCount(16000 * 3)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity)!
        buffer.frameLength = capacity
        if let data = buffer.floatChannelData?[0] {
            for i in 0..<Int(capacity) {
                // Modulate it so it sounds more voice-like (avoiding noise filters)
                data[i] = Float32(sin(Double(i) * .pi * 2.0 * 440.0 / 16000.0) * sin(Double(i) * .pi * 2.0 * 2.0 / 16000.0))
            }
        }
        
        // Send audio
        await wsm.sendAudio(buffer: buffer, speaker: "you", sessionID: sessionID)
        
        // Wait for transcript
        var received = false
        for _ in 0..<150 { // Wait up to 15s since model loading might be slow
            let segments = await wsm.transcriptSegments
            if !segments.isEmpty {
                received = true
                print("Received Transcript: \(segments.first!.text)")
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        XCTAssertTrue(received, "Failed to receive transcript segment")
    }
}
