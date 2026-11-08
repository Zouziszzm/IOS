import SwiftUI

/// Visual Charts for SRS Statistics: Actual vs Ideal, This Week vs Last Week, and Review Outcomes Breakdown
struct SRSProgressChartsView: View {
    let stats: SRSScopeStats
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared
    @ObservedObject var settingsManager: AppSettingsManager = AppSettingsManager.shared

    private var inkColor: Color { themeManager.inkColor }
    private var mutedColor: Color { themeManager.mutedColor }
    private var cardBackground: Color {
        themeManager.activeTheme == .dark ? Color(hex: "#1E222B") : Color.white
    }

    var body: some View {
        VStack(spacing: 20) {
            // Chart 1: Actual Progress vs Ideal Progress Line Chart
            actualVsIdealChartCard

            // Chart 2: This Week vs Last Week Comparison Line Chart
            weekComparisonChartCard

            // Chart 3: Review Outcomes Breakdown Bar Chart (Hard, Good, Easy)
            reviewOutcomesCard

            // Chart 4: Daily Goal Completion Bar Chart
            dailyGoalBarChartCard
        }
    }

    // MARK: - Chart 1: Actual Progress vs Ideal Progress (Line Chart)
    private var actualVsIdealChartCard: some View {
        let points = stats.progressComparison
        let hasData = points.contains { $0.dailyActual > 0 }
        let maxVal = max(100, max(points.map(\.actualCumulative).max() ?? 0, points.map(\.idealCumulative).max() ?? 100))

        let lastPoint = points.last
        let actualTotal = lastPoint?.actualCumulative ?? 0
        let idealTotal = lastPoint?.idealCumulative ?? 1400
        let diff = actualTotal - idealTotal
        let isAhead = diff >= 0

        return VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("累積進捗 vs 目標進捗")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(inkColor)

                    if settingsManager.showAppRomaji {
                        Text("Ruiseki Shinchoku vs Mokuhyou Shinchoku")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(mutedColor)
                    }

                    if settingsManager.showAppEnglishMeaning {
                        Text("Actual vs. Ideal Progress")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(mutedColor.opacity(0.85))
                    }

                    Text("過去14日間の目標ペース（1日100語）との比較")
                        .font(.system(size: 11))
                        .foregroundColor(mutedColor)
                }

                Spacer()

                // Pace Badge
                if hasData {
                    HStack(spacing: 4) {
                        Image(systemName: isAhead ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                            .font(.system(size: 11))
                        Text(isAhead ? "目標達成ペース (+\(diff))" : "目標より遅れ (\(diff))")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(isAhead ? Color(hex: "#10B981") : Color(hex: "#F59E0B"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isAhead ? Color(hex: "#10B981") : Color(hex: "#F59E0B")).opacity(0.12))
                    .cornerRadius(6)
                }
            }

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 5) {
                    Circle().fill(Color(hex: "#3B82F6")).frame(width: 8, height: 8)
                    Text("実績: \(actualTotal) 語")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(inkColor)
                }

