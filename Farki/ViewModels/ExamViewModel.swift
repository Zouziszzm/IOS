import SwiftUI
import Combine

final class ExamViewModel: ObservableObject {
    // MARK: - Navigation State
    @Published var destination: ExamScreenDestination = .landing

    // MARK: - Full-Length Setup & Paper Grouping State
    @Published var selectedFullLengthLevel: JLPTLevel = .all
    @Published var isFullLengthTimed: Bool = true
    @Published var fullLengthDeliveryMode: ExamDeliveryMode = .exam
    @Published var paperGroupMode: ExamPaperGroupMode = .type
    @Published var showAllPaperTypesInBrowser: Bool = true
    @Published var collapsedGroupIds: Set<String> = []

    // MARK: - Chapter-Wise Setup State (Section 3)
    @Published var selectedChapterLevel: JLPTLevel = .all
    @Published var chapterSelectionMode: ChapterSelectionMode = .single
    @Published var selectedChapters: Set<Int> = [1]
    @Published var rangeStartChapter: Int = 1
    @Published var rangeEndChapter: Int = 1
    @Published var selectedChapterCategories: Set<ExamQuestionCategory> = [.vocabulary, .kanji, .grammar]
    @Published var chapterQuestionCount: Int = 15
    @Published var chapterDurationMinutes: Int = 0 // 0 = untimed
    @Published var chapterDeliveryMode: ExamDeliveryMode = .exam
    @Published var chapterAvailabilityNotice: String? = nil

    // MARK: - Section-Wise Setup State (Section 4)
    @Published var selectedSectionLevel: JLPTLevel = .n5
    @Published var selectedSectionCategory: ExamQuestionCategory = .vocabulary
    @Published var sectionQuestionCount: Int = 10
    @Published var sectionDurationMinutes: Int = 0 // 0 = untimed
    @Published var sectionDeliveryMode: ExamDeliveryMode = .practice
    @Published var sectionAvailabilityNotice: String? = nil

    // MARK: - Active Attempt State (Section 2 & 7)
    @Published var activeAttempt: ExamAttempt? = nil
    @Published var currentQuestionIndex: Int = 0
    @Published var elapsedSeconds: Int = 0
    @Published var showLeaveConfirmationAlert: Bool = false
    @Published var showSubmitConfirmationAlert: Bool = false
    @Published var showQuestionNavigatorSheet: Bool = false
    @Published var bannerNoticeText: String? = nil

    // MARK: - Results Review Filter State (Section 8)
    @Published var reviewFilter: ResultsReviewFilter = .all

    // MARK: - History & Analytics State
    @Published var attemptsHistory: [ExamAttempt] = []

    enum ChapterSelectionMode: String, CaseIterable, Identifiable {
        case single = "Single"
        case multiple = "Multiple"
        case range = "Range"

        var id: String { rawValue }
    }

    enum ResultsReviewFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case incorrect = "Incorrect"
        case unanswered = "Unanswered"
        case flagged = "Flagged"

