import SwiftUI
import Combine

public enum VocabTabMode: String, CaseIterable, Identifiable {
    case study = "Study Cards"
    case chapters = "Chapters & Sections"
    case revision = "Revision"

    public var id: String { rawValue }
}

final class VocabViewModel: ObservableObject {
    @Published var items: [VocabItem] = []
    @Published var currentIndex: Int = 0
    @Published var totalWordCount: Int = 0
    @Published var completedWordCount: Int = 0
    @Published var displayPercentage: Int = 0

    // Mode Switcher (Study Cards, Chapters & Sections, Revision)
    @Published var selectedTabMode: VocabTabMode = .study
    @Published var isChapterSelectorExpanded: Bool = false

    // Chapter & Section Filter (Requirement 12)
    @Published var filter = VocabFilter()
    @Published var isShowingChapterSectionScreen: Bool = false
    @Published var rangeStartChapter: Int = 1
    @Published var rangeEndChapter: Int = 25
    @Published var isFilterSheetPresented: Bool = false
    @Published var isImportSheetPresented: Bool = false

    // Revision Session State (Requirement 2)
    @Published var revisionSelectedChapter: Int = 1
    @Published var revisionDirection: VocabRevisionDirection = .japaneseToEnglish
    @Published var isRevisionSessionActive: Bool = false
    @Published var revisionSessionWords: [VocabItem] = []
    @Published var revisionCurrentIndex: Int = 0
    @Published var isRevisionAnswerRevealed: Bool = false
    @Published var revisionSessionCorrectCount: Int = 0
    @Published var revisionSessionIncorrectCount: Int = 0
    @Published var isRevisionSessionFinished: Bool = false

    // Chapter Strip Scrolling & Dragging State (for VocabChapterStripView)
    @Published var chapterStripCenteredIndex: Int = 0
    @Published var chapterStripDragOffset: CGFloat = 0

    // Session Timer: Starts from zero and starts paused (clicking it starts / pauses it)
    @Published var sessionSeconds: Int = 0
    @Published var isTimerPaused: Bool = true

    // Card Flip (Requirement 5)
    @Published var isFlipped: Bool = false
    @Published var confettiTrigger: Int = 0

    // Custom Practice & Test Mode (Requirement 1 & 2)
    @Published var isCustomPracticeMenuPresented: Bool = false
    @Published var isTestModeActive: Bool = false
    @Published var isTestPaused: Bool = false
    @Published var testScopeTitle: String = "All Chapters"
    @Published var testTotalQuestions: Int = 0
    @Published var testCorrectCount: Int = 0
    @Published var testWrongCount: Int = 0
    @Published var testItems: [VocabItem] = []
    @Published var hasSavedPausedTest: Bool = false
    @Published var savedPausedSession: VocabTestSession? = nil
    var currentTestSession: VocabTestSession? = nil
    private let pausedTestSessionKey = "farki_vocab_test_paused_session_v1"

    // Import status & feedback
    @Published var lastImportResult: VocabImportValidationResult?
    @Published var lastImportError: String?

    // Tracking active word response time for Best Time (Requirement 4)
    private var wordStartTime: Date = Date()
    private var timerCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    init() {
        reloadItems()
        startSessionTimer()
        checkSavedPausedTestSession()

        // Auto reload when bundled or imported vocabulary changes
        NotificationCenter.default.publisher(for: .vocabDataUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadItems()
            }
            .store(in: &cancellables)
    }

    deinit {
        timerCancellable?.cancel()
    }

    // MARK: - Prioritized Sorting (Trouble Cards FIRST, Proficient Cards LAST)

    /// Sorts vocabulary items such that words the user faces problems with are at the FRONT,
    /// and words the user is proficient in are moved to the LAST of the list.
    func prioritizedVocabSort(_ list: [VocabItem]) -> [VocabItem] {
        return list.sorted { a, b in
            let prioA = priorityScore(for: a)
            let prioB = priorityScore(for: b)
            if prioA != prioB {
                return prioA < prioB // Lower score comes FIRST (0 = Hard/Trouble words)
            }
            // Tie-breaking within Hard/Trouble words: lowest streak / lowest accuracy first
            if a.difficulty == .hard {
                if a.currentStreak != b.currentStreak {
                    return a.currentStreak < b.currentStreak
                }
            } else if a.difficulty == .easy {
                // For proficient words: higher best streak goes further to the back
                if a.bestStreak != b.bestStreak {
                    return a.bestStreak < b.bestStreak
                }
            }
            // Stable natural chapter and sequence ordering
            if a.chapterNumber != b.chapterNumber {
                return a.chapterNumber < b.chapterNumber
            }
            return a.number < b.number
        }
    }

