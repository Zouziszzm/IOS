import Foundation

func assertTrue(_ condition: Bool, _ msg: String = "", file: StaticString = #file, line: UInt = #line) {
    guard condition else {
        fatalError("❌ assertTrue failed: \(msg) at \(file):\(line)")
    }
}

func assertFalse(_ condition: Bool, _ msg: String = "", file: StaticString = #file, line: UInt = #line) {
    guard !condition else {
        fatalError("❌ assertFalse failed: \(msg) at \(file):\(line)")
    }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "", file: StaticString = #file, line: UInt = #line) {
    guard a == b else {
        fatalError("❌ assertEqual failed: expected '\(b)', got '\(a)' [\(msg)] at \(file):\(line)")
    }
}

func assertEqualDouble(_ a: Double, _ b: Double, accuracy: Double = 0.05, _ msg: String = "", file: StaticString = #file, line: UInt = #line) {
    guard abs(a - b) <= accuracy else {
        fatalError("❌ assertEqualDouble failed: expected \(b) ± \(accuracy), got \(a) [\(msg)] at \(file):\(line)")
    }
}

// MARK: - Test Suite
final class SRSSchedulerTests {

    var config: SRSConfig
    var baseDate: Date

    init() {
        self.config = SRSConfig(
            learningSteps: [1.0, 10.0],
            relearningSteps: [10.0],
            graduatingIntervalDays: 1.0,
            easyIntervalDays: 4.0,
            startingEase: 2.5,
            minEase: 1.3,
            easyBonus: 1.3,
            hardMultiplier: 1.2,
            intervalModifier: 1.0,
            newCardsPerDay: 20,
            maxReviewsPerDay: 200,
            dayRolloverHour: 4,
            enableFuzz: false
        )
        self.baseDate = Date(timeIntervalSince1970: 1700000000) // Deterministic reference date
    }

    func reset() {
        self.config = SRSConfig(
            learningSteps: [1.0, 10.0],
            relearningSteps: [10.0],
            graduatingIntervalDays: 1.0,
            easyIntervalDays: 4.0,
            startingEase: 2.5,
            minEase: 1.3,
            easyBonus: 1.3,
            hardMultiplier: 1.2,
            intervalModifier: 1.0,
            newCardsPerDay: 20,
            maxReviewsPerDay: 200,
            dayRolloverHour: 4,
            enableFuzz: false
        )
        self.baseDate = Date(timeIntervalSince1970: 1700000000)
    }

    // MARK: - 1. New -> Learning -> Review (Step progression and graduation)
    func testNewToLearningProgressionAndGraduation() {
        reset()
        let newCard = CardState(cardId: "entry1:jp_meaning", state: .new)

        // Rating Good on new card -> stepIndex 1 of learning (10 min due)
        let step1 = SRSScheduler.schedule(card: newCard, rating: .good, now: baseDate, config: config)
        assertEqual(step1.state, .learning)
        assertEqual(step1.stepIndex, 1)
        assertEqualDouble(step1.due.timeIntervalSince(baseDate), 10.0 * 60.0, accuracy: 0.1)

        // Rating Good on step 1 -> graduates to .review with graduatingIntervalDays (1.0)
        let step2 = SRSScheduler.schedule(card: step1, rating: .good, now: baseDate, config: config)
        assertEqual(step2.state, .review)
        assertEqual(step2.stepIndex, 0)
        assertEqualDouble(step2.intervalDays, 1.0, accuracy: 0.01)
        assertEqualDouble(step2.due.timeIntervalSince(baseDate), 1.0 * 86400.0, accuracy: 0.1)

        // Test Easy on new card -> immediate graduation with easyIntervalDays (4.0)
        let earlyGrad = SRSScheduler.schedule(card: newCard, rating: .easy, now: baseDate, config: config)
        assertEqual(earlyGrad.state, .review)
        assertEqualDouble(earlyGrad.intervalDays, 4.0, accuracy: 0.01)
        assertEqualDouble(earlyGrad.due.timeIntervalSince(baseDate), 4.0 * 86400.0, accuracy: 0.1)
    }

    // MARK: - 2. Lapse -> Relearning -> Re-graduation
    func testLapseToRelearningAndRegraduation() {
        reset()
        let reviewCard = CardState(
            cardId: "entry1:jp_meaning",
            state: .review,
            due: baseDate,
            intervalDays: 15.0,
            ease: 2.5,
            reps: 5,
            lapses: 0
        )

        // Lapse with Again
        let lapsed = SRSScheduler.schedule(card: reviewCard, rating: .again, now: baseDate, config: config)
        assertEqual(lapsed.state, .relearning)
        assertEqual(lapsed.lapses, 1)
        assertEqual(lapsed.stepIndex, 0)
        assertEqualDouble(lapsed.ease, 2.3, accuracy: 0.001) // 2.5 - 0.20
        assertEqualDouble(lapsed.due.timeIntervalSince(baseDate), 10.0 * 60.0, accuracy: 0.1)

        // Good on relearning (1 step [10]) -> Re-graduates to review
        let regraduated = SRSScheduler.schedule(card: lapsed, rating: .good, now: baseDate, config: config)
        assertEqual(regraduated.state, .review)
        assertEqualDouble(regraduated.intervalDays, 1.0, accuracy: 0.01)
    }

    // MARK: - 3. Ease Bounds (minEase 1.3, decrements & increments)
    func testEaseBoundsAndUpdates() {
        reset()
        var card = CardState(cardId: "card:1", state: .review, intervalDays: 10.0, ease: 1.45)

        // Hard decrements by 0.15 -> 1.30
        card = SRSScheduler.schedule(card: card, rating: .hard, now: baseDate, config: config)
        assertEqualDouble(card.ease, 1.30, accuracy: 0.001)

        // Hard again decrements but is clamped to minEase (1.3)
        card = SRSScheduler.schedule(card: card, rating: .hard, now: baseDate, config: config)
        assertEqualDouble(card.ease, 1.30, accuracy: 0.001)

        // Again decrements by 0.20 but clamped to minEase (1.3)
        let lapsed = SRSScheduler.schedule(card: card, rating: .again, now: baseDate, config: config)
        assertEqualDouble(lapsed.ease, 1.30, accuracy: 0.001)

        // Easy on review card increments by 0.15
        var highCard = CardState(cardId: "card:2", state: .review, intervalDays: 10.0, ease: 2.50)
        highCard = SRSScheduler.schedule(card: highCard, rating: .easy, now: baseDate, config: config)
        assertEqualDouble(highCard.ease, 2.65, accuracy: 0.001)

        // Good does not change ease
        let goodCard = SRSScheduler.schedule(card: highCard, rating: .good, now: baseDate, config: config)
        assertEqualDouble(goodCard.ease, 2.65, accuracy: 0.001)
    }

