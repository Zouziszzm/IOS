import Foundation

// MARK: - Queue Item
struct SRSQueueItem: Identifiable, Equatable {
    var id: String { cardState.cardId }
    let cardState: CardState
    let vocabItem: VocabItem
    let direction: CardDirection
    let reference: LearningReviewReference
    let resolvedItem: ResolvedLearningItem?

    init(
        cardState: CardState,
        vocabItem: VocabItem,
        direction: CardDirection,
        reference: LearningReviewReference? = nil,
        resolvedItem: ResolvedLearningItem? = nil
    ) {
        self.cardState = cardState
        self.vocabItem = vocabItem
        self.direction = direction
        self.reference = reference ?? LearningItemReference.parse(from: vocabItem.id)
        self.resolvedItem = resolvedItem
    }
}

// MARK: - Queue Counts
struct SRSQueueCounts: Equatable {
    let newCount: Int
    let learningCount: Int
    let reviewCount: Int
    let totalDue: Int

    init(newCount: Int, learningCount: Int, reviewCount: Int) {
        self.newCount = newCount
        self.learningCount = learningCount
        self.reviewCount = reviewCount
        self.totalDue = learningCount + reviewCount + newCount
    }
}

// MARK: - Queue Builder
struct SRSQueueBuilder {

    /// Resolves the authoritative CardState for an entry key, checking both directional cardId and direct identity key
    static func resolveCardState(
        entryKey: String,
        direction: CardDirection,
        cardStates: [String: CardState]
    ) -> CardState {
        let directionalId = CardDirection.cardId(entryId: entryKey, direction: direction)
        let dirState = cardStates[directionalId]
        let directState = cardStates[entryKey]

        if let s1 = dirState, let s2 = directState {
            let t1 = s1.lastReviewedAt ?? .distantPast
            let t2 = s2.lastReviewedAt ?? .distantPast
            return (t2 > t1) ? s2 : s1
        }
        if let s1 = dirState {
            return s1
        }
        if let s2 = directState {
            return s2
        }
        return CardState(cardId: directionalId, state: .new)
    }

    /// Calculates the UTC timestamp for when the current SRS day started, respecting dayRolloverHour
    static func startOfSRSDay(for date: Date, rolloverHour: Int, calendar: Calendar = Calendar.current) -> Date {
        let cal = calendar
        let currentHour = cal.component(.hour, from: date)
        var targetDate = date

        if currentHour < rolloverHour {
            // It is before rollover hour today, so the current SRS day started yesterday at rolloverHour
            targetDate = cal.date(byAdding: .day, value: -1, to: date) ?? date
        }

        var components = cal.dateComponents([.year, .month, .day], from: targetDate)
        components.hour = rolloverHour
        components.minute = 0
        components.second = 0

        return cal.date(from: components) ?? date
    }

    /// Computes today's global usage across all scopes to enforce global quotas
    static func computeGlobalUsageToday(
        reviewLogs: [ReviewLog],
        now: Date,
        config: SRSConfig,
        calendar: Calendar = Calendar.current
    ) -> (newUsed: Int, reviewUsed: Int) {
        let dayStart = startOfSRSDay(for: now, rolloverHour: config.dayRolloverHour, calendar: calendar)

        var newIntroducedCardIds = Set<String>()
        var reviewReviewsCount = 0

        for log in reviewLogs where log.timestamp >= dayStart {
            if log.stateBefore == .new {
                newIntroducedCardIds.insert(log.cardId)
            } else if log.stateBefore == .review {
                reviewReviewsCount += 1
            }
        }

        return (newIntroducedCardIds.count, reviewReviewsCount)
    }

