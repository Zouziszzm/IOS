import SwiftUI

/// Slide-out Practice (れんしゅう) Bottom Navigation Bar matching VocabBottomNavBarView
struct SRSBottomNavBarView: View {
    @ObservedObject var viewModel: SRSViewModel
    @ObservedObject var navVM: NavigationViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared
    @ObservedObject var settingsManager: AppSettingsManager = AppSettingsManager.shared

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

            // Rating Buttons Bar is always displayed
            ratingButtonsBar
        }
        .safeAreaPadding(.bottom)
        .background {
            ZStack {
                VisualEffectBlur(
                    blurStyle: themeManager.activeTheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight,
                    intensity: 0.85
                )

                (themeManager.activeTheme == .dark ? Color.black.opacity(0.12) : Color.white.opacity(0.18))
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Rating Buttons Bar
    private var ratingButtonsBar: some View {
        let projections = viewModel.currentProjections

        return HStack(alignment: .center, spacing: 8) {
            // 1. Again Button
            ratingButton(
                title: "もう一度",
                romaji: "Mou ichido",
                english: "Again",
                interval: projections[.again]?.displayInterval ?? "1m",
                color: Color(hex: "#EF4444"),
                rating: .again
            )

            // 2. Hard Button
            ratingButton(
                title: "難しい",
                romaji: "Muzukashii",
                english: "Hard",
                interval: projections[.hard]?.displayInterval ?? "10m",
                color: Color(hex: "#F59E0B"),
                rating: .hard
            )

            // 3. Good Button
            ratingButton(
                title: "正解",
                romaji: "Seikai",
                english: "Good",
                interval: projections[.good]?.displayInterval ?? "1d",
                color: Color(hex: "#10B981"),
                rating: .good
            )

            // 4. Easy Button
            ratingButton(
                title: "簡単",
                romaji: "Kantan",
                english: "Easy",
                interval: projections[.easy]?.displayInterval ?? "4d",
                color: Color(hex: "#3B82F6"),
                rating: .easy
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }



    @ViewBuilder
    private func ratingButton(
        title: String,
        romaji: String,
        english: String,
        interval: String,
        color: Color,
        rating: SRSRating
    ) -> some View {
        let isDisabled = viewModel.wasCheckedMeaning && (rating == .good || rating == .easy)
        Button {
            viewModel.ensureTimerRunning()
            viewModel.answerCurrentCard(rating: rating)
        } label: {
            VStack(spacing: 2) {
                Text(interval)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(color)

                Text(title)
                    .font(.japanese(size: 12, weight: .bold))
                    .foregroundColor(inkColor)
                    .lineLimit(1)

                if settingsManager.showAppEnglishMeaning {
                    Text(english)
                        .font(.english(size: 11, weight: .regular))
                        .foregroundColor(mutedColor)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(color.opacity(isDisabled ? 0.04 : 0.08))
            .cornerRadius(8)
            .opacity(isDisabled ? 0.3 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
