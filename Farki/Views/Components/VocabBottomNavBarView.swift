import SwiftUI

struct VocabBottomNavBarView: View {
    @ObservedObject var viewModel: VocabViewModel
    @ObservedObject var navVM: NavigationViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared

    @State private var hasSwipedInCurrentGesture: Bool = false

    private var inkColor: Color {
        themeManager.inkColor
    }

    private var mutedColor: Color {
        themeManager.mutedColor
    }

    private var notchColor: Color {
        themeManager.activeTheme == .dark ? Color(hex: "#A1A1AA") : Color(hex: "#78716C")
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
                    // Test button on left (shows Resume if paused test exists)
                    Button {
                        if viewModel.hasSavedPausedTest {
                            viewModel.resumeTest()
                        } else {
                            viewModel.startTest()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.hasSavedPausedTest ? "play.circle.fill" : "graduationcap.fill")
                                .font(.system(size: 12))
                                .foregroundColor(viewModel.hasSavedPausedTest ? Color(hex: "#F59E0B") : Color(hex: "#3B82F6"))

                            Text(viewModel.hasSavedPausedTest ? "Resume" : "Test")
                                .font(.english(size: 16, weight: .bold))
                                .foregroundColor(inkColor)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background((viewModel.hasSavedPausedTest ? Color(hex: "#F59E0B") : Color(hex: "#3B82F6")).opacity(0.12))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    // Expansive navigation slider taking all remaining space
                    sliderNavControl
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                } else {
                    // Test Mode Active:
                    if viewModel.isTestPaused {
                        // Paused State: Big full-width Resume Test button
                        Button {
                            viewModel.resumeTest()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 13))
                                Text("Resume Test")
                                    .font(.english(size: 15, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color(hex: "#10B981"))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    } else if viewModel.isFlipped {
                        // Requirement 1: After revealing meaning, display ONLY two options: Don't Know and Hard
                        ForEach([VocabViewModel.PracticeRating.again, VocabViewModel.PracticeRating.hard], id: \.self) { rating in
                            Button {
                                viewModel.rateWord(rating)
                            } label: {
                                Text(rating.rawValue)
                                    .font(.english(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: rating.colorHex))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .padding(.horizontal, 4)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color(hex: rating.colorHex).opacity(0.14))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        // Normal Test Mode: All 4 Practice Rating Buttons: Don't Know, Hard, Good, Easy
                        ForEach(VocabViewModel.PracticeRating.allCases, id: \.self) { rating in
                            Button {
                                viewModel.rateWord(rating)
                            } label: {
                                Text(rating.rawValue)
                                    .font(.english(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: rating.colorHex))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .padding(.horizontal, 4)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color(hex: rating.colorHex).opacity(0.12))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 16)
            .padding(.top, 12)
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

    // MARK: - Navigation Slider Control (Bigger & Expansive)
    @ViewBuilder
    private var sliderNavControl: some View {
        HStack(spacing: 0) {
            // Left Diamond (size 10, was 7)
            Image(systemName: "diamond.fill")
                .font(.system(size: 10))
                .foregroundColor(inkColor)

            // Connecting line (height 2.5, was 2)
            Rectangle()
                .fill(inkColor.opacity(0.85))
                .frame(height: 2.5)
                .frame(maxWidth: .infinity)

            // Right Diamond (size 10, was 7)
            Image(systemName: "diamond.fill")
                .font(.system(size: 10))
                .foregroundColor(inkColor)
        }
        .padding(.horizontal, 6)
        .frame(height: 44)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    guard !hasSwipedInCurrentGesture else { return }
                    if value.translation.width < -18 {
                        // Swipe left -> Previous word
                        hasSwipedInCurrentGesture = true
                        viewModel.navigateOneWord(direction: -1)
                    } else if value.translation.width > 18 {
                        // Swipe right -> Next word
                        hasSwipedInCurrentGesture = true
                        viewModel.navigateOneWord(direction: 1)
                    }
                }
                .onEnded { _ in
                    hasSwipedInCurrentGesture = false
                }
        )
    }
}
