import SwiftUI

struct ImportSettingsView: View {
    @ObservedObject var vocabVM: VocabViewModel
    @ObservedObject var navVM: NavigationViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared
    @ObservedObject var settingsManager: AppSettingsManager = AppSettingsManager.shared

    @State private var jsonInputText: String = ""
    @State private var isShowingJSONEditor: Bool = false
    @State private var showSuccessBanner: Bool = false
    @State private var bannerMessage: String = ""
    @State private var bannerIsError: Bool = false
    @State private var showExplanationModal: Bool = false
    @State private var isShowingResetStatsAlert: Bool = false

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
        themeManager.activeTheme == .dark ? Color(hex: "#1C1917") : Color(hex: "#F5F5F4")
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 30) {
                // Header spacing to align below top persistent header
                Color.clear
                    .frame(height: 24)
                    .padding(.top, 14)

                // Top navigation bar with Back button and Page Title
                headerView

                // Status banner if an import or filter action occurs
                if showSuccessBanner {
                    statusBannerView
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Section 1: Minna no Nihongo Textbook Selection
                textbookSelectionSection

                // Section 2: Chapter Grid (with dimmed unimported chapters & clear logic)
                chapterGridSection

                // Section 3: Chapter Vocabulary Import
                importSection

                // Section 4: Study & Learning Filters
                studyFiltersSection

                // Section 5: App Language Guide Display Settings
                displayGuideSettingsSection

                // Section 6: Practice Mode Settings
                practiceSettingsSection

                // Section 7: Target Exam Date
                targetExamDateSettingSection

                // Section 8: Dashboard Widget Visibility
                dashboardWidgetVisibilitySection

                // Section 9: Appearance Theme
                appearanceSection

                // Section 10: Reset Progress & Stats
                resetProgressSection

                // Big CTA button to start studying
                startStudyingButton
                    .padding(.top, 10)
                    .padding(.bottom, 120) // Clearance for bottom menu
            }
            .padding(.horizontal, 24)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showSuccessBanner)
        .sheet(isPresented: $isShowingJSONEditor) {
            jsonImportSheet
        }
        .alert("Reset Study Progress?", isPresented: $isShowingResetStatsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset Progress", role: .destructive) {
                VocabDataService.shared.resetProgressAndStatsKeepVocab()
                vocabVM.reloadItems()
                vocabVM.sessionSeconds = 0
                vocabVM.isTimerPaused = true
                bannerMessage = "Study progress and statistics reset. All vocabulary words kept intact."
                bannerIsError = false
                showSuccessBanner = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        } message: {
            Text("All imported vocabulary words remain intact. Only study history, streaks, SRS review intervals, and session statistics will be reset to initial state.")
        }
    }

    // MARK: - Header
    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    navVM.activePage = .tab(.kotoba)
                    navVM.isVocabMenuVisible = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))

                        Text("To Vocab")
                            .font(.english(size: 13, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(inkColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(cardBackground)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    vocabVM.clearFilter()
                    showBanner(message: "Filters reset to default", isError: false)
                } label: {
                    Text("Reset")
                        .font(.english(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#BE123C"))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Import & Settings")
                    .font(.english(size: 30, weight: .bold))
                    .foregroundColor(inkColor)
                    .lineLimit(1)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Status Banner
    @ViewBuilder
    private var statusBannerView: some View {
        HStack(spacing: 10) {
            Image(systemName: bannerIsError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(bannerIsError ? Color(hex: "#EF4444") : Color(hex: "#10B981"))
                .font(.system(size: 18))

            Text(bannerMessage)
                .font(.english(size: 13, weight: .medium))
                .foregroundColor(inkColor)

            Spacer()

            Button {
                showSuccessBanner = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(mutedColor)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(bannerIsError ? Color(hex: "#EF4444").opacity(0.12) : Color(hex: "#10B981").opacity(0.12))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(bannerIsError ? Color(hex: "#EF4444").opacity(0.25) : Color(hex: "#10B981").opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Section 1: Textbook Selection
    @ViewBuilder
    private var textbookSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("01. Textbook Selection")
                .font(.english(size: 15, weight: .bold))
                .foregroundColor(inkColor)
                .lineLimit(1)

            HStack(spacing: 8) {
                bookTabButton(
                    title: "Book 1",
                    subtitle: "Chapters 1–25",
                    isSelected: vocabVM.filter.selectedBook == .book1
                ) {
                    vocabVM.selectBook(.book1)
                }

                bookTabButton(
                    title: "Book 2",
                    subtitle: "Chapters 26–50",
                    isSelected: vocabVM.filter.selectedBook == .book2
                ) {
                    vocabVM.selectBook(.book2)
                }

                bookTabButton(
                    title: "All",
                    subtitle: "Chapters 1–50",
                    isSelected: vocabVM.filter.selectedBook == nil
                ) {
                    vocabVM.selectBook(nil)
                }
            }

            // Active Chapter Card
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Current Study Target")
                        .font(.english(size: 12, weight: .semibold))
                        .foregroundColor(inkColor)

                    Text(vocabVM.filter.summaryText)
                        .font(.english(size: 16, weight: .bold))
                        .foregroundColor(inkColor)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(vocabVM.items.count) words")
                        .font(.english(size: 16, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("Registered Words")
                        .font(.english(size: 11, weight: .regular))
                        .foregroundColor(mutedColor)
                }
            }
            .padding(14)
            .background(cardBackground)
            .cornerRadius(10)
        }
    }

    @ViewBuilder
    private func bookTabButton(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.english(size: 14, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? canvasColor : inkColor)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.english(size: 10, weight: .regular))
                    .foregroundColor(isSelected ? canvasColor.opacity(0.8) : mutedColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? inkColor : cardBackground)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section 2: Chapter Grid
    @ViewBuilder
    private var chapterGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("02. Chapter Selection")
                    .font(.english(size: 15, weight: .bold))
                    .foregroundColor(inkColor)
                    .lineLimit(1)

                Spacer()

                if vocabVM.filter.selectedChapter != nil {
                    Button {
                        vocabVM.selectChapter(nil)
                    } label: {
                        Text("Show All Chapters")
                            .font(.english(size: 12, weight: .medium))
                            .foregroundColor(inkColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Explanation guide box
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#F59E0B"))

                    Text("Why select a specific chapter?")
                        .font(.english(size: 12, weight: .bold))
                        .foregroundColor(inkColor)
                }

                Text("Filters your active study session so you only practice words from one chapter instead of all 50. Solid blocks with green dots are imported. Dimmed blocks are unimported; tap one to load its JSON sheet.")
                    .font(.english(size: 12, weight: .regular))
                    .foregroundColor(mutedColor)
                    .lineSpacing(2)
            }
            .padding(12)
            .background(cardBackground)
            .cornerRadius(8)

            let startChapter = vocabVM.filter.selectedBook == .book2 ? 26 : 1
            let endChapter = vocabVM.filter.selectedBook == .book1 ? 25 : (vocabVM.filter.selectedBook == .book2 ? 50 : 50)
            let chapters = Array(startChapter...endChapter)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 5), spacing: 7) {
                ForEach(chapters, id: \.self) { (ch: Int) in
                    let isSelected = (vocabVM.filter.selectedChapter == ch)
                    let wordsInChapter = VocabDataService.shared.items.filter { $0.chapterNumber == ch }
                    let hasImportedWords = !wordsInChapter.isEmpty

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if hasImportedWords {
                            vocabVM.selectChapter(isSelected ? nil : ch)
                        } else {
                            jsonInputText = ""
                            isShowingJSONEditor = true
                        }
                    } label: {
                        VStack(spacing: 1) {
                            Text("\(ch)")
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .monospaced))
                                .foregroundColor(isSelected ? canvasColor : inkColor)

                            if hasImportedWords {
                                HStack(spacing: 2) {
                                    Circle()
                                        .fill(isSelected ? canvasColor : Color(hex: "#10B981"))
                                        .frame(width: 4, height: 4)
                                    Text("\(wordsInChapter.count)w")
                                        .font(.english(size: 9, weight: .bold))
                                        .foregroundColor(isSelected ? canvasColor : Color(hex: "#10B981"))
                                }
                            } else {
                                Text("Empty")
                                    .font(.english(size: 8, weight: .regular))
                                    .foregroundColor(mutedColor.opacity(0.7))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(isSelected ? inkColor : cardBackground)
                        .cornerRadius(8)
                        .opacity(hasImportedWords ? 1.0 : (isSelected ? 0.9 : 0.32))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(hasImportedWords ? Color.clear : mutedColor.opacity(0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Section 3: Chapter Vocabulary Import
    @ViewBuilder
    private var importSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("03. Chapter Vocabulary Sheet Import")
                .font(.english(size: 15, weight: .bold))
                .foregroundColor(inkColor)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 14) {
                Text("Importing a chapter JSON sheet unlocks that chapter for active practice.")
                    .font(.english(size: 12, weight: .regular))
                    .foregroundColor(mutedColor)
                    .lineSpacing(2)

                VStack(spacing: 10) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        isShowingJSONEditor = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 15, weight: .semibold))

                            Text("Import JSON Vocabulary Sheet")
                                .font(.english(size: 15, weight: .bold))
                                .lineLimit(1)

                            Spacer()

                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(canvasColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(inkColor)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if let pasted = UIPasteboard.general.string {
                            jsonInputText = pasted
                        }
                        isShowingJSONEditor = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 13))

                            Text("Paste JSON Sheet from Clipboard")
                                .font(.english(size: 13, weight: .medium))
                                .lineLimit(1)

                            Spacer()
                        }
                        .foregroundColor(inkColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(themeManager.segmentEmptyColor.opacity(0.35))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                if let result = vocabVM.lastImportResult {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recent Import History:")
                            .font(.english(size: 12, weight: .semibold))
                            .foregroundColor(inkColor)

                        HStack {
                            Text("Chapter \(result.chapterNumber) (\(result.bookNumber == 1 ? "Book 1" : "Book 2"))")
                                .font(.english(size: 14, weight: .bold))
                                .foregroundColor(inkColor)

                            Spacer()

                            Text("\(result.importedCount + result.updatedCount) words registered")
                                .font(.english(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "#10B981"))
                        }
                    }
                    .padding(12)
                    .background(Color(hex: "#10B981").opacity(0.08))
                    .cornerRadius(8)
                }
            }
            .padding(16)
            .background(cardBackground)
            .cornerRadius(12)
        }
    }

    // MARK: - Section 4: Study & Learning Filters
    @ViewBuilder
    private var studyFiltersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("04. Study Filters")
                .font(.english(size: 15, weight: .bold))
                .foregroundColor(inkColor)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 6) {
                Text("JLPT Level")
                    .font(.english(size: 12, weight: .medium))
                    .foregroundColor(inkColor)

                HStack(spacing: 8) {
                    filterChip(title: "All", isSelected: vocabVM.filter.selectedJLPTLevel == nil) {
                        vocabVM.selectJLPTLevel(nil)
                    }
                    filterChip(title: "N5", isSelected: vocabVM.filter.selectedJLPTLevel == .n5) {
                        vocabVM.selectJLPTLevel(.n5)
                    }
                    filterChip(title: "N4", isSelected: vocabVM.filter.selectedJLPTLevel == .n4) {
                        vocabVM.selectJLPTLevel(.n4)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Learning Status")
                    .font(.english(size: 12, weight: .medium))
                    .foregroundColor(inkColor)

                HStack(spacing: 8) {
                    filterChip(title: "All", isSelected: vocabVM.filter.selectedLearningStatus == nil) {
                        vocabVM.selectLearningStatus(nil)
                    }
                    ForEach(VocabLearningState.allCases) { state in
                        filterChip(title: stateEnglishLabel(state), isSelected: vocabVM.filter.selectedLearningStatus == state) {
                            vocabVM.selectLearningStatus(state)
                        }
                    }
                }
            }
        }
    }

    private func stateEnglishLabel(_ state: VocabLearningState) -> String {
        switch state {
        case .unseen: return "Unseen"
        case .knownDirectly: return "Known"
        case .knownAfterReveal: return "Review"
        }
    }

    @ViewBuilder
    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Text(title)
                .font(.english(size: 12, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? canvasColor : inkColor)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? inkColor : cardBackground)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section 5: App Language Guide Display Settings
    @ViewBuilder
    private var displayGuideSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("05. UI Language Guides")
                .font(.english(size: 15, weight: .bold))
                .foregroundColor(inkColor)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 14) {
                Text("Configure whether Romaji pronunciation guides and English translations appear across the app UI.")
                    .font(.english(size: 12, weight: .regular))
                    .foregroundColor(mutedColor)
                    .lineSpacing(2)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Display Mode:")
                        .font(.english(size: 12, weight: .semibold))
                        .foregroundColor(inkColor)

                    HStack(spacing: 6) {
                        ForEach(AppTextDisplayMode.allCases) { mode in
                            let isSelected = (settingsManager.activeDisplayMode == mode)
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                settingsManager.setDisplayMode(mode)
                            } label: {
                                Text(mode.english)
                                    .font(.english(size: 12, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? canvasColor : inkColor)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? inkColor : cardBackground)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isSelected ? Color.clear : mutedColor.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider()
                    .background(themeManager.hairlineColor)

                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Romaji Guide")
                                .font(.english(size: 14, weight: .medium))
                                .foregroundColor(inkColor)

                            Text("Show Romaji pronunciation under Japanese text")
                                .font(.english(size: 11, weight: .regular))
                                .foregroundColor(mutedColor)
                        }

                        Spacer()

                        Toggle("", isOn: $settingsManager.showAppRomaji)
                            .labelsHidden()
                            .tint(inkColor)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("English Meaning Guide")
                                .font(.english(size: 14, weight: .medium))
                                .foregroundColor(inkColor)

                            Text("Show English translation meaning under Japanese text")
                                .font(.english(size: 11, weight: .regular))
                                .foregroundColor(mutedColor)
                        }

                        Spacer()

                        Toggle("", isOn: $settingsManager.showAppEnglishMeaning)
                            .labelsHidden()
                            .tint(inkColor)
                    }
                }
            }
            .padding(14)
            .background(cardBackground)
            .cornerRadius(10)
        }
    }

    // MARK: - Section 6: Practice Mode Settings
    @ViewBuilder
    private var practiceSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("06. Practice Mode Settings")
                .font(.english(size: 15, weight: .bold))
                .foregroundColor(inkColor)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Hide English Meanings Initially")
                            .font(.english(size: 14, weight: .medium))
                            .foregroundColor(inkColor)

                        Text("Hides English meanings when card is first shown to stimulate active recall. Tapping reveals the meaning.")
                            .font(.english(size: 12, weight: .regular))
                            .foregroundColor(mutedColor)
                            .lineSpacing(2)
                            .padding(.top, 2)
                    }

                    Spacer()

                    Toggle("", isOn: $settingsManager.practiceHideMeaningByDefault)
                        .labelsHidden()
                        .tint(inkColor)
                }

                Divider()
                    .background(themeManager.hairlineColor)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Inherited UI Guide Settings:")
                        .font(.english(size: 12, weight: .semibold))
                        .foregroundColor(inkColor)

                    HStack(spacing: 14) {
                        HStack(spacing: 5) {
                            Image(systemName: settingsManager.showAppRomaji ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(settingsManager.showAppRomaji ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                            Text("Romaji: \(settingsManager.showAppRomaji ? "On" : "Off")")
                                .font(.english(size: 12, weight: .medium))
                                .foregroundColor(inkColor)
                        }

                        HStack(spacing: 5) {
                            Image(systemName: settingsManager.showAppEnglishMeaning ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(settingsManager.showAppEnglishMeaning ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                            Text("English: \(settingsManager.showAppEnglishMeaning ? "On" : "Off")")
                                .font(.english(size: 12, weight: .medium))
                                .foregroundColor(inkColor)
                        }
                    }
                }
            }
            .padding(14)
            .background(cardBackground)
            .cornerRadius(10)
        }
    }

    // MARK: - Section 7: Target Exam Date
    @ViewBuilder
    private var targetExamDateSettingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("07. Target Exam Date")
                .font(.english(size: 15, weight: .bold))
                .foregroundColor(inkColor)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 12) {
                Text("Sets the JLPT exam countdown displayed on the dashboard progress card (e.g. 48 D).")
                    .font(.english(size: 12, weight: .regular))
                    .foregroundColor(mutedColor)
                    .lineSpacing(2)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Exam Date")
                            .font(.english(size: 14, weight: .medium))
                            .foregroundColor(inkColor)

                        Text("\(settingsManager.daysUntilExam) days remaining")
                            .font(.english(size: 11, weight: .regular))
                            .foregroundColor(mutedColor)
                    }

                    Spacer()

                    DatePicker(
                        "",
                        selection: $settingsManager.targetExamDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(inkColor)
                }

                HStack {
                    Text("Current: \(settingsManager.formattedExamDate)")
                        .font(.english(size: 12, weight: .medium))
                        .foregroundColor(inkColor)

                    Spacer()

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        let calendar = Calendar.current
                        let now = Date()
                        var year = calendar.component(.year, from: now)
                        var comps = DateComponents(year: year, month: 12, day: 13, hour: 9, minute: 0)
                        if let d = calendar.date(from: comps), d < now {
                            year += 1
                            comps.year = year
                        }
                        if let dec13 = calendar.date(from: comps) {
                            settingsManager.targetExamDate = dec13
                        }
                    } label: {
                        Text("Set to Dec 13")
                            .font(.english(size: 11, weight: .medium))
                            .foregroundColor(inkColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(mutedColor.opacity(0.12))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(cardBackground)
            .cornerRadius(10)
        }
    }

    // MARK: - Section 8: Dashboard Widget Visibility (Requirement 5)
    @ViewBuilder
    private var dashboardWidgetVisibilitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("08. Dashboard Widget Visibility")
                .font(.english(size: 15, weight: .bold))
                .foregroundColor(inkColor)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 14) {
                Text("Select which learning analytics cards to display on your dashboard. Hidden widgets retain all underlying performance data.")
                    .font(.english(size: 12, weight: .regular))
                    .foregroundColor(mutedColor)
                    .lineSpacing(2)

                dashboardWidgetToggleRow(
                    title: "Recall Velocity",
                    description: "Average recall response time & fluency classification",
                    isOn: $settingsManager.showDashboardRecallVelocity
                )

                dashboardWidgetToggleRow(
                    title: "Hesitation Breakdown",
                    description: "Instant (<1.5s), steady, and hesitant distribution bar",
                    isOn: $settingsManager.showDashboardHesitation
                )

                dashboardWidgetToggleRow(
                    title: "Memory Retention",
                    description: "4-tier card maturity grid (mature, young, learning, unseen)",
                    isOn: $settingsManager.showDashboardMemoryRetention
                )

                dashboardWidgetToggleRow(
                    title: "Memory Stability",
                    description: "Upcoming 7-day review forecast histogram",
                    isOn: $settingsManager.showDashboardMemoryStability
                )
            }
            .padding(14)
            .background(cardBackground)
            .cornerRadius(10)
        }
    }

    @ViewBuilder
    private func dashboardWidgetToggleRow(title: String, description: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.english(size: 14, weight: .medium))
                    .foregroundColor(inkColor)

                Text(description)
                    .font(.english(size: 11, weight: .regular))
                    .foregroundColor(mutedColor)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(inkColor)
        }
    }

    // MARK: - Section 9: Appearance
    @ViewBuilder
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("09. Appearance Theme")
                .font(.english(size: 15, weight: .bold))
                .foregroundColor(inkColor)
                .lineLimit(1)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(themeManager.activeTheme == .dark ? "Dark Theme" : "Light Theme")
                        .font(.english(size: 14, weight: .medium))
                        .foregroundColor(inkColor)

                    Text(themeManager.activeTheme == .dark ? "Ink Black canvas" : "Warm Paper canvas")
                        .font(.english(size: 11, weight: .regular))
                        .foregroundColor(mutedColor)
                }

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    themeManager.toggleTheme()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: themeManager.activeTheme == .dark ? "moon.stars.fill" : "sun.max.fill")
                        Text(themeManager.activeTheme == .dark ? "Dark" : "Light")
                    }
                    .font(.english(size: 13, weight: .medium))
                    .foregroundColor(inkColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(cardBackground)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(cardBackground)
            .cornerRadius(10)
        }
    }

    // MARK: - Section 10: Reset Progress & Stats
    @ViewBuilder
    private var resetProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("10. Reset Learning Progress & Stats")
                .font(.english(size: 15, weight: .bold))
                .foregroundColor(inkColor)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 14) {
                Text("All vocabulary words remain intact. Only study status, review history, streaks, and response statistics are reset to initial state.")
                    .font(.english(size: 12, weight: .regular))
                    .foregroundColor(mutedColor)
                    .lineSpacing(2)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    isShowingResetStatsAlert = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "#EF4444"))

                        Text("Reset Progress & Stats (Keep Vocab Words)")
                            .font(.english(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "#EF4444"))
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#EF4444").opacity(0.7))
                    }
                    .padding(12)
                    .background(Color(hex: "#EF4444").opacity(0.08))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#EF4444").opacity(0.28), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(cardBackground)
            .cornerRadius(10)
        }
    }

    // MARK: - Start Studying Button
    @ViewBuilder
    private var startStudyingButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            navVM.activePage = .tab(.kotoba)
            navVM.isVocabMenuVisible = true
        } label: {
            HStack(spacing: 8) {
                Text("Start Studying Vocabulary With These Settings")
                    .font(.english(size: 16, weight: .bold))
                    .lineLimit(1)

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(canvasColor)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(inkColor)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - JSON Import Sheet
    @ViewBuilder
    private var jsonImportSheet: some View {
        NavigationStack {
            ZStack {
                canvasColor.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Paste your chapter JSON vocabulary sheet below:")
                        .font(.english(size: 14, weight: .medium))
                        .foregroundColor(inkColor)

                    TextEditor(text: $jsonInputText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(inkColor)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(cardBackground)
                        .cornerRadius(8)
                        .frame(maxHeight: .infinity)

                    HStack(spacing: 12) {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if let pasted = UIPasteboard.general.string {
                                jsonInputText = pasted
                            }
                        } label: {
                            Text("Paste from Clipboard")
                                .font(.english(size: 13, weight: .medium))
                                .foregroundColor(inkColor)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(cardBackground)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            executeImport()
                        } label: {
                            Text("Execute Import")
                                .font(.english(size: 14, weight: .bold))
                                .foregroundColor(canvasColor)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(inkColor)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(jsonInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Import Vocabulary Sheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isShowingJSONEditor = false
                    } label: {
                        Text("Close")
                            .font(.english(size: 14, weight: .medium))
                    }
                    .foregroundColor(inkColor)
                }
            }
        }
    }

    private func executeImport() {
        let success = vocabVM.importChapter(jsonString: jsonInputText)
        isShowingJSONEditor = false
        if success, let result = vocabVM.lastImportResult {
            showBanner(
                message: "Imported Chapter \(result.chapterNumber) (\(result.importedCount + result.updatedCount) words) successfully!",
                isError: false
            )
        } else {
            showBanner(
                message: vocabVM.lastImportError ?? "Import failed. Please check the JSON format.",
                isError: true
            )
        }
    }

    private func showBanner(message: String, isError: Bool) {
        bannerMessage = message
        bannerIsError = isError
        showSuccessBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation {
                showSuccessBanner = false
            }
        }
    }
}
