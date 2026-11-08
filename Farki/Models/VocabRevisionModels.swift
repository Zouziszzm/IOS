import SwiftUI

// MARK: - Revision Direction (Mode A & Mode B)
enum VocabRevisionDirection: String, CaseIterable, Identifiable, Codable {
    case japaneseToEnglish = "jp_to_en"
    case englishToJapanese = "en_to_jp"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .japaneseToEnglish: return "日本語 → English"
        case .englishToJapanese: return "English → 日本語"
        }
    }

    var shortTitle: String {
        switch self {
        case .japaneseToEnglish: return "JP → EN"
        case .englishToJapanese: return "EN → JP"
        }
    }

    var promptText: String {
        switch self {
        case .japaneseToEnglish: return "Recall & write the English meaning on paper"
        case .englishToJapanese: return "Recall & write the Japanese vocabulary on paper"
        }
    }
}

// MARK: - Word Revision Record
struct VocabRevisionRecord: Identifiable, Codable, Equatable {
    var id: String { wordId }
    let wordId: String
    let chapterNumber: Int
    var lastRevisedAt: Date
    var correctCount: Int
    var incorrectCount: Int
    var isLastAnswerCorrect: Bool

    init(
        wordId: String,
        chapterNumber: Int,
        lastRevisedAt: Date = Date(),
        correctCount: Int = 0,
        incorrectCount: Int = 0,
        isLastAnswerCorrect: Bool = false
    ) {
        self.wordId = wordId
        self.chapterNumber = chapterNumber
        self.lastRevisedAt = lastRevisedAt
        self.correctCount = correctCount
        self.incorrectCount = incorrectCount
        self.isLastAnswerCorrect = isLastAnswerCorrect
    }
}

// MARK: - Chapter Progress State for Dashboard
enum ChapterProgressState: String, Codable {
    case inProgress           // State 1: Vocabulary being studied
    case vocabularyCompleted  // State 2: 100% vocabulary completed, ready for revision (Blue)
    case fullyRevised         // State 3: 100% vocabulary revised and explicitly correct (Green)

    var title: String {
        switch self {
        case .inProgress: return "In Progress"
        case .vocabularyCompleted: return "Vocabulary Completed"
        case .fullyRevised: return "Fully Revised"
        }
    }

    var colorHex: String {
        switch self {
        case .inProgress: return "#F59E0B" // Amber
        case .vocabularyCompleted: return "#3B82F6" // Blue
        case .fullyRevised: return "#10B981" // Green
        }
    }
}

// MARK: - Chapter Progress Summary
struct ChapterProgressSummary: Identifiable, Equatable {
    var id: Int { chapterNumber }
    let chapterNumber: Int
    let totalWords: Int
    let studiedWords: Int
    let revisedWords: Int
    let correctlyRevisedWords: Int
    let incorrectWordsCount: Int
    let lastRevisionDate: Date?

    init(
        chapterNumber: Int,
        totalWords: Int,
        studiedWords: Int,
        revisedWords: Int,
        correctlyRevisedWords: Int,
        incorrectWordsCount: Int,
        lastRevisionDate: Date?
    ) {
        self.chapterNumber = chapterNumber
        self.totalWords = totalWords
        self.studiedWords = studiedWords
        self.revisedWords = revisedWords
        self.correctlyRevisedWords = correctlyRevisedWords
        self.incorrectWordsCount = incorrectWordsCount
        self.lastRevisionDate = lastRevisionDate
    }

    var vocabProgress: Double {
        totalWords > 0 ? (Double(studiedWords) / Double(totalWords)) : 0.0
    }

    var vocabPercentage: Int {
        totalWords > 0 ? min(100, Int(round(vocabProgress * 100))) : 0
    }

    var revisionProgress: Double {
        totalWords > 0 ? (Double(correctlyRevisedWords) / Double(totalWords)) : 0.0
    }

    var revisionPercentage: Int {
        totalWords > 0 ? min(100, Int(round(revisionProgress * 100))) : 0
    }

    var state: ChapterProgressState {
        if totalWords > 0 && correctlyRevisedWords >= totalWords {
            return .fullyRevised
        } else if totalWords > 0 && studiedWords >= totalWords {
            return .vocabularyCompleted
        } else {
            return .inProgress
        }
    }

    var statusDescription: String {
        switch state {
        case .fullyRevised:
            return "Fully Revised • Completed"
        case .vocabularyCompleted:
            return "Vocabulary Completed • Ready for Revision"
        case .inProgress:
            return "In Progress • \(studiedWords)/\(totalWords) words studied"
        }
    }
}

// MARK: - Global Revision Metrics
struct GlobalRevisionMetrics {
    let totalWordsRevised: Int
    let correctAnswers: Int
    let incorrectAnswers: Int
    var totalAnswers: Int { correctAnswers + incorrectAnswers }
    var accuracyPercentage: Int {
        totalAnswers > 0 ? Int(round((Double(correctAnswers) / Double(totalAnswers)) * 100)) : 0
    }
    let completedChaptersCount: Int

    init(
        totalWordsRevised: Int,
        correctAnswers: Int,
        incorrectAnswers: Int,
        completedChaptersCount: Int
    ) {
        self.totalWordsRevised = totalWordsRevised
        self.correctAnswers = correctAnswers
        self.incorrectAnswers = incorrectAnswers
        self.completedChaptersCount = completedChaptersCount
    }
}

// MARK: - Vocabulary Test Session Models (Requirement 2 & 3)
struct VocabTestSubmittedAnswer: Codable, Equatable {
    let wordId: String
    let rating: String
    let isCorrect: Bool
    let responseTimeSeconds: TimeInterval
    let answeredAt: Date
}

enum VocabTestSessionStatus: String, Codable {
    case inProgress
    case paused
    case completed
    case stopped
}

struct VocabTestSession: Codable, Identifiable {
    let id: String
    let scopeTitle: String
    let startedAt: Date
    var pausedAt: Date?
    var accumulatedDurationSeconds: Int
    var questionIds: [String]
    var currentIndex: Int
    var isMeaningRevealed: Bool
    var submittedAnswers: [VocabTestSubmittedAnswer]
    var correctCount: Int
    var wrongCount: Int
    var status: VocabTestSessionStatus

    var totalQuestions: Int {
        questionIds.count
    }

    var isCompleted: Bool {
        status == .completed || (totalQuestions > 0 && currentIndex >= totalQuestions)
    }
}
