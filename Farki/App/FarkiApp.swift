import SwiftUI

@main
struct FarkiApp: App {
    @StateObject private var themeManager = ThemeManager.shared

    init() {
        AppFontManager.registerCustomFonts()
    }

    var body: some Scene {
        WindowGroup {
            MainContainerView()
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}
