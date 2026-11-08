import SwiftUI
import Combine

public struct ChartBarDataPoint: Identifiable {
    public let id: Int // Chapter 1 to 25
    public let label: String
    public let easyValue: Double  // bottom (Easy - #38BDF8)
    public let goodValue: Double  // lower-mid (Good - #FDE047)
    public let hardValue: Double  // upper-mid (Hard - #F97316)
    public let againValue: Double // top (Don't Know / Again - #EF4444)
    public var segment1Value: Double { easyValue + goodValue }
    public var segment2Value: Double { hardValue }
    public var segment3Value: Double { againValue }
    public let total: Double

    public init(id: Int, label: String, easy: Double = 0, good: Double, hard: Double, again: Double) {
        self.id = id
        self.label = label
        self.easyValue = easy
        self.goodValue = good
        self.hardValue = hard
        self.againValue = again
        self.total = easy + good + hard + again
    }

    public init(id: Int, label: String, s1: Double, s2: Double, s3: Double) {
        self.init(id: id, label: label, easy: 0, good: s1, hard: s2, again: s3)
    }
}

public struct TroubleWordItem: Identifiable {
    public let id: String
    public let japanese: String
    public let kana: String
    public let romaji: String
    public let meaning: String
    public let category: String
    public let missCount: Int
    public let consecutiveFails: Int
}

public struct ChapterMasteryItem: Identifiable {
    public let id: Int // Chapter number
    public let chapterNumber: Int
    public let totalWords: Int
    public let masteredWords: Int
    public var masteryPct: Int {
        totalWords > 0 ? Int(round((Double(masteredWords) / Double(totalWords)) * 100)) : 0
    }
    public var status: String {
        if totalWords == 0 { return "Empty" }
        if masteryPct >= 80 { return "Solid" }
        if masteryPct >= 40 { return "Progress" }
        return "Review"
    }
}

public enum AnalyticsTimeframe: String, CaseIterable, Identifiable {
    case allChapters = "25 chapters"
    public var id: String { rawValue }
}

public enum AnalyticsChartType: String, CaseIterable, Identifiable {
    case ratings = "Type: Ratings"
    public var id: String { rawValue }
}

public final class PerformanceAnalyticsDataService: ObservableObject {
    public static let shared = PerformanceAnalyticsDataService()

    @Published public var totalWords: Int = 0
    @Published public var masteredWords: Int = 0
    @Published public var retentionPct: Int = 0
    @Published public var studyPace: Int = 0
    @Published public var currentStreak: Int = 0
    @Published public var avgRecallSeconds: Double = 0.0
    @Published public var hesitationInstantPct: Int = 0
    @Published public var hesitationSteadyPct: Int = 0
    @Published public var hesitationHesitantPct: Int = 0

    @Published public var matureCount: Int = 0
    @Published public var youngCount: Int = 0
    @Published public var learningCount: Int = 0
    @Published public var unseenCount: Int = 0

    @Published public var n5ReadinessPct: Int = 0
    @Published public var daysAheadOfSchedule: Int = 0
    @Published public var recommendedDailyTarget: Int = 10

    @Published public var troubleWords: [TroubleWordItem] = []
    @Published public var verbAccuracyPct: Int = 0
    @Published public var nounAccuracyPct: Int = 0
    @Published public var adjectiveAccuracyPct: Int = 0