    // MARK: - 4. Interval Growth (multiplier, easyBonus, intervalModifier)
    func testIntervalGrowth() {
        reset()
        let reviewCard = CardState(
            cardId: "card:growth",
            state: .review,
            intervalDays: 10.0,
            ease: 2.5
        )

        // Hard: interval = max(11, 10 * 1.2 * 1.0) = 12.0 days
        let hardResult = SRSScheduler.schedule(card: reviewCard, rating: .hard, now: baseDate, config: config)
        assertEqualDouble(hardResult.intervalDays, 12.0, accuracy: 0.01)

        // Good: interval = max(11, 10 * 2.5 * 1.0) = 25.0 days
        let goodResult = SRSScheduler.schedule(card: reviewCard, rating: .good, now: baseDate, config: config)
        assertEqualDouble(goodResult.intervalDays, 25.0, accuracy: 0.01)

        // Easy: interval = max(11, 10 * 2.5 * 1.3 * 1.0) = 32.5 days
        let easyResult = SRSScheduler.schedule(card: reviewCard, rating: .easy, now: baseDate, config: config)
        assertEqualDouble(easyResult.intervalDays, 32.5, accuracy: 0.01)

        // Test with intervalModifier = 1.2
        var modConfig = config
        modConfig.intervalModifier = 1.2
        let modResult = SRSScheduler.schedule(card: reviewCard, rating: .good, now: baseDate, config: modConfig)
        // 10 * 2.5 * 1.2 = 30.0 days
        assertEqualDouble(modResult.intervalDays, 30.0, accuracy: 0.01)
    }

    // MARK: - 5. Fuzz Bounds for Intervals > 2 Days
    func testFuzzBounds() {
        reset()
        var fuzzConfig = config
        fuzzConfig.enableFuzz = true

        // No fuzz for intervals <= 2 days
        let noFuzz = SRSScheduler.applyFuzzIfNeeded(interval: 2.0, config: fuzzConfig)
        assertEqualDouble(noFuzz, 2.0, accuracy: 0.001)

        // Test fuzz bounds for 10 days (should be within ±0.8 to 1.0 day)
        for _ in 0..<50 {
            let fuzzed = SRSScheduler.applyFuzzIfNeeded(interval: 10.0, config: fuzzConfig)
            assertTrue(fuzzed >= 9.0, "Fuzzed should be >= 9.0")
            assertTrue(fuzzed <= 11.0, "Fuzzed should be <= 11.0")
        }

        // Test fuzz bounds for 50 days (±5%, i.e. 47.5 .. 52.5)
        for _ in 0..<50 {
            let fuzzed = SRSScheduler.applyFuzzIfNeeded(interval: 50.0, config: fuzzConfig)
            assertTrue(fuzzed >= 47.0, "Fuzzed should be >= 47.0")
            assertTrue(fuzzed <= 53.0, "Fuzzed should be <= 53.0")
        }
    }

    // MARK: - 6. Day Rollover Hour
    func testDayRolloverCalculation() {
        reset()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // Create date: 2026-10-24 03:30:00 UTC (before 4 AM rollover)
        var comps = DateComponents(year: 2026, month: 10, day: 24, hour: 3, minute: 30, second: 0)
        let beforeRollover = calendar.date(from: comps)!

        let dayStartBefore = SRSQueueBuilder.startOfSRSDay(for: beforeRollover, rolloverHour: 4, calendar: calendar)
        let startCompsBefore = calendar.dateComponents([.year, .month, .day, .hour], from: dayStartBefore)
        assertEqual(startCompsBefore.year, 2026)
        assertEqual(startCompsBefore.month, 10)
        assertEqual(startCompsBefore.day, 23) // Starts on Oct 23 at 4:00 AM
        assertEqual(startCompsBefore.hour, 4)

        // Create date: 2026-10-24 05:15:00 UTC (after 4 AM rollover)
        comps.hour = 5
        comps.minute = 15
        let afterRollover = calendar.date(from: comps)!

        let dayStartAfter = SRSQueueBuilder.startOfSRSDay(for: afterRollover, rolloverHour: 4, calendar: calendar)
        let startCompsAfter = calendar.dateComponents([.year, .month, .day, .hour], from: dayStartAfter)
        assertEqual(startCompsAfter.year, 2026)
        assertEqual(startCompsAfter.month, 10)
        assertEqual(startCompsAfter.day, 24) // Starts on Oct 24 at 4:00 AM
        assertEqual(startCompsAfter.hour, 4)
    }

    // MARK: - 7. Queue Builder: Scope Filtering, Limits, and Ordering
    func testQueueBuilderScopeFilteringAndLimits() {
        reset()
        let vocab1 = VocabItem(
            id: "vocab-1",
            textbook: .minnaNoNihongo,
            bookNumber: 1,
            chapterNumber: 1,
            number: 1,
            japanese: "いく",
            kanji: "行く",
            kana: "いく",
            romaji: "iku",
            meaning: "to go",
            wordType: .verb(.group1),
            jlptLevel: .n5,
            categoryTag: "verb"
        )
        let vocab2 = VocabItem(
            id: "vocab-2",
            textbook: .minnaNoNihongo,
            bookNumber: 1,
            chapterNumber: 1,
            number: 2,
            japanese: "くる",
            kanji: "来る",
            kana: "くる",
            romaji: "kuru",
            meaning: "to come",
            wordType: .verb(.group3),
            jlptLevel: .n5,
            categoryTag: "verb"
        )
        let vocab3 = VocabItem(
            id: "vocab-3",
            textbook: .minnaNoNihongo,
            bookNumber: 1,
            chapterNumber: 2,
            number: 1,
            japanese: "たべる",
            kanji: "食べる",
            kana: "たべる",
            romaji: "taberu",
            meaning: "to eat",
            wordType: .verb(.group2),
            jlptLevel: .n5,
            categoryTag: "verb"
        )
        let allVocab = [vocab1, vocab2, vocab3]

        // Scope Chapter 1
        let queueCh1 = SRSQueueBuilder.buildQueue(
            scope: .chapter(1),
            vocabItems: allVocab,
            cardStates: [:],
            reviewLogs: [],
            now: baseDate,
            config: config
        )
        assertEqual(queueCh1.count, 2)
        assertTrue(queueCh1.allSatisfy { $0.vocabItem.chapterNumber == 1 }, "All items belong to Ch 1")

        // Scope Chapter 2
        let queueCh2 = SRSQueueBuilder.buildQueue(
            scope: .chapter(2),
            vocabItems: allVocab,
            cardStates: [:],
            reviewLogs: [],
            now: baseDate,
            config: config
        )
        assertEqual(queueCh2.count, 1)
        assertEqual(queueCh2.first?.vocabItem.id, "vocab-3")

        // Scope Selected [1, 2]
        let queueSelected = SRSQueueBuilder.buildQueue(
            scope: .selected([1, 2]),
            vocabItems: allVocab,
            cardStates: [:],
            reviewLogs: [],
            now: baseDate,
            config: config
        )
        assertEqual(queueSelected.count, 3)

        // Daily new limit test (set newCardsPerDay = 1)
        var limitConfig = config
        limitConfig.newCardsPerDay = 1
        let queueCapped = SRSQueueBuilder.buildQueue(
            scope: .all,
            vocabItems: allVocab,
            cardStates: [:],
            reviewLogs: [],
            now: baseDate,
            config: limitConfig
        )
        assertEqual(queueCapped.count, 1)
        assertEqual(queueCapped.first?.vocabItem.id, "vocab-1") // Chapter 1, entry 1
    }

