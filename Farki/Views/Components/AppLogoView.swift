import SwiftUI

/// App Logo component rendering the "日本" SVG brand logo with dark mode inversion support
struct AppLogoView: View {
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared
    var tintColor: Color? = nil

    private var effectiveTintColor: Color {
        if let tintColor = tintColor {
            return tintColor
        }
        return themeManager.inkColor
    }

    var body: some View {
        Image("AppLogo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundColor(effectiveTintColor)
    }
}
