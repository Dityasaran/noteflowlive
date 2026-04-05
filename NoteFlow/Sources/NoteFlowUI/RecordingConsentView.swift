import SwiftUI

public struct RecordingConsentView: View {
    @AppStorage("hasAcceptedRecordingConsent") var hasAcceptedConsent = false
    @State private var innerAccepted = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 24) {
            // App Icon
            Image(systemName: "waveform.and.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.blue)
                .padding(.top, 40)
            
            // Header
            VStack(spacing: 8) {
                Text("Before you start recording")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("NoteFlow records and transcribes audio\nfrom your microphone and system audio.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Body sections
            VStack(alignment: .leading, spacing: 20) {
                consentSection(
                    icon: "globe",
                    title: "Your responsibility",
                    description: "Recording laws vary by location. You are solely responsible for obtaining consent from all participants before recording."
                )
                
                consentSection(
                    icon: "lock.fill",
                    title: "Your privacy",
                    description: "Audio never leaves your Mac. Transcription is on-device. Only text is sent to Gemini for suggestions."
                )
                
                consentSection(
                    icon: "externaldrive.fill",
                    title: "Your data",
                    description: "Sessions are saved locally to ~/Documents/NoteFlow/. No audio is ever uploaded anywhere."
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Footer
            VStack(spacing: 16) {
                Toggle(isOn: $innerAccepted) {
                    Text("I understand and agree to obtain consent from all participants before recording")
                        .font(.subheadline)
                }
                .toggleStyle(.checkbox)
                
                Button(action: {
                    hasAcceptedConsent = true
                }) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(innerAccepted ? Color.blue : Color.gray.opacity(0.3))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(!innerAccepted)
                
                Button(action: {
                    if let url = URL(string: "https://github.com/ditya/notetaker/blob/main/README.md#privacy") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Learn more about privacy")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(width: 500, height: 750)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow).ignoresSafeArea())
    }
    
    private func consentSection(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// Helper for Background Vibrancy
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
