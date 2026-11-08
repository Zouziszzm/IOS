import Foundation
import SwiftUI

// MARK: - Particle Category (Section 2 Specification)
public enum ParticleCategory: String, Codable, CaseIterable, Identifiable {
    case topic = "topic"
    case subject = "subject"
    case object = "object"
    case location = "location"
    case time = "time"
    case direction = "direction"
    case possession = "possession"
    case connection = "connection"
    case comparison = "comparison"
    case limitation = "limitation"
    case causeReason = "cause_reason"
    case condition = "condition"
    case concession = "concession"
    case listing = "listing"
    case quotation = "quotation"
    case purpose = "purpose"
    case sentenceEnding = "sentence_ending"
    case emphasis = "emphasis"
    case other = "other"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .topic: return "Topic"
        case .subject: return "Subject"
        case .object: return "Object"
        case .location: return "Location"
        case .time: return "Time"
        case .direction: return "Direction"
        case .possession: return "Possession"
        case .connection: return "Connection"
        case .comparison: return "Comparison"
        case .limitation: return "Limitation"
        case .causeReason: return "Cause / Reason"
        case .condition: return "Condition"
        case .concession: return "Concession"
        case .listing: return "Listing"
        case .quotation: return "Quotation"
        case .purpose: return "Purpose"
        case .sentenceEnding: return "Sentence Ending"
        case .emphasis: return "Emphasis"
        case .other: return "Other"
        }
    }
}

// MARK: - Particle Example
public struct ParticleExample: Codable, Equatable, Hashable, Identifiable {
    public var id: String { "\(japanese)|\(meaning)" }
    public let japanese: String
    public var reading: String?
    public let meaning: String
    public var notes: String?

    public init(
        japanese: String,
        reading: String? = nil,
        meaning: String,
        notes: String? = nil
    ) {
        self.japanese = japanese
        self.reading = reading
        self.meaning = meaning
        self.notes = notes
    }
}

// MARK: - Particle Usage
struct ParticleUsage: Codable, Equatable, Identifiable {
    let id: String
    var meaning: String
    var explanation: String
    var pattern: String
    var examples: [ParticleExample]
    var jlptLevel: JLPTLevel?
    var grammarPointIds: [String]
    var relatedUsageIds: [String]
    var tags: [String]

    init(
        id: String,
        meaning: String,
        explanation: String,
        pattern: String,
        examples: [ParticleExample] = [],
        jlptLevel: JLPTLevel? = nil,
        grammarPointIds: [String] = [],
        relatedUsageIds: [String] = [],
        tags: [String] = []
    ) {
        self.id = id
        self.meaning = meaning
        self.explanation = explanation
        self.pattern = pattern
        self.examples = examples
        self.jlptLevel = jlptLevel
        self.grammarPointIds = grammarPointIds
        self.relatedUsageIds = relatedUsageIds
        self.tags = tags
    }
}

// MARK: - Particle (Unique Form)
struct Particle: Codable, Equatable, Identifiable {
    let id: String
    var japanese: String
    var romaji: String
    var alternativeReadings: [String]?
    var categories: [ParticleCategory]
    var usageIds: [String]
    var tags: [String]

    init(
        id: String,
        japanese: String,
        romaji: String,
        alternativeReadings: [String]? = nil,
        categories: [ParticleCategory] = [],
        usageIds: [String] = [],
        tags: [String] = []
    ) {
        self.id = id
        self.japanese = japanese
        self.romaji = romaji
        self.alternativeReadings = alternativeReadings
        self.categories = categories
        self.usageIds = usageIds
        self.tags = tags
    }

    var stripDisplay: String {
        if japanese.count > 6 {
            return String(japanese.prefix(5)) + "…"
        }
        return japanese
    }
}

// MARK: - Editorial Review Status
enum ParticleReviewStatus: String, Codable, CaseIterable {
    case unreviewed = "unreviewed"
    case verified = "verified"
    case needsCorrection = "needs_correction"

