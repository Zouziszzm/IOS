import SwiftUI

struct KanjiRevisionView: View {
    @ObservedObject var viewModel: KanjiViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared

    private var inkColor: Color {
        themeManager.inkColor
    }

    private var mutedColor: Color {
        themeManager.mutedColor
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
                    sessionFinishedView
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("KANJI REVISION")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)
                        .tracking(0.8)

                    Text("Active Recall & Self-Assessment")
                        .font(.english(size: 20, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("Select a chapter below to start revising kanji, readings, and compound words.")
                        .font(.english(size: 12, weight: .regular))
                        .foregroundColor(mutedColor)
                }

                // Global Metrics
                let metrics = KanjiDataService.shared.globalMetrics()
                HStack(spacing: 8) {
                    metricPill(label: "Total Kanjis", value: "\(metrics.total)")
                    metricPill(label: "Mastered", value: "\(metrics.mastered)", color: Color(hex: "#10B981"))
                    metricPill(label: "In Progress", value: "\(metrics.inProgress)", color: Color(hex: "#F59E0B"))
                    metricPill(label: "Accuracy", value: "\(metrics.accuracy)%", color: Color(hex: "#3B82F6"))
                }
            }
            .padding(14)
            .background(themeManager.segmentEmptyColor.opacity(0.35))
            .cornerRadius(12)

            // Chapter Revision Cards List
            Text("CHAPTER BREAKDOWN")
                .font(.english(size: 11, weight: .bold))
                .foregroundColor(mutedColor)
                .tracking(0.6)

