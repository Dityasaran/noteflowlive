import Foundation
@preconcurrency import AVFoundation

@MainActor
public class AudioCaptureEngine {
    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    
    public init() {
        engine.attach(mixer)
        // Connect mixer to output node so we can hear (if needed) but we usually just tap
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
    }
    
    /// Starts capturing audio and provides an AsyncStream of buffers.
    /// - Parameter useBlackHole: If true, attempts to attach an input node for the virtual driver.
    public func startCapturing(useBlackHole: Bool) -> AsyncStream<AVAudioPCMBuffer> {
        AsyncStream { continuation in
            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            
            // Tap the input node (Mic)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
                continuation.yield(buffer)
            }
            
            // If BlackHole is used, we'd traditionally need to switch the engine's input device 
            // to the BlackHole device. This logic assumes the system default input has been 
            // set to BlackHole (common approach) or we manage multiple engines. 
            // For now, we tap the primary input node which will be either the Mic or 
            // whatever the user has selected in System Settings.
            
            do {
                try engine.start()
            } catch {
                print("Failed to start Audio Engine: \(error)")
                continuation.finish()
            }
            
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.engine.stop()
                    inputNode.removeTap(onBus: 0)
                }
            }
        }
    }
    
    public func stop() {
        engine.stop()
    }
}
