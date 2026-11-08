import SwiftUI

struct ParticlesView: View {
    @ObservedObject var viewModel: ParticlesViewModel
    @ObservedObject var grammarVM: GrammarViewModel
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
                        // Non-Test Mode: Clean Mode Switcher (Step-by-Step Study vs Browse All Particles)
                        studyModeControlBar

                        if viewModel.isBrowseMode {
                            browseParticlesSection
                                .padding(.bottom, 120)
                        } else {
                            focusedParticleLearnSection
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

                Text("Particles Studio • 助詞")
                    .font(.english(size: 22, weight: .bold))
                    .foregroundColor(inkColor)
            }

            Spacer()

            // Active Particle / Usage Counter
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 6) {
                    Button {
                        viewModel.cycleActiveUsageStatus()
                    } label: {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(viewModel.currentProgress.reviewSquareColor)
                            .frame(width: 11, height: 11)
                    }
                    .buttonStyle(.plain)

                    let displayNumber = viewModel.isTestModeActive
                        ? (viewModel.currentTestIndex + 1)
                        : (viewModel.particles.isEmpty ? 0 : (viewModel.currentParticleIndex + 1))
                    let totalCount = viewModel.isTestModeActive
                        ? viewModel.testTotalQuestions
                        : viewModel.particles.count

                    Text("\(displayNumber)")
                        .font(.english(size: 24, weight: .bold))
                        .foregroundColor(inkColor)
                    Text("/\(totalCount)")
                        .font(.english(size: 14, weight: .medium))
                        .foregroundColor(mutedColor)
                }

                Text("\(viewModel.completedUsageCount)/\(viewModel.totalUsageCount) usages (\(viewModel.displayPercentage)%)")
                    .font(.english(size: 11, weight: .medium))
                    .foregroundColor(mutedColor)
            }
        }
    }

    // MARK: - Study Mode Switcher & Level Filter Bar
    @ViewBuilder
    private var studyModeControlBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
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
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 12, weight: .semibold))
                        Text("All Particles (\(viewModel.particles.count))")
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

            // Quick Level Filter (All / N5 / N4) + Study vs Quiz Toggle
            HStack(spacing: 8) {
                ForEach([nil, JLPTLevel.n5, JLPTLevel.n4], id: \.self) { lvl in
                    let isSelected = (viewModel.selectedJLPTLevel == lvl)
                    Button {
                        viewModel.selectedJLPTLevel = lvl
                    } label: {
                        Text(lvl == nil ? "All Particles" : "Verified \(lvl!.rawValue)")
                            .font(.english(size: 12, weight: .bold))
                            .foregroundColor(isSelected ? canvasColor : inkColor)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(isSelected ? inkColor : inkColor.opacity(0.06))
                            .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

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

    // MARK: - Focused Step-by-Step Particle Learning Card
    @ViewBuilder
    private var focusedParticleLearnSection: some View {
        if viewModel.particles.isEmpty {
            emptyStateCard
        } else {
            let particle = viewModel.currentParticle
            let usages = viewModel.currentParticleUsages
            let usage = viewModel.currentUsage
            let entry = viewModel.currentSourceEntry
            let progress = viewModel.currentProgress
            let shouldHideAnswer = viewModel.isRecallQuizMode && !viewModel.isFlipped

            VStack(alignment: .leading, spacing: 14) {
                // 1. HERO PARTICLE & USAGE STEPPER CARD
                VStack(alignment: .leading, spacing: 12) {
                    // Top Breadcrumb: Category, Source # & Streak
                    HStack(spacing: 8) {
                        if let level = usage?.jlptLevel {
                            Text(level.rawValue)
                                .font(.english(size: 11, weight: .bold))
                                .foregroundColor(level == .n5 ? Color(hex: "#10B981") : Color(hex: "#3B82F6"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background((level == .n5 ? Color(hex: "#10B981") : Color(hex: "#3B82F6")).opacity(0.12))
                                .cornerRadius(6)
                        }

                        if let cat = particle.categories.first {
                            Text(cat.displayName)
                                .font(.english(size: 11, weight: .semibold))
                                .foregroundColor(mutedColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(inkColor.opacity(0.05))
                                .cornerRadius(6)
                        }

                        if let entry = entry {
                            Text("#\(entry.sourceNumber)/188")
                                .font(.english(size: 11, weight: .medium))
                                .foregroundColor(mutedColor)
                        }

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

                    // Large Particle Character + Romaji + Speaker
                    HStack(alignment: .center, spacing: 14) {
                        Text(particle.japanese)
                            .font(.japanese(size: 40, weight: .bold))
                            .foregroundColor(inkColor)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(particle.romaji)
                                .font(.english(size: 18, weight: .bold))
                                .foregroundColor(inkColor.opacity(0.85))

                            if let alts = particle.alternativeReadings, !alts.isEmpty {
                                Text("Also read: \(alts.joined(separator: ", "))")
                                    .font(.english(size: 12, weight: .regular))
                                    .foregroundColor(mutedColor)
                            }
                        }

                        Spacer()

                        Button {
                            viewModel.speakCurrentParticle()
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(inkColor)
                                .frame(width: 40, height: 40)
                                .background(inkColor.opacity(0.07))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    // Usage Stepper Pills (If this particle has multiple meanings/usages, step through 1 at a time!)
                    if usages.count > 1 {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("USAGE \(viewModel.currentUsageIndex + 1) OF \(usages.count) FOR 「\(particle.japanese)」")
                                    .font(.english(size: 10, weight: .bold))
                                    .tracking(0.8)
                                    .foregroundColor(Color(hex: "#3B82F6"))

                                Spacer()

                                HStack(spacing: 6) {
                                    Button {
                                        if viewModel.currentUsageIndex > 0 {
                                            viewModel.selectUsage(at: viewModel.currentUsageIndex - 1)
                                        }
                                    } label: {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(viewModel.currentUsageIndex > 0 ? inkColor : mutedColor.opacity(0.4))
                                            .frame(width: 24, height: 24)
                                            .background(inkColor.opacity(0.06))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(viewModel.currentUsageIndex <= 0)

                                    Button {
                                        if viewModel.currentUsageIndex + 1 < usages.count {
                                            viewModel.selectUsage(at: viewModel.currentUsageIndex + 1)
                                        }
                                    } label: {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(viewModel.currentUsageIndex + 1 < usages.count ? inkColor : mutedColor.opacity(0.4))
                                            .frame(width: 24, height: 24)
                                            .background(inkColor.opacity(0.06))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(viewModel.currentUsageIndex + 1 >= usages.count)
                                }
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(usages.indices, id: \.self) { uIdx in
                                        let isCurrentUsage = (uIdx == viewModel.currentUsageIndex)
                                        let uProg = ParticleDataService.shared.progress(particleId: particle.id, usageId: usages[uIdx].id)
                                        Button {
                                            viewModel.selectUsage(at: uIdx)
                                        } label: {
                                            HStack(spacing: 5) {
                                                Circle()
                                                    .fill(uProg.reviewSquareColor)
                                                    .frame(width: 6, height: 6)
                                                Text("Usage \(uIdx + 1)")
                                                    .font(.english(size: 11, weight: isCurrentUsage ? .bold : .medium))
                                            }
                                            .foregroundColor(isCurrentUsage ? canvasColor : inkColor)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(isCurrentUsage ? inkColor : inkColor.opacity(0.06))
                                            .cornerRadius(7)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(inkColor.opacity(0.035))
                        .cornerRadius(9)
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
                                Text("Tap to Reveal Meaning & Examples")
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
                            Text("WHAT IT MEANS IN THIS USAGE")
                                .font(.english(size: 10, weight: .bold))
                                .tracking(1.0)
                                .foregroundColor(Color(hex: "#10B981"))

                            Text(usage?.meaning ?? entry?.originalMeaning ?? "")
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

                if !shouldHideAnswer, let usage = usage {
                    // 2. SENTENCE PATTERN BLUEPRINT
                    if !usage.pattern.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "link")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: "#3B82F6"))
                                Text("SENTENCE PATTERN")
                                    .font(.english(size: 11, weight: .bold))
                                    .tracking(0.8)
                                    .foregroundColor(mutedColor)
                            }

                            Text(usage.pattern)
                                .font(.japanese(size: 16, weight: .bold))
                                .foregroundColor(inkColor)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(hex: "#3B82F6").opacity(0.08))
                                .cornerRadius(9)
                        }
                        .padding(16)
                        .background(inkColor.opacity(0.035))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(hairlineColor, lineWidth: 0.8)
                        )
                    }

                    // 3. CLEAR EXPLANATION
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "#F59E0B"))
                            Text("HOW IT WORKS")
                                .font(.english(size: 11, weight: .bold))
                                .tracking(0.8)
                                .foregroundColor(mutedColor)
                        }

                        Text(usage.explanation)
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

                    // 4. VERIFIED EXAMPLES (Tap to Listen)
                    if !usage.examples.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "text.bubble.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: "#10B981"))
                                Text("EXAMPLES • TAP TO LISTEN")
                                    .font(.english(size: 11, weight: .bold))
                                    .tracking(0.8)
                                    .foregroundColor(mutedColor)
                            }

                            ForEach(Array(usage.examples.enumerated()), id: \.element.id) { idx, ex in
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

                    // 5. RELATED GRAMMAR LINKS
                    if !usage.grammarPointIds.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("RELATED GRAMMAR PATTERNS")
                                .font(.english(size: 10, weight: .bold))
                                .foregroundColor(mutedColor)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(usage.grammarPointIds, id: \.self) { gid in
                                        let gp = GrammarDataService.shared.point(forId: gid)
                                        Button {
                                            grammarVM.isBrowseMode = false
                                            grammarVM.selectPoint(byId: gid)
                                            navVM.selectItem(.bunpou)
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "link")
                                                    .font(.system(size: 10, weight: .bold))
                                                Text(gp?.title ?? gid)
                                                    .font(.japanese(size: 12, weight: .bold))
                                            }
                                            .foregroundColor(Color(hex: "#3B82F6"))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color(hex: "#3B82F6").opacity(0.12))
                                            .cornerRadius(7)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }

                // 6. PREVIOUS / NEXT STEPPER BAR
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
                        .foregroundColor(inkColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(inkColor.opacity(0.06))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.startTest(
                            scopeTitle: "Particle 「\(particle.japanese)」",
                            particleIds: [particle.id]
                        )
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                            Text("Quiz 「\(particle.japanese)」")
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
                        .foregroundColor(canvasColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(inkColor)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }

                // 7. OPTIONAL COLLAPSIBLE DRAWER FOR ALL USAGES OF THIS PARTICLE
                if usages.count > 1 {
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.showAllUsagesDrawer.toggle()
                            }
                        } label: {
                            HStack {
                                Text("All \(usages.count) Usages of 「\(particle.japanese)」")
                                    .font(.english(size: 13, weight: .bold))
                                    .foregroundColor(inkColor)
                                Spacer()
                                Text(viewModel.showAllUsagesDrawer ? "Hide List" : "Show All")
                                    .font(.english(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: "#3B82F6"))
                                Image(systemName: viewModel.showAllUsagesDrawer ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: "#3B82F6"))
                            }
                            .padding(12)
                            .background(inkColor.opacity(0.04))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)

                        if viewModel.showAllUsagesDrawer {
                            allUsagesListSection(for: particle)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Browse All Particles Directory
    @ViewBuilder
    private var browseParticlesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(mutedColor)

                TextField("Search particle (は, に, で), romaji, or meaning...", text: $viewModel.searchQuery)
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

            // Category Filter Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    filterChip(title: "All Categories", isSelected: viewModel.selectedCategory == nil) {
                        viewModel.selectedCategory = nil
                    }
                    ForEach(ParticleCategory.allCases) { cat in
                        filterChip(title: cat.displayName, isSelected: viewModel.selectedCategory == cat) {
                            viewModel.selectedCategory = (viewModel.selectedCategory == cat) ? nil : cat
                        }
                    }
                }
            }

            if viewModel.particles.isEmpty {
                emptyStateCard
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(viewModel.particles.enumerated()), id: \.element.id) { idx, p in
                        let diff = ParticleDataService.shared.aggregateDifficulty(for: p)
                        let pUsages = ParticleDataService.shared.usages(forParticleId: p.id)
                        let primaryMeaning = pUsages.first?.meaning ?? ""
                        let isCurrent = (idx == viewModel.currentParticleIndex)

                        Button {
                            viewModel.selectParticle(at: idx)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.isBrowseMode = false
                            }
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(diff.color)
                                    .frame(width: 9, height: 9)

                                Text(p.japanese)
                                    .font(.japanese(size: 20, weight: .bold))
                                    .foregroundColor(inkColor)
                                    .frame(width: 58, alignment: .leading)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(p.romaji)
                                            .font(.english(size: 13, weight: .bold))
                                            .foregroundColor(inkColor)

                                        Text("\(p.usageIds.count) usage\(p.usageIds.count == 1 ? "" : "s")")
                                            .font(.english(size: 10, weight: .semibold))
                                            .foregroundColor(Color(hex: "#3B82F6"))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(hex: "#3B82F6").opacity(0.12))
                                            .cornerRadius(4)
                                    }

                                    Text(primaryMeaning)
                                        .font(.english(size: 12, weight: .regular))
                                        .foregroundColor(mutedColor)
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

    // MARK: - Test Mode Views
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
                progress: viewModel.totalUsageCount > 0 ? (Double(viewModel.completedUsageCount) / Double(viewModel.totalUsageCount)) : 0.0,
                totalSegments: 30,
                height: 28
            )
        }
    }

    @ViewBuilder
    private var testModeCardSection: some View {
        let usage = viewModel.currentUsage

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
                        Text(usage?.meaning ?? "")
                            .font(.english(size: 15, weight: .bold))
                            .foregroundColor(inkColor)
                        Text(usage?.explanation ?? "")
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

    // MARK: - All Usages List for Current Particle (Inside Collapsible Drawer)
    @ViewBuilder
    private func allUsagesListSection(for particle: Particle) -> some View {
        let usages = viewModel.currentParticleUsages

        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.selectedUsageIds.isEmpty {
                HStack {
                    Text("\(viewModel.selectedUsageIds.count) usages selected")
                        .font(.english(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#3B82F6"))
                    Spacer()
                    Button("Quiz Selected") {
                        viewModel.startTest(
                            scopeTitle: "\(viewModel.selectedUsageIds.count) Selected Usages",
                            usageIds: Array(viewModel.selectedUsageIds)
                        )
                    }
                    .font(.english(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "#3B82F6"))
                    .cornerRadius(6)
                }
                .padding(10)
                .background(Color(hex: "#3B82F6").opacity(0.08))
                .cornerRadius(8)
            }

            ForEach(usages.indices, id: \.self) { idx in
                let u = usages[idx]
                let isCurrent = (idx == viewModel.currentUsageIndex)
                let isChecked = viewModel.selectedUsageIds.contains(u.id)
                let src = ParticleDataService.shared.sourceEntry(forUsageId: u.id)
                let prog = ParticleDataService.shared.progress(particleId: particle.id, usageId: u.id)

                HStack(alignment: .top, spacing: 10) {
                    Button {
                        viewModel.toggleUsageSelection(u.id)
                    } label: {
                        Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                            .font(.system(size: 16))
                            .foregroundColor(isChecked ? Color(hex: "#3B82F6") : mutedColor)
                            .padding(.top, 2)
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.selectUsage(at: idx)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Rectangle()
                                    .fill(prog.reviewSquareColor)
                                    .frame(width: 8, height: 8)

                                if let srcNum = src?.sourceNumber {
                                    Text("#\(srcNum)")
                                        .font(.english(size: 11, weight: .bold))
                                        .foregroundColor(mutedColor)
                                }

                                Text(u.meaning)
                                    .font(.english(size: 14, weight: isCurrent ? .bold : .medium))
                                    .foregroundColor(inkColor)
                                    .multilineTextAlignment(.leading)

                                Spacer()
                            }

                            Text(u.pattern)
                                .font(.japanese(size: 12))
                                .foregroundColor(mutedColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(isCurrent ? themeManager.segmentEmptyColor.opacity(0.55) : themeManager.segmentEmptyColor.opacity(0.22))
                .cornerRadius(10)
            }
        }
    }

    @ViewBuilder
    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(mutedColor.opacity(0.7))

            Text("No Particles Match Filter")
                .font(.english(size: 18, weight: .bold))
                .foregroundColor(inkColor)

            Button("Reset Filters") {
                viewModel.searchQuery = ""
                viewModel.selectedCategory = nil
                viewModel.selectedJLPTLevel = nil
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