    /// Builds the prioritized study queue for a Vocabulary scope respecting global limits
    static func buildQueue(
        scope: SRSScope,
        vocabItems: [VocabItem],
        cardStates: [String: CardState],
        reviewLogs: [ReviewLog],
        now: Date = Date(),
        config: SRSConfig = SRSConfig(),
        calendar: Calendar = Calendar.current
    ) -> [SRSQueueItem] {
        // 1. Filter vocab items matching scope
        let scopedVocab = vocabItems.filter { scope.matches(chapter: $0.chapterNumber) }

        // 2. Global quota calculation
        let (newUsedToday, reviewUsedToday) = computeGlobalUsageToday(
            reviewLogs: reviewLogs,
            now: now,
            config: config,
            calendar: calendar
        )
        let remainingNewQuota = max(0, config.newCardsPerDay - newUsedToday)
        let remainingReviewQuota = max(0, config.maxReviewsPerDay - reviewUsedToday)

        // 3. Separate cards into buckets
        var learningItems: [SRSQueueItem] = []
        var reviewItems: [SRSQueueItem] = []
        var newCandidates: [(VocabItem, CardState)] = []

        let direction = config.direction

        for vocab in scopedVocab {
            let state = resolveCardState(entryKey: vocab.id, direction: direction, cardStates: cardStates)

            switch state.state {
            case .learning, .relearning:
                if state.due <= now {
                    learningItems.append(SRSQueueItem(cardState: state, vocabItem: vocab, direction: direction))
                }
            case .review:
                if state.due <= now {
                    reviewItems.append(SRSQueueItem(cardState: state, vocabItem: vocab, direction: direction))
                }
            case .new:
                newCandidates.append((vocab, state))
            }
        }

        // 4. Sort learning & relearning by due date ascending
        learningItems.sort { $0.cardState.due < $1.cardState.due }

        // 5. Sort review by due date ascending, and take up to remaining review quota
        reviewItems.sort { $0.cardState.due < $1.cardState.due }
        let cappedReviewItems = Array(reviewItems.prefix(remainingReviewQuota))

        // 6. Sort new candidates by chapter number, then entry number, and take up to remaining new quota
        newCandidates.sort { a, b in
            if a.0.chapterNumber != b.0.chapterNumber {
                return a.0.chapterNumber < b.0.chapterNumber
            }
            return a.0.number < b.0.number
        }
        let cappedNewItems = newCandidates.prefix(remainingNewQuota).map {
            SRSQueueItem(cardState: $1, vocabItem: $0, direction: direction)
        }

        // 7. Combined queue: Learning/Relearning due -> Review due -> New
        return learningItems + cappedReviewItems + cappedNewItems
    }

