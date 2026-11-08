import Foundation
import Combine

extension Notification.Name {
    static let kanjiDataUpdated = Notification.Name("kanjiDataUpdated")
}

final class KanjiDataService: ObservableObject {
    static let shared = KanjiDataService()

    private let storageKey = "farki_kanji_repository_v2"
    private let masteryStorageKey = "farki_kanji_mastery_state_v2"

    @Published private(set) var items: [KanjiItem] = []
    @Published private(set) var chapters: [KanjiChapterSheet] = []

    private init() {
        loadData()
    }

    // MARK: - Data Loading & Persistence
    func loadData() {
        // 1. Load bundled or local JSON
        if let sheets = loadBundledKanjiSheets(), !sheets.isEmpty {
            self.chapters = sheets
            var allKanjis: [KanjiItem] = []
            for sheet in sheets {
                allKanjis.append(contentsOf: sheet.kanjis)
            }
            self.items = allKanjis
        } else {
            // Fallback seed items
            self.items = fallbackSeedKanjis()
            self.chapters = [
                KanjiChapterSheet(
                    chapterNumber: 1,
                    title: "第1課 • 自己紹介と身近な人々",
                    englishTitle: "Introductions & Personal Identity",
                    kanjis: self.items
                )
            ]
        }

        // 2. Restore user mastery and review progress
        applySavedMasteryState()

        NotificationCenter.default.post(name: .kanjiDataUpdated, object: nil)
    }

    private func applySavedMasteryState() {
        guard let savedData = UserDefaults.standard.data(forKey: masteryStorageKey),
              let dict = try? JSONDecoder().decode([String: KanjiMasteryRecord].self, from: savedData) else {
            return
        }

        for i in 0..<items.count {
            if let record = dict[items[i].id] {
                items[i].mastery = record.mastery
                items[i].currentStreak = record.currentStreak
                items[i].bestStreak = record.bestStreak
                items[i].lastReviewed = record.lastReviewed
            }
        }

        // Also update items inside chapters
        for chIdx in 0..<chapters.count {
            var updatedKanjis = chapters[chIdx].kanjis
            for kIdx in 0..<updatedKanjis.count {
                if let record = dict[updatedKanjis[kIdx].id] {
                    updatedKanjis[kIdx].mastery = record.mastery
                    updatedKanjis[kIdx].currentStreak = record.currentStreak
                    updatedKanjis[kIdx].bestStreak = record.bestStreak
                    updatedKanjis[kIdx].lastReviewed = record.lastReviewed
                }
            }
            chapters[chIdx] = KanjiChapterSheet(
                chapterNumber: chapters[chIdx].chapterNumber,
                title: chapters[chIdx].title,
                englishTitle: chapters[chIdx].englishTitle,
                kanjis: updatedKanjis
            )
        }
    }

