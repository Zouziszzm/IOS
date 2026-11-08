import SwiftUI

struct CollapsibleKanjiChapterSelectorView: View {
    @ObservedObject var viewModel: KanjiViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared

    @State private var isExpanded: Bool = false

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
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            // Collapsible Content
            if isExpanded {
                expandedDrawer
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(cardBorderColor, lineWidth: 1)
        )
    }

    // MARK: - Header Bar
    @ViewBuilder
    private var headerBar: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                    viewModel.isChapterSelectorExpanded = isExpanded
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "slider.horizontal.3")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(inkColor)

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text("Chapter \(viewModel.selectedChapter)")
                                .font(.english(size: 14, weight: .bold))
                                .foregroundColor(inkColor)

                            Text("• \(viewModel.totalChapterKanjiCount) Kanjis")
                                .font(.english(size: 12, weight: .regular))
                                .foregroundColor(mutedColor)
                        }

                        if let sheet = viewModel.currentChapterSheet {
                            Text(sheet.englishTitle)
                                .font(.english(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "#3B82F6"))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Text(isExpanded ? "Collapse" : "Select Chapter")
                        .font(.english(size: 12, weight: .medium))
                        .foregroundColor(mutedColor)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)
                }
                .padding(.horizontal, 12)
                .frame(height: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Fast Previous Chapter Button
            Button {
                if viewModel.selectedChapter > 1 {
                    viewModel.selectChapter(viewModel.selectedChapter - 1)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(viewModel.selectedChapter > 1 ? inkColor : mutedColor.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .disabled(viewModel.selectedChapter <= 1)
            .buttonStyle(.plain)

            // Fast Next Chapter Button
            let maxCh = max(1, viewModel.availableChapters.map(\.chapterNumber).max() ?? 25)
            Button {
                if viewModel.selectedChapter < maxCh {
                    viewModel.selectChapter(viewModel.selectedChapter + 1)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(viewModel.selectedChapter < maxCh ? inkColor : mutedColor.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .disabled(viewModel.selectedChapter >= maxCh)
            .buttonStyle(.plain)
            .padding(.trailing, 6)
        }
    }

    // MARK: - Expanded Drawer
    @ViewBuilder
    private var expandedDrawer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .background(cardBorderColor)

            Text("MINNA NO NIHONGO CHAPTERS")
                .font(.english(size: 11, weight: .bold))
                .foregroundColor(mutedColor)
                .tracking(0.6)
                .padding(.horizontal, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.availableChapters) { ch in
                        let isSelected = ch.chapterNumber == viewModel.selectedChapter
                        let count = ch.kanjis.count

                        Button {
                            viewModel.selectChapter(ch.chapterNumber)
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                isExpanded = false
                                viewModel.isChapterSelectorExpanded = false
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("Ch \(ch.chapterNumber)")
                                        .font(.english(size: 13, weight: isSelected ? .bold : .semibold))
                                        .foregroundColor(isSelected ? .white : inkColor)

                                    Spacer()

                                    Text("\(count) Kj")
                                        .font(.english(size: 11, weight: .bold))
                                        .foregroundColor(isSelected ? .white.opacity(0.85) : Color(hex: "#3B82F6"))
                                }

                                Text(ch.title)
                                    .font(.system(size: 10))
                                    .foregroundColor(isSelected ? .white.opacity(0.9) : mutedColor)
                                    .lineLimit(1)

                                Text(ch.englishTitle)
                                    .font(.english(size: 10, weight: .regular))
                                    .foregroundColor(isSelected ? .white.opacity(0.75) : mutedColor.opacity(0.8))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(width: 140, alignment: .leading)
                            .background(
                                isSelected
                                    ? Color(hex: "#3B82F6")
                                    : (themeManager.activeTheme == .dark ? Color(hex: "#1E1C1A") : Color.white)
                            )
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color.clear : cardBorderColor, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 12)
        }
    }
}