    /// Domain-aware queue builder for Vocabulary, Grammar, and Particles using the same scheduler and rules (Section 4)
    static func buildDomainQueue(
        references: [LearningReviewReference],
        cardStates: [String: CardState],
        reviewLogs: [ReviewLog],
        now: Date = Date(),
        config: SRSConfig = SRSConfig(),
        calendar: Calendar = Calendar.current
    ) -> [SRSQueueItem] {
        let (newUsedToday, reviewUsedToday) = computeGlobalUsageToday(
            reviewLogs: reviewLogs,
            now: now,
            config: config,
            calendar: calendar
        )
        let remainingNewQuota = max(0, config.newCardsPerDay - newUsedToday)
        let remainingReviewQuota = max(0, config.maxReviewsPerDay - reviewUsedToday)

        var learningItems: [SRSQueueItem] = []
        var reviewItems: [SRSQueueItem] = []
        var newCandidates: [(ResolvedLearningItem, CardState)] = []

        let direction = config.direction

        for ref in references {
            guard let resolved = LearningItemResolver.resolve(ref) else { continue }
            let state = resolveCardState(entryKey: resolved.reference.reviewIdentityKey, direction: direction, cardStates: cardStates)
            let synthVocab = resolved.toSyntheticVocabItem()

            switch state.state {
            case .learning, .relearning:
                if state.due <= now {
                    learningItems.append(SRSQueueItem(
                        cardState: state,
                        vocabItem: synthVocab,
                        direction: direction,
                        reference: resolved.reference,
                        resolvedItem: resolved
                    ))
                }
            case .review:
                if state.due <= now {
                    reviewItems.append(SRSQueueItem(
                        cardState: state,
                        vocabItem: synthVocab,
                        direction: direction,
                        reference: resolved.reference,
                        resolvedItem: resolved
                    ))
                }
            case .new:
                newCandidates.append((resolved, state))
            }
        }

        // Prioritize missed/difficult items first among learning/review ties, then due date ascending
        learningItems.sort { a, b in
            if a.cardState.due != b.cardState.due {
                return a.cardState.due < b.cardState.due
            }
            return a.vocabItem.difficulty.numericValue > b.vocabItem.difficulty.numericValue
        }

        reviewItems.sort { a, b in
            if a.cardState.due != b.cardState.due {
                return a.cardState.due < b.cardState.due
            }
            return a.vocabItem.difficulty.numericValue > b.vocabItem.difficulty.numericValue
        }
        let cappedReviewItems = Array(reviewItems.prefix(remainingReviewQuota))

        // Sort new candidates prioritizing trouble/missed items first, then natural chapter & sequence order
        newCandidates.sort { a, b in
            if a.0.progress.difficulty != b.0.progress.difficulty {
                return a.0.progress.difficulty.numericValue > b.0.progress.difficulty.numericValue
            }
            if a.0.chapterNumber != b.0.chapterNumber {
                return a.0.chapterNumber < b.0.chapterNumber
            }
            return a.0.sequenceNumber < b.0.sequenceNumber
        }
        let cappedNewItems = newCandidates.prefix(remainingNewQuota).map { (resolved, state) in
            SRSQueueItem(
                cardState: state,
                vocabItem: resolved.toSyntheticVocabItem(),
                direction: direction,
                reference: resolved.reference,
                resolvedItem: resolved
            )
        }

        return learningItems + cappedReviewItems + cappedNewItems
    }

    /// Computes summary counts (New, Learning, Due) for a scope
    static func computeCounts(
        scope: SRSScope,
        vocabItems: [VocabItem],
        cardStates: [String: CardState],
        reviewLogs: [ReviewLog],
        now: Date = Date(),
        config: SRSConfig = SRSConfig(),
        calendar: Calendar = Calendar.current
    ) -> SRSQueueCounts {
        let queue = buildQueue(
            scope: scope,
            vocabItems: vocabItems,
            cardStates: cardStates,
            reviewLogs: reviewLogs,
            now: now,
            config: config,
            calendar: calendar
        )

        var newCount = 0
        var learningCount = 0
        var reviewCount = 0

        for item in queue {
            switch item.cardState.state {
            case .new: newCount += 1
            case .learning, .relearning: learningCount += 1
            case .review: reviewCount += 1
            }
        }

        return SRSQueueCounts(newCount: newCount, learningCount: learningCount, reviewCount: reviewCount)
    }

    /// Computes summary counts for a domain-aware reference list
    static func computeDomainCounts(
        references: [LearningReviewReference],
        cardStates: [String: CardState],
        reviewLogs: [ReviewLog],
        now: Date = Date(),
        config: SRSConfig = SRSConfig(),
        calendar: Calendar = Calendar.current
    ) -> SRSQueueCounts {
        let queue = buildDomainQueue(
            references: references,
            cardStates: cardStates,
            reviewLogs: reviewLogs,
            now: now,
            config: config,
            calendar: calendar
        )

        var newCount = 0
        var learningCount = 0
        var reviewCount = 0

        for item in queue {
            switch item.cardState.state {
            case .new: newCount += 1
            case .learning, .relearning: learningCount += 1
            case .review: reviewCount += 1
            }
        }

        return SRSQueueCounts(newCount: newCount, learningCount: learningCount, reviewCount: reviewCount)
    }
}
