import SwiftUI

struct KanjiDetailCardView: View {
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
        VStack(alignment: .leading, spacing: 20) {
            // MARK: - 1. Top Badges Row (JLPT, Stroke Count, Audio, Mastery)
            HStack(spacing: 8) {
                // JLPT Level Badge
                Text(item.level.rawValue)
                    .font(.english(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#3B82F6"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#3B82F6").opacity(0.12))
                    .cornerRadius(6)

                // Stroke Count Badge
                HStack(spacing: 3) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 10))
                    Text("\(item.strokeCount) Strokes")
                        .font(.english(size: 12, weight: .semibold))
                }
                .foregroundColor(Color(hex: "#8B5CF6"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#8B5CF6").opacity(0.12))
                .cornerRadius(6)

                Spacer()

                // Audio Speaker Button
                Button {
                    let reading = item.kunyomi.first ?? item.onyomi.first
                    viewModel.playAudio(for: item.kanji, phonetic: reading)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 12))
                        Text("Pronounce")
                            .font(.english(size: 12, weight: .medium))
                    }
                    .foregroundColor(inkColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(themeManager.hairlineColor)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                // Mastery Status Badge (Clickable)
                Button {
                    viewModel.cycleActiveKanjiMastery()
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(item.mastery.badgeColor)
                            .frame(width: 7, height: 7)

                        Text(item.mastery.rawValue)
                            .font(.english(size: 12, weight: .bold))
                            .foregroundColor(item.mastery.badgeColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(item.mastery.badgeColor.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            // MARK: - 2. Prominent Kanji Hero Section
            HStack(alignment: .center) {
                Spacer()
                VStack(spacing: 6) {
                    Text(item.kanji)
                        .font(.system(size: 82, weight: .bold))
                        .foregroundColor(inkColor)
                        .minimumScaleFactor(0.8)

                    Text(item.english)
                        .font(.english(size: 22, weight: .bold))
                        .foregroundColor(inkColor)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
            .padding(.vertical, 8)

            // MARK: - 3. Readings Section (On'yomi & Kun'yomi)
            VStack(alignment: .leading, spacing: 12) {
                Text("READINGS")
                    .font(.english(size: 11, weight: .bold))
                    .foregroundColor(mutedColor)
                    .tracking(0.6)

                HStack(alignment: .top, spacing: 12) {
                    // On'yomi (音読み - Chinese reading)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("音")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#3B82F6"))
                                .cornerRadius(4)

                            Text("ON'YOMI")
                                .font(.english(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "#3B82F6"))
                        }

                        if item.onyomi.isEmpty {
                            Text("None")
                                .font(.english(size: 13, weight: .regular))
                                .foregroundColor(mutedColor)
                        } else {
                            Text(item.onyomi.joined(separator: " • "))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(inkColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(hex: "#3B82F6").opacity(0.08))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#3B82F6").opacity(0.2), lineWidth: 1)
                    )

                    // Kun'yomi (訓読み - Japanese reading)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("訓")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#F59E0B"))
                                .cornerRadius(4)

                            Text("KUN'YOMI")
                                .font(.english(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "#F59E0B"))
                        }

                        if item.kunyomi.isEmpty {
                            Text("None")
                                .font(.english(size: 13, weight: .regular))
                                .foregroundColor(mutedColor)
                        } else {
                            Text(item.kunyomi.joined(separator: " • "))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(inkColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(hex: "#F59E0B").opacity(0.08))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#F59E0B").opacity(0.2), lineWidth: 1)
                    )
                }
            }

            // MARK: - 4. Kanji with a Word (Chapter Compound Vocabulary)
            if !item.words.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("KANJI WITH WORDS (CHAPTER \(item.chapterNumber))")
                            .font(.english(size: 11, weight: .bold))
                            .foregroundColor(mutedColor)
                            .tracking(0.6)

                        Spacer()

                        Text("\(item.words.count) words")
                            .font(.english(size: 11, weight: .regular))
                            .foregroundColor(mutedColor)
                    }

                    VStack(spacing: 8) {
                        ForEach(item.words) { word in
                            HStack(alignment: .center, spacing: 10) {
                                Button {
                                    viewModel.playAudio(for: word.word, phonetic: word.reading)
                                } label: {
                                    Image(systemName: "speaker.wave.1.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "#3B82F6"))
                                        .frame(width: 26, height: 26)
                                        .background(Color(hex: "#3B82F6").opacity(0.12))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(word.word)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(inkColor)

                                        Text(word.reading)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(Color(hex: "#F59E0B"))
                                    }

                                    Text(word.meaning)
                                        .font(.english(size: 13, weight: .regular))
                                        .foregroundColor(mutedColor)
                                }

                                Spacer()
                            }
                            .padding(10)
                            .background(themeManager.canvasColor.opacity(0.5))
                            .cornerRadius(8)
                        }
                    }
                }
            }

            // MARK: - 5. Example Sentences
            if !item.examples.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("EXAMPLE SENTENCES")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)
                        .tracking(0.6)

                    VStack(spacing: 8) {
                        ForEach(item.examples) { ex in
                            HStack(alignment: .top, spacing: 10) {
                                Button {
                                    viewModel.playAudio(for: ex.japanese)
                                } label: {
                                    Image(systemName: "speaker.wave.2")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "#10B981"))
                                        .frame(width: 28, height: 28)
                                        .background(Color(hex: "#10B981").opacity(0.12))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(ex.japanese)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(inkColor)
                                        .lineSpacing(3)

                                    Text(ex.translation)
                                        .font(.english(size: 13, weight: .regular))
                                        .foregroundColor(mutedColor)
                                }

                                Spacer()
                            }
                            .padding(10)
                            .background(themeManager.canvasColor.opacity(0.5))
                            .cornerRadius(8)
                        }
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

