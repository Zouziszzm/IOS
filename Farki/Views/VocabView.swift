import SwiftUI

struct VocabView: View {
    @ObservedObject var viewModel: VocabViewModel
    @ObservedObject var navVM: NavigationViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared
    @ObservedObject var settingsManager: AppSettingsManager = AppSettingsManager.shared

    @State private var isPresetsExpanded: Bool = true
    @State private var isSectionsExpanded: Bool = true
    @State private var isRangeExpanded: Bool = false
    @State private var isBook1Expanded: Bool = true
    @State private var isBook2Expanded: Bool = false

    private var inkColor: Color {
        themeManager.inkColor
    }

    private var mutedColor: Color {
        themeManager.mutedColor
    }

    private var canvasColor: Color {
        themeManager.canvasColor
    }

    private var activeWord: VocabItem {
        viewModel.currentWord
    }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Section 1: Top Section (Timer, Stop button beside timer, Word Number, Total Count)
                    // Padded comfortably at top so timer never touches or overlaps the pinned logo
                    topHeaderSection
                        .padding(.top, 68)
                        .padding(.bottom, 16)

                    // Test Mode Active Banner or Paused Test Resume Banner
                    if viewModel.isTestModeActive {
                        testModeBanner
                            .padding(.bottom, 16)
                    } else if viewModel.hasSavedPausedTest {
                        pausedTestBanner
                            .padding(.bottom, 16)
                    }

                    // Section 2: Progress Section (Completed count, percentage, segmented bar)
                    progressSection
                        .padding(.bottom, 14)

                    // Section 2.5: Mode Switcher (Study Cards vs Chapters & Sections vs Revision)
                    if !viewModel.isTestModeActive {
                        vocabModeBar
                            .padding(.bottom, 18)
                    }

