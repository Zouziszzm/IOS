import SwiftUI

enum AppTheme: String, CaseIterable {
    case light
    case dark
}

struct AppColors {
    // Canvas background
    static func canvas(for theme: AppTheme) -> Color {
        theme == .light ? Color(hex: "#F5F5F5") : Color(hex: "#0C0A09")
    }

    // Secondary elevated surface (e.g. flashcard container)
    static func surfaceCard(for theme: AppTheme) -> Color {
        theme == .light ? Color(hex: "#FFFFFF") : Color(hex: "#1C1917")
    }

    // Grid item / receipt card background
    static func receiptCard(for theme: AppTheme) -> Color {
        theme == .light ? Color(hex: "#ECECEC") : Color(hex: "#18181B")
    }

    // Text & Primary Ink
    static func ink(for theme: AppTheme) -> Color {
        theme == .light ? Color(hex: "#0C0A09") : Color(hex: "#FAFAFA")
    }

    // Muted typography
    static func muted(for theme: AppTheme) -> Color {
        theme == .light ? Color(hex: "#78716C") : Color(hex: "#A1A1AA")
    }

    // Hairlines and dividers
    static func hairline(for theme: AppTheme) -> Color {
        theme == .light ? Color(hex: "#E5E5E5") : Color(hex: "#27272A")
    }

    // Accent red for index numbers, status dots, and badges
    static let accentRed = Color(hex: "#E11D48")

    // Pill background for floating control bar
    static func capsuleBar(for theme: AppTheme) -> Color {
        theme == .light ? Color(hex: "#0C0A09") : Color(hex: "#27272A")
    }

    // Capsule active pill
    static func capsuleActive(for theme: AppTheme) -> Color {
        theme == .light ? Color(hex: "#FFFFFF") : Color(hex: "#3F3F46")
    }
}
