import Foundation

// MARK: - Next Review Projection
public struct SRSProjection: Equatable {
    public let rating: SRSRating
    public let nextState: CardStateEnum
    public let nextIntervalDays: Double
    public let nextDue: Date
    public let displayInterval: String

    public init(
        rating: SRSRating,
        nextState: CardStateEnum,
        nextIntervalDays: Double,
        nextDue: Date,
        displayInterval: String
    ) {
        self.rating = rating
        self.nextState = nextState
        self.nextIntervalDays = nextIntervalDays
        self.nextDue = nextDue
        self.displayInterval = displayInterval
    }
}

// MARK: - Anki v2 Style SM-2 Pure Scheduler
public struct SRSScheduler {

    /// Custom fuzz provider for testing: takes (baseInterval, range) -> fuzzedInterval
    public static var customFuzzProvider: ((Double, ClosedRange<Double>) -> Double)? = nil

    /// Computes the new CardState given an existing state, rating, timestamp, and config
    public static func schedule(
        card: CardState,
        rating: SRSRating,
        now: Date = Date(),
        config: SRSConfig = SRSConfig()
    ) -> CardState {
        var updated = card
        updated.reps += 1
        updated.lastReviewedAt = now

        let state = card.state

        switch state {
        case .new:
            updated.ease = config.startingEase
            updated.stepIndex = 0
            handleLearning(updated: &updated, rating: rating, now: now, config: config, isRelearning: false)

        case .learning:
            handleLearning(updated: &updated, rating: rating, now: now, config: config, isRelearning: false)

        case .relearning:
            handleLearning(updated: &updated, rating: rating, now: now, config: config, isRelearning: true)

        case .review:
            handleReview(updated: &updated, rating: rating, now: now, config: config)
        }

        return updated
    }

    // MARK: - Learning & Relearning Flow
    private static func handleLearning(
        updated: inout CardState,
        rating: SRSRating,
        now: Date,
        config: SRSConfig,
        isRelearning: Bool
    ) {
        let steps = isRelearning ? config.relearningSteps : config.learningSteps
        let safeSteps = steps.isEmpty ? [10.0] : steps
        // Preserve post-lapse review interval (in days) while in relearning
        let postLapseIntervalDays = max(config.minimumLapseIntervalDays, updated.intervalDays >= 1.0 ? updated.intervalDays : config.minimumLapseIntervalDays)

        switch rating {
        case .again:
            updated.stepIndex = 0
            updated.state = isRelearning ? .relearning : .learning
            let stepMinutes = safeSteps[0]
            updated.intervalDays = isRelearning ? postLapseIntervalDays : (stepMinutes / 1440.0)
            updated.due = now.addingTimeInterval(stepMinutes * 60.0)

        case .hard:
            let currentIndex = max(0, min(updated.stepIndex, safeSteps.count - 1))
            let stepMinutes: Double
            if currentIndex == 0 {
                if safeSteps.count > 1 {
                    // Anki Classic: on first step with multiple steps, Hard is average of step 0 and step 1
                    stepMinutes = (safeSteps[0] + safeSteps[1]) / 2.0
                } else {
                    // Anki Classic: on first step with single step, Hard is 1.5x of step 0 (max 1 day)
                    stepMinutes = min(1440.0, safeSteps[0] * 1.5)
                }
            } else {
                // Anki Classic: on subsequent learning steps, Hard repeats the current step
                stepMinutes = safeSteps[currentIndex]
            }
            updated.state = isRelearning ? .relearning : .learning
            updated.intervalDays = isRelearning ? postLapseIntervalDays : (stepMinutes / 1440.0)
            updated.due = now.addingTimeInterval(stepMinutes * 60.0)

        case .good:
            let nextIndex = updated.stepIndex + 1
            if nextIndex < safeSteps.count {
                // Move to next learning step
                updated.stepIndex = nextIndex
                updated.state = isRelearning ? .relearning : .learning
                let stepMinutes = safeSteps[nextIndex]
                updated.intervalDays = isRelearning ? postLapseIntervalDays : (stepMinutes / 1440.0)
                updated.due = now.addingTimeInterval(stepMinutes * 60.0)
            } else {
                // Graduate to review!
                let targetDays = isRelearning ? postLapseIntervalDays : (config.graduatingIntervalDays * config.intervalModifier)
                graduate(updated: &updated, intervalDays: targetDays, now: now, config: config)
            }

        case .easy:
            // Early graduation with easy interval (or post-lapse + 1 day in relearning)
            let targetDays = isRelearning
                ? max(postLapseIntervalDays + 1.0, config.easyIntervalDays * config.intervalModifier)
                : (config.easyIntervalDays * config.intervalModifier)
            graduate(updated: &updated, intervalDays: targetDays, now: now, config: config)
        }
    }

