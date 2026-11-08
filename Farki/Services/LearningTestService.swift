import Foundation

/// Manages domain-aware test sessions across Vocabulary, Grammar, and Particles,
/// reusing the authoritative Vocabulary scoring and SRS mistake-scheduling flow.
final class LearningTestService {
    static let shared = LearningTestService()

    private struct PrivateAnswerKey {
        let questionId: String
        let reference: LearningItemReference
        let questionType: LearningQuestionType
        let correctAnswer: String
        let acceptableAnswers: Set<String>
        let explanation: String
    }

    private struct ActiveSessionState {
        let sessionId: String
        let scope: LearningTestScope
        let startedAt: Date
        var completedAt: Date?
        let questions: [LearningPublicQuestion]
        let answerKeysByQuestionId: [String: PrivateAnswerKey]
        var answersByQuestionId: [String: LearningTestAnswerRecord]
        var orderedAnswers: [LearningTestAnswerRecord]
    }

    private let historyStorageKey = "farki_learning_test_history_v1"
    private var activeSessions: [String: ActiveSessionState] = [:]
    private(set) var completedSessions: [LearningTestSessionResult] = []

    private init() {
        loadHistory()
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyStorageKey),
           let saved = try? JSONDecoder().decode([LearningTestSessionResult].self, from: data) {
            self.completedSessions = saved
        }
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(completedSessions) {
            UserDefaults.standard.set(encoded, forKey: historyStorageKey)
        }
    }

    // MARK: - Create Test Session
    func startSession(
        scope: LearningTestScope,
        preferredQuestionType: LearningQuestionType? = nil
    ) -> (sessionId: String, questions: [LearningPublicQuestion]) {
        let sessionId = "test-session-\(UUID().uuidString)"
        let resolvedItems = LearningItemResolver.resolveItems(for: scope)

        var publicQuestions: [LearningPublicQuestion] = []
        var answerKeys: [String: PrivateAnswerKey] = [:]

        for (index, item) in resolvedItems.enumerated() {
            // Only generate a question when content has a verified/non-empty correct answer
            let trimmedMeaning = item.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedJP = item.promptJapanese.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedMeaning.isEmpty, !trimmedJP.isEmpty else {
                continue
            }

            let qId = "\(sessionId)-q-\(index + 1)"
            let (pubQ, key) = buildQuestion(
                questionId: qId,
                sessionId: sessionId,
                item: item,
                allItems: resolvedItems,
                preferredType: preferredQuestionType
            )
            publicQuestions.append(pubQ)
            answerKeys[qId] = key
        }

        let state = ActiveSessionState(
            sessionId: sessionId,
            scope: scope,
            startedAt: Date(),
            completedAt: nil,
            questions: publicQuestions,
            answerKeysByQuestionId: answerKeys,
            answersByQuestionId: [:],
            orderedAnswers: []
        )
        activeSessions[sessionId] = state
        return (sessionId, publicQuestions)
    }

    // MARK: - Build Domain-Specific Question (Without Exposing Answer Key in Public Payload)
    private func buildQuestion(
        questionId: String,
        sessionId: String,
        item: ResolvedLearningItem,
        allItems: [ResolvedLearningItem],
        preferredType: LearningQuestionType?
    ) -> (LearningPublicQuestion, PrivateAnswerKey) {
        switch item.reference.domain {
        case .vocabulary:
            let options = buildMeaningOptions(correct: item.meaning, pool: allItems.map(\.meaning))
            let pub = LearningPublicQuestion(
                id: questionId,
                sessionId: sessionId,
                reference: item.reference,
                questionType: .vocabularyMeaning,
                prompt: item.promptJapanese,
                subtitle: item.promptRomaji,
                contextSentence: nil,
                romajiHint: item.promptRomaji,
                options: options,
                jlptLevel: item.jlptLevel,
                categoryLabel: item.categoryTag
            )
            let key = PrivateAnswerKey(
                questionId: questionId,
                reference: item.reference,
                questionType: .vocabularyMeaning,
                correctAnswer: item.meaning,
                acceptableAnswers: normalizedAcceptableSet([item.meaning, item.promptJapanese, item.promptRomaji]),
                explanation: "\(item.promptJapanese) (\(item.promptRomaji)): \(item.meaning)"
            )
            return (pub, key)

        case .grammar:
            // If preferredType is .grammarContextChoice and there is a verified example sentence containing the pattern/form
            if let firstEx = item.examples.first, !firstEx.japanese.isEmpty,
               preferredType == .grammarContextChoice {
                let options = buildPatternOptions(correct: item.promptJapanese, domain: .grammar)
                let pub = LearningPublicQuestion(
                    id: questionId,
                    sessionId: sessionId,
                    reference: item.reference,
                    questionType: .grammarContextChoice,
                    prompt: "Choose the grammar form for: \"\(firstEx.meaning)\"",
                    subtitle: item.pattern,
                    contextSentence: firstEx.japanese,
                    romajiHint: item.promptRomaji,
                    options: options,
                    jlptLevel: item.jlptLevel,
                    categoryLabel: item.categoryTag
                )
                let key = PrivateAnswerKey(
                    questionId: questionId,
                    reference: item.reference,
                    questionType: .grammarContextChoice,
                    correctAnswer: item.promptJapanese,
                    acceptableAnswers: normalizedAcceptableSet([item.promptJapanese, item.meaning, item.promptRomaji]),
                    explanation: item.explanation
                )
                return (pub, key)
            } else {
                let options = buildMeaningOptions(
                    correct: item.meaning,
                    pool: GrammarDataService.shared.grammarPoints.map(\.meaning) + allItems.map(\.meaning)
                )
                let pub = LearningPublicQuestion(
                    id: questionId,
                    sessionId: sessionId,
                    reference: item.reference,
                    questionType: .grammarPatternMeaning,
                    prompt: item.promptJapanese,
                    subtitle: item.pattern ?? item.promptRomaji,
                    contextSentence: item.examples.first?.japanese,
                    romajiHint: item.promptRomaji,
                    options: options,
                    jlptLevel: item.jlptLevel,
                    categoryLabel: item.categoryTag
                )
                let key = PrivateAnswerKey(
                    questionId: questionId,
                    reference: item.reference,
                    questionType: .grammarPatternMeaning,
                    correctAnswer: item.meaning,
                    acceptableAnswers: normalizedAcceptableSet([item.meaning, item.promptJapanese]),
                    explanation: item.explanation
                )
                return (pub, key)
            }

        case .particles:
            // Section 3 Rule: A fill-in-the-blank or sentence context question requires a verified sentence!
            let verifiedExample = item.examples.first { ex in
                !ex.japanese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                ex.japanese.contains(item.promptJapanese)
            }

            if let example = verifiedExample,
               (preferredType == .particleFillBlank || preferredType == .particleDistinguishContext) {
                let blankedSentence = example.japanese.replacingOccurrences(
                    of: item.promptJapanese,
                    with: " [ ___ ] "
                )
                let qType: LearningQuestionType = (preferredType == .particleDistinguishContext)
                    ? .particleDistinguishContext
                    : .particleFillBlank
                let maxOpts = (qType == .particleDistinguishContext) ? 2 : 4
                let options = buildParticleFormOptions(correct: item.promptJapanese, count: maxOpts)

                let pub = LearningPublicQuestion(
                    id: questionId,
                    sessionId: sessionId,
                    reference: item.reference,
                    questionType: qType,
                    prompt: blankedSentence,
                    subtitle: example.meaning,
                    contextSentence: blankedSentence,
                    romajiHint: item.pattern,
                    options: options,
                    jlptLevel: item.jlptLevel,
                    categoryLabel: item.categoryTag
                )
                let key = PrivateAnswerKey(
                    questionId: questionId,
                    reference: item.reference,
                    questionType: qType,
                    correctAnswer: item.promptJapanese,
                    acceptableAnswers: normalizedAcceptableSet([item.promptJapanese, item.promptRomaji]),
                    explanation: "\(item.promptJapanese) (\(item.promptRomaji)) — \(item.meaning). \(item.explanation)"
                )
                return (pub, key)
            } else {
                // Default / fallback when no verified sentence exists: Match particle usage to its meaning
                let usagePool = ParticleDataService.shared.usages.map(\.meaning)
                let options = buildMeaningOptions(correct: item.meaning, pool: usagePool)
                let pub = LearningPublicQuestion(
                    id: questionId,
                    sessionId: sessionId,
                    reference: item.reference,
                    questionType: .particleMeaningMatch,
                    prompt: "\(item.promptJapanese) (\(item.promptRomaji))",
                    subtitle: item.pattern,
                    contextSentence: verifiedExample?.japanese,
                    romajiHint: item.promptRomaji,
                    options: options,
                    jlptLevel: item.jlptLevel,
                    categoryLabel: item.categoryTag
                )
                let key = PrivateAnswerKey(
                    questionId: questionId,
                    reference: item.reference,
                    questionType: .particleMeaningMatch,
                    correctAnswer: item.meaning,
                    acceptableAnswers: normalizedAcceptableSet([item.meaning, item.originalMeaning ?? item.meaning]),
                    explanation: "\(item.promptJapanese) (\(item.promptRomaji)): \(item.explanation)"
                )
                return (pub, key)
            }
        }
    }

    private func buildMeaningOptions(correct: String, pool: [String], count: Int = 4) -> [String] {
        var distractors: [String] = []
        for candidate in pool where candidate != correct && !distractors.contains(candidate) {
            distractors.append(candidate)
            if distractors.count >= count - 1 {
                break
            }
        }
        var result = [correct] + distractors
        // Deterministic rotation based on hash so options don't always have correct at index 0
        let shift = abs(correct.hashValue) % max(1, result.count)
        if shift > 0 && shift < result.count {
            result = Array(result[shift...]) + Array(result[..<shift])
        }
        return result
    }

    private func buildParticleFormOptions(correct: String, count: Int = 4) -> [String] {
        let commonForms = ["は", "が", "を", "に", "で", "の", "と", "も", "へ", "から", "まで", "より"]
        let pool = commonForms + ParticleDataService.shared.particles.map(\.japanese)
        return buildMeaningOptions(correct: correct, pool: pool, count: count)
    }

    private func buildPatternOptions(correct: String, domain: LearningDomain, count: Int = 4) -> [String] {
        let pool = GrammarDataService.shared.grammarPoints.map(\.japanese)
        return buildMeaningOptions(correct: correct, pool: pool, count: count)
    }

    private func normalizedAcceptableSet(_ list: [String]) -> Set<String> {
        Set(list.map { normalizeAnswer($0) }.filter { !$0.isEmpty })
    }

    private func normalizeAnswer(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Submit Written / Multiple-Choice Answer (Authoritative Scoring + SRS Integration)
    @discardableResult
    func submitAnswer(
        sessionId: String,
        questionId: String,
        submittedAnswer: String?,
        durationSeconds: TimeInterval = 1.5,
        now: Date = Date()
    ) -> LearningTestAnswerRecord? {
        guard var session = activeSessions[sessionId],
              let key = session.answerKeysByQuestionId[questionId] else {
            return nil
        }

        // Section 5 Safeguard: One submitted answer must not create duplicate review events!
        if let existingRecord = session.answersByQuestionId[questionId] {
            return existingRecord
        }

        let rawSubmitted = submittedAnswer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isSkipped = rawSubmitted.isEmpty
        let isCorrect = !isSkipped && key.acceptableAnswers.contains(normalizeAnswer(rawSubmitted))
        let rating: SRSRating = isCorrect ? .good : .again

        // Connect test result to existing review & progress mechanism using Vocabulary policy
        let scopeId = "test_\(key.reference.domain.rawValue)"
        LearningItemResolver.recordReviewOutcome(
            reference: key.reference,
            rating: rating,
            wasRevealedBeforeRating: !isCorrect,
            durationSeconds: durationSeconds,
            scopeIdentifier: scopeId,
            now: now
        )

        let record = LearningTestAnswerRecord(
            sessionId: sessionId,
            questionId: questionId,
            reference: key.reference,
            questionType: key.questionType,
            submittedAnswer: rawSubmitted,
            rating: rating,
            isCorrect: isCorrect,
            isSkipped: isSkipped,
            correctAnswer: key.correctAnswer,
            explanation: key.explanation,
            durationMs: max(300, Int(durationSeconds * 1000)),
            timestamp: now
        )

        session.answersByQuestionId[questionId] = record
        session.orderedAnswers.append(record)
        if session.orderedAnswers.count == session.questions.count {
            session.completedAt = now
        }
        activeSessions[sessionId] = session
        persistSessionSummary(session)

        return record
    }

    // MARK: - Submit Self-Rated Answer (4-Button Rating: Don't Know / Hard / Good / Easy)
    @discardableResult
    func submitSelfRating(
        sessionId: String,
        questionId: String,
        rating: SRSRating,
        wasRevealed: Bool = false,
        durationSeconds: TimeInterval = 1.5,
        now: Date = Date()
    ) -> LearningTestAnswerRecord? {
        guard var session = activeSessions[sessionId],
              let key = session.answerKeysByQuestionId[questionId] else {
            return nil
        }

        // Section 5 Safeguard: Prevent duplicate review events for the same question in a session!
        if let existingRecord = session.answersByQuestionId[questionId] {
            return existingRecord
        }

        // If meaning was revealed in test mode before rating, Vocabulary policy caps rating at Hard/Again (incorrect)
        let effectiveRating: SRSRating
        if wasRevealed && (rating == .good || rating == .easy) {
            effectiveRating = .hard
        } else {
            effectiveRating = rating
        }

        let isCorrect = (effectiveRating == .good || effectiveRating == .easy)
        let scopeId = "test_\(key.reference.domain.rawValue)"

        LearningItemResolver.recordReviewOutcome(
            reference: key.reference,
            rating: effectiveRating,
            wasRevealedBeforeRating: wasRevealed,
            durationSeconds: durationSeconds,
            scopeIdentifier: scopeId,
            now: now
        )

        let record = LearningTestAnswerRecord(
            sessionId: sessionId,
            questionId: questionId,
            reference: key.reference,
            questionType: key.questionType,
            submittedAnswer: isCorrect ? key.correctAnswer : effectiveRating.title,
            rating: effectiveRating,
            isCorrect: isCorrect,
            isSkipped: false,
            correctAnswer: key.correctAnswer,
            explanation: key.explanation,
            durationMs: max(300, Int(durationSeconds * 1000)),
            timestamp: now
        )

        session.answersByQuestionId[questionId] = record
        session.orderedAnswers.append(record)
        if session.orderedAnswers.count == session.questions.count {
            session.completedAt = now
        }
        activeSessions[sessionId] = session
        persistSessionSummary(session)

        return record
    }

    // MARK: - Pure Read-Only Session Results (Section 5 Safeguard: Never Submits or Schedules Again)
    func getSessionResult(sessionId: String) -> LearningTestSessionResult? {
        if let active = activeSessions[sessionId] {
            return buildResult(from: active)
        }
        return completedSessions.first { $0.sessionId == sessionId }
    }

    private func buildResult(from session: ActiveSessionState) -> LearningTestSessionResult {
        let answers = session.orderedAnswers
        let correct = answers.filter { $0.isCorrect }.count
        let skipped = answers.filter { $0.isSkipped }.count
        let wrong = answers.count - correct

        return LearningTestSessionResult(
            sessionId: session.sessionId,
            scope: session.scope,
            totalQuestions: session.questions.count,
            answeredCount: answers.count,
            correctCount: correct,
            wrongCount: wrong,
            skippedCount: skipped,
            answers: answers,
            startedAt: session.startedAt,
            completedAt: session.completedAt
        )
    }

    private func persistSessionSummary(_ session: ActiveSessionState) {
        let result = buildResult(from: session)
        if let idx = completedSessions.firstIndex(where: { $0.sessionId == session.sessionId }) {
            completedSessions[idx] = result
        } else {
            completedSessions.insert(result, at: 0)
        }
        saveHistory()
    }
}

