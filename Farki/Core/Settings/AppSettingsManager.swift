import SwiftUI

enum AppTextDisplayMode: String, CaseIterable, Identifiable {
    case both = "both"           // Japanese + Romaji + English
    case romajiOnly = "romaji"   // Japanese + Romaji only
    case englishOnly = "english" // Japanese + English only
    case japaneseOnly = "none"   // Japanese only

    var id: String { rawValue }

    var japanese: String {
        switch self {
        case .both: return "両方"
        case .romajiOnly: return "ローマ字"
        case .englishOnly: return "英語の意味"
        case .japaneseOnly: return "日本語のみ"
        }
    }

    var romaji: String {
        switch self {
        case .both: return "Ryouhou"
        case .romajiOnly: return "Roomaji"
        case .englishOnly: return "Eigo no Imi"
        case .japaneseOnly: return "Nihongo Nomi"
        }
    }

    var english: String {
        switch self {
        case .both: return "Both"
        case .romajiOnly: return "Romaji Only"
        case .englishOnly: return "English Only"
        case .japaneseOnly: return "Japanese Only"
        }
    }
}

final class AppSettingsManager: ObservableObject {
    static let shared = AppSettingsManager()

    /// Show Romaji subtitles in app UI (menus, settings, navigation) - independent of vocab cards
    @Published var showAppRomaji: Bool {
        didSet {
            UserDefaults.standard.set(showAppRomaji, forKey: "farki_app_show_romaji")
        }
    }

    /// Show English translations/meanings in app UI (menus, settings, navigation) - independent of vocab cards
    @Published var showAppEnglishMeaning: Bool {
        didSet {
            UserDefaults.standard.set(showAppEnglishMeaning, forKey: "farki_app_show_english_meaning")
        }
    }

    /// Practice Mode: Hide English meaning initially to encourage active recall
    @Published var practiceHideMeaningByDefault: Bool {
        didSet {
            UserDefaults.standard.set(practiceHideMeaningByDefault, forKey: "farki_practice_hide_meaning_by_default")
        }
    }

    /// Target Exam Date (defaults to December 13)
    @Published var targetExamDate: Date {
        didSet {
            UserDefaults.standard.set(targetExamDate.timeIntervalSince1970, forKey: "farki_app_target_exam_date")
            NotificationCenter.default.post(name: .examDateUpdated, object: nil)
        }
    }

    /// Dashboard Widget Visibility Controls (Requirement 5)
    @Published var showDashboardRecallVelocity: Bool {
        didSet {
            UserDefaults.standard.set(showDashboardRecallVelocity, forKey: "farki_show_dashboard_recall_velocity")
        }
    }

    @Published var showDashboardHesitation: Bool {
        didSet {
            UserDefaults.standard.set(showDashboardHesitation, forKey: "farki_show_dashboard_hesitation")
        }
    }

    @Published var showDashboardMemoryRetention: Bool {
        didSet {
            UserDefaults.standard.set(showDashboardMemoryRetention, forKey: "farki_show_dashboard_memory_retention")
        }
    }

    @Published var showDashboardMemoryStability: Bool {
        didSet {
            UserDefaults.standard.set(showDashboardMemoryStability, forKey: "farki_show_dashboard_memory_stability")
        }
    }

    /// Remaining days until target exam date
    var daysUntilExam: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: targetExamDate)
        let components = calendar.dateComponents([.day], from: today, to: target)
        return max(0, components.day ?? 0)
    }

    /// Formatted display string for target exam date (e.g. "Dec 13, 2026")
    var formattedExamDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: targetExamDate)
    }

    private init() {
        if UserDefaults.standard.object(forKey: "farki_app_show_romaji") != nil {
            self.showAppRomaji = UserDefaults.standard.bool(forKey: "farki_app_show_romaji")
        } else {
            self.showAppRomaji = true // Default ON
        }

        if UserDefaults.standard.object(forKey: "farki_app_show_english_meaning") != nil {
            self.showAppEnglishMeaning = UserDefaults.standard.bool(forKey: "farki_app_show_english_meaning")
        } else {
            self.showAppEnglishMeaning = true // Default ON
        }

        if UserDefaults.standard.object(forKey: "farki_practice_hide_meaning_by_default") != nil {
            self.practiceHideMeaningByDefault = UserDefaults.standard.bool(forKey: "farki_practice_hide_meaning_by_default")
        } else {
            self.practiceHideMeaningByDefault = true // Default ON for active recall
        }

        if UserDefaults.standard.object(forKey: "farki_show_dashboard_recall_velocity") != nil {
            self.showDashboardRecallVelocity = UserDefaults.standard.bool(forKey: "farki_show_dashboard_recall_velocity")
        } else {
            self.showDashboardRecallVelocity = false
        }

        if UserDefaults.standard.object(forKey: "farki_show_dashboard_hesitation") != nil {
            self.showDashboardHesitation = UserDefaults.standard.bool(forKey: "farki_show_dashboard_hesitation")
        } else {
            self.showDashboardHesitation = false
        }

        if UserDefaults.standard.object(forKey: "farki_show_dashboard_memory_retention") != nil {
            self.showDashboardMemoryRetention = UserDefaults.standard.bool(forKey: "farki_show_dashboard_memory_retention")
        } else {
            self.showDashboardMemoryRetention = false
        }

        if UserDefaults.standard.object(forKey: "farki_show_dashboard_memory_stability") != nil {
            self.showDashboardMemoryStability = UserDefaults.standard.bool(forKey: "farki_show_dashboard_memory_stability")
        } else {
            self.showDashboardMemoryStability = false
        }

        if let savedTimestamp = UserDefaults.standard.object(forKey: "farki_app_target_exam_date") as? Double {
            self.targetExamDate = Date(timeIntervalSince1970: savedTimestamp)
        } else {
            // Default: December 13 of current year (or next year if Dec 13 has already passed)
            let calendar = Calendar.current
            let now = Date()
            var currentYear = calendar.component(.year, from: now)
            var targetComps = DateComponents(year: currentYear, month: 12, day: 13, hour: 9, minute: 0)
            if let date = calendar.date(from: targetComps), date < now {
                currentYear += 1
                targetComps.year = currentYear
            }
            self.targetExamDate = calendar.date(from: targetComps) ?? Date()
        }
    }

    var activeDisplayMode: AppTextDisplayMode {
        if showAppRomaji && showAppEnglishMeaning {
            return .both
        } else if showAppRomaji && !showAppEnglishMeaning {
            return .romajiOnly
        } else if !showAppRomaji && showAppEnglishMeaning {
            return .englishOnly
        } else {
            return .japaneseOnly
        }
    }

    func setDisplayMode(_ mode: AppTextDisplayMode) {
        withAnimation(.easeInOut(duration: 0.25)) {
            switch mode {
            case .both:
                showAppRomaji = true
                showAppEnglishMeaning = true
            case .romajiOnly:
                showAppRomaji = true
                showAppEnglishMeaning = false
            case .englishOnly:
                showAppRomaji = false
                showAppEnglishMeaning = true
            case .japaneseOnly:
                showAppRomaji = false
                showAppEnglishMeaning = false
            }
        }
    }
}

extension Notification.Name {
    static let examDateUpdated = Notification.Name("examDateUpdated")
}
