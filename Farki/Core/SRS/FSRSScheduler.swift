import Foundation

// MARK: - FSRS (Free Spaced Repetition Scheduler) Pure Implementation
public struct FSRSScheduler {

    /// Standard FSRS-4.5 / v5 Default Parameters (w0 ... w16)
    public static let defaultWeights: [Double] = [
        0.40255, 1.18385, 3.173, 15.69105, // w0..w3: Initial stabilities for ratings 1, 2, 3, 4
        7.1949, 0.5345,                     // w4, w5: Initial difficulty & delta
        1.4604, 0.0046,                     // w6, w7: Difficulty delta & mean reversion
        1.5457, 0.1192, 1.0192,             // w8..w10: Stability after recall
        1.9395, 0.11, 0.29605, 0.2298,      // w11..w14: Stability after lapse (forget)
        0.2315, 2.9898                      // w15, w16: Hard multiplier / easy bonus in recall
    ]

    // MARK: - Schedule Function
    public static func schedule(
        card: CardState,
        rating: SRSRating,
        now: Date = Date(),
        config: SRSConfig = SRSConfig(),
        weights: [Double] = defaultWeights
    ) -> CardState {
        var updated = card
        updated.reps += 1

        let isNew = (card.state == .new) || (card.reps == 0 && card.lastReviewedAt == nil)

        // Elapsed days since last review
        let elapsedDays: Double
        if let last = card.lastReviewedAt {
            elapsedDays = max(0.0, now.timeIntervalSince(last) / 86400.0)
        } else {
            elapsedDays = 0.0
        }
        updated.lastReviewedAt = now

        let targetRetention = min(0.99, max(0.70, config.fsrsRequestRetention))

        if isNew {
            // First time reviewing card: calculate initial stability and difficulty
            let s0 = initialStability(rating: rating, weights: weights)
            let d0 = initialDifficulty(rating: rating, weights: weights)

            updated.ease = d0 // Store FSRS difficulty in ease field

            switch rating {
            case .again:
                updated.state = .learning
                updated.stepIndex = 0
                let stepMinutes = config.learningSteps.first ?? 1.0
                updated.intervalDays = s0
                updated.due = now.addingTimeInterval(stepMinutes * 60.0)

            case .hard:
                updated.state = .learning
                updated.stepIndex = 0
                let stepMinutes = config.learningSteps.count > 1 ? config.learningSteps[1] : 10.0
                updated.intervalDays = s0
                updated.due = now.addingTimeInterval(stepMinutes * 60.0)

            case .good, .easy:
                updated.state = .review
                updated.stepIndex = 0
                let interval = intervalForStability(s0, retention: targetRetention)
                let fuzzed = SRSScheduler.applyFuzzIfNeeded(interval: interval, config: config)
                updated.intervalDays = fuzzed
                updated.due = now.addingTimeInterval(fuzzed * 86400.0)
            }
        } else {
            // Subsequent reviews: DSR update
            let currentS = max(0.1, card.intervalDays)
            // Existing difficulty (mapped from ease or defaulted to 5.0)
            let currentD = clampDifficulty(card.ease > 0 ? card.ease : 5.0)
            let retrievability = calculateRetrievability(elapsedDays: elapsedDays, stability: currentS)

            let nextD = calculateNextDifficulty(d: currentD, rating: rating, weights: weights)
            updated.ease = nextD

            switch rating {
            case .again:
                // Lapse
                updated.lapses += 1
                let nextS = calculateStabilityLapse(d: nextD, s: currentS, r: retrievability, weights: weights)
                updated.intervalDays = nextS
                updated.state = .relearning
                updated.stepIndex = 0
                let stepMinutes = config.relearningSteps.first ?? 10.0
                updated.due = now.addingTimeInterval(stepMinutes * 60.0)

            case .hard, .good, .easy:
                // Recall
                let nextS = calculateStabilityRecall(d: nextD, s: currentS, r: retrievability, rating: rating, weights: weights)
                let interval = intervalForStability(nextS, retention: targetRetention)
                let fuzzed = SRSScheduler.applyFuzzIfNeeded(interval: interval, config: config)
                updated.intervalDays = fuzzed
                updated.due = now.addingTimeInterval(fuzzed * 86400.0)
                updated.state = .review
                updated.stepIndex = 0
            }
        }

        return updated
    }

