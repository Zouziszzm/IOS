import SwiftUI

struct KanjiTestCardView: View {
    let item: KanjiItem
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
        VStack(alignment: .leading, spacing: 18) {
            // MARK: - Top Question Header
            HStack {
                HStack(spacing: 6) {
                    Text("KANJI TEST")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#3B82F6"))
                        .tracking(0.6)

                    Text("• Question \(viewModel.testCurrentIndex + 1) of \(viewModel.testItems.count)")
                        .font(.english(size: 11, weight: .semibold))
                        .foregroundColor(mutedColor)
                }

                Spacer()

                HStack(spacing: 6) {
                    Text("\(item.strokeCount) Strokes")
                        .font(.english(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#8B5CF6"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#8B5CF6").opacity(0.12))
                        .cornerRadius(4)

                    Text(item.level.rawValue)
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#3B82F6"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#3B82F6").opacity(0.12))
                        .cornerRadius(4)
                }
            }

            // MARK: - Hero Prompt: Kanji + Kanji with a Word (Meaning/Readings Hidden)
            VStack(spacing: 12) {
                // Prominent Kanji Character
                Text(item.kanji)
                    .font(.system(size: 88, weight: .bold))
                    .foregroundColor(inkColor)
                    .padding(.top, 4)

                // Kanji with a Word contextual prompt
                if let promptWord = viewModel.currentTestPromptWord {
                    VStack(spacing: 4) {
                        Text("KANJI WITH A WORD")
                            .font(.english(size: 10, weight: .bold))
                            .foregroundColor(mutedColor)
                            .tracking(0.8)

                        HStack(spacing: 6) {
                            Text(promptWord.word)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(inkColor)

                            if viewModel.isTestAnswerRevealed {
                                Text("(\(promptWord.reading))")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(hex: "#F59E0B"))
                            }
                        }

                        if viewModel.isTestAnswerRevealed {
                            Text(promptWord.meaning)
                                .font(.english(size: 13, weight: .regular))
                                .foregroundColor(mutedColor)
                        } else {
                            Text("Context compound from Chapter \(item.chapterNumber)")
                                .font(.english(size: 11, weight: .regular))
                                .foregroundColor(mutedColor.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(themeManager.canvasColor.opacity(0.6))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(cardBorderColor, lineWidth: 1)
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)

            // MARK: - Writing / Input Area
            if !viewModel.isTestAnswerRevealed {
                VStack(alignment: .leading, spacing: 14) {
                    Text("WRITE YOUR RECALL (MEANING & READINGS)")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)
                        .tracking(0.6)

                    // 1. Meaning input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. English Meaning:")
                            .font(.english(size: 12, weight: .semibold))
                            .foregroundColor(inkColor)

                        TextField("Type meaning (e.g. \(item.english.components(separatedBy: ",").first ?? "meaning"))...", text: $viewModel.inputMeaning)
                            .font(.english(size: 15, weight: .regular))
                            .foregroundColor(inkColor)
                            .padding(.horizontal, 12)
                            .frame(height: 42)
                            .background(themeManager.canvasColor)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(cardBorderColor, lineWidth: 1)
                            )
                    }

                    // 2. On'yomi input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("2. On'yomi (音読み):")
                            .font(.english(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#3B82F6"))

                        TextField("Type On'yomi (Katakana or Romaji)...", text: $viewModel.inputOnyomi)
                            .font(.system(size: 14))
                            .foregroundColor(inkColor)
                            .padding(.horizontal, 12)
                            .frame(height: 42)
                            .background(themeManager.canvasColor)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(cardBorderColor, lineWidth: 1)
                            )
                    }

                    // 3. Kun'yomi input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("3. Kun'yomi (訓読み):")
                            .font(.english(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#F59E0B"))

                        TextField("Type Kun'yomi (Hiragana or Romaji)...", text: $viewModel.inputKunyomi)
                            .font(.system(size: 14))
                            .foregroundColor(inkColor)
                            .padding(.horizontal, 12)
                            .frame(height: 42)
                            .background(themeManager.canvasColor)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(cardBorderColor, lineWidth: 1)
                            )
                    }

                    // Check / Reveal Button
                    Button {
                        viewModel.checkAnswer()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                            Text("Check & Reveal Answer")
                                .font(.english(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color(hex: "#3B82F6"))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            } else {
                // MARK: - Answer Revealed with Visual Cues
                VStack(alignment: .leading, spacing: 14) {
                    Text("VERIFICATION & ANSWER KEY")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)
                        .tracking(0.6)

                    // 1. English Meaning Verification
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("MEANING")
                                .font(.english(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "#10B981"))

                            Spacer()

                            if viewModel.isMeaningMatch {
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Match")
                                }
                                .font(.english(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "#10B981"))
                            }
                        }

                        Text(item.english)
                            .font(.english(size: 18, weight: .bold))
                            .foregroundColor(inkColor)

                        if !viewModel.inputMeaning.isEmpty {
                            Text("Your input: \"\(viewModel.inputMeaning)\"")
                                .font(.english(size: 12, weight: .regular))
                                .foregroundColor(mutedColor)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#10B981").opacity(0.09))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#10B981").opacity(0.3), lineWidth: 1)
                    )

                    // 2. On'yomi & Kun'yomi Verification Row
                    HStack(alignment: .top, spacing: 10) {
                        // On'yomi
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("ON'YOMI (音)")
                                    .font(.english(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: "#3B82F6"))

                                Spacer()

                                if viewModel.isOnyomiMatch {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: "#10B981"))
                                }
                            }

                            Text(item.onyomi.isEmpty ? "None" : item.onyomi.joined(separator: ", "))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(inkColor)

                            if !viewModel.inputOnyomi.isEmpty {
                                Text("You: \(viewModel.inputOnyomi)")
                                    .font(.system(size: 11))
                                    .foregroundColor(mutedColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(hex: "#3B82F6").opacity(0.08))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "#3B82F6").opacity(0.25), lineWidth: 1)
                        )

                        // Kun'yomi
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("KUN'YOMI (訓)")
                                    .font(.english(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: "#F59E0B"))

                                Spacer()

                                if viewModel.isKunyomiMatch {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: "#10B981"))
                                }
                            }

                            Text(item.kunyomi.isEmpty ? "None" : item.kunyomi.joined(separator: ", "))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(inkColor)

                            if !viewModel.inputKunyomi.isEmpty {
                                Text("You: \(viewModel.inputKunyomi)")
                                    .font(.system(size: 11))
                                    .foregroundColor(mutedColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(hex: "#F59E0B").opacity(0.08))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "#F59E0B").opacity(0.25), lineWidth: 1)
                        )
                    }

                    // Self Assessment Question
                    Text("HOW WELL DID YOU KNOW THIS KANJI?")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)
                        .tracking(0.6)
                        .padding(.top, 4)

                    // 4 Rating Buttons
                    HStack(spacing: 8) {
                        Button {
                            viewModel.rateTestItem(status: .unlearned, isCorrect: false)
                        } label: {
                            VStack(spacing: 2) {
                                Text("Don't Know")
                                    .font(.english(size: 13, weight: .bold))
                            }
                            .foregroundColor(Color(hex: "#EF4444"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(Color(hex: "#EF4444").opacity(0.12))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button {
                            viewModel.rateTestItem(status: .learning, isCorrect: false)
                        } label: {
                            VStack(spacing: 2) {
                                Text("Hard")
                                    .font(.english(size: 13, weight: .bold))
                            }
                            .foregroundColor(Color(hex: "#F59E0B"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(Color(hex: "#F59E0B").opacity(0.12))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button {
                            viewModel.rateTestItem(status: .learning, isCorrect: true)
                        } label: {
                            VStack(spacing: 2) {
                                Text("Good")
                                    .font(.english(size: 13, weight: .bold))
                            }
                            .foregroundColor(Color(hex: "#3B82F6"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(Color(hex: "#3B82F6").opacity(0.12))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button {
                            viewModel.rateTestItem(status: .mastered, isCorrect: true)
                        } label: {
                            VStack(spacing: 2) {
                                Text("Easy")
                                    .font(.english(size: 13, weight: .bold))
                            }
                            .foregroundColor(Color(hex: "#10B981"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(Color(hex: "#10B981").opacity(0.12))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
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

