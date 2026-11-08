import SwiftUI

struct KanjiBottomNavBarView: View {
    @ObservedObject var viewModel: KanjiViewModel
    @ObservedObject var navVM: NavigationViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared

    private var inkColor: Color {
        themeManager.inkColor
    }

    private var mutedColor: Color {
        themeManager.mutedColor
    }

    var body: some View {
        VStack(spacing: 0) {
            // Hairline divider
            Rectangle()
                .fill(themeManager.hairlineColor)
                .frame(height: 0.5)

            HStack(alignment: .center, spacing: 10) {
                if !viewModel.isTestModeActive {
                    // Normal Mode:
                    // 1. Test button on left
                    Button {
                        viewModel.startTest()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "#3B82F6"))

                            Text("Test")
                                .font(.english(size: 16, weight: .bold))
                                .foregroundColor(inkColor)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(Color(hex: "#3B82F6").opacity(0.12))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    // 2. Expansive Slider Navigation Control
                    sliderNavControl
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                } else {
                    // Test Mode Active:
                    if viewModel.isTestPaused {
                        Button {
                            viewModel.resumeTest()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                Text("Resume Test")
                            }
                            .font(.english(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color(hex: "#10B981"))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    } else if !viewModel.isTestAnswerRevealed {
                        // Check & Reveal Button
                        Button {
                            viewModel.checkAnswer()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "eye.fill")
                                Text("Check & Reveal")
                            }
                            .font(.english(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color(hex: "#3B82F6"))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Revealed: 2 Quick Action Buttons
                        Button {
                            viewModel.rateTestItem(status: .learning, isCorrect: false)
                        } label: {
                            Text("Needs Review")
                                .font(.english(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: "#EF4444"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(hex: "#EF4444").opacity(0.14))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button {
                            viewModel.rateTestItem(status: .mastered, isCorrect: true)
                        } label: {
                            Text("Got It Right")
                                .font(.english(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: "#10B981"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(hex: "#10B981").opacity(0.14))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
        .safeAreaPadding(.bottom)
        .background {
            ZStack {
                VisualEffectBlur(
                    blurStyle: themeManager.activeTheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight,
                    intensity: 0.85
                )
                (themeManager.activeTheme == .dark ? Color.black.opacity(0.08) : Color.white.opacity(0.12))
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Slider Navigation Control
    @ViewBuilder
    private var sliderNavControl: some View {
        let total = max(1, viewModel.items.count)
        let current = viewModel.currentIndex + 1

        HStack(spacing: 8) {
            // Previous Item Button
            Button {
                viewModel.previousKanji()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(viewModel.currentIndex > 0 ? inkColor : mutedColor.opacity(0.3))
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(viewModel.currentIndex <= 0)
            .buttonStyle(.plain)

            // Scrubber Bar & Index Label
            GeometryReader { geo in
                let progress = total > 1 ? CGFloat(viewModel.currentIndex) / CGFloat(total - 1) : 0
                let trackWidth = max(0, geo.size.width)

                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(themeManager.segmentEmptyColor)
                        .frame(height: 4)

                    // Filled Track
                    Capsule()
                        .fill(Color(hex: "#3B82F6"))
                        .frame(width: trackWidth * progress, height: 4)

                    // Thumb
                    Circle()
                        .fill(Color(hex: "#3B82F6"))
                        .frame(width: 14, height: 14)
                        .offset(x: max(0, min(trackWidth - 14, (trackWidth * progress) - 7)))
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let fraction = max(0, min(1, val.location.x / trackWidth))
                            let target = Int(round(fraction * CGFloat(total - 1)))
                            if target != viewModel.currentIndex {
                                viewModel.selectKanji(at: target)
                            }
                        }
                )
            }
            .frame(height: 20)

            // Index Indicator Text
            Text("\(current)/\(total)")
                .font(.english(size: 12, weight: .bold))
                .foregroundColor(mutedColor)
                .frame(minWidth: 40)

            // Next Item Button
            Button {
                viewModel.nextKanji()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(viewModel.currentIndex < total - 1 ? inkColor : mutedColor.opacity(0.3))
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(viewModel.currentIndex >= total - 1)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .background(themeManager.activeTheme == .dark ? Color(hex: "#181614") : Color(hex: "#F5F5F4"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeManager.hairlineColor, lineWidth: 1)
        )
    }
}

