import SwiftUI
import Combine

final class KanjiViewModel: ObservableObject {
    private let dataService = KanjiDataService.shared
    private var cancellables = Set<AnyCancellable>()
    private var timerCancellable: AnyCancellable?

    // MARK: - Navigation & Chapter Selection
    @Published var availableChapters: [KanjiChapterSheet] = []
    @Published var selectedChapter: Int = 1
    @Published var selectedTabMode: KanjiTabMode = .study
    @Published var isChapterSelectorExpanded: Bool = false

    // MARK: - Study Mode State
    @Published var items: [KanjiItem] = []
    @Published var currentIndex: Int = 0
    @Published var isFlipped: Bool = false
    @Published var sessionSeconds: Int = 0
    @Published var isTimerPaused: Bool = true
    @Published var confettiTrigger: Int = 0

    // MARK: - Test Mode State
    @Published var isTestModeActive: Bool = false
    @Published var isTestPaused: Bool = false
    @Published var testItems: [KanjiItem] = []
    @Published var testCurrentIndex: Int = 0
    @Published var testCorrectCount: Int = 0
    @Published var testWrongCount: Int = 0
    @Published var isTestAnswerRevealed: Bool = false

    // Test Inputs (Requirement: Write meaning, On'yomi, Kun'yomi)
    @Published var inputMeaning: String = ""
    @Published var inputOnyomi: String = ""
    @Published var inputKunyomi: String = ""

    // MARK: - Revision Mode State
    @Published var revisionSelectedChapter: Int = 1
    @Published var isRevisionSessionActive: Bool = false
    @Published var isRevisionSessionFinished: Bool = false
    @Published var revisionWords: [KanjiItem] = []
    @Published var revisionCurrentIndex: Int = 0
    @Published var isRevisionAnswerRevealed: Bool = false
    @Published var revisionCorrectCount: Int = 0
    @Published var revisionIncorrectCount: Int = 0

    init() {
        reloadData()
        startSessionTimer()

        // Auto reload when kanji data updates
        NotificationCenter.default.publisher(for: .kanjiDataUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadData()
            }
            .store(in: &cancellables)
    }

    deinit {
        timerCancellable?.cancel()
    }

    // MARK: - Data Reload
    func reloadData() {
        self.availableChapters = dataService.chapters
        let chKanjis = dataService.kanjis(for: selectedChapter)
        self.items = chKanjis.isEmpty ? dataService.items : chKanjis

        if currentIndex >= items.count {
            currentIndex = max(0, items.count - 1)
        }
    }

    // MARK: - Computed Properties
    var currentKanji: KanjiItem {
        guard items.indices.contains(currentIndex) else {
            return KanjiItem(
                id: "placeholder",
                chapterNumber: selectedChapter,
                kanji: "漢",
                english: "Kanji",
                furigana: "かんじ",
                romaji: "kanji",
                onyomi: ["カン"],
                kunyomi: [],
                strokeCount: 13,
                level: .n5,
                words: [KanjiWord(word: "漢字", reading: "かんじ", meaning: "Kanji; Chinese character")],
                examples: [ExampleSentence(japanese: "漢字の勉強をします。", translation: "I study kanji.")],
                mastery: .unlearned
            )
        }
        return items[currentIndex]
    }

    var currentTestKanji: KanjiItem {
        guard testItems.indices.contains(testCurrentIndex) else {
            return currentKanji
        }
        return testItems[testCurrentIndex]
    }

    var currentTestPromptWord: KanjiWord? {
        currentTestKanji.words.first
    }

    var currentRevisionKanji: KanjiItem {
        guard revisionWords.indices.contains(revisionCurrentIndex) else {
            return currentKanji
        }
        return revisionWords[revisionCurrentIndex]
    }

    var currentRevisionPromptWord: KanjiWord? {
        currentRevisionKanji.words.first
    }

    var currentChapterSheet: KanjiChapterSheet? {
        availableChapters.first(where: { $0.chapterNumber == selectedChapter })
    }

    var totalChapterKanjiCount: Int {
        items.count
    }

    var masteredChapterKanjiCount: Int {
        items.filter { $0.mastery == .mastered }.count
    }

    var formattedSessionTime: String {
        let m = sessionSeconds / 60
        let s = sessionSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Chapter & Item Selection
    func selectChapter(_ chapter: Int) {
        selectedChapter = chapter
        revisionSelectedChapter = chapter
        reloadData()
        currentIndex = 0
        isFlipped = false

        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
    }

    func selectKanji(at index: Int) {
        guard items.indices.contains(index), index != currentIndex else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            currentIndex = index
            isFlipped = false
        }
        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
    }

    func navigateOneKanji(direction: Int) {
        let nextIndex = currentIndex + direction
        if items.indices.contains(nextIndex) {
            selectKanji(at: nextIndex)
        }
    }

    func nextKanji() {
        navigateOneKanji(direction: 1)
    }

    func previousKanji() {
        navigateOneKanji(direction: -1)
    }

