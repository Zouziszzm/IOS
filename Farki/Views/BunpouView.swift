import SwiftUI

struct BunpouView: View {
    @ObservedObject var viewModel: GrammarViewModel
    @ObservedObject var particlesVM: ParticlesViewModel
    @ObservedObject var navVM: NavigationViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared

    private var inkColor: Color { themeManager.inkColor }
    private var mutedColor: Color { themeManager.mutedColor }
    private var canvasColor: Color { themeManager.canvasColor }
    private var hairlineColor: Color { themeManager.hairlineColor }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Section 1: Compact Top Header
                    topHeaderSection
                        .padding(.top, 68)

                    // Test Mode Active Banner & Test View
                    if viewModel.isTestModeActive {
                        testModeBanner
                        progressSection
                        testModeCardSection
                            .padding(.bottom, 120)
                    } else {
                        // Non-Test Mode: Clean Mode Switcher (Focused Study vs Browse Syllabus)
                        studyModeControlBar

                        if viewModel.isBrowseMode {
                            browseTopicsSection
                                .padding(.bottom, 120)
                        } else {
                            focusedLearnCardSection
                                .padding(.bottom, 120)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }

            ConfettiBurstView(trigger: $viewModel.confettiTrigger)
                .ignoresSafeArea()
        }
    }

    // MARK: - Section 1: Top Header
    @ViewBuilder
    private var topHeaderSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        navVM.navigateToMenuDestination(.dashboard)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 9, weight: .semibold))
                            Text("Dashboard")
                                .font(.english(size: 11, weight: .medium))
                        }
                        .foregroundColor(mutedColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.segmentEmptyColor.opacity(0.45))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.toggleTimer()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.isTimerPaused ? "play.circle.fill" : "pause.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(viewModel.isTimerPaused ? Color(hex: "#3B82F6") : inkColor)

                            Text(viewModel.formattedSessionTime)
                                .font(.english(size: 13, weight: .medium))
                                .foregroundColor(inkColor)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.segmentEmptyColor.opacity(0.35))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    if viewModel.isTestModeActive {
                        Button {
                            viewModel.stopTest()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 9))
                                Text("Stop Test")
                                    .font(.english(size: 11, weight: .bold))
                            }
                            .foregroundColor(Color(hex: "#EF4444"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "#EF4444").opacity(0.12))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("Grammar Studio • 文法")
                    .font(.english(size: 22, weight: .bold))
                    .foregroundColor(inkColor)
            }

            Spacer()

            // Active Item Position & Mastery Status Square
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 6) {
                    Button {
                        viewModel.cycleActiveGrammarStatus()
                    } label: {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(viewModel.currentProgress.reviewSquareColor)
                            .frame(width: 11, height: 11)
                    }
                    .buttonStyle(.plain)

                    let displayNum = viewModel.isTestModeActive
                        ? (viewModel.currentTestIndex + 1)
                        : (viewModel.grammarPoints.isEmpty ? 0 : (viewModel.currentPointIndex + 1))
                    Text("\(displayNum)")
                        .font(.english(size: 24, weight: .bold))
                        .foregroundColor(inkColor)
                    Text("/\(viewModel.isTestModeActive ? viewModel.testTotalQuestions : viewModel.totalPointCount)")
                        .font(.english(size: 14, weight: .medium))
                        .foregroundColor(mutedColor)
                }

                Text("\(viewModel.completedPointCount) learned (\(viewModel.displayPercentage)%)")
                    .font(.english(size: 11, weight: .medium))
                    .foregroundColor(mutedColor)
            }
        }
    }

    // MARK: - Study Mode Switcher & Quick Level/Filter Bar
    @ViewBuilder
    private var studyModeControlBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                // 1. Focused Study vs Browse Topics Toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isBrowseMode = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Step-by-Step Study")
                            .font(.english(size: 13, weight: .bold))
                    }
                    .foregroundColor(!viewModel.isBrowseMode ? canvasColor : inkColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(!viewModel.isBrowseMode ? inkColor : inkColor.opacity(0.06))
                    .cornerRadius(9)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isBrowseMode = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Browse All (\(viewModel.totalPointCount))")
                            .font(.english(size: 13, weight: .bold))
                    }
                    .foregroundColor(viewModel.isBrowseMode ? canvasColor : inkColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(viewModel.isBrowseMode ? inkColor : inkColor.opacity(0.06))
                    .cornerRadius(9)
                }
                .buttonStyle(.plain)
            }

            // Quick Level Filter Bar (All / N5 / N4) + Active Scope Indicator
            HStack(spacing: 8) {
                ForEach([nil, JLPTLevel.n5, JLPTLevel.n4], id: \.self) { lvl in
                    let isSelected = (viewModel.selectedJLPTLevel == lvl)
                    Button {
                        viewModel.selectedJLPTLevel = lvl
                    } label: {
                        Text(lvl == nil ? "All Levels" : lvl!.rawValue)
                            .font(.english(size: 12, weight: .bold))
                            .foregroundColor(isSelected ? canvasColor : inkColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isSelected ? inkColor : inkColor.opacity(0.06))
                            .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                }

                if let ch = viewModel.selectedChapterNumber {
                    Button {
                        viewModel.selectedChapterNumber = nil
                    } label: {
                        HStack(spacing: 4) {
                            Text("Ch. \(ch)")
                                .font(.english(size: 11, weight: .bold))
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color(hex: "#10B981"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(hex: "#10B981").opacity(0.12))
                        .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Self-Quiz (Hide Meaning) toggle when in Focused Study
                if !viewModel.isBrowseMode {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.isRecallQuizMode.toggle()
                            viewModel.isFlipped = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.isRecallQuizMode ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 11))
                            Text(viewModel.isRecallQuizMode ? "Quiz Mode" : "Study Mode")
                                .font(.english(size: 11, weight: .bold))
                        }
                        .foregroundColor(viewModel.isRecallQuizMode ? Color(hex: "#F59E0B") : mutedColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(viewModel.isRecallQuizMode ? Color(hex: "#F59E0B").opacity(0.14) : inkColor.opacity(0.05))
                        .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Focused Step-by-Step Study Card (Clean, Structured, Non-Overwhelming)
    @ViewBuilder
    private var focusedLearnCardSection: some View {
        if viewModel.grammarPoints.isEmpty {
            emptyStateCard
        } else {
            let point = viewModel.currentPoint
            let variant = viewModel.currentVariant
            let progress = viewModel.currentProgress
            let shouldHideAnswer = viewModel.isRecallQuizMode && !viewModel.isFlipped

            VStack(alignment: .leading, spacing: 14) {
                // 1. HERO PATTERN & MEANING CARD
                VStack(alignment: .leading, spacing: 12) {
                    // Metadata Breadcrumb: Level, Chapter, Category, Streak
                    HStack(spacing: 8) {
                        if let level = point.jlptLevel {
                            Text(level.rawValue)
                                .font(.english(size: 11, weight: .bold))
                                .foregroundColor(level == .n5 ? Color(hex: "#10B981") : Color(hex: "#3B82F6"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background((level == .n5 ? Color(hex: "#10B981") : Color(hex: "#3B82F6")).opacity(0.12))
                                .cornerRadius(6)
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.isBrowseMode = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("Ch. \(point.chapterNumber) • \(point.categoryTag)")
                                    .font(.english(size: 11, weight: .semibold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(mutedColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(inkColor.opacity(0.05))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        if progress.bestStreak > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: "#F59E0B"))
                                Text("\(progress.bestStreak)")
                                    .font(.english(size: 12, weight: .bold))
                                    .foregroundColor(inkColor)
                            }
                        }
                    }

                    // Large Japanese Pattern + Speaker
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(variant?.pattern ?? point.japanese)
                                .font(.japanese(size: 30, weight: .bold))
                                .foregroundColor(inkColor)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(variant?.romaji ?? point.romaji)
                                .font(.english(size: 15, weight: .medium))
                                .foregroundColor(mutedColor)
                        }

                        Spacer()

                        Button {
                            viewModel.speakCurrentGrammar()
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(inkColor)
                                .frame(width: 38, height: 38)
                                .background(inkColor.opacity(0.07))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()
                        .background(hairlineColor)

                    // Core Meaning Box (Visible immediately in Study Mode, or Tap-to-Reveal in Quiz Mode)
                    if shouldHideAnswer {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.flipCard()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Tap to Reveal Meaning & Explanation")
                                    .font(.english(size: 14, weight: .bold))
                            }
                            .foregroundColor(Color(hex: "#3B82F6"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#3B82F6").opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CORE MEANING")
                                .font(.english(size: 10, weight: .bold))
                                .tracking(1.0)
                                .foregroundColor(Color(hex: "#10B981"))

                            Text(variant?.meaning ?? point.meaning)
                                .font(.english(size: 20, weight: .bold))
                                .foregroundColor(inkColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "#10B981").opacity(0.08))
                        .cornerRadius(10)
                    }
                }
                .padding(18)
                .background(inkColor.opacity(0.04))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(hairlineColor, lineWidth: 0.9)
                )

                if !shouldHideAnswer {
                    // 2. HOW TO BUILD IT (Formation Blueprint & Forms)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "#3B82F6"))
                            Text("HOW TO FORM IT")
                                .font(.english(size: 11, weight: .bold))
                                .tracking(0.8)
                                .foregroundColor(mutedColor)
                        }

                        Text(variant?.pattern ?? point.pattern)
                            .font(.japanese(size: 16, weight: .bold))
                            .foregroundColor(inkColor)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: "#3B82F6").opacity(0.08))
                            .cornerRadius(9)

                        // If this grammar point has multiple conjugation variants (e.g. Present/Past Aff/Neg)
                        if point.variants.count > 1 {
                            Text("TAP A FORM TO INSPECT")
                                .font(.english(size: 10, weight: .bold))
                                .foregroundColor(mutedColor)
                                .padding(.top, 2)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    Button {
                                        viewModel.selectVariant(at: nil)
                                    } label: {
                                        Text("All / Overview")
                                            .font(.english(size: 12, weight: viewModel.selectedVariantIndex == nil ? .bold : .medium))
                                            .foregroundColor(viewModel.selectedVariantIndex == nil ? canvasColor : inkColor)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(viewModel.selectedVariantIndex == nil ? inkColor : inkColor.opacity(0.06))
                                            .cornerRadius(7)
                                    }
                                    .buttonStyle(.plain)

                                    ForEach(point.variants.indices, id: \.self) { vIdx in
                                        let v = point.variants[vIdx]
                                        let isSelected = (viewModel.selectedVariantIndex == vIdx)
                                        Button {
                                            viewModel.selectVariant(at: vIdx)
                                        } label: {
                                            Text(v.label)
                                                .font(.english(size: 12, weight: isSelected ? .bold : .medium))
                                                .foregroundColor(isSelected ? canvasColor : v.category.color(for: themeManager.activeTheme))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(isSelected ? inkColor : inkColor.opacity(0.06))
                                                .cornerRadius(7)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(inkColor.opacity(0.035))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(hairlineColor, lineWidth: 0.8)
                    )

                    // 3. WHEN & WHY TO USE IT (Clear Explanation)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "#F59E0B"))
                            Text("EXPLANATION & USAGE")
                                .font(.english(size: 11, weight: .bold))
                                .tracking(0.8)
                                .foregroundColor(mutedColor)
                        }

                        Text(variant?.explanation ?? point.explanation)
                            .font(.english(size: 14, weight: .regular))
                            .foregroundColor(inkColor.opacity(0.9))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(inkColor.opacity(0.035))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(hairlineColor, lineWidth: 0.8)
                    )

                    // 4. EXAMPLE SENTENCES (With Tap-to-Speak Audio)
                    let examplesToShow = (variant != nil && !(variant!.examples.isEmpty)) ? variant!.examples : point.examples
                    if !examplesToShow.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "text.bubble.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: "#10B981"))
                                Text("EXAMPLE SENTENCES • TAP TO LISTEN")
                                    .font(.english(size: 11, weight: .bold))
                                    .tracking(0.8)
                                    .foregroundColor(mutedColor)
                            }

                            ForEach(Array(examplesToShow.enumerated()), id: \.element.id) { idx, ex in
                                Button {
                                    SpeechService.shared.speak(text: ex.japanese, phoneticReading: ex.reading)
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        Text(String(format: "%02d", idx + 1))
                                            .font(.english(size: 11, weight: .bold))
                                            .foregroundColor(Color(hex: "#10B981"))
                                            .padding(.top, 3)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(ex.japanese)
                                                .font(.japanese(size: 16, weight: .bold))
                                                .foregroundColor(inkColor)
                                                .multilineTextAlignment(.leading)

                                            if let reading = ex.reading, !reading.isEmpty, reading != ex.japanese {
                                                Text(reading)
                                                    .font(.english(size: 12, weight: .regular))
                                                    .foregroundColor(mutedColor)
                                                    .multilineTextAlignment(.leading)
                                            }

                                            Text(ex.meaning)
                                                .font(.english(size: 13, weight: .medium))
                                                .foregroundColor(inkColor.opacity(0.85))
                                                .multilineTextAlignment(.leading)
                                        }

                                        Spacer()

                                        Image(systemName: "speaker.wave.2")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(mutedColor)
                                            .padding(.top, 3)
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(inkColor.opacity(0.04))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                        .background(inkColor.opacity(0.03))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(hairlineColor, lineWidth: 0.8)
                        )
                    }

                    // 5. RELATED PARTICLES (If Linked)
                    if !point.relatedParticleIds.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("RELATED PARTICLES")
                                .font(.english(size: 10, weight: .bold))
                                .foregroundColor(mutedColor)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(point.relatedParticleIds, id: \.self) { pid in
                                        let p = ParticleDataService.shared.particle(forId: pid)
                                        Button {
                                            particlesVM.searchQuery = ""
                                            particlesVM.selectedCategory = nil
                                            particlesVM.selectedJLPTLevel = nil
                                            particlesVM.isBrowseMode = false
                                            if let idx = particlesVM.particles.firstIndex(where: { $0.id == pid }) {
                                                particlesVM.selectParticle(at: idx)
                                            }
                                            navVM.selectItem(.joshi)
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text(p?.japanese ?? pid)
                                                    .font(.japanese(size: 13, weight: .bold))
                                                if let rom = p?.romaji {
                                                    Text("(\(rom))")
                                                        .font(.english(size: 11))
                                                }
                                                Image(systemName: "arrow.up.right")
                                                    .font(.system(size: 9, weight: .bold))
                                            }
                                            .foregroundColor(Color(hex: "#10B981"))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color(hex: "#10B981").opacity(0.12))
                                            .cornerRadius(7)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }

                // 6. PREVIOUS / NEXT GRAMMAR POINT STEPPER BAR
                HStack(spacing: 10) {
                    Button {
                        viewModel.navigateOneItem(direction: -1)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 12, weight: .bold))
                            Text("Previous")
                                .font(.english(size: 13, weight: .bold))
                        }
                        .foregroundColor(viewModel.currentPointIndex > 0 ? inkColor : mutedColor.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(inkColor.opacity(0.06))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.currentPointIndex <= 0)

                    Button {
                        viewModel.startTest(
                            scopeTitle: "Ch. \(point.chapterNumber) Grammar",
                            grammarPointIds: viewModel.grammarPoints.filter { $0.chapterNumber == point.chapterNumber }.map(\.id)
                        )
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                            Text("Quiz Ch. \(point.chapterNumber)")
                                .font(.english(size: 12, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "#3B82F6"))
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                        .background(Color(hex: "#3B82F6").opacity(0.12))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.navigateOneItem(direction: 1)
                    } label: {
                        HStack(spacing: 6) {
                            Text("Next")
                                .font(.english(size: 13, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(viewModel.currentPointIndex + 1 < viewModel.grammarPoints.count ? canvasColor : mutedColor.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(viewModel.currentPointIndex + 1 < viewModel.grammarPoints.count ? inkColor : inkColor.opacity(0.06))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.currentPointIndex + 1 >= viewModel.grammarPoints.count)
                }
            }
        }
    }

    // MARK: - Browse All Topics & Syllabus View
    @ViewBuilder
    private var browseTopicsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(mutedColor)

                TextField("Search grammar pattern, meaning, romaji...", text: $viewModel.searchQuery)
                    .font(.english(size: 13))
                    .foregroundColor(inkColor)

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(mutedColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(themeManager.segmentEmptyColor.opacity(0.35))
            .cornerRadius(9)

            // Category Filter Chips
            VStack(alignment: .leading, spacing: 6) {
                Text("FILTER BY GRAMMAR TOPIC")
                    .font(.english(size: 10, weight: .bold))
                    .foregroundColor(mutedColor)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        filterChip(title: "All Topics", isSelected: viewModel.selectedCategoryTag == nil) {
                            viewModel.selectedCategoryTag = nil
                        }
                        ForEach(GrammarDataService.shared.availableCategories, id: \.self) { cat in
                            filterChip(title: cat, isSelected: viewModel.selectedCategoryTag == cat) {
                                viewModel.selectedCategoryTag = (viewModel.selectedCategoryTag == cat) ? nil : cat
                            }
                        }
                    }
                }
            }

            // Chapter Filter Chips (1..50)
            VStack(alignment: .leading, spacing: 6) {
                Text("FILTER BY CHAPTER")
                    .font(.english(size: 10, weight: .bold))
                    .foregroundColor(mutedColor)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        filterChip(title: "All Chapters", isSelected: viewModel.selectedChapterNumber == nil) {
                            viewModel.selectedChapterNumber = nil
                        }
                        ForEach(1...50, id: \.self) { ch in
                            filterChip(title: "Ch. \(ch)", isSelected: viewModel.selectedChapterNumber == ch) {
                                viewModel.selectedChapterNumber = (viewModel.selectedChapterNumber == ch) ? nil : ch
                            }
                        }
                    }
                }
            }

            // Filtered Grammar List (Tap any row to study it in Focused Card mode)
            if viewModel.grammarPoints.isEmpty {
                emptyStateCard
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(viewModel.grammarPoints.enumerated()), id: \.element.id) { idx, gp in
                        let prog = GrammarDataService.shared.progress(pointId: gp.id)
                        let isCurrent = (idx == viewModel.currentPointIndex)

                        Button {
                            viewModel.selectPoint(at: idx)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.isBrowseMode = false
                            }
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(prog.reviewSquareColor)
                                    .frame(width: 9, height: 9)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(gp.japanese)
                                            .font(.japanese(size: 16, weight: .bold))
                                            .foregroundColor(inkColor)
                                        if let lvl = gp.jlptLevel {
                                            Text(lvl.rawValue)
                                                .font(.english(size: 10, weight: .bold))
                                                .foregroundColor(lvl == .n5 ? Color(hex: "#10B981") : Color(hex: "#3B82F6"))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background((lvl == .n5 ? Color(hex: "#10B981") : Color(hex: "#3B82F6")).opacity(0.12))
                                                .cornerRadius(4)
                                        }
                                        Text("Ch. \(gp.chapterNumber)")
                                            .font(.english(size: 10, weight: .semibold))
                                            .foregroundColor(mutedColor)
                                    }

                                    Text(gp.meaning)
                                        .font(.english(size: 13, weight: .medium))
                                        .foregroundColor(inkColor.opacity(0.85))
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(mutedColor)
                            }
                            .padding(12)
                            .background(isCurrent ? inkColor.opacity(0.08) : inkColor.opacity(0.035))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(hairlineColor, lineWidth: 0.7)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Test Mode Views (Preserved for Active Testing)
    @ViewBuilder
    private var testModeBanner: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: "#3B82F6"))
                    .frame(width: 7, height: 7)

                Text("Testing: \(viewModel.testScopeTitle)")
                    .font(.english(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "#3B82F6"))
            }

            Spacer()

            Text("Correct: \(viewModel.testCorrectCount)  Wrong: \(viewModel.testWrongCount)")
                .font(.english(size: 12))
                .foregroundColor(mutedColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(hex: "#3B82F6").opacity(0.08))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Test Progress")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("Answered \(viewModel.testCorrectCount + viewModel.testWrongCount)/\(viewModel.testTotalQuestions) items")
                        .font(.english(size: 12, weight: .regular))
                        .foregroundColor(mutedColor)
                }

                Spacer()

                Text("\(viewModel.displayPercentage)%")
                    .font(.english(size: 22, weight: .bold))
                    .foregroundColor(mutedColor)
            }

            SegmentedProgressBar(
                progress: viewModel.totalPointCount > 0 ? (Double(viewModel.completedPointCount) / Double(viewModel.totalPointCount)) : 0.0,
                totalSegments: 30,
                height: 28
            )
        }
    }

    @ViewBuilder
    private var testModeCardSection: some View {
        let point = viewModel.currentPoint
        let variant = viewModel.currentVariant

        VStack(alignment: .leading, spacing: 16) {
            if let q = viewModel.currentTestQuestion {
                Text(q.prompt)
                    .font(.japanese(size: 28, weight: .bold))
                    .foregroundColor(inkColor)
                    .fixedSize(horizontal: false, vertical: true)

                if !q.options.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(q.questionType.label)
                            .font(.english(size: 12, weight: .bold))
                            .foregroundColor(mutedColor)

                        ForEach(q.options, id: \.self) { option in
                            let isSelected = (viewModel.selectedOptionAnswer == option)
                            let isCorrectOption = (viewModel.lastSubmittedRecord?.correctAnswer == option)
                            let bgColor: Color = {
                                guard viewModel.lastSubmittedRecord != nil else {
                                    return themeManager.segmentEmptyColor.opacity(0.35)
                                }
                                if isCorrectOption { return Color(hex: "#10B981").opacity(0.18) }
                                if isSelected { return Color(hex: "#EF4444").opacity(0.18) }
                                return themeManager.segmentEmptyColor.opacity(0.25)
                            }()

                            Button {
                                if viewModel.lastSubmittedRecord == nil {
                                    viewModel.submitMultipleChoiceOption(option)
                                }
                            } label: {
                                HStack {
                                    Text(option)
                                        .font(.english(size: 14, weight: isSelected || isCorrectOption ? .bold : .regular))
                                        .foregroundColor(inkColor)
                                        .multilineTextAlignment(.leading)

                                    Spacer()

                                    if viewModel.lastSubmittedRecord != nil {
                                        if isCorrectOption {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(Color(hex: "#10B981"))
                                        } else if isSelected {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(Color(hex: "#EF4444"))
                                        }
                                    }
                                }
                                .padding(12)
                                .background(bgColor)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if viewModel.showTestNextButton {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(variant?.meaning ?? point.meaning)
                            .font(.english(size: 15, weight: .bold))
                            .foregroundColor(inkColor)
                        Text(variant?.explanation ?? point.explanation)
                            .font(.english(size: 12))
                            .foregroundColor(mutedColor)
                            .lineLimit(3)
                    }
                    Spacer()
                    Button {
                        viewModel.advanceToNextTestQuestion()
                    } label: {
                        HStack(spacing: 5) {
                            Text("Next")
                                .font(.english(size: 13, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(canvasColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(inkColor)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(inkColor.opacity(0.04))
                .cornerRadius(10)
            }
        }
    }

    @ViewBuilder
    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 32))
                .foregroundColor(mutedColor.opacity(0.7))

            Text("No Grammar Points Match Filter")
                .font(.english(size: 18, weight: .bold))
                .foregroundColor(inkColor)

            Button("Reset Filters") {
                viewModel.searchQuery = ""
                viewModel.selectedJLPTLevel = nil
                viewModel.selectedCategoryTag = nil
                viewModel.selectedChapterNumber = nil
            }
            .font(.english(size: 13, weight: .bold))
            .foregroundColor(Color(hex: "#3B82F6"))
        }
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity)
        .background(themeManager.segmentEmptyColor.opacity(0.35))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.english(size: 11, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? canvasColor : inkColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? inkColor : themeManager.segmentEmptyColor.opacity(0.4))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