    // MARK: - 8. Queue Builder Priority Ordering
    func testQueuePriorityOrdering() {
        reset()
        let vLearn = VocabItem(id: "v-learn", textbook: .minnaNoNihongo, bookNumber: 1, chapterNumber: 1, number: 1, japanese: "A", kanji: nil, kana: "A", romaji: "a", meaning: "a", wordType: .noun, jlptLevel: .n5, categoryTag: "")
        let vReview = VocabItem(id: "v-review", textbook: .minnaNoNihongo, bookNumber: 1, chapterNumber: 1, number: 2, japanese: "B", kanji: nil, kana: "B", romaji: "b", meaning: "b", wordType: .noun, jlptLevel: .n5, categoryTag: "")
        let vNew = VocabItem(id: "v-new", textbook: .minnaNoNihongo, bookNumber: 1, chapterNumber: 1, number: 3, japanese: "C", kanji: nil, kana: "C", romaji: "c", meaning: "c", wordType: .noun, jlptLevel: .n5, categoryTag: "")

        let cardStates: [String: CardState] = [
            "v-learn:jp_meaning": CardState(cardId: "v-learn:jp_meaning", state: .learning, due: baseDate.addingTimeInterval(-60)),
            "v-review:jp_meaning": CardState(cardId: "v-review:jp_meaning", state: .review, due: baseDate.addingTimeInterval(-3600)),
            "v-new:jp_meaning": CardState(cardId: "v-new:jp_meaning", state: .new)
        ]

        let queue = SRSQueueBuilder.buildQueue(
            scope: .all,
            vocabItems: [vNew, vReview, vLearn],
            cardStates: cardStates,
            reviewLogs: [],
            now: baseDate,
            config: config
        )

        assertEqual(queue.count, 3)
        // 1. Learning due
        assertEqual(queue[0].cardState.state, .learning)
        assertEqual(queue[0].vocabItem.id, "v-learn")
        // 2. Review due
        assertEqual(queue[1].cardState.state, .review)
        assertEqual(queue[1].vocabItem.id, "v-review")
        // 3. New
        assertEqual(queue[2].cardState.state, .new)
        assertEqual(queue[2].vocabItem.id, "v-new")
    }

    // MARK: - 9. Single Source of Truth: Review in "Chapter 1" scope updates "All" scope
    func testSingleSourceOfTruthAcrossScopes() {
        reset()
        let vocab1 = VocabItem(id: "vocab-shared", textbook: .minnaNoNihongo, bookNumber: 1, chapterNumber: 1, number: 1, japanese: "みず", kanji: "水", kana: "みず", romaji: "mizu", meaning: "water", wordType: .noun, jlptLevel: .n5, categoryTag: "")

        // Single in-memory repository (source of truth)
        var cardStatesRepository: [String: CardState] = [:]

        // Check initial state in "Chapter 1" scope
        let initialCh1Queue = SRSQueueBuilder.buildQueue(
            scope: .chapter(1),
            vocabItems: [vocab1],
            cardStates: cardStatesRepository,
            reviewLogs: [],
            now: baseDate,
            config: config
        )
        assertEqual(initialCh1Queue.first?.cardState.state, .new)

        // Review card while inside "Chapter 1" scope
        let reviewedCard = SRSScheduler.schedule(
            card: initialCh1Queue.first!.cardState,
            rating: .good,
            now: baseDate,
            config: config
        )

        // Update single source of truth
        cardStatesRepository[reviewedCard.cardId] = reviewedCard

        // Now query from "All" scope
        let allQueue = SRSQueueBuilder.buildQueue(
            scope: .all,
            vocabItems: [vocab1],
            cardStates: cardStatesRepository,
            reviewLogs: [],
            now: baseDate.addingTimeInterval(600), // 10 minutes later (when due)
            config: config
        )

        // The card in "All" scope reflects the review performed in "Chapter 1" scope
        assertEqual(allQueue.first?.cardState.state, .learning)
        assertEqual(allQueue.first?.cardState.stepIndex, 1)
        assertEqual(allQueue.first?.cardState.reps, 1)
    }

    // MARK: - 10. Projected Intervals for UI
    func testProjectedIntervals() {
        reset()
        let newCard = CardState(cardId: "entry:test", state: .new)
        let projections = SRSScheduler.projectedIntervals(card: newCard, now: baseDate, config: config)

        assertEqual(projections[.again]?.displayInterval, "1m")
        assertEqual(projections[.hard]?.displayInterval, "6m") // (1 + 10)/2 = 5.5m -> rounded to 6m
        assertEqual(projections[.good]?.displayInterval, "10m")
        assertEqual(projections[.easy]?.displayInterval, "4d")
    }

