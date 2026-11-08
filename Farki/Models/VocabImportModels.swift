import Foundation

// MARK: - Chapter Vocabulary Sheet (Requirement 12 Import Schema)
struct ChapterVocabSheet: Codable {
    let textbook: String                     // e.g. "Minna no Nihongo" or "みんなの日本語"
    let bookNumber: Int                      // 1 or 2
    let chapterNumber: Int                   // 1–50
    let title: String?                       // e.g. "第6課"
    let entries: [ChapterVocabEntryImport]
}

// MARK: - Pure Chapter Vocabulary Entry Import (Without Grammar Forms)
struct ChapterVocabEntryImport: Codable {
    let id: String?                          // Stable unique ID (auto-generated if omitted)
    let number: Int?                         // Sequence in chapter
    let japanese: String                     // e.g. "たべます" or "食べます"
    let kanji: String?                       // Kanji writing if applicable
    let kana: String?                        // Kana reading
    let romaji: String                       // Romaji
    let meaning: String                      // English definition
    let partOfSpeech: String                 // "verb_group1", "verb_group2", "verb_group3", "i_adjective", "na_adjective", "noun", "other"
    let jlptLevel: String?                   // "N5" or "N4"
    let categoryTag: String?                 // e.g. "ひらがな"
    let difficulty: String?                  // "easy" (1/green), "medium" (2/orange), "hard" (3/red)
    let examples: [ParticleExample]?         // Optional Tatoeba / OpenJLPT example sentences
}

// MARK: - Validation Result & Errors (Requirement 12)
struct VocabImportValidationResult {
    let isValid: Bool
    let chapterNumber: Int
    let bookNumber: Int
    let importedCount: Int
    let updatedCount: Int
    let errors: [VocabImportError]
    let warnings: [String]
}

enum VocabImportError: LocalizedError, Equatable {
    case invalidBookNumber(Int)
    case invalidChapterNumber(Int)
    case chapterBookMismatch(chapter: Int, book: Int)
    case emptyEntries
    case missingRequiredField(field: String, entryIndex: Int)
    case invalidPartOfSpeech(value: String, entryIndex: Int)
    case invalidJLPTLevel(value: String, entryIndex: Int)
    case parsingFailure(String)

    var errorDescription: String? {
        switch self {
        case .invalidBookNumber(let book):
            return "Invalid book number: \(book). Must be 1 (Shokyū I) or 2 (Shokyū II)."
        case .invalidChapterNumber(let chapter):
            return "Invalid chapter number: \(chapter). Must be between 1 and 50."
        case .chapterBookMismatch(let chapter, let book):
            return "Chapter \(chapter) does not belong to Book \(book) (Book 1: Chapters 1–25, Book 2: Chapters 26–50)."
        case .emptyEntries:
            return "Vocabulary sheet contains zero entries."
        case .missingRequiredField(let field, let entryIndex):
            return "Entry #\(entryIndex + 1) is missing required field: '\(field)'."
        case .invalidPartOfSpeech(let value, let entryIndex):
            return "Entry #\(entryIndex + 1) has invalid part of speech: '\(value)'."
        case .invalidJLPTLevel(let value, let entryIndex):
            return "Entry #\(entryIndex + 1) has invalid JLPT level: '\(value)'. Only N5 or N4 allowed."
        case .parsingFailure(let details):
            return "Failed to parse vocabulary sheet: \(details)"
        }
    }
}

// MARK: - Vocabulary Section / Word Category
enum VocabSectionCategory: String, CaseIterable, Identifiable, Hashable {
    case nouns = "nouns"
    case verbsGroup1 = "verbs_g1"
    case verbsGroup2 = "verbs_g2"
    case verbsGroup3 = "verbs_g3"
    case iAdjectives = "i_adj"
    case naAdjectives = "na_adj"
    case expressions = "expressions"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nouns: return "Nouns (名詞)"
        case .verbsGroup1: return "Verbs I (五段)"
        case .verbsGroup2: return "Verbs II (一段)"
        case .verbsGroup3: return "Verbs III (する・くる)"
        case .iAdjectives: return "い-Adjectives"
        case .naAdjectives: return "な-Adjectives"
        case .expressions: return "Expressions & Other"
        }
    }

    func matches(_ wordType: VocabWordType) -> Bool {
        switch (self, wordType) {
        case (.nouns, .noun):
            return true
        case (.verbsGroup1, .verb(.group1)):
            return true
        case (.verbsGroup2, .verb(.group2)):
            return true
        case (.verbsGroup3, .verb(.group3)):
            return true
        case (.iAdjectives, .iAdjective):
            return true
        case (.naAdjectives, .naAdjective):
            return true
        case (.expressions, .other):
            return true
        default:
            return false
        }
    }
}

// MARK: - Chapter & Section Filter Model
struct VocabFilter: Equatable {
    var textbook: TextbookType? = .minnaNoNihongo
    var selectedBook: TextbookBook? = nil
    var selectedChapter: Int? = nil
    var selectedChapters: Set<Int> = []
    var selectedSectionCategories: Set<VocabSectionCategory> = []
    var selectedJLPTLevel: JLPTLevel? = nil
    var selectedLearningStatus: VocabLearningState? = nil
    var troubleWordsOnly: Bool = false

    var isFiltering: Bool {
        selectedBook != nil
            || selectedChapter != nil
            || !selectedChapters.isEmpty
            || !selectedSectionCategories.isEmpty
            || selectedJLPTLevel != nil
            || selectedLearningStatus != nil
            || troubleWordsOnly
    }

    var summaryText: String {
        var parts: [String] = []
        if let book = selectedBook {
            parts.append(book.title)
        }
        if !selectedChapters.isEmpty {
            let sorted = selectedChapters.sorted()
            if sorted.count == 1, let only = sorted.first {
                parts.append("Ch. \(only)")
            } else if sorted == Array(1...25) {
                parts.append("Ch. 1–25 (N5)")
            } else if sorted == Array(26...50) {
                parts.append("Ch. 26–50 (N4)")
            } else if sorted.count <= 4 {
                parts.append(sorted.map { "Ch. \($0)" }.joined(separator: ", "))
            } else {
                parts.append("\(sorted.count) Chapters")
            }
        } else if let chapter = selectedChapter {
            parts.append("Ch. \(chapter)")
        }
        if !selectedSectionCategories.isEmpty {
            if selectedSectionCategories.count == 1, let first = selectedSectionCategories.first {
                parts.append(first.title)
            } else {
                parts.append("\(selectedSectionCategories.count) Sections")
            }
        }
        if let jlpt = selectedJLPTLevel {
            parts.append(jlpt.shortLabel)
        }
        if let status = selectedLearningStatus {
            parts.append(status.label)
        }
        if troubleWordsOnly {
            parts.append("Trouble Words")
        }
        return parts.isEmpty ? "All Chapters (1–50)" : parts.joined(separator: " • ")
    }
}
