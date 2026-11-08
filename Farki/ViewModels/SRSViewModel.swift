import SwiftUI
import Combine

final class SRSViewModel: ObservableObject {
    private let storage: SRSStorageService
    private let vocabService: VocabDataService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published State
    @Published var activeDomain: LearningDomain = .vocabulary {
        didSet {
            loadQueue()
            updateStats()
        }
    }

    @Published var customDomainReferences: [LearningReviewReference]? = nil

    @Published var activeScope: SRSScope = .all {
        didSet {
            loadQueue()
            updateStats()
        }
    }

    @Published var currentQueue: [SRSQueueItem] = []
    @Published var currentIndex: Int = 0
    @Published var isAnswerRevealed: Bool = false
    @Published var wasCheckedMeaning: Bool = false
    @Published var cardStartTime: Date = Date()

    @Published var queueCounts: SRSQueueCounts = SRSQueueCounts(newCount: 0, learningCount: 0, reviewCount: 0)
    @Published var scopeStats: SRSScopeStats? = nil

    // Sheets / Modals
    @Published var isScopePickerPresented: Bool = false
    @Published var isStatsPresented: Bool = false
    @Published var isSettingsPresented: Bool = false
    @Published var isPresetSavePresented: Bool = false
    @Published var newPresetName: String = ""

    // Multi-select state inside Scope Picker
    @Published var selectedMultiChapters: Set<Int> = [1]

    // Toast / Feedback
    @Published var toastMessage: String? = nil

    // Session Timer
    @Published var sessionSeconds: Int = 0
    @Published var isTimerPaused: Bool = true
    private var timerCancellable: AnyCancellable?

    init(storage: SRSStorageService = .shared, vocabService: VocabDataService = .shared) {
        self.storage = storage
        self.vocabService = vocabService

        startSessionTimer()

        // Subscribe to database updates
        NotificationCenter.default.publisher(for: .srsDataUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshCurrentScopeCounts()
                self?.updateStats()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .vocabDataUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadQueue()
                self?.updateStats()
            }
            .store(in: &cancellables)

        loadQueue()
        updateStats()
    }

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
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    func ensureTimerRunning() {
        if isTimerPaused {
            isTimerPaused = false
        }
    }

