import SwiftUI
import Combine

final class GrammarViewModel: ObservableObject {
    @Published var grammarPoints: [GrammarPoint] = []
    @Published var currentPointIndex: Int = 0
    @Published var selectedVariantIndex: Int? = nil

    // Search & Filters
    @Published var searchQuery: String = "" {
        didSet { reloadGrammarPoints() }
    }
    @Published var selectedJLPTLevel: JLPTLevel? = nil {
        didSet { reloadGrammarPoints() }
    }
    @Published var selectedCategoryTag: String? = nil {
        didSet { reloadGrammarPoints() }
    }
    @Published var selectedChapterNumber: Int? = nil {
        didSet { reloadGrammarPoints() }
    }
    @Published var isBrowseMode: Bool = false
    @Published var isRecallQuizMode: Bool = false

    // Progress Summary
    @Published var totalPointCount: Int = 0
    @Published var completedPointCount: Int = 0
    @Published var displayPercentage: Int = 0

    // Session Timer
    @Published var sessionSeconds: Int = 0
    @Published var isTimerPaused: Bool = true

    // Card Flip & Confetti
    @Published var isFlipped: Bool = false
    @Published var confettiTrigger: Int = 0

    // Test Mode State
    @Published var isTestModeActive: Bool = false
    @Published var testScopeTitle: String = "All Grammar"
    @Published var testItems: [ResolvedLearningItem] = []
    @Published var testQuestions: [LearningPublicQuestion] = []
    @Published var activeTestSessionId: String? = nil
    @Published var currentTestIndex: Int = 0
    @Published var testTotalQuestions: Int = 0
    @Published var testCorrectCount: Int = 0
    @Published var testWrongCount: Int = 0
    @Published var showTestNextButton: Bool = false
    @Published var selectedOptionAnswer: String? = nil
    @Published var lastSubmittedRecord: LearningTestAnswerRecord? = nil

    private var hasRecordedRevealForCurrentCard: Bool = false
    private var itemStartTime: Date = Date()
    private var timerCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    init() {
        reloadGrammarPoints()
        startSessionTimer()

        NotificationCenter.default.publisher(for: .grammarDataUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshProgressCounts()
            }
            .store(in: &cancellables)
    }

    deinit {
        timerCancellable?.cancel()
    }

    // MARK: - Reload & Filter Grammar Points
    func reloadGrammarPoints() {
        let gService = GrammarDataService.shared
        let fetched = gService.searchGrammarPoints(
            query: searchQuery,
            jlptLevel: selectedJLPTLevel,
            chapterNumber: selectedChapterNumber,
            categoryTag: selectedCategoryTag
        )

        self.grammarPoints = fetched.sorted { a, b in
            let pA = gService.progress(pointId: a.id)
            let pB = gService.progress(pointId: b.id)
            if pA.difficulty != pB.difficulty {
                return pA.difficulty.numericValue > pB.difficulty.numericValue
            }
            return a.number < b.number
        }

        if grammarPoints.isEmpty {
            currentPointIndex = 0
            selectedVariantIndex = nil
        } else {
            currentPointIndex = max(0, min(currentPointIndex, grammarPoints.count - 1))
            selectedVariantIndex = nil
        }

        refreshProgressCounts()
        isFlipped = false
        itemStartTime = Date()
    }

    func refreshProgressCounts() {
        let gService = GrammarDataService.shared
        let total = grammarPoints.count
        let completed = grammarPoints.filter { gService.progress(pointId: $0.id).learningState != .unseen }.count
        self.totalPointCount = total
        self.completedPointCount = completed
        self.displayPercentage = total > 0 ? min(100, Int(round((Double(completed) / Double(total)) * 100.0))) : 0
    }

    // MARK: - Active Grammar Point & Variant Accessors
    var currentPoint: GrammarPoint {
        if isTestModeActive, testItems.indices.contains(currentTestIndex) {
            let gid = testItems[currentTestIndex].reference.contentId
            if let gp = GrammarDataService.shared.point(forId: gid) {
                return gp
            }
        }
        guard grammarPoints.indices.contains(currentPointIndex) else {
            return GrammarPoint(
                id: "empty",
                number: 0,
                title: "No Grammar Found",
                japanese: "文法なし",
                romaji: "Bunpou nashi",
                meaning: "No grammar points in current filter",
                explanation: "",
                pattern: ""
            )
        }
        return grammarPoints[currentPointIndex]
    }

    var currentVariant: GrammarVariant? {
        if isTestModeActive, testItems.indices.contains(currentTestIndex) {
            if let vid = testItems[currentTestIndex].reference.subContentId {
                return GrammarDataService.shared.variant(pointId: currentPoint.id, variantId: vid)
            }
            return nil
        }
        guard let vIdx = selectedVariantIndex,
              currentPoint.variants.indices.contains(vIdx) else {
            return nil
        }
        return currentPoint.variants[vIdx]
    }

