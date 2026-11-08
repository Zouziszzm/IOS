import Foundation
import SwiftUI

// MARK: - Learning Domain (Section 3 & Section 4 Specification)
public enum LearningDomain: String, Codable, CaseIterable, Identifiable {
    case vocabulary = "vocabulary"
    case grammar = "grammar"
    case particles = "particles"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .vocabulary: return "Vocabulary"
        case .grammar: return "Grammar"
        case .particles: return "Particles"
        }
    }
}

// MARK: - Domain-Aware Item & Review Reference (Section 3 & Section 4)
public struct LearningItemReference: Codable, Equatable, Hashable, Identifiable {
    public let domain: LearningDomain
    public let contentId: String
    public var subContentId: String?

    public var id: String { reviewIdentityKey }

    public init(domain: LearningDomain, contentId: String, subContentId: String? = nil) {
        self.domain = domain
        self.contentId = contentId
        if let sub = subContentId, !sub.isEmpty {
            self.subContentId = sub
        } else {
            self.subContentId = nil
        }
    }

    /// Canonical review identity:
    /// - Vocabulary preserves its exact existing entryId so all existing Vocabulary SRS records remain untouched.
    /// - Grammar uses "grammar/<contentId>" or "grammar/<contentId>/<subContentId>".
    /// - Particles uses "particles/<contentId>/<subContentId>" (or "particles/<contentId>").
    public var reviewIdentityKey: String {
        switch domain {
        case .vocabulary:
            if let sub = subContentId, !sub.isEmpty {
                return "\(contentId)/\(sub)"
            }
            return contentId
        case .grammar:
            if let sub = subContentId, !sub.isEmpty {
                return "grammar/\(contentId)/\(sub)"
            }
            return "grammar/\(contentId)"
        case .particles:
            if let sub = subContentId, !sub.isEmpty {
                return "particles/\(contentId)/\(sub)"
            }
            return "particles/\(contentId)"
        }
    }

    /// Card ID for SRSQueueBuilder with direction suffix
    public func srsCardId(direction: CardDirection = .jpToMeaning) -> String {
        return CardDirection.cardId(entryId: reviewIdentityKey, direction: direction)
    }

    /// Parses a review identity key or SRS cardId back into a LearningItemReference
    public static func parse(from rawCardOrIdentityKey: String) -> LearningItemReference {
        let entryKey = CardDirection.parse(cardId: rawCardOrIdentityKey)?.entryId ?? rawCardOrIdentityKey

        if entryKey.hasPrefix("particles/") {
            let parts = entryKey.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
            if parts.count >= 3 {
                return LearningItemReference(domain: .particles, contentId: parts[1], subContentId: parts[2])
            } else if parts.count == 2 {
                return LearningItemReference(domain: .particles, contentId: parts[1], subContentId: nil)
            }
        } else if entryKey.hasPrefix("grammar/") {
            let parts = entryKey.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
            if parts.count >= 3 {
                return LearningItemReference(domain: .grammar, contentId: parts[1], subContentId: parts[2])
            } else if parts.count == 2 {
                return LearningItemReference(domain: .grammar, contentId: parts[1], subContentId: nil)
            }
        }
        return LearningItemReference(domain: .vocabulary, contentId: entryKey, subContentId: nil)
    }
}

public typealias LearningReviewReference = LearningItemReference

// MARK: - Separate Progress Record (Decoupled from Static Grammar & Particle Content)
struct LearningItemProgress: Codable, Equatable {
    let identityKey: String
    var learningState: VocabLearningState
    var difficulty: VocabDifficulty
    var bestTimeSeconds: TimeInterval?
    var currentStreak: Int
    var bestStreak: Int

    init(
        identityKey: String,
        learningState: VocabLearningState = .unseen,
        difficulty: VocabDifficulty = .easy,
        bestTimeSeconds: TimeInterval? = nil,
        currentStreak: Int = 0,
        bestStreak: Int = 0
    ) {
        self.identityKey = identityKey
        self.learningState = learningState
        self.difficulty = difficulty
        self.bestTimeSeconds = bestTimeSeconds
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
    }

