import SwiftUI
import Combine

enum NavMenuItem: String, CaseIterable, Identifiable {
    case kotoba = "Vocab"
    case kanji = "Kanji"
    case joshi = "Particles"
    case bunpou = "Grammar"
    case exam = "Exam"

    var id: String { rawValue }

    var romaji: String { rawValue }

    var english: String { rawValue }
}

enum MenuDestination: String, CaseIterable {
    case dashboard = "Dashboard"
    case about = "About"
    case theme = "Theme"
    case importSettings = "Import & Settings"
}

enum ActivePage: Equatable {
    case dashboard // In the menu; active by default, so none of the 5 nav items are highlighted
    case tab(NavMenuItem)
    case about
    case importSettings
}

final class NavigationViewModel: ObservableObject {
    /// Active page state. Default is dashboard (in menu), so all 5 nav items start at 50% opacity
    @Published var activePage: ActivePage = .dashboard

    /// Menu drawer state (controls presentation and sliding from top to bottom)
    @Published var isMenuOpen: Bool = false

    /// Menu content visibility (controls the staggered fade-in / fade-out of items)
    @Published var isContentVisible: Bool = false

    /// Selected item inside the menu drawer (01 ダッシュボード vs 02 〜について)
    @Published var selectedMenuItem: MenuDestination = .dashboard

    /// Controls whether the vocabulary menu or regular menu is visible on the vocabulary page
    @Published var isVocabMenuVisible: Bool = false

    // MARK: - Vocabulary Menu Notch & Tap Interaction (Requirements 2, 3, 4, 5)
    @Published var isNotchVisible: Bool = false
    @Published var isNotchPulsing: Bool = false
    @Published var notchYOffset: CGFloat = 0

    private var tapCountInWindow: Int = 0
    private var lastTapTimestamp: TimeInterval = 0
    private var autoFadeTask: DispatchWorkItem?
    private var tapResetTask: DispatchWorkItem?

    var isKotobaActive: Bool {
        activePage == .tab(.kotoba)
    }

    var isKanjiActive: Bool {
        activePage == .tab(.kanji)
    }

    var isJoshiActive: Bool {
        activePage == .tab(.joshi)
    }

    var isBunpouActive: Bool {
        activePage == .tab(.bunpou)
    }

    var isExamActive: Bool {
        activePage == .tab(.exam)
    }

    var isStudyTabActive: Bool {
        isKotobaActive || isKanjiActive || isJoshiActive || isBunpouActive
    }

    @Published var isRenshuuMenuVisible: Bool = false

    private var closeWorkItem: DispatchWorkItem?

