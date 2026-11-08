import SwiftUI

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    /// Active theme persisted in UserDefaults: .dark or .light
    @Published var activeTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(activeTheme.rawValue, forKey: "farki_app_theme")
        }
    }

    /// ColorScheme applied to the window hierarchy
    var colorScheme: ColorScheme {
        activeTheme == .dark ? .dark : .light
    }

    var inkColor: Color {
        activeTheme == .dark ? Color.white : Color(hex: "#0C0A09")
    }

    var canvasColor: Color {
        activeTheme == .dark ? Color(hex: "#0C0A09") : Color.white
    }

    var mutedColor: Color {
        activeTheme == .dark ? Color(hex: "#A1A1AA") : Color(hex: "#78716C")
    }

    var segmentFilledColor: Color {
        activeTheme == .dark ? Color.white : Color(hex: "#262626")
    }

    var segmentEmptyColor: Color {
        activeTheme == .dark ? Color(hex: "#27272A") : Color(hex: "#D4D4D8")
    }

    var hairlineColor: Color {
        activeTheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08)
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "farki_app_theme"),
           let theme = AppTheme(rawValue: saved) {
            self.activeTheme = theme
        } else {
            self.activeTheme = .dark
        }
    }

    /// Toggles the app theme smoothly between dark and light, completely independent of the OS
    func toggleTheme() {
        withAnimation(.easeInOut(duration: 0.35)) {
            activeTheme = (activeTheme == .dark ? .light : .dark)
        }
    }
}
