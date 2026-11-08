import SwiftUI

struct VocabWordStripView: View {
    @ObservedObject var viewModel: VocabViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared

    @State private var dragOffset: CGFloat = 0

    private var inkColor: Color {
        themeManager.inkColor
    }

    private let itemWidth: CGFloat = 86
    private let itemHeight: CGFloat = 42
    private let itemSpacing: CGFloat = 14

    private var itemPitch: CGFloat {
        itemWidth + itemSpacing
    }

    private var activeList: [VocabItem] {
        viewModel.isTestModeActive ? viewModel.testItems : viewModel.items
    }

    var body: some View {
        GeometryReader { geometry in
            let centerOffset = (geometry.size.width / 2) - (itemWidth / 2)
            let currentOffset = centerOffset - (CGFloat(viewModel.currentIndex) * itemPitch) + dragOffset

            ZStack(alignment: .leading) {
                Color.clear
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .contentShape(Rectangle())

                HStack(spacing: itemSpacing) {
                    ForEach(activeList.indices, id: \.self) { index in
                        let item = activeList[index]
                        let offsetFromCenter = CGFloat(index - viewModel.currentIndex)
                        let isSelected = (index == viewModel.currentIndex)

                        let distance = abs(offsetFromCenter - (dragOffset / itemPitch))
                        let blurRadius = max(0, (distance - 0.5) * 1.5)
                        let opacity = max(0.22, 1.0 - (distance * 0.35))

                        VStack(spacing: 4) {
                            Text(item.stripDisplay)
                                .font(.japanese(size: 16, weight: isSelected ? .bold : .regular))
                                .foregroundColor(inkColor)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)

                            Rectangle()
                                .fill(isSelected ? inkColor : Color.clear)
                                .frame(height: 2)
                                .frame(width: 44)
                                .opacity(isSelected ? 1.0 : 0.0)
                        }
                        .frame(width: itemWidth, height: itemHeight)
                        .blur(radius: blurRadius)
                        .opacity(opacity)
                        .scaleEffect(isSelected ? 1.06 : 0.94)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !viewModel.isTestModeActive else { return }
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                viewModel.selectWord(at: index)
                            }
                        }
                    }
                }
                .offset(x: currentOffset)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
            .clipped()
            .gesture(
                viewModel.isTestModeActive ? nil :
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        dragOffset = value.translation.width * 0.8
                    }
                    .onEnded { value in
                        let translation = value.translation.width
                        let velocity = value.predictedEndTranslation.width - value.translation.width
                        let speed = abs(velocity)
                        let step: Int
                        if speed > 700 || abs(translation) > 180 {
                            step = min(10, max(3, Int(round(speed / 130))))
                        } else if abs(translation) > 25 || speed > 160 {
                            step = 1
                        } else {
                            step = 0
                        }

                        let direction = (translation < 0 || velocity < -100) ? 1 : -1
                        let targetIndex = max(0, min(activeList.count - 1, viewModel.currentIndex + (direction * step)))

                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                            dragOffset = 0
                            if step > 0 && targetIndex != viewModel.currentIndex {
                                viewModel.selectWord(at: targetIndex)
                            }
                        }
                    }
            )
        }
        .frame(height: 48)
    }
}
