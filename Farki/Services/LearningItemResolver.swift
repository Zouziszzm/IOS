import Foundation

/// Resolves learning items across Vocabulary, Grammar (points & variants), and Particles (particles & usages),
/// and applies the unified Vocabulary prioritization and progress update policy.
struct LearningItemResolver {

    static func resolve(_ reference: LearningItemReference) -> ResolvedLearningItem? {
        switch reference.domain {
        case .vocabulary:
            guard let item = VocabDataService.shared.items.first(where: { $0.id == reference.contentId }) else {
                return nil
            }
            let progress = LearningItemProgress(
                identityKey: item.id,
                learningState: item.learningState,
                difficulty: item.difficulty,
                bestTimeSeconds: item.bestTimeSeconds,
                currentStreak: item.currentStreak,
                bestStreak: item.bestStreak
            )
            return ResolvedLearningItem(
                reference: LearningItemReference(domain: .vocabulary, contentId: item.id),
                sequenceNumber: item.number,
                chapterNumber: item.chapterNumber,
                promptJapanese: item.japanese,
                promptKana: item.kana,
                promptRomaji: item.romaji,
                meaning: item.meaning,
                explanation: "\(item.wordType.description) • Chapter \(item.chapterNumber)",
                pattern: item.kanji,
                categoryTag: item.categoryTag,
                jlptLevel: item.jlptLevel,
                examples: [],
                relatedGrammarPointIds: [],
                sourceNumber: item.number,
                originalMeaning: item.meaning,
                progress: progress
            )

        case .grammar:
            guard let point = GrammarDataService.shared.point(forId: reference.contentId) else {
                return nil
            }
            if let variantId = reference.subContentId,
               let variant = point.variants.first(where: { $0.id == variantId }) {
                let ref = LearningItemReference(domain: .grammar, contentId: point.id, subContentId: variant.id)
                let progress = GrammarDataService.shared.progress(for: ref)
                return ResolvedLearningItem(
                    reference: ref,
                    sequenceNumber: point.number,
                    chapterNumber: point.chapterNumber,
                    promptJapanese: variant.pattern,
                    promptKana: variant.pattern,
                    promptRomaji: variant.romaji,
                    meaning: variant.meaning,
                    explanation: variant.explanation ?? point.explanation,
                    pattern: variant.pattern,
                    categoryTag: "\(point.categoryTag) • \(variant.label)",
                    jlptLevel: point.jlptLevel,
                    examples: variant.examples.isEmpty ? point.examples : variant.examples,
                    relatedGrammarPointIds: [point.id],
                    sourceNumber: point.number,
                    originalMeaning: variant.meaning,
                    progress: progress
                )
            } else {
                let ref = LearningItemReference(domain: .grammar, contentId: point.id, subContentId: nil)
                let progress = GrammarDataService.shared.progress(for: ref)
                return ResolvedLearningItem(
                    reference: ref,
                    sequenceNumber: point.number,
                    chapterNumber: point.chapterNumber,
                    promptJapanese: point.japanese,
                    promptKana: point.japanese,
                    promptRomaji: point.romaji,
                    meaning: point.meaning,
                    explanation: point.explanation,
                    pattern: point.pattern,
                    categoryTag: point.categoryTag,
                    jlptLevel: point.jlptLevel,
                    examples: point.examples,
                    relatedGrammarPointIds: [point.id],
                    sourceNumber: point.number,
                    originalMeaning: point.meaning,
                    progress: progress
                )
            }

        case .particles:
            let pService = ParticleDataService.shared
            guard let particle = pService.particle(forId: reference.contentId) else {
                return nil
            }
            let targetUsageId = reference.subContentId ?? particle.usageIds.first
            guard let usageId = targetUsageId,
                  let usage = pService.usage(forId: usageId) else {
                return nil
            }
            let canonicalRef = LearningItemReference(domain: .particles, contentId: particle.id, subContentId: usage.id)
            let sourceEntry = pService.sourceEntry(forUsageId: usage.id)
            let progress = pService.progress(for: canonicalRef)
            let catLabel = particle.categories.first?.displayName ?? "Particle"
            let seqNum = sourceEntry?.sourceNumber ?? 1

            return ResolvedLearningItem(
                reference: canonicalRef,
                sequenceNumber: seqNum,
                chapterNumber: sourceEntry?.sourcePage ?? 1,
                promptJapanese: particle.japanese,
                promptKana: particle.japanese,
                promptRomaji: particle.romaji,
                meaning: usage.meaning,
                explanation: usage.explanation,
                pattern: usage.pattern,
                categoryTag: "#\(seqNum) • \(catLabel)",
                jlptLevel: usage.jlptLevel,
                examples: usage.examples,
                relatedGrammarPointIds: usage.grammarPointIds,
                sourceNumber: sourceEntry?.sourceNumber,
                originalMeaning: sourceEntry?.originalMeaning ?? usage.meaning,
                progress: progress
            )
        }
    }