    private func saveMasteryState() {
        var dict: [String: KanjiMasteryRecord] = [:]
        for item in items {
            dict[item.id] = KanjiMasteryRecord(
                mastery: item.mastery,
                currentStreak: item.currentStreak,
                bestStreak: item.bestStreak,
                lastReviewed: item.lastReviewed
            )
        }
        if let encoded = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(encoded, forKey: masteryStorageKey)
        }
    }

    // MARK: - Query Methods
    func kanjis(for chapter: Int) -> [KanjiItem] {
        return items.filter { $0.chapterNumber == chapter }
    }

    func kanjiCount(for chapter: Int) -> Int {
        return kanjis(for: chapter).count
    }

    func chapterSheet(for chapter: Int) -> KanjiChapterSheet? {
        return chapters.first { $0.chapterNumber == chapter }
    }

    // MARK: - Progress & Mastery Updates
    func updateMastery(id: String, mastery: MasteryStatus, wasCorrect: Bool) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }

        items[index].mastery = mastery
        items[index].lastReviewed = Date()

        if wasCorrect {
            items[index].currentStreak += 1
            items[index].bestStreak = max(items[index].bestStreak, items[index].currentStreak)
        } else {
            items[index].currentStreak = 0
        }

        // Update in chapter sheet
        let chNum = items[index].chapterNumber
        if let chIdx = chapters.firstIndex(where: { $0.chapterNumber == chNum }),
           let kIdx = chapters[chIdx].kanjis.firstIndex(where: { $0.id == id }) {
            var updatedKanjis = chapters[chIdx].kanjis
            updatedKanjis[kIdx] = items[index]
            chapters[chIdx] = KanjiChapterSheet(
                chapterNumber: chapters[chIdx].chapterNumber,
                title: chapters[chIdx].title,
                englishTitle: chapters[chIdx].englishTitle,
                kanjis: updatedKanjis
            )
        }

        saveMasteryState()
        NotificationCenter.default.post(name: .kanjiDataUpdated, object: nil)
    }

    func recordTestResult(id: String, isCorrect: Bool) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let newMastery: MasteryStatus = isCorrect ? .mastered : .learning
        updateMastery(id: id, mastery: newMastery, wasCorrect: isCorrect)
    }

    func globalMetrics() -> (total: Int, mastered: Int, inProgress: Int, unlearned: Int, accuracy: Int) {
        let total = items.count
        guard total > 0 else { return (0, 0, 0, 0, 0) }

        let mastered = items.filter { $0.mastery == .mastered }.count
        let inProgress = items.filter { $0.mastery == .learning }.count
        let unlearned = items.filter { $0.mastery == .unlearned }.count

        let accuracy = Int(round((Double(mastered) / Double(total)) * 100))
        return (total, mastered, inProgress, unlearned, accuracy)
    }

    // MARK: - Backward Compatibility
    func fetchDefaultKanjis() -> [KanjiItem] {
        return items
    }

    // MARK: - Robust JSON Discovery
    private func loadBundledKanjiSheets() -> [KanjiChapterSheet]? {
        guard let data = findKanjiJSONData() else { return nil }
        return try? JSONDecoder().decode([KanjiChapterSheet].self, from: data)
    }

    private func findKanjiJSONData() -> Data? {
        let filename = "minna_kanji_chapters"
        // 1. Bundle resource
        if let url = Bundle.main.url(forResource: filename, withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        if let url = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: "Kanji"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        if let url = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: "Resources/Kanji"),
           let data = try? Data(contentsOf: url) {
            return data
        }

        // 2. Relative to #filePath
        let thisFileUrl = URL(fileURLWithPath: #filePath)
        let candidatePath = thisFileUrl
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Kanji/\(filename).json")
        if let data = try? Data(contentsOf: candidatePath) {
            return data
        }

        // 3. Absolute path
        let absolutePath = "/Users/static/Documents/projects/farki/Farki/Resources/Kanji/\(filename).json"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: absolutePath)) {
            return data
        }

        return nil
    }

    private func fallbackSeedKanjis() -> [KanjiItem] {
        return [
            KanjiItem(
                id: "k-1",
                chapterNumber: 1,
                kanji: "私",
                english: "I, me, private",
                furigana: "わたし",
                romaji: "watashi",
                onyomi: ["シ"],
                kunyomi: ["わたし", "わたくし"],
                strokeCount: 7,
                level: .n5,
                words: [
                    KanjiWord(word: "私", reading: "わたし", meaning: "I; me"),
                    KanjiWord(word: "私たち", reading: "わたしたち", meaning: "we; us")
                ],
                examples: [
                    ExampleSentence(japanese: "私は学生です。", translation: "I am a student.")
                ],
                mastery: .unlearned
            ),
            KanjiItem(
                id: "k-2",
                chapterNumber: 1,
                kanji: "人",
                english: "person, human",
                furigana: "ひと",
                romaji: "hito",
                onyomi: ["ジン", "ニン"],
                kunyomi: ["ひと"],
                strokeCount: 2,
                level: .n5,
                words: [
                    KanjiWord(word: "あの人", reading: "あのひと", meaning: "that person"),
                    KanjiWord(word: "日本人", reading: "にほんじん", meaning: "Japanese person")
                ],
                examples: [
                    ExampleSentence(japanese: "あの人はどなたですか。", translation: "Who is that person?")
                ],
                mastery: .unlearned
            )
        ]
    }
}

private struct KanjiMasteryRecord: Codable {
    let mastery: MasteryStatus
    let currentStreak: Int
    let bestStreak: Int
    let lastReviewed: Date?
}
