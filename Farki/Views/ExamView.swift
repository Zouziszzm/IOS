import SwiftUI

struct ExamView: View {
    @ObservedObject var viewModel: ExamViewModel
    @ObservedObject var navVM: NavigationViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared
    @Environment(\.openURL) private var openURL

    private var inkColor: Color { themeManager.inkColor }
    private var canvasColor: Color { themeManager.canvasColor }
    private var mutedColor: Color { themeManager.mutedColor }
    private var hairlineColor: Color { themeManager.hairlineColor }

    var body: some View {
        ZStack {
            canvasColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top spacer to clear persistent app header logo
                Color.clear
                    .frame(height: 38)

                switch viewModel.destination {
                case .landing:
                    landingView
                case .fullLengthSetup:
                    fullLengthSetupView
                case .chapterWiseSetup:
                    chapterWiseSetupView
                case .sectionWiseSetup:
                    sectionWiseSetupView
                case .history:
                    historyView
                case .instructions(let paper):
                    instructionsView(for: paper)
                case .activeAttempt:
                    activeAttemptView
                case .results(let attemptId):
                    resultsView(attemptId: attemptId)
                }
            }
            .safeAreaPadding(.top)
        }
        .sheet(isPresented: $viewModel.showQuestionNavigatorSheet) {
            questionNavigatorSheet
        }
        .alert("Leave Unfinished Exam?", isPresented: $viewModel.showLeaveConfirmationAlert) {
            Button("Save & Exit", role: .destructive) {
                viewModel.saveAndExitAttempt()
            }
            Button("Continue Exam", role: .cancel) {}
        } message: {
            Text("Your selected answers, flagged questions, and remaining time will be saved so you can resume later.")
        }
        .alert("Submit Exam?", isPresented: $viewModel.showSubmitConfirmationAlert) {
            Button("Submit Now", role: .destructive) {
                viewModel.finalizeSubmission(didTimeout: false)
            }
            Button("Review Questions", role: .cancel) {}
        } message: {
            if let attempt = viewModel.activeAttempt {
                let unanswered = attempt.questions.count - attempt.answeredCount
                let flagged = attempt.flaggedQuestionIds.count
                Text("You have \(unanswered) unanswered question(s) and \(flagged) flagged question(s). Are you sure you want to submit?")
            } else {
                Text("Are you sure you want to submit your exam?")
            }
        }
    }

    // MARK: - 1. Exam Landing Page (Section 1)
    private var landingView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("EXAM CENTER")
                        .font(.english(size: 11, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(mutedColor)

                    Text("Mock Exams & Chapter Tests")
                        .font(.english(size: 26, weight: .bold))
                        .foregroundColor(inkColor)
                }
                .padding(.top, 8)

                // Resume In-Progress Banner
                if let inProgress = viewModel.inProgressAttempts.first {
                    resumeAttemptBanner(inProgress)
                }

                // Four Destinations (Section 1)
                VStack(spacing: 12) {
                    destinationCard(
                        number: "01",
                        title: "Full-Length Exams",
                        subtitle: "Timed N5 and N4 mock exams with official JLPT section structure",
                        badgeText: "N5 • N4",
                        accentHex: "#3B82F6"
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.destination = .fullLengthSetup
                        }
                    }

                    destinationCard(
                        number: "02",
                        title: "Chapter-Wise Tests",
                        subtitle: "Tests generated strictly from selected Minna no Nihongo chapters or ranges",
                        badgeText: "Ch. \(viewModel.availableChapters.first ?? 1)+",
                        accentHex: "#10B981"
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.destination = .chapterWiseSetup
                        }
                    }

                    destinationCard(
                        number: "03",
                        title: "Section-Wise Practice",
                        subtitle: "Vocabulary, Kanji, Grammar, Reading, and Listening in Practice or Exam mode",
                        badgeText: "5 Sections",
                        accentHex: "#F59E0B"
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.destination = .sectionWiseSetup
                        }
                    }

                    destinationCard(
                        number: "04",
                        title: "Exam History",
                        subtitle: "Previous attempts, section breakdowns, weak areas, and retry missed items",
                        badgeText: "\(viewModel.completedAttempts.count) Completed",
                        accentHex: "#8B5CF6"
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.destination = .history
                        }
                    }
                }

                // External Reference Links (Section 6 Licensing Compliance)
                VStack(alignment: .leading, spacing: 10) {
                    Text("OFFICIAL & OPEN JLPT REFERENCES")
                        .font(.english(size: 11, weight: .bold))
                        .tracking(1.1)
                        .foregroundColor(mutedColor)
                        .padding(.top, 6)

                    ForEach(ExamService.shared.externalResources) { res in
                        Button {
                            if let url = URL(string: res.urlString) {
                                openURL(url)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(hex: "#3B82F6"))
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(res.title)
                                            .font(.english(size: 14, weight: .bold))
                                            .foregroundColor(inkColor)
                                        Spacer()
                                        Text(res.levelLabel)
                                            .font(.english(size: 11, weight: .semibold))
                                            .foregroundColor(mutedColor)
                                    }
                                    Text("\(res.attribution) • \(res.licenseNote)")
                                        .font(.english(size: 11, weight: .regular))
                                        .foregroundColor(mutedColor)
                                        .lineLimit(2)
                                }
                            }
                            .padding(12)
                            .background(inkColor.opacity(0.035))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(hairlineColor, lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 95)
            }
            .padding(.horizontal, 24)
        }
    }

    private func resumeAttemptBanner(_ attempt: ExamAttempt) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("IN PROGRESS")
                    .font(.english(size: 10, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(Color(hex: "#F59E0B"))
                Spacer()
                Text("\(attempt.answeredCount)/\(attempt.questions.count) Answered")
                    .font(.english(size: 11, weight: .medium))
                    .foregroundColor(mutedColor)
            }

            Text(attempt.examTitle)
                .font(.english(size: 16, weight: .bold))
                .foregroundColor(inkColor)

            HStack(spacing: 10) {
                Button {
                    viewModel.resumeAttempt(attempt)
                } label: {
                    Text("Resume Exam")
                        .font(.english(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#3B82F6"))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    _ = ExamService.shared.submitAttempt(attemptId: attempt.id)
                    viewModel.refreshHistory()
                } label: {
                    Text("Submit Now")
                        .font(.english(size: 13, weight: .semibold))
                        .foregroundColor(inkColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(inkColor.opacity(0.08))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(hex: "#F59E0B").opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#F59E0B").opacity(0.35), lineWidth: 1)
        )
    }

    private func destinationCard(
        number: String,
        title: String,
        subtitle: String,
        badgeText: String,
        accentHex: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Text(number)
                        .font(.english(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: accentHex))
                    Text(title)
                        .font(.english(size: 18, weight: .bold))
                        .foregroundColor(inkColor)
                    Spacer()
                    Text(badgeText)
                        .font(.english(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: accentHex))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: accentHex).opacity(0.12))
                        .cornerRadius(6)
                }

                Text(subtitle)
                    .font(.english(size: 13, weight: .regular))
                    .foregroundColor(mutedColor)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(inkColor.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(hairlineColor, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2. Full-Length & Grouped Exam Paper Browser (Section 2)
    private var fullLengthSetupView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                backHeader(title: "Exam Papers & Mock Tests") {
                    viewModel.destination = .landing
                }

                // Level Selector (N5 / N4 / All)
                VStack(alignment: .leading, spacing: 8) {
                    Text("SELECT JLPT LEVEL")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)

                    HStack(spacing: 10) {
                        ForEach([JLPTLevel.n5, JLPTLevel.n4, JLPTLevel.all], id: \.self) { lvl in
                            let selected = (viewModel.selectedFullLengthLevel == lvl)
                            Button {
                                viewModel.selectedFullLengthLevel = lvl
                            } label: {
                                Text(lvl == .all ? "All (N5 & N4)" : lvl.rawValue)
                                    .font(.english(size: 14, weight: .bold))
                                    .foregroundColor(selected ? canvasColor : inkColor)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(selected ? inkColor : inkColor.opacity(0.06))
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Scope Toggle: All 82 Papers vs Full-Length Mock Papers Only
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showAllPaperTypesInBrowser = true
                        }
                    } label: {
                        Text("All Papers (Full, Section & Chapter)")
                            .font(.english(size: 12, weight: .bold))
                            .foregroundColor(viewModel.showAllPaperTypesInBrowser ? canvasColor : inkColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(viewModel.showAllPaperTypesInBrowser ? inkColor : inkColor.opacity(0.06))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showAllPaperTypesInBrowser = false
                        }
                    } label: {
                        Text("Full-Length Only")
                            .font(.english(size: 12, weight: .bold))
                            .foregroundColor(!viewModel.showAllPaperTypesInBrowser ? canvasColor : inkColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(!viewModel.showAllPaperTypesInBrowser ? inkColor : inkColor.opacity(0.06))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                // Timed vs Untimed Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Official Section Time Limits")
                            .font(.english(size: 14, weight: .bold))
                            .foregroundColor(inkColor)
                        Text(viewModel.isFullLengthTimed ? "Auto-submits when timer expires" : "Untimed practice paper")
                            .font(.english(size: 12, weight: .regular))
                            .foregroundColor(mutedColor)
                    }
                    Spacer()
                    Toggle("", isOn: $viewModel.isFullLengthTimed)
                        .labelsHidden()
                }
                .padding(14)
                .background(inkColor.opacity(0.04))
                .cornerRadius(10)

                // Group By Selector (Type, Time, Difficulty, Source)
                paperGroupingBar

                // Grouped Exam Papers
                groupedPapersList(
                    sections: viewModel.groupedBrowserSections,
                    allowInstructionsForFullLength: true
                )

                Spacer(minLength: 95)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Reusable Paper Grouping Bar & Collapsible Group Sections
    private var paperGroupingBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("GROUP PAPERS BY")
                    .font(.english(size: 11, weight: .bold))
                    .foregroundColor(mutedColor)
                Spacer()
                if !viewModel.collapsedGroupIds.isEmpty {
                    Button("Expand All") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.collapsedGroupIds.removeAll()
                        }
                    }
                    .font(.english(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#3B82F6"))
                }
            }

            HStack(spacing: 8) {
                ForEach(ExamPaperGroupMode.allCases) { mode in
                    let isSelected = (viewModel.paperGroupMode == mode)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.paperGroupMode = mode
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 11, weight: .semibold))
                            Text(mode.rawValue)
                                .font(.english(size: 12, weight: .bold))
                        }
                        .foregroundColor(isSelected ? canvasColor : inkColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(isSelected ? inkColor : inkColor.opacity(0.06))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func groupedPapersList(
        sections: [ExamPaperGroupSection],
        allowInstructionsForFullLength: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(sections) { group in
                let isCollapsed = viewModel.collapsedGroupIds.contains(group.id)
                VStack(alignment: .leading, spacing: 10) {
                    // Group Header Button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.toggleGroupCollapsed(group.id)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: group.iconName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: group.accentHex))
                                .frame(width: 28, height: 28)
                                .background(Color(hex: group.accentHex).opacity(0.14))
                                .cornerRadius(7)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.title)
                                    .font(.english(size: 14, weight: .bold))
                                    .foregroundColor(inkColor)
                                    .multilineTextAlignment(.leading)
                                Text(group.subtitle)
                                    .font(.english(size: 11, weight: .medium))
                                    .foregroundColor(mutedColor)
                            }

                            Spacer()

                            Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(mutedColor)
                        }
                        .padding(12)
                        .background(inkColor.opacity(0.055))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(hex: group.accentHex).opacity(0.3), lineWidth: 0.9)
                        )
                    }
                    .buttonStyle(.plain)

                    if !isCollapsed {
                        VStack(spacing: 10) {
                            ForEach(group.papers) { paper in
                                groupedPaperCard(
                                    paper: paper,
                                    allowInstructionsForFullLength: allowInstructionsForFullLength
                                )
                            }
                        }
                        .padding(.leading, 6)
                    }
                }
            }
        }
    }

    private func groupedPaperCard(
        paper: ExamPaper,
        allowInstructionsForFullLength: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Metadata Chips: Difficulty, Type, Time, Question Count
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // 1. Difficulty & Level chip
                    Text(paper.difficultyShortBadge)
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: paper.difficultyHexColor))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: paper.difficultyHexColor).opacity(0.12))
                        .cornerRadius(6)

                    // 2. Type / Section chip (Listening, Reading, Grammar, Vocab, Kanji, Full-Length, Chapter)
                    HStack(spacing: 4) {
                        Image(systemName: paper.primaryTypeIcon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(paper.shortTypeBadge)
                            .font(.english(size: 11, weight: .semibold))
                    }
                    .foregroundColor(inkColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(inkColor.opacity(0.07))
                    .cornerRadius(6)

                    // 3. Time chip
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 10, weight: .semibold))
                        Text(paper.formattedDuration)
                            .font(.english(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "#8B5CF6"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#8B5CF6").opacity(0.12))
                    .cornerRadius(6)

                    // 4. Question count chip
                    Text("\(paper.questionIds.count) Qs")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(inkColor.opacity(0.05))
                        .cornerRadius(6)
                }
            }

            // Paper Title
            Text(paper.title)
                .font(.english(size: 16, weight: .bold))
                .foregroundColor(inkColor)

            // Section breakdown for multi-section papers
            if paper.sections.count > 1 {
                ForEach(paper.sections) { sec in
                    HStack {
                        Text("• \(sec.title)")
                            .font(.english(size: 12, weight: .medium))
                            .foregroundColor(inkColor.opacity(0.85))
                        Spacer()
                        Text("\(sec.durationSeconds / 60)m")
                            .font(.english(size: 11, weight: .regular))
                            .foregroundColor(mutedColor)
                    }
                }
            }

            // Source & License row
            HStack(spacing: 6) {
                Image(systemName: "building.columns")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#0EA5E9"))
                Text("Source: \(paper.sourceTitle) (\(paper.license))")
                    .font(.english(size: 11, weight: .medium))
                    .foregroundColor(mutedColor)
                    .lineLimit(1)
            }

            // Action Buttons
            if paper.kind == .fullLength && allowInstructionsForFullLength {
                HStack(spacing: 8) {
                    Button {
                        viewModel.openInstructions(for: paper)
                    } label: {
                        Text(ExamService.shared.activeAttempt(forExamId: paper.id) != nil ? "Resume / Instructions" : "Instructions & Timed Start")
                            .font(.english(size: 13, weight: .bold))
                            .foregroundColor(canvasColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(inkColor)
                            .cornerRadius(9)
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.beginBundledPaper(paper, isTimed: false, deliveryMode: .practice)
                    } label: {
                        Text("Practice Mode")
                            .font(.english(size: 13, weight: .bold))
                            .foregroundColor(inkColor)
                            .padding(.horizontal, 14)
                            .frame(height: 40)
                            .background(inkColor.opacity(0.08))
                            .cornerRadius(9)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack(spacing: 8) {
                    Button {
                        viewModel.beginBundledPaper(paper, isTimed: true, deliveryMode: .exam)
                    } label: {
                        Text("Start Timed (\(paper.formattedDuration))")
                            .font(.english(size: 13, weight: .bold))
                            .foregroundColor(canvasColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(inkColor)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.beginBundledPaper(paper, isTimed: false, deliveryMode: .practice)
                    } label: {
                        Text("Practice Mode")
                            .font(.english(size: 13, weight: .bold))
                            .foregroundColor(inkColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(inkColor.opacity(0.08))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(inkColor.opacity(0.038))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(hairlineColor, lineWidth: 0.8)
        )
    }

    private func instructionsView(for paper: ExamPaper) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                backHeader(title: "Exam Instructions") {
                    viewModel.destination = .fullLengthSetup
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(paper.title)
                        .font(.english(size: 20, weight: .bold))
                        .foregroundColor(inkColor)

                    Text("Mode: \(viewModel.isFullLengthTimed ? "Timed (\(paper.formattedDuration))" : "Untimed") • Feedback Hidden Until Submission")
                        .font(.english(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#3B82F6"))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("SECTION STRUCTURE")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)

                    ForEach(paper.sections) { sec in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(sec.title)
                                    .font(.english(size: 14, weight: .bold))
                                    .foregroundColor(inkColor)
                                Spacer()
                                Text("\(sec.durationSeconds / 60) min")
                                    .font(.english(size: 12, weight: .semibold))
                                    .foregroundColor(mutedColor)
                            }
                            Text(sec.japaneseTitle)
                                .font(.japanese(size: 13, weight: .medium))
                                .foregroundColor(inkColor.opacity(0.8))
                            Text(sec.description)
                                .font(.english(size: 12, weight: .regular))
                                .foregroundColor(mutedColor)
                        }
                        .padding(12)
                        .background(inkColor.opacity(0.04))
                        .cornerRadius(10)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("EXAM RULES & SAFEGUARDS")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)

                    bulletRow("You can change answers and flag questions at any time before submitting.")
                    bulletRow("Your progress and timer are automatically saved if you leave and resume.")
                    bulletRow("Correctness feedback and explanations remain hidden until final submission.")
                    bulletRow("When the timer reaches 00:00, your exam is submitted automatically.")
                    bulletRow("Practice Score Disclaimer: Raw percentages are practice scores and are not official JLPT scaled scores.")
                }
                .padding(14)
                .background(inkColor.opacity(0.035))
                .cornerRadius(10)

                Button {
                    viewModel.beginFullLengthExam(paper)
                } label: {
                    Text("Begin \(paper.level.rawValue) Full-Length Exam")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(canvasColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(inkColor)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 95)
            }
            .padding(.horizontal, 24)
        }
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.english(size: 13, weight: .bold))
                .foregroundColor(inkColor)
            Text(text)
                .font(.english(size: 13, weight: .regular))
                .foregroundColor(inkColor.opacity(0.85))
        }
    }

    // MARK: - 3. Chapter-Wise Tests Setup (Section 3)
    private var chapterWiseSetupView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                backHeader(title: "Chapter-Wise Tests (Ch. 1–50)") {
                    viewModel.destination = .landing
                }

                // Level Selection: All (Ch. 1–50), N5 (Ch. 1–25), N4 (Ch. 26–50)
                VStack(alignment: .leading, spacing: 8) {
                    Text("CURRICULUM LEVEL")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)

                    HStack(spacing: 8) {
                        ForEach([JLPTLevel.all, JLPTLevel.n5, JLPTLevel.n4], id: \.self) { lvl in
                            let selected = (viewModel.selectedChapterLevel == lvl)
                            let label: String = {
                                switch lvl {
                                case .all: return "All (Ch. 1–50)"
                                case .n5: return "N5 (Ch. 1–25)"
                                case .n4: return "N4 (Ch. 26–50)"
                                default: return lvl.rawValue
                                }
                            }()
                            Button {
                                viewModel.selectChapterLevel(lvl)
                            } label: {
                                Text(label)
                                    .font(.english(size: 13, weight: .bold))
                                    .foregroundColor(selected ? canvasColor : inkColor)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(selected ? inkColor : inkColor.opacity(0.06))
                                    .cornerRadius(9)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Custom Chapter Builder (Chapters 1–25 N5 + Chapters 26–50 N4 Grid)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("SELECT CHAPTER(S)")
                            .font(.english(size: 11, weight: .bold))
                            .foregroundColor(mutedColor)
                        Spacer()
                        Picker("Selection Mode", selection: $viewModel.chapterSelectionMode) {
                            ForEach(ExamViewModel.ChapterSelectionMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 210)
                    }

                    if viewModel.chapterSelectionMode == .multiple {
                        HStack(spacing: 8) {
                            Button("Select N5 (Ch. 1–25)") {
                                viewModel.selectedChapters = Set(viewModel.availableChapters.filter { $0 <= 25 })
                            }
                            .font(.english(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#10B981"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#10B981").opacity(0.12))
                            .cornerRadius(7)
                            .buttonStyle(.plain)

                            Button("Select N4 (Ch. 26–50)") {
                                viewModel.selectedChapters = Set(viewModel.availableChapters.filter { $0 >= 26 })
                            }
                            .font(.english(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#3B82F6"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#3B82F6").opacity(0.12))
                            .cornerRadius(7)
                            .buttonStyle(.plain)

                            Button("All 1–50") {
                                viewModel.selectedChapters = Set(viewModel.availableChapters)
                            }
                            .font(.english(size: 11, weight: .bold))
                            .foregroundColor(inkColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(inkColor.opacity(0.08))
                            .cornerRadius(7)
                            .buttonStyle(.plain)
                        }
                    }

                    if viewModel.chapterSelectionMode == .range {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("From Chapter")
                                    .font(.english(size: 12, weight: .medium))
                                    .foregroundColor(mutedColor)
                                Picker("From", selection: $viewModel.rangeStartChapter) {
                                    ForEach(viewModel.availableChaptersForSelectedLevel, id: \.self) { ch in
                                        Text("Ch. \(ch) (\(ch <= 25 ? "N5" : "N4"))").tag(ch)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("To Chapter")
                                    .font(.english(size: 12, weight: .medium))
                                    .foregroundColor(mutedColor)
                                Picker("To", selection: $viewModel.rangeEndChapter) {
                                    ForEach(viewModel.availableChaptersForSelectedLevel, id: \.self) { ch in
                                        Text("Ch. \(ch) (\(ch <= 25 ? "N5" : "N4"))").tag(ch)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        .padding(12)
                        .background(inkColor.opacity(0.04))
                        .cornerRadius(10)
                    } else {
                        let visibleChapters = viewModel.availableChaptersForSelectedLevel
                        let n5Chs = visibleChapters.filter { $0 <= 25 }
                        let n4Chs = visibleChapters.filter { $0 >= 26 }

                        VStack(alignment: .leading, spacing: 12) {
                            if !n5Chs.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("JLPT N5 • Book 1 (Chapters 1–25)")
                                        .font(.english(size: 11, weight: .bold))
                                        .foregroundColor(Color(hex: "#10B981"))

                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                                        ForEach(n5Chs, id: \.self) { ch in
                                            let isSelected = viewModel.selectedChapters.contains(ch)
                                            Button {
                                                viewModel.toggleChapter(ch)
                                            } label: {
                                                Text("Ch. \(ch)")
                                                    .font(.english(size: 12, weight: .bold))
                                                    .foregroundColor(isSelected ? .white : inkColor)
                                                    .frame(maxWidth: .infinity)
                                                    .frame(height: 36)
                                                    .background(isSelected ? Color(hex: "#10B981") : inkColor.opacity(0.06))
                                                    .cornerRadius(7)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }

                            if !n4Chs.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("JLPT N4 • Book 2 (Chapters 26–50)")
                                        .font(.english(size: 11, weight: .bold))
                                        .foregroundColor(Color(hex: "#3B82F6"))

                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                                        ForEach(n4Chs, id: \.self) { ch in
                                            let isSelected = viewModel.selectedChapters.contains(ch)
                                            Button {
                                                viewModel.toggleChapter(ch)
                                            } label: {
                                                Text("Ch. \(ch)")
                                                    .font(.english(size: 12, weight: .bold))
                                                    .foregroundColor(isSelected ? .white : inkColor)
                                                    .frame(maxWidth: .infinity)
                                                    .frame(height: 36)
                                                    .background(isSelected ? Color(hex: "#3B82F6") : inkColor.opacity(0.06))
                                                    .cornerRadius(7)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Category Selection (Vocabulary, Kanji, Grammar, or Mixed)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("QUESTION CATEGORIES")
                            .font(.english(size: 11, weight: .bold))
                            .foregroundColor(mutedColor)
                        Spacer()
                        Button("Select Mixed (All)") {
                            viewModel.selectMixedChapterCategories()
                        }
                        .font(.english(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#3B82F6"))
                    }

                    HStack(spacing: 8) {
                        ForEach(ExamQuestionCategory.chapterWiseCategories) { cat in
                            let selected = viewModel.selectedChapterCategories.contains(cat)
                            Button {
                                viewModel.toggleChapterCategory(cat)
                            } label: {
                                Text(cat.displayName)
                                    .font(.english(size: 13, weight: .bold))
                                    .foregroundColor(selected ? canvasColor : inkColor)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .background(selected ? inkColor : inkColor.opacity(0.06))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Question Count & Optional Timer
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("QUESTION COUNT")
                            .font(.english(size: 11, weight: .bold))
                            .foregroundColor(mutedColor)
                        Spacer()
                        Text("\(viewModel.availableChapterQuestionCount) available in selected chapter(s)")
                            .font(.english(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#10B981"))
                    }

                    HStack(spacing: 8) {
                        ForEach([5, 10, 15, 25, 50], id: \.self) { count in
                            let selected = (viewModel.chapterQuestionCount == count)
                            Button {
                                viewModel.chapterQuestionCount = count
                            } label: {
                                Text("\(count)")
                                    .font(.english(size: 13, weight: .bold))
                                    .foregroundColor(selected ? canvasColor : inkColor)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(selected ? inkColor : inkColor.opacity(0.06))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if viewModel.chapterQuestionCount > viewModel.availableChapterQuestionCount {
                        Text("Note: Only \(viewModel.availableChapterQuestionCount) verified question(s) exist in the selected chapter(s) for \(viewModel.selectedChapterLevel.rawValue). The test will include those \(viewModel.availableChapterQuestionCount) question(s) without adding items from other chapters.")
                            .font(.english(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#F59E0B"))
                            .padding(.top, 2)
                    }
                }

                // Timer & Delivery Mode
                VStack(alignment: .leading, spacing: 8) {
                    Text("OPTIONAL TIMER (MINUTES)")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)

                    HStack(spacing: 8) {
                        ForEach([0, 10, 15, 20, 30], id: \.self) { mins in
                            let selected = (viewModel.chapterDurationMinutes == mins)
                            Button {
                                viewModel.chapterDurationMinutes = mins
                            } label: {
                                Text(mins == 0 ? "Untimed" : "\(mins)m")
                                    .font(.english(size: 13, weight: .bold))
                                    .foregroundColor(selected ? canvasColor : inkColor)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(selected ? inkColor : inkColor.opacity(0.06))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                deliveryModePicker(selection: $viewModel.chapterDeliveryMode)

                if let notice = viewModel.chapterAvailabilityNotice {
                    Text(notice)
                        .font(.english(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#EF4444"))
                }

                Button {
                    viewModel.beginChapterWiseTest()
                } label: {
                    Text("Start Custom Chapter-Wise Test")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(canvasColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(viewModel.availableChapterQuestionCount > 0 ? inkColor : inkColor.opacity(0.3))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.availableChapterQuestionCount == 0)

                // Ready-to-Take Bundled Chapter Exam Papers (Ch. 1–25 N5 + Ch. 26–50 N4, Grouped by Type, Time, Difficulty, or Source)
                if !viewModel.filteredChapterPapers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("READY-TO-TAKE CHAPTER PAPERS (CH. 1–50)")
                            .font(.english(size: 11, weight: .bold))
                            .foregroundColor(mutedColor)
                            .padding(.top, 8)

                        paperGroupingBar
                        groupedPapersList(
                            sections: viewModel.groupedChapterPaperSections,
                            allowInstructionsForFullLength: false
                        )
                    }
                }

                Spacer(minLength: 95)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - 4. Section-Wise Practice Setup (Section 4)
    private var sectionWiseSetupView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                backHeader(title: "Section-Wise Practice") {
                    viewModel.destination = .landing
                }

                // Level Selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("JLPT LEVEL")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)

                    HStack(spacing: 10) {
                        ForEach([JLPTLevel.n5, JLPTLevel.n4], id: \.self) { lvl in
                            let selected = (viewModel.selectedSectionLevel == lvl)
                            Button {
                                viewModel.selectedSectionLevel = lvl
                            } label: {
                                Text(lvl.rawValue)
                                    .font(.english(size: 14, weight: .bold))
                                    .foregroundColor(selected ? canvasColor : inkColor)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(selected ? inkColor : inkColor.opacity(0.06))
                                    .cornerRadius(9)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Category Selector (Vocabulary, Kanji, Grammar, Reading, Listening)
                VStack(alignment: .leading, spacing: 8) {
                    Text("SELECT SECTION")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)

                    ForEach(ExamQuestionCategory.allCases) { cat in
                        let selected = (viewModel.selectedSectionCategory == cat)
                        Button {
                            viewModel.selectedSectionCategory = cat
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: cat.iconName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(selected ? canvasColor : inkColor)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.displayName)
                                        .font(.english(size: 15, weight: .bold))
                                        .foregroundColor(selected ? canvasColor : inkColor)
                                    Text(cat.japaneseTitle)
                                        .font(.japanese(size: 12, weight: .regular))
                                        .foregroundColor(selected ? canvasColor.opacity(0.8) : mutedColor)
                                }
                                Spacer()
                                if selected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(canvasColor)
                                }
                            }
                            .padding(12)
                            .background(selected ? inkColor : inkColor.opacity(0.05))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Ready-to-Take Bundled Section Exam Papers (Grouped by Type, Time, Difficulty, or Source)
                if !viewModel.filteredSectionPapers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        paperGroupingBar
                        groupedPapersList(
                            sections: viewModel.groupedSectionPaperSections,
                            allowInstructionsForFullLength: false
                        )
                    }
                }

                // Custom Section Session Builder
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("CUSTOM QUESTION COUNT")
                            .font(.english(size: 11, weight: .bold))
                            .foregroundColor(mutedColor)
                        Spacer()
                        Text("\(viewModel.availableSectionQuestionCount) total available")
                            .font(.english(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#10B981"))
                    }

                    HStack(spacing: 8) {
                        ForEach([5, 10, 15, 25], id: \.self) { count in
                            let selected = (viewModel.sectionQuestionCount == count)
                            Button {
                                viewModel.sectionQuestionCount = count
                            } label: {
                                Text("\(count)")
                                    .font(.english(size: 13, weight: .bold))
                                    .foregroundColor(selected ? canvasColor : inkColor)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(selected ? inkColor : inkColor.opacity(0.06))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                deliveryModePicker(selection: $viewModel.sectionDeliveryMode)

                Button {
                    viewModel.beginSectionWisePractice()
                } label: {
                    Text("Start Custom \(viewModel.selectedSectionCategory.displayName) Session")
                        .font(.english(size: 15, weight: .bold))
                        .foregroundColor(canvasColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(inkColor)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 95)
            }
            .padding(.horizontal, 24)
        }
    }

    private func deliveryModePicker(selection: Binding<ExamDeliveryMode>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FEEDBACK MODE")
                .font(.english(size: 11, weight: .bold))
                .foregroundColor(mutedColor)

            HStack(spacing: 10) {
                ForEach(ExamDeliveryMode.allCases) { mode in
                    let isSelected = (selection.wrappedValue == mode)
                    Button {
                        selection.wrappedValue = mode
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.displayName)
                                .font(.english(size: 14, weight: .bold))
                                .foregroundColor(isSelected ? canvasColor : inkColor)
                            Text(mode.subtitle)
                                .font(.english(size: 11, weight: .regular))
                                .foregroundColor(isSelected ? canvasColor.opacity(0.8) : mutedColor)
                                .lineLimit(2)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(isSelected ? inkColor : inkColor.opacity(0.05))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 5. Active Exam / Test Runner View
    private var activeAttemptView: some View {
        VStack(spacing: 0) {
            if let attempt = viewModel.activeAttempt,
               let question = viewModel.currentPublicQuestion {
                // Top Exam Bar
                HStack(spacing: 10) {
                    Button {
                        viewModel.showLeaveConfirmationAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Exit")
                        }
                        .font(.english(size: 13, weight: .semibold))
                        .foregroundColor(inkColor)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Timer Badge
                    HStack(spacing: 5) {
                        Image(systemName: attempt.isTimed ? "timer" : "clock")
                            .font(.system(size: 12))
                        Text(viewModel.formattedClockText)
                            .font(.english(size: 13, weight: .bold))
                            .monospacedDigit()
                    }
                    .foregroundColor(attempt.isTimed ? Color(hex: "#F59E0B") : inkColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(inkColor.opacity(0.06))
                    .cornerRadius(8)

                    // Flag Question Button
                    Button {
                        viewModel.toggleCurrentQuestionFlag()
                    } label: {
                        Image(systemName: viewModel.isCurrentQuestionFlagged ? "flag.fill" : "flag")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(viewModel.isCurrentQuestionFlagged ? Color(hex: "#F59E0B") : inkColor)
                            .frame(width: 32, height: 32)
                            .background(inkColor.opacity(0.06))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    // Question Navigator Grid Button
                    Button {
                        viewModel.showQuestionNavigatorSheet = true
                    } label: {
                        Text("\(viewModel.currentQuestionIndex + 1)/\(attempt.questions.count)")
                            .font(.english(size: 12, weight: .bold))
                            .foregroundColor(inkColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(inkColor.opacity(0.06))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    // Submit Button
                    Button {
                        viewModel.requestSubmitAttempt()
                    } label: {
                        Text("Submit")
                            .font(.english(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#3B82F6"))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                Divider()
                    .background(hairlineColor)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        if let notice = viewModel.bannerNoticeText {
                            Text(notice)
                                .font(.english(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#3B82F6"))
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(hex: "#3B82F6").opacity(0.08))
                                .cornerRadius(8)
                        }

                        // Category & Level Header
                        HStack {
                            Text("\(question.level.rawValue) • \(question.category.displayName.uppercased())")
                                .font(.english(size: 11, weight: .bold))
                                .tracking(1.0)
                                .foregroundColor(mutedColor)

                            Spacer()

                            if !question.chapterIds.isEmpty {
                                Text("Ch. \(question.chapterIds.map(String.init).joined(separator: ", "))")
                                    .font(.english(size: 11, weight: .semibold))
                                    .foregroundColor(mutedColor)
                            }
                        }

                        // Reading Passage Box (kept together for passage-grouped questions)
                        if let passage = question.passageText, !passage.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("READING PASSAGE / CONTEXT")
                                    .font(.english(size: 10, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(mutedColor)

                                Text(passage)
                                    .font(.japanese(size: 16, weight: .regular))
                                    .foregroundColor(inkColor)
                                    .lineSpacing(5)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(inkColor.opacity(0.045))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(hairlineColor, lineWidth: 0.8)
                            )
                        }

                        // Listening Audio Player Button
                        if question.category == .listening || question.audioScript != nil {
                            Button {
                                viewModel.playListeningAudio(for: question)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Play Listening Audio (Japanese TTS)")
                                        .font(.english(size: 14, weight: .bold))
                                    Spacer()
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 20))
                                }
                                .foregroundColor(Color(hex: "#3B82F6"))
                                .padding(14)
                                .background(Color(hex: "#3B82F6").opacity(0.10))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }

                        // Question Prompt
                        Text(question.prompt)
                            .font(.japanese(size: 20, weight: .bold))
                            .foregroundColor(inkColor)
                            .fixedSize(horizontal: false, vertical: true)

                        if let ctx = question.context, !ctx.isEmpty {
                            Text(ctx)
                                .font(.english(size: 13, weight: .regular))
                                .foregroundColor(mutedColor)
                        }

                        // Answer Choices (Allows changing answers anytime in Exam mode)
                        VStack(spacing: 10) {
                            ForEach(Array(question.choices.enumerated()), id: \.offset) { idx, choice in
                                let isSelected = (viewModel.currentSelectedChoice == choice)
                                let feedback = viewModel.currentPracticeFeedback

                                Button {
                                    viewModel.chooseOption(choice)
                                } label: {
                                    HStack(spacing: 12) {
                                        Text("\(idx + 1)")
                                            .font(.english(size: 13, weight: .bold))
                                            .foregroundColor(isSelected ? canvasColor : inkColor)
                                            .frame(width: 26, height: 26)
                                            .background(isSelected ? inkColor : inkColor.opacity(0.08))
                                            .clipShape(Circle())

                                        Text(choice)
                                            .font(.japanese(size: 16, weight: .medium))
                                            .foregroundColor(inkColor)
                                            .multilineTextAlignment(.leading)

                                        Spacer()

                                        if let fb = feedback {
                                            if choice == fb.correctAnswer {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(Color(hex: "#10B981"))
                                            } else if isSelected && !fb.isCorrect {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(Color(hex: "#EF4444"))
                                            }
                                        } else if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(Color(hex: "#3B82F6"))
                                        }
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(isSelected ? inkColor.opacity(0.09) : inkColor.opacity(0.035))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isSelected ? inkColor : hairlineColor, lineWidth: isSelected ? 1.4 : 0.8)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Practice Mode Immediate Feedback Box (Hidden in Exam Mode until submission!)
                        if let feedback = viewModel.currentPracticeFeedback {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: feedback.isCorrect ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                        .foregroundColor(feedback.isCorrect ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                                    Text(feedback.isCorrect ? "Correct" : "Incorrect — Correct Answer: \(feedback.correctAnswer)")
                                        .font(.english(size: 13, weight: .bold))
                                        .foregroundColor(feedback.isCorrect ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                                }
                                Text(feedback.explanation)
                                    .font(.english(size: 13, weight: .regular))
                                    .foregroundColor(inkColor.opacity(0.9))
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background((feedback.isCorrect ? Color(hex: "#10B981") : Color(hex: "#EF4444")).opacity(0.08))
                            .cornerRadius(10)
                        }

                        // Prev / Next Controls
                        HStack(spacing: 12) {
                            Button {
                                viewModel.previousQuestion()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.left")
                                    Text("Previous")
                                }
                                .font(.english(size: 14, weight: .bold))
                                .foregroundColor(inkColor)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(inkColor.opacity(0.06))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.currentQuestionIndex == 0)
                            .opacity(viewModel.currentQuestionIndex == 0 ? 0.4 : 1.0)

                            if viewModel.currentQuestionIndex + 1 < attempt.questions.count {
                                Button {
                                    viewModel.nextQuestion()
                                } label: {
                                    HStack {
                                        Text("Next")
                                        Image(systemName: "arrow.right")
                                    }
                                    .font(.english(size: 14, weight: .bold))
                                    .foregroundColor(canvasColor)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(inkColor)
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    viewModel.requestSubmitAttempt()
                                } label: {
                                    Text("Finish & Submit")
                                        .font(.english(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(Color(hex: "#10B981"))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 8)

                        Spacer(minLength: 95)
                    }
                    .padding(20)
                }
            }
        }
    }

    // MARK: - Question Navigator Sheet
    private var questionNavigatorSheet: some View {
        NavigationStack {
            ScrollView {
                if let attempt = viewModel.activeAttempt {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                        ForEach(Array(attempt.questions.enumerated()), id: \.element.id) { idx, q in
                            let isAnswered = !(attempt.selectedAnswers[q.id]?.isEmpty ?? true)
                            let isFlagged = attempt.flaggedQuestionIds.contains(q.id)
                            let isCurrent = (idx == viewModel.currentQuestionIndex)

                            Button {
                                viewModel.jumpToQuestion(at: idx)
                                viewModel.showQuestionNavigatorSheet = false
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Text("\(idx + 1)")
                                        .font(.english(size: 14, weight: .bold))
                                        .foregroundColor(isCurrent ? canvasColor : inkColor)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(
                                            isCurrent
                                                ? inkColor
                                                : (isAnswered ? Color(hex: "#10B981").opacity(0.18) : inkColor.opacity(0.06))
                                        )
                                        .cornerRadius(8)

                                    if isFlagged {
                                        Image(systemName: "flag.fill")
                                            .font(.system(size: 9))
                                            .foregroundColor(Color(hex: "#F59E0B"))
                                            .padding(4)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Question Navigator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        viewModel.showQuestionNavigatorSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - 6. Results & Review Screen (Section 8)
    private func resultsView(attemptId: String) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            if let attempt = viewModel.attemptForResults(attemptId) {
                VStack(alignment: .leading, spacing: 18) {
                    backHeader(title: "Exam Results") {
                        viewModel.destination = .landing
                    }

                    // Summary Score Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(attempt.status.displayLabel.uppercased())
                                .font(.english(size: 10, weight: .bold))
                                .tracking(1.0)
                                .foregroundColor(Color(hex: "#3B82F6"))
                            Spacer()
                            Text("Time Used: \(ExamViewModel.formatSeconds(attempt.elapsedSeconds))")
                                .font(.english(size: 12, weight: .semibold))
                                .foregroundColor(mutedColor)
                        }

                        Text(attempt.examTitle)
                            .font(.english(size: 20, weight: .bold))
                            .foregroundColor(inkColor)

                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(attempt.scorePercentage)%")
                                .font(.english(size: 38, weight: .bold))
                                .foregroundColor(inkColor)

                            Text("\(attempt.correctCount) / \(attempt.totalQuestions) Correct")
                                .font(.english(size: 15, weight: .semibold))
                                .foregroundColor(mutedColor)
                        }

                        HStack(spacing: 14) {
                            statPill(label: "Correct", value: attempt.correctCount, colorHex: "#10B981")
                            statPill(label: "Incorrect", value: attempt.incorrectCount, colorHex: "#EF4444")
                            statPill(label: "Unanswered", value: attempt.unansweredCount, colorHex: "#F59E0B")
                        }

                        // Practice Score Disclaimer (Section 2 Requirement)
                        Text("Practice Score Only: Raw percentages reflect accuracy on this practice set and are not official JLPT scaled scores.")
                            .font(.english(size: 11, weight: .regular))
                            .foregroundColor(mutedColor)
                            .padding(.top, 4)
                    }
                    .padding(16)
                    .background(inkColor.opacity(0.04))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(hairlineColor, lineWidth: 0.8)
                    )

                    // Section / Category Breakdown
                    if !attempt.sectionResults.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SECTION BREAKDOWN")
                                .font(.english(size: 11, weight: .bold))
                                .foregroundColor(mutedColor)

                            ForEach(attempt.sectionResults) { sec in
                                HStack {
                                    Text(sec.title)
                                        .font(.english(size: 14, weight: .bold))
                                        .foregroundColor(inkColor)
                                    Spacer()
                                    Text("\(sec.correctCount)/\(sec.totalQuestions) (\(sec.scorePercentage)%)")
                                        .font(.english(size: 13, weight: .semibold))
                                        .foregroundColor(inkColor)
                                }
                                .padding(12)
                                .background(inkColor.opacity(0.035))
                                .cornerRadius(8)
                            }
                        }
                    }

                    // Retry Incorrect & Retake Actions (Section 8)
                    HStack(spacing: 10) {
                        if attempt.incorrectCount + attempt.unansweredCount > 0 {
                            Button {
                                viewModel.retryIncorrect(from: attempt.id)
                            } label: {
                                Text("Retry Missed (\(attempt.incorrectCount + attempt.unansweredCount))")
                                    .font(.english(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color(hex: "#EF4444"))
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            viewModel.retakeFullAttempt(from: attempt.id)
                        } label: {
                            Text("Retake Test")
                                .font(.english(size: 13, weight: .bold))
                                .foregroundColor(canvasColor)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(inkColor)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }

                    // Answer Review Filter
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("ANSWER REVIEW & EXPLANATIONS")
                                .font(.english(size: 11, weight: .bold))
                                .foregroundColor(mutedColor)
                            Spacer()
                        }

                        Picker("Filter", selection: $viewModel.reviewFilter) {
                            ForEach(ExamViewModel.ResultsReviewFilter.allCases) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)

                        ForEach(viewModel.filteredReviewItems(for: attempt)) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(item.category.displayName.uppercased())
                                        .font(.english(size: 10, weight: .bold))
                                        .foregroundColor(mutedColor)
                                    if item.isFlagged {
                                        Label("Flagged", systemImage: "flag.fill")
                                            .font(.english(size: 10, weight: .bold))
                                            .foregroundColor(Color(hex: "#F59E0B"))
                                    }
                                    Spacer()
                                    Text(item.isCorrect ? "Correct" : (item.isUnanswered ? "Unanswered" : "Incorrect"))
                                        .font(.english(size: 11, weight: .bold))
                                        .foregroundColor(
                                            item.isCorrect
                                                ? Color(hex: "#10B981")
                                                : (item.isUnanswered ? Color(hex: "#F59E0B") : Color(hex: "#EF4444"))
                                        )
                                }

                                Text(item.prompt)
                                    .font(.japanese(size: 16, weight: .bold))
                                    .foregroundColor(inkColor)

                                Text("Your Answer: \(item.selectedAnswer ?? "— (Unanswered)")")
                                    .font(.english(size: 13, weight: .medium))
                                    .foregroundColor(item.isCorrect ? Color(hex: "#10B981") : Color(hex: "#EF4444"))

                                if !item.isCorrect {
                                    Text("Verified Correct Answer: \(item.correctAnswer)")
                                        .font(.english(size: 13, weight: .bold))
                                        .foregroundColor(Color(hex: "#10B981"))
                                }

                                Text(item.explanation)
                                    .font(.english(size: 12, weight: .regular))
                                    .foregroundColor(inkColor.opacity(0.85))

                                Text("Source: \(item.sourceTitle) • \(item.license)")
                                    .font(.english(size: 10, weight: .regular))
                                    .foregroundColor(mutedColor)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(inkColor.opacity(0.035))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(hairlineColor, lineWidth: 0.8)
                            )
                        }
                    }

                    Spacer(minLength: 95)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func statPill(label: String, value: Int, colorHex: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 7, height: 7)
            Text("\(label): \(value)")
                .font(.english(size: 12, weight: .semibold))
                .foregroundColor(inkColor)
        }
    }

    // MARK: - 7. Exam History & Weak Areas View (Section 1 & 8)
    private var historyView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                backHeader(title: "Exam History & Weak Areas") {
                    viewModel.destination = .landing
                }

                // Weak Areas Summary
                let weakAreas = ExamService.shared.weakCategoriesSummary()
                if !weakAreas.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CATEGORY ACCURACY (WEAKEST FIRST)")
                            .font(.english(size: 11, weight: .bold))
                            .foregroundColor(mutedColor)

                        ForEach(weakAreas, id: \.category.id) { entry in
                            HStack {
                                Text(entry.category.displayName)
                                    .font(.english(size: 14, weight: .bold))
                                    .foregroundColor(inkColor)
                                Spacer()
                                Text("\(entry.accuracy)% (\(entry.totalAnswered) qs)")
                                    .font(.english(size: 13, weight: .semibold))
                                    .foregroundColor(entry.accuracy < 70 ? Color(hex: "#EF4444") : Color(hex: "#10B981"))
                            }
                            .padding(12)
                            .background(inkColor.opacity(0.04))
                            .cornerRadius(8)
                        }
                    }
                }

                // Completed Attempts List
                VStack(alignment: .leading, spacing: 10) {
                    Text("PAST ATTEMPTS")
                        .font(.english(size: 11, weight: .bold))
                        .foregroundColor(mutedColor)

                    if viewModel.completedAttempts.isEmpty {
                        Text("No completed exam attempts yet. Start a Full-Length Exam, Chapter-Wise Test, or Section-Wise Practice session to track your scores.")
                            .font(.english(size: 13, weight: .regular))
                            .foregroundColor(mutedColor)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(viewModel.completedAttempts) { attempt in
                            Button {
                                viewModel.reviewFilter = .all
                                viewModel.destination = .results(attempt.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(attempt.examTitle)
                                            .font(.english(size: 15, weight: .bold))
                                            .foregroundColor(inkColor)
                                        Spacer()
                                        Text("\(attempt.scorePercentage)%")
                                            .font(.english(size: 16, weight: .bold))
                                            .foregroundColor(Color(hex: "#3B82F6"))
                                    }
                                    HStack {
                                        Text("\(attempt.correctCount)/\(attempt.totalQuestions) Correct • \(ExamViewModel.formatSeconds(attempt.elapsedSeconds))")
                                            .font(.english(size: 12, weight: .regular))
                                            .foregroundColor(mutedColor)
                                        Spacer()
                                        Text("View Review →")
                                            .font(.english(size: 12, weight: .semibold))
                                            .foregroundColor(inkColor)
                                    }
                                }
                                .padding(14)
                                .background(inkColor.opacity(0.04))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(hairlineColor, lineWidth: 0.8)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: 95)
            }
            .padding(.horizontal, 24)
        }
    }

    private func backHeader(title: String, onBack: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.english(size: 14, weight: .semibold))
                .foregroundColor(inkColor)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title)
                .font(.english(size: 16, weight: .bold))
                .foregroundColor(inkColor)

            Spacer()
        }
        .padding(.top, 6)
    }
}