    private func priorityScore(for item: VocabItem) -> Int {
        switch item.difficulty {
        case .hard:
            // Priority 0: Words facing problem (got wrong / missed) -> FIRST!
            return 0
        case .medium:
            // Priority 1: Sometimes miss / reviewing -> Middle
            return 1
        case .easy:
            if item.learningState == .unseen {
                // Priority 2: Unseen / unstudied words -> Middle
                return 2
            } else {
                // Priority 3: Proficient / mastered words -> LAST of the list!
                return 3
            }
        }
    }

    // MARK: - Multi-Chapter & Section Selection Helpers (Requirement 2.5)
    var availableChapters: [Int] {
        let allItems = VocabDataService.shared.items
        let chapters = Set(allItems.map { $0.chapterNumber })
        return chapters.sorted()
    }

    func wordCount(forChapter chapter: Int) -> Int {
        VocabDataService.shared.items.filter { $0.chapterNumber == chapter }.count
    }

    func wordCount(forSection section: VocabSectionCategory) -> Int {
        var chapterScoped = VocabDataService.shared.items
        if !filter.selectedChapters.isEmpty {
            chapterScoped = chapterScoped.filter { filter.selectedChapters.contains($0.chapterNumber) }
        } else if let ch = filter.selectedChapter {
            chapterScoped = chapterScoped.filter { $0.chapterNumber == ch }
        } else if let book = filter.selectedBook {
            chapterScoped = chapterScoped.filter { book.chapterRange.contains($0.chapterNumber) }
        }
        return chapterScoped.filter { section.matches($0.wordType) }.count
    }

    var troubleWordCountInSelectedChapters: Int {
        var chapterScoped = VocabDataService.shared.items
        if !filter.selectedChapters.isEmpty {
            chapterScoped = chapterScoped.filter { filter.selectedChapters.contains($0.chapterNumber) }
        } else if let ch = filter.selectedChapter {
            chapterScoped = chapterScoped.filter { $0.chapterNumber == ch }
        } else if let book = filter.selectedBook {
            chapterScoped = chapterScoped.filter { book.chapterRange.contains($0.chapterNumber) }
        }
        return chapterScoped.filter { $0.difficulty == .hard || $0.difficulty == .medium }.count
    }

    var isAllChaptersSelected: Bool {
        filter.selectedChapters.isEmpty && filter.selectedChapter == nil && filter.selectedBook == nil
    }

    func isChapterSelected(_ chapter: Int) -> Bool {
        filter.selectedChapters.contains(chapter) || filter.selectedChapter == chapter
    }

    func toggleChapterSelection(_ chapter: Int) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if let single = filter.selectedChapter {
            filter.selectedChapters.insert(single)
            filter.selectedChapter = nil
        }

