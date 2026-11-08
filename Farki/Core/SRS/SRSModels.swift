import Foundation

// MARK: - Card State
public enum CardStateEnum: String, Codable, CaseIterable {
    case new
    case learning
    case review
    case relearning
}

// MARK: - Review Rating
public enum SRSRating: Int, Codable, CaseIterable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    public var title: String {
        switch self {
        case .again: return "Again"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }
}

// MARK: - Card Direction
public enum CardDirection: String, Codable, CaseIterable {
    case jpToMeaning = "jp_meaning"
    case meaningToJp = "meaning_jp"

    public var displayName: String {
        switch self {
        case .jpToMeaning: return "日本語 → 意味 (JP → EN)"
        case .meaningToJp: return "意味 → 日本語 (EN → JP)"
        }
    }

    public static func cardId(entryId: String, direction: CardDirection) -> String {
        return "\(entryId):\(direction.rawValue)"
    }

    public static func parse(cardId: String) -> (entryId: String, direction: CardDirection)? {
        let parts = cardId.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let dir = CardDirection(rawValue: String(parts[1])) else {
            return (cardId, .jpToMeaning)
        }
        return (String(parts[0]), dir)
    }
}

// MARK: - Single Source of Truth Card State
public struct CardState: Codable, Equatable {
    public let cardId: String
    public var state: CardStateEnum
    public var due: Date
    public var intervalDays: Double
    public var ease: Double
    public var reps: Int
    public var lapses: Int
    public var stepIndex: Int
    public var lastReviewedAt: Date?

    public init(
        cardId: String,
        state: CardStateEnum = .new,
        due: Date = Date(),
        intervalDays: Double = 0.0,
        ease: Double = 2.5,
        reps: Int = 0,
        lapses: Int = 0,
        stepIndex: Int = 0,
        lastReviewedAt: Date? = nil
    ) {
        self.cardId = cardId
        self.state = state
        self.due = due
        self.intervalDays = intervalDays
        self.ease = ease
        self.reps = reps
        self.lapses = lapses
        self.stepIndex = stepIndex
        self.lastReviewedAt = lastReviewedAt
    }
}

// MARK: - Review Log
public struct ReviewLog: Codable, Equatable, Identifiable {
    public var id: Int64?
    public let cardId: String
    public let timestamp: Date
    public let rating: SRSRating
    public let stateBefore: CardStateEnum
    public let intervalBefore: Double
    public let intervalAfter: Double
    public let easeAfter: Double
    public let durationMs: Int
    public let scope: String

    // Stored for lossless undo restoration
    public let stepIndexBefore: Int
    public let lapsesBefore: Int
    public let repsBefore: Int
    public let dueBefore: Date
    public let easeBefore: Double
    public let lastReviewedAtBefore: Date?

    public init(
        id: Int64? = nil,
        cardId: String,
        timestamp: Date,
        rating: SRSRating,
        stateBefore: CardStateEnum,
        intervalBefore: Double,
        intervalAfter: Double,
        easeAfter: Double,
        durationMs: Int,
        scope: String,
        stepIndexBefore: Int = 0,
        lapsesBefore: Int = 0,
        repsBefore: Int = 0,
        dueBefore: Date = Date(),
        easeBefore: Double = 2.5,
        lastReviewedAtBefore: Date? = nil
    ) {
        self.id = id
        self.cardId = cardId
        self.timestamp = timestamp
        self.rating = rating
        self.stateBefore = stateBefore
        self.intervalBefore = intervalBefore
        self.intervalAfter = intervalAfter
        self.easeAfter = easeAfter
        self.durationMs = durationMs
        self.scope = scope
        self.stepIndexBefore = stepIndexBefore
        self.lapsesBefore = lapsesBefore
        self.repsBefore = repsBefore
        self.dueBefore = dueBefore
        self.easeBefore = easeBefore
        self.lastReviewedAtBefore = lastReviewedAtBefore
    }
}

