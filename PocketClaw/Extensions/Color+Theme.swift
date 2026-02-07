import SwiftUI
import UIKit

// MARK: - Theme Colors

extension Color {
    /// Terminal Green — primary accent color `#30D158`
    static let terminalGreen = Color(red: 0x30 / 255.0, green: 0xD1 / 255.0, blue: 0x58 / 255.0)

    /// User message bubble background (green-tinted)
    static let userBubble = Color.terminalGreen.opacity(0.15)

    /// Assistant message bubble background
    static let assistantBubble = Color(uiColor: .systemGray6)

    /// Status dot colors
    static let statusOnline = Color.terminalGreen
    static let statusOffline = Color(uiColor: .systemGray3)
    static let statusBusy = Color.orange

    /// Code block background
    static let codeBackground = Color(uiColor: .systemGray6)
}

// MARK: - Theme Mode

enum ThemeMode: String, CaseIterable, Identifiable {
    case system
    case dark
    case light

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .dark: "Dark"
        case .light: "Light"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }
}