    // MARK: - Initial Stability & Difficulty
    public static func initialStability(rating: SRSRating, weights: [Double]) -> Double {
        let index = max(0, min(3, rating.rawValue - 1))
        return max(0.1, weights[index])
    }

    public static func initialDifficulty(rating: SRSRating, weights: [Double]) -> Double {
        let r = Double(rating.rawValue)
        let d = weights[4] - exp(weights[5] * (r - 1.0)) + 1.0
        return clampDifficulty(d)
    }

    // MARK: - Retrievability (Forgetting Curve)
    public static func calculateRetrievability(elapsedDays: Double, stability: Double) -> Double {
        guard stability > 0 else { return 0.0 }
        let factor = 19.0 / 81.0
        let r = pow(1.0 + factor * (elapsedDays / stability), -0.5)
        return min(1.0, max(0.01, r))
    }

    // MARK: - Next Difficulty
    public static func calculateNextDifficulty(d: Double, rating: SRSRating, weights: [Double]) -> Double {
        let r = Double(rating.rawValue)
        let d0_3 = initialDifficulty(rating: .good, weights: weights)
        let nextD = weights[7] * d0_3 + (1.0 - weights[7]) * (d - weights[6] * (r - 3.0))
        return clampDifficulty(nextD)
    }

    // MARK: - Stability on Recall
    public static func calculateStabilityRecall(
        d: Double,
        s: Double,
        r: Double,
        rating: SRSRating,
        weights: [Double]
    ) -> Double {
        let bonus: Double
        switch rating {
        case .hard: bonus = weights[15]
        case .good: bonus = 1.0
        case .easy: bonus = weights[16]
        case .again: bonus = 1.0
        }

        let inner = 1.0 + exp(weights[8]) * (11.0 - d) * pow(s, -weights[9]) * (exp(weights[10] * (1.0 - r)) - 1.0) * bonus
        let nextS = s * max(1.0, inner)
        return round(nextS * 100.0) / 100.0
    }

    // MARK: - Stability on Lapse
    public static func calculateStabilityLapse(
        d: Double,
        s: Double,
        r: Double,
        weights: [Double]
    ) -> Double {
        let nextS = weights[11] * pow(d, -weights[12]) * (pow(s + 1.0, weights[13]) - 1.0) * exp(weights[14] * (1.0 - r))
        return max(0.1, round(nextS * 100.0) / 100.0)
    }

    // MARK: - Next Interval Given Stability and Target Retention
    public static func intervalForStability(_ stability: Double, retention: Double) -> Double {
        let factor = 19.0 / 81.0
        let exponent = (pow(retention, -2.0) - 1.0) / factor
        let rawInterval = max(1.0, stability * exponent)
        return round(rawInterval * 10.0) / 10.0
    }

    private static func clampDifficulty(_ d: Double) -> Double {
        return min(10.0, max(1.0, round(d * 100.0) / 100.0))
    }

    // MARK: - Projected Intervals for UI Buttons
    public static func projectedIntervals(
        card: CardState,
        now: Date = Date(),
        config: SRSConfig = SRSConfig()
    ) -> [SRSRating: SRSProjection] {
        var projections: [SRSRating: SRSProjection] = [:]
        var deterministicConfig = config
        deterministicConfig.enableFuzz = false

        for rating in SRSRating.allCases {
            let projectedState = schedule(card: card, rating: rating, now: now, config: deterministicConfig)
            let secondsUntilDue = max(0, projectedState.due.timeIntervalSince(now))
            let display = SRSScheduler.formatInterval(
                seconds: secondsUntilDue,
                intervalDays: projectedState.intervalDays,
                state: projectedState.state
            )

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
}