        var id: String { rawValue }
    }

    private var timerCancellable: AnyCancellable?
    private var dataUpdateCancellable: AnyCancellable?

    init() {
        refreshHistory()
        let chs = ExamService.shared.availableChapters
        if let first = chs.first {
            selectedChapters = [first]
            rangeStartChapter = first
            rangeEndChapter = chs.last ?? first
        }

        dataUpdateCancellable = NotificationCenter.default.publisher(for: .examDataUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshHistory()
            }
    }

    func refreshHistory() {
        attemptsHistory = ExamService.shared.attempts
        if let active = activeAttempt,
           let updated = ExamService.shared.attempts.first(where: { $0.id == active.id }) {
            activeAttempt = updated
        }
    }

    // MARK: - Computed Helpers
    var availableChapters: [Int] {
        ExamService.shared.availableChapters
    }

    var availableChaptersForSelectedLevel: [Int] {
        let all = availableChapters
        switch selectedChapterLevel {
        case .n5:
            let n5Chs = all.filter { $0 <= 25 }
            return n5Chs.isEmpty ? all : n5Chs
        case .n4:
            let n4Chs = all.filter { $0 >= 26 }
            return n4Chs.isEmpty ? all : n4Chs
        default:
            return all
        }
    }

    var effectiveSelectedChapters: Set<Int> {
        switch chapterSelectionMode {
        case .single, .multiple:
            return selectedChapters
        case .range:
            let low = min(rangeStartChapter, rangeEndChapter)
            let high = max(rangeStartChapter, rangeEndChapter)
            return Set(availableChapters.filter { $0 >= low && $0 <= high })
        }
    }

    var availableChapterQuestionCount: Int {
        ExamService.shared.availableChapterQuestions(
            level: selectedChapterLevel,
            chapters: effectiveSelectedChapters,
            categories: selectedChapterCategories
        ).count
    }

    var availableSectionQuestionCount: Int {
        ExamService.shared.availableSectionQuestions(
            level: selectedSectionLevel,
            category: selectedSectionCategory
        ).count
    }

    var filteredFullLengthPapers: [ExamPaper] {
        ExamService.shared.fullLengthExams.filter {
            selectedFullLengthLevel == .all || $0.level == selectedFullLengthLevel
        }
    }

    var filteredAllLevelPapersForBrowser: [ExamPaper] {
        let base: [ExamPaper]
        if showAllPaperTypesInBrowser {
            base = ExamService.shared.fullLengthExams
                + ExamService.shared.sectionPapers
                + ExamService.shared.chapterPapers
        } else {
            base = ExamService.shared.fullLengthExams
        }
        return base.filter {
            selectedFullLengthLevel == .all || $0.level == selectedFullLengthLevel
        }
    }

    var filteredSectionPapers: [ExamPaper] {
        ExamService.shared.sectionPapers.filter { paper in
            let matchesLevel = (selectedSectionLevel == .all || paper.level == selectedSectionLevel)
            let paperCats = Set(paper.sections.flatMap(\.categories))
            return matchesLevel && paperCats.contains(selectedSectionCategory)
        }
    }

    var filteredChapterPapers: [ExamPaper] {
        ExamService.shared.chapterPapers.filter { paper in
            selectedChapterLevel == .all || paper.level == selectedChapterLevel
        }
    }

    var groupedBrowserSections: [ExamPaperGroupSection] {
        groupPapers(filteredAllLevelPapersForBrowser, by: paperGroupMode)
    }

    var groupedSectionPaperSections: [ExamPaperGroupSection] {
        groupPapers(filteredSectionPapers, by: paperGroupMode)
    }

    var groupedChapterPaperSections: [ExamPaperGroupSection] {
        groupPapers(filteredChapterPapers, by: paperGroupMode)
    }

    func toggleGroupCollapsed(_ groupId: String) {
        if collapsedGroupIds.contains(groupId) {
            collapsedGroupIds.remove(groupId)
        } else {
            collapsedGroupIds.insert(groupId)
        }
    }

    func groupPapers(_ papers: [ExamPaper], by mode: ExamPaperGroupMode) -> [ExamPaperGroupSection] {
        guard !papers.isEmpty else { return [] }
        var order: [String] = []
        var bucketMap: [String: [ExamPaper]] = [:]

        for paper in papers {
            let key: String
            switch mode {
            case .type:
                key = paper.primaryTypeLabel
            case .time:
                key = paper.durationBucketLabel
            case .difficulty:
                key = paper.difficultyGroupLabel
            case .source:
                key = paper.sourceGroupLabel
            }
            if bucketMap[key] == nil {
                order.append(key)
                bucketMap[key] = []
            }
            bucketMap[key]?.append(paper)
        }

        return order.compactMap { key in
            guard let items = bucketMap[key], let first = items.first else { return nil }
            let totalQs = items.reduce(0) { $0 + $1.questionIds.count }
            let icon: String
            let accent: String
            switch mode {
            case .type:
                icon = first.primaryTypeIcon
                switch first.kind {
                case .fullLength: accent = "#3B82F6"
                case .chapter: accent = "#10B981"
                case .section: accent = "#F59E0B"
                }
            case .time:
                icon = "clock.fill"
                accent = "#8B5CF6"
            case .difficulty:
                icon = "chart.bar.fill"
                accent = first.difficultyHexColor
            case .source:
                icon = "building.columns.fill"
                accent = "#0EA5E9"
            }
            return ExamPaperGroupSection(
                id: "\(mode.rawValue)-\(key)",
                title: key,
                subtitle: "\(items.count) paper\(items.count == 1 ? "" : "s") • \(totalQs) total questions",
                iconName: icon,
                accentHex: accent,
                papers: items
            )
        }
    }

    var inProgressAttempts: [ExamAttempt] {
        attemptsHistory.filter { $0.status == .inProgress }
    }

    var completedAttempts: [ExamAttempt] {
        attemptsHistory.filter { $0.status != .inProgress }
    }

    var currentPublicQuestion: ExamPublicQuestion? {
        guard let attempt = activeAttempt,
              attempt.questions.indices.contains(currentQuestionIndex) else { return nil }
        return attempt.questions[currentQuestionIndex]
    }

    var currentSelectedChoice: String? {
        guard let attempt = activeAttempt,
              let q = currentPublicQuestion else { return nil }
        return attempt.selectedAnswers[q.id]
    }

    var isCurrentQuestionFlagged: Bool {
        guard let attempt = activeAttempt,
              let q = currentPublicQuestion else { return false }
        return attempt.flaggedQuestionIds.contains(q.id)
    }

    var currentPracticeFeedback: ExamQuestionReviewItem? {
        guard let attempt = activeAttempt,
              attempt.deliveryMode == .practice,
              let q = currentPublicQuestion else { return nil }
        return attempt.practiceFeedbackByQuestionId[q.id]
    }

    var formattedClockText: String {
        guard let attempt = activeAttempt else { return "00:00" }
        if attempt.isTimed, let limit = attempt.durationLimitSeconds {
            let rem = max(0, limit - elapsedSeconds)
            let m = rem / 60
            let s = rem % 60
            return String(format: "%02d:%02d", m, s)
        } else {
            let m = elapsedSeconds / 60
            let s = elapsedSeconds % 60
            return String(format: "%02d:%02d", m, s)
        }
    }

    // MARK: - Actions: Full-Length Exam
    func openInstructions(for paper: ExamPaper) {
        bannerNoticeText = nil
        destination = .instructions(paper)
    }

    func beginFullLengthExam(_ paper: ExamPaper) {
        let attempt = ExamService.shared.startFullLengthExam(
            paper: paper,
            isTimed: isFullLengthTimed,
            deliveryMode: fullLengthDeliveryMode
        )
        launchAttempt(attempt, notice: nil)
    }

    func beginBundledPaper(_ paper: ExamPaper, isTimed: Bool, deliveryMode: ExamDeliveryMode) {
        let attempt = ExamService.shared.startFullLengthExam(
            paper: paper,
            isTimed: isTimed,
            deliveryMode: deliveryMode
        )
        launchAttempt(attempt, notice: nil)
    }

    // MARK: - Actions: Chapter-Wise Test (Section 3)
    func selectChapterLevel(_ lvl: JLPTLevel) {
        selectedChapterLevel = lvl
        chapterAvailabilityNotice = nil
        let validChs = availableChaptersForSelectedLevel
        if let first = validChs.first {
            if selectedChapters.intersection(Set(validChs)).isEmpty {
                selectedChapters = [first]
            } else {
                selectedChapters = selectedChapters.intersection(Set(validChs))
            }
            rangeStartChapter = first
            rangeEndChapter = validChs.last ?? first
        }
    }
    func toggleChapter(_ ch: Int) {
        switch chapterSelectionMode {
        case .single:
            selectedChapters = [ch]
        case .multiple:
            if selectedChapters.contains(ch) {
                if selectedChapters.count > 1 {
                    selectedChapters.remove(ch)
                }
            } else {
                selectedChapters.insert(ch)
            }
        case .range:
            break
        }
        chapterAvailabilityNotice = nil
    }

    func toggleChapterCategory(_ cat: ExamQuestionCategory) {
        if selectedChapterCategories.contains(cat) {
            if selectedChapterCategories.count > 1 {
                selectedChapterCategories.remove(cat)
            }
        } else {
            selectedChapterCategories.insert(cat)
        }
        chapterAvailabilityNotice = nil
    }

    func selectMixedChapterCategories() {
        selectedChapterCategories = Set(ExamQuestionCategory.chapterWiseCategories)
        chapterAvailabilityNotice = nil
    }

    func beginChapterWiseTest() {
        let durationSecs = chapterDurationMinutes > 0 ? chapterDurationMinutes * 60 : nil
        let (attempt, _, notice) = ExamService.shared.startChapterWiseTest(
            level: selectedChapterLevel,
            chapters: effectiveSelectedChapters,
            categories: selectedChapterCategories,
            requestedQuestionCount: chapterQuestionCount,
            durationSeconds: durationSecs,
            deliveryMode: chapterDeliveryMode
        )
        chapterAvailabilityNotice = notice
        guard let validAttempt = attempt else { return }
        launchAttempt(validAttempt, notice: notice)
    }

    // MARK: - Actions: Section-Wise Practice (Section 4)
    func beginSectionWisePractice() {
        let durationSecs = sectionDurationMinutes > 0 ? sectionDurationMinutes * 60 : nil
        let (attempt, _, notice) = ExamService.shared.startSectionWisePractice(
            level: selectedSectionLevel,
            category: selectedSectionCategory,
            requestedQuestionCount: sectionQuestionCount,
            durationSeconds: durationSecs,
            deliveryMode: sectionDeliveryMode
        )
        sectionAvailabilityNotice = notice
        guard let validAttempt = attempt else { return }
        launchAttempt(validAttempt, notice: notice)
    }

    // MARK: - Launch or Resume Attempt
    func launchAttempt(_ attempt: ExamAttempt, notice: String? = nil) {
        self.activeAttempt = attempt
        self.currentQuestionIndex = min(attempt.currentQuestionIndex, max(0, attempt.questions.count - 1))
        self.elapsedSeconds = attempt.elapsedSeconds
        self.bannerNoticeText = notice
        self.destination = .activeAttempt
        startAttemptTimer()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func resumeAttempt(_ attempt: ExamAttempt) {
        launchAttempt(attempt, notice: "Resumed saved exam progress.")
    }

    // MARK: - Active Attempt Interactions
    func chooseOption(_ option: String) {
        guard let attempt = activeAttempt,
              let q = currentPublicQuestion else { return }

        if let updated = ExamService.shared.selectAnswer(
            attemptId: attempt.id,
            questionId: q.id,
            choice: option
        ) {
            self.activeAttempt = updated
            ExamService.shared.updateProgressState(
                attemptId: updated.id,
                currentQuestionIndex: currentQuestionIndex,
                elapsedSeconds: elapsedSeconds
            )
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    func toggleCurrentQuestionFlag() {
        guard let attempt = activeAttempt,
              let q = currentPublicQuestion else { return }

        if let updated = ExamService.shared.toggleFlag(
            attemptId: attempt.id,
            questionId: q.id
        ) {
            self.activeAttempt = updated
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    func jumpToQuestion(at index: Int) {
        guard let attempt = activeAttempt,
              attempt.questions.indices.contains(index) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentQuestionIndex = index
        }
        ExamService.shared.updateProgressState(
            attemptId: attempt.id,
            currentQuestionIndex: index,
            elapsedSeconds: elapsedSeconds
        )
    }

    func nextQuestion() {
        guard let attempt = activeAttempt else { return }
        if currentQuestionIndex + 1 < attempt.questions.count {
            jumpToQuestion(at: currentQuestionIndex + 1)
        }
    }

    func previousQuestion() {
        if currentQuestionIndex > 0 {
            jumpToQuestion(at: currentQuestionIndex - 1)
        }
    }

    func playListeningAudio(for question: ExamPublicQuestion) {
        if let script = question.audioScript, !script.isEmpty {
            SpeechService.shared.speak(text: script)
        } else {
            SpeechService.shared.speak(text: question.prompt)
        }
    }

    // MARK: - Timer & Submission (Section 2 & 7)
    private func startAttemptTimer() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self,
                      let attempt = self.activeAttempt,
                      attempt.status == .inProgress else { return }

                self.elapsedSeconds += 1

                if self.elapsedSeconds % 5 == 0 {
                    ExamService.shared.updateProgressState(
                        attemptId: attempt.id,
                        currentQuestionIndex: self.currentQuestionIndex,
                        elapsedSeconds: self.elapsedSeconds
                    )
                }

                if attempt.isTimed,
                   let limit = attempt.durationLimitSeconds,
                   self.elapsedSeconds >= limit {
                    self.finalizeSubmission(didTimeout: true)
                }
            }
    }

    func stopAttemptTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func requestSubmitAttempt() {
        guard let attempt = activeAttempt else { return }
        let unanswered = attempt.questions.count - attempt.answeredCount
        if unanswered > 0 || !attempt.flaggedQuestionIds.isEmpty {
            showSubmitConfirmationAlert = true
        } else {
            finalizeSubmission(didTimeout: false)
        }
    }

    func finalizeSubmission(didTimeout: Bool) {
        stopAttemptTimer()
        SpeechService.shared.stop()
        guard let attempt = activeAttempt else { return }

        ExamService.shared.updateProgressState(
            attemptId: attempt.id,
            currentQuestionIndex: currentQuestionIndex,
            elapsedSeconds: elapsedSeconds
        )
        if let submitted = ExamService.shared.submitAttempt(
            attemptId: attempt.id,
            didTimeout: didTimeout
        ) {
            self.activeAttempt = submitted
            self.reviewFilter = .all
            self.destination = .results(submitted.id)
            refreshHistory()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    func saveAndExitAttempt() {
        stopAttemptTimer()
        SpeechService.shared.stop()
        if let attempt = activeAttempt {
            ExamService.shared.updateProgressState(
                attemptId: attempt.id,
                currentQuestionIndex: currentQuestionIndex,
                elapsedSeconds: elapsedSeconds
            )
        }
        refreshHistory()
        destination = .landing
    }

    // MARK: - Results & Retry Actions (Section 8)
    func attemptForResults(_ attemptId: String) -> ExamAttempt? {
        attemptsHistory.first { $0.id == attemptId }
    }

    func filteredReviewItems(for attempt: ExamAttempt) -> [ExamQuestionReviewItem] {
        switch reviewFilter {
        case .all:
            return attempt.reviewItems
        case .incorrect:
            return attempt.reviewItems.filter { !$0.isCorrect && !$0.isUnanswered }
        case .unanswered:
            return attempt.reviewItems.filter { $0.isUnanswered }
        case .flagged:
            return attempt.reviewItems.filter { $0.isFlagged }
        }
    }

    func retryIncorrect(from attemptId: String) {
        guard let retryAttempt = ExamService.shared.retryIncorrectQuestions(from: attemptId) else { return }
        launchAttempt(retryAttempt, notice: "Retrying missed questions in Practice Mode.")
    }

    func retakeFullAttempt(from attemptId: String) {
        guard let retake = ExamService.shared.retakeExam(from: attemptId) else { return }
        launchAttempt(retake, notice: nil)
    }

    static func formatSeconds(_ secs: Int) -> String {
        let m = secs / 60
        let s = secs % 60
        if m >= 60 {
            let h = m / 60
            let remM = m % 60
            return String(format: "%dh %02dm %02ds", h, remM, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}

