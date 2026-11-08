import SwiftUI

struct VocabChapterStripView: View {
    @ObservedObject var viewModel: VocabViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared

    private var inkColor: Color {
        themeManager.inkColor
    }

    private let itemWidth: CGFloat = 64
    private let itemHeight: CGFloat = 42
    private let itemSpacing: CGFloat = 14

    private var itemPitch: CGFloat {
        itemWidth + itemSpacing
    }

    /// Display chapters 1..25 (or up to 50 if Book 2 chapters exist)
    private var chapters: [Int] {
        viewModel.chapterList
    }

    var body: some View {
        GeometryReader { geometry in
            let activeIndex = resolvedActiveIndex()
            let centerOffset = (geometry.size.width / 2) - (itemWidth / 2)
            let currentOffset = centerOffset - (CGFloat(activeIndex) * itemPitch) + viewModel.chapterStripDragOffset

            ZStack(alignment: .leading) {
                // Interactive touch surface
                Color.clear
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .contentShape(Rectangle())

                // Strip of chapters matching word strip UI
                HStack(spacing: itemSpacing) {
                    ForEach(chapters.indices, id: \.self) { index in
                        let chapter = chapters[index]
                        let isSelected = viewModel.isChapterSelected(chapter)
                        let hasWords = viewModel.wordCount(forChapter: chapter) > 0
                        let offsetFromCenter = CGFloat(index - activeIndex)

                        // Visual fading & progressive blur toward edges
                        let distance = abs(offsetFromCenter - (viewModel.chapterStripDragOffset / itemPitch))
                        let blurRadius = max(0, (distance - 0.8) * 1.4)
                        let opacity = max(0.24, 1.0 - (distance * 0.32))

                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                // Empty star if not selected, filled star if selected
                                Image(systemName: isSelected ? "star.fill" : "star")
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? Color(hex: "#F59E0B") : inkColor.opacity(hasWords ? 0.75 : 0.3))

                                Text("\(chapter)")
                                    .font(.english(size: 18, weight: isSelected ? .bold : .regular))
                                    .foregroundColor(isSelected ? inkColor : inkColor.opacity(hasWords ? 0.85 : 0.35))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }

                            // Underline indicator matching the word strip style
                            Rectangle()
                                .fill(isSelected ? inkColor : Color.clear)
                                .frame(height: 2)
                                .frame(width: 38)
                                .opacity(isSelected ? 1.0 : 0.0)
                        }
                        .frame(width: itemWidth, height: itemHeight)
                        .blur(radius: blurRadius)
                        .opacity(opacity)
                        .scaleEffect(isSelected ? 1.06 : 0.94)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                viewModel.toggleChapterSelection(chapter)
                                viewModel.chapterStripCenteredIndex = index
                            }
                        }
                    }
                }
                .offset(x: currentOffset)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
            .clipped()
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        viewModel.updateChapterStripDrag(offset: value.translation.width * 0.8)
                    }
                    .onEnded { value in
                        let translation = value.translation.width
                        let velocity = value.predictedEndTranslation.width - value.translation.width
                        viewModel.endChapterStripDrag(translation: translation, velocity: velocity)
                    }
            )
        }
        .frame(height: 48)
        .onAppear {
            viewModel.syncChapterStripIndex()
        }
        .onChange(of: viewModel.currentWord.chapterNumber) { _, _ in
            viewModel.syncChapterStripIndex()
        }
    }

    private func resolvedActiveIndex() -> Int {
        if viewModel.chapterStripCenteredIndex >= 0 && viewModel.chapterStripCenteredIndex < chapters.count {
            return viewModel.chapterStripCenteredIndex
        }
        return 0
    }
}
