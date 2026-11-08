import Foundation
import SwiftUI

// MARK: - Daily Review Count
struct SRSDayReviewStat: Identifiable, Equatable {
    var id: String { dateString }
    let date: Date
    let dateString: String
    let count: Int
}

// MARK: - Forecast Day
struct SRSForecastDay: Identifiable, Equatable {
    var id: Int { dayOffset }
    let dayOffset: Int          // 0 = Today, 1 = Tomorrow, ..., 6 = Day 7
    let date: Date
    let label: String           // e.g. "Today", "Sun", "Mon"
    let count: Int
}

// MARK: - Daily Activity Level for GitHub-Style Grid
enum DailyActivityLevel: Equatable {
    case goalAchieved   // >= 100 words or 2-3 chapters (Green)
    case partialProgress // 30-99 words (Orange)
    case minimalProgress // 1-29 words (Red)
    case noPractice     // 0 words (Cracked block)

    var color: Color {
        switch self {
        case .goalAchieved: return Color(hex: "#10B981")   // Green
        case .partialProgress: return Color(hex: "#F59E0B") // Orange
        case .minimalProgress: return Color(hex: "#EF4444") // Red
        case .noPractice: return Color.clear               // Cracked block shape rendered
        }
    }

    var label: String {
        switch self {
        case .goalAchieved: return "目標達成 (100+ 語)"
        case .partialProgress: return "部分進捗 (30-99 語)"
        case .minimalProgress: return "少量練習 (1-29 語)"
        case .noPractice: return "練習なし (0 語)"
        }
    }
}

// MARK: - Daily Streak Record
struct DailyStreakRecord: Identifiable, Equatable {
    var id: String { dateString }
    let date: Date
    let dateString: String
    let weekdayString: String
    let wordsReviewed: Int
    let totalReviews: Int
    let chaptersTouched: [Int]
    let activityLevel: DailyActivityLevel
    let isFuture: Bool
    let isToday: Bool
    let isBeforeStart: Bool
    let isExamDay: Bool
}

// MARK: - Streak Stats
struct StreakStats: Equatable {
    let currentStreak: Int
    let longestStreak: Int
    let totalDaysPracticed: Int
    let gridWeeks: [[DailyStreakRecord]] // 16 weeks x 7 days
    let allRecords: [String: DailyStreakRecord]
}

// MARK: - Actual vs Ideal Progress Data Point
struct ProgressComparisonPoint: Identifiable, Equatable {
    var id: String { dateString }
    let date: Date
    let dateString: String
    let actualCumulative: Int
    let idealCumulative: Int
    let dailyActual: Int
    let dailyIdeal: Int
}

// MARK: - Week Day Comparison
struct WeekDayComparison: Identifiable, Equatable {
    var id: Int { dayIndex }
    let dayIndex: Int            // 0 = Mon .. 6 = Sun
    let dayName: String          // "月", "火", etc.
    let englishDayName: String   // "Mon", "Tue", etc.
    let thisWeekCount: Int
    let lastWeekCount: Int
}

// MARK: - Trend Direction
enum TrendDirection: Equatable {
    case improved
    case declined
    case steady

    var title: String {
        switch self {
        case .improved: return "向上 (Improved)"
        case .declined: return "減少 (Declined)"
        case .steady: return "維持 (Steady)"
        }
    }

    var color: Color {
        switch self {
        case .improved: return Color(hex: "#10B981")
        case .declined: return Color(hex: "#EF4444")
        case .steady: return Color(hex: "#3B82F6")
        }
    }

    var icon: String {
        switch self {
        case .improved: return "arrow.up.right"
        case .declined: return "arrow.down.right"
        case .steady: return "equal"
        }
    }
}

// MARK: - Week Comparison Stats
struct WeekComparisonStats: Equatable {
    let thisWeekTotal: Int
    let lastWeekTotal: Int
    let absoluteDiff: Int
    let percentageChange: Double?
    let trend: TrendDirection
    let days: [WeekDayComparison]
}

// MARK: - Review Outcomes Stats
struct ReviewOutcomesStat: Equatable {
    let againCount: Int
    let hardCount: Int
    let goodCount: Int
    let easyCount: Int
    let total: Int

    var againPercent: Double { total > 0 ? (Double(againCount) / Double(total)) * 100.0 : 0.0 }
    var hardPercent: Double { total > 0 ? (Double(hardCount) / Double(total)) * 100.0 : 0.0 }
    var goodPercent: Double { total > 0 ? (Double(goodCount) / Double(total)) * 100.0 : 0.0 }
    var easyPercent: Double { total > 0 ? (Double(easyCount) / Double(total)) * 100.0 : 0.0 }
}

