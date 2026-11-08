import Foundation
import SwiftUI

struct ExampleSentence: Identifiable, Codable, Equatable {
    var id: String { japanese }
    let japanese: String
    let translation: String

    init(japanese: String, translation: String) {
        self.japanese = japanese
        self.translation = translation
    }
}

enum MasteryStatus: String, Codable, CaseIterable {
    case unlearned = "New"
    case learning = "In Progress"
    case mastered = "Mastered"

    var badgeColor: Color {
        switch self {
        case .unlearned: return Color(hex: "#71717A")
        case .learning: return Color(hex: "#F59E0B")
        case .mastered: return Color(hex: "#10B981")
        }
    }
}

struct KanjiWord: Identifiable, Codable, Equatable {
    var id: String { word }
    let word: String        // e.g. "先生", "学生"
    let reading: String     // e.g. "せんせい", "がくせい"
    let meaning: String     // e.g. "teacher; instructor"

    init(word: String, reading: String, meaning: String) {
        self.word = word
        self.reading = reading
        self.meaning = meaning
    }
}

struct KanjiItem: Identifiable, Codable, Equatable {
    let id: String
    var chapterNumber: Int
    let kanji: String
    let english: String
    let furigana: String
    let romaji: String
    let onyomi: [String]
    let kunyomi: [String]
    let strokeCount: Int
    let level: JLPTLevel
    var words: [KanjiWord]
    let examples: [ExampleSentence]
    var mastery: MasteryStatus
    var currentStreak: Int
    var bestStreak: Int
    var lastReviewed: Date?

    init(
        id: String = UUID().uuidString,
        chapterNumber: Int = 1,
        kanji: String,
        english: String,
        furigana: String = "",
        romaji: String = "",
        onyomi: [String] = [],
        kunyomi: [String] = [],
        strokeCount: Int = 1,
        level: JLPTLevel = .n5,
        words: [KanjiWord] = [],
        examples: [ExampleSentence] = [],
        mastery: MasteryStatus = .unlearned,
        currentStreak: Int = 0,
        bestStreak: Int = 0,
        lastReviewed: Date? = nil
    ) {
        self.id = id
        self.chapterNumber = chapterNumber
        self.kanji = kanji
        self.english = english
        self.furigana = furigana
        self.romaji = romaji
        self.onyomi = onyomi
        self.kunyomi = kunyomi
        self.strokeCount = strokeCount
        self.level = level
        self.words = words
        self.examples = examples
        self.mastery = mastery
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.lastReviewed = lastReviewed
    }

    enum CodingKeys: String, CodingKey {
        case id, chapterNumber, kanji, english, furigana, romaji
        case onyomi, kunyomi, strokeCount, level, words, examples
        case mastery, currentStreak, bestStreak, lastReviewed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.chapterNumber = try container.decodeIfPresent(Int.self, forKey: .chapterNumber) ?? 1
        self.kanji = try container.decode(String.self, forKey: .kanji)
        self.english = try container.decode(String.self, forKey: .english)
        self.furigana = try container.decodeIfPresent(String.self, forKey: .furigana) ?? ""
        self.romaji = try container.decodeIfPresent(String.self, forKey: .romaji) ?? ""
        self.onyomi = try container.decodeIfPresent([String].self, forKey: .onyomi) ?? []
        self.kunyomi = try container.decodeIfPresent([String].self, forKey: .kunyomi) ?? []
        self.strokeCount = try container.decodeIfPresent(Int.self, forKey: .strokeCount) ?? 1
        self.level = try container.decodeIfPresent(JLPTLevel.self, forKey: .level) ?? .n5
        self.words = try container.decodeIfPresent([KanjiWord].self, forKey: .words) ?? []
        self.examples = try container.decodeIfPresent([ExampleSentence].self, forKey: .examples) ?? []
        self.mastery = try container.decodeIfPresent(MasteryStatus.self, forKey: .mastery) ?? .unlearned
        self.currentStreak = try container.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        self.bestStreak = try container.decodeIfPresent(Int.self, forKey: .bestStreak) ?? 0
        self.lastReviewed = try container.decodeIfPresent(Date.self, forKey: .lastReviewed)
    }
}

struct KanjiChapterSheet: Identifiable, Codable, Equatable {
    var id: Int { chapterNumber }
    let chapterNumber: Int
    let title: String
    let englishTitle: String
    let kanjis: [KanjiItem]

    init(chapterNumber: Int, title: String, englishTitle: String, kanjis: [KanjiItem]) {
        self.chapterNumber = chapterNumber
        self.title = title
        self.englishTitle = englishTitle
        self.kanjis = kanjis
    }
}

enum KanjiTabMode: String, CaseIterable, Identifiable {
    case study = "Kanji Cards"
    case breakdown = "Chapters & Breakdown"
    case revision = "Revision"

    var id: String { rawValue }
}
