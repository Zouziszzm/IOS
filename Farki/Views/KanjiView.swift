import SwiftUI

struct KanjiView: View {
    @ObservedObject var viewModel: KanjiViewModel
    @ObservedObject var navVM: NavigationViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared

    private var inkColor: Color {
        themeManager.inkColor
    }

    private var mutedColor: Color {
        themeManager.mutedColor
    }

    private var canvasColor: Color {
        themeManager.canvasColor
    }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Section 1: Top Header Section (Timer, Test controls, Counter)
                    topHeaderSection
                        .padding(.top, 68)
                        .padding(.bottom, 16)

                    // Test Mode Banner
                    if viewModel.isTestModeActive {
                        testModeBanner
                            .padding(.bottom, 16)
                    }

                    // Section 2: Progress Section (Mastered count, percentage bar)
                    progressSection
                        .padding(.bottom, 14)

                    // Section 2.5: Mode Switcher Bar (Kanji Cards vs Breakdown vs Revision)
                    if !viewModel.isTestModeActive {
                        modeSwitcherBar
                            .padding(.bottom, 18)
                    }

                    // Section 3: Content based on active mode
                    if viewModel.isTestModeActive {
                        KanjiTestCardView(item: viewModel.currentTestKanji, viewModel: viewModel)
                            .padding(.bottom, 120)
                    } else if viewModel.selectedTabMode == .revision {
                        KanjiRevisionView(viewModel: viewModel)
                            .padding(.bottom, 120)
                    } else if viewModel.selectedTabMode == .breakdown {
                        KanjiChaptersBreakdownView(viewModel: viewModel)
                            .padding(.bottom, 120)
                    } else {
                        // Study Cards Mode:
                        // Collapsible Chapter Selector
                        CollapsibleKanjiChapterSelectorView(viewModel: viewModel)
                            .padding(.bottom, 14)

                        // Kanji Word Strip
                        if !viewModel.items.isEmpty {
                            KanjiWordStripView(viewModel: viewModel)
                                .padding(.bottom, 18)
                        }

                        // Active Kanji Detail Card
                        KanjiDetailCardView(item: viewModel.currentKanji, viewModel: viewModel)
                            .padding(.bottom, 120)
                    }
                }
                .padding(.horizontal, 24)
            }

            // Confetti Burst Overlay
            ConfettiBurstView(trigger: $viewModel.confettiTrigger)
                .ignoresSafeArea()
        }
    }

    // MARK: - Top Header Section
    @ViewBuilder
    private var topHeaderSection: some View {
        HStack(alignment: .center) {
            // Left: Timer
            Button {
                viewModel.toggleTimer()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isTimerPaused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(viewModel.isTimerPaused ? Color(hex: "#3B82F6") : inkColor)

                    Text(viewModel.formattedSessionTime)
                        .font(.english(size: 16, weight: .regular))
                        .foregroundColor(inkColor)
                        .opacity(viewModel.isTimerPaused ? 0.75 : 1.0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if viewModel.isTestModeActive {
                // Pause / Resume Button
                Button {
                    if viewModel.isTestPaused {
                        viewModel.resumeTest()
                    } else {
                        viewModel.pauseTest()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isTestPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 11))
                        Text(viewModel.isTestPaused ? "Resume" : "Pause")
                            .font(.english(size: 12, weight: .semibold))
                    }
                    .foregroundColor(viewModel.isTestPaused ? Color(hex: "#10B981") : Color(hex: "#F59E0B"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((viewModel.isTestPaused ? Color(hex: "#10B981") : Color(hex: "#F59E0B")).opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)

                // Stop / Exit Test Button
                Button {
                    viewModel.exitTest()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                        Text("Exit Test")
                            .font(.english(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "#EF4444"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#EF4444").opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }

            Spacer()

            // Right: Kanji Counter Badge
            HStack(spacing: 4) {
                let current = viewModel.isTestModeActive ? (viewModel.testCurrentIndex + 1) : (viewModel.currentIndex + 1)
                let total = viewModel.isTestModeActive ? viewModel.testItems.count : viewModel.totalChapterKanjiCount

                Text("\(current)")
                    .font(.english(size: 15, weight: .bold))
                    .foregroundColor(inkColor)

                Text("/ \(total) Kj")
                    .font(.english(size: 13, weight: .medium))
                    .foregroundColor(mutedColor)
            }
        }
    }

    // MARK: - Test Mode Active Banner
    @ViewBuilder
    private var testModeBanner: some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(viewModel.isTestPaused ? Color(hex: "#F59E0B") : Color(hex: "#3B82F6"))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.isTestPaused ? "KANJI TEST PAUSED" : "KANJI TEST IN PROGRESS")
                    .font(.english(size: 11, weight: .bold))
                    .foregroundColor(viewModel.isTestPaused ? Color(hex: "#F59E0B") : Color(hex: "#3B82F6"))
                    .tracking(0.6)

                Text("Chapter \(viewModel.selectedChapter) • Recall Meaning & Readings")
                    .font(.english(size: 12, weight: .regular))
                    .foregroundColor(inkColor)
            }

            Spacer()

            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text("\(viewModel.testCorrectCount)")
                        .font(.english(size: 12, weight: .bold))
                }
                .foregroundColor(Color(hex: "#10B981"))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(hex: "#10B981").opacity(0.12))
                .cornerRadius(4)

                HStack(spacing: 3) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                    Text("\(viewModel.testWrongCount)")
                        .font(.english(size: 12, weight: .bold))
                }
                .foregroundColor(Color(hex: "#EF4444"))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(hex: "#EF4444").opacity(0.12))
                .cornerRadius(4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background((viewModel.isTestPaused ? Color(hex: "#F59E0B") : Color(hex: "#3B82F6")).opacity(0.08))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke((viewModel.isTestPaused ? Color(hex: "#F59E0B") : Color(hex: "#3B82F6")).opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Progress Section
    @ViewBuilder
    private var progressSection: some View {
        let total = max(1, viewModel.totalChapterKanjiCount)
        let mastered = viewModel.masteredChapterKanjiCount
        let progress = Double(mastered) / Double(total)
        let pct = Int(round(progress * 100))

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(mastered)/\(total) Mastered")
                    .font(.english(size: 13, weight: .bold))
                    .foregroundColor(inkColor)

                Spacer()

                Text("\(pct)%")
                    .font(.english(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "#10B981"))
            }

            // Progress Bar
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(themeManager.segmentEmptyColor)
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "#10B981"))
                        .frame(width: w * CGFloat(progress), height: 5)
                }
            }
            .frame(height: 5)
        }
    }

    // MARK: - Mode Switcher Bar
    @ViewBuilder
    private var modeSwitcherBar: some View {
        HStack(spacing: 6) {
            ForEach(KanjiTabMode.allCases) { mode in
                let isSelected = (viewModel.selectedTabMode == mode)

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        viewModel.selectedTabMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.english(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? inkColor : mutedColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(isSelected ? themeManager.hairlineColor.opacity(1.5) : Color.clear)
                        .cornerRadius(7)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(themeManager.activeTheme == .dark ? Color(hex: "#181614") : Color(hex: "#F5F5F4"))
        .cornerRadius(9)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(themeManager.hairlineColor, lineWidth: 1)
        )
    }
}

