import SwiftUI

// MARK: - Grammar Tense & Polarity (For Dedicated Grammar Section)
enum GrammarTense: String, CaseIterable, Codable {
    case present = "現在"
    case past = "過去"

    var label: String {
        switch self {
        case .present: return "Present"
        case .past: return "Past"
        }
    }
}

enum GrammarPolarity: String, CaseIterable, Codable {
    case affirmative = "肯定"
    case negative = "否定"

    var label: String {
        switch self {
        case .affirmative: return "Positive"
        case .negative: return "Negative"
        }
    }
}

enum CycleTickState: Equatable {
    case none
    case singleCompletedCycle    // Double grey tick: rotated once
    case multipleCompletedCycles // Double blue tick: cycled again
}

// MARK: - Grammar Category for Color Coding
enum GrammarColorCategory: String, Codable {
    case affirmative      // Green
    case negative         // Red
    case present          // Blue
    case past             // Orange
    case polite           // Green default
    case dictionary       // Purple default
    case conditional      // Teal
    case potential        // Cyan
    case request          // Amber
    case permission       // Light green
    case obligation       // Deep orange
    case prohibition      // Deep red

    func color(for theme: AppTheme) -> Color {
        switch self {
        case .affirmative, .polite:
            return theme == .dark ? Color(hex: "#4ADE80") : Color(hex: "#16A34A")
        case .negative:
            return theme == .dark ? Color(hex: "#F87171") : Color(hex: "#DC2626")
        case .present:
            return theme == .dark ? Color(hex: "#60A5FA") : Color(hex: "#2563EB")
        case .past:
            return theme == .dark ? Color(hex: "#FB923C") : Color(hex: "#EA580C")
        case .dictionary:
            return theme == .dark ? Color(hex: "#C084FC") : Color(hex: "#9333EA")
        case .conditional:
            return theme == .dark ? Color(hex: "#2DD4BF") : Color(hex: "#0D9488")
        case .potential:
            return theme == .dark ? Color(hex: "#22D3EE") : Color(hex: "#0891B2")
        case .request:
            return theme == .dark ? Color(hex: "#FBBF24") : Color(hex: "#D97706")
        case .permission:
            return theme == .dark ? Color(hex: "#A3E635") : Color(hex: "#65A30D")
        case .obligation:
            return theme == .dark ? Color(hex: "#FB923C") : Color(hex: "#C2410C")
        case .prohibition:
            return theme == .dark ? Color(hex: "#EF4444") : Color(hex: "#B91C1C")
        }
    }
}

// MARK: - Conjugation Variant (Specific Form x Tense x Polarity)
struct ConjugationVariant: Codable, Equatable {
    let conjugation: String
    let romaji: String
    let sentenceJapanese: String
    let sentenceRomaji: String
    let sentenceTranslation: String
}

// MARK: - Example Sentence
struct VocabExampleSentence: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let label: String                     // e.g. "Past" or "Present"
    let labelCategory: GrammarColorCategory
    let japanese: String
    let romaji: String
    let translation: String

    enum CodingKeys: String, CodingKey {
        case label, labelCategory, japanese, romaji, translation
    }

    init(id: UUID = UUID(), label: String, labelCategory: GrammarColorCategory, japanese: String, romaji: String, translation: String) {
        self.id = id
        self.label = label
        self.labelCategory = labelCategory
        self.japanese = japanese
        self.romaji = romaji
        self.translation = translation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.label = try container.decode(String.self, forKey: .label)
        self.labelCategory = try container.decode(GrammarColorCategory.self, forKey: .labelCategory)
        self.japanese = try container.decode(String.self, forKey: .japanese)
        self.romaji = try container.decode(String.self, forKey: .romaji)
        self.translation = try container.decode(String.self, forKey: .translation)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(label, forKey: .label)
        try container.encode(labelCategory, forKey: .labelCategory)
        try container.encode(japanese, forKey: .japanese)
        try container.encode(romaji, forKey: .romaji)
        try container.encode(translation, forKey: .translation)
    }
}

// MARK: - Grammar Form Item (For Dedicated Grammar Section)
struct GrammarFormItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let tenseName: String                 // e.g. "現在・過去", "て形", "可能動詞"
    let formLabel: String                 // e.g. "Polite", "Plain", "Te-Form", "Potential", etc.
    let formCategory: GrammarColorCategory
    let conjugation: String               // Default / summary conjugation, e.g. "ます / ました"
    var romaji: String? = nil             // Romaji for summary conjugation, e.g. "masu / mashita"

    // Detailed variants for full Form x Tense x Polarity support
    var presentAffirmative: ConjugationVariant? = nil
    var presentNegative: ConjugationVariant? = nil
    var pastAffirmative: ConjugationVariant? = nil
    var pastNegative: ConjugationVariant? = nil

    // Legacy fallback examples
    var pastExample: VocabExampleSentence? = nil
    var presentExample: VocabExampleSentence? = nil

    func variant(tense: GrammarTense, polarity: GrammarPolarity) -> ConjugationVariant? {
        switch (tense, polarity) {
        case (.present, .affirmative):
            return presentAffirmative ?? fallbackVariant(tense: .present, polarity: .affirmative)
        case (.present, .negative):
            return presentNegative ?? fallbackVariant(tense: .present, polarity: .negative)
        case (.past, .affirmative):
            return pastAffirmative ?? fallbackVariant(tense: .past, polarity: .affirmative)
        case (.past, .negative):
            return pastNegative ?? fallbackVariant(tense: .past, polarity: .negative)
        }
    }

    private func fallbackVariant(tense: GrammarTense, polarity: GrammarPolarity) -> ConjugationVariant? {
        let example = (tense == .past) ? (pastExample ?? presentExample) : (presentExample ?? pastExample)
        guard let ex = example else { return nil }
        return ConjugationVariant(
            conjugation: conjugation,
            romaji: romaji ?? "",
            sentenceJapanese: ex.japanese,
            sentenceRomaji: ex.romaji,
            sentenceTranslation: ex.translation
        )
    }
}