    // MARK: - Resolve Items for Scope
    static func resolveItems(for scope: LearningTestScope) -> [ResolvedLearningItem] {
        let activeDomains = scope.domains.isEmpty ? [.vocabulary] : scope.domains
        let chapterNumbers: Set<Int> = Set(scope.chapterIds.compactMap { str in
            if let num = Int(str) { return num }
            let digits = str.filter(\.isNumber)
            return Int(digits)
        })
        let jlptFilter = Set(scope.jlptLevels.filter { $0 != .all })

        var candidates: [ResolvedLearningItem] = []

        if activeDomains.contains(.vocabulary) {
            for vocab in VocabDataService.shared.items {
                if !chapterNumbers.isEmpty && !chapterNumbers.contains(vocab.chapterNumber) {
                    continue
                }
                if !jlptFilter.isEmpty && !jlptFilter.contains(vocab.jlptLevel) {
                    continue
                }
                if let resolved = resolve(LearningItemReference(domain: .vocabulary, contentId: vocab.id)) {
                    candidates.append(resolved)
                }
            }
        }

        if activeDomains.contains(.grammar) {
            let requestedGrammarIds = Set(scope.grammarPointIds)
            for point in GrammarDataService.shared.grammarPoints {
                if !requestedGrammarIds.isEmpty && !requestedGrammarIds.contains(point.id) {
                    continue
                }
                if !chapterNumbers.isEmpty && !chapterNumbers.contains(point.chapterNumber) {
                    continue
                }
                if !jlptFilter.isEmpty {
                    guard let level = point.jlptLevel, jlptFilter.contains(level) else {
                        continue
                    }
                }
                if let resolvedPoint = resolve(LearningItemReference(domain: .grammar, contentId: point.id)) {
                    candidates.append(resolvedPoint)
                }
                for variant in point.variants {
                    if let resolvedVariant = resolve(LearningItemReference(domain: .grammar, contentId: point.id, subContentId: variant.id)) {
                        candidates.append(resolvedVariant)
                    }
                }
            }
        }

        if activeDomains.contains(.particles) {
            let pService = ParticleDataService.shared
            let requestedParticleIds = Set(scope.particleIds)
            let requestedUsageIds = Set(scope.particleUsageIds)

            for entry in pService.sourceEntries {
                if !requestedParticleIds.isEmpty && !requestedParticleIds.contains(entry.particleId) {
                    continue
                }
                if !requestedUsageIds.isEmpty && !requestedUsageIds.contains(entry.usageId) {
                    continue
                }
                let ref = LearningItemReference(domain: .particles, contentId: entry.particleId, subContentId: entry.usageId)
                guard let resolved = resolve(ref) else { continue }

                if !jlptFilter.isEmpty {
                    guard let level = resolved.jlptLevel, jlptFilter.contains(level) else {
                        continue
                    }
                }
                candidates.append(resolved)
            }
        }

        if scope.mistakesOnly {
            let cardStates = SRSStorageService.shared.cardStates
            let filtered = candidates.filter { item in
                if item.progress.difficulty == .hard || item.progress.difficulty == .medium {
                    return true
                }
                let cardId = item.reference.srsCardId(direction: SRSStorageService.shared.config.direction)
                if let state = cardStates[cardId], (state.lapses > 0 || state.state == .relearning) {
                    return true
                }
                if let directState = cardStates[item.reference.reviewIdentityKey], (directState.lapses > 0 || directState.state == .relearning) {
                    return true
                }
                return false
            }
            candidates = filtered
        }

        let sorted = prioritizedSort(candidates)
        if scope.questionCount > 0 && sorted.count > scope.questionCount {
            return Array(sorted.prefix(scope.questionCount))
        }
        return sorted
    }