    // MARK: - 11. FSRS Initial State & Interval Growth
    func testFSRSInitialStateAndGrowth() {
        reset()
        var fsrsConfig = config
        fsrsConfig.algorithm = .fsrs
        fsrsConfig.fsrsRequestRetention = 0.90

        let newCard = CardState(cardId: "fsrs:new", state: .new)

        // Rating Good on new card with FSRS
        let cardGood = FSRSScheduler.schedule(card: newCard, rating: .good, now: baseDate, config: fsrsConfig)
        assertEqual(cardGood.state, CardStateEnum.review)
        // Default initial stability for Good is w2 ≈ 3.17 days
        assertTrue(cardGood.intervalDays >= 3.0 && cardGood.intervalDays <= 3.3, "FSRS Good stability should be ~3.17d")
        assertTrue(cardGood.ease >= 1.0 && cardGood.ease <= 10.0, "FSRS difficulty should be clamped 1..10")

        // Rating Easy on new card with FSRS
        let cardEasy = FSRSScheduler.schedule(card: newCard, rating: .easy, now: baseDate, config: fsrsConfig)
        assertEqual(cardEasy.state, CardStateEnum.review)
        // Default initial stability for Easy is w3 ≈ 15.69 days
        assertTrue(cardEasy.intervalDays >= 15.0 && cardEasy.intervalDays <= 16.0, "FSRS Easy stability should be ~15.69d")

        // Review cardGood 3 days later with rating Good -> stability should increase
        let reviewDate = baseDate.addingTimeInterval(3.0 * 86400.0)
        let cardReviewed = FSRSScheduler.schedule(card: cardGood, rating: .good, now: reviewDate, config: fsrsConfig)
        assertEqual(cardReviewed.state, CardStateEnum.review)
        assertTrue(cardReviewed.intervalDays > cardGood.intervalDays, "Stability should increase after successful recall")
    }

    // MARK: - 12. FSRS Retrievability Curve & Lapse
    func testFSRSRetrievabilityAndLapse() {
        // At t = 0, R = 1.0
        let r0 = FSRSScheduler.calculateRetrievability(elapsedDays: 0, stability: 10.0)
        assertEqualDouble(r0, 1.0, accuracy: 0.001)

        // At t = S, R should be approximately 0.90
        let rS = FSRSScheduler.calculateRetrievability(elapsedDays: 10.0, stability: 10.0)
        assertEqualDouble(rS, 0.90, accuracy: 0.02)

        // Lapse with Again
        var fsrsConfig = config
        fsrsConfig.algorithm = .fsrs
        let reviewCard = CardState(cardId: "fsrs:lapse", state: .review, intervalDays: 20.0, ease: 5.0, reps: 4, lastReviewedAt: baseDate)
        let lapseDate = baseDate.addingTimeInterval(20.0 * 86400.0)

        let lapsed = FSRSScheduler.schedule(card: reviewCard, rating: .again, now: lapseDate, config: fsrsConfig)
        assertEqual(lapsed.state, CardStateEnum.relearning)
        assertEqual(lapsed.lapses, 1)
        assertTrue(lapsed.intervalDays < reviewCard.intervalDays, "Stability should drop after lapse")
    }

    // MARK: - 13. Dynamic Algorithm Swapping Without Storage Changes
    func testEngineAlgorithmSwappingWithoutStorageChanges() {
        reset()
        let card = CardState(cardId: "shared:card", state: .review, intervalDays: 10.0, ease: 2.5, reps: 2, lastReviewedAt: baseDate)
        let reviewDate = baseDate.addingTimeInterval(10.0 * 86400.0)

        // 1. Run using SM-2
        var sm2Config = config
        sm2Config.algorithm = .sm2
        let sm2Result = SRSEngine.schedule(card: card, rating: .good, now: reviewDate, config: sm2Config)
        assertEqual(sm2Result.state, CardStateEnum.review)
        assertEqualDouble(sm2Result.intervalDays, 25.0, accuracy: 0.1) // 10 * 2.5

        // 2. Run exact same CardState using FSRS
        var fsrsConfig = config
        fsrsConfig.algorithm = .fsrs
        let fsrsResult = SRSEngine.schedule(card: card, rating: .good, now: reviewDate, config: fsrsConfig)
        assertEqual(fsrsResult.state, CardStateEnum.review)
        assertTrue(fsrsResult.intervalDays > 10.0, "FSRS should calculate next interval")

        // 3. Proves CardState schema requires zero changes between algorithms
        assertEqual(sm2Result.cardId, fsrsResult.cardId)
    }

    // MARK: - Chapter 01 Order & Reset Tests
    func testChapter01DataLoadingAndOrder() {
        guard let items = VocabDataService.shared.loadChapter01Items() else {
            fatalError("Failed to load chapter_01.json")
        }
        assertEqual(items.count, 75, "Chapter 1 must have exactly 75 entries")
        assertEqual(items[0].number, 1, "First item must be number 1")
        assertEqual(items[0].japanese, "わたし", "First item must be わたし")
        assertEqual(items[74].number, 75, "Last item must be number 75")

        for (idx, item) in items.enumerated() {
            assertEqual(item.number, idx + 1, "Items must be in exact sequential order 1..75")
            assertEqual(item.chapterNumber, 1, "Chapter must be 1")
        }
    }

    func testResetProgressAndStatsKeepVocab() {
        let service = VocabDataService.shared
        assertTrue(!service.items.isEmpty, "Vocab items must not be empty")
        let initialCount = service.items.count

        // Simulate study progress
        service.updateWordProgress(id: service.items[0].id, learningState: .knownDirectly, isCorrect: true)
        SRSStorageService.shared.recordReview(cardId: "card_test_01", rating: .good, durationMs: 1200, scope: "c1")

        // Execute reset
        service.resetProgressAndStatsKeepVocab()

        // Verify words stay intact
        assertEqual(service.items.count, initialCount, "Total vocabulary count must remain intact")
        assertEqual(service.items[0].learningState, .unseen, "Progress must be reset to unseen")
        assertEqual(service.items[0].currentStreak, 0, "Streak must be reset to 0")
        assertEqual(service.items[0].bestStreak, 0, "Best streak must be reset to 0")

        // Verify SRS stats are reset
        assertEqual(SRSStorageService.shared.cardStates.count, 0, "SRS card states must be reset")
        assertEqual(SRSStorageService.shared.reviewLogs.count, 0, "SRS review logs must be reset")
    }

