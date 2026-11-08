import SwiftUI

/// Collapsible GitHub-Style Daily Activity Grid & Streaks Component
struct StreaksActivityGridView: View {
    let streakStats: StreakStats
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared
    @ObservedObject var settingsManager: AppSettingsManager = AppSettingsManager.shared

    @State private var isExpanded: Bool = true
    @State private var selectedRecord: DailyStreakRecord? = nil

    private var inkColor: Color { themeManager.inkColor }
    private var mutedColor: Color { themeManager.mutedColor }
    private var canvasColor: Color { themeManager.canvasColor }
    private var cardBackground: Color {
        themeManager.activeTheme == .dark ? Color(hex: "#1E222B") : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsible Header
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    // Full-width title without wrap
                    HStack(alignment: .center) {
                        Text("連続学習・アクティビティ")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(inkColor)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(mutedColor)
                    }

                    // Romaji below title
                    if settingsManager.showAppRomaji {
                        Text("Renzoku Gakushuu • Akutibiti")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(mutedColor)
                            .lineLimit(1)
                    }

                    // English below title
                    if settingsManager.showAppEnglishMeaning {
                        Text("Streaks & Daily Activity")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(mutedColor.opacity(0.85))
                            .lineLimit(1)
                    }

                    // Below title: Streak & Cup icons with text (NO card UI)
                    HStack(spacing: 20) {
                        // Current Streak (Fire)
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 14))
                                .foregroundColor(streakStats.currentStreak > 0 ? Color(hex: "#F59E0B") : mutedColor)

