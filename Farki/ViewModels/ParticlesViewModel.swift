import SwiftUI
import Combine

final class ParticlesViewModel: ObservableObject {
    // Filtered unique particles (1 entry per unique particle form)
    @Published var particles: [Particle] = []
    @Published var currentParticleIndex: Int = 0
    @Published var currentUsageIndex: Int = 0

    // Search & Filters (Section 7 Requirements)
    @Published var searchQuery: String = "" {
        didSet { reloadParticles() }
    }
    @Published var selectedCategory: ParticleCategory? = nil {
        didSet { reloadParticles() }
    }
    @Published var selectedJLPTLevel: JLPTLevel? = nil {
        didSet { reloadParticles() }
    }

    // Group usage selection for targeted testing/review (Section 7 Requirement)
    @Published var selectedUsageIds: Set<String> = []
    @Published var isBrowseMode: Bool = false
    @Published var isRecallQuizMode: Bool = false
    @Published var showAllUsagesDrawer: Bool = false

    // Progress Summary (Across all 188 usages or active filter)
    @Published var totalUsageCount: Int = 0
    @Published var completedUsageCount: Int = 0
    @Published var displayPercentage: Int = 0

    // Session Timer (Same behavior as VocabViewModel)
    @Published var sessionSeconds: Int = 0
    @Published var isTimerPaused: Bool = true

    // Card Flip & Confetti
    @Published var isFlipped: Bool = false
    @Published var confettiTrigger: Int = 0

    // Test Mode State (Reusing Vocabulary Test Flow & LearningTestService)
    @Published var isTestModeActive: Bool = false
    @Published var testScopeTitle: String = "All Particles"
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
        reloadParticles()
        startSessionTimer()

