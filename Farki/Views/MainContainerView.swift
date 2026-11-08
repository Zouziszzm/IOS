import SwiftUI

private struct HeaderLogoFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

struct MainContainerView: View {
    @StateObject private var navVM = NavigationViewModel()
    @StateObject private var dashboardVM = DashboardViewModel()
    @StateObject private var vocabVM = VocabViewModel()
    @StateObject private var kanjiVM = KanjiViewModel()
    @StateObject private var particlesVM = ParticlesViewModel()
    @StateObject private var grammarVM = GrammarViewModel()
    @StateObject private var examVM = ExamViewModel()
    @StateObject private var srsVM = SRSViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    // Single Authoritative Splash Transition State
    @State private var isSplashActive: Bool = true
    @State private var splashBgOpacity: Double = 1.0
    @State private var logoOpacity: Double = 0.0
    @State private var isSplashGlided: Bool = false
    @State private var headerLogoFrame: CGRect = .zero
    @State private var hasStartedSplash: Bool = false
    @State private var isLogoSettled: Bool = false

    private var canvasColor: Color {
        themeManager.canvasColor
    }

    private var inkColor: Color {
        themeManager.inkColor
    }

    var body: some View {
        GeometryReader { screenGeo in
            let screenCenter = CGPoint(x: screenGeo.size.width / 2, y: screenGeo.size.height / 2)
            let targetCenter: CGPoint = {
                if headerLogoFrame != .zero && headerLogoFrame.midY > 30 {
                    return CGPoint(x: headerLogoFrame.midX, y: headerLogoFrame.midY)
                }
                return CGPoint(x: 24 + 21, y: 59 + 14 + 11)
            }()

            let logoOffset: CGSize = isSplashGlided
                ? .zero
                : CGSize(width: screenCenter.x - targetCenter.x, height: screenCenter.y - targetCenter.y)

            let logoScale: CGFloat = isSplashGlided ? 1.0 : (144.0 / 42.0)

            ZStack {
                // Clean minimal canvas background adapting to active theme
                canvasColor
                    .ignoresSafeArea()

                // Main Active Content
                Group {
                    switch navVM.activePage {
                    case .dashboard:
                        DashboardView(viewModel: dashboardVM)
                    case .tab(let item):
                        if item == .kotoba {
                            VocabView(viewModel: vocabVM, navVM: navVM)
                        } else if item == .kanji {
                            KanjiView(viewModel: kanjiVM, navVM: navVM)
                        } else if item == .joshi {
                            ParticlesView(viewModel: particlesVM, grammarVM: grammarVM, navVM: navVM)
                        } else if item == .bunpou {
                            BunpouView(viewModel: grammarVM, particlesVM: particlesVM, navVM: navVM)
                        } else if item == .exam {
                            ExamView(viewModel: examVM, navVM: navVM)
                        } else {
                            UnderDevelopmentView(
                                title: item.rawValue,
                                navVM: navVM,
                                themeManager: themeManager
                            )
                        }
                    case .about:
                        AboutView(navVM: navVM, themeManager: themeManager)
                    case .importSettings:
                        ImportSettingsView(vocabVM: vocabVM, navVM: navVM, themeManager: themeManager)
                    }
                }
                .zIndex(0)

                // Menu Drawer sliding from top to bottom
                if navVM.isMenuOpen {
                    FullMenuView(navVM: navVM, themeManager: themeManager)
                        .id("FullMenuView")
                        .ignoresSafeArea(edges: .bottom)
                        .transition(.move(edge: .top))
                        .zIndex(1)
                }

                // Bottom Navigation Area pinned to bottom with smooth menu swap
                VStack(spacing: 0) {
                    Spacer()

                    // Double-tap interaction area just above the bottom navigation bar
                    if navVM.isStudyTabActive {
                        Color.clear
                            .frame(height: 52)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                navVM.toggleVocabMenu()
                            }
                    }

                    let isSubMenuShowing = navVM.isStudyTabActive && navVM.isVocabMenuVisible

                    ZStack(alignment: .bottom) {
                        // Regular Bottom Navigation Bar
                        BottomNavBarView(navVM: navVM)
                            .offset(y: isSubMenuShowing ? -55 : 0)
                            .opacity(isSubMenuShowing ? 0 : 1)
                            .allowsHitTesting(!isSubMenuShowing)

                        // Vocabulary Bottom Navigation Bar with attached Notch
                        if navVM.isKotobaActive {
                            VocabBottomNavBarView(viewModel: vocabVM, navVM: navVM)
                                .offset(y: navVM.isVocabMenuVisible ? 0 : 55)
                                .opacity(navVM.isVocabMenuVisible ? 1 : 0)
                                .allowsHitTesting(navVM.isVocabMenuVisible)
                        } else if navVM.isKanjiActive {
                            KanjiBottomNavBarView(viewModel: kanjiVM, navVM: navVM)
                                .offset(y: navVM.isVocabMenuVisible ? 0 : 55)
                                .opacity(navVM.isVocabMenuVisible ? 1 : 0)
                                .allowsHitTesting(navVM.isVocabMenuVisible)
                        } else if navVM.isJoshiActive {
                            DomainBottomNavBarView(
                                isTestModeActive: particlesVM.isTestModeActive,
                                showTestNextButton: particlesVM.showTestNextButton,
                                onStartTest: { particlesVM.startTest() },
                                onNavigate: { dir in
                                    particlesVM.navigateOneItem(direction: dir)
                                },
                                onRate: { rating in
                                    particlesVM.rateCurrentItem(rating)
                                }
                            )
                            .offset(y: navVM.isVocabMenuVisible ? 0 : 55)
                            .opacity(navVM.isVocabMenuVisible ? 1 : 0)
                            .allowsHitTesting(navVM.isVocabMenuVisible)
                        } else if navVM.isBunpouActive {
                            DomainBottomNavBarView(
                                isTestModeActive: grammarVM.isTestModeActive,
                                showTestNextButton: grammarVM.showTestNextButton,
                                onStartTest: { grammarVM.startTest() },
                                onNavigate: { dir in
                                    grammarVM.navigateOneItem(direction: dir)
                                },
                                onRate: { rating in
                                    grammarVM.rateCurrentItem(rating)
                                }
                            )
                            .offset(y: navVM.isVocabMenuVisible ? 0 : 55)
                            .opacity(navVM.isVocabMenuVisible ? 1 : 0)
                            .allowsHitTesting(navVM.isVocabMenuVisible)
                        }
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                .animation(.spring(response: 0.38, dampingFraction: 0.85), value: navVM.isVocabMenuVisible)
                .zIndex(2)

                // Full-screen Splash Background overlay (fades out smoothly to reveal UI)
                if isSplashActive {
                    canvasColor
                        .ignoresSafeArea()
                        .opacity(splashBgOpacity)
                        .allowsHitTesting(splashBgOpacity > 0.05)
                        .zIndex(8)
                }

                // Persistent Top Header with the SINGLE authoritative AppLogoShape
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        // Header logo slot: measures its frame and holds the ONLY logo in the app
                        ZStack {
                            Color.clear
                                .frame(width: 42, height: 22)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .preference(
                                                key: HeaderLogoFramePreferenceKey.self,
                                                value: geo.frame(in: .global)
                                            )
                                    }
                                )

                            // The single logo that starts centered in splash, glides here, and remains permanently.
                            // Double-tap / double-click opens or closes the Menu page (Section 9).
                            AppLogoShape()
                                .fill(inkColor)
                                .frame(width: 42, height: 22)
                                .scaleEffect(logoScale, anchor: .center)
                                .offset(logoOffset)
                                .opacity(isSplashActive ? logoOpacity : 1.0)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    navVM.toggleMenu()
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("nihon App Logo")
                                .accessibilityHint("Double-tap to toggle the Menu page")
                                .accessibilityAddTraits(.isButton)
                                .accessibilityAction {
                                    navVM.toggleMenu()
                                }
                                .accessibilityAction(named: "Toggle Menu") {
                                    navVM.toggleMenu()
                                }

                            // Accessible keyboard shortcut alternative (Cmd+M) for opening/closing Menu
                            Button("") {
                                navVM.toggleMenu()
                            }
                            .keyboardShortcut("m", modifiers: [.command])
                            .frame(width: 0, height: 0)
                            .opacity(0)
                            .accessibilityHidden(true)
                        }
                        .frame(width: 42, height: 22)

                        Spacer()

                        if isLogoSettled && !navVM.isMenuOpen && !navVM.isStudyTabActive && !navVM.isExamActive && navVM.activePage != .importSettings && navVM.activePage != .about {
                            Text(dashboardVM.userLevelText)
                                .font(.english(size: 14, weight: .regular))
                                .foregroundColor(inkColor)
                                .transition(.opacity)
                        }
                    }
                    .frame(height: 24)
                    .padding(.horizontal, 24)
                    .padding(.top, 14)

                    Spacer()
                }
                .safeAreaPadding(.top)
                .animation(.easeInOut(duration: 0.25), value: navVM.isMenuOpen)
                .zIndex(10)
            }
            .onAppear {
                startSingleSplashSequence()
            }
        }
        .onPreferenceChange(HeaderLogoFramePreferenceKey.self) { frame in
            if frame != .zero {
                headerLogoFrame = frame
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
    }

    private func startSingleSplashSequence() {
        guard !hasStartedSplash else { return }
        hasStartedSplash = true

        // Step 1: Smoothly fade in the centered solid logo
        withAnimation(.easeOut(duration: 0.45)) {
            logoOpacity = 1.0
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Step 2: Spring glide the logo from center directly into the header slot
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.spring(response: 0.58, dampingFraction: 0.82)) {
                isSplashGlided = true
            }

            // Step 3: Fade out splash background to reveal active view
            withAnimation(.easeInOut(duration: 0.35).delay(0.12)) {
                splashBgOpacity = 0.0
            }

            // Step 4: Settle completely; splash background overlay is removed, header logo remains
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                isLogoSettled = true
                isSplashActive = false
            }
        }
    }
}
