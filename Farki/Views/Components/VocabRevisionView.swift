import SwiftUI

struct VocabRevisionView: View {
    @ObservedObject var viewModel: VocabViewModel
    @ObservedObject var revisionService: VocabRevisionService = VocabRevisionService.shared
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared
    @ObservedObject var settingsManager: AppSettingsManager = AppSettingsManager.shared

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
        themeManager.activeTheme == .dark ? Color(hex: "#141210") : Color(hex: "#F5F5F4")
    }

    private var cardBorderColor: Color {
        themeManager.activeTheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.12)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if viewModel.isRevisionSessionActive {
                if viewModel.isRevisionSessionFinished {
                    sessionFinishedSummaryView
                } else {
                    activeRevisionSessionView
                }
            } else {
                chapterSelectionListView
            }
        }
    }

    // MARK: - 1. Chapter Selection List View
    @ViewBuilder
    private var chapterSelectionListView: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Revision Header & Global Metrics
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VOCABULARY REVISION")
                            .font(.english(size: 11, weight: .bold))
                            .foregroundColor(mutedColor)
                            .tracking(0.8)

                        Text("Active Recall & Self-Assessment")
                            .font(.english(size: 20, weight: .bold))
                            .foregroundColor(inkColor)

                        Text("Select a chapter below to begin your revision session. Answers are written on paper and self-verified.")
                            .font(.english(size: 12, weight: .regular))
                            .foregroundColor(mutedColor)
                            .lineSpacing(2)
                    }

                    Spacer()
                }

                // Independent Revision Metrics Banner (Requirement 2.3)
                let metrics = revisionService.globalMetrics()
                HStack(spacing: 8) {
                    metricPill(label: "Words Revised", value: "\(metrics.totalWordsRevised)")
                    metricPill(label: "Correct", value: "\(metrics.correctAnswers)", color: Color(hex: "#10B981"))
                    metricPill(label: "Incorrect", value: "\(metrics.incorrectAnswers)", color: Color(hex: "#EF4444"))
                    metricPill(label: "Accuracy", value: "\(metrics.accuracyPercentage)%", color: Color(hex: "#3B82F6"))
                }
            }
            .padding(14)
            .background(themeManager.segmentEmptyColor.opacity(0.35))
            .cornerRadius(12)

            // Revision Recall Direction Switcher (Requirement 2.2)
            VStack(alignment: .leading, spacing: 8) {
                Text("REVISION DIRECTION")
                    .font(.english(size: 11, weight: .bold))
                    .foregroundColor(mutedColor)
                    .tracking(0.6)

                HStack(spacing: 10) {
                    directionOptionButton(
                        direction: .japaneseToEnglish,
                        subtitle: "Prompt: Japanese → Recall: English meaning"
                    )

                    directionOptionButton(
                        direction: .englishToJapanese,
                        subtitle: "Prompt: English → Recall: Japanese word"
                    )
                }
            }

            // Available Chapters List (Requirement 2.1)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("SELECT CHAPTER TO REVISE")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)
                        .tracking(0.6)

                    Spacer()

                    Text("Minna no Nihongo")
                        .font(.english(size: 11, weight: .medium))
                        .foregroundColor(mutedColor)
                }

                let chapters = Array(1...25)
                VStack(spacing: 8) {
                    ForEach(chapters, id: \.self) { ch in
                        let summary = revisionService.chapterSummary(for: ch)
                        chapterRevisionRow(summary: summary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func metricPill(label: String, value: String, color: Color? = nil) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.english(size: 15, weight: .bold))
                .foregroundColor(color ?? inkColor)

            Text(label)
                .font(.english(size: 10, weight: .regular))
                .foregroundColor(mutedColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(cardBackground)
        .cornerRadius(8)
    }

    @ViewBuilder
    private func directionOptionButton(direction: VocabRevisionDirection, subtitle: String) -> some View {
        let isSelected = viewModel.revisionDirection == direction
        Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            viewModel.revisionDirection = direction
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(direction.title)
                        .font(.english(size: 13, weight: .bold))
                        .foregroundColor(isSelected ? canvasColor : inkColor)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(canvasColor)
                    }
                }

                Text(subtitle)
                    .font(.english(size: 10, weight: .regular))
                    .foregroundColor(isSelected ? canvasColor.opacity(0.85) : mutedColor)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? inkColor : themeManager.segmentEmptyColor.opacity(0.45))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func chapterRevisionRow(summary: ChapterProgressSummary) -> some View {
        let ch = summary.chapterNumber
        let hasWords = summary.totalWords > 0
        let isFullyRevised = summary.state == .fullyRevised

        Button {
            if hasWords {
                viewModel.startRevision(chapter: ch, direction: viewModel.revisionDirection)
            }
        } label: {
            HStack(spacing: 12) {
                // Chapter Number Box
                VStack(spacing: 2) {
                    Text("CH")
                        .font(.english(size: 9, weight: .bold))
                        .foregroundColor(isFullyRevised ? Color(hex: "#10B981") : mutedColor)

                    Text("\(ch)")
                        .font(.english(size: 18, weight: .bold))
                        .foregroundColor(isFullyRevised ? Color(hex: "#10B981") : inkColor)
                }
                .frame(width: 44, height: 44)
                .background(isFullyRevised ? Color(hex: "#10B981").opacity(0.12) : themeManager.segmentEmptyColor.opacity(0.45))
                .cornerRadius(8)

                // Chapter Details & Progress
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Chapter \(ch)")
                            .font(.english(size: 14, weight: .bold))
                            .foregroundColor(inkColor)

                        if isFullyRevised {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 10))
                                Text("Fully Revised")
                                    .font(.english(size: 10, weight: .bold))
                            }
                            .foregroundColor(Color(hex: "#10B981"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#10B981").opacity(0.12))
                            .cornerRadius(4)
                        } else if summary.state == .vocabularyCompleted {
                            Text("Ready for Revision")
                                .font(.english(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "#3B82F6"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#3B82F6").opacity(0.12))
                                .cornerRadius(4)
                        }
                    }

                    Text("\(summary.totalWords) words • \(summary.studiedWords) studied • \(summary.correctlyRevisedWords) verified correct")
                        .font(.english(size: 11, weight: .regular))
                        .foregroundColor(mutedColor)
                }

                Spacer()

                // Action Arrow / Badge
                HStack(spacing: 4) {
                    Text("Revise")
                        .font(.english(size: 12, weight: .bold))
                        .foregroundColor(canvasColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(inkColor)
                        .cornerRadius(6)
                }
            }
            .padding(12)
            .background(cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isFullyRevised ? Color(hex: "#10B981").opacity(0.3) : cardBorderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!hasWords)
        .opacity(hasWords ? 1.0 : 0.5)
    }

    // MARK: - 2. Active Interactive Revision Session View
    @ViewBuilder
    private var activeRevisionSessionView: some View {
        if let word = viewModel.currentRevisionWord {
            VStack(alignment: .leading, spacing: 18) {
                // Top Session Bar: Chapter, Mode, Word Counter & Exit Button
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Chapter \(viewModel.revisionSelectedChapter) Revision")
                                .font(.english(size: 15, weight: .bold))
                                .foregroundColor(inkColor)

                            Text("• \(viewModel.revisionDirection.shortTitle)")
                                .font(.english(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#3B82F6"))
                        }

                        Text("Word \(viewModel.revisionCurrentIndex + 1) of \(viewModel.revisionSessionWords.count)")
                            .font(.english(size: 12, weight: .regular))
                            .foregroundColor(mutedColor)
                    }

                    Spacer()

                    Button {
                        viewModel.exitRevisionSession()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                            Text("End")
                                .font(.english(size: 12, weight: .medium))
                        }
                        .foregroundColor(mutedColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(themeManager.segmentEmptyColor.opacity(0.45))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                // Progress Bar
                GeometryReader { geo in
                    let progress = Double(viewModel.revisionCurrentIndex) / Double(max(1, viewModel.revisionSessionWords.count))
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(themeManager.segmentEmptyColor)
                            .frame(height: 5)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(inkColor)
                            .frame(width: geo.size.width * CGFloat(progress), height: 5)
                    }
                }
                .frame(height: 5)

                // Current Session Score Counter
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#10B981"))
                        Text("\(viewModel.revisionSessionCorrectCount) Correct")
                            .font(.english(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#10B981"))
                    }

                    Text("•")
                        .foregroundColor(mutedColor)

                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#EF4444"))
                        Text("\(viewModel.revisionSessionIncorrectCount) Wrong")
                            .font(.english(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#EF4444"))
                    }

                    Spacer()

                    Text(viewModel.revisionDirection.promptText)
                        .font(.english(size: 11, weight: .regular))
                        .foregroundColor(mutedColor)
                }

                // Prompt Card
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        if viewModel.revisionDirection == .japaneseToEnglish {
                            // Mode A: Japanese displayed prominently
                            Text(word.japanese)
                                .font(.japanese(size: 38, weight: .bold))
                                .foregroundColor(inkColor)
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)

                            if word.kana != word.japanese {
                                Text(word.kana)
                                    .font(.japanese(size: 16, weight: .medium))
                                    .foregroundColor(mutedColor)
                            }

                            if settingsManager.showAppRomaji && !word.romaji.isEmpty {
                                Text(word.romaji)
                                    .font(.english(size: 15, weight: .medium))
                                    .foregroundColor(mutedColor.opacity(0.85))
                            }
                        } else {
                            // Mode B: English meaning displayed prominently
                            Text(word.meaning)
                                .font(.english(size: 30, weight: .bold))
                                .foregroundColor(inkColor)
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)

                            Text(word.categoryTag)
                                .font(.japanese(size: 13, weight: .medium))
                                .foregroundColor(mutedColor)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(cardBorderColor, lineWidth: 1)
                    )

                    // Verification Container: Revealed only when user requests
                    if viewModel.isRevisionAnswerRevealed {
                        VStack(spacing: 14) {
                            VStack(spacing: 6) {
                                Text("EXPECTED ANSWER")
                                    .font(.english(size: 10, weight: .bold))
                                    .foregroundColor(mutedColor)
                                    .tracking(0.8)

                                if viewModel.revisionDirection == .japaneseToEnglish {
                                    Text(word.meaning)
                                        .font(.english(size: 24, weight: .bold))
                                        .foregroundColor(inkColor)
                                        .multilineTextAlignment(.center)
                                } else {
                                    Text(word.japanese)
                                        .font(.japanese(size: 28, weight: .bold))
                                        .foregroundColor(inkColor)
                                        .multilineTextAlignment(.center)

                                    Text("\(word.kana) (\(word.romaji))")
                                        .font(.english(size: 14, weight: .medium))
                                        .foregroundColor(mutedColor)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(themeManager.segmentEmptyColor.opacity(0.35))
                            .cornerRadius(10)

                            // Self-Assessment Buttons (Enabled ONLY after checking answer)
                            HStack(spacing: 12) {
                                Button {
                                    viewModel.recordRevisionAnswer(isCorrect: false)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 14, weight: .bold))
                                        Text("Got it wrong")
                                            .font(.english(size: 14, weight: .bold))
                                    }
                                    .foregroundColor(Color(hex: "#EF4444"))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color(hex: "#EF4444").opacity(0.12))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(hex: "#EF4444").opacity(0.4), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    viewModel.recordRevisionAnswer(isCorrect: true)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                        Text("Got it right")
                                            .font(.english(size: 14, weight: .bold))
                                    }
                                    .foregroundColor(Color(hex: "#10B981"))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color(hex: "#10B981").opacity(0.14))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(hex: "#10B981").opacity(0.4), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        // Prominent Reveal & Verify Answer Button
                        Button {
                            viewModel.revealRevisionAnswer()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 14))
                                Text("Reveal & Verify Answer")
                                    .font(.english(size: 15, weight: .bold))
                            }
                            .foregroundColor(canvasColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(inkColor)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 3. Session Finished Summary View
    @ViewBuilder
    private var sessionFinishedSummaryView: some View {
        let total = viewModel.revisionSessionWords.count
        let correct = viewModel.revisionSessionCorrectCount
        let wrong = viewModel.revisionSessionIncorrectCount
        let pct = total > 0 ? Int(round((Double(correct) / Double(total)) * 100)) : 0
        let isAllCorrect = (wrong == 0 && total > 0)
        let isChapterComplete = revisionService.isChapterFullyRevised(chapter: viewModel.revisionSelectedChapter)

        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Image(systemName: isAllCorrect ? "star.circle.fill" : "checkmark.seal.fill")
                    .font(.system(size: 46))
                    .foregroundColor(isAllCorrect ? Color(hex: "#10B981") : Color(hex: "#3B82F6"))

                Text(isAllCorrect ? "Chapter Fully Revised!" : "Revision Session Completed")
                    .font(.english(size: 22, weight: .bold))
                    .foregroundColor(inkColor)

                Text("Chapter \(viewModel.revisionSelectedChapter) • \(viewModel.revisionDirection.title)")
                    .font(.english(size: 13, weight: .medium))
                    .foregroundColor(mutedColor)
            }
            .padding(.top, 10)

            // Result Metrics Grid
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    metricCard(title: "Accuracy", value: "\(pct)%", color: pct >= 80 ? Color(hex: "#10B981") : Color(hex: "#F59E0B"))
                    metricCard(title: "Words Revised", value: "\(total)", color: inkColor)
                }

                HStack(spacing: 10) {
                    metricCard(title: "Correct", value: "\(correct)", color: Color(hex: "#10B981"))
                    metricCard(title: "Wrong", value: "\(wrong)", color: wrong > 0 ? Color(hex: "#EF4444") : mutedColor)
                }
            }

            // Chapter Status Banner
            HStack(spacing: 8) {
                Circle()
                    .fill(isChapterComplete ? Color(hex: "#10B981") : Color(hex: "#3B82F6"))
                    .frame(width: 8, height: 8)

                Text(isChapterComplete ? "Status: Chapter \(viewModel.revisionSelectedChapter) is now Fully Revised (Green on Dashboard)" : "Status: In Progress • \(wrong) words need further practice")
                    .font(.english(size: 12, weight: .bold))
                    .foregroundColor(isChapterComplete ? Color(hex: "#10B981") : inkColor)

                Spacer()
            }
            .padding(12)
            .background(themeManager.segmentEmptyColor.opacity(0.35))
            .cornerRadius(8)

            // CTA Action Buttons
            VStack(spacing: 10) {
                Button {
                    viewModel.restartRevisionSession()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .bold))
                        Text("Revise This Chapter Again")
                            .font(.english(size: 14, weight: .bold))
                    }
                    .foregroundColor(canvasColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(inkColor)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    // Switch direction and restart
                    let newDir: VocabRevisionDirection = viewModel.revisionDirection == .japaneseToEnglish ? .englishToJapanese : .japaneseToEnglish
                    viewModel.startRevision(chapter: viewModel.revisionSelectedChapter, direction: newDir)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 13, weight: .bold))
                        Text("Switch to \(viewModel.revisionDirection == .japaneseToEnglish ? "English → 日本語" : "日本語 → English")")
                            .font(.english(size: 14, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "#3B82F6"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color(hex: "#3B82F6").opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.exitRevisionSession()
                } label: {
                    Text("Select Another Chapter")
                        .font(.english(size: 13, weight: .medium))
                        .foregroundColor(mutedColor)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardBorderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func metricCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.english(size: 22, weight: .bold))
                .foregroundColor(color)

            Text(title)
                .font(.english(size: 11, weight: .regular))
                .foregroundColor(mutedColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(themeManager.segmentEmptyColor.opacity(0.35))
        .cornerRadius(8)
    }
}

