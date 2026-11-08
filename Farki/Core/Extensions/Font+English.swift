import SwiftUI
import CoreText

public enum AppFontManager {
    private static var hasRegistered = false

    public static func registerCustomFonts() {
        guard !hasRegistered else { return }
        hasRegistered = true

        let fontFiles = [
            "NanumPenScript-Regular",
            "JacquardaBastarda9-Regular",
            "DotGothic16-Regular"
        ]

        for fontName in fontFiles {
            if let url = Bundle.main.url(forResource: fontName, withExtension: "ttf") {
                var error: Unmanaged<CFError>?
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
                continue
            }

            let candidatePaths = [
                Bundle.main.bundlePath + "/\(fontName).ttf",
                Bundle.main.bundlePath + "/Fonts/\(fontName).ttf"
            ]
            for path in candidatePaths {
                if FileManager.default.fileExists(atPath: path) {
                    var error: Unmanaged<CFError>?
                    CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: path) as CFURL, .process, &error)
                    break
                }
            }
        }
    }
}

extension Font {
    /// Nanum Pen Script for English exclusively, 2px smaller everywhere across the app
    public static func english(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        AppFontManager.registerCustomFonts()
        let adjusted = max(10, size - 2)
        return Font.custom("NanumPen-Regular", size: adjusted)
    }

    /// Full size for Menu page titles
    public static func englishMenu(size: CGFloat) -> Font {
        AppFontManager.registerCustomFonts()
        return Font.custom("NanumPen-Regular", size: size)
    }

    /// DotGothic16 for Japanese text everywhere across the app
    public static func japanese(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        AppFontManager.registerCustomFonts()
        return Font.custom("DotGothic16-Regular", size: size)
    }
}