                    if viewModel.selectedTabMode == .revision && !viewModel.isTestModeActive {
                        VocabRevisionView(viewModel: viewModel)
                            .padding(.bottom, 120)
                    } else if (viewModel.selectedTabMode == .chapters || viewModel.isShowingChapterSectionScreen) && !viewModel.isTestModeActive {
                        chaptersAndSectionsScreen
                            .padding(.bottom, 120)
                    } else {
                        // Section 2.7: Collapsible Chapters and Sections Control immediately above vocabulary grid
                        CollapsibleChapterSelectorView(viewModel: viewModel)
                            .padding(.bottom, 14)

                        // Section 3: Word Strip
                        if !viewModel.items.isEmpty {
                            VocabWordStripView(viewModel: viewModel)
                                .padding(.bottom, 22)
                        }

                        // Section 4 & 5: Word Details, Flippable Card & Pure Vocab Details
                        wordDetailsSection
                            .padding(.bottom, 120) // Space above bottom menu
                    }
                }
                .padding(.horizontal, 24)
            }

            // Twin cannon confetti burst overlay shooting from each side
            ConfettiBurstView(trigger: $viewModel.confettiTrigger)
                .ignoresSafeArea()
        }
    }

    // MARK: - Section 1: Top Section
    @ViewBuilder
    private var topHeaderSection: some View {
        HStack(alignment: .center) {
            // Left: Timer (Clickable to start/pause/resume, starts from 00:00 paused)
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
                            .font(.system(size: 10))

                        Text(viewModel.isTestPaused ? "Resume" : "Pause")
                            .font(.english(size: 12, weight: .medium))
                    }
                    .foregroundColor(viewModel.isTestPaused ? Color(hex: "#10B981") : Color(hex: "#F59E0B"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((viewModel.isTestPaused ? Color(hex: "#10B981") : Color(hex: "#F59E0B")).opacity(0.12))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)

                // Stop Button
                Button {
                    viewModel.stopTest()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))

                        Text("Stop")
                            .font(.english(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#EF4444"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#EF4444").opacity(0.12))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            } else {
                // Button beside the timer to reset to first card
                Button {
                    viewModel.resetToFirstCard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10))

                        Text("Reset")
                            .font(.english(size: 12, weight: .medium))
                    }
                    .foregroundColor(mutedColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeManager.segmentEmptyColor.opacity(0.5))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Right: Back button to Dashboard + Active word number & Total count
            VStack(alignment: .trailing, spacing: 3) {
                // Top Right Back button to Dashboard
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    navVM.navigateToMenuDestination(.dashboard)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Dashboard")
                            .font(.english(size: 11, weight: .medium))
                    }
                    .foregroundColor(mutedColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(themeManager.segmentEmptyColor.opacity(0.45))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 2)

                HStack(spacing: 8) {
                    Button {
                        viewModel.cycleActiveWordStatus()
                    } label: {
                        Rectangle()
                            .fill(viewModel.statusColor(for: activeWord))
                            .frame(width: 10, height: 10)
                    }
                    .buttonStyle(.plain)

                    Text("\(viewModel.isTestModeActive ? (viewModel.currentIndex + 1) : (viewModel.items.isEmpty ? 0 : (activeWord.number > 0 ? activeWord.number : viewModel.currentIndex + 1)))")
                        .font(.english(size: 32, weight: .bold))
                        .foregroundColor(inkColor)
                }

                Text("/\(viewModel.isTestModeActive ? viewModel.testTotalQuestions : viewModel.totalWordCount)")
                    .font(.english(size: 18, weight: .regular))
                    .foregroundColor(mutedColor)
            }
        }
    }

    // MARK: - Test Mode Active Banner
    @ViewBuilder
    private var testModeBanner: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isTestPaused ? Color(hex: "#F59E0B") : Color(hex: "#3B82F6"))
                    .frame(width: 7, height: 7)

                Text(viewModel.isTestPaused ? "Paused: \(viewModel.testScopeTitle)" : "Testing: \(viewModel.testScopeTitle)")
                    .font(.english(size: 13, weight: .bold))
                    .foregroundColor(viewModel.isTestPaused ? Color(hex: "#F59E0B") : Color(hex: "#3B82F6"))
            }

            Spacer()

            if viewModel.isTestPaused {
                Button {
                    viewModel.resumeTest()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Resume")
                            .font(.english(size: 12, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "#10B981"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#10B981").opacity(0.15))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            } else {
                Text("Correct: \(viewModel.testCorrectCount)  Wrong: \(viewModel.testWrongCount)")
                    .font(.english(size: 12))
                    .foregroundColor(mutedColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background((viewModel.isTestPaused ? Color(hex: "#F59E0B") : Color(hex: "#3B82F6")).opacity(0.08))
        .cornerRadius(8)
    }

    // MARK: - Paused Test Resume Banner (Requirement 2.4)
    @ViewBuilder
    private var pausedTestBanner: some View {
        if let session = viewModel.savedPausedSession {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#F59E0B"))

                        Text("UNFINISHED TEST PAUSED")
                            .font(.english(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#F59E0B"))
                            .tracking(0.5)
                    }

                    Text("\(session.scopeTitle) • Question \(session.currentIndex + 1) of \(session.totalQuestions) (\(session.submittedAnswers.count) answered)")
                        .font(.english(size: 13, weight: .medium))
                        .foregroundColor(inkColor)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        viewModel.resumeTest()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text("Resume")
                                .font(.english(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#3B82F6"))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.discardPausedTest()
                    } label: {
                        Text("Discard")
                            .font(.english(size: 12, weight: .medium))
                            .foregroundColor(mutedColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(hex: "#F59E0B").opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(hex: "#F59E0B").opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(10)
        }
    }

    // MARK: - Section 2: Progress Section
    @ViewBuilder
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.isTestModeActive ? "Test Progress" : "Vocab")
                        .font(.english(size: 15, weight: .regular))
                        .foregroundColor(inkColor)

                    Text(viewModel.isTestModeActive ? "Answered \(viewModel.testCorrectCount + viewModel.testWrongCount)/\(viewModel.totalWordCount) words" : "You completed \(viewModel.completedWordCount)/\(viewModel.totalWordCount) words")
                        .font(.english(size: 12, weight: .regular))
                        .foregroundColor(mutedColor)
                }

                Spacer()

                Text("\(viewModel.displayPercentage)%")
                    .font(.english(size: 26, weight: .bold))
                    .foregroundColor(mutedColor)
            }

            SegmentedProgressBar(
                progress: viewModel.totalWordCount > 0 ? (Double(viewModel.completedWordCount) / Double(viewModel.totalWordCount)) : 0.0,
                totalSegments: 30,
                height: 34
            )
        }
    }

    // MARK: - Section 2.5: Mode Switcher (Study Cards vs Chapters & Sections vs Revision)
    @ViewBuilder
    private var vocabModeBar: some View {
        HStack(spacing: 8) {
            modeBarButton(mode: .study, title: "Study Cards", icon: "rectangle.stack.fill")
            modeBarButton(mode: .chapters, title: "Chapters & Sections", icon: "slider.horizontal.3")
            modeBarButton(mode: .revision, title: "Revision", icon: "arrow.triangle.2.circlepath")
        }
    }

    @ViewBuilder
    private func modeBarButton(mode: VocabTabMode, title: String, icon: String) -> some View {
        let isSelected = viewModel.selectedTabMode == mode
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                viewModel.selectedTabMode = mode
                viewModel.isShowingChapterSectionScreen = (mode == .chapters)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.english(size: 12, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(isSelected ? canvasColor : inkColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(isSelected ? inkColor : themeManager.segmentEmptyColor.opacity(0.45))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dedicated Chapters & Sections Selection Screen
    @ViewBuilder
    private var chaptersAndSectionsScreen: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 1. Active Selection Summary Banner + CTA Buttons
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CURRENT SELECTION")
                            .font(.english(size: 10, weight: .bold))
                            .foregroundColor(mutedColor)
                            .tracking(0.8)

                        Text(viewModel.filter.summaryText)
                            .font(.english(size: 16, weight: .bold))
                            .foregroundColor(inkColor)

                        Text("\(viewModel.totalWordCount) words matched • \(viewModel.completedWordCount) studied")
                            .font(.english(size: 12, weight: .regular))
                            .foregroundColor(mutedColor)
                    }

                    Spacer()

                    if viewModel.filter.isFiltering {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            viewModel.clearFilter()
                        } label: {
                            Text("Reset All")
                                .font(.english(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#EF4444"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(hex: "#EF4444").opacity(0.12))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            viewModel.selectedTabMode = .study
                            viewModel.isShowingChapterSectionScreen = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 12))
                            Text("Study (\(viewModel.totalWordCount))")
                                .font(.english(size: 13, weight: .bold))
                        }
                        .foregroundColor(canvasColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(inkColor)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.startTestFromCurrentFilter()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                            Text("Test Selected")
                                .font(.english(size: 13, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "#3B82F6"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#3B82F6").opacity(0.14))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(themeManager.segmentEmptyColor.opacity(0.35))
            .cornerRadius(12)

            // 2. Quick Chapter Presets
            VStack(alignment: .leading, spacing: 10) {
                Text("QUICK CHAPTER PRESETS")
                    .font(.english(size: 11, weight: .bold))
                    .foregroundColor(mutedColor)
                    .tracking(0.6)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        presetChip(
                            title: "All (1–50)",
                            isSelected: viewModel.isAllChaptersSelected
                        ) {
                            viewModel.selectAllChapters()
                        }

                        presetChip(
                            title: "JLPT N5 (Ch. 1–25)",
                            isSelected: viewModel.filter.selectedChapters == Set(1...25)
                        ) {
                            viewModel.selectChapterRange(1...25)
                        }

                        presetChip(
                            title: "JLPT N4 (Ch. 26–50)",
                            isSelected: viewModel.filter.selectedChapters == Set(26...50)
                        ) {
                            viewModel.selectChapterRange(26...50)
                        }

                        presetChip(
                            title: "Ch. 1–10",
                            isSelected: viewModel.filter.selectedChapters == Set(1...10)
                        ) {
                            viewModel.selectChapterRange(1...10)
                        }

                        presetChip(
                            title: "Ch. 11–25",
                            isSelected: viewModel.filter.selectedChapters == Set(11...25)
                        ) {
                            viewModel.selectChapterRange(11...25)
                        }

                        presetChip(
                            title: "Ch. 26–38",
                            isSelected: viewModel.filter.selectedChapters == Set(26...38)
                        ) {
                            viewModel.selectChapterRange(26...38)
                        }

                        presetChip(
                            title: "Ch. 39–50",
                            isSelected: viewModel.filter.selectedChapters == Set(39...50)
                        ) {
                            viewModel.selectChapterRange(39...50)
                        }
                    }
                }
            }

            // 3. Vocabulary Sections (Word Types & Trouble Filter)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("VOCABULARY SECTIONS (WORD TYPES)")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)
                        .tracking(0.6)

                    Spacer()

                    if !viewModel.filter.selectedSectionCategories.isEmpty || viewModel.filter.troubleWordsOnly {
                        Button {
                            viewModel.clearSectionCategories()
                            if viewModel.filter.troubleWordsOnly {
                                viewModel.toggleTroubleWordsOnly()
                            }
                        } label: {
                            Text("All Sections")
                                .font(.english(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "#3B82F6"))
                        }
                        .buttonStyle(.plain)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(VocabSectionCategory.allCases, id: \.self) { section in
                        let isSelected = viewModel.filter.selectedSectionCategories.contains(section)
                        let count = viewModel.wordCount(forSection: section)
                        Button {
                            viewModel.toggleSectionCategory(section)
                        } label: {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(section.title)
                                        .font(.english(size: 13, weight: .bold))
                                        .foregroundColor(isSelected ? canvasColor : inkColor)
                                        .lineLimit(1)

                                    Text("\(count) words")
                                        .font(.english(size: 11, weight: .regular))
                                        .foregroundColor(isSelected ? canvasColor.opacity(0.8) : mutedColor)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(canvasColor)
                                }
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 9)
                            .background(isSelected ? inkColor : themeManager.segmentEmptyColor.opacity(0.4))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }

                    // Trouble / Hard Words section card
                    let troubleSelected = viewModel.filter.troubleWordsOnly
                    let troubleCount = viewModel.troubleWordCountInSelectedChapters
                    Button {
                        viewModel.toggleTroubleWordsOnly()
                    } label: {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Trouble Words")
                                    .font(.english(size: 13, weight: .bold))
                                    .foregroundColor(troubleSelected ? .white : Color(hex: "#EF4444"))
                                    .lineLimit(1)

                                Text("苦手・復習 • \(troubleCount)")
                                    .font(.japanese(size: 11, weight: .regular))
                                    .foregroundColor(troubleSelected ? .white.opacity(0.85) : mutedColor)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: troubleSelected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(troubleSelected ? .white : Color(hex: "#EF4444"))
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 9)
                        .background(troubleSelected ? Color(hex: "#EF4444") : Color(hex: "#EF4444").opacity(0.12))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 4. Custom Chapter Range Selector
            VStack(alignment: .leading, spacing: 10) {
                Text("CUSTOM CHAPTER RANGE")
                    .font(.english(size: 11, weight: .bold))
                    .foregroundColor(mutedColor)
                    .tracking(0.6)

                HStack(spacing: 10) {
                    Menu {
                        Picker("From Chapter", selection: $viewModel.rangeStartChapter) {
                            ForEach(1...50, id: \.self) { ch in
                                Text("Chapter \(ch)").tag(ch)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("From")
                                .font(.english(size: 12, weight: .medium))
                                .foregroundColor(mutedColor)
                            Text("Ch. \(viewModel.rangeStartChapter)")
                                .font(.english(size: 12, weight: .bold))
                                .foregroundColor(inkColor)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(mutedColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(themeManager.segmentEmptyColor.opacity(0.45))
                        .cornerRadius(8)
                    }

                    Menu {
                        Picker("To Chapter", selection: $viewModel.rangeEndChapter) {
                            ForEach(1...50, id: \.self) { ch in
                                Text("Chapter \(ch)").tag(ch)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("To")
                                .font(.english(size: 12, weight: .medium))
                                .foregroundColor(mutedColor)
                            Text("Ch. \(viewModel.rangeEndChapter)")
                                .font(.english(size: 12, weight: .bold))
                                .foregroundColor(inkColor)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(mutedColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(themeManager.segmentEmptyColor.opacity(0.45))
                        .cornerRadius(8)
                    }

                    Spacer()

                    Button {
                        viewModel.applyCustomChapterRange()
                    } label: {
                        Text("Select Range")
                            .font(.english(size: 12, weight: .bold))
                            .foregroundColor(canvasColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(inkColor)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 5. Custom Multi-Chapter Grid: JLPT N5 (Ch. 1–25) & JLPT N4 (Ch. 26–50)
            chapterBookGridSection(
                title: "JLPT N5 • MINNA NO NIHONGO I (CH. 1–25)",
                badgeColor: Color(hex: "#10B981"),
                chapters: Array(1...25),
                isExpanded: $isBook1Expanded
            )

            chapterBookGridSection(
                title: "JLPT N4 • MINNA NO NIHONGO II (CH. 26–50)",
                badgeColor: Color(hex: "#3B82F6"),
                chapters: Array(26...50),
                isExpanded: $isBook2Expanded
            )
        }
    }

    @ViewBuilder
    private func presetChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.english(size: 12, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? canvasColor : inkColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? inkColor : themeManager.segmentEmptyColor.opacity(0.45))
                .cornerRadius(7)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func chapterBookGridSection(
        title: String,
        badgeColor: Color,
        chapters: [Int],
        isExpanded: Binding<Bool>
    ) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
        VStack(alignment: .leading, spacing: 10) {
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack {
                    Circle()
                        .fill(badgeColor)
                        .frame(width: 7, height: 7)
                    Text(title)
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)
                        .tracking(0.5)

                    Spacer()

                    Text(isExpanded.wrappedValue ? "Collapse" : "Expand")
                        .font(.english(size: 10, weight: .regular))
                        .foregroundColor(mutedColor.opacity(0.8))

                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(mutedColor)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(chapters, id: \.self) { ch in
                        let isSelected = viewModel.isChapterSelected(ch)
                        let count = viewModel.wordCount(forChapter: ch)
                        Button {
                            viewModel.selectSingleChapter(ch)
                        } label: {
                            VStack(spacing: 2) {
                                Text("Ch.\(ch)")
                                    .font(.english(size: 13, weight: .bold))
                                    .foregroundColor(isSelected ? canvasColor : inkColor)

                                Text("\(count)w")
                                    .font(.english(size: 10, weight: .regular))
                                    .foregroundColor(isSelected ? canvasColor.opacity(0.8) : mutedColor)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isSelected ? inkColor : themeManager.segmentEmptyColor.opacity(0.38))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Section 4 & 5: Word Details & Card Flip (Pure Vocabulary)
    @ViewBuilder
    private var wordDetailsSection: some View {
        if viewModel.items.isEmpty {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 38))
                        .foregroundColor(mutedColor.opacity(0.7))

                    Text("No Vocabulary Found")
                        .font(.english(size: 20, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("No words available for this selection.\nImport or select other chapters.")
                        .font(.english(size: 13, weight: .regular))
                        .foregroundColor(mutedColor)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 36)
                .frame(maxWidth: .infinity)
                .background(themeManager.segmentEmptyColor.opacity(0.35))
                .cornerRadius(12)
            }
            .padding(.top, 10)
        } else {
            VStack(alignment: .leading, spacing: 18) {
                // Word category tag & Best Streak
                HStack(alignment: .firstTextBaseline) {
                    Text(activeWord.categoryTag)
                        .font(.japanese(size: 14, weight: .regular))
                        .foregroundColor(inkColor)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Best")
                            .font(.english(size: 11, weight: .regular))
                            .foregroundColor(mutedColor)

                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "#F59E0B"))

                            Text("\(activeWord.bestStreak)")
                                .font(.english(size: 15, weight: .bold))
                                .foregroundColor(inkColor)
                        }
                    }
                }

                // Flippable Vocabulary Card (Pure Vocabulary Focus)
                // Meaning is ONLY flipped via explicit 'Show Meaning' button to avoid accidental taps near audio
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 4) {
                        if viewModel.isFlipped {
                            // Reverse Side: English Meaning (Large and prominent)
                            Text(activeWord.meaning)
                                .font(.english(size: 34, weight: .bold))
                                .foregroundColor(inkColor)
                                .lineLimit(2)
                                .minimumScaleFactor(0.70)
                                .transition(.opacity)

                            Text(activeWord.japanese)
                                .font(.japanese(size: 16, weight: .bold))
                                .foregroundColor(mutedColor)
                                .transition(.opacity)
                        } else {
                            // Front Side: Japanese Word
                            Text(activeWord.japanese)
                                .font(.japanese(size: 36, weight: .bold))
                                .foregroundColor(inkColor)
                                .lineLimit(2)
                                .minimumScaleFactor(0.70)
                                .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 46)

                    // Word romaji pronunciation (controlled by Romaji setting) & audio button
                    HStack(spacing: 8) {
                        if settingsManager.showAppRomaji {
                            Text(activeWord.romaji)
                                .font(.english(size: 17, weight: .medium))
                                .foregroundColor(mutedColor)
                        }

                        Button {
                            viewModel.speakCurrentWord()
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 14))
                                .foregroundColor(mutedColor)
                                .padding(6)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settingsManager.showAppRomaji.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: settingsManager.showAppRomaji ? "eye.fill" : "eye.slash")
                                    .font(.system(size: 11))
                                Text(settingsManager.showAppRomaji ? "Romaji" : "Romaji Off")
                                    .font(.english(size: 11, weight: .medium))
                            }
                            .foregroundColor(mutedColor.opacity(0.85))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(themeManager.segmentEmptyColor.opacity(0.45))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 6)

                // Pure Vocabulary Info Badges: Part of Speech, JLPT level & Flip button
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        // Word Type Pill
                        Text(activeWord.wordType.description)
                            .font(.english(size: 13, weight: .medium))
                            .foregroundColor(inkColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(themeManager.segmentEmptyColor.opacity(0.6))
                            .cornerRadius(6)

                        // JLPT Level Pill
                        Text(activeWord.jlptLevel.rawValue)
                            .font(.english(size: 13, weight: .medium))
                            .foregroundColor(activeWord.jlptLevel == .n5 ? Color(hex: "#10B981") : Color(hex: "#3B82F6"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(themeManager.segmentEmptyColor.opacity(0.6))
                            .cornerRadius(6)

                        Spacer()

                        // English Flip Card Button (Show Meaning / Show Word)
                        Button {
                            viewModel.flipCard()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11))
                                Text(viewModel.isFlipped ? "Show Word" : "Show Meaning")
                                    .font(.english(size: 13, weight: .medium))
                            }
                            .foregroundColor(mutedColor)
                        }
                        .buttonStyle(.plain)
                    }

                    // Kanji Writing Info & Romaji Reading below badges (one below the other)
                    if let kanji = activeWord.kanji, !kanji.isEmpty, kanji != activeWord.kana {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Text("Kanji:")
                                    .font(.english(size: 13, weight: .medium))
                                    .foregroundColor(mutedColor)
                                Text(kanji)
                                    .font(.japanese(size: 15, weight: .bold))
                                    .foregroundColor(inkColor)
                            }

                            HStack(spacing: 6) {
                                Text("Reading:")
                                    .font(.english(size: 13, weight: .medium))
                                    .foregroundColor(mutedColor)
                                Text(activeWord.kana)
                                    .font(.japanese(size: 14, weight: .regular))
                                    .foregroundColor(inkColor)
                                if settingsManager.showAppRomaji {
                                    Text("(\(activeWord.romaji))")
                                        .font(.english(size: 14, weight: .regular))
                                        .foregroundColor(mutedColor)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.top, 6)
            }
        }
    }
}

// MARK: - 3D Card Flip Modifier (Requirement 5)
struct CardFlipModifier: AnimatableModifier {
    var progress: Double // 0.0 (front) to 1.0 (back)
    let isBack: Bool

    init(isFlipped: Bool, isBack: Bool) {
        self.progress = isFlipped ? 1.0 : 0.0
        self.isBack = isBack
    }

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let isVisible = isBack ? (progress >= 0.5) : (progress < 0.5)
        let angle = isBack ? (1.0 - progress) * -180.0 : progress * 180.0

        content
            .opacity(isVisible ? 1.0 : 0.0)
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 1, y: 0, z: 0),
                anchor: .center,
                perspective: 0.35
            )
            .accessibilityHidden(!isVisible)
    }
}