                HStack(spacing: 5) {
                    Rectangle().stroke(Color(hex: "#F59E0B"), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])).frame(width: 14, height: 2)
                    Text("目標: 100語/日")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(mutedColor)
                }
            }

            // Line Canvas
            if !hasData {
                VStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 26))
                        .foregroundColor(mutedColor.opacity(0.5))
                    Text("過去14日間の練習実績がありません。\n学習を進めると実績ラインが描画されます。")
                        .font(.system(size: 11))
                        .foregroundColor(mutedColor)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(themeManager.segmentEmptyColor.opacity(0.20))
                .cornerRadius(8)
            } else {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let count = points.count
                    let stepX = count > 1 ? (w - 24) / CGFloat(count - 1) : 0

                    ZStack {
                        // Background grid lines
                        VStack(spacing: 0) {
                            Divider().background(themeManager.hairlineColor)
                            Spacer()
                            Divider().background(themeManager.hairlineColor)
                            Spacer()
                            Divider().background(themeManager.hairlineColor)
                        }

                        // Ideal Progress Line (Dashed Orange)
                        Path { path in
                            for i in 0..<count {
                                let x = 12 + CGFloat(i) * stepX
                                let y = h - (CGFloat(points[i].idealCumulative) / CGFloat(maxVal)) * (h - 16) - 8
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(Color(hex: "#F59E0B"), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

                        // Actual Progress Area Gradient
                        Path { path in
                            guard count > 0 else { return }
                            let startX: CGFloat = 12
                            let startY = h - (CGFloat(points[0].actualCumulative) / CGFloat(maxVal)) * (h - 16) - 8
                            path.move(to: CGPoint(x: startX, y: h))
                            path.addLine(to: CGPoint(x: startX, y: startY))
                            for i in 1..<count {
                                let x = 12 + CGFloat(i) * stepX
                                let y = h - (CGFloat(points[i].actualCumulative) / CGFloat(maxVal)) * (h - 16) - 8
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                            let lastX = 12 + CGFloat(count - 1) * stepX
                            path.addLine(to: CGPoint(x: lastX, y: h))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#3B82F6").opacity(0.25), Color(hex: "#3B82F6").opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        // Actual Progress Line (Solid Blue)
                        Path { path in
                            for i in 0..<count {
                                let x = 12 + CGFloat(i) * stepX
                                let y = h - (CGFloat(points[i].actualCumulative) / CGFloat(maxVal)) * (h - 16) - 8
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(Color(hex: "#3B82F6"), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                        // Data dots on Actual
                        ForEach(0..<count, id: \.self) { i in
                            let x = 12 + CGFloat(i) * stepX
                            let y = h - (CGFloat(points[i].actualCumulative) / CGFloat(maxVal)) * (h - 16) - 8
                            Circle()
                                .fill(Color(hex: "#3B82F6"))
                                .frame(width: 5, height: 5)
                                .position(x: x, y: y)
                        }
                    }
                }
                .frame(height: 130)

                // Bottom X-axis Date Labels
                HStack {
                    if let first = points.first {
                        Text(first.dateString)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(mutedColor)
                    }
                    Spacer()
                    if points.count >= 7 {
                        Text(points[points.count / 2].dateString)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(mutedColor)
                    }
                    Spacer()
                    if let last = points.last {
                        Text(last.dateString)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(mutedColor)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }

    // MARK: - Chart 2: This Week vs Last Week (Line Chart)
    private var weekComparisonChartCard: some View {
        let week = stats.weekComparison
        let maxVal = max(10, max(week.days.map(\.thisWeekCount).max() ?? 0, week.days.map(\.lastWeekCount).max() ?? 0))
        let hasAnyActivity = (week.thisWeekTotal > 0 || week.lastWeekTotal > 0)

        return VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("今週 vs 先週")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(inkColor)

                    if settingsManager.showAppRomaji {
                        Text("Konshuu vs Senshuu")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(mutedColor)
                    }

                    if settingsManager.showAppEnglishMeaning {
                        Text("This Week vs. Last Week")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(mutedColor.opacity(0.85))
                    }

                    Text("曜日別（月〜日）の復習学習推移の比較")
                        .font(.system(size: 11))
                        .foregroundColor(mutedColor)
                }

                Spacer()

                // Trend Badge
                if hasAnyActivity {
                    HStack(spacing: 4) {
                        Image(systemName: week.trend.icon)
                            .font(.system(size: 11, weight: .bold))

                        if let pct = week.percentageChange {
                            Text(String(format: "%+.1f%%", pct))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        } else {
                            Text(week.trend.title)
                                .font(.system(size: 10, weight: .bold))
                        }
                    }
                    .foregroundColor(week.trend.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(week.trend.color.opacity(0.12))
                    .cornerRadius(6)
                }
            }

            // Totals Row
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Circle().fill(Color(hex: "#10B981")).frame(width: 8, height: 8)
                        Text("今週")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(mutedColor)
                    }
                    if settingsManager.showAppEnglishMeaning {
                        Text("This Week")
                            .font(.system(size: 9))
                            .foregroundColor(mutedColor.opacity(0.85))
                    }
                    Text("\(week.thisWeekTotal) 語")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(inkColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Circle().fill(Color(hex: "#94A3B8")).frame(width: 8, height: 8)
                        Text("先週")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(mutedColor)
                    }
                    if settingsManager.showAppEnglishMeaning {
                        Text("Last Week")
                            .font(.system(size: 9))
                            .foregroundColor(mutedColor.opacity(0.85))
                    }
                    Text("\(week.lastWeekTotal) 語")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(mutedColor)
                }

                Spacer()

                if week.lastWeekTotal > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("差分")
                            .font(.system(size: 10))
                            .foregroundColor(mutedColor)
                        if settingsManager.showAppEnglishMeaning {
                            Text("Diff")
                                .font(.system(size: 8))
                                .foregroundColor(mutedColor.opacity(0.85))
                        }
                        Text(String(format: "%+d 語", week.absoluteDiff))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(week.trend.color)
                    }
                }
            }

            if !hasAnyActivity {
                VStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 24))
                        .foregroundColor(mutedColor.opacity(0.5))
                    Text("今週・先週の復習データがありません。\n学習を継続すると週ごとの比較が表示されます。")
                        .font(.system(size: 11))
                        .foregroundColor(mutedColor)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(themeManager.segmentEmptyColor.opacity(0.20))
                .cornerRadius(8)
            } else {
                // Dual Line Chart Canvas
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let count = 7
                    let stepX = (w - 24) / CGFloat(count - 1)

                    ZStack {
                        // Horizontal divider guides
                        VStack(spacing: 0) {
                            Divider().background(themeManager.hairlineColor)
                            Spacer()
                            Divider().background(themeManager.hairlineColor)
                            Spacer()
                            Divider().background(themeManager.hairlineColor)
                        }

                        // Last Week Line (Slate Grey)
                        Path { path in
                            for i in 0..<count {
                                let x = 12 + CGFloat(i) * stepX
                                let val = (i < week.days.count) ? week.days[i].lastWeekCount : 0
                                let y = h - (CGFloat(val) / CGFloat(maxVal)) * (h - 16) - 8
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(Color(hex: "#94A3B8"), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round, dash: [4, 3]))

                        // This Week Line (Green)
                        Path { path in
                            for i in 0..<count {
                                let x = 12 + CGFloat(i) * stepX
                                let val = (i < week.days.count) ? week.days[i].thisWeekCount : 0
                                let y = h - (CGFloat(val) / CGFloat(maxVal)) * (h - 16) - 8
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(Color(hex: "#10B981"), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                        // Dots on This Week
                        ForEach(0..<count, id: \.self) { i in
                            let x = 12 + CGFloat(i) * stepX
                            let val = (i < week.days.count) ? week.days[i].thisWeekCount : 0
                            let y = h - (CGFloat(val) / CGFloat(maxVal)) * (h - 16) - 8
                            Circle()
                                .fill(Color(hex: "#10B981"))
                                .frame(width: 5, height: 5)
                                .position(x: x, y: y)
                        }
                    }
                }
                .frame(height: 110)

                // Days Labels (Mon to Sun)
                HStack {
                    ForEach(week.days) { d in
                        Text(d.dayName)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(mutedColor)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }

    // MARK: - Chart 3: Review Outcomes Breakdown (Bar Chart)
    private var reviewOutcomesCard: some View {
        let outcomes = stats.reviewOutcomes

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("評価結果の内訳")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(inkColor)

                    if settingsManager.showAppRomaji {
                        Text("Hyouka Kekka no Uchiwake")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(mutedColor)
                    }

                    if settingsManager.showAppEnglishMeaning {
                        Text("Review Outcomes Breakdown")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(mutedColor.opacity(0.85))
                    }

                    Text("全復習ログ（\(outcomes.total) 回）の自己評価分布")
                        .font(.system(size: 11))
                        .foregroundColor(mutedColor)
                }

                Spacer()
            }

            if outcomes.total == 0 {
                Text("復習ログがまだありません。")
                    .font(.system(size: 12))
                    .foregroundColor(mutedColor)
                    .padding(.vertical, 8)
            } else {
                // Stacked Bar
                GeometryReader { geo in
                    let w = geo.size.width
                    let againW = w * CGFloat(outcomes.againPercent / 100.0)
                    let hardW = w * CGFloat(outcomes.hardPercent / 100.0)
                    let goodW = w * CGFloat(outcomes.goodPercent / 100.0)
                    let easyW = w * CGFloat(outcomes.easyPercent / 100.0)

                    HStack(spacing: 2) {
                        if outcomes.againCount > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: "#EF4444"))
                                .frame(width: max(4, againW))
                        }
                        if outcomes.hardCount > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: "#F59E0B"))
                                .frame(width: max(4, hardW))
                        }
                        if outcomes.goodCount > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: "#10B981"))
                                .frame(width: max(4, goodW))
                        }
                        if outcomes.easyCount > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: "#3B82F6"))
                                .frame(width: max(4, easyW))
                        }
                    }
                }
                .frame(height: 12)

                // Breakdown Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    outcomeTile(title: "もう一度", romaji: "Mou Ichido", english: "Again", count: outcomes.againCount, percent: outcomes.againPercent, color: Color(hex: "#EF4444"))
                    outcomeTile(title: "難しい", romaji: "Muzukashii", english: "Hard", count: outcomes.hardCount, percent: outcomes.hardPercent, color: Color(hex: "#F59E0B"))
                    outcomeTile(title: "正解", romaji: "Seikai", english: "Good", count: outcomes.goodCount, percent: outcomes.goodPercent, color: Color(hex: "#10B981"))
                    outcomeTile(title: "簡単", romaji: "Kantan", english: "Easy", count: outcomes.easyCount, percent: outcomes.easyPercent, color: Color(hex: "#3B82F6"))
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func outcomeTile(title: String, romaji: String, english: String, count: Int, percent: Double, color: Color) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(inkColor)
                    .lineLimit(1)

                if settingsManager.showAppRomaji {
                    Text(romaji)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(mutedColor)
                        .lineLimit(1)
                }

                if settingsManager.showAppEnglishMeaning {
                    Text(english)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(mutedColor.opacity(0.85))
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text("\(count)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(inkColor)

                    Text(String(format: "(%.1f%%)", percent))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(color)
                }
            }
            Spacer()
        }
        .padding(8)
        .background(themeManager.segmentEmptyColor.opacity(0.30))
        .cornerRadius(6)
    }

    // MARK: - Chart 4: Daily Words & Goal Completion (Bar Chart)
    private var dailyGoalBarChartCard: some View {
        let days = stats.reviewsPerDay
        let maxVal = max(100, days.map(\.count).max() ?? 100)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("日別復習実績と目標達成")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(inkColor)

                    if settingsManager.showAppRomaji {
                        Text("Hibetsu Fukushuu Jisseki to Mokuhyou Tassei")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(mutedColor)
                    }

                    if settingsManager.showAppEnglishMeaning {
                        Text("Daily Reviews & Goal Completion")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(mutedColor.opacity(0.85))
                    }

                    Text("直近14日間の復習単語数と1日100語目標達成度")
                        .font(.system(size: 11))
                        .foregroundColor(mutedColor)
                }

                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(days) { day in
                        let isGoalMet = day.count >= 100
                        let barHeight = max(4, CGFloat(day.count) / CGFloat(maxVal) * 80.0)

                        VStack(spacing: 4) {
                            Text("\(day.count)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(isGoalMet ? Color(hex: "#10B981") : (day.count > 0 ? Color(hex: "#3B82F6") : mutedColor))

                            RoundedRectangle(cornerRadius: 3)
                                .fill(isGoalMet ? Color(hex: "#10B981") : (day.count > 0 ? Color(hex: "#3B82F6") : themeManager.segmentEmptyColor.opacity(0.40)))
                                .frame(width: 14, height: barHeight)

                            Text(day.dateString)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(mutedColor)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(height: 120)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}