    var currentReference: LearningItemReference {
        if isTestModeActive, testItems.indices.contains(currentTestIndex) {
            return testItems[currentTestIndex].reference
        }
        return LearningItemReference(
            domain: .grammar,
            contentId: currentPoint.id,
            subContentId: currentVariant?.id
        )
    }

    var currentProgress: LearningItemProgress {
        GrammarDataService.shared.progress(for: currentReference)
    }

    var currentTestQuestion: LearningPublicQuestion? {
        guard isTestModeActive, testQuestions.indices.contains(currentTestIndex) else { return nil }
        return testQuestions[currentTestIndex]
    }

    // MARK: - Navigation
    func selectPoint(at index: Int) {
        guard grammarPoints.indices.contains(index) else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            currentPointIndex = index
            selectedVariantIndex = nil
            isFlipped = false
            itemStartTime = Date()
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func selectPoint(byId id: String) {
        if searchQuery != "" || selectedCategoryTag != nil || selectedJLPTLevel != nil {
            searchQuery = ""
            selectedCategoryTag = nil
            selectedJLPTLevel = nil
        }
        if let idx = grammarPoints.firstIndex(where: { $0.id == id }) {
            selectPoint(at: idx)
        }
    }

    func selectVariant(at index: Int?) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            selectedVariantIndex = index
            isFlipped = false
            itemStartTime = Date()
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func navigateOneItem(direction: Int) {
        if isTestModeActive {
            let next = currentTestIndex + direction
            if testItems.indices.contains(next) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    currentTestIndex = next
                    isFlipped = false
                    showTestNextButton = false
                    selectedOptionAnswer = nil
                    lastSubmittedRecord = nil
                    hasRecordedRevealForCurrentCard = false
                    itemStartTime = Date()
                }
            }
            return
        }