    // MARK: - Unified Prioritized Sort (Reuses Vocabulary Priority Logic)
    static func prioritizedSort(_ list: [ResolvedLearningItem]) -> [ResolvedLearningItem] {
        return list.sorted { a, b in
            let prioA = priorityScore(for: a.progress)
            let prioB = priorityScore(for: b.progress)
            if prioA != prioB {
                return prioA < prioB // 0 = Hard/Trouble first, 3 = Mastered last
            }
            if a.progress.difficulty == .hard {
                if a.progress.currentStreak != b.progress.currentStreak {
                    return a.progress.currentStreak < b.progress.currentStreak
                }
            } else if a.progress.difficulty == .easy {
                if a.progress.bestStreak != b.progress.bestStreak {
                    return a.progress.bestStreak < b.progress.bestStreak
                }
            }
            if a.chapterNumber != b.chapterNumber {
                return a.chapterNumber < b.chapterNumber
            }
            return a.sequenceNumber < b.sequenceNumber
        }
    }

    private static func priorityScore(for progress: LearningItemProgress) -> Int {
        switch progress.difficulty {
        case .hard:
            return 0
        case .medium:
            return 1
        case .easy:
            return progress.learningState == .unseen ? 2 : 3
        }
    }

    // MARK: - Unified Progress & SRS Update Policy (Matches Vocabulary Exactly)
    @discardableResult
    static func recordReviewOutcome(
        reference: LearningItemReference,
        rating: SRSRating,
        wasRevealedBeforeRating: Bool = false,
        durationSeconds: TimeInterval,
        scopeIdentifier: String,
        now: Date = Date()
    ) -> CardState {
        let learningState: VocabLearningState
        let difficulty: VocabDifficulty
        let isCorrect: Bool

        switch rating {
        case .again:
            difficulty = .hard
            isCorrect = false
            learningState = .knownAfterReveal
        case .hard:
            difficulty = .hard
            isCorrect = false
            learningState = .knownAfterReveal
        case .good:
            difficulty = .medium
            isCorrect = true
            learningState = wasRevealedBeforeRating ? .knownAfterReveal : .knownDirectly
        case .easy:
            difficulty = .easy
            isCorrect = true
            learningState = wasRevealedBeforeRating ? .knownAfterReveal : .knownDirectly
        }

        switch reference.domain {
        case .vocabulary:
            VocabDataService.shared.updateWordProgress(
                id: reference.contentId,
                learningState: learningState,
                difficulty: difficulty,
                responseTime: durationSeconds,
                isCorrect: isCorrect
            )
        case .grammar:
            GrammarDataService.shared.updateProgress(
                for: reference,
                learningState: learningState,
                difficulty: difficulty,
                responseTime: durationSeconds,
                isCorrect: isCorrect
            )
        case .particles:
            ParticleDataService.shared.updateProgress(
                for: reference,
                learningState: learningState,
                difficulty: difficulty,
                responseTime: durationSeconds,
                isCorrect: isCorrect
            )
        }

        let durationMs = max(300, Int(durationSeconds * 1000))
        let updatedState = SRSStorageService.shared.recordReview(
            cardId: reference.reviewIdentityKey,
            rating: rating,
            durationMs: durationMs,
            scope: scopeIdentifier,
            now: now
        )
        return updatedState
    }
}

