import Foundation
import SwiftUI

// MARK: - Exam Navigation Destination
enum ExamScreenDestination: Equatable {
    case landing
    case fullLengthSetup
    case chapterWiseSetup
    case sectionWiseSetup
    case history
    case instructions(ExamPaper)
    case activeAttempt
    case results(String) // attemptId
}

// MARK: - Exam Kind (Section 7)
enum ExamKind: String, Codable, CaseIterable, Identifiable {
    case fullLength = "full_length"
    case section = "section"
    case chapter = "chapter"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullLength: return "Full-Length Exam"
        case .section: return "Section-Wise Practice"
        case .chapter: return "Chapter-Wise Test"
        }
    }
}

// MARK: - Exam Delivery Mode (Section 2 & Section 4)
enum ExamDeliveryMode: String, Codable, CaseIterable, Identifiable {
    case exam = "exam"         // Feedback hidden until submission
    case practice = "practice" // Immediate feedback after each answer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .exam: return "Exam Mode"
        case .practice: return "Practice Mode"
        }
    }

    var subtitle: String {
        switch self {
        case .exam: return "Correctness feedback hidden until submission"
        case .practice: return "Immediate feedback and explanation after each answer"
        }
    }
}

// MARK: - Question Category (Section 3, 4 & 7)
enum ExamQuestionCategory: String, Codable, CaseIterable, Identifiable {
    case vocabulary = "vocabulary"
    case kanji = "kanji"
    case grammar = "grammar"
    case reading = "reading"
    case listening = "listening"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vocabulary: return "Vocabulary"
        case .kanji: return "Kanji"
        case .grammar: return "Grammar"
        case .reading: return "Reading"
        case .listening: return "Listening"
        }
    }

    var japaneseTitle: String {
        switch self {
        case .vocabulary: return "文字・語彙 (語彙)"
        case .kanji: return "文字・語彙 (漢字)"
        case .grammar: return "言語知識 (文法)"
        case .reading: return "読解"
        case .listening: return "聴解"
        }
    }

    var iconName: String {
        switch self {
        case .vocabulary: return "character.book.closed"
        case .kanji: return "character.ja"
        case .grammar: return "text.book.closed"
        case .reading: return "doc.text.magnifyingglass"
        case .listening: return "headphones"
        }
    }

    /// Categories supported by Chapter-Wise Tests (Section 3: Vocabulary, Kanji, Grammar, or Mixed)
    static var chapterWiseCategories: [ExamQuestionCategory] {
        [.vocabulary, .kanji, .grammar]
    }
}

// MARK: - Exam Section Specification (JLPT Structure)
struct ExamSectionSpec: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let japaneseTitle: String
    let categories: [ExamQuestionCategory]
    let durationSeconds: Int
    let description: String
}

// MARK: - Paper Grouping Mode (By Type, Time, Difficulty, or Source)
enum ExamPaperGroupMode: String, CaseIterable, Identifiable {
    case type = "Type"
    case time = "Time"
    case difficulty = "Difficulty"
    case source = "Source"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .type: return "square.grid.2x2"
        case .time: return "clock"
        case .difficulty: return "chart.bar.fill"
        case .source: return "building.columns"
        }
    }
}

struct ExamPaperGroupSection: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let iconName: String
    let accentHex: String
    let papers: [ExamPaper]
}

// MARK: - Exam Paper (Section 7 Logical Model)
struct ExamPaper: Codable, Equatable, Identifiable {
    let id: String
    var title: String
    var level: JLPTLevel
    var kind: ExamKind
    var sourceTitle: String
    var sourceUrl: String?
    var license: String
    var attribution: String
    var dateChecked: String
    var sections: [ExamSectionSpec]
    var questionIds: [String]
    var durationSeconds: Int? // nil when untimed

    var formattedDuration: String {
        guard let secs = durationSeconds, secs > 0 else { return "Untimed" }
        let mins = secs / 60
        return "\(mins) min"
    }

