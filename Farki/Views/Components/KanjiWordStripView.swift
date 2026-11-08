import SwiftUI

struct KanjiWordStripView: View {
    @ObservedObject var viewModel: KanjiViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared

    private var inkColor: Color {
        themeManager.inkColor
    }

    private var mutedColor: Color {
        themeManager.mutedColor
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                        let isSelected = (index == viewModel.currentIndex)

                        Button {
                            viewModel.selectKanji(at: index)
                        } label: {
                            VStack(spacing: 4) {
                                // Top stroke count pill
                                HStack(spacing: 2) {
                                    Text("\(item.strokeCount)画")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(isSelected ? .white.opacity(0.85) : mutedColor)

                                    Spacer(minLength: 0)

                                    Circle()
                                        .fill(item.mastery.badgeColor)
                                        .frame(width: 5, height: 5)
                                }

                                Spacer(minLength: 0)

                                // Prominent Kanji Character
                                Text(item.kanji)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(isSelected ? .white : inkColor)

                                Spacer(minLength: 0)

                                // Meaning preview
                                Text(item.english)
                                    .font(.english(size: 11, weight: .medium))
                                    .foregroundColor(isSelected ? .white.opacity(0.9) : mutedColor)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(width: 72, height: 86)
                            .background(
                                isSelected
                                    ? Color(hex: "#3B82F6")
                                    : (themeManager.activeTheme == .dark ? Color(hex: "#181614") : Color(hex: "#F5F5F4"))
                            )
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        isSelected ? Color.clear : themeManager.activeTheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
            .onChange(of: viewModel.currentIndex) { newIndex in
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
}

