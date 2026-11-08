import Foundation

extension Notification.Name {
    static let grammarDataUpdated = Notification.Name("grammarDataUpdated")
}

final class GrammarDataService {
    static let shared = GrammarDataService()

    private let dbStorageKey = "farki_grammar_database_v2"
    private let progressStorageKey = "farki_grammar_progress_v1"

    private(set) var database: GrammarDatabase
    private(set) var progressByKey: [String: LearningItemProgress] = [:]

    var grammarPoints: [GrammarPoint] { database.grammarPoints }

    private init() {
        self.database = GrammarDatabase(schemaVersion: 1, grammarPoints: [])
        loadProgress()
        loadDatabase()
    }

    // MARK: - Persistence & Loading
    private func loadProgress() {
        if let data = UserDefaults.standard.data(forKey: progressStorageKey),
           let decoded = try? JSONDecoder().decode([String: LearningItemProgress].self, from: data) {
            self.progressByKey = decoded
        }
    }

    func saveProgress() {
        if let encoded = try? JSONEncoder().encode(progressByKey) {
            UserDefaults.standard.set(encoded, forKey: progressStorageKey)
            NotificationCenter.default.post(name: .grammarDataUpdated, object: nil)
        }
    }

    private func loadDatabase() {
        if let data = UserDefaults.standard.data(forKey: dbStorageKey),
           let saved = try? JSONDecoder().decode(GrammarDatabase.self, from: data),
           !saved.grammarPoints.isEmpty {
            self.database = saved
            if let bundled = loadBundledGrammarDatabase(),
               bundled.grammarPoints.count > saved.grammarPoints.count {
                importDatabase(bundled)
            }
        } else if let bundled = loadBundledGrammarDatabase() {
            self.database = bundled
            saveDatabase()
        }
    }

    func saveDatabase() {
        if let encoded = try? JSONEncoder().encode(database) {
            UserDefaults.standard.set(encoded, forKey: dbStorageKey)
            NotificationCenter.default.post(name: .grammarDataUpdated, object: nil)
        }
    }

    func loadBundledGrammarDatabase() -> GrammarDatabase? {
        guard let data = findGrammarJSONData() else { return nil }
        return try? JSONDecoder().decode(GrammarDatabase.self, from: data)
    }

    private func findGrammarJSONData() -> Data? {
        if let url = Bundle.main.url(forResource: "grammar_points", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        if let url = Bundle.main.url(forResource: "grammar_points", withExtension: "json", subdirectory: "Grammar"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        if let url = Bundle.main.url(forResource: "grammar_points", withExtension: "json", subdirectory: "Resources/Grammar"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        let thisFileUrl = URL(fileURLWithPath: #filePath)
        let candidatePath = thisFileUrl
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Grammar/grammar_points.json")
        if let data = try? Data(contentsOf: candidatePath) {
            return data
        }
        let absolutePath = "/Users/static/Documents/projects/farki/Farki/Resources/Grammar/grammar_points.json"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: absolutePath)) {
            return data
        }
        return nil
    }

    // MARK: - Idempotent Import
    @discardableResult
    func importDatabase(from jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8),
              let incoming = try? JSONDecoder().decode(GrammarDatabase.self, from: data) else {
            return false
        }
        importDatabase(incoming)
        return true
    }

    func importDatabase(_ incoming: GrammarDatabase) {
        var merged = database.grammarPoints
        for gp in incoming.grammarPoints {
            if let idx = merged.firstIndex(where: { $0.id == gp.id }) {
                merged[idx] = gp
            } else {
                merged.append(gp)
            }
        }
        merged.sort { $0.number < $1.number }
        self.database = GrammarDatabase(schemaVersion: incoming.schemaVersion, grammarPoints: merged)
        // Progress and SRS review records are preserved
        saveDatabase()
    }

    // MARK: - Lookup & Search
    func point(forId id: String) -> GrammarPoint? {
        database.grammarPoints.first { $0.id == id }
    }

    func variant(pointId: String, variantId: String) -> GrammarVariant? {
        point(forId: pointId)?.variants.first { $0.id == variantId }
    }

    var availableCategories: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for gp in database.grammarPoints {
            if seen.insert(gp.categoryTag).inserted {
                result.append(gp.categoryTag)
            }
        }
        return result
    }

    func searchGrammarPoints(
        query: String = "",
        jlptLevel: JLPTLevel? = nil,
        chapterNumber: Int? = nil,
        categoryTag: String? = nil
    ) -> [GrammarPoint] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return database.grammarPoints.filter { gp in
            if let level = jlptLevel, level != .all {
                if gp.jlptLevel != level {
                    return false
                }
            }
            if let ch = chapterNumber {
                if gp.chapterNumber != ch {
                    return false
                }
            }
            if let cat = categoryTag, !cat.isEmpty {
                if gp.categoryTag != cat {
                    return false
                }
            }
            if !trimmed.isEmpty {
                let matchesTitle = gp.title.lowercased().contains(trimmed)
                let matchesJP = gp.japanese.lowercased().contains(trimmed)
                let matchesRomaji = gp.romaji.lowercased().contains(trimmed)
                let matchesMeaning = gp.meaning.lowercased().contains(trimmed)
                let matchesExp = gp.explanation.lowercased().contains(trimmed)
                let matchesPattern = gp.pattern.lowercased().contains(trimmed)
                let matchesVariant = gp.variants.contains {
                    $0.pattern.lowercased().contains(trimmed) ||
                    $0.meaning.lowercased().contains(trimmed) ||
                    $0.label.lowercased().contains(trimmed)
                }
                if !matchesTitle && !matchesJP && !matchesRomaji && !matchesMeaning && !matchesExp && !matchesPattern && !matchesVariant {
                    return false
                }
            }
            return true
        }
    }

    // MARK: - Progress Tracking (Per Grammar Point or Variant)
    func reference(pointId: String, variantId: String? = nil) -> LearningItemReference {
        LearningItemReference(domain: .grammar, contentId: pointId, subContentId: variantId)
    }

    func progress(for reference: LearningItemReference) -> LearningItemProgress {
        let key = reference.reviewIdentityKey
        return progressByKey[key] ?? LearningItemProgress(identityKey: key)
    }

    func progress(pointId: String, variantId: String? = nil) -> LearningItemProgress {
        progress(for: reference(pointId: pointId, variantId: variantId))
    }

    func updateProgress(
        for reference: LearningItemReference,
        learningState: VocabLearningState,
        difficulty: VocabDifficulty? = nil,
        responseTime: TimeInterval? = nil,
        isCorrect: Bool? = nil
    ) {
        let key = reference.reviewIdentityKey
        var current = progressByKey[key] ?? LearningItemProgress(identityKey: key)
        current.learningState = learningState
        if let diff = difficulty {
            current.difficulty = diff
        }
        if let correct = isCorrect {
            if correct {
                current.currentStreak += 1
                current.bestStreak = max(current.bestStreak, current.currentStreak)
            } else {
                current.currentStreak = 0
            }
        }
        if let time = responseTime {
            if let best = current.bestTimeSeconds {
                current.bestTimeSeconds = min(best, time)
            } else {
                current.bestTimeSeconds = time
            }
        }
        progressByKey[key] = current
        saveProgress()
    }

    func cycleDifficulty(for reference: LearningItemReference) {
        let key = reference.reviewIdentityKey
        var current = progressByKey[key] ?? LearningItemProgress(identityKey: key)
        current.cycleDifficulty()
        progressByKey[key] = current
        saveProgress()
    }

    func resetProgressKeepContent() {
        progressByKey = [:]
        saveProgress()
    }
}