    var allCategories: [ExamQuestionCategory] {
        var seen = Set<ExamQuestionCategory>()
        var result: [ExamQuestionCategory] = []
        for cat in sections.flatMap(\.categories) {
            if seen.insert(cat).inserted {
                result.append(cat)
            }
        }
        return result
    }

    /// Type / Skill classification (Listening, Reading, Grammar, Vocabulary, Kanji, Chapter Block, Single Chapter, Full-Length)
    var primaryTypeLabel: String {
        switch kind {
        case .fullLength:
            return "Full-Length Mock Exam (All 3 Sections)"
        case .chapter:
            if id.hasPrefix("chapter-paper-ch-") {
                return level == .n4
                    ? "JLPT N4 • Single-Chapter Tests (Chapters 26–50)"
                    : "JLPT N5 • Single-Chapter Tests (Chapters 1–25)"
            }
            return "5-Chapter Block Exams (Chapters 1–50)"
        case .section:
            let cats = allCategories
            if cats.count == 1, let only = cats.first {
                switch only {
                case .listening: return "Listening Comprehension (聴解 • Choukai)"
                case .reading: return "Reading Comprehension (読解 • Dokkai)"
                case .grammar: return "Grammar (言語知識 • Bunpou)"
                case .vocabulary: return "Vocabulary (語彙 • Goi)"
                case .kanji: return "Kanji & Orthography (文字 • Moji)"
                }
            }
            return "Section Practice (\(cats.map(\.displayName).joined(separator: " • ")))"
        }
    }

    var shortTypeBadge: String {
        switch kind {
        case .fullLength:
            return "Full-Length (3 Sections)"
        case .chapter:
            return id.hasPrefix("chapter-paper-ch-") ? "Single Chapter (\(level.rawValue))" : "5-Chapter Block (\(level.rawValue))"
        case .section:
            if let first = allCategories.first {
                return "\(first.displayName) (\(first.japaneseTitle))"
            }
            return "Section Paper"
        }
    }

    var primaryTypeIcon: String {
        switch kind {
        case .fullLength:
            return "doc.text.fill"
        case .chapter:
            return "book.closed.fill"
        case .section:
            return allCategories.first?.iconName ?? "square.stack.3d.up.fill"
        }
    }

    /// Time / Duration bucket classification
    var durationBucketLabel: String {
        guard let secs = durationSeconds, secs > 0 else {
            return "Untimed Practice"
        }
        let mins = secs / 60
        if mins <= 15 {
            return "Quick Papers (≤ 15 min)"
        } else if mins <= 25 {
            return "Standard Papers (16–25 min)"
        } else if mins <= 45 {
            return "Extended Papers (26–45 min)"
        } else {
            return "Full Mock Duration (90–115 min)"
        }
    }

    /// Difficulty classification based on JLPT level, question volume, and section complexity
    var difficultyGroupLabel: String {
        let qCount = questionIds.count
        let cats = Set(allCategories)
        if level == .n5 {
            if kind == .fullLength {
                return "Level 2 • JLPT N5 Full Exam Simulation (60–69 Qs)"
            } else if cats.contains(.reading) || cats.contains(.listening) || qCount >= 25 {
                return "Level 2 • JLPT N5 Applied (Reading / Listening / Multi-Chapter)"
            } else {
                return "Level 1 • JLPT N5 Foundation (Core Vocab / Kanji / Grammar)"
            }
        } else {
            if kind == .fullLength {
                return "Level 4 • JLPT N4 Full Exam Simulation (55 Qs)"
            } else if cats.contains(.reading) || cats.contains(.listening) || qCount >= 25 {
                return "Level 4 • JLPT N4 Advanced (Reading / Listening / Multi-Chapter)"
            } else {
                return "Level 3 • JLPT N4 Intermediate (Core Vocab / Kanji / Grammar)"
            }
        }
    }

