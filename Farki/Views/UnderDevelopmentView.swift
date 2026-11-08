import SwiftUI

struct UnderDevelopmentView: View {
    let title: String
    @ObservedObject var navVM: NavigationViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared

    @State private var isPulsing: Bool = false

    private var inkColor: Color {
        themeManager.inkColor
    }

    private var mutedColor: Color {
        themeManager.mutedColor
    }

    private var cardBackground: Color {
        themeManager.activeTheme == .dark ? Color(hex: "#1C1917") : Color(hex: "#F5F5F4")
    }

    private var englishTitle: String {
        switch title {
        case "Kanji", "かんじ": return "Kanji Practice"
        case "Particles", "じょし": return "Particles Study"
        case "Grammar", "ぶんぽう", "れんしゅう": return "Grammar Curriculum"
        case "About", "〜について": return "About nihon"
        default: return title
        }
    }

    private var featureDescription: String {
        switch title {
        case "Kanji", "かんじ":
            return "Kanji stroke order, Onyomi/Kunyomi readings, and writing practice are currently under construction."
        case "Particles", "じょし":
            return "Contextual usage and interactive quizzes for Japanese particles (wa, ga, o, ni, de) are currently under construction."
        case "Grammar", "ぶんぽう", "れんしゅう":
            return "Dedicated grammar curriculum, conjugation patterns, and sentence structure practice are currently under construction. Stay tuned for future updates!"
        case "About", "〜について":
            return "Textbook integration info, version notes, and sync details are currently in development."
        default:
            return "This section is currently under construction. Stay tuned for upcoming updates!"
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                // Top header clearance aligned with persistent logo
                Color.clear
                    .frame(height: 24)
                    .padding(.top, 14)

                Spacer()
                    .frame(height: 20)

                // Traffic Cone & Road Block Construction Icon Badge
                ZStack {
                    Circle()
                        .fill(Color(hex: "#F59E0B").opacity(0.14))
                        .frame(width: 104, height: 104)
                        .scaleEffect(isPulsing ? 1.08 : 0.95)

                    Circle()
                        .fill(Color(hex: "#F59E0B").opacity(0.22))
                        .frame(width: 84, height: 84)

                    // Traffic cone SF Symbol
                    Image(systemName: "cone.fill")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(Color(hex: "#F59E0B"))
                        .shadow(color: Color(hex: "#F59E0B").opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }

                // In Development Status Badge
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .bold))

                    Text("UNDER CONSTRUCTION")
                        .font(.english(size: 13, weight: .bold))
                }
                .foregroundColor(Color(hex: "#F59E0B"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "#F59E0B").opacity(0.12))
                .cornerRadius(20)

                // Title Section
                VStack(spacing: 6) {
                    Text(title)
                        .font(.english(size: 32, weight: .bold))
                        .foregroundColor(inkColor)

                    Text(englishTitle)
                        .font(.english(size: 15, weight: .medium))
                        .foregroundColor(mutedColor)
                }

                // Roadmap Description Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(inkColor)

                        Text("PLANNED FEATURES")
                            .font(.english(size: 13, weight: .bold))
                            .foregroundColor(mutedColor)
                    }

                    Text(featureDescription)
                        .font(.english(size: 15, weight: .regular))
                        .foregroundColor(inkColor)
                        .lineSpacing(4)

                    Divider()
                        .background(themeManager.hairlineColor)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: "#10B981"))
                            .frame(width: 6, height: 6)

                        Text("Vocabulary study is active and available.")
                            .font(.english(size: 13, weight: .medium))
                            .foregroundColor(mutedColor)
                    }
                }
                .padding(18)
                .background(cardBackground)
                .cornerRadius(14)
                .padding(.horizontal, 8)

                // Action Button: Jump to Active Vocab Study
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    navVM.selectItem(.kotoba)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 14))

                        Text("Go to Vocabulary")
                            .font(.english(size: 17, weight: .bold))
                    }
                    .foregroundColor(themeManager.canvasColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(inkColor)
                    .cornerRadius(12)
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)

                // Secondary Action: Go to Dashboard
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    navVM.activePage = .dashboard
                } label: {
                    Text("Back to Dashboard")
                        .font(.english(size: 15, weight: .medium))
                        .foregroundColor(mutedColor)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 100) // Clearance above bottom navigation
            }
            .padding(.horizontal, 24)
        }
    }
}