        if filter.selectedChapters.contains(chapter) {
            filter.selectedChapters.remove(chapter)
        } else {
            filter.selectedChapters.insert(chapter)
        }
        filter.selectedBook = nil
        reloadItems()
    }

    var currentSelectedChapter: Int {
        if let ch = filter.selectedChapter { return ch }
        if let first = filter.selectedChapters.sorted().first { return first }
        if !items.isEmpty { return items[currentIndex].chapterNumber }
        return 1
    }

    func selectSingleChapter(_ chapter: Int) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        filter.selectedChapters.removeAll()
        filter.selectedChapter = chapter
        filter.selectedBook = TextbookBook.book(forChapter: chapter)
        reloadItems()
    }

    func selectNextChapter() {
        let current = currentSelectedChapter
        let next = min(50, current + 1)
        selectSingleChapter(next)
    }

    func selectPreviousChapter() {
        let current = currentSelectedChapter
        let prev = max(1, current - 1)
        selectSingleChapter(prev)
    }

    func selectAllChapters() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        filter.selectedChapters.removeAll()
        filter.selectedChapter = nil
        filter.selectedBook = nil
        reloadItems()
    }

    func selectChapterRange(_ range: ClosedRange<Int>) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        filter.selectedChapters = Set(range)
        filter.selectedChapter = nil
        filter.selectedBook = nil
        rangeStartChapter = range.lowerBound
        rangeEndChapter = range.upperBound
        reloadItems()
    }

    func applyCustomChapterRange() {
        let start = min(rangeStartChapter, rangeEndChapter)
        let end = max(rangeStartChapter, rangeEndChapter)
        selectChapterRange(start...end)
    }

    func toggleSectionCategory(_ section: VocabSectionCategory) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if filter.selectedSectionCategories.contains(section) {
            filter.selectedSectionCategories.remove(section)
        } else {
            filter.selectedSectionCategories.insert(section)
        }
        reloadItems()
    }

    func clearSectionCategories() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        filter.selectedSectionCategories.removeAll()
        reloadItems()
    }

    func toggleTroubleWordsOnly() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        filter.troubleWordsOnly.toggle()
        reloadItems()
    }

    func startTestFromCurrentFilter() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            isShowingChapterSectionScreen = false
        }
        startTest(scopeTitle: filter.summaryText)
    }

    // MARK: - Revision Workflow Methods (Requirement 2)
    func startRevision(chapter: Int, direction: VocabRevisionDirection) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        self.revisionSelectedChapter = chapter
        self.revisionDirection = direction

        // Retrieve vocabulary belonging to that chapter
        let chapterItems = VocabDataService.shared.items.filter { $0.chapterNumber == chapter }
        // Use the vocabulary already studied or gone through as the basis for revision
        let studiedItems = chapterItems.filter { $0.learningState != .unseen }

        if !studiedItems.isEmpty {
            self.revisionSessionWords = studiedItems
        } else {
            // Graceful fallback: if none studied yet, present all chapter words
            self.revisionSessionWords = chapterItems
        }

        self.revisionCurrentIndex = 0
        self.isRevisionAnswerRevealed = false
        self.revisionSessionCorrectCount = 0
        self.revisionSessionIncorrectCount = 0
        self.isRevisionSessionFinished = false
        self.isRevisionSessionActive = true
    }

    var currentRevisionWord: VocabItem? {
        guard !revisionSessionWords.isEmpty,
              revisionCurrentIndex >= 0,
              revisionCurrentIndex < revisionSessionWords.count else {
            return nil
        }
        return revisionSessionWords[revisionCurrentIndex]
    }

    func revealRevisionAnswer() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation(.easeInOut(duration: 0.2)) {
            isRevisionAnswerRevealed = true
        }
    }

    func recordRevisionAnswer(isCorrect: Bool) {
        guard let word = currentRevisionWord else { return }

        let generator = UIImpactFeedbackGenerator(style: isCorrect ? .light : .heavy)
        generator.impactOccurred()

        // Explicit verification saved into VocabRevisionService
        VocabRevisionService.shared.recordAnswer(
            word: word,
            isCorrect: isCorrect,
            direction: revisionDirection
        )

        if isCorrect {
            revisionSessionCorrectCount += 1
        } else {
            revisionSessionIncorrectCount += 1
        }

        if revisionCurrentIndex + 1 < revisionSessionWords.count {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                revisionCurrentIndex += 1
                isRevisionAnswerRevealed = false
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isRevisionSessionFinished = true
                if revisionSessionIncorrectCount == 0 {
                    confettiTrigger += 1
                }
            }
        }
    }

    func restartRevisionSession() {
        startRevision(chapter: revisionSelectedChapter, direction: revisionDirection)
    }

    func exitRevisionSession() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            isRevisionSessionActive = false
            isRevisionSessionFinished = false
            isRevisionAnswerRevealed = false
            revisionSessionWords = []
        }
    }

    // MARK: - Chapter Strip Scrolling & Slide Helpers (for VocabChapterStripView)
    var chapterList: [Int] {
        let maxCh = availableChapters.max() ?? 25
        let limit = max(25, maxCh)
        return Array(1...limit)
    }

    func syncChapterStripIndex() {
        let ch = currentWord.chapterNumber
        if let idx = chapterList.firstIndex(of: ch) {
            chapterStripCenteredIndex = idx
        } else if let firstSelected = filter.selectedChapters.sorted().first,
                  let idx = chapterList.firstIndex(of: firstSelected) {
            chapterStripCenteredIndex = idx
        }
    }

    func updateChapterStripDrag(offset: CGFloat) {
        chapterStripDragOffset = offset
    }

    func endChapterStripDrag(translation: CGFloat, velocity: CGFloat) {
        let count = chapterList.count
        guard count > 0 else { return }
        let step = (abs(velocity) > 600 || abs(translation) > 90) ? 3 : 1

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            chapterStripDragOffset = 0
            if translation > 30 || velocity > 200 {
                chapterStripCenteredIndex = max(0, chapterStripCenteredIndex - step)
            } else if translation < -30 || velocity < -200 {
                chapterStripCenteredIndex = min(count - 1, chapterStripCenteredIndex + step)
            }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Reload Items According to Filter
    func reloadItems() {
        guard !isTestModeActive else { return }
        let fetched = VocabDataService.shared.fetchVocabItems(filter: filter)
        // Apply prioritized sort: problem words first, proficient words last
        self.items = prioritizedVocabSort(fetched)

        let completed = fetched.filter { $0.learningState != .unseen }.count
        self.totalWordCount = fetched.count
        self.completedWordCount = completed
        self.displayPercentage = totalWordCount > 0 ? min(100, Int(round((Double(self.completedWordCount) / Double(self.totalWordCount)) * 100))) : 0

        self.currentIndex = fetched.isEmpty ? 0 : max(0, min(currentIndex, fetched.count - 1))

        self.wordStartTime = Date()
        self.isFlipped = false
    }

    // MARK: - Filter Modification (Requirement 12)
    func selectBook(_ book: TextbookBook?) {
        filter.selectedBook = book
        if let b = book, let ch = filter.selectedChapter, !b.chapterRange.contains(ch) {
            filter.selectedChapter = nil
        }
        reloadItems()
    }

    func selectChapter(_ chapter: Int?) {
        filter.selectedChapter = chapter
        if let ch = chapter {
            filter.selectedBook = TextbookBook.book(forChapter: ch)
        }
        reloadItems()
    }

    func selectJLPTLevel(_ level: JLPTLevel?) {
        filter.selectedJLPTLevel = level
        reloadItems()
    }

    func selectLearningStatus(_ status: VocabLearningState?) {
        filter.selectedLearningStatus = status
        reloadItems()
    }

    func clearFilter() {
        filter = VocabFilter()
        reloadItems()
    }

    // MARK: - Custom Practice & Test Mode

    /// Directly starts or toggles test mode
    func toggleTestMode() {
        if isTestModeActive {
            stopTest()
        } else {
            startTest()
        }
    }

    /// Opens test directly on current chapter or all chapters without opening drawer
    func openTestMenu() {
        startTest()
    }

    /// Starts a test session on the selected scope
    func startTest(scopeTitle: String? = nil, chapters: [Int]? = nil, troubleOnly: Bool = false) {
        var baseList: [VocabItem]
        let title: String

        if let chapters = chapters {
            baseList = VocabDataService.shared.items.filter { chapters.contains($0.chapterNumber) }
            if troubleOnly {
                baseList = baseList.filter { $0.difficulty == .hard || $0.difficulty == .medium }
            }
            if let scopeTitle = scopeTitle {
                title = scopeTitle
            } else if chapters.count == 1, let ch = chapters.first {
                title = "Chapter \(ch)"
            } else if !chapters.isEmpty {
                title = "\(chapters.count) Chapters"
            } else {
                title = "All Chapters"
            }
        } else {
            baseList = VocabDataService.shared.fetchVocabItems(filter: filter)
            if troubleOnly {
                baseList = baseList.filter { $0.difficulty == .hard || $0.difficulty == .medium }
            }
            title = scopeTitle ?? filter.summaryText
        }

        if baseList.isEmpty {
            baseList = VocabDataService.shared.items
        }

        // Prioritize: problem words first, proficient words last
        let sorted = prioritizedVocabSort(baseList)
        self.testItems = sorted
        self.items = sorted
        self.testScopeTitle = title
        self.testTotalQuestions = sorted.count
        self.totalWordCount = sorted.count
        self.testCorrectCount = 0
        self.testWrongCount = 0
        self.currentIndex = 0
        self.isTestModeActive = true
        self.isTestPaused = false
        self.isShowingChapterSectionScreen = false
        self.isFlipped = false
        self.showTestNextButton = false
        self.hasRecordedRevealForCurrentCard = false
        self.sessionSeconds = 0
        self.isTimerPaused = false
        self.wordStartTime = Date()

        let session = VocabTestSession(
            id: UUID().uuidString,
            scopeTitle: title,
            startedAt: Date(),
            pausedAt: nil,
            accumulatedDurationSeconds: 0,
            questionIds: sorted.map { $0.id },
            currentIndex: 0,
            isMeaningRevealed: false,
            submittedAnswers: [],
            correctCount: 0,
            wrongCount: 0,
            status: .inProgress
        )
        self.currentTestSession = session
        saveActiveTestSession(status: .inProgress)

        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }

    // MARK: - Test Pause & Resume (Requirements 2 & 3)

    /// Pauses an active vocabulary test session
    func pauseTest() {
        guard isTestModeActive, !isTestPaused else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            isTestPaused = true
            isTimerPaused = true
        }
        saveActiveTestSession(status: .paused)

        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
    }

    /// Resumes a paused vocabulary test session
    func resumeTest() {
        if isTestModeActive && isTestPaused {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                isTestPaused = false
                isTimerPaused = false
                wordStartTime = Date()
            }
            saveActiveTestSession(status: .inProgress)

            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.impactOccurred()
            return
        }

        // Resume from persisted paused session
        guard let session = savedPausedSession ?? loadSavedPausedTestSession() else { return }
        let allItems = VocabDataService.shared.items
        let itemMap = Dictionary(uniqueKeysWithValues: allItems.map { ($0.id, $0) })
        let restored = session.questionIds.compactMap { itemMap[$0] }
        guard !restored.isEmpty else {
            clearSavedTestSession()
            return
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            self.testItems = restored
            self.items = restored
            self.testScopeTitle = session.scopeTitle
            self.testTotalQuestions = restored.count
            self.totalWordCount = restored.count
            self.testCorrectCount = session.correctCount
            self.testWrongCount = session.wrongCount
            self.currentIndex = min(session.currentIndex, max(0, restored.count - 1))
            self.isFlipped = session.isMeaningRevealed
            self.sessionSeconds = session.accumulatedDurationSeconds
            self.isTestModeActive = true
            self.isTestPaused = false
            self.isTimerPaused = false
            self.wordStartTime = Date()
            self.completedWordCount = session.submittedAnswers.count
            self.displayPercentage = session.totalQuestions > 0 ? min(100, Int(round((Double(session.currentIndex) / Double(session.totalQuestions)) * 100))) : 0

            var activeSession = session
            activeSession.status = .inProgress
            self.currentTestSession = activeSession
        }

        saveActiveTestSession(status: .inProgress)
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }

    /// Discards any saved paused test session
    func discardPausedTest() {
        clearSavedTestSession()
        if isTestModeActive {
            stopTest()
        }
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }

    // MARK: - Test Session Persistence (UserDefaults)

    func checkSavedPausedTestSession() {
        if let session = loadSavedPausedTestSession(), (session.status == .paused || session.status == .inProgress), !session.isCompleted {
            self.savedPausedSession = session
            self.hasSavedPausedTest = true
        } else {
            self.savedPausedSession = nil
            self.hasSavedPausedTest = false
        }
    }

    private func loadSavedPausedTestSession() -> VocabTestSession? {
        guard let data = UserDefaults.standard.data(forKey: pausedTestSessionKey) else { return nil }
        return try? JSONDecoder().decode(VocabTestSession.self, from: data)
    }

    func saveActiveTestSession(status: VocabTestSessionStatus) {
        guard var session = currentTestSession else { return }
        session.status = status
        session.accumulatedDurationSeconds = sessionSeconds
        session.currentIndex = currentIndex
        session.isMeaningRevealed = isFlipped
        session.correctCount = testCorrectCount
        session.wrongCount = testWrongCount
        if status == .paused {
            session.pausedAt = Date()
        }
        self.currentTestSession = session

        if let encoded = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(encoded, forKey: pausedTestSessionKey)
        }

        if status == .paused {
            self.savedPausedSession = session
            self.hasSavedPausedTest = true
        } else if status == .completed || status == .stopped {
            self.savedPausedSession = nil
            self.hasSavedPausedTest = false
        }
    }

    func clearSavedTestSession() {
        UserDefaults.standard.removeObject(forKey: pausedTestSessionKey)
        self.savedPausedSession = nil
        self.hasSavedPausedTest = false
        self.currentTestSession = nil
    }

    /// Stops the test and returns to the normal cards list
    func stopTest() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            self.isTestModeActive = false
            self.isTestPaused = false
            self.showTestNextButton = false
            self.hasRecordedRevealForCurrentCard = false
            self.isFlipped = false
        }
        clearSavedTestSession()
        reloadItems()

        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
    }

    func exitTestMode() {
        stopTest()
    }

    /// Returns to Card #1 (reset to beginning of cards)
    func resetToFirstCard() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            self.currentIndex = 0
            self.isFlipped = false
            self.wordStartTime = Date()
        }
        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
    }

    // MARK: - Import Chapter Vocabulary (Requirement 12)
    @discardableResult
    func importChapter(jsonString: String) -> Bool {
        let result = VocabDataService.shared.importChapter(from: jsonString)
        self.lastImportResult = result
        if result.isValid {
            self.lastImportError = nil
            self.filter.selectedChapter = result.chapterNumber
            self.filter.selectedBook = (result.bookNumber == 1) ? .book1 : .book2
            self.filter.selectedChapters.removeAll()
            reloadItems()
            self.currentIndex = 0
            return true
        } else {
            self.lastImportError = result.errors.first?.localizedDescription ?? "Validation failed"
            return false
        }
    }

    // MARK: - Active Word Accessor
    var currentWord: VocabItem {
        if isTestModeActive {
            // Retrieve strictly by current question's stable vocabulary ID
            if let session = currentTestSession,
               session.questionIds.indices.contains(currentIndex) {
                let stableId = session.questionIds[currentIndex]
                if let match = testItems.first(where: { $0.id == stableId }) {
                    return match
                }
                if let match = VocabDataService.shared.items.first(where: { $0.id == stableId }) {
                    return match
                }
            }
            if testItems.indices.contains(currentIndex) {
                return testItems[currentIndex]
            }
        }
        guard items.indices.contains(currentIndex) else {
            return VocabItem(
                id: "empty",
                textbook: .minnaNoNihongo,
                bookNumber: 1,
                chapterNumber: 1,
                number: 0,
                japanese: "単語がありません",
                kanji: "単語がありません",
                kana: "たんごがありません",
                romaji: "Tango ga arimasen",
                meaning: "No vocabulary in current filter",
                wordType: .noun,
                jlptLevel: .n5,
                categoryTag: "なし",
                difficulty: .easy,
                bestTimeSeconds: nil,
                learningState: .unseen
            )
        }
        return items[currentIndex]
    }

    // MARK: - Timer Handling
    func startSessionTimer() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if !self.isTimerPaused && !self.isTestPaused {
                    self.sessionSeconds += 1
                    if self.isTestModeActive {
                        self.currentTestSession?.accumulatedDurationSeconds = self.sessionSeconds
                    }
                }
            }
    }

    func toggleTimer() {
        if isTestModeActive {
            if isTestPaused {
                resumeTest()
            } else {
                pauseTest()
            }
        } else {
            isTimerPaused.toggle()
            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.impactOccurred()
        }
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

    // MARK: - Card Flip (Requirement 1: Meaning Revealed for Current Word)
    @Published var showTestNextButton: Bool = false
    private var hasRecordedRevealForCurrentCard: Bool = false

    func flipCard() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isFlipped.toggle()
        }

        if isTestModeActive {
            currentTestSession?.isMeaningRevealed = isFlipped
            saveActiveTestSession(status: isTestPaused ? .paused : .inProgress)
        }

        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    func advanceToNextWord() {
        let activeList = isTestModeActive ? testItems : items
        let nextIndex = currentIndex + 1
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            isFlipped = false
            showTestNextButton = false
            hasRecordedRevealForCurrentCard = false
            wordStartTime = Date()

            if nextIndex < activeList.count {
                currentIndex = nextIndex
                if isTestModeActive {
                    currentTestSession?.currentIndex = nextIndex
                    currentTestSession?.isMeaningRevealed = false
                    saveActiveTestSession(status: .inProgress)
                }
            } else {
                // Reached 100% test completion!
                if isTestModeActive {
                    if testWrongCount == 0 && testCorrectCount > 0 {
                        confettiTrigger += 1
                    }
                    currentTestSession?.status = .completed
                    clearSavedTestSession()
                    isTestModeActive = false
                    reloadItems()
                }
                currentIndex = 0
            }
        }
    }

    func advanceToNextWordFromTest() {
        guard !items.isEmpty else { return }
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
        advanceToNextWord()
    }

    // MARK: - Navigation
    func selectWord(at index: Int) {
        let activeList = isTestModeActive ? testItems : items
        guard activeList.indices.contains(index), index != currentIndex else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            currentIndex = index
            isFlipped = false
            wordStartTime = Date()
        }
        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
    }

    /// Single word navigation for the right-side slider (Requirement 7.E)
    func navigateOneWord(direction: Int) {
        let nextIndex = currentIndex + direction
        if items.indices.contains(nextIndex) {
            selectWord(at: nextIndex)
        }
    }

    func nextWord() {
        navigateOneWord(direction: 1)
    }

    func previousWord() {
        navigateOneWord(direction: -1)
    }

    /// Swipes on main strip (Requirement 3: slow = 1 word, fast = ~10 words)
    func swipeStrip(velocity: CGFloat) {
        let step: Int = abs(velocity) > 800 ? 10 : 1
        let direction = velocity < 0 ? 1 : -1
        let targetIndex = max(0, min(items.count - 1, currentIndex + (direction * step)))
        if targetIndex != currentIndex {
            selectWord(at: targetIndex)
        }
    }

    // MARK: - Word Review Status (Red: got wrong, Yellow: sometimes miss, Green: know)
    func statusColor(for item: VocabItem) -> Color {
        item.reviewSquareColor
    }

    func cycleActiveWordStatus() {
        guard items.indices.contains(currentIndex) else { return }
        var item = items[currentIndex]
        item.cycleDifficulty()

        VocabDataService.shared.updateItem(
            id: item.id,
            learningState: item.learningState,
            difficulty: item.difficulty,
            responseTime: nil,
            isCorrect: (item.difficulty == .easy)
        )

        // Re-sort: if marked proficient (easy), moves to the last; if trouble (hard), moves to the first
        items[currentIndex] = item
        items = prioritizedVocabSort(items)

        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
    }

    // MARK: - Answering & Practice Action (Proficient -> LAST of list, Problem -> FIRST of list)

    /// Known / Answer Word (Tick mark -> Green)
    /// Card user is proficient in is moved to the LAST of the list!
    func answerWord() {
        guard items.indices.contains(currentIndex) else { return }
        resumeTimerIfNeeded()

        let elapsed = Date().timeIntervalSince(wordStartTime)
        var item = items[currentIndex]

        let newState: VocabLearningState = isFlipped ? .knownAfterReveal : .knownDirectly
        item.learningState = newState
        item.difficulty = .easy
        item.currentStreak += 1
        item.bestStreak = max(item.bestStreak, item.currentStreak)

        if let existing = item.bestTimeSeconds {
            item.bestTimeSeconds = min(existing, elapsed)
        } else {
            item.bestTimeSeconds = elapsed
        }

        VocabDataService.shared.updateItem(
            id: item.id,
            learningState: newState,
            difficulty: .easy,
            responseTime: elapsed,
            isCorrect: true
        )

        SRSStorageService.shared.recordReview(
            cardId: item.id,
            rating: .good,
            durationMs: max(300, Int(elapsed * 1000)),
            scope: "chapter_\(item.chapterNumber)"
        )

        testCorrectCount += 1
        items[currentIndex] = item

        self.completedWordCount = items.filter { $0.learningState != .unseen }.count
        self.displayPercentage = totalWordCount > 0 ? min(100, Int(round((Double(completedWordCount) / Double(totalWordCount)) * 100))) : 0

        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)

        advanceToNextWord()
    }

    /// Reject / Got Wrong (X mark -> Red)
    /// Card the user is facing problem with stays at the FIRST of the list!
    func rejectWord() {
        guard items.indices.contains(currentIndex) else { return }
        resumeTimerIfNeeded()

        let elapsed = Date().timeIntervalSince(wordStartTime)
        var item = items[currentIndex]

        item.difficulty = .hard
        item.currentStreak = 0

        VocabDataService.shared.updateItem(
            id: item.id,
            learningState: item.learningState,
            difficulty: .hard,
            responseTime: elapsed,
            isCorrect: false
        )

        SRSStorageService.shared.recordReview(
            cardId: item.id,
            rating: .again,
            durationMs: max(300, Int(elapsed * 1000)),
            scope: "chapter_\(item.chapterNumber)"
        )

        testWrongCount += 1

        // Keep problem words at the FRONT (first) of the list
        items[currentIndex] = item
        items = prioritizedVocabSort(items)

        // Advance to next trouble word or stay at front
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            currentIndex = min(currentIndex + 1, max(0, items.count - 1))
            isFlipped = false
            wordStartTime = Date()
        }

        self.completedWordCount = items.filter { $0.learningState != .unseen }.count
        self.displayPercentage = totalWordCount > 0 ? min(100, Int(round((Double(completedWordCount) / Double(totalWordCount)) * 100))) : 0

        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.warning)
    }

    // MARK: - 4-Button Test Rating (Don't Know, Hard, Good, Easy)
    enum PracticeRating: String, CaseIterable {
        case again = "Don't Know"
        case hard = "Hard"
        case good = "Good"
        case easy = "Easy"

        var colorHex: String {
            switch self {
            case .again: return "#EF4444"
            case .hard: return "#F59E0B"
            case .good: return "#10B981"
            case .easy: return "#3B82F6"
            }
        }
    }

    func rateWord(_ rating: PracticeRating) {
        guard !isTestPaused else { return }
        let activeList = isTestModeActive ? testItems : items
        guard activeList.indices.contains(currentIndex) else { return }

        resumeTimerIfNeeded()
        let elapsed = Date().timeIntervalSince(wordStartTime)
        var item = currentWord

        let srsRating: SRSRating
        let isCorrect: Bool

        switch rating {
        case .again:
            srsRating = .again
            isCorrect = false
            item.difficulty = .hard
            item.currentStreak = 0
            if item.learningState == .unseen {
                item.learningState = .knownAfterReveal
            }
            testWrongCount += 1

            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.warning)

        case .hard:
            srsRating = .hard
            isCorrect = false
            item.difficulty = .hard
            item.currentStreak = max(0, item.currentStreak)
            if item.learningState == .unseen {
                item.learningState = .knownAfterReveal
            }
            testWrongCount += 1

            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.impactOccurred()

        case .good:
            srsRating = .good
            isCorrect = true
            item.difficulty = .medium
            item.currentStreak += 1
            if item.currentStreak > item.bestStreak {
                item.bestStreak = item.currentStreak
            }
            if item.learningState == .unseen {
                item.learningState = isFlipped ? .knownAfterReveal : .knownDirectly
            }
            testCorrectCount += 1

            let feedback = UIImpactFeedbackGenerator(style: .light)
            feedback.impactOccurred()

        case .easy:
            srsRating = .easy
            isCorrect = true
            item.difficulty = .easy
            item.currentStreak += 1
            if item.currentStreak > item.bestStreak {
                item.bestStreak = item.currentStreak
            }
            if item.learningState == .unseen {
                item.learningState = isFlipped ? .knownAfterReveal : .knownDirectly
            }
            testCorrectCount += 1

            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
        }

        SRSStorageService.shared.recordReview(
            cardId: item.id,
            rating: srsRating,
            durationMs: max(300, Int(elapsed * 1000)),
            scope: "chapter_\(item.chapterNumber)"
        )

        VocabDataService.shared.updateItem(
            id: item.id,
            learningState: item.learningState,
            difficulty: item.difficulty,
            responseTime: elapsed,
            isCorrect: isCorrect
        )

        if isTestModeActive {
            if let idx = testItems.firstIndex(where: { $0.id == item.id }) {
                testItems[idx] = item
            }
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx] = item
            }

            let answer = VocabTestSubmittedAnswer(
                wordId: item.id,
                rating: rating.rawValue,
                isCorrect: isCorrect,
                responseTimeSeconds: elapsed,
                answeredAt: Date()
            )
            currentTestSession?.submittedAnswers.append(answer)
            currentTestSession?.correctCount = testCorrectCount
            currentTestSession?.wrongCount = testWrongCount
        } else {
            items[currentIndex] = item
        }

        let currentActive = isTestModeActive ? testItems : items
        self.completedWordCount = currentActive.filter { $0.learningState != .unseen }.count
        self.displayPercentage = totalWordCount > 0 ? min(100, Int(round((Double(completedWordCount) / Double(totalWordCount)) * 100))) : 0

        // Advance to next word across strip and active counter
        advanceToNextWord()
    }

    // MARK: - Pronunciation Audio
    func speakCurrentWord() {
        let word = currentWord
        guard !word.japanese.isEmpty else { return }
        SpeechService.shared.speak(text: word.japanese, phoneticReading: word.kana)
    }
}
