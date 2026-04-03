import Foundation
@preconcurrency import AVFoundation

public class AudioResampler {
    private let engineFormat: AVAudioFormat
    private let targetFormat: AVAudioFormat
    private let converter: AVAudioConverter
    
    public init?(sourceFormat: AVAudioFormat, targetSampleRate: Double = 16000.0) {
        self.engineFormat = sourceFormat
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: targetSampleRate, channels: 1, interleaved: false) else { return nil }
        self.targetFormat = format
        guard let conv = AVAudioConverter(from: sourceFormat, to: targetFormat) else { return nil }
        self.converter = conv
    }
    
    public func convert(buffer inputBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let capacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * targetFormat.sampleRate / engineFormat.sampleRate) + 1
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return nil }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }
        
        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if status == .error || error != nil {
            print("Audio conversion error: \(String(describing: error))")
            return nil
        }
        return outputBuffer
    }
    
    public static func toFloat32Data(buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.floatChannelData else { return nil }
        let frameLength = Int(buffer.frameLength)
        let bytes = UnsafeBufferPointer(start: channelData[0], count: frameLength)
        return Data(buffer: bytes)
    }
}
