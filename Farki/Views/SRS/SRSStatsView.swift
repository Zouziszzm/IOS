import SwiftUI

struct SRSStatsView: View {
    @ObservedObject var viewModel: SRSViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var settingsManager = AppSettingsManager.shared

    private var inkColor: Color { themeManager.inkColor }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.canvasColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Scope Header Banner
                        scopeHeader

                        if let stats = viewModel.scopeStats {
                            // Primary Metrics Cards Grid
                            metricsGrid(stats: stats)

                            // Collapsible GitHub-Style Streaks & Activity Grid
                            StreaksActivityGridView(streakStats: stats.streakStats)

                            // Visual Progress Charts & Comparisons (Actual vs Ideal, This Week vs Last Week, Outcomes)
                            SRSProgressChartsView(stats: stats)

                            // 30-Day Retention Card
                            retentionCard(stats: stats)

                            // 7-Day Due Forecast Chart
                            forecastCard(stats: stats)
                        } else {
                            ProgressView()
                                .padding(.top, 40)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("統計・進捗")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(inkColor)

                        if settingsManager.showAppRomaji {
                            Text("Toukei • Shincho")
                                .font(.system(size: 9, weight: .regular, design: .monospaced))
                                .foregroundColor(themeManager.mutedColor)
                        }

                        if settingsManager.showAppEnglishMeaning {
                            Text("SRS Statistics")
                                .font(.system(size: 9, weight: .regular, design: .monospaced))
                                .foregroundColor(themeManager.mutedColor.opacity(0.85))
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                }
            }
        }
    }

    // MARK: - Scope Header
    private var scopeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("現在の学習範囲")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(inkColor)

                if settingsManager.showAppRomaji {
                    Text("Genzai no Gakushuu Hani")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(themeManager.mutedColor)
                }

                if settingsManager.showAppEnglishMeaning {
                    Text("Current Study Scope")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(themeManager.mutedColor.opacity(0.85))
                }

                Text(viewModel.activeScope.displayName)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#3B82F6"))
                    .padding(.top, 2)
            }

            Spacer()

            Button(action: {
                viewModel.isScopePickerPresented = true
            }) {
                Text("範囲変更")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#3B82F6"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#3B82F6").opacity(0.12))
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(themeManager.colorScheme == .dark ? Color(hex: "#1E222B") : Color.white)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Metrics Grid
    private func metricsGrid(stats: SRSScopeStats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            // Mastered
            statMetricTile(
                title: "習得済み",
                romaji: "Shuutoku-zumi",
                english: "Mastered",
                value: "\(stats.masteredCount)",
                subtitle: String(format: "%.1f%% of scope (≥21d)", stats.masteredPercent),
                color: Color(hex: "#10B981"),
                icon: "checkmark.seal.fill"
            )

            // Due Today
            statMetricTile(
                title: "本日の復習",
                romaji: "Honjitsu no Fukushuu",
                english: "Due Today",
                value: "\(stats.dueCount)",
                subtitle: "Cards ready to review",
                color: Color(hex: "#3B82F6"),
                icon: "clock.badge.checkmark.fill"
            )

            // Learning
            statMetricTile(
                title: "学習中",
                romaji: "Gakushuu-chuu",
                english: "Learning",
                value: "\(stats.learningCount)",
                subtitle: "In short learning steps",
                color: Color(hex: "#F59E0B"),
                icon: "flame.fill"
            )

            // New Cards
            statMetricTile(
                title: "未習得",
                romaji: "Mi-shuutoku",
                english: "New Cards",
                value: "\(stats.newCount)",
                subtitle: "Waiting to be introduced",
                color: Color(hex: "#8B5CF6"),
                icon: "sparkles"
            )
        }
        .padding(.horizontal, 16)
    }

    private func statMetricTile(title: String, romaji: String, english: String, value: String, subtitle: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 14))

                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(inkColor)
                    .lineLimit(1)
            }

            if settingsManager.showAppRomaji {
                Text(romaji)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(themeManager.mutedColor)
                    .lineLimit(1)
            }

            if settingsManager.showAppEnglishMeaning {
                Text(english)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(themeManager.mutedColor.opacity(0.85))
                    .lineLimit(1)
            }

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .foregroundColor(inkColor)
                .padding(.top, 2)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(themeManager.mutedColor)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(themeManager.colorScheme == .dark ? Color(hex: "#1E222B") : Color.white)
        )
    }

    // MARK: - Retention Rate Card
    private func retentionCard(stats: SRSScopeStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("過去30日間の記憶定着率")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(inkColor)

                    if settingsManager.showAppRomaji {
                        Text("Kako 30-kakan no Kioku Teichaku-ritsu")
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundColor(themeManager.mutedColor)
                    }

                    if settingsManager.showAppEnglishMeaning {
                        Text("30-Day Retention Rate")
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundColor(themeManager.mutedColor.opacity(0.85))
                    }
                }

                Spacer()

                if let rate = stats.retentionRate30Days {
                    Text(String(format: "%.1f%%", rate))
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(rate >= 80 ? Color(hex: "#10B981") : Color(hex: "#F59E0B"))
                } else {
                    Text("記録なし")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }

            if let rate = stats.retentionRate30Days {
                // Retention progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.18))
                            .frame(height: 10)

                        Capsule()
                            .fill(LinearGradient(colors: [Color(hex: "#3B82F6"), Color(hex: "#10B981")], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(rate / 100.0))), height: 10)
                    }
                }
                .frame(height: 10)

                Text("\(stats.successfulReviews30Days) / \(stats.totalReviews30Days) 回の復習で正解（GoodまたはEasy）")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            } else {
                Text("過去30日間の復習記録がありません。学習を開始すると定着率が集計されます。")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(themeManager.colorScheme == .dark ? Color(hex: "#1E222B") : Color.white)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - 7-Day Forecast Card
    private func forecastCard(stats: SRSScopeStats) -> some View {
        let maxCount = max(1, stats.forecast7Days.map(\.count).max() ?? 1)

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("7日間の復習予測")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(inkColor)

                if settingsManager.showAppRomaji {
                    Text("7-kakan no Fukushuu Yosoku")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(themeManager.mutedColor)
                }

                if settingsManager.showAppEnglishMeaning {
                    Text("7-Day Review Forecast")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(themeManager.mutedColor.opacity(0.85))
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(stats.forecast7Days) { day in
                    VStack(spacing: 6) {
                        Text("\(day.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(day.count > 0 ? Color(hex: "#3B82F6") : .gray)

                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(day.dayOffset == 0 ? Color(hex: "#3B82F6") : Color(hex: "#60A5FA").opacity(0.7))
                            .frame(height: max(6, CGFloat(day.count) / CGFloat(maxCount) * 70.0))

                        Text(day.label)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 110)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(themeManager.colorScheme == .dark ? Color(hex: "#1E222B") : Color.white)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Reviews Per Day Activity Card
    private func reviewsActivityCard(stats: SRSScopeStats) -> some View {
        let maxActivity = max(1, stats.reviewsPerDay.map(\.count).max() ?? 1)

        return VStack(alignment: .leading, spacing: 14) {
            Text("最近14日間の復習実績 (Review Activity)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(inkColor)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(stats.reviewsPerDay) { day in
                        VStack(spacing: 4) {
                            Text("\(day.count)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(day.count > 0 ? Color(hex: "#10B981") : .gray)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(day.count > 0 ? Color(hex: "#10B981") : Color.gray.opacity(0.15))
                                .frame(width: 16, height: max(4, CGFloat(day.count) / CGFloat(maxActivity) * 60.0))

                            Text(day.dateString)
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(themeManager.colorScheme == .dark ? Color(hex: "#1E222B") : Color.white)
        )
        .padding(.horizontal, 16)
    }
}