    // MARK: - 16. Particle Database 188 Source Entries, Validation, and Idempotent Import
    func testParticleDatabaseValidationAndIdempotentImport() {
        let particleService = ParticleDataService.shared
        let grammarService = GrammarDataService.shared

        assertTrue(!particleService.particles.isEmpty, "Particles must be loaded")
        assertEqual(particleService.sourceEntries.count, 188, "Must have all 188 source entries")
        assertTrue(VocabDataService.shared.items.count >= 1300, "Must bundle 1,300+ N5 & N4 vocabulary words across Chapters 1–50")
        assertEqual(VocabDataService.shared.availableChapters.count, 50, "Must load all 50 vocabulary chapters (Book 1 N5 + Book 2 N4)")
        assertTrue(grammarService.grammarPoints.count >= 500, "Must bundle 500+ N5 & N4 grammar points from OpenJLPT, jkindrix, and hanabira.org")

        // Verify sourceNumbers 1...188 are present and sequential
        let numbers = particleService.sourceEntries.map(\.sourceNumber).sorted()
        assertEqual(numbers.first, 1, "First source number must be 1")
        assertEqual(numbers.last, 188, "Last source number must be 188")

        // Verify validation rules pass with zero errors
        let grammarIds = Set(grammarService.grammarPoints.map(\.id))
        let validation = particleService.validateDatabase(
            particleService.database,
            knownGrammarPointIds: grammarIds
        )
        assertTrue(validation.isValid, "Particle database must pass all Section 6 validation rules: \(validation.errors)")
        assertEqual(validation.errors.count, 0, "Validation errors must be empty")

        // Verify unreviewed entries do not fabricate JLPT levels or unverified examples
        let unreviewedUsageIds = Set(
            particleService.sourceEntries
                .filter { $0.reviewStatus == .unreviewed }
                .map(\.usageId)
        )
        assertTrue(!unreviewedUsageIds.isEmpty, "Some source entries should remain unreviewed")
        for usage in particleService.usages where unreviewedUsageIds.contains(usage.id) {
            assertTrue(usage.jlptLevel == nil, "Unreviewed usage \(usage.id) must keep jlptLevel == nil")
            assertTrue(usage.examples.isEmpty, "Unreviewed usage \(usage.id) must not fabricate examples")
        }

        // Verify particle-ni has separate usages (ni-location, ni-time, etc.)
        guard let niParticle = particleService.particle(forId: "particle-ni") else {
            fatalError("Expected particle-ni in database")
        }
        let niUsageIds = Set(niParticle.usageIds)
        assertTrue(niUsageIds.contains("ni-location"), "particle-ni must include ni-location")
        assertTrue(niUsageIds.contains("ni-time"), "particle-ni must include ni-time")

        // Record progress on ni-location, then re-import database idempotently
        let niLocRef = particleService.reference(particleId: "particle-ni", usageId: "ni-location")
        particleService.updateProgress(
            for: niLocRef,
            learningState: .knownDirectly,
            difficulty: .easy,
            isCorrect: true
        )
        let particleCountBefore = particleService.particles.count
        let usageCountBefore = particleService.usages.count

        let reimportValidation = particleService.importDatabase(particleService.database)
        assertTrue(reimportValidation.isValid, "Re-importing particle database must succeed")
        assertEqual(particleService.particles.count, particleCountBefore, "Idempotent import must not duplicate particles")
        assertEqual(particleService.usages.count, usageCountBefore, "Idempotent import must not duplicate usages")
        assertEqual(
            particleService.progress(particleId: "particle-ni", usageId: "ni-location").learningState,
            .knownDirectly,
            "Idempotent import must preserve existing user progress"
        )
    }

    // MARK: - 17. Independent SRS Scheduling for Particle Usages & Grammar Variants
    func testIndependentDomainSRSScheduling() {
        reset()
        VocabDataService.shared.resetProgressAndStatsKeepVocab()

        let niLocationRef = LearningItemReference(domain: .particles, contentId: "particle-ni", subContentId: "ni-location")
        let niTimeRef = LearningItemReference(domain: .particles, contentId: "particle-ni", subContentId: "ni-time")
        assertFalse(niLocationRef.reviewIdentityKey == niTimeRef.reviewIdentityKey, "Two usages of same particle must have distinct review identity keys")

        // Verify CardDirection.parse works cleanly with canonical review identity keys
        let niLocCardId = CardDirection.cardId(entryId: niLocationRef.reviewIdentityKey, direction: .jpToMeaning)
        let parsed = CardDirection.parse(cardId: niLocCardId)
        assertEqual(parsed?.entryId, niLocationRef.reviewIdentityKey, "CardDirection.parse must preserve reviewIdentityKey")
        assertEqual(parsed?.direction, .jpToMeaning, "CardDirection.parse must preserve direction")

        // Schedule ni-location as Hard (.again) and ni-time as Easy (.easy)
        LearningItemResolver.recordReviewOutcome(
            reference: niLocationRef,
            rating: .again,
            durationSeconds: 0.9,
            scopeIdentifier: "test_particles",
            now: baseDate
        )
        LearningItemResolver.recordReviewOutcome(
            reference: niTimeRef,
            rating: .easy,
            durationSeconds: 0.6,
            scopeIdentifier: "test_particles",
            now: baseDate
        )

        let niLocState = SRSStorageService.shared.getCardState(for: niLocationRef.reviewIdentityKey)
        let niTimeState = SRSStorageService.shared.getCardState(for: niTimeRef.reviewIdentityKey)

        assertEqual(niLocState.state, .learning, "ni-location rated .again should be in learning")
        assertEqual(niTimeState.state, .review, "ni-time rated .easy should graduate to review")
        assertTrue(niTimeState.intervalDays > niLocState.intervalDays, "ni-time interval must be independent of ni-location")

        // Verify domain progress is also tracked independently per usage
        assertEqual(
            ParticleDataService.shared.progress(particleId: "particle-ni", usageId: "ni-location").difficulty,
            .hard,
            "ni-location difficulty should be .hard"
        )
        assertEqual(
            ParticleDataService.shared.progress(particleId: "particle-ni", usageId: "ni-time").difficulty,
            .easy,
            "ni-time difficulty should be .easy"
        )

        // Verify Grammar variants also schedule independently
        let desuAffRef = LearningItemReference(domain: .grammar, contentId: "grammar-desu", subContentId: "desu-present-aff")
        let desuNegRef = LearningItemReference(domain: .grammar, contentId: "grammar-desu", subContentId: "desu-present-neg")
        LearningItemResolver.recordReviewOutcome(
            reference: desuAffRef,
            rating: .good,
            durationSeconds: 0.8,
            scopeIdentifier: "test_grammar",
            now: baseDate
        )

        let desuAffState = SRSStorageService.shared.getCardState(for: desuAffRef.reviewIdentityKey)
        let desuNegState = SRSStorageService.shared.getCardState(for: desuNegRef.reviewIdentityKey)
        assertEqual(desuAffState.reps, 1, "Reviewed grammar variant must have 1 rep")
        assertEqual(desuNegState.state, CardStateEnum.new, "Unreviewed sibling grammar variant must remain .new")

        // Verify SRSQueueBuilder.buildDomainQueue builds independent queue items for particle usages
        let domainQueue = SRSQueueBuilder.buildDomainQueue(
            references: [niLocationRef, niTimeRef],
            cardStates: SRSStorageService.shared.cardStates,
            reviewLogs: SRSStorageService.shared.reviewLogs,
            now: baseDate.addingTimeInterval(120), // 2 minutes later so learning card (1m) is due
            config: config
        )
        assertEqual(domainQueue.count, 1, "Only due ni-location should appear in queue 2m later")
        assertEqual(domainQueue.first?.reference, niLocationRef, "Due queue item must be ni-location")
    }