            VStack(spacing: 12) {
                ForEach(viewModel.availableChapters) { ch in
                    chapterRevisionCard(for: ch)
                }
            }
        }
    }

    @ViewBuilder
    private func chapterRevisionCard(for sheet: KanjiChapterSheet) -> some View {
        let kanjis = sheet.kanjis
        let total = kanjis.count
        let mastered = kanjis.filter { $0.mastery == .mastered }.count
        let inProgress = kanjis.filter { $0.mastery == .learning }.count
        let pct = total > 0 ? Int(round((Double(mastered) / Double(total)) * 100)) : 0

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Chapter \(sheet.chapterNumber)")
                            .font(.english(size: 15, weight: .bold))
                            .foregroundColor(inkColor)

                        Text("• \(total) Kanjis")
                            .font(.english(size: 12, weight: .regular))
                            .foregroundColor(mutedColor)
                    }

                    Text(sheet.title)
                        .font(.system(size: 11))
                        .foregroundColor(mutedColor)

                    Text(sheet.englishTitle)
                        .font(.english(size: 11, weight: .regular))
                        .foregroundColor(Color(hex: "#3B82F6"))
                }

                Spacer()

                // Start Revision Button
                Button {
                    viewModel.startRevision(chapter: sheet.chapterNumber)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .bold))
                        Text("Revise")
                            .font(.english(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#3B82F6"))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            // Visual Progress Segment Bar
            GeometryReader { geo in
                let w = geo.size.width
                let masteredWidth = total > 0 ? (CGFloat(mastered) / CGFloat(total)) * w : 0
                let progressWidth = total > 0 ? (CGFloat(inProgress) / CGFloat(total)) * w : 0

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(themeManager.segmentEmptyColor)
                        .frame(height: 6)

                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color(hex: "#10B981"))
                            .frame(width: masteredWidth, height: 6)

                        Rectangle()
                            .fill(Color(hex: "#F59E0B"))
                            .frame(width: progressWidth, height: 6)
                    }
                    .cornerRadius(3)
                }
            }
            .frame(height: 6)

            // Visual Mini-Strip of Kanjis
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(kanjis) { k in
                        Text(k.kanji)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(inkColor)
                            .frame(width: 30, height: 30)
                            .background(k.mastery.badgeColor.opacity(0.15))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(k.mastery.badgeColor.opacity(0.4), lineWidth: 1)
                            )
                    }
                }
                .padding(.vertical, 2)
            }

            // Stats row
            HStack {
                Text("\(mastered)/\(total) Mastered (\(pct)%)")
                    .font(.english(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#10B981"))

                Spacer()

                if inProgress > 0 {
                    Text("\(inProgress) In Progress")
                        .font(.english(size: 11, weight: .regular))
                        .foregroundColor(Color(hex: "#F59E0B"))
                }
            }
        }
        .padding(14)
        .background(cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(cardBorderColor, lineWidth: 1)
        )
    }

    // MARK: - 2. Active Revision Session View
    @ViewBuilder
    private var activeRevisionSessionView: some View {
        let active = viewModel.currentRevisionKanji

        VStack(alignment: .leading, spacing: 18) {
            // Header: Exit button + Card progress + Score
            HStack {
                Button {
                    viewModel.exitRevision()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("Exit Revision")
                            .font(.english(size: 12, weight: .medium))
                    }
                    .foregroundColor(mutedColor)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Card \(viewModel.revisionCurrentIndex + 1) of \(viewModel.revisionWords.count)")
                    .font(.english(size: 13, weight: .bold))
                    .foregroundColor(inkColor)

                Spacer()

                HStack(spacing: 8) {
                    Text("✓ \(viewModel.revisionCorrectCount)")
                        .font(.english(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#10B981"))

                    Text("✗ \(viewModel.revisionIncorrectCount)")
                        .font(.english(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#EF4444"))
                }
            }

            // Hero Card
            VStack(spacing: 16) {
                // Stroke count & level
                HStack {
                    Text("\(active.strokeCount) Strokes")
                        .font(.english(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#8B5CF6"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#8B5CF6").opacity(0.12))
                        .cornerRadius(4)

                    Spacer()

                    Text(active.mastery.rawValue)
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(active.mastery.badgeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(active.mastery.badgeColor.opacity(0.12))
                        .cornerRadius(4)
                }

                // Huge Kanji
                Text(active.kanji)
                    .font(.system(size: 88, weight: .bold))
                    .foregroundColor(inkColor)
                    .padding(.vertical, 4)

                // Kanji with a word prompt
                if let word = viewModel.currentRevisionPromptWord {
                    HStack(spacing: 6) {
                        Text(word.word)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(inkColor)

                        if viewModel.isRevisionAnswerRevealed {
                            Text("(\(word.reading))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#F59E0B"))

                            Text("• \(word.meaning)")
                                .font(.english(size: 12, weight: .regular))
                                .foregroundColor(mutedColor)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(themeManager.canvasColor.opacity(0.6))
                    .cornerRadius(8)
                }

                if !viewModel.isRevisionAnswerRevealed {
                    // Reveal Answer Button
                    Button {
                        viewModel.revealRevisionAnswer()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 13))
                            Text("Reveal Meaning & Readings")
                                .font(.english(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color(hex: "#3B82F6"))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                } else {
                    // Revealed details with visual cues
                    VStack(alignment: .leading, spacing: 12) {
                        // English Meaning
                        VStack(alignment: .leading, spacing: 2) {
                            Text("MEANING")
                                .font(.english(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "#10B981"))

                            Text(active.english)
                                .font(.english(size: 18, weight: .bold))
                                .foregroundColor(inkColor)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "#10B981").opacity(0.09))
                        .cornerRadius(8)

                        // Readings
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ON'YOMI (音)")
                                    .font(.english(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: "#3B82F6"))

                                Text(active.onyomi.isEmpty ? "None" : active.onyomi.joined(separator: ", "))
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(inkColor)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(hex: "#3B82F6").opacity(0.08))
                            .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("KUN'YOMI (訓)")
                                    .font(.english(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: "#F59E0B"))

                                Text(active.kunyomi.isEmpty ? "None" : active.kunyomi.joined(separator: ", "))
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(inkColor)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(hex: "#F59E0B").opacity(0.08))
                            .cornerRadius(8)
                        }

                        // Rating buttons
                        HStack(spacing: 12) {
                            Button {
                                viewModel.rateRevision(isCorrect: false)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark")
                                    Text("Needs Practice")
                                }
                                .font(.english(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: "#EF4444"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(hex: "#EF4444").opacity(0.12))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            Button {
                                viewModel.rateRevision(isCorrect: true)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark")
                                    Text("Mastered")
                                }
                                .font(.english(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: "#10B981"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(hex: "#10B981").opacity(0.12))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(16)
            .background(cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(cardBorderColor, lineWidth: 1)
            )
        }
    }

    // MARK: - 3. Session Finished Summary View
    @ViewBuilder
    private var sessionFinishedView: some View {
        let total = viewModel.revisionCorrectCount + viewModel.revisionIncorrectCount
        let accuracy = total > 0 ? Int(round((Double(viewModel.revisionCorrectCount) / Double(total)) * 100)) : 0

        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("REVISION COMPLETE!")
                    .font(.english(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#10B981"))
                    .tracking(0.8)

                Text("\(accuracy)% Accuracy")
                    .font(.english(size: 32, weight: .bold))
                    .foregroundColor(inkColor)

                Text("You revised \(total) kanjis in Chapter \(viewModel.revisionSelectedChapter)")
                    .font(.english(size: 13, weight: .regular))
                    .foregroundColor(mutedColor)
            }
            .padding(.top, 12)

            HStack(spacing: 12) {
                metricPill(label: "Correct", value: "\(viewModel.revisionCorrectCount)", color: Color(hex: "#10B981"))
                metricPill(label: "Needs Review", value: "\(viewModel.revisionIncorrectCount)", color: Color(hex: "#EF4444"))
                metricPill(label: "Accuracy", value: "\(accuracy)%", color: Color(hex: "#3B82F6"))
            }

            VStack(spacing: 10) {
                Button {
                    viewModel.startRevision(chapter: viewModel.revisionSelectedChapter)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Revise Chapter Again")
                    }
                    .font(.english(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color(hex: "#3B82F6"))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.exitRevision()
                } label: {
                    Text("Return to Chapter List")
                        .font(.english(size: 14, weight: .semibold))
                        .foregroundColor(inkColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(cardBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(cardBorderColor, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardBorderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func metricPill(label: String, value: String, color: Color = Color.primary) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.english(size: 17, weight: .bold))
                .foregroundColor(color == Color.primary ? inkColor : color)

            Text(label)
                .font(.english(size: 10, weight: .medium))
                .foregroundColor(mutedColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(cardBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(cardBorderColor, lineWidth: 1)
        )
    }
}