// MARK: - SRS Algorithm Selection
public enum SRSAlgorithm: String, Codable, CaseIterable {
    case sm2 = "sm2"
    case fsrs = "fsrs"

    public var title: String {
        switch self {
        case .sm2: return "Anki Classic (SM-2)"
        case .fsrs: return "Anki Modern (FSRS)"
        }
    }
}

// MARK: - SRS Configuration
public struct SRSConfig: Codable, Equatable {
    public var algorithm: SRSAlgorithm          // .sm2 or .fsrs
    public var fsrsRequestRetention: Double     // default 0.90 (90%)
    public var learningSteps: [Double]          // in minutes, default [1, 10]
    public var relearningSteps: [Double]        // in minutes, default [10]
    public var graduatingIntervalDays: Double   // default 1
    public var easyIntervalDays: Double         // default 4
    public var startingEase: Double             // default 2.5 (250%)
    public var minEase: Double                  // default 1.3 (130%)
    public var easyBonus: Double                // default 1.3 (130%)
    public var hardMultiplier: Double           // default 1.2 (120%)
    public var intervalModifier: Double         // default 1.0 (100%)
    public var lapseNewInterval: Double         // default 0.0 (0% of old interval on lapse)
    public var minimumLapseIntervalDays: Double // default 1.0 (min 1 day after lapse)
    public var maximumIntervalDays: Double      // default 36500.0 (100 years)
    public var newCardsPerDay: Int              // default 20
    public var maxReviewsPerDay: Int            // default 200
    public var dayRolloverHour: Int             // default 4 (4:00 AM)
    public var enableFuzz: Bool                 // default true
    public var direction: CardDirection         // default jpToMeaning

    public init(
        algorithm: SRSAlgorithm = .sm2,
        fsrsRequestRetention: Double = 0.90,
        learningSteps: [Double] = [1.0, 10.0],
        relearningSteps: [Double] = [10.0],
        graduatingIntervalDays: Double = 1.0,
        easyIntervalDays: Double = 4.0,
        startingEase: Double = 2.5,
        minEase: Double = 1.3,
        easyBonus: Double = 1.3,
        hardMultiplier: Double = 1.2,
        intervalModifier: Double = 1.0,
        lapseNewInterval: Double = 0.0,
        minimumLapseIntervalDays: Double = 1.0,
        maximumIntervalDays: Double = 36500.0,
        newCardsPerDay: Int = 20,
        maxReviewsPerDay: Int = 200,
        dayRolloverHour: Int = 4,
        enableFuzz: Bool = true,
        direction: CardDirection = .jpToMeaning
    ) {
        self.algorithm = algorithm
        self.fsrsRequestRetention = fsrsRequestRetention
        self.learningSteps = learningSteps
        self.relearningSteps = relearningSteps
        self.graduatingIntervalDays = graduatingIntervalDays
        self.easyIntervalDays = easyIntervalDays
        self.startingEase = startingEase
        self.minEase = minEase
        self.easyBonus = easyBonus
        self.hardMultiplier = hardMultiplier
        self.intervalModifier = intervalModifier
        self.lapseNewInterval = lapseNewInterval
        self.minimumLapseIntervalDays = minimumLapseIntervalDays
        self.maximumIntervalDays = maximumIntervalDays
        self.newCardsPerDay = newCardsPerDay
        self.maxReviewsPerDay = maxReviewsPerDay
        self.dayRolloverHour = dayRolloverHour
        self.enableFuzz = enableFuzz
        self.direction = direction
    }