    var difficultyShortBadge: String {
        let cats = Set(allCategories)
        if level == .n5 {
            if kind == .fullLength { return "N5 • Full Mock" }
            if cats.contains(.reading) || cats.contains(.listening) { return "N5 • Applied" }
            return "N5 • Foundation"
        } else {
            if kind == .fullLength { return "N4 • Full Mock" }
            if cats.contains(.reading) || cats.contains(.listening) { return "N4 • Advanced" }
            return "N4 • Intermediate"
        }
    }

    var difficultyHexColor: String {
        if level == .n5 {
            return kind == .fullLength ? "#3B82F6" : "#10B981"
        } else {
            return kind == .fullLength ? "#EF4444" : "#F59E0B"
        }
    }

    /// Source repository classification
    var sourceGroupLabel: String {
        let lower = sourceTitle.lowercased()
        if lower.contains("jlptsuccess") && lower.contains("openjlpt") {
            return "JLPTSuccess + OpenJLPT Combined (MIT / CC-BY-SA-4.0)"
        } else if lower.contains("jlptsuccess") {
            return "JLPTSuccess Open Paper Bank (MIT)"
        } else if lower.contains("openjlpt") {
            return "OpenJLPT + Tatoeba Dataset (CC-BY-SA-4.0)"
        } else {
            return "nihon In-App Curated JLPT Bank"
        }
    }

    var shortSourceBadge: String {
        let lower = sourceTitle.lowercased()
        if lower.contains("jlptsuccess") && lower.contains("openjlpt") {
            return "JLPTSuccess + OpenJLPT"
        } else if lower.contains("jlptsuccess") {
            return "JLPTSuccess (MIT)"
        } else if lower.contains("openjlpt") {
            return "OpenJLPT (CC-BY-SA)"
        } else {
            return "In-App Bank"
        }
    }
}

// MARK: - Verified Internal Exam Question (Section 6 & 7)
struct ExamQuestion: Codable, Equatable, Identifiable {
    let id: String
    var reference: LearningItemReference? // Links back to Vocabulary/Grammar/Particles for SRS & progress reuse
    var level: JLPTLevel
    var category: ExamQuestionCategory
    var sectionId: String
    var passageGroupId: String? // Keeps passage-based & dependent questions together (Section 3)
    var passageText: String?
    var prompt: String
    var context: String?
    var audioScript: String?    // Spoken via SpeechService for Listening items
    var imageAsset: String?
    var choices: [String]
    var correctAnswer: String   // Verified answer key (never exposed in active Exam mode before submission)
    var explanation: String
    var chapterIds: [Int]       // Tagged Minna no Nihongo chapters when known
    var sourceTitle: String
    var sourceUrl: String?
    var license: String
    var attribution: String
    var dateChecked: String

    func toPublicQuestion() -> ExamPublicQuestion {
        ExamPublicQuestion(
            id: id,
            reference: reference,
            level: level,
            category: category,
            sectionId: sectionId,
            passageGroupId: passageGroupId,
            passageText: passageText,
            prompt: prompt,
            context: context,
            audioScript: audioScript,
            imageAsset: imageAsset,
            choices: choices,
            chapterIds: chapterIds,
            sourceTitle: sourceTitle,
            sourceUrl: sourceUrl,
            license: license,
            attribution: attribution,
            dateChecked: dateChecked
        )
    }
}

// MARK: - Public Question Payload (Excludes Correct Answer & Explanation Before Submission)
struct ExamPublicQuestion: Codable, Equatable, Identifiable {
    let id: String
    let reference: LearningItemReference?
    let level: JLPTLevel
    let category: ExamQuestionCategory
    let sectionId: String
    let passageGroupId: String?
    let passageText: String?
    let prompt: String
    let context: String?
    let audioScript: String?
    let imageAsset: String?
    let choices: [String]
    let chapterIds: [Int]
    let sourceTitle: String
    let sourceUrl: String?
    let license: String
    let attribution: String
    let dateChecked: String
}

