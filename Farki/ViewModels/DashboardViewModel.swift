import SwiftUI
import Combine

public final class DashboardViewModel: ObservableObject {
    /// Top header text
    @Published public var brandTitle: String = "日本"
    @Published public var userLevelText: String = "You are ? ~ Lv"

    /// N5 Section Items
    @Published public var vocabItem: DashboardMetricItem
    @Published public var kanjiItem: DashboardMetricItem
    @Published public var particlesItem: DashboardMetricItem

    /// Progress Section Item
    @Published public var paceItem: DashboardPaceItem

    /// GuideBook Section Items
    @Published public var shokyu1Item: DashboardMetricItem
    @Published public var shokyu2Item: DashboardMetricItem

    private var cancellables = Set<AnyCancellable>()

    public init() {
        self.userLevelText = DashboardViewModel.computePredictedLevel()

        // Initial state computed dynamically from actual repository data
        let allItems = VocabDataService.shared.items
        let totalWords = allItems.count
        let completedWords = allItems.filter { $0.learningState != .unseen }.count
        let vocabProgress = totalWords > 0 ? (Double(completedWords) / Double(totalWords)) : 0.0
        let vocabPct = totalWords > 0 ? Int(round(vocabProgress * 100)) : 0

        self.vocabItem = DashboardMetricItem(
            title: "Vocab",
            completed: completedWords,
            total: totalWords,
            unit: "words",
            progressOverride: vocabProgress,
            percentageOverride: String(format: "%02d%%", vocabPct),
            customSubtitle: "You completed \(completedWords)/\(totalWords) words"
        )

        let kanjiMetrics = KanjiDataService.shared.globalMetrics()
        let kanjiProgress = kanjiMetrics.total > 0 ? (Double(kanjiMetrics.mastered) / Double(kanjiMetrics.total)) : 0.0
        self.kanjiItem = DashboardMetricItem(
            title: "Kanji",
            completed: kanjiMetrics.mastered,
            total: kanjiMetrics.total,
            unit: "Kj",
            progressOverride: kanjiProgress,
            percentageOverride: String(format: "%02d%%", kanjiMetrics.accuracy),
            customSubtitle: "You mastered \(kanjiMetrics.mastered)/\(kanjiMetrics.total) Kj"
        )

        self.particlesItem = DashboardMetricItem(
            title: "Particles",
            completed: 0,
            total: 25,
            unit: "Pt",
            progressOverride: 0.0,
            percentageOverride: "00%",
            customSubtitle: "00/25 Pt (Under Construction)"
        )

        let book1Chapters = Set(allItems.filter { $0.bookNumber == 1 }.map { $0.chapterNumber }).count
        let book2Chapters = Set(allItems.filter { $0.bookNumber == 2 }.map { $0.chapterNumber }).count
        let s1Progress = Double(book1Chapters) / 25.0
        let s2Progress = Double(book2Chapters) / 25.0

        self.shokyu1Item = DashboardMetricItem(
            title: "Shokyū I",
            completed: book1Chapters,
            total: 25,
            unit: "CH",
            progressOverride: s1Progress,
            percentageOverride: String(format: "%02d%%", Int(round(s1Progress * 100))),
            customSubtitle: "You imported \(book1Chapters)/25 CH"
        )

        self.shokyu2Item = DashboardMetricItem(
            title: "Shokyū II",
            completed: book2Chapters,
            total: 25,
            unit: "CH",
            progressOverride: s2Progress,
            percentageOverride: String(format: "%02d%%", Int(round(s2Progress * 100))),
            customSubtitle: "You imported \(book2Chapters)/25 CH"
        )

        let examDays = AppSettingsManager.shared.daysUntilExam
        let formattedExam = AppSettingsManager.shared.formattedExamDate
        self.paceItem = DashboardPaceItem(
            title: "Current",
            subtitle: "Target JLPT Exam: \(formattedExam)",
            targetDays: examDays,
            daysUnit: "D",
            progress: vocabProgress
        )

        // Subscribe to repository updates
        NotificationCenter.default.publisher(for: .vocabDataUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)

        // Subscribe to spaced repetition updates
        NotificationCenter.default.publisher(for: .srsDataUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)

        // Subscribe to target exam date changes
        NotificationCenter.default.publisher(for: .examDateUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)

        // Subscribe to vocabulary revision updates
        NotificationCenter.default.publisher(for: .vocabRevisionUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)

        // Subscribe to kanji updates
        NotificationCenter.default.publisher(for: .kanjiDataUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
    }

    // MARK: - Dynamic Data Refresh
    public func refreshData() {
        let allItems = VocabDataService.shared.items
        let totalWords = allItems.count
        let completedWords = allItems.filter { $0.learningState != .unseen }.count
        let vocabProgress = totalWords > 0 ? (Double(completedWords) / Double(totalWords)) : 0.0
        let vocabPct = totalWords > 0 ? Int(round(vocabProgress * 100)) : 0

        withAnimation(.easeInOut(duration: 0.35)) {
            userLevelText = DashboardViewModel.computePredictedLevel()

            vocabItem = DashboardMetricItem(
                title: "Vocab",
                completed: completedWords,
                total: totalWords,
                unit: "words",
                progressOverride: vocabProgress,
                percentageOverride: String(format: "%02d%%", vocabPct),
                customSubtitle: "You completed \(completedWords)/\(totalWords) words"
            )

            let kanjiMetrics = KanjiDataService.shared.globalMetrics()
            let kanjiProg = kanjiMetrics.total > 0 ? (Double(kanjiMetrics.mastered) / Double(kanjiMetrics.total)) : 0.0
            kanjiItem = DashboardMetricItem(
                title: "Kanji",
                completed: kanjiMetrics.mastered,
                total: kanjiMetrics.total,
                unit: "Kj",
                progressOverride: kanjiProg,
                percentageOverride: String(format: "%02d%%", kanjiMetrics.accuracy),
                customSubtitle: "You mastered \(kanjiMetrics.mastered)/\(kanjiMetrics.total) Kj"
            )

            let book1Chapters = Set(allItems.filter { $0.bookNumber == 1 }.map { $0.chapterNumber }).count
            let book2Chapters = Set(allItems.filter { $0.bookNumber == 2 }.map { $0.chapterNumber }).count
            let s1Progress = Double(book1Chapters) / 25.0
            let s2Progress = Double(book2Chapters) / 25.0

            shokyu1Item = DashboardMetricItem(
                title: "Shokyū I",
                completed: book1Chapters,
                total: 25,
                unit: "CH",
                progressOverride: s1Progress,
                percentageOverride: String(format: "%02d%%", Int(round(s1Progress * 100))),
                customSubtitle: "You imported \(book1Chapters)/25 CH"
            )

            shokyu2Item = DashboardMetricItem(
                title: "Shokyū II",
                completed: book2Chapters,
                total: 25,
                unit: "CH",
                progressOverride: s2Progress,
                percentageOverride: String(format: "%02d%%", Int(round(s2Progress * 100))),
                customSubtitle: "You imported \(book2Chapters)/25 CH"
            )

            let examDays = AppSettingsManager.shared.daysUntilExam
            let formattedExam = AppSettingsManager.shared.formattedExamDate
            paceItem = DashboardPaceItem(
                title: "Current",
                subtitle: "Target JLPT Exam: \(formattedExam)",
                targetDays: examDays,
                daysUnit: "D",
                progress: vocabProgress
            )

            PerformanceAnalyticsDataService.shared.refresh()
        }
    }

    // MARK: - Dynamic Spaced Repetition & Vocab Level Prediction
    public static func computePredictedLevel() -> String {
        let reviewLogs = SRSStorageService.shared.reviewLogs
        let cardStates = SRSStorageService.shared.cardStates
        let allItems = VocabDataService.shared.items

        let completedWords = allItems.filter { $0.learningState != .unseen }

        // If user hasn't tested or reviewed at least 3 cards yet, level is still uncalibrated
        let totalEngagements = reviewLogs.count + completedWords.count
        guard totalEngagements >= 3 else {
            return "You are ? ~ Lv"
        }

        // 1. Calculate Retention Rate from recent SRS review logs (or completed words)
        let recentLogs = reviewLogs.suffix(40)
        let srsRetention: Double
        if !recentLogs.isEmpty {
            let successful = recentLogs.filter { $0.rating == .good || $0.rating == .easy }.count
            srsRetention = Double(successful) / Double(recentLogs.count)
        } else {
            let easyCount = completedWords.filter { $0.difficulty == .easy }.count
            srsRetention = completedWords.isEmpty ? 0.5 : Double(easyCount) / Double(completedWords.count)
        }

        // 2. Compute Card-by-Card Mastery Weight
        // Based on SRS intervals (SM-2/FSRS stability), ease, lapses, and vocab streak
        var n5MasteryPoints: Double = 0.0
        var n4MasteryPoints: Double = 0.0

        for item in allItems {
            let card = cardStates[item.id]
            let interval = card?.intervalDays ?? 0.0
            let lapses = card?.lapses ?? 0
            let reps = card?.reps ?? 0
            let isSeen = item.learningState != .unseen

            guard isSeen || card != nil else { continue }

            var cardPower: Double = 0.0

            // SRS Stability Tier
            if interval >= 21.0 && lapses <= 1 {
                // Mature card: Solid long-term retention
                cardPower = 1.0
            } else if interval >= 7.0 || reps >= 3 {
                // Young card: Consistent recall across days
                cardPower = 0.75
            } else if interval >= 1.0 || reps >= 1 {
                // Learning: Short interval recall
                cardPower = 0.45
            } else {
                // Just encountered or relearning
                cardPower = 0.20
            }

            // Vocab-specific performance modifiers
            switch item.difficulty {
            case .easy:
                cardPower *= 1.15
            case .medium:
                cardPower *= 0.85
            case .hard:
                // Struggled / got wrong
                cardPower *= 0.35
            }

            // Streak bonus (up to +15% for streaks >= 3)
            if item.currentStreak >= 3 {
                cardPower *= 1.15
            } else if item.currentStreak == 0 && item.difficulty == .hard {
                cardPower *= 0.70
            }

            // Frequent forget lapse penalty
            if lapses >= 3 {
                cardPower *= 0.50
            }

            // Categorize by JLPT tier
            if item.jlptLevel == .n4 || item.bookNumber == 2 {
                n4MasteryPoints += cardPower
            } else {
                n5MasteryPoints += cardPower
            }
        }

        // Retention modifier: Low retention diminishes effective score
        // 90%+ retention = 1.05x, 70% retention = 0.90x, 40% retention = 0.60x
        let retentionMultiplier = max(0.40, min(1.10, 0.30 + (srsRetention * 0.80)))
        let effectiveN5 = n5MasteryPoints * retentionMultiplier
        let effectiveN4 = n4MasteryPoints * retentionMultiplier

        // 3. Dynamic Level Determination
        // JLPT N5 has ~700 words (Minna no Nihongo Book 1, Chapters 1-25).
        // Chapter 1 has 75 words.
        if effectiveN4 >= 75 && srsRetention >= 0.75 {
            return "You are N4 ~ Lv"
        } else if effectiveN4 >= 20 || effectiveN5 >= 300 {
            return "You are N5+ ~ Lv"
        } else if effectiveN5 >= 180 && srsRetention >= 0.78 {
            return "You are N5 ~ Lv"
        } else if effectiveN5 >= 110 && srsRetention >= 0.72 {
            return "You are N5.4 ~ Lv"
        } else if effectiveN5 >= 55 {
            return "You are N5.3 ~ Lv"
        } else if effectiveN5 >= 22 {
            return "You are N5.2 ~ Lv"
        } else if effectiveN5 >= 6 {
            return "You are N5.1 ~ Lv"
        } else if effectiveN5 >= 1 {
            return "You are N5.0 ~ Lv"
        } else {
            return "You are ? ~ Lv"
        }
    }
}
