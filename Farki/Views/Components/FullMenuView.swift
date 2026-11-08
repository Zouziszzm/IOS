import SwiftUI

struct ArrowLineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let arrowLen: CGFloat = 9
        let arrowSpread: CGFloat = 6
        let lineEnd = rect.width - 2

        // Main horizontal line
        path.move(to: CGPoint(x: 0, y: midY))
        path.addLine(to: CGPoint(x: lineEnd, y: midY))

        // Upper arrow wing
        path.move(to: CGPoint(x: lineEnd - arrowLen, y: midY - arrowSpread))
        path.addLine(to: CGPoint(x: lineEnd, y: midY))

        // Lower arrow wing
        path.addLine(to: CGPoint(x: lineEnd - arrowLen, y: midY + arrowSpread))

        return path
    }
}

struct ArrowLineView: View {
    var color: Color = Color(hex: "#0C0A09")
    var lineWidth: CGFloat = 1.8

    var body: some View {
        ArrowLineShape()
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
}

struct FullMenuView: View {
    @ObservedObject var navVM: NavigationViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared
    @ObservedObject var settingsManager: AppSettingsManager = AppSettingsManager.shared
    @Environment(\.colorScheme) var colorScheme

    private var inkColor: Color {
        themeManager.inkColor
    }

    private var canvasColor: Color {
        themeManager.canvasColor
    }

    private var mutedColor: Color {
        themeManager.mutedColor
    }

    // Staggered animation states
    @State private var animTitle = false
    @State private var animText1 = false
    @State private var animText2 = false
    @State private var animText3 = false
    @State private var animText4 = false
    @State private var animLine1 = false
    @State private var animLine2 = false
    @State private var animLine3 = false
    @State private var animLine4 = false

    var body: some View {
        let isDashActive = (navVM.selectedMenuItem == .dashboard)
        let isAboutActive = (navVM.selectedMenuItem == .about)
        let isThemeActive = (navVM.selectedMenuItem == .theme)
        let isImportSettingsActive = (navVM.selectedMenuItem == .importSettings)

        ZStack(alignment: .bottom) {
            canvasColor
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Top Header spacing placeholder so layout is aligned with persistent logo
                Color.clear
                    .frame(height: 24)
                    .padding(.top, 14)

                Spacer()

                // "Menu" Section Title
                VStack(alignment: .leading, spacing: 3) {
                    Text("Menu")
                        .font(.englishMenu(size: 34))
                        .foregroundColor(inkColor)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .opacity(animTitle ? 1.0 : 0.0)
                .offset(x: animTitle ? 0 : -25)

                // Menu Items
                VStack(alignment: .leading, spacing: 30) {
                    // Item 01: 01 ダッシュボード
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            navVM.selectedMenuItem = .dashboard
                        }
                        navVM.closeMenu()
                    } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("01 Dashboard")
                                .font(.englishMenu(size: 28))
                                .foregroundColor(inkColor)
                                .opacity(animText1 ? (isDashActive ? 1.0 : 0.5) : 0.0)
                                .offset(x: animText1 ? 0 : -30)

                            ZStack(alignment: .leading) {
                                if isDashActive {
                                    // Active item: ArrowLine with 100% opacity
                                    ArrowLineView(color: inkColor)
                                        .frame(height: 14)
                                        .opacity(animLine1 ? 1.0 : 0.0)
                                } else {
                                    // Inactive item: non-arrow line with 40% opacity centered in same 14pt frame
                                    Rectangle()
                                        .fill(inkColor)
                                        .frame(width: 200, height: 1.8)
                                        .opacity(animLine1 ? 0.4 : 0.0)
                                }
                            }
                            .frame(height: 14, alignment: .center)
                            .scaleEffect(x: animLine1 ? 1.0 : 0.0, y: 1.0, anchor: .leading)
                        }
                        .padding(.leading, 24)
                        .padding(.trailing, 28)
                    }
                    .buttonStyle(.plain)

