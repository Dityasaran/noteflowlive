import SwiftUI
import NoteFlowCore

public struct SuggestionPanel: View {
    @ObservedObject var manager: SuggestionManager
    
    public init(manager: SuggestionManager) {
        self.manager = manager
    }
    
    public var body: some View {
        ZStack {
            if !manager.suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(manager.suggestions) { card in
                            suggestionCardView(card)
                                .transition(MotionManager.shouldReduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal)
                }
            } else if manager.isThinking {
                thinkingCard
                    .transition(.opacity)
            } else {
                VStack {
                    Spacer()
                    Text("Listening for moments to help…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                        .frame(maxWidth: .infinity)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(MotionManager.shouldReduceMotion ? nil : .spring(), value: manager.suggestions)
        .animation(.easeInOut, value: manager.isThinking)
    }
    
    private func suggestionCardView(_ card: SuggestionCard) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 4) {
                Circle()
                    .fill(confidenceColor(for: card.score))
                    .frame(width: 6, height: 6)
                
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 10))
                Text(card.sourceBreadcrumb)
                    .font(.system(size: 10))
                    .lineLimit(1)
            }
            .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(width: 300, height: 80, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .onTapGesture {
            withAnimation {
                manager.dismiss(suggestionID: card.id)
            }
        }
    }
    
    private var thinkingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.6)
            Text("Analyzing context...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color(NSColor.controlBackgroundColor).opacity(0.8)))
    }
    
    private func confidenceColor(for score: Float) -> Color {
        if score > 0.85 {
            return .green
        } else if score >= 0.72 {
            return .yellow
        } else {
            return .red
        }
    }
}
