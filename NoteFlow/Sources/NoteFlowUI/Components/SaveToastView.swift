import SwiftUI

public struct SaveToastView: View {
    let folderURL: URL?
    let onDismiss: () -> Void
    
    public init(folderURL: URL?, onDismiss: @escaping () -> Void) {
        self.folderURL = folderURL
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            VStack(alignment: .leading) {
                Text("Session saved")
                    .fontWeight(.bold)
                Text(folderURL?.lastPathComponent ?? "Meeting")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Show in Finder") {
                if let url = folderURL {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(radius: 10)
        .padding()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                onDismiss()
            }
        }
    }
}