        NotificationCenter.default.publisher(for: .particleDataUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshProgressCounts()
            }
            .store(in: &cancellables)
    }

    deinit {
        timerCancellable?.cancel()
    }

    // MARK: - Reload & Filter Unique Particles
    func reloadParticles() {
        let fetched = ParticleDataService.shared.searchParticles(
            query: searchQuery,
            category: selectedCategory,
            jlptLevel: selectedJLPTLevel
        )
        // Prioritize particles with Hard usages first, proficient last
        self.particles = fetched.sorted { a, b in
            let diffA = ParticleDataService.shared.aggregateDifficulty(for: a)
            let diffB = ParticleDataService.shared.aggregateDifficulty(for: b)
            if diffA != diffB {
                return diffA.numericValue > diffB.numericValue
            }
            let numA = ParticleDataService.shared.sourceEntry(forUsageId: a.usageIds.first ?? "")?.sourceNumber ?? 999
            let numB = ParticleDataService.shared.sourceEntry(forUsageId: b.usageIds.first ?? "")?.sourceNumber ?? 999
            return numA < numB
        }

        if particles.isEmpty {
            currentParticleIndex = 0
            currentUsageIndex = 0
        } else {
            currentParticleIndex = max(0, min(currentParticleIndex, particles.count - 1))
            let usageCount = particles[currentParticleIndex].usageIds.count
            currentUsageIndex = max(0, min(currentUsageIndex, max(0, usageCount - 1)))
        }

        refreshProgressCounts()
        isFlipped = false
        itemStartTime = Date()
    }

    func refreshProgressCounts() {
        let pService = ParticleDataService.shared
        let visibleUsageIds = Set(particles.flatMap(\.usageIds))
        let total = visibleUsageIds.count
        var completed = 0
        for p in particles {
            for uid in p.usageIds {
                if pService.progress(particleId: p.id, usageId: uid).learningState != .unseen {
                    completed += 1
                }
            }
        }
        self.totalUsageCount = total
        self.completedUsageCount = completed
        self.displayPercentage = total > 0 ? min(100, Int(round((Double(completed) / Double(total)) * 100.0))) : 0
    }

    // MARK: - Active Particle & Usage Accessors
    var currentParticle: Particle {
        if isTestModeActive, testItems.indices.contains(currentTestIndex) {
            let pid = testItems[currentTestIndex].reference.contentId
            if let p = ParticleDataService.shared.particle(forId: pid) {
                return p
            }
        }
        guard particles.indices.contains(currentParticleIndex) else {
            return Particle(
                id: "empty",
                japanese: "助詞なし",
                romaji: "Joshi nashi",
                categories: [.other],
                usageIds: [],
                tags: []
            )
        }
        return particles[currentParticleIndex]
    }

    var currentParticleUsages: [ParticleUsage] {
        ParticleDataService.shared.usages(forParticleId: currentParticle.id)
    }

    var currentUsage: ParticleUsage? {
        if isTestModeActive, testItems.indices.contains(currentTestIndex) {
            if let uid = testItems[currentTestIndex].reference.subContentId {
                return ParticleDataService.shared.usage(forId: uid)
            }
        }
        let list = currentParticleUsages
        guard list.indices.contains(currentUsageIndex) else { return list.first }
        return list[currentUsageIndex]
    }

    var currentSourceEntry: ParticleSourceEntry? {
        guard let usage = currentUsage else { return nil }
        return ParticleDataService.shared.sourceEntry(forUsageId: usage.id)
    }

    var currentReference: LearningItemReference {
        if isTestModeActive, testItems.indices.contains(currentTestIndex) {
            return testItems[currentTestIndex].reference
        }
        let pid = currentParticle.id
        let uid = currentUsage?.id
        return LearningItemReference(domain: .particles, contentId: pid, subContentId: uid)
    }

    var currentProgress: LearningItemProgress {
        ParticleDataService.shared.progress(for: currentReference)
    }

    var currentTestQuestion: LearningPublicQuestion? {
        guard isTestModeActive, testQuestions.indices.contains(currentTestIndex) else { return nil }
        return testQuestions[currentTestIndex]
    }

    // MARK: - Selection & Navigation
    func selectParticle(at index: Int) {
        guard particles.indices.contains(index) else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            currentParticleIndex = index
            currentUsageIndex = 0
            isFlipped = false
            itemStartTime = Date()
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func selectUsage(at index: Int) {
        let usages = currentParticleUsages
        guard usages.indices.contains(index) else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            currentUsageIndex = index
            isFlipped = false
            itemStartTime = Date()
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func toggleUsageSelection(_ usageId: String) {
        if selectedUsageIds.contains(usageId) {
            selectedUsageIds.remove(usageId)
        } else {
            selectedUsageIds.insert(usageId)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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

        let usages = currentParticleUsages
        let nextUsage = currentUsageIndex + direction
        if usages.indices.contains(nextUsage) {
            selectUsage(at: nextUsage)
        } else {
            let nextParticle = currentParticleIndex + direction
            if particles.indices.contains(nextParticle) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    currentParticleIndex = nextParticle
                    let newUsages = ParticleDataService.shared.usages(forParticleId: particles[nextParticle].id)
                    currentUsageIndex = direction < 0 ? max(0, newUsages.count - 1) : 0
                    isFlipped = false
                    itemStartTime = Date()
                }
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
    }

    func resetToFirstCard() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            currentParticleIndex = 0
            currentUsageIndex = 0
            isFlipped = false
            itemStartTime = Date()
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func cycleActiveUsageStatus() {
        ParticleDataService.shared.cycleDifficulty(for: currentReference)
        refreshProgressCounts()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func speakCurrentParticle() {
        if let ex = currentUsage?.examples.first {
            SpeechService.shared.speak(text: ex.japanese, phoneticReading: ex.reading)
        } else {
            SpeechService.shared.speak(text: currentParticle.japanese)
        }
    }

    // MARK: - Timer Handling
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

    // MARK: - Test Mode (Reuses Vocabulary Test Flow & LearningTestService)
    func startTest(
        scopeTitle: String? = nil,
        particleIds: [String] = [],
        usageIds: [String] = [],
        mistakesOnly: Bool = false,
        preferredQuestionType: LearningQuestionType? = nil
    ) {
        let effectiveUsageIds: [String]
        let effectiveParticleIds: [String]
        let title: String

        if !usageIds.isEmpty {
            effectiveUsageIds = usageIds
            effectiveParticleIds = particleIds
            title = scopeTitle ?? (usageIds.count == 1 ? "1 Usage" : "\(usageIds.count) Usages")
        } else if !selectedUsageIds.isEmpty {
            effectiveUsageIds = Array(selectedUsageIds)
            effectiveParticleIds = particleIds
            title = scopeTitle ?? "\(selectedUsageIds.count) Selected Usages"
        } else if !particleIds.isEmpty {
            effectiveParticleIds = particleIds
            effectiveUsageIds = []
            title = scopeTitle ?? (particleIds.count == 1 ? currentParticle.japanese : "\(particleIds.count) Particles")
        } else {
            effectiveParticleIds = particles.map(\.id)
            effectiveUsageIds = []
            title = scopeTitle ?? (mistakesOnly ? "Trouble Particles" : "All Particles")
        }

        let jlptFilter: [JLPTLevel] = (selectedJLPTLevel != nil && selectedJLPTLevel != .all) ? [selectedJLPTLevel!] : []
        var scope = LearningTestScope(
            domains: [.particles],
            jlptLevels: jlptFilter,
            chapterIds: [],
            particleIds: effectiveParticleIds,
            particleUsageIds: effectiveUsageIds,
            questionCount: 0,
            mistakesOnly: mistakesOnly
        )

        var resolved = LearningItemResolver.resolveItems(for: scope)
        if resolved.isEmpty {
            scope.mistakesOnly = false
            scope.particleIds = []
            scope.particleUsageIds = []
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
        reloadParticles()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Flip Card & Test Reveal (Same Policy as Vocabulary)
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