// MARK: - Grammar Form Import Models
struct GrammarFormImport: Codable {
    let tenseName: String                    // e.g. "丁寧語", "普通形", "て形"
    let formLabel: String                    // e.g. "Polite", "Plain", "Te-Form"
    let formCategory: String                 // "affirmative", "negative", "present", "past", "polite", "dictionary", "conditional", etc.
    let conjugation: String                  // e.g. "のみます / のみました"
    let romaji: String?                      // Romaji for form conjugation, e.g. "Nomimasu / Nomimashita"
    let pastExample: ExampleSentenceImport?
    let presentExample: ExampleSentenceImport?

    let presentAffirmative: ConjugationVariantImport?
    let presentNegative: ConjugationVariantImport?
    let pastAffirmative: ConjugationVariantImport?
    let pastNegative: ConjugationVariantImport?
}

struct ConjugationVariantImport: Codable {
    let conjugation: String
    let romaji: String
    let sentenceJapanese: String?
    let sentenceRomaji: String?
    let sentenceTranslation: String?
}

struct ExampleSentenceImport: Codable {
    let label: String                        // e.g. "Past" or "Present"
    let labelCategory: String?               // e.g. "past", "present", "negative"
    let japanese: String
    let romaji: String
    let translation: String
}

// MARK: - Dedicated Grammar Points & Variants (Grammar & Particles Specification)

struct GrammarVariant: Codable, Equatable, Identifiable {
    let id: String
    var label: String
    var pattern: String
    var romaji: String
    var meaning: String
    var explanation: String?
    var tense: GrammarTense?
    var polarity: GrammarPolarity?
    var category: GrammarColorCategory
    var examples: [ParticleExample]

    init(
        id: String,
        label: String,
        pattern: String,
        romaji: String,
        meaning: String,
        explanation: String? = nil,
        tense: GrammarTense? = nil,
        polarity: GrammarPolarity? = nil,
        category: GrammarColorCategory = .present,
        examples: [ParticleExample] = []
    ) {
        self.id = id
        self.label = label
        self.pattern = pattern
        self.romaji = romaji
        self.meaning = meaning
        self.explanation = explanation
        self.tense = tense
        self.polarity = polarity
        self.category = category
        self.examples = examples
    }
}

struct GrammarPoint: Codable, Equatable, Identifiable {
    let id: String
    var number: Int
    var chapterNumber: Int
    var bookNumber: Int
    var title: String
    var japanese: String
    var romaji: String
    var meaning: String
    var explanation: String
    var pattern: String
    var jlptLevel: JLPTLevel?
    var categoryTag: String
    var variants: [GrammarVariant]
    var examples: [ParticleExample]
    var relatedParticleIds: [String]
    var relatedUsageIds: [String]
    var tags: [String]

    init(
        id: String,
        number: Int,
        chapterNumber: Int = 1,
        bookNumber: Int = 1,
        title: String,
        japanese: String,
        romaji: String,
        meaning: String,
        explanation: String,
        pattern: String,
        jlptLevel: JLPTLevel? = .n5,
        categoryTag: String = "01 Polite & Plain Forms",
        variants: [GrammarVariant] = [],
        examples: [ParticleExample] = [],
        relatedParticleIds: [String] = [],
        relatedUsageIds: [String] = [],
        tags: [String] = []
    ) {
        self.id = id
        self.number = number
        self.chapterNumber = chapterNumber
        self.bookNumber = bookNumber
        self.title = title
        self.japanese = japanese
        self.romaji = romaji
        self.meaning = meaning
        self.explanation = explanation
        self.pattern = pattern
        self.jlptLevel = jlptLevel
        self.categoryTag = categoryTag
        self.variants = variants
        self.examples = examples
        self.relatedParticleIds = relatedParticleIds
        self.relatedUsageIds = relatedUsageIds
        self.tags = tags
    }

    var stripDisplay: String {
        if japanese.count > 6 {
            return String(japanese.prefix(5)) + "…"
        }
        return japanese
    }
}

struct GrammarDatabase: Codable, Equatable {
    let schemaVersion: Int
    var grammarPoints: [GrammarPoint]

    init(schemaVersion: Int = 1, grammarPoints: [GrammarPoint]) {
        self.schemaVersion = schemaVersion
        self.grammarPoints = grammarPoints
    }
}