    // MARK: - 18. Shared LearningTestService: Question Generation, Answer Key Stripping, SRS Mistake Flow, and Idempotency
    func testLearningTestServiceFlowAndIdempotency() {
        reset()
        VocabDataService.shared.resetProgressAndStatsKeepVocab()
        let testService = LearningTestService.shared

        // 1. Test Particle usage with verified example vs unverified example
        guard let unverifiedUsage = ParticleDataService.shared.usages.first(where: { $0.examples.isEmpty }),
              let unverifiedParticle = ParticleDataService.shared.particle(forUsageId: unverifiedUsage.id) else {
            fatalError("Expected at least one unverified usage without examples")
        }
        let unverifiedUsageRef = LearningItemReference(
            domain: .particles,
            contentId: unverifiedParticle.id,
            subContentId: unverifiedUsage.id
        )

        let (sessionId, publicQuestions) = testService.startSession(
            scope: LearningTestScope(
                domains: [.particles],
                particleUsageIds: ["ni-location", unverifiedUsage.id],
                questionCount: 10
            ),
            preferredQuestionType: .particleFillBlank
        )

        assertEqual(publicQuestions.count, 2, "Must generate questions for the 2 requested usages")

        // Unverified usage without examples must NEVER generate .particleFillBlank
        if let unverifiedQ = publicQuestions.first(where: { $0.reference == unverifiedUsageRef }) {
            assertFalse(
                unverifiedQ.questionType == .particleFillBlank,
                "Usage without verified examples must not generate fill-in-the-blank question"
            )
        }

        // Verified usage with examples should generate .particleFillBlank when requested
        if let verifiedQ = publicQuestions.first(where: { $0.reference.subContentId == "ni-location" }) {
            assertEqual(
                verifiedQ.questionType,
                .particleFillBlank,
                "Verified usage with example sentence must support fill-in-the-blank"
            )
        }

        // Verify public question has options and non-empty prompt
        let firstQ = publicQuestions[0]
        assertTrue(!firstQ.prompt.isEmpty, "Question prompt must not be empty")
        assertTrue(firstQ.options.count >= 2, "Question must have multiple choice options")

        // 2. Submit a wrong answer and verify SRS mistake scheduling + idempotency
        let logsBefore = SRSStorageService.shared.reviewLogs.count
        guard let wrongRecord = testService.submitAnswer(
            sessionId: sessionId,
            questionId: firstQ.id,
            submittedAnswer: "__DEFINITELY_WRONG_ANSWER__",
            durationSeconds: 1.1,
            now: baseDate
        ) else {
            fatalError("submitAnswer must return a record")
        }

        assertFalse(wrongRecord.isCorrect, "Intentionally wrong answer must be marked incorrect")
        let logsAfterFirstSubmit = SRSStorageService.shared.reviewLogs.count
        assertEqual(logsAfterFirstSubmit, logsBefore + 1, "Mistake in test must record 1 SRS review event")

        // 3. Submit the SAME question a second time -> must return existing record without duplicating SRS review logs
        guard let duplicateSubmitRecord = testService.submitAnswer(
            sessionId: sessionId,
            questionId: firstQ.id,
            submittedAnswer: firstQ.options.first ?? "",
            durationSeconds: 0.5,
            now: baseDate
        ) else {
            fatalError("Repeated submitAnswer must return the existing record")
        }
        assertEqual(duplicateSubmitRecord.id, wrongRecord.id, "Repeated submission must return identical answer record")
        assertEqual(
            SRSStorageService.shared.reviewLogs.count,
            logsAfterFirstSubmit,
            "Repeated submission must NOT create duplicate SRS review events"
        )

        // 4. Inspecting session results multiple times must never re-submit or re-schedule
        let result1 = testService.getSessionResult(sessionId: sessionId)
        let result2 = testService.getSessionResult(sessionId: sessionId)
        assertEqual(result1?.wrongCount, 1, "Session result must report 1 wrong answer")
        assertEqual(result1?.answers.count, result2?.answers.count, "Result inspection must be deterministic")
        assertEqual(
            SRSStorageService.shared.reviewLogs.count,
            logsAfterFirstSubmit,
            "Viewing test results must not trigger additional SRS review logs"
        )

        // Clean up test session
        VocabDataService.shared.resetProgressAndStatsKeepVocab()
    }