                    // Item 02: 02 〜について
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            navVM.selectedMenuItem = .about
                        }
                        navVM.navigateToMenuDestination(.about)
                    } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("02 About")
                                .font(.englishMenu(size: 28))
                                .foregroundColor(inkColor)
                                .opacity(animText2 ? (isAboutActive ? 1.0 : 0.5) : 0.0)
                                .offset(x: animText2 ? 0 : -30)

                            ZStack(alignment: .leading) {
                                if isAboutActive {
                                    // Active item: ArrowLine with 100% opacity
                                    ArrowLineView(color: inkColor)
                                        .frame(height: 14)
                                        .opacity(animLine2 ? 1.0 : 0.0)
                                } else {
                                    // Inactive item: non-arrow line with 40% opacity centered in same 14pt frame
                                    Rectangle()
                                        .fill(inkColor)
                                        .frame(width: 198, height: 1.8)
                                        .opacity(animLine2 ? 0.4 : 0.0)
                                }
                            }
                            .frame(height: 14, alignment: .center)
                            .scaleEffect(x: animLine2 ? 1.0 : 0.0, y: 1.0, anchor: .leading)
                        }
                        .padding(.leading, 24)
                        .padding(.trailing, 28)
                    }
                    .buttonStyle(.plain)

                    // Item 03: 03 テーマ
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            navVM.selectedMenuItem = .theme
                        }
                        themeManager.toggleTheme()
                    } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("03 Theme")
                                .font(.englishMenu(size: 28))
                                .foregroundColor(inkColor)
                                .opacity(animText3 ? (isThemeActive ? 1.0 : 0.5) : 0.0)
                                .offset(x: animText3 ? 0 : -30)

                            ZStack(alignment: .leading) {
                                if isThemeActive {
                                    // Active item: ArrowLine with 100% opacity
                                    ArrowLineView(color: inkColor)
                                        .frame(height: 14)
                                        .opacity(animLine3 ? 1.0 : 0.0)
                                } else {
                                    // Inactive item: non-arrow line with 40% opacity centered in same 14pt frame
                                    Rectangle()
                                        .fill(inkColor)
                                        .frame(width: 198, height: 1.8)
                                        .opacity(animLine3 ? 0.4 : 0.0)
                                }
                            }
                            .frame(height: 14, alignment: .center)
                            .scaleEffect(x: animLine3 ? 1.0 : 0.0, y: 1.0, anchor: .leading)
                        }
                        .padding(.leading, 24)
                        .padding(.trailing, 28)
                    }
                    .buttonStyle(.plain)

                    // Item 04: 04 インポート・設定
                    Button {
                        navVM.navigateToMenuDestination(.importSettings)
                    } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("04 Import & Settings")
                                .font(.englishMenu(size: 28))
                                .foregroundColor(inkColor)
                                .opacity(animText4 ? (isImportSettingsActive ? 1.0 : 0.5) : 0.0)
                                .offset(x: animText4 ? 0 : -30)

                            ZStack(alignment: .leading) {
                                if isImportSettingsActive {
                                    // Active item: ArrowLine with 100% opacity
                                    ArrowLineView(color: inkColor)
                                        .frame(height: 14)
                                        .opacity(animLine4 ? 1.0 : 0.0)
                                } else {
                                    // Inactive item: non-arrow line with 40% opacity centered in same 14pt frame
                                    Rectangle()
                                        .fill(inkColor)
                                        .frame(width: 198, height: 1.8)
                                        .opacity(animLine4 ? 0.4 : 0.0)
                                }
                            }
                            .frame(height: 14, alignment: .center)
                            .scaleEffect(x: animLine4 ? 1.0 : 0.0, y: 1.0, anchor: .leading)
                        }
                        .padding(.leading, 24)
                        .padding(.trailing, 28)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
                    .frame(height: 100)
            }
            .safeAreaPadding(.top)
        }
        .gesture(
            DragGesture().onEnded { value in
                // Swipe up to trigger dismiss
                if value.translation.height < -35 {
                    navVM.closeMenu()
                }
            }
        )
        .onAppear {
            updateAnimation(visible: navVM.isContentVisible)
        }
        .onChange(of: navVM.isContentVisible) { _, isVisible in
            updateAnimation(visible: isVisible)
        }
    }

    private func updateAnimation(visible: Bool) {
        if visible {
            // OPENING SEQUENCE:
            // 1. Page finishes sliding down empty from top (~0.30s)
            // 2. As it touches bottom, items stagger fade + slide in from left to right
            // 3. After items have come in, lines stagger in from left to right

            withAnimation(.easeOut(duration: 0.28).delay(0.30)) {
                animTitle = true
            }
            withAnimation(.easeOut(duration: 0.28).delay(0.38)) {
                animText1 = true
            }
            withAnimation(.easeOut(duration: 0.28).delay(0.46)) {
                animText2 = true
            }
            withAnimation(.easeOut(duration: 0.28).delay(0.54)) {
                animText3 = true
            }
            withAnimation(.easeOut(duration: 0.28).delay(0.62)) {
                animText4 = true
            }
            // Lines animate in AFTER texts have arrived
            withAnimation(.easeOut(duration: 0.30).delay(0.70)) {
                animLine1 = true
            }
            withAnimation(.easeOut(duration: 0.30).delay(0.76)) {
                animLine2 = true
            }
            withAnimation(.easeOut(duration: 0.30).delay(0.82)) {
                animLine3 = true
            }
            withAnimation(.easeOut(duration: 0.30).delay(0.88)) {
                animLine4 = true
            }
        } else {
            // CLOSING SEQUENCE (Reverse Order):
            // 1. Arrows/lines fade/slide out first from right to left
            // 2. Texts fade/slide out from right to left
            // 3. Title fades out
            // 4. Finally, drawer page slides from bottom to top out of view

            withAnimation(.easeIn(duration: 0.10).delay(0.00)) {
                animLine4 = false
            }
            withAnimation(.easeIn(duration: 0.10).delay(0.04)) {
                animLine3 = false
            }
            withAnimation(.easeIn(duration: 0.10).delay(0.08)) {
                animLine2 = false
            }
            withAnimation(.easeIn(duration: 0.10).delay(0.12)) {
                animLine1 = false
            }
            withAnimation(.easeIn(duration: 0.10).delay(0.16)) {
                animText4 = false
            }
            withAnimation(.easeIn(duration: 0.10).delay(0.20)) {
                animText3 = false
            }
            withAnimation(.easeIn(duration: 0.10).delay(0.24)) {
                animText2 = false
            }
            withAnimation(.easeIn(duration: 0.10).delay(0.28)) {
                animText1 = false
            }
            withAnimation(.easeIn(duration: 0.10).delay(0.32)) {
                animTitle = false
            }
        }
    }
}