                            Text("\(streakStats.currentStreak)日")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(inkColor)
                        }

                        // Longest Streak (Cup)
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 13))
                                .foregroundColor(streakStats.longestStreak > 0 ? Color(hex: "#EAB308") : mutedColor)

                            Text("最長 \(streakStats.longestStreak)日")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(mutedColor)
                        }
                    }
                    .padding(.top, 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Collapsible Content (Directly on canvas - NO CARD UI)
            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    // Contribution Graph
                    activityGridSection
                        .padding(.top, 10)

                    // Legend
                    activityLegendSection

                    // Selected Day Detail (Clean, minimal)
                    if let selected = selectedRecord {
                        selectedDayDetailCard(selected)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Activity Grid Section
    private var activityGridSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 6) {
                    // Weekday Labels on Left (Mon, Wed, Fri, Sun)
                    VStack(spacing: 3) {
                        weekdayLabel("月")
                        weekdayLabel("")
                        weekdayLabel("水")
                        weekdayLabel("")
                        weekdayLabel("金")
                        weekdayLabel("")
                        weekdayLabel("日")
                    }
                    .padding(.top, 2)

                    // Columns of Weeks (16 weeks x 7 days)
                    HStack(spacing: 3) {
                        ForEach(0..<streakStats.gridWeeks.count, id: \.self) { weekIndex in
                            let week = streakStats.gridWeeks[weekIndex]
                            VStack(spacing: 3) {
                                ForEach(week) { record in
                                    dayBlockView(record)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
        }
    }

    @ViewBuilder
    private func weekdayLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(mutedColor.opacity(0.75))
            .frame(width: 14, height: 13, alignment: .center)
    }

    // MARK: - Day Block View (Illuminated vs Cracked)
    @ViewBuilder
    private func dayBlockView(_ record: DailyStreakRecord) -> some View {
        let isSelected = (selectedRecord?.dateString == record.dateString)

        if record.isBeforeStart {
            // Days prior to Oct 24 are empty transparent cells
            Color.clear
                .frame(width: 13, height: 13)
        } else {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    if selectedRecord?.dateString == record.dateString {
                        selectedRecord = nil
                    } else {
                        selectedRecord = record
                    }
                }
            } label: {
                ZStack {
                    if record.isFuture {
                        if record.isExamDay {
                            ZStack {
                                RoundedRectangle(cornerRadius: 2.5)
                                    .stroke(Color(hex: "#F59E0B"), lineWidth: 1.0)
                                    .frame(width: 13, height: 13)
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(Color(hex: "#F59E0B"))
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 2.5)
                                .stroke(mutedColor.opacity(0.12), lineWidth: 0.5)
                                .frame(width: 13, height: 13)
                        }
                    } else if record.activityLevel == .noPractice {
                        // Distinctive Cracked Block Appearance for days with 0 practice
                        ZStack {
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(themeManager.segmentEmptyColor.opacity(0.40))

                            // Cracked fracture lines
                            CrackedBlockShape()
                                .stroke(mutedColor.opacity(0.50), lineWidth: 0.8)

                            RoundedRectangle(cornerRadius: 2.5)
                                .stroke(mutedColor.opacity(0.30), lineWidth: 0.5)
                        }
                        .frame(width: 13, height: 13)
                    } else {
                        // Illuminated Block
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(record.activityLevel.color)
                            .frame(width: 13, height: 13)
                    }

                    // Selected or Today Highlight Border
                    if isSelected {
                        RoundedRectangle(cornerRadius: 2.5)
                            .stroke(inkColor, lineWidth: 1.5)
                            .frame(width: 13, height: 13)
                    } else if record.isToday {
                        RoundedRectangle(cornerRadius: 2.5)
                            .stroke(Color(hex: "#3B82F6"), lineWidth: 1.0)
                            .frame(width: 13, height: 13)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Activity Legend Section
    private var activityLegendSection: some View {
        HStack(spacing: 12) {
            Text("達成度:")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(mutedColor)

            // Cracked (0 words)
            HStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(themeManager.segmentEmptyColor.opacity(0.40))
                        .frame(width: 10, height: 10)
                    CrackedBlockShape()
                        .stroke(mutedColor.opacity(0.55), lineWidth: 0.6)
                        .frame(width: 10, height: 10)
                }
                Text("0語 (未習)")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(mutedColor)
            }

            // Red (1-29 words)
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "#EF4444"))
                    .frame(width: 10, height: 10)
                Text("1–29語")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(mutedColor)
            }

            // Orange (30-99 words)
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "#F59E0B"))
                    .frame(width: 10, height: 10)
                Text("30–99語")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(mutedColor)
            }

            // Green (100+ words)
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "#10B981"))
                    .frame(width: 10, height: 10)
                Text("100+語 (達成)")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(mutedColor)
            }

            Spacer()
        }
        .padding(.top, 2)
    }

    // MARK: - Selected Day Detail Card
    @ViewBuilder
    private func selectedDayDetailCard(_ record: DailyStreakRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(record.dateString) (\(record.weekdayString))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(inkColor)

                    Text(record.activityLevel.label)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(record.activityLevel == .noPractice ? mutedColor : record.activityLevel.color)
                }

                Spacer()

                if record.wordsReviewed >= 100 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                        Text("Goal Met")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(Color(hex: "#10B981"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#10B981").opacity(0.12))
                    .cornerRadius(4)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("学習単語数")
                        .font(.system(size: 10))
                        .foregroundColor(mutedColor)
                    Text("\(record.wordsReviewed) 語")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(inkColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("総復習回数")
                        .font(.system(size: 10))
                        .foregroundColor(mutedColor)
                    Text("\(record.totalReviews) 回")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(inkColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("該当課")
                        .font(.system(size: 10))
                        .foregroundColor(mutedColor)
                    if record.chaptersTouched.isEmpty {
                        Text("—")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(mutedColor)
                    } else {
                        Text(record.chaptersTouched.map { "第\($0)課" }.joined(separator: ", "))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#3B82F6"))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(12)
        .background(themeManager.segmentEmptyColor.opacity(0.35))
        .cornerRadius(10)
    }
}

// MARK: - Custom Cracked Fracture Shape
struct CrackedBlockShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Main diagonal jagged crack
        path.move(to: CGPoint(x: w * 0.30, y: 0))
        path.addLine(to: CGPoint(x: w * 0.45, y: h * 0.35))
        path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.60))
        path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.82))
        path.addLine(to: CGPoint(x: w * 0.50, y: h))

        // Lateral branch crack
        path.move(to: CGPoint(x: w * 0.45, y: h * 0.35))
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.42))

        return path
    }
}