    // MARK: - 19. Exam Chapter-Wise Filtering, Available Count Notice, and Passage Grouping
    func testExamChapterFilteringAndPassageGrouping() {
        reset()
        let examService = ExamService.shared
        examService.resetExamAttempts()

        // 1. Chapter 1 questions must belong ONLY to Chapter 1
        let ch1Pool = examService.availableChapterQuestions(
            level: .n5,
            chapters: [1],
            categories: [.vocabulary, .kanji, .grammar]
        )
        assertTrue(!ch1Pool.isEmpty, "Chapter 1 must generate questions from in-app study data")
        assertTrue(
            ch1Pool.allSatisfy { $0.chapterIds.contains(1) },
            "Every question in a Chapter 1 test must be tagged to Chapter 1"
        )

        // 2. Requesting a non-existent chapter (e.g. Chapter 99) must NOT pull questions from other chapters
        let (emptyAttempt, emptyCount, emptyNotice) = examService.startChapterWiseTest(
            level: .n5,
            chapters: [99],
            categories: [.vocabulary, .kanji, .grammar],
            requestedQuestionCount: 10,
            durationSeconds: nil,
            deliveryMode: .exam
        )
        assertTrue(emptyAttempt == nil, "Chapter 99 with 0 items must not silently pull from other chapters")
        assertEqual(emptyCount, 0, "Available count for empty chapter must be 0")
        assertTrue(emptyNotice != nil, "Must provide explanatory notice when no questions are available")

        // 3. Requesting more questions than available in Chapter 1 must explain available count and cap cleanly
        let (cappedAttempt, availableCount, cappedNotice) = examService.startChapterWiseTest(
            level: .n5,
            chapters: [1],
            categories: [.kanji],
            requestedQuestionCount: 500,
            durationSeconds: 600,
            deliveryMode: .exam
        )
        assertTrue(cappedAttempt != nil, "Chapter 1 Kanji test must be created")
        assertEqual(cappedAttempt?.questions.count, availableCount, "Test must use only the available chapter questions")
        assertTrue(cappedNotice != nil, "Must explain available count when fewer questions exist than requested")

        // 4. Passage-grouped questions must stay contiguous
        let readingPool = examService.availableSectionQuestions(level: .n5, category: .reading)
        let passageGroupIds = readingPool.compactMap(\.passageGroupId)
        assertTrue(passageGroupIds.count >= 2, "Reading bank must include multi-question passage groups")
        if let firstGroup = passageGroupIds.first {
            let indices = readingPool.enumerated().compactMap { $0.element.passageGroupId == firstGroup ? $0.offset : nil }
            if indices.count == 2 {
                assertEqual(indices[1] - indices[0], 1, "Dependent passage questions must be kept together")
            }
        }

        examService.resetExamAttempts()
    }

    // MARK: - 20. Full-Length Exam: Resume Safety, Flagging, Timeout Auto-Submit, Manual Submit & Retry
    func testFullLengthExamResumeScoringTimeoutAndRetry() {
        reset()
        VocabDataService.shared.resetProgressAndStatsKeepVocab()
        let examService = ExamService.shared

        guard let n5Paper = examService.fullLengthExams.first(where: { $0.level == .n5 }) else {
            fatalError("Expected N5 full-length paper")
        }
        assertTrue(examService.fullLengthExams.count >= 12, "Must load at least 12 full-length mock exam papers (7 N5 + 5 N4)")
        assertEqual(examService.sectionPapers.count, 58, "Must load 58 dedicated section-wise exam papers (N5 Moji/Goi/Bunpou/Dokkai/Listening + N4 Moji/Goi/Bunpou/Dokkai/Listening)")
        assertEqual(examService.chapterPapers.count, 60, "Must load 60 dedicated chapter exam papers (10 5-chapter blocks + 50 individual chapter papers Ch. 1–50)")
        assertEqual(examService.availableChapters.count, 50, "Must support all 50 Minna no Nihongo chapters (Ch. 1–25 N5 + Ch. 26–50 N4)")
        for n4Ch in 26...50 {
            let n4ChQs = examService.availableChapterQuestions(level: .n4, chapters: [n4Ch], categories: [.vocabulary, .kanji, .grammar])
            assertTrue(n4ChQs.count >= 20, "N4 Chapter \(n4Ch) must have at least 20 verified chapter-wise questions")
        }
        assertTrue(examService.originalQuestionBank.count >= 1400, "Must load 1,400+ verified exam questions from jlpt_exam_bank.json")
        assertTrue(n5Paper.questionIds.count >= 50, "Full-length N5 mock paper must contain a full exam paper set (50+ questions)")

        // Verify launching a bundled Section Paper and a bundled Chapter Paper
        if let firstSecPaper = examService.sectionPapers.first {
            let secAttempt = examService.startFullLengthExam(paper: firstSecPaper, isTimed: true, deliveryMode: .exam)
            assertEqual(secAttempt.kind, .section, "Bundled section paper must launch with .section kind")
            assertTrue(secAttempt.questions.count >= 8, "Bundled section paper must contain its full question set")
        }
        if let firstChPaper = examService.chapterPapers.first {
            let chAttempt = examService.startFullLengthExam(paper: firstChPaper, isTimed: false, deliveryMode: .practice)
            assertEqual(chAttempt.kind, .chapter, "Bundled chapter paper must launch with .chapter kind")
            assertTrue(chAttempt.questions.count >= 20, "Bundled chapter paper must contain its full chapter question set")
            assertTrue(!chAttempt.selectedChapters.isEmpty, "Bundled chapter paper must record its covered chapters")
        }

        // 1. Start timed full-length N5 exam
        let attempt = examService.startFullLengthExam(paper: n5Paper, isTimed: true, deliveryMode: .exam)
        assertEqual(attempt.status, .inProgress, "New attempt must start in_progress")
        assertTrue(!attempt.questions.isEmpty, "Full-length exam must have questions")
        assertEqual(attempt.reviewItems.count, 0, "Exam mode must hide review items / answer keys before submission")

        let q0 = attempt.questions[0]
        let q1 = attempt.questions[1]
        guard let verifiedQ0 = examService.verifiedQuestion(forId: q0.id),
              let verifiedQ1 = examService.verifiedQuestion(forId: q1.id) else {
            fatalError("Verified questions must exist in registry")
        }

        // 2. Select an answer on q0, then change it to the verified correct answer; select wrong answer on q1; leave rest unanswered
        let wrongChoice0 = q0.choices.first { $0 != verifiedQ0.correctAnswer } ?? "__wrong__"
        _ = examService.selectAnswer(attemptId: attempt.id, questionId: q0.id, choice: wrongChoice0)
        // Change answer on q0 to correct answer
        _ = examService.selectAnswer(attemptId: attempt.id, questionId: q0.id, choice: verifiedQ0.correctAnswer)

        let wrongChoice1 = q1.choices.first { $0 != verifiedQ1.correctAnswer } ?? "__wrong__"
        _ = examService.selectAnswer(attemptId: attempt.id, questionId: q1.id, choice: wrongChoice1)

        // Flag q1 and save timer/index progress
        _ = examService.toggleFlag(attemptId: attempt.id, questionId: q1.id)
        examService.updateProgressState(attemptId: attempt.id, currentQuestionIndex: 2, elapsedSeconds: 340)

        // 3. Verify resume-safety: calling startFullLengthExam again for the same paper returns the in-progress attempt without resetting timer or reshuffling questions
        let resumed = examService.startFullLengthExam(paper: n5Paper, isTimed: true, deliveryMode: .exam)
        assertEqual(resumed.id, attempt.id, "Resuming must return the same in-progress attempt")
        assertEqual(resumed.elapsedSeconds, 340, "Resuming must preserve elapsed time")
        assertEqual(resumed.currentQuestionIndex, 2, "Resuming must preserve current question index")
        assertEqual(resumed.questions.map(\.id), attempt.questions.map(\.id), "Resuming must not reshuffle questions")
        assertTrue(resumed.flaggedQuestionIds.contains(q1.id), "Resuming must preserve flagged questions")
        assertEqual(resumed.selectedAnswers[q0.id], verifiedQ0.correctAnswer, "Resuming must preserve changed answer")

        // 4. Submit via timeout auto-submission and verify scoring, unanswered count, section breakdown, and idempotency
        guard let submitted = examService.submitAttempt(attemptId: attempt.id, didTimeout: true, now: baseDate) else {
            fatalError("submitAttempt must return submitted attempt")
        }
        assertEqual(submitted.status, .timedOut, "Timeout submission must mark status as .timedOut")
        assertEqual(submitted.correctCount, 1, "Must count 1 correct answer (q0)")
        assertEqual(submitted.incorrectCount, 1, "Must count 1 incorrect answer (q1)")
        assertEqual(submitted.unansweredCount, submitted.totalQuestions - 2, "Remaining questions must be counted as unanswered")
        assertTrue(!submitted.sectionResults.isEmpty, "Submitted exam must compute section breakdown")
        assertEqual(submitted.reviewItems.count, submitted.totalQuestions, "Submitted exam must reveal verified answers and explanations")

        // Calling submitAttempt a second time must be idempotent
        let logsAfterSubmit = SRSStorageService.shared.reviewLogs.count
        let duplicateSubmit = examService.submitAttempt(attemptId: attempt.id, didTimeout: false, now: baseDate)
        assertEqual(duplicateSubmit?.status, .timedOut, "Repeated submit must not overwrite status")
        assertEqual(SRSStorageService.shared.reviewLogs.count, logsAfterSubmit, "Repeated submit must not duplicate SRS review logs")

        // 5. Retry incorrect/missed questions
        guard let retryAttempt = examService.retryIncorrectQuestions(from: submitted.id) else {
            fatalError("retryIncorrectQuestions must create a retry attempt for missed items")
        }
        assertEqual(retryAttempt.questions.count, submitted.totalQuestions - 1, "Retry attempt must include only incorrect and unanswered questions")
        assertFalse(retryAttempt.questions.contains(where: { $0.id == q0.id }), "Retry attempt must exclude already-correct q0")

        VocabDataService.shared.resetProgressAndStatsKeepVocab()
    }