    var reviewSquareColor: Color {
        switch difficulty {
        case .hard: return Color(hex: "#EF4444")   // Red: got wrong
        case .medium: return Color(hex: "#F59E0B") // Orange: sometimes miss
        case .easy: return Color(hex: "#10B981")   // Green: know well
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
}

// MARK: - Learning Test Scope (Section 3 Specification)
struct LearningTestScope: Codable, Equatable {
    var domains: [LearningDomain]
    var jlptLevels: [JLPTLevel]
    var chapterIds: [String]
    var particleIds: [String]
    var particleUsageIds: [String]
    var grammarPointIds: [String]
    var questionCount: Int
    var mistakesOnly: Bool

    init(
        domains: [LearningDomain] = [.vocabulary],
        jlptLevels: [JLPTLevel] = [],
        chapterIds: [String] = [],
        particleIds: [String] = [],
        particleUsageIds: [String] = [],
        grammarPointIds: [String] = [],
        questionCount: Int = 0,
        mistakesOnly: Bool = false
    ) {
        self.domains = domains
        self.jlptLevels = jlptLevels
        self.chapterIds = chapterIds
        self.particleIds = particleIds
        self.particleUsageIds = particleUsageIds
        self.grammarPointIds = grammarPointIds
        self.questionCount = questionCount
        self.mistakesOnly = mistakesOnly
    }
}

// MARK: - Question Types (Section 3 Specification)
enum LearningQuestionType: String, Codable, CaseIterable {
    case vocabularyMeaning = "vocabulary_meaning"
    case grammarPatternMeaning = "grammar_pattern_meaning"
    case grammarContextChoice = "grammar_context_choice"
    case particleFillBlank = "particle_fill_blank"
    case particleMeaningMatch = "particle_meaning_match"
    case particleDistinguishContext = "particle_distinguish_context"

    var label: String {
        switch self {
        case .vocabularyMeaning: return "Vocabulary Meaning"
        case .grammarPatternMeaning: return "Grammar Pattern & Meaning"
        case .grammarContextChoice: return "Grammar Form in Context"
        case .particleFillBlank: return "Fill in the Particle"
        case .particleMeaningMatch: return "Match Particle Usage"
        case .particleDistinguishContext: return "Particle Context Distinction"
        }
    }
}

// MARK: - Public Question Payload (Excludes Answer Key Before Submission)
struct LearningPublicQuestion: Codable, Equatable, Identifiable {
    let id: String
    let sessionId: String
    let reference: LearningItemReference
    let questionType: LearningQuestionType
    let prompt: String
    let subtitle: String?
    let contextSentence: String?
    let romajiHint: String?
    let options: [String]
    let jlptLevel: JLPTLevel?
    let categoryLabel: String

    init(
        id: String,
        sessionId: String,
        reference: LearningItemReference,
        questionType: LearningQuestionType,
        prompt: String,
        subtitle: String? = nil,
        contextSentence: String? = nil,
        romajiHint: String? = nil,
        options: [String] = [],
        jlptLevel: JLPTLevel? = nil,
        categoryLabel: String = ""
    ) {
        self.id = id
        self.sessionId = sessionId
        self.reference = reference
        self.questionType = questionType
        self.prompt = prompt
        self.subtitle = subtitle
        self.contextSentence = contextSentence
        self.romajiHint = romajiHint
        self.options = options
        self.jlptLevel = jlptLevel
        self.categoryLabel = categoryLabel
    }
}

// MARK: - Traceable Test Answer Record (Section 3 & Section 5)
struct LearningTestAnswerRecord: Codable, Equatable, Identifiable {
    let id: String
    let sessionId: String
    let questionId: String
    let reference: LearningItemReference
    let questionType: LearningQuestionType
    let submittedAnswer: String
    let rating: SRSRating
    let isCorrect: Bool
    let isSkipped: Bool
    let correctAnswer: String
    let explanation: String
    let durationMs: Int
    let timestamp: Date

    init(
        id: String = UUID().uuidString,
        sessionId: String,
        questionId: String,
        reference: LearningItemReference,
        questionType: LearningQuestionType,
        submittedAnswer: String,
        rating: SRSRating,
        isCorrect: Bool,
        isSkipped: Bool = false,
        correctAnswer: String,
        explanation: String,
        durationMs: Int,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.questionId = questionId
        self.reference = reference
        self.questionType = questionType
        self.submittedAnswer = submittedAnswer
        self.rating = rating
        self.isCorrect = isCorrect
        self.isSkipped = isSkipped
        self.correctAnswer = correctAnswer
        self.explanation = explanation
        self.durationMs = durationMs
        self.timestamp = timestamp
    }
}

// MARK: - Test Session Results Summary
struct LearningTestSessionResult: Codable, Equatable, Identifiable {
    var id: String { sessionId }
    let sessionId: String
    let scope: LearningTestScope
    let totalQuestions: Int
    let answeredCount: Int
    let correctCount: Int
    let wrongCount: Int
    let skippedCount: Int
    let answers: [LearningTestAnswerRecord]
    let startedAt: Date
    let completedAt: Date?

    var scorePercentage: Int {
        guard totalQuestions > 0 else { return 0 }
        return Int(round((Double(correctCount) / Double(totalQuestions)) * 100.0))
    }

    var missedReferences: [LearningItemReference] {
        answers.filter { !$0.isCorrect }.map { $0.reference }
    }
}

// MARK: - Resolved Learning Content (Unified Resolver Output for Vocab, Grammar, Particles)
struct ResolvedLearningItem: Equatable, Identifiable {
    var id: String { reference.reviewIdentityKey }
    let reference: LearningItemReference
    let sequenceNumber: Int
    let chapterNumber: Int
    let promptJapanese: String
    let promptKana: String
    let promptRomaji: String
    let meaning: String
    let explanation: String
    let pattern: String?
    let categoryTag: String
    let jlptLevel: JLPTLevel?
    let examples: [ParticleExample]
    let relatedGrammarPointIds: [String]
    let sourceNumber: Int?
    let originalMeaning: String?
    var progress: LearningItemProgress

    /// Compatibility accessor for SRSQueueBuilder / SRSViews
    func toSyntheticVocabItem() -> VocabItem {
        return VocabItem(
            id: reference.reviewIdentityKey,
            textbook: .minnaNoNihongo,
            bookNumber: chapterNumber <= 25 ? 1 : 2,
            chapterNumber: max(1, chapterNumber),
            number: sequenceNumber,
            japanese: promptJapanese,
            kanji: pattern ?? promptJapanese,
            kana: promptKana,
            romaji: promptRomaji,
            meaning: meaning,
            wordType: .other(reference.domain.displayName),
            jlptLevel: jlptLevel ?? .n5,
            categoryTag: categoryTag,
            difficulty: progress.difficulty,
            bestTimeSeconds: progress.bestTimeSeconds,
            learningState: progress.learningState,
            currentStreak: progress.currentStreak,
            bestStreak: progress.bestStreak
        )
    }
}
