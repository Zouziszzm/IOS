import SwiftUI

struct CollapsibleChapterSelectorView: View {
    @ObservedObject var viewModel: VocabViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared

    @State private var isExpanded: Bool = false

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
        VStack(spacing: 0) {
            // MARK: - Header Bar (Always visible, minimal height)
            headerBar

            // MARK: - Collapsible Drawer Content
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
            // Main tap target to toggle expand / collapse
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
                            Text(currentChapterLabel)
                                .font(.english(size: 13, weight: .bold))
                                .foregroundColor(inkColor)

                            Text("• \(viewModel.totalWordCount)w")
                                .font(.english(size: 11, weight: .regular))
                                .foregroundColor(mutedColor)
                        }

                        if !viewModel.filter.selectedSectionCategories.isEmpty {
                            Text(activeSectionsSummary)
                                .font(.english(size: 10, weight: .medium))
                                .foregroundColor(Color(hex: "#3B82F6"))
                        }
                    }

                    Spacer()

                    Text(isExpanded ? "Collapse" : "Select Chapter")
                        .font(.english(size: 11, weight: .medium))
                        .foregroundColor(mutedColor)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(mutedColor)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Chapter Previous / Next Stepper Controls (Works even when collapsed)
            HStack(spacing: 3) {
                Button {
                    viewModel.selectPreviousChapter()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(viewModel.currentSelectedChapter > 1 ? inkColor : mutedColor.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .background(themeManager.segmentEmptyColor.opacity(0.45))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.currentSelectedChapter <= 1)

                Button {
                    viewModel.selectNextChapter()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(viewModel.currentSelectedChapter < 50 ? inkColor : mutedColor.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .background(themeManager.segmentEmptyColor.opacity(0.45))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.currentSelectedChapter >= 50)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var currentChapterLabel: String {
        if let single = viewModel.filter.selectedChapter {
            return "Chapter \(single)"
        } else if !viewModel.filter.selectedChapters.isEmpty {
            let sorted = viewModel.filter.selectedChapters.sorted()
            if sorted.count == 1 {
                return "Chapter \(sorted[0])"
            } else if sorted == Array(1...25) {
                return "JLPT N5 (Ch 1–25)"
            } else if sorted == Array(26...50) {
                return "JLPT N4 (Ch 26–50)"
            } else {
                return "Ch. \(sorted.first ?? 1)–\(sorted.last ?? 25)"
            }
        } else {
            return "All Chapters (1–50)"
        }
    }

    private var activeSectionsSummary: String {
        let titles = viewModel.filter.selectedSectionCategories.map(\.title)
        return titles.joined(separator: ", ")
    }

    // MARK: - Expanded Drawer
    @ViewBuilder
    private var expandedDrawer: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
                .background(cardBorderColor)
                .padding(.horizontal, 12)

            // 1. Quick Presets
            VStack(alignment: .leading, spacing: 6) {
                Text("QUICK CHAPTER PRESETS")
                    .font(.english(size: 10, weight: .bold))
                    .foregroundColor(mutedColor)
                    .tracking(0.6)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        presetChip(title: "All", isSelected: viewModel.isAllChaptersSelected) {
                            viewModel.selectAllChapters()
                        }
                        presetChip(title: "JLPT N5 (1–25)", isSelected: viewModel.filter.selectedChapters == Set(1...25)) {
                            viewModel.selectChapterRange(1...25)
                        }
                        presetChip(title: "JLPT N4 (26–50)", isSelected: viewModel.filter.selectedChapters == Set(26...50)) {
                            viewModel.selectChapterRange(26...50)
                        }
                        presetChip(title: "Ch 1–10", isSelected: viewModel.filter.selectedChapters == Set(1...10)) {
                            viewModel.selectChapterRange(1...10)
                        }
                        presetChip(title: "Ch 11–25", isSelected: viewModel.filter.selectedChapters == Set(11...25)) {
                            viewModel.selectChapterRange(11...25)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)

            // 2. Sections (Word Types Filter)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("SECTIONS")
                        .font(.english(size: 10, weight: .bold))
                        .foregroundColor(mutedColor)
                        .tracking(0.6)

                    Spacer()

                    if !viewModel.filter.selectedSectionCategories.isEmpty {
                        Button {
                            viewModel.clearSectionCategories()
                        } label: {
                            Text("Clear")
                                .font(.english(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "#3B82F6"))
                        }
                        .buttonStyle(.plain)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(VocabSectionCategory.allCases, id: \.self) { section in
                            let isSelected = viewModel.filter.selectedSectionCategories.contains(section)
                            Button {
                                viewModel.toggleSectionCategory(section)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(section.title)
                                        .font(.english(size: 11, weight: isSelected ? .bold : .medium))
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                }
                                .foregroundColor(isSelected ? canvasColor : inkColor)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(isSelected ? inkColor : themeManager.segmentEmptyColor.opacity(0.45))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)

            // 3. Chapter Grid (Ch 1 to 25 / up to 50)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("SELECT CHAPTER (MINNA NO NIHONGO)")
                        .font(.english(size: 10, weight: .bold))
                        .foregroundColor(mutedColor)
                        .tracking(0.6)

                    Spacer()

                    Text("Tap to jump to chapter")
                        .font(.english(size: 10, weight: .regular))
                        .foregroundColor(mutedColor.opacity(0.8))
                }

                let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(1...25, id: \.self) { ch in
                        let isSelected = viewModel.filter.selectedChapter == ch || (viewModel.filter.selectedChapters.count == 1 && viewModel.filter.selectedChapters.contains(ch))
                        let count = viewModel.wordCount(forChapter: ch)
                        let hasWords = count > 0

                        Button {
                            viewModel.selectSingleChapter(ch)
                        } label: {
                            VStack(spacing: 1) {
                                Text("Ch.\(ch)")
                                    .font(.english(size: 12, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? canvasColor : (hasWords ? inkColor : mutedColor.opacity(0.4)))

                                Text("\(count)w")
                                    .font(.english(size: 9, weight: .regular))
                                    .foregroundColor(isSelected ? canvasColor.opacity(0.85) : mutedColor.opacity(hasWords ? 0.8 : 0.3))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(isSelected ? inkColor : themeManager.segmentEmptyColor.opacity(hasWords ? 0.38 : 0.15))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func presetChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.english(size: 11, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? canvasColor : inkColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? inkColor : themeManager.segmentEmptyColor.opacity(0.45))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