    @Published public var chapterMasteries: [ChapterMasteryItem] = []
    @Published public var sevenDayForecast: [Int] = [0, 0, 0, 0, 0, 0, 0]

    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupSubscriptions()
        refresh()
    }

    private func setupSubscriptions() {
        NotificationCenter.default.publisher(for: .vocabDataUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .srsDataUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    public func refresh() {
        let allItems = VocabDataService.shared.items
        let cardStates = SRSStorageService.shared.cardStates
        let reviewLogs = SRSStorageService.shared.reviewLogs

        self.totalWords = allItems.count
        let mastered = allItems.filter { $0.learningState == .knownDirectly }
        self.masteredWords = mastered.count

        // Dynamic N5 Readiness: based strictly on mastered words
        if totalWords > 0 {
            let ratio = Double(masteredWords) / Double(totalWords)
            self.n5ReadinessPct = Int(round(ratio * 100))
        } else {
            self.n5ReadinessPct = 0
        }

        // Current Streak
        self.currentStreak = allItems.map(\.currentStreak).max() ?? 0

        // Retention %: (Good + Easy) / Total reviews
        if !reviewLogs.isEmpty {
            let successful = reviewLogs.filter { $0.rating == .good || $0.rating == .easy }.count
            self.retentionPct = Int(round((Double(successful) / Double(reviewLogs.count)) * 100))
        } else {
            self.retentionPct = 0
        }

        // Recall Velocity (Response Time)
        let timedLogs = reviewLogs.filter { $0.durationMs > 0 }
        if !timedLogs.isEmpty {
            let totalMs = timedLogs.map(\.durationMs).reduce(0, +)
            self.avgRecallSeconds = Double(totalMs) / Double(timedLogs.count * 1000)

            let instant = timedLogs.filter { $0.durationMs < 1500 }.count
            let steady = timedLogs.filter { $0.durationMs >= 1500 && $0.durationMs <= 4000 }.count
            let hesitant = timedLogs.filter { $0.durationMs > 4000 }.count
            let count = Double(timedLogs.count)
            self.hesitationInstantPct = Int(round((Double(instant) / count) * 100))
            self.hesitationSteadyPct = Int(round((Double(steady) / count) * 100))
            self.hesitationHesitantPct = Int(round((Double(hesitant) / count) * 100))
        } else {
            self.avgRecallSeconds = 0.0
            self.hesitationInstantPct = 0
            self.hesitationSteadyPct = 0
            self.hesitationHesitantPct = 0
        }

        // SRS Maturity Breakdown
        let unseen = allItems.filter { $0.learningState == .unseen }.count
        let mature = cardStates.values.filter { $0.intervalDays >= 21 }.count
        let young = cardStates.values.filter { $0.intervalDays > 0 && $0.intervalDays < 21 }.count
        let learning = cardStates.values.filter { $0.state == .learning || $0.state == .relearning }.count
            + allItems.filter { $0.learningState == .knownAfterReveal }.count

        self.unseenCount = unseen
        self.matureCount = mature
        self.youngCount = young
        self.learningCount = learning

        // Study Pace: words reviewed in last 7 days / 7
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentReviews = reviewLogs.filter { $0.timestamp >= sevenDaysAgo }
        self.studyPace = max(0, recentReviews.count / 7)

        // Recommended Daily Target
        let remainingWords = max(0, totalWords - masteredWords)
        let daysRemaining = max(1, AppSettingsManager.shared.daysUntilExam)
        self.recommendedDailyTarget = max(5, Int(ceil(Double(remainingWords) / Double(daysRemaining))))
        self.daysAheadOfSchedule = max(0, (masteredWords * daysRemaining) / max(1, totalWords))

        // Chapters Mastery calculation (Ch 1..25)
        var chapters: [ChapterMasteryItem] = []
        for ch in 1...25 {
            let chWords = allItems.filter { $0.chapterNumber == ch }
            let chMastered = chWords.filter { $0.learningState == .knownDirectly }.count
            chapters.append(ChapterMasteryItem(
                id: ch,
                chapterNumber: ch,
                totalWords: chWords.count,
                masteredWords: chMastered
            ))
        }
        self.chapterMasteries = chapters

        // Trouble words calculation (leech detection): ONLY real words marked hard or with lapses
        let actualTroubleWords = allItems.filter { item in
            if item.difficulty == .hard { return true }
            if let card = cardStates[item.id], card.lapses >= 1 { return true }
            return false
        }
        var leeches: [TroubleWordItem] = []
        for item in actualTroubleWords.prefix(6) {
            let card = cardStates[item.id]
            let miss = max(1, card?.lapses ?? (item.difficulty == .hard ? 2 : 1))
            leeches.append(TroubleWordItem(
                id: item.id,
                japanese: item.japanese,
                kana: item.kana,
                romaji: item.romaji,
                meaning: item.meaning,
                category: item.wordType.description,
                missCount: miss,
                consecutiveFails: max(1, card?.lapses ?? 1)
            ))
        }
        self.troubleWords = leeches

        // Category Accuracies
        self.verbAccuracyPct = calculateAccuracy(for: allItems.filter {
            if case .verb = $0.wordType { return true }; return false
        })
        self.nounAccuracyPct = calculateAccuracy(for: allItems.filter {
            if case .noun = $0.wordType { return true }; return false
        })
        self.adjectiveAccuracyPct = calculateAccuracy(for: allItems.filter {
            if case .iAdjective = $0.wordType { return true }
            if case .naAdjective = $0.wordType { return true }
            return false
        })

        // 7-Day Forecast from scheduled SRS cards
        var forecast: [Int] = []
        let today = calendar.startOfDay(for: Date())
        for dayOffset in 1...7 {
            if let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                let dueCount = cardStates.values.filter { card in
                    calendar.isDate(card.due, inSameDayAs: targetDay)
                }.count
                forecast.append(dueCount)
            } else {
                forecast.append(0)
            }
        }
        self.sevenDayForecast = forecast
    }

    private func calculateAccuracy(for items: [VocabItem]) -> Int {
        let studied = items.filter { $0.learningState != .unseen }
        guard !studied.isEmpty else { return 0 }
        let known = studied.filter { $0.learningState == .knownDirectly }.count
        return Int(round((Double(known) / Double(studied.count)) * 100))
    }

    /// Generates 25 stacked bar data points corresponding to Chapters 1 through 25
    public func chartData(timeframe: AnalyticsTimeframe = .allChapters, type: AnalyticsChartType = .ratings) -> [ChartBarDataPoint] {
        let allItems = VocabDataService.shared.items
        let reviewLogs = SRSStorageService.shared.reviewLogs

        // Build lookup of the most recent rating per vocabulary entry ID
        var latestRatingByWordId: [String: SRSRating] = [:]
        for log in reviewLogs {
            let entryId = CardDirection.parse(cardId: log.cardId)?.entryId ?? log.cardId
            latestRatingByWordId[entryId] = log.rating
        }

        return (1...25).map { ch in
            let chWords = allItems.filter { $0.chapterNumber == ch }

            var easyCount: Double = 0
            var goodCount: Double = 0
            var hardCount: Double = 0
            var againCount: Double = 0

            for word in chWords {
                if let rating = latestRatingByWordId[word.id] {
                    switch rating {
                    case .easy:
                        easyCount += 1
                    case .good:
                        goodCount += 1
                    case .hard:
                        hardCount += 1
                    case .again:
                        againCount += 1
                    }
                } else if word.learningState != .unseen {
                    switch word.difficulty {
                    case .easy:
                        if word.learningState == .knownDirectly {
                            easyCount += 1
                        } else {
                            goodCount += 1
                        }
                    case .medium:
                        goodCount += 1
                    case .hard:
                        againCount += 1
                    }
                }
            }

            return ChartBarDataPoint(
                id: ch,
                label: "CH \(ch)",
                easy: easyCount,
                good: goodCount,
                hard: hardCount,
                again: againCount
            )
        }
    }
}