    // Handle bottom navigation item tap
    func selectItem(_ item: NavMenuItem) {
        resetNotch()
        if isMenuOpen {
            closeMenu(targetPage: .tab(item))
            return
        }
        if activePage == .tab(item) {
            activePage = .dashboard
            isVocabMenuVisible = false
        } else {
            activePage = .tab(item)
            if item == .kotoba || item == .kanji || item == .joshi || item == .bunpou {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                    isVocabMenuVisible = true
                }
            } else {
                isVocabMenuVisible = false
            }
        }
    }

    /// Toggles between regular bottom menu and vocabulary/study bottom menu
    func toggleVocabMenu() {
        guard isStudyTabActive else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isVocabMenuVisible.toggle()
        }
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }

    /// Handles taps in the interaction area above the menu (Requirements 3, 4, 5)
    func handleMenuAreaTap() {
        guard isKotobaActive else { return }

        // When regular menu is visible on vocabulary page, double-tap restores vocab menu
        if !isVocabMenuVisible {
            handleRegularMenuDoubleTap()
            return
        }

        let now = Date().timeIntervalSince1970
        let elapsed = now - lastTapTimestamp
        lastTapTimestamp = now

        let isWithinDoubleTapWindow = (elapsed < 0.38 && tapCountInWindow > 0)

        if isWithinDoubleTapWindow {
            tapCountInWindow += 1
        } else {
            tapCountInWindow = 1
        }

        tapResetTask?.cancel()
        tapResetTask = nil

        if tapCountInWindow == 1 {
            // First tap: Fade in notch and start subtle pulse
            autoFadeTask?.cancel()
            autoFadeTask = nil

            withAnimation(.easeInOut(duration: 0.22)) {
                isNotchVisible = true
                notchYOffset = 0
            }
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                isNotchPulsing = true
            }

            // Auto-fadeout after ~1.8 seconds if no further tap occurs
            let fadeWork = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                withAnimation(.easeInOut(duration: 0.28)) {
                    self.isNotchVisible = false
                    self.isNotchPulsing = false
                }
                self.tapCountInWindow = 0
            }
            autoFadeTask = fadeWork
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: fadeWork)

            // Reset double-tap window after 0.38s
            let resetWork = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.tapCountInWindow = 0
            }
            tapResetTask = resetWork
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38, execute: resetWork)

        } else if tapCountInWindow == 2 {
            // Second tap within double-tap detection window: Valid double tap!
            autoFadeTask?.cancel()
            autoFadeTask = nil
            tapResetTask?.cancel()
            tapResetTask = nil
            tapCountInWindow = 0

            // Briefly move notch downward by 3.5px, return smoothly, and toggle menu
            withAnimation(.easeInOut(duration: 0.08)) {
                notchYOffset = 3.5
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self = self else { return }
                withAnimation(.easeInOut(duration: 0.12)) {
                    self.notchYOffset = 0
                }
                self.toggleVocabMenu()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    self.isNotchVisible = false
                    self.isNotchPulsing = false
                }
            }

        } else if tapCountInWindow >= 3 {
            // Third tap without completing a double tap:
            // Demonstrate tap location by dipping downward without toggling menu
            autoFadeTask?.cancel()
            autoFadeTask = nil
            tapResetTask?.cancel()
            tapResetTask = nil
            tapCountInWindow = 0

            withAnimation(.easeInOut(duration: 0.12)) {
                notchYOffset = 3.5
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                guard let self = self else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    self.notchYOffset = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        self.isNotchVisible = false
                        self.isNotchPulsing = false
                    }
                }
            }
        }
    }

    private func handleRegularMenuDoubleTap() {
        let now = Date().timeIntervalSince1970
        let elapsed = now - lastTapTimestamp
        lastTapTimestamp = now

        if elapsed < 0.38 {
            toggleVocabMenu()
            tapCountInWindow = 0
        } else {
            tapCountInWindow = 1
            let resetWork = DispatchWorkItem { [weak self] in
                self?.tapCountInWindow = 0
            }
            tapResetTask = resetWork
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38, execute: resetWork)
        }
    }

    func resetNotch() {
        autoFadeTask?.cancel()
        autoFadeTask = nil
        tapResetTask?.cancel()
        tapResetTask = nil
        tapCountInWindow = 0
        isNotchVisible = false
        isNotchPulsing = false
        notchYOffset = 0
    }

    // Toggle menu drawer reliably
    func toggleMenu() {
        if isMenuOpen {
            closeMenu()
        } else {
            openMenu()
        }
    }

    // Open menu drawer: empty page slides in from top, then content fades in
    func openMenu() {
        closeWorkItem?.cancel()
        closeWorkItem = nil

        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            isMenuOpen = true
        }
        isContentVisible = true
    }

    // Close menu drawer: items fade/slide out in reverse first, then page slides bottom-to-top
    func closeMenu(targetPage: ActivePage = .dashboard) {
        closeWorkItem?.cancel()

        resetNotch()
        activePage = targetPage
        isVocabMenuVisible = false
        isContentVisible = false

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            withAnimation(.spring(response: 0.40, dampingFraction: 0.88)) {
                self.isMenuOpen = false
            }
        }
        closeWorkItem = workItem
        // Allow the reverse staggered fade-out (lines, texts, title, logo) to complete before sliding page up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40, execute: workItem)
    }

    /// Navigate to a specific menu destination
    func navigateToMenuDestination(_ destination: MenuDestination) {
        selectedMenuItem = destination
        switch destination {
        case .dashboard:
            closeMenu(targetPage: .dashboard)
        case .about:
            closeMenu(targetPage: .about)
        case .theme:
            break
        case .importSettings:
            closeMenu(targetPage: .importSettings)
        }
    }
}