    // MARK: - Review Flow (Anki Classic SM-2 Rules)
    private static func handleReview(
        updated: inout CardState,
        rating: SRSRating,
        now: Date,
        config: SRSConfig
    ) {
        let currentInterval = max(1.0, updated.intervalDays)
        let currentEase = max(config.minEase, updated.ease)
        // Anki overdue delay in days (0 if reviewed on time or early)
        let overdueDays = max(0.0, now.timeIntervalSince(updated.due) / 86400.0)

        // Base intervals following Anki's monotonic constraint: Hard < Good < Easy
        let rawHard = min(
            config.maximumIntervalDays,
            max(currentInterval + 1.0, currentInterval * config.hardMultiplier * config.intervalModifier)
        )
        let rawGood = min(
            config.maximumIntervalDays,
            max(rawHard + 1.0, (currentInterval + overdueDays / 2.0) * currentEase * config.intervalModifier)
        )
        let rawEasy = min(
            config.maximumIntervalDays,
            max(rawGood + 1.0, (currentInterval + overdueDays) * currentEase * config.easyBonus * config.intervalModifier)
        )

        switch rating {
        case .again:
            // Lapse! Ease drops by 20% (min 130%), goes to relearning (10m default),
            // new interval after lapse = lapseNewInterval (0% default) of old interval (min 1 day)
            updated.ease = max(config.minEase, currentEase - 0.20)
            updated.lapses += 1
            let postLapseInterval = min(
                config.maximumIntervalDays,
                max(config.minimumLapseIntervalDays, round(currentInterval * config.lapseNewInterval))
            )
            updated.intervalDays = postLapseInterval

            if config.relearningSteps.isEmpty {
                updated.state = .review
                updated.stepIndex = 0
                updated.due = now.addingTimeInterval(postLapseInterval * 86400.0)
            } else {
                updated.state = .relearning
                updated.stepIndex = 0
                let stepMinutes = config.relearningSteps[0]
                updated.due = now.addingTimeInterval(stepMinutes * 60.0)
            }

        case .hard:
            // Ease drops by 15% (min 130%), interval multiplied by 1.2
            updated.ease = max(config.minEase, currentEase - 0.15)
            let finalInterval = applyFuzzIfNeeded(interval: rawHard, config: config)
            updated.intervalDays = finalInterval
            updated.due = now.addingTimeInterval(finalInterval * 86400.0)
            updated.state = .review

        case .good:
            // Ease unchanged, interval multiplied by current ease
            let finalInterval = applyFuzzIfNeeded(interval: rawGood, config: config)
            updated.intervalDays = finalInterval
            updated.due = now.addingTimeInterval(finalInterval * 86400.0)
            updated.state = .review

        case .easy:
            // Ease increases by 15%, interval multiplied by current ease * easy bonus (1.3)
            updated.ease = currentEase + 0.15
            let finalInterval = applyFuzzIfNeeded(interval: rawEasy, config: config)
            updated.intervalDays = finalInterval
            updated.due = now.addingTimeInterval(finalInterval * 86400.0)
            updated.state = .review
        }
    }

    // MARK: - Graduation Helper
    private static func graduate(
        updated: inout CardState,
        intervalDays: Double,
        now: Date,
        config: SRSConfig
    ) {
        let clamped = min(config.maximumIntervalDays, max(1.0, intervalDays))
        let fuzzed = applyFuzzIfNeeded(interval: clamped, config: config)
        updated.state = .review
        updated.stepIndex = 0
        updated.intervalDays = fuzzed
        updated.due = now.addingTimeInterval(fuzzed * 86400.0)
    }

    // MARK: - Fuzz Calculation
    public static func applyFuzzIfNeeded(interval: Double, config: SRSConfig) -> Double {
        guard config.enableFuzz && interval > 2.0 else {
            return round(interval * 100.0) / 100.0
        }

        // Anki v2 fuzz ranges:
        // 2..7 days: ±1 day
        // 7..30 days: ±15% (or ±1 to 3 days)
        // > 30 days: ±5%
        let fuzzRange: ClosedRange<Double>
        if interval < 7.0 {
            let delta = 0.5
            fuzzRange = max(2.1, interval - delta)...(interval + delta)
        } else if interval < 30.0 {
            let delta = max(1.0, interval * 0.08)
            fuzzRange = (interval - delta)...(interval + delta)
        } else {
            let delta = max(2.0, interval * 0.05)
            fuzzRange = (interval - delta)...(interval + delta)
        }

        if let custom = customFuzzProvider {
            return custom(interval, fuzzRange)
        }

        let randomFactor = Double.random(in: fuzzRange)
        return round(randomFactor * 10.0) / 10.0
    }

    // MARK: - Projected Intervals for UI Buttons
    public static func projectedIntervals(
        card: CardState,
        now: Date = Date(),
        config: SRSConfig = SRSConfig()
    ) -> [SRSRating: SRSProjection] {
        var projections: [SRSRating: SRSProjection] = [:]

        // Temporarily disable fuzz for UI button label projection so preview is stable
        var deterministicConfig = config
        deterministicConfig.enableFuzz = false

        for rating in SRSRating.allCases {
            let projectedState = schedule(card: card, rating: rating, now: now, config: deterministicConfig)
            let secondsUntilDue = max(0, projectedState.due.timeIntervalSince(now))
            let display = formatInterval(seconds: secondsUntilDue, intervalDays: projectedState.intervalDays, state: projectedState.state)

            projections[rating] = SRSProjection(
                rating: rating,
                nextState: projectedState.state,
                nextIntervalDays: projectedState.intervalDays,
                nextDue: projectedState.due,
                displayInterval: display
            )
        }

        return projections
    }

    // MARK: - Interval String Formatter (e.g. "1m", "10m", "1d", "4d", "1.2mo")
    public static func formatInterval(seconds: Double, intervalDays: Double, state: CardStateEnum) -> String {
        if state == .learning || state == .relearning || seconds < 86400.0 {
            let minutes = max(1, Int(round(seconds / 60.0)))
            if minutes < 60 {
                return "\(minutes)m"
            }
            let hours = max(1, Int(round(Double(minutes) / 60.0)))
            return "\(hours)h"
        }

        let days = intervalDays
        if days < 30.0 {
            let roundedDays = max(1, Int(round(days)))
            return "\(roundedDays)d"
        } else if days < 365.0 {
            let months = round((days / 30.0) * 10.0) / 10.0
            return "\(months)mo"
        } else {
            let years = round((days / 365.0) * 10.0) / 10.0
            return "\(years)y"
        }
    }
}
