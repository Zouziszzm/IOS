import Foundation
import Combine

final class VocabRevisionService: ObservableObject {
    static let shared = VocabRevisionService()

    private let storageKey = "farki_vocab_revision_records_v1"
    @Published private(set) var records: [String: VocabRevisionRecord] = [:]

    private init() {
        loadRecords()
    }

    // MARK: - Persistence
    private func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([String: VocabRevisionRecord].self, from: data) {
            self.records = saved
        } else {
            self.records = [:]
        }
    }

    private func saveRecords() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        NotificationCenter.default.post(name: .vocabRevisionUpdated, object: nil)
    }

    // MARK: - Record Revision Answer
    func recordAnswer(
        word: VocabItem,
        isCorrect: Bool,
        direction: VocabRevisionDirection
    ) {
        var record = records[word.id] ?? VocabRevisionRecord(
            wordId: word.id,
            chapterNumber: word.chapterNumber,
            lastRevisedAt: Date(),
            correctCount: 0,
            incorrectCount: 0,
            isLastAnswerCorrect: false
        )

        record.lastRevisedAt = Date()
        if isCorrect {
            record.correctCount += 1
            record.isLastAnswerCorrect = true
        } else {
            record.incorrectCount += 1
            record.isLastAnswerCorrect = false
        }

        records[word.id] = record
        saveRecords()
    }

    // MARK: - Queries
    func record(for wordId: String) -> VocabRevisionRecord? {
        records[wordId]
    }

    func isWordCorrectlyRevised(wordId: String) -> Bool {
        guard let rec = records[wordId] else { return false }
        return rec.isLastAnswerCorrect && rec.correctCount > 0
    }

    func revisedWordsCount(for chapter: Int) -> Int {
        records.values.filter { $0.chapterNumber == chapter }.count
    }

    func correctlyRevisedWordsCount(for chapter: Int) -> Int {
        records.values.filter { $0.chapterNumber == chapter && $0.isLastAnswerCorrect && $0.correctCount > 0 }.count
    }

    func incorrectWordsCount(for chapter: Int) -> Int {
        records.values.filter { $0.chapterNumber == chapter && !$0.isLastAnswerCorrect && ($0.incorrectCount > 0 || $0.correctCount > 0) }.count
    }

    func lastRevisionDate(for chapter: Int) -> Date? {
        let chapterRecords = records.values.filter { $0.chapterNumber == chapter }
        return chapterRecords.map(\.lastRevisedAt).max()
    }

    func isChapterFullyRevised(chapter: Int) -> Bool {
        let allItems = VocabDataService.shared.items.filter { $0.chapterNumber == chapter }
        guard !allItems.isEmpty else { return false }
        return correctlyRevisedWordsCount(for: chapter) >= allItems.count
    }

    // MARK: - Chapter Progress Summaries
    func chapterSummary(for chapter: Int) -> ChapterProgressSummary {
        let chapterItems = VocabDataService.shared.items.filter { $0.chapterNumber == chapter }
        let totalWords = chapterItems.count
        let studiedWords = chapterItems.filter { $0.learningState != .unseen }.count
        let revisedWords = revisedWordsCount(for: chapter)
        let correctlyRevised = correctlyRevisedWordsCount(for: chapter)
        let incorrectWords = incorrectWordsCount(for: chapter)
        let lastDate = lastRevisionDate(for: chapter)

        return ChapterProgressSummary(
            chapterNumber: chapter,
            totalWords: totalWords,
            studiedWords: studiedWords,
            revisedWords: revisedWords,
            correctlyRevisedWords: correctlyRevised,
            incorrectWordsCount: incorrectWords,
            lastRevisionDate: lastDate
        )
    }

    func allChapterSummaries() -> [ChapterProgressSummary] {
        let allItems = VocabDataService.shared.items
        let chapterNumbers = Array(Set(allItems.map(\.chapterNumber))).sorted()
        let effectiveChapters = chapterNumbers.isEmpty ? Array(1...25) : chapterNumbers
        return effectiveChapters.map { chapterSummary(for: $0) }
    }

    /// Displays three active chapters at a time on Dashboard.
    /// Automatically rotates completed chapters (State 3: Fully Revised).
    func activeThreeChapters() -> [ChapterProgressSummary] {
        let summaries = allChapterSummaries()
        // Filter out chapters that are fully completed (State 3: Fully Revised)
        let active = summaries.filter { $0.state != .fullyRevised }

        if active.count >= 3 {
            return Array(active.prefix(3))
        } else if !active.isEmpty {
            return active
        } else {
            // If all chapters are fully revised, show the last 3 for reference
            return Array(summaries.suffix(3))
        }
    }

    /// Trouble Radar: displays the three most recent chapters with revision activity
    func troubleRadarChapters() -> [ChapterProgressSummary] {
        let summaries = allChapterSummaries()
        let revisedChapters = summaries.filter { $0.lastRevisionDate != nil }

        // Sort descending by most recent revision activity
        let sorted = revisedChapters.sorted {
            ($0.lastRevisionDate ?? .distantPast) > ($1.lastRevisionDate ?? .distantPast)
        }

        return Array(sorted.prefix(3))
    }

    // MARK: - Global Metrics
    func globalMetrics() -> GlobalRevisionMetrics {
        let totalRevised = records.count
        let correct = records.values.reduce(0) { $0 + $1.correctCount }
        let incorrect = records.values.reduce(0) { $0 + $1.incorrectCount }
        let completed = allChapterSummaries().filter { $0.state == .fullyRevised }.count

        return GlobalRevisionMetrics(
            totalWordsRevised: totalRevised,
            correctAnswers: correct,
            incorrectAnswers: incorrect,
            completedChaptersCount: completed
        )
    }

    // MARK: - Reset
    func resetAllRevisionProgress() {
        records.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
        saveRecords()
    }
}

extension Notification.Name {
    static let vocabRevisionUpdated = Notification.Name("vocabRevisionUpdated")
}
