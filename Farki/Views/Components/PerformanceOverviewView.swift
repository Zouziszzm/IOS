import SwiftUI

struct PerformanceOverviewView: View {
    @ObservedObject var analytics = PerformanceAnalyticsDataService.shared
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared
    @ObservedObject var settingsManager: AppSettingsManager = AppSettingsManager.shared
    @ObservedObject var revisionService: VocabRevisionService = VocabRevisionService.shared

    @State private var hoveredBarId: Int? = nil

    private var inkColor: Color {
        themeManager.inkColor
    }

    private var mutedColor: Color {
        themeManager.mutedColor
    }

    private var canvasColor: Color {
        themeManager.canvasColor
    }

    private var cardBackground: Color {
        themeManager.activeTheme == .dark ? Color(hex: "#0C0A09") : Color(hex: "#F5F5F4")
    }

    private var cardBorderColor: Color {
        themeManager.activeTheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.12)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            // MARK: - 0. Top Bracket Status Bar
            topBracketsStatusBar

            // MARK: - 0. Resource Overview Header & Stats Row
            headerAndStatsRow

            // MARK: - Priority 1: Chapter Progress Widget (3 Active Chapters)
            chapterProgressSection

            // MARK: - Priority 2: Trouble Radar (Chapter-wise Vocabulary Difficulty)
            troubleRadarSection

            // MARK: - Priority 3: JLPT N5 Pacing & Exam Target Forecast
            jlptPacingForecastSection

            // MARK: - Priority 4: Actionable Learning Insights (Controlled by Settings)
            if settingsManager.showDashboardRecallVelocity || settingsManager.showDashboardHesitation {
                recallVelocitySection
            }

            if settingsManager.showDashboardMemoryRetention || settingsManager.showDashboardMemoryStability {
                memoryRetentionSection
            }