    // MARK: - Runner
    static func runAllTests() {
        let suite = SRSSchedulerTests()
        print("▶ Running testNewToLearningProgressionAndGraduation...")
        suite.testNewToLearningProgressionAndGraduation()
        print("  ✓ Passed")

        print("▶ Running testLapseToRelearningAndRegraduation...")
        suite.testLapseToRelearningAndRegraduation()
        print("  ✓ Passed")

        print("▶ Running testEaseBoundsAndUpdates...")
        suite.testEaseBoundsAndUpdates()
        print("  ✓ Passed")

        print("▶ Running testIntervalGrowth...")
        suite.testIntervalGrowth()
        print("  ✓ Passed")

        print("▶ Running testFuzzBounds...")
        suite.testFuzzBounds()
        print("  ✓ Passed")

        print("▶ Running testDayRolloverCalculation...")
        suite.testDayRolloverCalculation()
        print("  ✓ Passed")

        print("▶ Running testQueueBuilderScopeFilteringAndLimits...")
        suite.testQueueBuilderScopeFilteringAndLimits()
        print("  ✓ Passed")

        print("▶ Running testQueuePriorityOrdering...")
        suite.testQueuePriorityOrdering()
        print("  ✓ Passed")

        print("▶ Running testSingleSourceOfTruthAcrossScopes...")
        suite.testSingleSourceOfTruthAcrossScopes()
        print("  ✓ Passed")

        print("▶ Running testProjectedIntervals...")
        suite.testProjectedIntervals()
        print("  ✓ Passed")

        print("▶ Running testFSRSInitialStateAndGrowth...")
        suite.testFSRSInitialStateAndGrowth()
        print("  ✓ Passed")

        print("▶ Running testFSRSRetrievabilityAndLapse...")
        suite.testFSRSRetrievabilityAndLapse()
        print("  ✓ Passed")

        print("▶ Running testEngineAlgorithmSwappingWithoutStorageChanges...")
        suite.testEngineAlgorithmSwappingWithoutStorageChanges()
        print("  ✓ Passed")

        print("▶ Running testChapter01DataLoadingAndOrder...")
        suite.testChapter01DataLoadingAndOrder()
        print("  ✓ Passed")

        print("▶ Running testResetProgressAndStatsKeepVocab...")
        suite.testResetProgressAndStatsKeepVocab()
        print("  ✓ Passed")

        print("▶ Running testParticleDatabaseValidationAndIdempotentImport...")
        suite.testParticleDatabaseValidationAndIdempotentImport()
        print("  ✓ Passed")

        print("▶ Running testIndependentDomainSRSScheduling...")
        suite.testIndependentDomainSRSScheduling()
        print("  ✓ Passed")

        print("▶ Running testLearningTestServiceFlowAndIdempotency...")
        suite.testLearningTestServiceFlowAndIdempotency()
        print("  ✓ Passed")

        print("▶ Running testExamChapterFilteringAndPassageGrouping...")
        suite.testExamChapterFilteringAndPassageGrouping()
        print("  ✓ Passed")

        print("▶ Running testFullLengthExamResumeScoringTimeoutAndRetry...")
        suite.testFullLengthExamResumeScoringTimeoutAndRetry()
        print("  ✓ Passed")

        print("\n🎉 ALL 20 TESTS (SM-2 + FSRS + ENGINE SWAP + CH1 ORDER + STATS RESET + PARTICLES 188 + DOMAIN SRS + TEST ENGINE + EXAM SECTION) PASSED SUCCESSFULLY!")
    }
}