        let next = currentPointIndex + direction
        if grammarPoints.indices.contains(next) {
            selectPoint(at: next)
        }
    }

    func resetToFirstCard() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            currentPointIndex = 0
            selectedVariantIndex = nil
            isFlipped = false
            itemStartTime = Date()
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func cycleActiveGrammarStatus() {
        GrammarDataService.shared.cycleDifficulty(for: currentReference)
        refreshProgressCounts()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func speakCurrentGrammar() {
        if let v = currentVariant, let ex = v.examples.first {
            SpeechService.shared.speak(text: ex.japanese, phoneticReading: ex.reading)
        } else if let ex = currentPoint.examples.first {
            SpeechService.shared.speak(text: ex.japanese, phoneticReading: ex.reading)
        } else {
            SpeechService.shared.speak(text: currentPoint.japanese)
        }
    }

    // MARK: - Timer
    func startSessionTimer() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, !self.isTimerPaused else { return }
                self.sessionSeconds += 1
            }
    }

    func toggleTimer() {
        isTimerPaused.toggle()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func resumeTimerIfNeeded() {
        if isTimerPaused {
            isTimerPaused = false
        }
    }

    var formattedSessionTime: String {
        let m = sessionSeconds / 60
        let s = sessionSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Test Mode
    func startTest(
        scopeTitle: String? = nil,
        grammarPointIds: [String] = [],
        mistakesOnly: Bool = false,
        preferredQuestionType: LearningQuestionType? = nil
    ) {
        let effectiveIds = grammarPointIds.isEmpty ? grammarPoints.map(\.id) : grammarPointIds
        let title = scopeTitle ?? (grammarPointIds.count == 1 ? currentPoint.japanese : (mistakesOnly ? "Trouble Grammar" : "All Grammar"))
        let jlptFilter: [JLPTLevel] = (selectedJLPTLevel != nil && selectedJLPTLevel != .all) ? [selectedJLPTLevel!] : []

        var scope = LearningTestScope(
            domains: [.grammar],
            jlptLevels: jlptFilter,
            chapterIds: [],
            particleIds: [],
            particleUsageIds: [],
            grammarPointIds: effectiveIds,
            questionCount: 0,
            mistakesOnly: mistakesOnly
        )

        var resolved = LearningItemResolver.resolveItems(for: scope)
        if resolved.isEmpty {
            scope.mistakesOnly = false
            scope.grammarPointIds = []
            resolved = LearningItemResolver.resolveItems(for: scope)
        }

        let (sessionId, questions) = LearningTestService.shared.startSession(
            scope: scope,
            preferredQuestionType: preferredQuestionType
        )

        self.activeTestSessionId = sessionId
        self.testItems = resolved
        self.testQuestions = questions
        self.testScopeTitle = title
        self.testTotalQuestions = questions.count
        self.testCorrectCount = 0
        self.testWrongCount = 0
        self.currentTestIndex = 0
        self.isTestModeActive = true
        self.isFlipped = false
        self.showTestNextButton = false
        self.selectedOptionAnswer = nil
        self.lastSubmittedRecord = nil
        self.hasRecordedRevealForCurrentCard = false
        self.itemStartTime = Date()
        self.resumeTimerIfNeeded()

        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func stopTest() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            self.isTestModeActive = false
            self.showTestNextButton = false
            self.selectedOptionAnswer = nil
            self.lastSubmittedRecord = nil
            self.hasRecordedRevealForCurrentCard = false
            self.isFlipped = false
        }
        reloadGrammarPoints()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Flip Card & Test Reveal
    func flipCard() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isFlipped.toggle()
        }

        if isTestModeActive && isFlipped && !hasRecordedRevealForCurrentCard {
            hasRecordedRevealForCurrentCard = true
            recordTestHardReveal()
            withAnimation(.easeInOut(duration: 0.22)) {
                showTestNextButton = true
            }
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func recordTestHardReveal() {
        guard isTestModeActive,
              let sessionId = activeTestSessionId,
              testQuestions.indices.contains(currentTestIndex) else { return }

        let elapsed = Date().timeIntervalSince(itemStartTime)
        let q = testQuestions[currentTestIndex]

        if let record = LearningTestService.shared.submitSelfRating(
            sessionId: sessionId,
            questionId: q.id,
            rating: .hard,
            wasRevealed: true,
            durationSeconds: elapsed
        ) {
            self.lastSubmittedRecord = record
            if let summary = LearningTestService.shared.getSessionResult(sessionId: sessionId) {
                self.testCorrectCount = summary.correctCount
                self.testWrongCount = summary.wrongCount
            }
        }
        refreshProgressCounts()
    }

    func submitMultipleChoiceOption(_ option: String) {
        guard isTestModeActive,
              let sessionId = activeTestSessionId,
              testQuestions.indices.contains(currentTestIndex) else { return }

        resumeTimerIfNeeded()
        selectedOptionAnswer = option
        let elapsed = Date().timeIntervalSince(itemStartTime)
        let q = testQuestions[currentTestIndex]

        if let record = LearningTestService.shared.submitAnswer(
            sessionId: sessionId,
            questionId: q.id,
            submittedAnswer: option,
            durationSeconds: elapsed
        ) {
            self.lastSubmittedRecord = record
            self.hasRecordedRevealForCurrentCard = true
            self.isFlipped = true
            self.showTestNextButton = true
            if let summary = LearningTestService.shared.getSessionResult(sessionId: sessionId) {
                self.testCorrectCount = summary.correctCount
                self.testWrongCount = summary.wrongCount
            }
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(record.isCorrect ? .success : .warning)
        }
        refreshProgressCounts()
    }

    func rateCurrentItem(_ rating: VocabViewModel.PracticeRating) {
        guard isTestModeActive,
              let sessionId = activeTestSessionId,
              testQuestions.indices.contains(currentTestIndex) else { return }

        if showTestNextButton && (rating == .good || rating == .easy) {
            return
        }
        resumeTimerIfNeeded()

        let alreadyRevealed = hasRecordedRevealForCurrentCard
        let elapsed = Date().timeIntervalSince(itemStartTime)
        let q = testQuestions[currentTestIndex]

        let srsRating: SRSRating
        switch rating {
        case .again: srsRating = .again
        case .hard: srsRating = .hard
        case .good: srsRating = .good
        case .easy: srsRating = .easy
        }

        if !alreadyRevealed {
            _ = LearningTestService.shared.submitSelfRating(
                sessionId: sessionId,
                questionId: q.id,
                rating: srsRating,
                wasRevealed: false,
                durationSeconds: elapsed
            )
            if let summary = LearningTestService.shared.getSessionResult(sessionId: sessionId) {
                self.testCorrectCount = summary.correctCount
                self.testWrongCount = summary.wrongCount
            }
        }

        refreshProgressCounts()
        advanceToNextTestQuestion()
    }

    func advanceToNextTestQuestion() {
        guard !testQuestions.isEmpty else { return }
        let nextIndex = currentTestIndex + 1
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            isFlipped = false
            showTestNextButton = false
            selectedOptionAnswer = nil
            lastSubmittedRecord = nil
            hasRecordedRevealForCurrentCard = false
            itemStartTime = Date()

            if nextIndex < testQuestions.count {
                currentTestIndex = nextIndex
            } else {
                if testWrongCount == 0 && testCorrectCount > 0 {
                    confettiTrigger += 1
                }
                currentTestIndex = 0
            }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