    var formattedSessionTime: String {
        let m = sessionSeconds / 60
        let s = sessionSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Current Card Item
    var currentItem: SRSQueueItem? {
        guard !currentQueue.isEmpty && currentIndex < currentQueue.count else { return nil }
        return currentQueue[currentIndex]
    }

    var config: SRSConfig {
        storage.config
    }

    var presets: [ScopePreset] {
        storage.presets
    }

    var availableChapters: [Int] {
        vocabService.availableChapters
    }

    // MARK: - Load / Refresh Queue
    func startDomainReview(domain: LearningDomain, references: [LearningReviewReference]? = nil) {
        self.customDomainReferences = references
        self.activeDomain = domain
        loadQueue()
    }

    private func resolvedDomainReferences(for domain: LearningDomain) -> [LearningReviewReference] {
        if let custom = customDomainReferences, !custom.isEmpty {
            return custom
        }
        switch domain {
        case .vocabulary:
            return vocabService.items
                .filter { activeScope.matches(chapter: $0.chapterNumber) }
                .map { LearningReviewReference(domain: .vocabulary, contentId: $0.id) }
        case .grammar:
            return GrammarDataService.shared.grammarPoints.map {
                LearningReviewReference(domain: .grammar, contentId: $0.id)
            }
        case .particles:
            return ParticleDataService.shared.sourceEntries.map {
                LearningReviewReference(domain: .particles, contentId: $0.particleId, subContentId: $0.usageId)
            }
        }
    }

    func loadQueue() {
        let states = storage.cardStates
        let logs = storage.reviewLogs
        let cfg = storage.config

        let queue: [SRSQueueItem]
        if activeDomain == .vocabulary && customDomainReferences == nil {
            queue = SRSQueueBuilder.buildQueue(
                scope: activeScope,
                vocabItems: vocabService.items,
                cardStates: states,
                reviewLogs: logs,
                now: Date(),
                config: cfg
            )
        } else {
            let refs = resolvedDomainReferences(for: activeDomain)
            queue = SRSQueueBuilder.buildDomainQueue(
                references: refs,
                cardStates: states,
                reviewLogs: logs,
                now: Date(),
                config: cfg
            )
        }

        self.currentQueue = queue
        self.currentIndex = 0
        self.isAnswerRevealed = false
        self.wasCheckedMeaning = false
        self.cardStartTime = Date()

        refreshCurrentScopeCounts()
    }

    func refreshCurrentScopeCounts() {
        if activeDomain == .vocabulary && customDomainReferences == nil {
            self.queueCounts = SRSQueueBuilder.computeCounts(
                scope: activeScope,
                vocabItems: vocabService.items,
                cardStates: storage.cardStates,
                reviewLogs: storage.reviewLogs,
                now: Date(),
                config: storage.config
            )
        } else {
            let refs = resolvedDomainReferences(for: activeDomain)
            self.queueCounts = SRSQueueBuilder.computeDomainCounts(
                references: refs,
                cardStates: storage.cardStates,
                reviewLogs: storage.reviewLogs,
                now: Date(),
                config: storage.config
            )
        }
    }

    func countsForScope(_ scope: SRSScope) -> SRSQueueCounts {
        return SRSQueueBuilder.computeCounts(
            scope: scope,
            vocabItems: vocabService.items,
            cardStates: storage.cardStates,
            reviewLogs: storage.reviewLogs,
            now: Date(),
            config: storage.config
        )
    }

    func updateStats() {
        self.scopeStats = SRSStatsService.computeStats(
            scope: activeScope,
            vocabItems: vocabService.items,
            cardStates: storage.cardStates,
            reviewLogs: storage.reviewLogs,
            now: Date(),
            config: storage.config
        )
    }

    // MARK: - Card Actions
    func revealAnswer() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isAnswerRevealed = true
        }
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }

    /// Check Meaning interaction: reveals English meaning and automatically classifies review as Hard
    func checkMeaning() {
        ensureTimerRunning()
        wasCheckedMeaning = true
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isAnswerRevealed = true
        }
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
    }

    func answerCurrentCard(rating: SRSRating) {
        guard let item = currentItem else { return }

        let durationMs = Int(Date().timeIntervalSince(cardStartTime) * 1000.0)

        // Record review into single source of truth
        let updatedCard = storage.recordReview(
            cardId: item.cardState.cardId,
            rating: rating,
            durationMs: durationMs,
            scope: activeScope.identifier,
            now: Date()
        )

        let feedback = UINotificationFeedbackGenerator()
        if rating == .again {
            feedback.notificationOccurred(.warning)
        } else {
            feedback.notificationOccurred(.success)
        }

        // Sync difficulty (Red/Yellow/Green) and streak back to VocabItem
        let reviewDifficulty: VocabDifficulty
        let isCorrect: Bool
        switch rating {
        case .again:
            reviewDifficulty = .hard    // Red: words I got wrong
            isCorrect = false
        case .hard:
            reviewDifficulty = .medium  // Yellow: sometimes I miss
            isCorrect = true
        case .good, .easy:
            reviewDifficulty = .easy    // Green: the ones I know
            isCorrect = true
        }

        let elapsed = Date().timeIntervalSince(cardStartTime)
        let newState: VocabLearningState = (rating == .again) ? .unseen : .knownDirectly

        switch item.reference.domain {
        case .vocabulary:
            vocabService.updateWordProgress(
                id: item.vocabItem.id,
                learningState: newState,
                difficulty: reviewDifficulty,
                responseTime: elapsed,
                isCorrect: isCorrect
            )
        case .grammar:
            GrammarDataService.shared.updateProgress(
                for: item.reference,
                learningState: newState,
                difficulty: reviewDifficulty,
                responseTime: elapsed,
                isCorrect: isCorrect
            )
        case .particles:
            ParticleDataService.shared.updateProgress(
                for: item.reference,
                learningState: newState,
                difficulty: reviewDifficulty,
                responseTime: elapsed,
                isCorrect: isCorrect
            )
        }

        // If card was rated Again or Hard in learning, it may re-appear later in session if needed
        // For current session progression:
        withAnimation(.easeInOut(duration: 0.25)) {
            isAnswerRevealed = false
            wasCheckedMeaning = false
            currentIndex += 1
            cardStartTime = Date()
        }

        // If learning card was failed, re-queue at end of current session
        if updatedCard.state == .learning || updatedCard.state == .relearning {
            currentQueue.append(SRSQueueItem(
                cardState: updatedCard,
                vocabItem: item.vocabItem,
                direction: item.direction,
                reference: item.reference,
                resolvedItem: item.resolvedItem
            ))
        }

        refreshCurrentScopeCounts()
        updateStats()
    }

    // MARK: - Undo
    func undoLastReview() {
        guard let result = storage.undoLastReview() else {
            showToast("No reviews to undo")
            return
        }

        // If index > 0, move back
        if currentIndex > 0 {
            currentIndex -= 1
        }

        // Refresh card in current queue
        if let idx = currentQueue.firstIndex(where: { $0.cardState.cardId == result.restoredCard.cardId }) {
            currentQueue[idx] = SRSQueueItem(
                cardState: result.restoredCard,
                vocabItem: currentQueue[idx].vocabItem,
                direction: currentQueue[idx].direction
            )
        }

        isAnswerRevealed = false
        cardStartTime = Date()

        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()

        showToast("Undid last review")
        refreshCurrentScopeCounts()
        updateStats()
    }

    // MARK: - Projected Intervals for Current Card
    var currentProjections: [SRSRating: SRSProjection] {
        guard let item = currentItem else { return [:] }
        return SRSEngine.projectedIntervals(
            card: item.cardState,
            now: Date(),
            config: storage.config
        )
    }

    // MARK: - Scope Preset Management
    func saveCurrentScopeAsPreset() {
        let trimmed = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let chaptersToSave: [Int]
        switch activeScope {
        case .all:
            chaptersToSave = vocabService.availableChapters
        case .chapter(let ch):
            chaptersToSave = [ch]
        case .selected(let chs), .preset(_, _, let chs):
            chaptersToSave = chs
        }

        let preset = storage.savePreset(name: trimmed, chapters: chaptersToSave)
        activeScope = .preset(id: preset.id, name: preset.name, chapters: preset.chapters)
        newPresetName = ""
        isPresetSavePresented = false
        showToast("Saved preset: \(preset.name)")
    }

    func deletePreset(id: String) {
        storage.deletePreset(id: id)
        if case .preset(let activeId, _, _) = activeScope, activeId == id {
            activeScope = .all
        }
        showToast("Preset deleted")
    }

    // MARK: - Config Update
    func updateConfig(_ newConfig: SRSConfig) {
        storage.updateConfig(newConfig)
        loadQueue()
        showToast("Settings saved")
    }

    // MARK: - Backup & Restore
    func exportBackup() -> URL? {
        let result = storage.exportBackupData()
        switch result {
        case .success(let data):
            let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("farki_srs_backup_\(Int(Date().timeIntervalSince1970)).json")
            try? data.write(to: tempUrl)
            return tempUrl
        case .failure(let error):
            showToast("Export failed: \(error.localizedDescription)")
            return nil
        }
    }

    func importBackup(from url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            showToast("Failed to read backup file")
            return
        }

        let result = storage.importBackupData(data: data)
        switch result {
        case .success(let count):
            loadQueue()
            showToast("Restored \(count) cards successfully!")
        case .failure(let error):
            showToast("Import failed: \(error.localizedDescription)")
        }
    }

    private func showToast(_ msg: String) {
        self.toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.toastMessage == msg {
                self?.toastMessage = nil
            }
        }
    }
}
