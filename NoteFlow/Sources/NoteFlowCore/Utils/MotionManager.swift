import SwiftUI
import AppKit

public struct MotionManager {
    public static var shouldReduceMotion: Bool {
        if CommandLine.arguments.contains("--ui-testing") { return true }
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    
    public static func apply(_ anim: Animation) -> Animation? {
        return shouldReduceMotion ? nil : anim
    }
}