// MARK: - Attempt Status (Section 7)
enum ExamAttemptStatus: String, Codable, Equatable {
    case inProgress = "in_progress"
    case submitted = "submitted"
    case timedOut = "timed_out"

    var displayLabel: String {
        switch self {
        case .inProgress: return "In Progress"
        case .submitted: return "Submitted"
        case .timedOut: return "Time Expired (Auto-Submitted)"
        }
    }
}

// MARK: - Section Breakdown Result (Section 7 & 8)
struct ExamSectionResult: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let category: ExamQuestionCategory?
    let totalQuestions: Int
    let correctCount: Int
    let incorrectCount: Int
    let unansweredCount: Int

    var scorePercentage: Int {
        guard totalQuestions > 0 else { return 0 }
        return Int(round((Double(correctCount) / Double(totalQuestions)) * 100.0))
    }
}

// MARK: - Post-Submission Question Review Item (Section 8)
struct ExamQuestionReviewItem: Codable, Equatable, Identifiable {
    var id: String { questionId }
    let questionId: String
    let reference: LearningItemReference?
    let category: ExamQuestionCategory
    let sectionId: String
    let prompt: String
    let context: String?
    let passageText: String?
    let audioScript: String?
    let choices: [String]
    let selectedAnswer: String?
    let correctAnswer: String
    let isCorrect: Bool
    let isUnanswered: Bool
    let isFlagged: Bool
    let explanation: String
    let chapterIds: [Int]
    let sourceTitle: String
    let sourceUrl: String?
    let license: String
    let attribution: String
}

// MARK: - Persisted Exam Attempt (Section 7 & 8)
struct ExamAttempt: Codable, Equatable, Identifiable {
    let id: String
    let examId: String
    let examTitle: String
    let kind: ExamKind
    let level: JLPTLevel
    let deliveryMode: ExamDeliveryMode
    let isTimed: Bool
    let durationLimitSeconds: Int?
    let selectedChapters: [Int]
    let selectedCategories: [ExamQuestionCategory]
    let sections: [ExamSectionSpec]
    let questions: [ExamPublicQuestion]
    let startedAt: Date
    var submittedAt: Date?
    var currentQuestionIndex: Int
    var selectedAnswers: [String: String]     // questionId -> chosen option
    var flaggedQuestionIds: Set<String>       // flagged for review
    var practiceFeedbackByQuestionId: [String: ExamQuestionReviewItem] // only populated in Practice Mode
    var status: ExamAttemptStatus
    var elapsedSeconds: Int
    var score: Int
    var totalQuestions: Int
    var correctCount: Int
    var incorrectCount: Int
    var unansweredCount: Int
    var sectionResults: [ExamSectionResult]
    var reviewItems: [ExamQuestionReviewItem] // populated only after submission

    var scorePercentage: Int {
        guard totalQuestions > 0 else { return 0 }
        return Int(round((Double(correctCount) / Double(totalQuestions)) * 100.0))
    }

    var remainingSeconds: Int? {
        guard isTimed, let limit = durationLimitSeconds else { return nil }
        return max(0, limit - elapsedSeconds)
    }

    var answeredCount: Int {
        questions.filter { q in
            if let ans = selectedAnswers[q.id], !ans.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
            return false
        }.count
    }
}

// MARK: - Curated External Reference Link (Section 6 Licensing Compliance)
struct ExamExternalResource: Identifiable, Equatable {
    let id: String
    let title: String
    let levelLabel: String
    let urlString: String
    let licenseNote: String
    let attribution: String
    let dateChecked: String
}

// MARK: - Bundled Exam Bank Root JSON Schema
struct ExamBankDatabase: Codable, Equatable {
    let schemaVersion: Int
    var papers: [ExamPaper]
    var questions: [ExamQuestion]
}