            // MARK: - Priority 5: Chapter Breakdown (Moved to Bottom)
            breakdownChartCard
        }
        .onAppear {
            analytics.refresh()
        }
    }

    // MARK: - Top Bracket Status Bar (Matching Image: [ ■ ■   ■ ■   ■ ■   ■ ])
    @ViewBuilder
    private var topBracketsStatusBar: some View {
        HStack(spacing: 8) {
            Text("[")
                .font(.english(size: 15, weight: .bold))
                .foregroundColor(inkColor)

            HStack(spacing: 5) {
                Rectangle().fill(mutedColor.opacity(0.4)).frame(width: 8, height: 8)
                Rectangle().fill(mutedColor.opacity(0.4)).frame(width: 8, height: 8)
            }
            .padding(.trailing, 10)

            HStack(spacing: 5) {
                Rectangle().fill(mutedColor.opacity(0.6)).frame(width: 8, height: 8)
                Rectangle().fill(mutedColor.opacity(0.6)).frame(width: 8, height: 8)
            }
            .padding(.trailing, 10)

            HStack(spacing: 5) {
                Rectangle().fill(mutedColor.opacity(0.8)).frame(width: 8, height: 8)
                Rectangle().fill(mutedColor.opacity(0.8)).frame(width: 8, height: 8)
            }
            .padding(.trailing, 10)

            Rectangle()
                .fill(inkColor)
                .frame(width: 8, height: 8)

            Spacer()

            Text("]")
                .font(.english(size: 15, weight: .bold))
                .foregroundColor(inkColor)
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Header & Stats Stack (Horizontal Format)
    @ViewBuilder
    private var headerAndStatsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RESOURCE OVERVIEW")
                .font(.english(size: 24, weight: .bold))
                .foregroundColor(inkColor)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    bracketStatPill(label: "Words", value: "\(analytics.totalWords)")
                    bracketStatPill(label: "Units", value: "\(analytics.chapterMasteries.filter { $0.totalWords > 0 }.count)")
                    bracketStatPill(label: "Mastered", value: "\(analytics.masteredWords)")
                    bracketStatPill(label: "Retention", value: "\(analytics.retentionPct)%")
                }
            }
        }
    }

    @ViewBuilder
    private func bracketStatPill(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text("[")
                .font(.english(size: 14, weight: .bold))
                .foregroundColor(inkColor)

            Text("\(label):")
                .font(.english(size: 14, weight: .regular))
                .foregroundColor(mutedColor)

            Text(value)
                .font(.english(size: 14, weight: .bold))
                .foregroundColor(inkColor)

            Text("]")
                .font(.english(size: 14, weight: .bold))
                .foregroundColor(inkColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(themeManager.segmentEmptyColor.opacity(0.45))
        .cornerRadius(6)
    }

    // MARK: - Priority 1: Chapter Progress Widget (Requirement 3)
    @ViewBuilder
    private var chapterProgressSection: some View {
        let activeChapters = revisionService.activeThreeChapters()

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Text("[")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("CHAPTER PROGRESS")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("]")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(inkColor)
                }

                Spacer()

                Text("[ ACTIVE CHAPTERS: 3 ]")
                    .font(.english(size: 11, weight: .bold))
                    .foregroundColor(mutedColor)
                    .tracking(0.5)
            }

            if activeChapters.isEmpty {
                VStack(spacing: 6) {
                    Text("ALL CHAPTERS COMPLETED")
                        .font(.english(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#10B981"))
                    Text("All chapter vocabulary studied and fully revised!")
                        .font(.english(size: 12, weight: .regular))
                        .foregroundColor(mutedColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(themeManager.segmentEmptyColor.opacity(0.35))
                .cornerRadius(8)
            } else {
                VStack(spacing: 12) {
                    ForEach(activeChapters) { ch in
                        chapterProgressRow(ch)
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(cardBorderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func chapterProgressRow(_ ch: ChapterProgressSummary) -> some View {
        // Completion state colors:
        // State 1: In Progress -> inkColor or amber
        // State 2: Vocabulary Completed -> Blue (#3B82F6)
        // State 3: Fully Revised -> Green (#10B981)
        let state = ch.state
        let barColor: Color = {
            switch state {
            case .inProgress: return inkColor
            case .vocabularyCompleted: return Color(hex: "#3B82F6")
            case .fullyRevised: return Color(hex: "#10B981")
            }
        }()

        let statusBadgeColor: Color = {
            switch state {
            case .inProgress: return mutedColor
            case .vocabularyCompleted: return Color(hex: "#3B82F6")
            case .fullyRevised: return Color(hex: "#10B981")
            }
        }()

        VStack(alignment: .leading, spacing: 8) {
            // Chapter Header: Title, Vocabulary % and State Badge
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Text("Chapter \(ch.chapterNumber)")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("— Vocabulary: \(ch.vocabPercentage)%")
                        .font(.english(size: 13, weight: .semibold))
                        .foregroundColor(barColor)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(statusBadgeColor)
                        .frame(width: 6, height: 6)

                    Text(state.title)
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(statusBadgeColor)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusBadgeColor.opacity(0.12))
                .cornerRadius(4)
            }

            // Individual Progress Bar (Turns Blue on Vocab Completed, Green on Fully Revised)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(themeManager.segmentEmptyColor)
                        .frame(height: 7)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(ch.vocabProgress))), height: 7)
                }
            }
            .frame(height: 7)

            // Status Description & Revision Details
            HStack {
                Text(ch.statusDescription)
                    .font(.english(size: 11, weight: .regular))
                    .foregroundColor(mutedColor)

                Spacer()

                if ch.revisedWords > 0 {
                    Text("\(ch.correctlyRevisedWords)/\(ch.totalWords) revised correct")
                        .font(.english(size: 11, weight: .medium))
                        .foregroundColor(ch.correctlyRevisedWords == ch.totalWords ? Color(hex: "#10B981") : mutedColor)
                } else {
                    Text("Revision: Awaiting")
                        .font(.english(size: 11, weight: .regular))
                        .foregroundColor(mutedColor.opacity(0.8))
                }
            }
        }
        .padding(12)
        .background(themeManager.segmentEmptyColor.opacity(0.35))
        .cornerRadius(8)
    }

    // MARK: - Priority 2: Trouble Radar (Requirement 4)
    @ViewBuilder
    private var troubleRadarSection: some View {
        let troubleChapters = revisionService.troubleRadarChapters()

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Text("[")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("TROUBLE RADAR")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("]")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(inkColor)
                }

                Spacer()

                Text("RECENT REVISION DIFFICULTY")
                    .font(.english(size: 11, weight: .bold))
                    .foregroundColor(mutedColor)
                    .tracking(0.5)
            }

            if troubleChapters.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#10B981"))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("NO REVISION ACTIVITY YET")
                            .font(.english(size: 13, weight: .bold))
                            .foregroundColor(inkColor)

                        Text("Start a revision session in Vocabulary to record chapter difficulty")
                            .font(.english(size: 11, weight: .regular))
                            .foregroundColor(mutedColor)
                    }

                    Spacer()
                }
                .padding(14)
                .background(themeManager.segmentEmptyColor.opacity(0.35))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(troubleChapters) { ch in
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text("Chapter \(ch.chapterNumber)")
                                        .font(.english(size: 14, weight: .bold))
                                        .foregroundColor(inkColor)

                                    if let date = ch.lastRevisionDate {
                                        Text("• \(timeAgoString(from: date))")
                                            .font(.english(size: 10, weight: .regular))
                                            .foregroundColor(mutedColor)
                                    }
                                }

                                Text("Total: \(ch.totalWords) words")
                                    .font(.english(size: 11, weight: .regular))
                                    .foregroundColor(mutedColor)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 3) {
                                HStack(spacing: 4) {
                                    Text("\(ch.incorrectWordsCount) / \(ch.totalWords)")
                                        .font(.english(size: 14, weight: .bold))
                                        .foregroundColor(ch.incorrectWordsCount > 0 ? Color(hex: "#EF4444") : Color(hex: "#10B981"))

                                    Text("incorrect")
                                        .font(.english(size: 12, weight: .medium))
                                        .foregroundColor(ch.incorrectWordsCount > 0 ? Color(hex: "#EF4444") : Color(hex: "#10B981"))
                                }

                                // Visual bar showing error ratio
                                let ratio = ch.totalWords > 0 ? (Double(ch.incorrectWordsCount) / Double(ch.totalWords)) : 0.0
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(themeManager.segmentEmptyColor)
                                            .frame(height: 4)

                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(ch.incorrectWordsCount > 0 ? Color(hex: "#EF4444") : Color(hex: "#10B981"))
                                            .frame(width: max(4, geo.size.width * CGFloat(ratio)), height: 4)
                                    }
                                }
                                .frame(width: 90, height: 4)
                            }
                        }
                        .padding(12)
                        .background(themeManager.segmentEmptyColor.opacity(0.35))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(cardBorderColor, lineWidth: 1)
        )
    }

    private func timeAgoString(from date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(diff / 60)m ago" }
        if diff < 86400 { return "\(diff / 3600)h ago" }
        return "\(diff / 86400)d ago"
    }

    // MARK: - Priority 3: JLPT N5 Pacing Forecast
    @ViewBuilder
    private var jlptPacingForecastSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text("[")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("JLPT N5 PACING FORECAST")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("]")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(inkColor)
                }

                Spacer()

                Text("[ 16 D Ahead ]")
                    .font(.english(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#10B981"))
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(analytics.n5ReadinessPct)%")
                        .font(.english(size: 32, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("N5 Vocabulary Readiness")
                        .font(.english(size: 12, weight: .regular))
                        .foregroundColor(mutedColor)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Target: \(settingsManager.formattedExamDate)")
                        .font(.english(size: 12, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("\(settingsManager.daysUntilExam) D Remaining")
                        .font(.english(size: 12, weight: .medium))
                        .foregroundColor(mutedColor)

                    Text("Recommended Pace: \(analytics.recommendedDailyTarget) words/D")
                        .font(.english(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "#38BDF8"))
                }
            }

            SegmentedProgressBar(progress: Double(analytics.n5ReadinessPct) / 100.0, totalSegments: 25, height: 18)
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(cardBorderColor, lineWidth: 1)
        )
    }

    // MARK: - Priority 4: Recall Velocity & Hesitation Metric (Controlled by Settings)
    @ViewBuilder
    private var recallVelocitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text("[")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("RECALL VELOCITY & HESITATION")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("]")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(inkColor)
                }

                Spacer()

                if analytics.avgRecallSeconds == 0.0 {
                    Text("[ FLUENCY: UNTESTED ]")
                        .font(.english(size: 12, weight: .bold))
                        .foregroundColor(mutedColor)
                } else if analytics.avgRecallSeconds < 1.5 {
                    Text("[ FLUENCY: RAPID ]")
                        .font(.english(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#10B981"))
                } else if analytics.avgRecallSeconds < 3.5 {
                    Text("[ FLUENCY: STEADY ]")
                        .font(.english(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#F59E0B"))
                } else {
                    Text("[ FLUENCY: DELIBERATE ]")
                        .font(.english(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#EF4444"))
                }
            }

            if settingsManager.showDashboardRecallVelocity {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(String(format: "%.1f", analytics.avgRecallSeconds))s")
                            .font(.english(size: 32, weight: .bold))
                            .foregroundColor(inkColor)

                        Text(analytics.avgRecallSeconds == 0.0 ? "Take a test to record recall velocity" : "Average Recall Response Time")
                            .font(.english(size: 12, weight: .regular))
                            .foregroundColor(mutedColor)
                    }

                    Spacer()
                }
            }

            if settingsManager.showDashboardHesitation {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Text("[ < 1.5s: Instant (\(analytics.hesitationInstantPct)%) ]")
                            .font(.english(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#10B981"))
                        Spacer()
                        Text("[ 1.5-4s: Steady (\(analytics.hesitationSteadyPct)%) ]")
                            .font(.english(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#F59E0B"))
                        Spacer()
                        Text("[ > 4.0s: Hesitant (\(analytics.hesitationHesitantPct)%) ]")
                            .font(.english(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#EF4444"))
                    }

                    // Tri-Split Hesitation Bar
                    GeometryReader { geo in
                        let totalPct = analytics.hesitationInstantPct + analytics.hesitationSteadyPct + analytics.hesitationHesitantPct
                        if totalPct > 0 {
                            HStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: "#10B981"))
                                    .frame(width: geo.size.width * CGFloat(analytics.hesitationInstantPct) / 100.0)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: "#F59E0B"))
                                    .frame(width: geo.size.width * CGFloat(analytics.hesitationSteadyPct) / 100.0)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: "#EF4444"))
                                    .frame(width: geo.size.width * CGFloat(analytics.hesitationHesitantPct) / 100.0)
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(themeManager.segmentEmptyColor)
                                .frame(width: geo.size.width)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(cardBorderColor, lineWidth: 1)
        )
    }

    // MARK: - Priority 4: Memory Retention & SRS Health (Controlled by Settings)
    @ViewBuilder
    private var memoryRetentionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Text("[")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("MEMORY RETENTION & STABILITY")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("]")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(inkColor)
                }

                Spacer()

                Text("TARGET: 85-90%")
                    .font(.english(size: 12, weight: .bold))
                    .foregroundColor(mutedColor)
            }

            // 4-Tier Maturity Grid (Controlled by showDashboardMemoryRetention)
            if settingsManager.showDashboardMemoryRetention {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                    maturityPill(title: "Mature (>21d)", count: analytics.matureCount, color: Color(hex: "#10B981"))
                    maturityPill(title: "Young (<21d)", count: analytics.youngCount, color: Color(hex: "#38BDF8"))
                    maturityPill(title: "Learning", count: analytics.learningCount, color: Color(hex: "#F59E0B"))
                    maturityPill(title: "Unseen Cards", count: analytics.unseenCount, color: mutedColor)
                }
            }

            // Upcoming 7-Day Forecast Histogram (Controlled by showDashboardMemoryStability)
            if settingsManager.showDashboardMemoryStability {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Upcoming 7-Day Review Forecast:")
                        .font(.english(size: 12, weight: .semibold))
                        .foregroundColor(inkColor)

                    HStack(alignment: .bottom, spacing: 6) {
                        let days = ["D+1", "D+2", "D+3", "D+4", "D+5", "D+6", "D+7"]
                        ForEach(0..<min(days.count, analytics.sevenDayForecast.count), id: \.self) { idx in
                            let count = analytics.sevenDayForecast[idx]
                            VStack(spacing: 3) {
                                Text("\(count)")
                                    .font(.english(size: 13, weight: .bold))
                                    .foregroundColor(inkColor)

                                Rectangle()
                                    .fill(idx == 0 ? Color(hex: "#EF4444") : Color(hex: "#10B981"))
                                    .frame(height: CGFloat(count * 2))

                                Text(days[idx])
                                    .font(.english(size: 11, weight: .medium))
                                    .foregroundColor(mutedColor)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 64, alignment: .bottom)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(cardBorderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func maturityPill(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.english(size: 11, weight: .regular))
                    .foregroundColor(mutedColor)

                Text("\(count) cards")
                    .font(.english(size: 14, weight: .bold))
                    .foregroundColor(inkColor)
            }

            Spacer()
        }
        .padding(10)
        .background(themeManager.segmentEmptyColor.opacity(0.35))
        .cornerRadius(8)
    }

    // MARK: - Priority 5: Central Stacked Chart Box ("CHAPTER BREAKDOWN" at Bottom)
    @ViewBuilder
    private var breakdownChartCard: some View {
        let chartData = analytics.chartData()
        let maxVal: Double = max(1, chartData.map(\.total).max() ?? 1)
        let totalReviewsRecorded = chartData.map(\.total).reduce(0, +)

        VStack(alignment: .leading, spacing: 14) {
            // Clean Header
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Text("[")
                        .font(.english(size: 14, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("CHAPTER BREAKDOWN")
                        .font(.english(size: 16, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("]")
                        .font(.english(size: 14, weight: .bold))
                        .foregroundColor(inkColor)
                }

                Spacer()

                Text("[ CH 1 — 25 ]")
                    .font(.english(size: 13, weight: .bold))
                    .foregroundColor(mutedColor)
            }

            Divider()
                .background(cardBorderColor)

            // Dynamic Inspection Banner
            if let activeId = hoveredBarId, let bar = chartData.first(where: { $0.id == activeId }) {
                HStack(spacing: 6) {
                    Text("[ CH \(bar.id):")
                        .font(.english(size: 13, weight: .bold))
                        .foregroundColor(inkColor)

                    if bar.total > 0 {
                        Text("\(Int(bar.total)) Reviewed • Easy: \(Int(bar.easyValue)) Good: \(Int(bar.goodValue)) Hard: \(Int(bar.hardValue)) Don't Know: \(Int(bar.againValue)) ]")
                            .font(.english(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#10B981"))
                    } else {
                        Text("0 Reviewed • All Unseen ]")
                            .font(.english(size: 13, weight: .regular))
                            .foregroundColor(mutedColor)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(themeManager.segmentEmptyColor.opacity(0.45))
                .cornerRadius(6)
            }

            // Legend Row
            VStack(spacing: 6) {
                HStack {
                    bracketLegend(color: Color(hex: "#EF4444"), title: "Don't Know")
                    Spacer()
                    bracketLegend(color: Color(hex: "#F97316"), title: "Hard")
                }
                HStack {
                    bracketLegend(color: Color(hex: "#FDE047"), title: "Good")
                    Spacer()
                    bracketLegend(color: Color(hex: "#38BDF8"), title: "Easy")
                }
            }

            // Stacked Bar Graph (25 Chapters)
            VStack(spacing: 6) {
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { _ in
                            Spacer()
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 0.8)
                        }
                    }
                    .frame(height: 140)

                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(chartData) { (bar: ChartBarDataPoint) in
                            let isSelected = (hoveredBarId == bar.id)
                            VStack(spacing: 1) {
                                if bar.total > 0 {
                                    let barHeight = max(8, CGFloat((bar.total / maxVal) * 135))
                                    let easyH = CGFloat((bar.easyValue / bar.total) * Double(barHeight))
                                    let goodH = CGFloat((bar.goodValue / bar.total) * Double(barHeight))
                                    let hardH = CGFloat((bar.hardValue / bar.total) * Double(barHeight))
                                    let againH = CGFloat((bar.againValue / bar.total) * Double(barHeight))

                                    if bar.againValue > 0 {
                                        Rectangle()
                                            .fill(Color(hex: "#EF4444"))
                                            .frame(height: max(2, againH))
                                    }

                                    if bar.hardValue > 0 {
                                        Rectangle()
                                            .fill(Color(hex: "#F97316"))
                                            .frame(height: max(2, hardH))
                                    }

                                    if bar.goodValue > 0 {
                                        Rectangle()
                                            .fill(Color(hex: "#FDE047"))
                                            .frame(height: max(2, goodH))
                                    }

                                    if bar.easyValue > 0 {
                                        Rectangle()
                                            .fill(Color(hex: "#38BDF8"))
                                            .frame(height: max(2, easyH))
                                    }
                                } else {
                                    Rectangle()
                                        .fill(isSelected ? inkColor : themeManager.segmentEmptyColor)
                                        .frame(height: 3)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    hoveredBarId = bar.id
                                }
                            }
                        }
                    }
                    .frame(height: 140, alignment: .bottom)

                    if totalReviewsRecorded == 0 {
                        VStack(spacing: 4) {
                            Text("[ ALL CHAPTERS UNSEEN • PROGRESS RESET ]")
                                .font(.english(size: 13, weight: .bold))
                                .foregroundColor(mutedColor)

                            Text("Review or test words to populate chapter breakdown bars")
                                .font(.english(size: 11, weight: .regular))
                                .foregroundColor(mutedColor.opacity(0.8))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(cardBackground.opacity(0.92))
                        .cornerRadius(8)
                        .padding(.bottom, 45)
                    }
                }
                .frame(height: 140)

                HStack(spacing: 2) {
                    ForEach(chartData) { bar in
                        Text("\(bar.id)")
                            .font(.english(size: 11, weight: hoveredBarId == bar.id ? .bold : .regular))
                            .foregroundColor(hoveredBarId == bar.id ? inkColor : mutedColor.opacity(0.85))
                            .frame(maxWidth: .infinity)
                    }
                }

                HStack {
                    Text("CH 01")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)

                    Spacer()

                    Text("CHAPTER CURRICULUM (1 — 25)")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor.opacity(0.7))

                    Spacer()

                    Text("CH 25")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)
                }
                .padding(.top, 2)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(cardBorderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func bracketLegend(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Text("[")
                .font(.english(size: 13, weight: .bold))
                .foregroundColor(inkColor)

            Rectangle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.english(size: 13, weight: .medium))
                .foregroundColor(inkColor)

            Text("]")
                .font(.english(size: 13, weight: .bold))
                .foregroundColor(inkColor)
        }
    }
}
