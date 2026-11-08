import Foundation

// MARK: - SRS Engine Facade (Decoupled Scheduler Abstraction)
public struct SRSEngine {

    /// Routes schedule computation to active scheduler algorithm (SM-2 or FSRS)
    public static func schedule(
        card: CardState,
        rating: SRSRating,
        now: Date = Date(),
        config: SRSConfig = SRSConfig()
    ) -> CardState {
        switch config.algorithm {
        case .sm2:
            return SRSScheduler.schedule(card: card, rating: rating, now: now, config: config)
        case .fsrs:
            return FSRSScheduler.schedule(card: card, rating: rating, now: now, config: config)
        }
    }

    /// Routes projected interval computation for UI buttons
    public static func projectedIntervals(
        card: CardState,
        now: Date = Date(),
        config: SRSConfig = SRSConfig()
    ) -> [SRSRating: SRSProjection] {
        switch config.algorithm {
        case .sm2:
            return SRSScheduler.projectedIntervals(card: card, now: now, config: config)
        case .fsrs:
            return FSRSScheduler.projectedIntervals(card: card, now: now, config: config)
        }
    }
}