    func flipCard() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isFlipped.toggle()
        }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    // MARK: - Session Timer
    private func startSessionTimer() {
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, !self.isTimerPaused else { return }
                self.sessionSeconds += 1
            }
    }

    func toggleTimer() {
        isTimerPaused.toggle()
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }

    // MARK: - Audio Speech
    func playAudio(for text: String, phonetic: String? = nil) {
        SpeechService.shared.speak(text: text, phoneticReading: phonetic)
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    // MARK: - Mastery Status Updates
    func cycleActiveKanjiMastery() {
        guard items.indices.contains(currentIndex) else { return }
        let current = items[currentIndex].mastery
        let next: MasteryStatus
        switch current {
        case .unlearned: next = .learning
        case .learning: next = .mastered
        case .mastered: next = .unlearned
        }
        dataService.updateMastery(id: items[currentIndex].id, mastery: next, wasCorrect: (next == .mastered))
        reloadData()

        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
    }

    func setMastery(for id: String, status: MasteryStatus) {
        dataService.updateMastery(id: id, mastery: status, wasCorrect: (status == .mastered))
        reloadData()
    }

    // MARK: - Test Mode Actions
    func startTest() {
        let pool = items.isEmpty ? dataService.items : items
        guard !pool.isEmpty else { return }

        testItems = pool.shuffled()
        testCurrentIndex = 0
        testCorrectCount = 0
        testWrongCount = 0
        isTestAnswerRevealed = false
        isTestPaused = false
        clearTestInputs()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isTestModeActive = true
        }
        isTimerPaused = false

        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }

    func pauseTest() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isTestPaused = true
        }
    }

    func resumeTest() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isTestPaused = false
        }
        isTimerPaused = false
    }

    func exitTest() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isTestModeActive = false
            isTestPaused = false
        }
        clearTestInputs()
        reloadData()
    }

    func clearTestInputs() {
        inputMeaning = ""
        inputOnyomi = ""
        inputKunyomi = ""
    }

    func checkAnswer() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            isTestAnswerRevealed = true
        }
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    func rateTestItem(status: MasteryStatus, isCorrect: Bool) {
        guard testItems.indices.contains(testCurrentIndex) else { return }
        let active = testItems[testCurrentIndex]

        dataService.updateMastery(id: active.id, mastery: status, wasCorrect: isCorrect)

        if isCorrect {
            testCorrectCount += 1
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
        } else {
            testWrongCount += 1
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.warning)
        }

        advanceTestQuestion()
    }

    func advanceTestQuestion() {
        let nextIndex = testCurrentIndex + 1
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            clearTestInputs()
            isTestAnswerRevealed = false

            if nextIndex < testItems.count {
                testCurrentIndex = nextIndex
            } else {
                // Test completed!
                if testWrongCount == 0 && testCorrectCount > 0 {
                    confettiTrigger += 1
                }
                isTestModeActive = false
                reloadData()
            }
        }
    }

    // Match verification helpers for visual cues
    var isMeaningMatch: Bool {
        guard !inputMeaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let entered = inputMeaning.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let actual = currentTestKanji.english.lowercased()
        return actual.contains(entered) || entered.contains(actual)
    }

    var isOnyomiMatch: Bool {
        guard !inputOnyomi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let entered = inputOnyomi.trimmingCharacters(in: .whitespacesAndNewlines)
        return currentTestKanji.onyomi.contains { on in
            on.localizedCaseInsensitiveContains(entered) || entered.localizedCaseInsensitiveContains(on)
        }
    }

    var isKunyomiMatch: Bool {
        guard !inputKunyomi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let entered = inputKunyomi.trimmingCharacters(in: .whitespacesAndNewlines)
        return currentTestKanji.kunyomi.contains { kun in
            let clean = kun.replacingOccurrences(of: "・", with: "")
            return clean.localizedCaseInsensitiveContains(entered) || entered.localizedCaseInsensitiveContains(clean)
        }
    }

    // MARK: - Revision Tab Actions
    func startRevision(chapter: Int) {
        revisionSelectedChapter = chapter
        let chKanjis = dataService.kanjis(for: chapter)
        let pool = chKanjis.isEmpty ? dataService.items : chKanjis

        revisionWords = pool.shuffled()
        revisionCurrentIndex = 0
        revisionCorrectCount = 0
        revisionIncorrectCount = 0
        isRevisionAnswerRevealed = false
        isRevisionSessionFinished = false

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isRevisionSessionActive = true
        }

        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }

    func revealRevisionAnswer() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            isRevisionAnswerRevealed = true
        }
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    func rateRevision(isCorrect: Bool) {
        guard revisionWords.indices.contains(revisionCurrentIndex) else { return }
        let item = revisionWords[revisionCurrentIndex]

        let newStatus: MasteryStatus = isCorrect ? .mastered : .learning
        dataService.updateMastery(id: item.id, mastery: newStatus, wasCorrect: isCorrect)

        if isCorrect {
            revisionCorrectCount += 1
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
        } else {
            revisionIncorrectCount += 1
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.warning)
        }

        let nextIndex = revisionCurrentIndex + 1
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            isRevisionAnswerRevealed = false
            if nextIndex < revisionWords.count {
                revisionCurrentIndex = nextIndex
            } else {
                isRevisionSessionFinished = true
                let total = revisionCorrectCount + revisionIncorrectCount
                if total > 0 && Double(revisionCorrectCount) / Double(total) >= 0.8 {
                    confettiTrigger += 1
                }
            }
        }
    }

    func exitRevision() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isRevisionSessionActive = false
            isRevisionSessionFinished = false
        }
        reloadData()
    }
}
