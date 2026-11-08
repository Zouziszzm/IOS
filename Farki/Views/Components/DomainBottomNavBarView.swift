import SwiftUI

struct DomainBottomNavBarView: View {
    let isTestModeActive: Bool
    let showTestNextButton: Bool
    let onStartTest: () -> Void
    let onNavigate: (Int) -> Void
    let onRate: (VocabViewModel.PracticeRating) -> Void

    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared
    @State private var hasSwipedInCurrentGesture: Bool = false

    private var inkColor: Color { themeManager.inkColor }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(themeManager.hairlineColor)
                .frame(height: 0.5)

            HStack(alignment: .center, spacing: 10) {
                if !isTestModeActive {
                    Button {
                        onStartTest()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 12))
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

                    sliderNavControl
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                } else {
                    ForEach(VocabViewModel.PracticeRating.allCases, id: \.self) { rating in
                        let isDisabled = showTestNextButton && (rating == .good || rating == .easy)
                        Button {
                            onRate(rating)
                        } label: {
                            Text(rating.rawValue)
                                .font(.english(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: rating.colorHex))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 4)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(hex: rating.colorHex).opacity(isDisabled ? 0.05 : 0.12))
                                .cornerRadius(8)
                                .opacity(isDisabled ? 0.3 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .disabled(isDisabled)
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

    @ViewBuilder
    private var sliderNavControl: some View {
        HStack(spacing: 0) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 10))
                .foregroundColor(inkColor)

            Rectangle()
                .fill(inkColor.opacity(0.85))
                .frame(height: 2.5)
                .frame(maxWidth: .infinity)

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
                        hasSwipedInCurrentGesture = true
                        onNavigate(-1)
                    } else if value.translation.width > 18 {
                        hasSwipedInCurrentGesture = true
                        onNavigate(1)
                    }
                }
                .onEnded { _ in
                    hasSwipedInCurrentGesture = false
                }
        )
    }
}

