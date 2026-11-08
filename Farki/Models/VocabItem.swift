import SwiftUI

// MARK: - Textbook Definitions (Requirement 12)
enum TextbookType: String, CaseIterable, Identifiable, Codable {
    case minnaNoNihongo = "みんなの日本語"

    var id: String { rawValue }
    var displayName: String { "Minna no Nihongo" }
}

enum TextbookBook: Int, CaseIterable, Identifiable, Codable {
    case book1 = 1 // Minna no Nihongo Shokyū I, Chapters 1–25
    case book2 = 2 // Minna no Nihongo Shokyū II, Chapters 26–50

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .book1: return "初級 I (Book 1)"
        case .book2: return "初級 II (Book 2)"
        }
    }

    var fullTitle: String {
        switch self {
        case .book1: return "Minna no Nihongo Shokyū I (Chapters 1–25)"
        case .book2: return "Minna no Nihongo Shokyū II (Chapters 26–50)"
        }
    }

    var chapterRange: ClosedRange<Int> {
        switch self {
        case .book1: return 1...25
        case .book2: return 26...50
        }
    }

    var defaultJLPTLevel: JLPTLevel {
        switch self {
        case .book1: return .n5
        case .book2: return .n4
        }
    }

    static func book(forChapter chapter: Int) -> TextbookBook {
        return chapter <= 25 ? .book1 : .book2
    }
}

// MARK: - Learning State
enum VocabLearningState: String, CaseIterable, Identifiable, Codable {
    case unseen = "unseen"
    case knownDirectly = "knownDirectly"       // Tick mark: knew without seeing meaning
    case knownAfterReveal = "knownAfterReveal" // Read tick: knew after seeing meaning

    var id: String { rawValue }

    var label: String {
        switch self {
        case .unseen: return "未習 (Unseen)"
        case .knownDirectly: return "習得 (Known directly)"
        case .knownAfterReveal: return "復習 (Reviewed)"
        }
    }
}

// MARK: - Vocabulary Difficulty Level
enum VocabDifficulty: String, Codable, CaseIterable {
    case easy = "easy"       // 1 - Green
    case medium = "medium"   // 2 - Orange
    case hard = "hard"       // 3 - Red

    var label: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    var numericValue: Int {
        switch self {
        case .easy: return 1
        case .medium: return 2
        case .hard: return 3
        }
    }

    var color: Color {
        switch self {
        case .easy: return Color(hex: "#10B981")   // Green
        case .medium: return Color(hex: "#F59E0B") // Orange
        case .hard: return Color(hex: "#EF4444")   // Red
        }
    }

    static func from(string: String?) -> VocabDifficulty {
        guard let s = string?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else {
            return .easy
        }
        if s == "easy" || s == "1" || s == "green" || s == "初級" {
            return .easy
        } else if s == "medium" || s == "2" || s == "orange" || s == "中級" {
            return .medium
        } else if s == "hard" || s == "3" || s == "red" || s == "上級" {
            return .hard
        }
        return .easy
    }
}

// MARK: - Word Type
enum VocabWordType: Codable, Equatable {
    case verb(VerbGroup)
    case iAdjective
    case naAdjective
    case noun
    case other(String)

    var description: String {
        switch self {
        case .verb(let group):
            return "動詞 \(group.rawValue)"
        case .iAdjective:
            return "い形容詞"
        case .naAdjective:
            return "な形容詞"
        case .noun:
            return "名詞"
        case .other(let name):
            return name
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, group, otherName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "verb":
            let group = try container.decode(VerbGroup.self, forKey: .group)
            self = .verb(group)
        case "iAdjective":
            self = .iAdjective
        case "naAdjective":
            self = .naAdjective
        case "noun":
            self = .noun
        default:
            let otherName = try container.decodeIfPresent(String.self, forKey: .otherName) ?? "その他"
            self = .other(otherName)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .verb(let group):
            try container.encode("verb", forKey: .type)
            try container.encode(group, forKey: .group)
        case .iAdjective:
            try container.encode("iAdjective", forKey: .type)
        case .naAdjective:
            try container.encode("naAdjective", forKey: .type)
        case .noun:
            try container.encode("noun", forKey: .type)
        case .other(let name):
            try container.encode("other", forKey: .type)
            try container.encode(name, forKey: .otherName)
        }
    }
}

enum VerbGroup: String, Codable {
    case group1 = "Iグループ"
    case group2 = "IIグループ"
    case group3 = "IIIグループ"
}

