import SwiftUI

struct KanjiChaptersBreakdownView: View {
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
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("MINNA NO NIHONGO KANJI CURRICULUM")
                    .font(.english(size: 11, weight: .bold))
                    .foregroundColor(mutedColor)
                    .tracking(0.8)

                Text("Chapter-wise Breakdown")
                    .font(.english(size: 20, weight: .bold))
                    .foregroundColor(inkColor)

                Text("Explore the kanjis introduced and practiced across each chapter of Minna no Nihongo.")
                    .font(.english(size: 12, weight: .regular))
                    .foregroundColor(mutedColor)
            }
            .padding(.bottom, 6)

            // Chapters Grid / List
            VStack(spacing: 12) {
                ForEach(viewModel.availableChapters) { ch in
                    chapterCard(for: ch)
                }
            }
        }
    }

    @ViewBuilder
    private func chapterCard(for sheet: KanjiChapterSheet) -> some View {
        let isCurrent = sheet.chapterNumber == viewModel.selectedChapter
        let kanjis = sheet.kanjis
        let count = kanjis.count
        let mastered = kanjis.filter { $0.mastery == .mastered }.count

        Button {
            viewModel.selectChapter(sheet.chapterNumber)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                viewModel.selectedTabMode = .study
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Chapter \(sheet.chapterNumber)")
                                .font(.english(size: 16, weight: .bold))
                                .foregroundColor(isCurrent ? Color(hex: "#3B82F6") : inkColor)

                            Text("• \(count) Kanjis")
                                .font(.english(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#3B82F6"))

                            if isCurrent {
                                Text("ACTIVE")
                                    .font(.english(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: "#3B82F6"))
                                    .cornerRadius(4)
                            }
                        }

                        Text(sheet.title)
                            .font(.system(size: 12))
                            .foregroundColor(inkColor)

                        Text(sheet.englishTitle)
                            .font(.english(size: 12, weight: .regular))
                            .foregroundColor(mutedColor)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(mutedColor)
                }

                // Grid of kanjis in this chapter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(kanjis) { k in
                            VStack(spacing: 2) {
                                Text(k.kanji)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(inkColor)

                                Text("\(k.strokeCount)画")
                                    .font(.system(size: 9))
                                    .foregroundColor(mutedColor)
                            }
                            .frame(width: 36, height: 42)
                            .background(k.mastery.badgeColor.opacity(0.12))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(k.mastery.badgeColor.opacity(0.35), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }

                // Mastery summary
                HStack {
                    Text("\(mastered)/\(count) Mastered")
                        .font(.english(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#10B981"))

                    Spacer()

                    Text("Tap to Study →")
                        .font(.english(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#3B82F6"))
                }
            }
            .padding(14)
            .background(cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isCurrent ? Color(hex: "#3B82F6").opacity(0.6) : cardBorderColor, lineWidth: isCurrent ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

