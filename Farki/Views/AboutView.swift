import SwiftUI

/// Complete About & Information View
struct AboutView: View {
    @ObservedObject var navVM: NavigationViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared
    @ObservedObject var settingsManager: AppSettingsManager = AppSettingsManager.shared

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
        themeManager.activeTheme == .dark ? Color(hex: "#1C1917") : Color(hex: "#F5F5F4")
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                // Top Header spacing placeholder
                Color.clear
                    .frame(height: 24)
                    .padding(.top, 14)

                // Page Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("About")
                        .font(.english(size: 30, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("Minna no Nihongo Vocabulary & Learning System")
                        .font(.english(size: 13, weight: .regular))
                        .foregroundColor(mutedColor)
                }
                .padding(.bottom, 6)

                // Hero Info Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("nihon (日本)")
                                .font(.english(size: 22, weight: .bold))
                                .foregroundColor(inkColor)

                            Text("Minna no Nihongo Vocabulary & SRS Learning System")
                                .font(.english(size: 12, weight: .regular))
                                .foregroundColor(mutedColor)
                        }

                        Spacer()

                        Text("v1.0")
                            .font(.english(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#10B981"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "#10B981").opacity(0.14))
                            .cornerRadius(6)
                    }

                    Rectangle()
                        .fill(themeManager.hairlineColor)
                        .frame(height: 0.8)

                    Text("A focused Japanese vocabulary learning system built around the Minna no Nihongo curriculum. Features intelligent spaced repetition (SM-2 & FSRS), active recall testing, and chapter-based practice.")
                        .font(.english(size: 14, weight: .regular))
                        .foregroundColor(inkColor)
                        .lineSpacing(4)
                }
                .padding(18)
                .background(cardBackground)
                .cornerRadius(12)

                // Feature Highlights Section
                VStack(alignment: .leading, spacing: 14) {
                    Text("Key Features")
                        .font(.english(size: 16, weight: .bold))
                        .foregroundColor(inkColor)

                    featureRow(
                        icon: "books.vertical.fill",
                        title: "Curriculum Chapters",
                        desc: "Standard 50-chapter curriculum covering Beginner I (Chapters 1–25) and Beginner II (Chapters 26–50)."
                    )

                    featureRow(
                        icon: "brain.head.profile",
                        title: "Spaced Repetition System",
                        desc: "Automated review intervals powered by SM-2 and FSRS algorithms for optimal retention."
                    )

                    featureRow(
                        icon: "checkmark.circle",
                        title: "Active Recall Practice",
                        desc: "Custom test mode with Don't Know, Hard, Good, and Easy ratings that dynamically prioritize difficult words."
                    )

                    featureRow(
                        icon: "calendar.badge.clock",
                        title: "Target Exam Tracking",
                        desc: "Track real-time countdown to your upcoming JLPT exam date directly on your dashboard."
                    )
                }
                .padding(18)
                .background(cardBackground)
                .cornerRadius(12)

                // Action Shortcuts Section
                VStack(spacing: 12) {
                    Button {
                        navVM.selectItem(.kotoba)
                    } label: {
                        HStack {
                            Image(systemName: "character.textbox")
                            Text("Start Vocabulary Practice")
                                .font(.english(size: 15, weight: .bold))
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .foregroundColor(canvasColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(inkColor)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    Button {
                        navVM.navigateToMenuDestination(.importSettings)
                    } label: {
                        HStack {
                            Image(systemName: "gearshape")
                            Text("Open Import & Settings")
                                .font(.english(size: 14, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundColor(inkColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(cardBackground)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    Button {
                        navVM.navigateToMenuDestination(.dashboard)
                    } label: {
                        HStack {
                            Image(systemName: "gauge")
                            Text("Back to Dashboard")
                                .font(.english(size: 14, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundColor(inkColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(cardBackground)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }

                // Footer Clearance
                Color.clear
                    .frame(height: 120)
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(inkColor)
                .frame(width: 26)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.english(size: 14, weight: .bold))
                    .foregroundColor(inkColor)

                Text(desc)
                    .font(.english(size: 12, weight: .regular))
                    .foregroundColor(mutedColor)
                    .lineSpacing(2)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}