// MARK: - Pure Vocab Item (Chapter-Based Vocabulary Architecture)
struct VocabItem: Identifiable, Codable, Equatable {
    let id: String                        // Stable unique ID, e.g. "mnn-b1-c06-tabemasu"
    var textbook: TextbookType            // e.g. .minnaNoNihongo
    var bookNumber: Int                   // 1 (Chapters 1–25) or 2 (Chapters 26–50)
    var chapterNumber: Int                // Chapter 1..50
    var number: Int                       // Position in chapter or session
    var japanese: String                  // e.g. "たべます"
    var kanji: String?                    // e.g. "食べます"
    var kana: String                      // e.g. "たべます"
    var romaji: String                    // e.g. "Tabemasu"
    var meaning: String                   // e.g. "to eat"
    var wordType: VocabWordType           // .verb(.group2), .iAdjective, .naAdjective, .noun
    var jlptLevel: JLPTLevel              // .n5 or .n4
    var categoryTag: String               // e.g. "ひらがな"
    var difficulty: VocabDifficulty = .easy // easy (green: know), medium (yellow: sometimes miss), hard (red: got wrong)
    var bestTimeSeconds: TimeInterval?    // Response time record
    var learningState: VocabLearningState = .unseen
    var currentStreak: Int = 0            // Current consecutive correct streak
    var bestStreak: Int = 0               // All-time highest streak of getting it right
    var examples: [ParticleExample] = []  // Example sentences (OpenJLPT / Tatoeba)

    /// Color of the square beside the active number:
    /// Red (#EF4444) = words I got wrong
    /// Yellow (#F59E0B) = sometimes I miss
    /// Green (#10B981) = the ones I know
    var reviewSquareColor: Color {
        switch difficulty {
        case .hard: return Color(hex: "#EF4444")   // Red: got wrong
        case .medium: return Color(hex: "#F59E0B") // Yellow: sometimes miss
        case .easy: return Color(hex: "#10B981")   // Green: ones I know
        }
    }

    mutating func cycleDifficulty() {
        switch difficulty {
        case .hard:
            difficulty = .medium
        case .medium:
            difficulty = .easy
            currentStreak = max(1, currentStreak)
            bestStreak = max(bestStreak, currentStreak)
        case .easy:
            difficulty = .hard
            currentStreak = 0
        }
    }

    /// Legacy reading accessor for compatibility
    var reading: String { kana }

    /// Truncated string for word strip (5-6 characters as specified in Section 3)
    var stripDisplay: String {
        if japanese.count > 6 {
            return String(japanese.prefix(5)) + "…"
        }
        return japanese
    }

    /// Formatted best time string "02:07"
    var bestTimeString: String {
        guard let seconds = bestTimeSeconds else { return "--:--" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    enum CodingKeys: String, CodingKey {
        case id, textbook, bookNumber, chapterNumber, number, japanese, kanji, kana, romaji, meaning, wordType, jlptLevel, categoryTag, difficulty, bestTimeSeconds, learningState, currentStreak, bestStreak, examples
    }

    init(
        id: String,
        textbook: TextbookType,
        bookNumber: Int,
        chapterNumber: Int,
        number: Int,
        japanese: String,
        kanji: String?,
        kana: String,
        romaji: String,
        meaning: String,
        wordType: VocabWordType,
        jlptLevel: JLPTLevel,
        categoryTag: String,
        difficulty: VocabDifficulty = .easy,
        bestTimeSeconds: TimeInterval? = nil,
        learningState: VocabLearningState = .unseen,
        currentStreak: Int = 0,
        bestStreak: Int = 0,
        examples: [ParticleExample] = []
    ) {
        self.id = id
        self.textbook = textbook
        self.bookNumber = bookNumber
        self.chapterNumber = chapterNumber
        self.number = number
        self.japanese = japanese
        self.kanji = kanji
        self.kana = kana
        self.romaji = romaji
        self.meaning = meaning
        self.wordType = wordType
        self.jlptLevel = jlptLevel
        self.categoryTag = categoryTag
        self.difficulty = difficulty
        self.bestTimeSeconds = bestTimeSeconds
        self.learningState = learningState
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.examples = examples
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.textbook = try container.decode(TextbookType.self, forKey: .textbook)
        self.bookNumber = try container.decode(Int.self, forKey: .bookNumber)
        self.chapterNumber = try container.decode(Int.self, forKey: .chapterNumber)
        self.number = try container.decode(Int.self, forKey: .number)
        self.japanese = try container.decode(String.self, forKey: .japanese)
        self.kanji = try container.decodeIfPresent(String.self, forKey: .kanji)
        self.kana = try container.decode(String.self, forKey: .kana)
        self.romaji = try container.decode(String.self, forKey: .romaji)
        self.meaning = try container.decode(String.self, forKey: .meaning)
        self.wordType = try container.decode(VocabWordType.self, forKey: .wordType)
        self.jlptLevel = try container.decode(JLPTLevel.self, forKey: .jlptLevel)
        self.categoryTag = try container.decode(String.self, forKey: .categoryTag)
        self.difficulty = try container.decodeIfPresent(VocabDifficulty.self, forKey: .difficulty) ?? .easy
        self.bestTimeSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .bestTimeSeconds)
        self.learningState = try container.decodeIfPresent(VocabLearningState.self, forKey: .learningState) ?? .unseen
        self.currentStreak = try container.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        self.bestStreak = try container.decodeIfPresent(Int.self, forKey: .bestStreak) ?? 0
        self.examples = try container.decodeIfPresent([ParticleExample].self, forKey: .examples) ?? []
    }
}