    var label: String {
        switch self {
        case .unreviewed: return "Unreviewed"
        case .verified: return "Verified"
        case .needsCorrection: return "Needs Correction"
        }
    }
}

// MARK: - Particle Source Entry (1..188 Catalogue Entry)
struct ParticleSourceEntry: Codable, Equatable, Identifiable {
    let id: String
    let sourceId: String
    let sourceNumber: Int
    let sourcePage: Int
    let particleId: String
    let usageId: String
    let originalParticleText: String
    let originalMeaning: String
    var reviewStatus: ParticleReviewStatus
    var editorialNote: String?

    init(
        id: String? = nil,
        sourceId: String = "nihon-188-particles",
        sourceNumber: Int,
        sourcePage: Int,
        particleId: String,
        usageId: String,
        originalParticleText: String,
        originalMeaning: String,
        reviewStatus: ParticleReviewStatus = .unreviewed,
        editorialNote: String? = nil
    ) {
        self.id = id ?? "\(sourceId):\(sourceNumber)"
        self.sourceId = sourceId
        self.sourceNumber = sourceNumber
        self.sourcePage = sourcePage
        self.particleId = particleId
        self.usageId = usageId
        self.originalParticleText = originalParticleText
        self.originalMeaning = originalMeaning
        self.reviewStatus = reviewStatus
        self.editorialNote = editorialNote
    }
}

// MARK: - Particle Database Root
struct ParticleDatabase: Codable, Equatable {
    let schemaVersion: Int
    var particles: [Particle]
    var usages: [ParticleUsage]
    var sourceEntries: [ParticleSourceEntry]

    init(
        schemaVersion: Int = 1,
        particles: [Particle],
        usages: [ParticleUsage],
        sourceEntries: [ParticleSourceEntry]
    ) {
        self.schemaVersion = schemaVersion
        self.particles = particles
        self.usages = usages
        self.sourceEntries = sourceEntries
    }
}

// MARK: - Particle Validation & Import Result (Section 6 Rules)
public enum ParticleValidationError: Error, Equatable, LocalizedError {
    case duplicateParticleId(String)
    case duplicateUsageId(String)
    case duplicateSourceEntryId(String)
    case missingSourceNumbers([Int])
    case invalidSourcePageNumber(entryNumber: Int, page: Int)
    case unresolvedParticleReference(sourceNumber: Int, particleId: String)
    case unresolvedUsageReference(context: String, usageId: String)
    case unresolvedGrammarReference(usageId: String, grammarPointId: String)
    case unverifiedJLPTLevelAssigned(usageId: String)
    case parsingFailure(String)

    public var errorDescription: String? {
        switch self {
        case .duplicateParticleId(let id):
            return "Duplicate Particle ID: \(id)"
        case .duplicateUsageId(let id):
            return "Duplicate ParticleUsage ID: \(id)"
        case .duplicateSourceEntryId(let id):
            return "Duplicate ParticleSourceEntry ID: \(id)"
        case .missingSourceNumbers(let nums):
            return "Missing source numbers in 1..188: \(nums.map(String.init).joined(separator: ", "))"
        case .invalidSourcePageNumber(let num, let page):
            return "Invalid source page \(page) for entry #\(num)"
        case .unresolvedParticleReference(let num, let pid):
            return "Source entry #\(num) references unknown particle ID '\(pid)'"
        case .unresolvedUsageReference(let ctx, let uid):
            return "\(ctx) references unknown usage ID '\(uid)'"
        case .unresolvedGrammarReference(let uid, let gid):
            return "Usage '\(uid)' references unknown grammar point ID '\(gid)'"
        case .unverifiedJLPTLevelAssigned(let uid):
            return "Unreviewed usage '\(uid)' must have jlptLevel set to null until verified"
        case .parsingFailure(let msg):
            return "JSON parsing failure: \(msg)"
        }
    }
}

public struct ParticleImportValidationResult: Equatable {
    public let isValid: Bool
    public let particleCount: Int
    public let usageCount: Int
    public let sourceEntryCount: Int
    public let errors: [ParticleValidationError]
}