    enum CodingKeys: String, CodingKey {
        case algorithm, fsrsRequestRetention, learningSteps, relearningSteps, graduatingIntervalDays, easyIntervalDays, startingEase, minEase, easyBonus, hardMultiplier, intervalModifier, lapseNewInterval, minimumLapseIntervalDays, maximumIntervalDays, newCardsPerDay, maxReviewsPerDay, dayRolloverHour, enableFuzz, direction
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.algorithm = try container.decodeIfPresent(SRSAlgorithm.self, forKey: .algorithm) ?? .sm2
        self.fsrsRequestRetention = try container.decodeIfPresent(Double.self, forKey: .fsrsRequestRetention) ?? 0.90
        self.learningSteps = try container.decodeIfPresent([Double].self, forKey: .learningSteps) ?? [1.0, 10.0]
        self.relearningSteps = try container.decodeIfPresent([Double].self, forKey: .relearningSteps) ?? [10.0]
        self.graduatingIntervalDays = try container.decodeIfPresent(Double.self, forKey: .graduatingIntervalDays) ?? 1.0
        self.easyIntervalDays = try container.decodeIfPresent(Double.self, forKey: .easyIntervalDays) ?? 4.0
        self.startingEase = try container.decodeIfPresent(Double.self, forKey: .startingEase) ?? 2.5
        self.minEase = try container.decodeIfPresent(Double.self, forKey: .minEase) ?? 1.3
        self.easyBonus = try container.decodeIfPresent(Double.self, forKey: .easyBonus) ?? 1.3
        self.hardMultiplier = try container.decodeIfPresent(Double.self, forKey: .hardMultiplier) ?? 1.2
        self.intervalModifier = try container.decodeIfPresent(Double.self, forKey: .intervalModifier) ?? 1.0
        self.lapseNewInterval = try container.decodeIfPresent(Double.self, forKey: .lapseNewInterval) ?? 0.0
        self.minimumLapseIntervalDays = try container.decodeIfPresent(Double.self, forKey: .minimumLapseIntervalDays) ?? 1.0
        self.maximumIntervalDays = try container.decodeIfPresent(Double.self, forKey: .maximumIntervalDays) ?? 36500.0
        self.newCardsPerDay = try container.decodeIfPresent(Int.self, forKey: .newCardsPerDay) ?? 20
        self.maxReviewsPerDay = try container.decodeIfPresent(Int.self, forKey: .maxReviewsPerDay) ?? 200
        self.dayRolloverHour = try container.decodeIfPresent(Int.self, forKey: .dayRolloverHour) ?? 4
        self.enableFuzz = try container.decodeIfPresent(Bool.self, forKey: .enableFuzz) ?? true
        self.direction = try container.decodeIfPresent(CardDirection.self, forKey: .direction) ?? .jpToMeaning
    }
}

// MARK: - Study Scope
public enum SRSScope: Equatable, Hashable {
    case all
    case chapter(Int)
    case selected([Int])
    case preset(id: String, name: String, chapters: [Int])

    public var identifier: String {
        switch self {
        case .all: return "all"
        case .chapter(let ch): return "chapter_\(ch)"
        case .selected(let chs): return "selected_\(chs.sorted().map(String.init).joined(separator: "_"))"
        case .preset(let id, _, _): return "preset_\(id)"
        }
    }

    public var displayName: String {
        switch self {
        case .all:
            return "すべての課 (All Chapters)"
        case .chapter(let ch):
            return "第\(ch)課 (Chapter \(ch))"
        case .selected(let chs):
            let sorted = chs.sorted()
            if sorted.count == 1 {
                return "第\(sorted[0])課 (Chapter \(sorted[0]))"
            }
            return "\(sorted.count) Chapters (\(sorted.prefix(3).map(String.init).joined(separator: ", "))\(sorted.count > 3 ? "..." : ""))"
        case .preset(_, let name, _):
            return name
        }
    }

    public func matches(chapter: Int) -> Bool {
        switch self {
        case .all:
            return true
        case .chapter(let ch):
            return chapter == ch
        case .selected(let chs), .preset(_, _, let chs):
            return chs.contains(chapter)
        }
    }
}

// MARK: - Scope Preset
public struct ScopePreset: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var chapters: [Int]
    public let createdAt: Date

    public init(id: String = UUID().uuidString, name: String, chapters: [Int], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.chapters = chapters
        self.createdAt = createdAt
    }
}