// MARK: - Comprehensive Scope Stats
struct SRSScopeStats: Equatable {
    let scope: SRSScope
    let totalCards: Int
    let newCount: Int
    let learningCount: Int
    let dueCount: Int
    let reviewPendingCount: Int   // All review cards
    let masteredCount: Int        // intervalDays >= 21.0
    let retentionRate30Days: Double? // 0.0 .. 100.0, nil if no reviews
    let totalReviews30Days: Int
    let successfulReviews30Days: Int
    let reviewsPerDay: [SRSDayReviewStat]
    let forecast7Days: [SRSForecastDay]

    // New Advanced Stats
    let streakStats: StreakStats
    let progressComparison: [ProgressComparisonPoint]
    let weekComparison: WeekComparisonStats
    let reviewOutcomes: ReviewOutcomesStat

    var masteredPercent: Double {
        guard totalCards > 0 else { return 0 }
        return Double(masteredCount) / Double(totalCards) * 100.0
    }
}

// MARK: - Stats Service
struct SRSStatsService {

    static func computeStats(
        scope: SRSScope,
        vocabItems: [VocabItem],
        cardStates: [String: CardState],
        reviewLogs: [ReviewLog],
        now: Date = Date(),
        config: SRSConfig = SRSConfig(),
        calendar: Calendar = Calendar.current
    ) -> SRSScopeStats {
        let scopedVocab = vocabItems.filter { scope.matches(chapter: $0.chapterNumber) }
        let direction = config.direction

        var scopedCardIds = Set<String>()
        var newCount = 0
        var learningCount = 0
        var dueCount = 0
        var reviewPendingCount = 0
        var masteredCount = 0

        for vocab in scopedVocab {
            let cardId = CardDirection.cardId(entryId: vocab.id, direction: direction)
            scopedCardIds.insert(cardId)
            let state = cardStates[cardId] ?? CardState(cardId: cardId, state: .new)

            switch state.state {
            case .new:
                newCount += 1
            case .learning, .relearning:
                learningCount += 1
            case .review:
                reviewPendingCount += 1
                if state.due <= now {
                    dueCount += 1
                }
                if state.intervalDays >= 21.0 {
                    masteredCount += 1
                }
            }
        }

        // Retention Rate for last 30 days
        let thirtyDaysAgo = now.addingTimeInterval(-30.0 * 86400.0)
        let scoped30DayLogs = reviewLogs.filter {
            scopedCardIds.contains($0.cardId) && $0.timestamp >= thirtyDaysAgo
        }

        var successfulReviews = 0
        for log in scoped30DayLogs {
            if log.rating == .good || log.rating == .easy {
                successfulReviews += 1
            }
        }

        let retentionRate: Double?
        if !scoped30DayLogs.isEmpty {
            retentionRate = (Double(successfulReviews) / Double(scoped30DayLogs.count)) * 100.0
        } else {
            retentionRate = nil
        }

        // Reviews Per Day (Last 14 days)
        var reviewsPerDay: [SRSDayReviewStat] = []
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "M/d"
        dayFormatter.calendar = calendar

        for dayOffset in (0..<14).reversed() {
            guard let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: targetDate)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let count = reviewLogs.filter {
                scopedCardIds.contains($0.cardId) && $0.timestamp >= dayStart && $0.timestamp < dayEnd
            }.count

            reviewsPerDay.append(SRSDayReviewStat(
                date: dayStart,
                dateString: dayFormatter.string(from: dayStart),
                count: count
            ))
        }

        // 7-Day Due Forecast (Day 0 / Today through Day 6)
        var forecast7Days: [SRSForecastDay] = []
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "E"
        weekdayFormatter.calendar = calendar

        for dayOffset in 0..<7 {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: targetDate)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let label: String
            if dayOffset == 0 {
                label = "Today"
            } else if dayOffset == 1 {
                label = "Tmrw"
            } else {
                label = weekdayFormatter.string(from: dayStart)
            }

            let dueInWindowCount = scopedVocab.reduce(0) { count, vocab in
                let cardId = CardDirection.cardId(entryId: vocab.id, direction: direction)
                guard let state = cardStates[cardId], state.state == .review else { return count }
                if dayOffset == 0 {
                    return (state.due < dayEnd) ? count + 1 : count
                } else {
                    return (state.due >= dayStart && state.due < dayEnd) ? count + 1 : count
                }
            }

