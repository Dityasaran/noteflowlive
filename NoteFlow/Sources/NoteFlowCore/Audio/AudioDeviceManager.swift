import Foundation
import AVFoundation
import NoteFlowCore

@MainActor
public class AudioDeviceManager {
    @MainActor public static let shared = AudioDeviceManager()
    
    private init() {}
    
    /// Detects if "BlackHole 2ch" (or whatever is in Config) exists in the system.
    public func isBlackHoleInstalled() -> Bool {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        ).devices
        
        return devices.contains { $0.localizedName.contains(Config.Audio.blackHoleDriverName) }
    }
    
    /// Finds the default microphone and the BlackHole device.
    public func getAvailableDevices() -> (mic: AVCaptureDevice?, system: AVCaptureDevice?) {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        ).devices
        
        let mic = devices.first { $0.deviceType == .builtInMicrophone } ?? devices.first
        let system = devices.first { $0.localizedName.contains(Config.Audio.blackHoleDriverName) }
        
        return (mic, system)
    }
}