            forecast7Days.append(SRSForecastDay(
                dayOffset: dayOffset,
                date: dayStart,
                label: label,
                count: dueInWindowCount
            ))
        }

        // Fast lookup map for vocab items
        let vocabMap = Dictionary(uniqueKeysWithValues: vocabItems.map { ($0.id, $0) })

        // Advanced Stats:
        let streakStats = computeStreakStats(reviewLogs: reviewLogs, vocabMap: vocabMap, now: now, calendar: calendar)
        let progressComparison = computeProgressComparison(reviewLogs: reviewLogs, now: now, calendar: calendar)
        let weekComparison = computeWeekComparison(reviewLogs: reviewLogs, now: now, calendar: calendar)
        let reviewOutcomes = computeReviewOutcomes(reviewLogs: reviewLogs)

        return SRSScopeStats(
            scope: scope,
            totalCards: scopedVocab.count,
            newCount: newCount,
            learningCount: learningCount,
            dueCount: dueCount,
            reviewPendingCount: reviewPendingCount,
            masteredCount: masteredCount,
            retentionRate30Days: retentionRate,
            totalReviews30Days: scoped30DayLogs.count,
            successfulReviews30Days: successfulReviews,
            reviewsPerDay: reviewsPerDay,
            forecast7Days: forecast7Days,
            streakStats: streakStats,
            progressComparison: progressComparison,
            weekComparison: weekComparison,
            reviewOutcomes: reviewOutcomes
        )
    }

    // MARK: - Streak & GitHub-Style Grid Calculation
    private static func computeStreakStats(
        reviewLogs: [ReviewLog],
        vocabMap: [String: VocabItem],
        now: Date,
        calendar: Calendar
    ) -> StreakStats {
        let today = calendar.startOfDay(for: now)

        // Group reviews by calendar day
        var logsByDay: [Date: [ReviewLog]] = [:]
        for log in reviewLogs {
            let day = calendar.startOfDay(for: log.timestamp)
            logsByDay[day, default: []].append(log)
        }

        var cal = calendar
        cal.firstWeekday = 2 // Monday is 1st weekday

        // Habit blocks start from October 24, 2026 (or today / earliest review)
        let october24 = cal.date(from: DateComponents(year: 2026, month: 10, day: 24)) ?? today
        let startDate = min(today, october24)

        // Grid starts on Monday of the start week so weekdays (Mon..Sun) align cleanly
        let startWeekday = cal.component(.weekday, from: startDate)
        let daysSinceMonday = (startWeekday == 1) ? 6 : (startWeekday - 2)
        guard let gridStartDate = cal.date(byAdding: .day, value: -daysSinceMonday, to: startDate) else {
            return StreakStats(currentStreak: 0, longestStreak: 0, totalDaysPracticed: 0, gridWeeks: [], allRecords: [:])
        }

        // Target Exam date (e.g., December 13)
        let examDate = cal.startOfDay(for: AppSettingsManager.shared.targetExamDate)

        // End grid on the Sunday of the target exam week (or at least 8 weeks)
        let examWeekday = cal.component(.weekday, from: examDate)
        let daysToSunday = (examWeekday == 1) ? 0 : (8 - examWeekday)
        let candidateEndDate = cal.date(byAdding: .day, value: daysToSunday, to: examDate) ?? examDate

        // Ensure at least 8 weeks (56 days) for consistent habit runway
        let minEndDate = cal.date(byAdding: .day, value: 55, to: gridStartDate) ?? candidateEndDate
        let gridEndDate = max(candidateEndDate, minEndDate)

        let totalDays = (cal.dateComponents([.day], from: gridStartDate, to: gridEndDate).day ?? 55) + 1

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dayFormatter.calendar = cal

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "E"
        weekdayFormatter.calendar = cal

        var allRecords: [String: DailyStreakRecord] = [:]
        var gridWeeks: [[DailyStreakRecord]] = []
        var currentWeek: [DailyStreakRecord] = []

        var dateCursor = gridStartDate
        var totalPracticedDays = 0

        for _ in 0..<totalDays {
            let dateKey = dayFormatter.string(from: dateCursor)
            let isBeforeStart = dateCursor < startDate
            let isFuture = dateCursor > today
            let isToday = dateCursor == today
            let isExamDay = (dateCursor == examDate)

            let dayLogs = logsByDay[dateCursor] ?? []
            let uniqueWordIds = Set(dayLogs.compactMap { CardDirection.parse(cardId: $0.cardId)?.entryId })
            let wordsReviewed = uniqueWordIds.count
            let totalReviews = dayLogs.count
            let chapters = Set(uniqueWordIds.compactMap { vocabMap[$0]?.chapterNumber }).sorted()

            let activityLevel: DailyActivityLevel
            if isBeforeStart || isFuture {
                activityLevel = .noPractice
            } else if wordsReviewed >= 100 || chapters.count >= 2 {
                activityLevel = .goalAchieved
                totalPracticedDays += 1
            } else if wordsReviewed >= 30 {
                activityLevel = .partialProgress
                totalPracticedDays += 1
            } else if wordsReviewed >= 1 {
                activityLevel = .minimalProgress
                totalPracticedDays += 1
            } else {
                activityLevel = .noPractice
            }

            let record = DailyStreakRecord(
                date: dateCursor,
                dateString: dateKey,
                weekdayString: weekdayFormatter.string(from: dateCursor),
                wordsReviewed: wordsReviewed,
                totalReviews: totalReviews,
                chaptersTouched: chapters,
                activityLevel: activityLevel,
                isFuture: isFuture,
                isToday: isToday,
                isBeforeStart: isBeforeStart,
                isExamDay: isExamDay
            )

            allRecords[dateKey] = record
            currentWeek.append(record)

            if currentWeek.count == 7 {
                gridWeeks.append(currentWeek)
                currentWeek = []
            }

            guard let next = cal.date(byAdding: .day, value: 1, to: dateCursor) else { break }
            dateCursor = next
        }

        // Streak Calculation
        // A qualifying practice day is any day with wordsReviewed >= 1
        var currentStreak = 0
        var checkDate = today

        // If today has activity:
        let todayKey = dayFormatter.string(from: today)
        let practicedToday = (allRecords[todayKey]?.wordsReviewed ?? 0) > 0

        if practicedToday {
            currentStreak = 1
            if let yesterday = cal.date(byAdding: .day, value: -1, to: today) {
                checkDate = yesterday
                while true {
                    let k = dayFormatter.string(from: checkDate)
                    if let rec = allRecords[k], rec.wordsReviewed > 0 {
                        currentStreak += 1
                        guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
                        checkDate = prev
                    } else if (logsByDay[checkDate]?.count ?? 0) > 0 {
                        currentStreak += 1
                        guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
                        checkDate = prev
                    } else {
                        break
                    }
                }
            }
        } else {
            // Check yesterday
            if let yesterday = cal.date(byAdding: .day, value: -1, to: today) {
                checkDate = yesterday
                let yKey = dayFormatter.string(from: yesterday)
                if let yRec = allRecords[yKey], yRec.wordsReviewed > 0 {
                    currentStreak = 1
                    if let dayBefore = cal.date(byAdding: .day, value: -1, to: yesterday) {
                        checkDate = dayBefore
                        while true {
                            let k = dayFormatter.string(from: checkDate)
                            if let rec = allRecords[k], rec.wordsReviewed > 0 {
                                currentStreak += 1
                                guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
                                checkDate = prev
                            } else if (logsByDay[checkDate]?.count ?? 0) > 0 {
                                currentStreak += 1
                                guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
                                checkDate = prev
                            } else {
                                break
                            }
                        }
                    }
                }
            }
        }

        // Longest Streak across all recorded dates
        let sortedPracticedDays = logsByDay.keys.filter { (logsByDay[$0]?.count ?? 0) > 0 }.sorted()
        var longestStreak = 0
        var tempStreak = 0
        var prevDate: Date? = nil

        for day in sortedPracticedDays {
            if let prev = prevDate {
                if let nextExpected = cal.date(byAdding: .day, value: 1, to: prev),
                   nextExpected == day {
                    tempStreak += 1
                } else {
                    tempStreak = 1
                }
            } else {
                tempStreak = 1
            }
            prevDate = day
            longestStreak = max(longestStreak, tempStreak)
        }
        longestStreak = max(longestStreak, currentStreak)

        return StreakStats(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            totalDaysPracticed: totalPracticedDays,
            gridWeeks: gridWeeks,
            allRecords: allRecords
        )
    }

    // MARK: - Actual vs Ideal Progress Calculation (Last 14 Days)
    private static func computeProgressComparison(
        reviewLogs: [ReviewLog],
        now: Date,
        calendar: Calendar
    ) -> [ProgressComparisonPoint] {
        let today = calendar.startOfDay(for: now)
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "M/d"
        dayFormatter.calendar = calendar

        let daysCount = 14
        let idealDailyTarget = 100

        var points: [ProgressComparisonPoint] = []
        var runningActual = 0

        // Find reviews per day
        var dailyActualMap: [Date: Int] = [:]
        for log in reviewLogs {
            let day = calendar.startOfDay(for: log.timestamp)
            dailyActualMap[day, default: 0] += 1
        }

        for i in 0..<daysCount {
            let offset = -(daysCount - 1 - i)
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let actualCount = dailyActualMap[date] ?? 0
            runningActual += actualCount
            let idealCumulative = (i + 1) * idealDailyTarget

            points.append(ProgressComparisonPoint(
                date: date,
                dateString: dayFormatter.string(from: date),
                actualCumulative: runningActual,
                idealCumulative: idealCumulative,
                dailyActual: actualCount,
                dailyIdeal: idealDailyTarget
            ))
        }

        return points
    }

    // MARK: - This Week vs Last Week Comparison
    private static func computeWeekComparison(
        reviewLogs: [ReviewLog],
        now: Date,
        calendar: Calendar
    ) -> WeekComparisonStats {
        var cal = calendar
        cal.firstWeekday = 2 // Monday

        let today = cal.startOfDay(for: now)
        let weekday = cal.component(.weekday, from: today) // 2=Mon ... 1=Sun
        let daysSinceMonday = (weekday == 1) ? 6 : (weekday - 2)

        guard let thisMonday = cal.date(byAdding: .day, value: -daysSinceMonday, to: today),
              let lastMonday = cal.date(byAdding: .day, value: -7, to: thisMonday) else {
            return WeekComparisonStats(thisWeekTotal: 0, lastWeekTotal: 0, absoluteDiff: 0, percentageChange: nil, trend: .steady, days: [])
        }

        let dayNamesJP = ["月", "火", "水", "木", "金", "土", "日"]
        let dayNamesEN = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

        var dayStats: [WeekDayComparison] = []
        var thisWeekTotal = 0
        var lastWeekTotal = 0

        for i in 0..<7 {
            guard let thisDay = cal.date(byAdding: .day, value: i, to: thisMonday),
                  let thisNext = cal.date(byAdding: .day, value: 1, to: thisDay),
                  let lastDay = cal.date(byAdding: .day, value: i, to: lastMonday),
                  let lastNext = cal.date(byAdding: .day, value: 1, to: lastDay) else { continue }

            let thisCount = reviewLogs.filter { $0.timestamp >= thisDay && $0.timestamp < thisNext }.count
            let lastCount = reviewLogs.filter { $0.timestamp >= lastDay && $0.timestamp < lastNext }.count

            thisWeekTotal += thisCount
            lastWeekTotal += lastCount

            dayStats.append(WeekDayComparison(
                dayIndex: i,
                dayName: dayNamesJP[i],
                englishDayName: dayNamesEN[i],
                thisWeekCount: thisCount,
                lastWeekCount: lastCount
            ))
        }

        let diff = thisWeekTotal - lastWeekTotal
        let pct: Double?
        if lastWeekTotal > 0 {
            pct = (Double(diff) / Double(lastWeekTotal)) * 100.0
        } else {
            pct = nil
        }

        let trend: TrendDirection
        if diff > 0 {
            trend = .improved
        } else if diff < 0 {
            trend = .declined
        } else {
            trend = .steady
        }

        return WeekComparisonStats(
            thisWeekTotal: thisWeekTotal,
            lastWeekTotal: lastWeekTotal,
            absoluteDiff: diff,
            percentageChange: pct,
            trend: trend,
            days: dayStats
        )
    }

    // MARK: - Review Outcomes Breakdown
    private static func computeReviewOutcomes(reviewLogs: [ReviewLog]) -> ReviewOutcomesStat {
        var again = 0
        var hard = 0
        var good = 0
        var easy = 0

        for log in reviewLogs {
            switch log.rating {
            case .again: again += 1
            case .hard: hard += 1
            case .good: good += 1
            case .easy: easy += 1
            }
        }

        return ReviewOutcomesStat(
            againCount: again,
            hardCount: hard,
            goodCount: good,
            easyCount: easy,
            total: reviewLogs.count
        )
    }
}
