import Foundation

extension Notification.Name {
    static let particleDataUpdated = Notification.Name("particleDataUpdated")
}

final class ParticleDataService {
    static let shared = ParticleDataService()

    private let dbStorageKey = "farki_particle_database_v1"
    private let progressStorageKey = "farki_particle_progress_v1"

    private(set) var database: ParticleDatabase
    private(set) var progressByKey: [String: LearningItemProgress] = [:]

    var particles: [Particle] { database.particles }
    var usages: [ParticleUsage] { database.usages }
    var sourceEntries: [ParticleSourceEntry] { database.sourceEntries }

    private init() {
        self.database = ParticleDatabase(schemaVersion: 1, particles: [], usages: [], sourceEntries: [])
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
            NotificationCenter.default.post(name: .particleDataUpdated, object: nil)
        }
    }

    private func loadDatabase() {
        if let data = UserDefaults.standard.data(forKey: dbStorageKey),
           let saved = try? JSONDecoder().decode(ParticleDatabase.self, from: data),
           saved.sourceEntries.count == 188 {
            self.database = saved
        } else if let bundled = loadBundledParticleDatabase() {
            self.database = bundled
            saveDatabase()
        }
    }

    func saveDatabase() {
        if let encoded = try? JSONEncoder().encode(database) {
            UserDefaults.standard.set(encoded, forKey: dbStorageKey)
            NotificationCenter.default.post(name: .particleDataUpdated, object: nil)
        }
    }

    func loadBundledParticleDatabase() -> ParticleDatabase? {
        guard let data = findParticles188JSONData() else { return nil }
        return try? JSONDecoder().decode(ParticleDatabase.self, from: data)
    }

    private func findParticles188JSONData() -> Data? {
        if let url = Bundle.main.url(forResource: "particles_188", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        if let url = Bundle.main.url(forResource: "particles_188", withExtension: "json", subdirectory: "Particles"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        if let url = Bundle.main.url(forResource: "particles_188", withExtension: "json", subdirectory: "Resources/Particles"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        let thisFileUrl = URL(fileURLWithPath: #filePath)
        let candidatePath = thisFileUrl
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Particles/particles_188.json")
        if let data = try? Data(contentsOf: candidatePath) {
            return data
        }
        let absolutePath = "/Users/static/Documents/projects/farki/Farki/Resources/Particles/particles_188.json"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: absolutePath)) {
            return data
        }
        return nil
    }

    // MARK: - Section 6 Validation Rules
    func validateDatabase(
        _ db: ParticleDatabase,
        knownGrammarPointIds: Set<String>? = nil,
        requireAll188Numbers: Bool = true
    ) -> ParticleImportValidationResult {
        var errors: [ParticleValidationError] = []

        // 1. Unique Particle IDs
        var seenParticleIds = Set<String>()
        for p in db.particles {
            if !seenParticleIds.insert(p.id).inserted {
                errors.append(.duplicateParticleId(p.id))
            }
        }

        // 2. Unique Usage IDs
        var seenUsageIds = Set<String>()
        var usageById: [String: ParticleUsage] = [:]
        for u in db.usages {
            if !seenUsageIds.insert(u.id).inserted {
                errors.append(.duplicateUsageId(u.id))
            }
            usageById[u.id] = u
        }

        // 3. Unique SourceEntry IDs & Source Numbers 1..188
        var seenSourceEntryIds = Set<String>()
        var seenSourceNumbers = Set<Int>()
        for entry in db.sourceEntries {
            let canonicalEntryId = "\(entry.sourceId):\(entry.sourceNumber)"
            if !seenSourceEntryIds.insert(entry.id).inserted || (entry.id != canonicalEntryId && seenSourceEntryIds.contains(canonicalEntryId)) {
                errors.append(.duplicateSourceEntryId(entry.id))
            }
            seenSourceEntryIds.insert(canonicalEntryId)
            seenSourceNumbers.insert(entry.sourceNumber)

            if entry.sourcePage < 1 || entry.sourcePage > 20 {
                errors.append(.invalidSourcePageNumber(entryNumber: entry.sourceNumber, page: entry.sourcePage))
            }
            if !seenParticleIds.contains(entry.particleId) {
                errors.append(.unresolvedParticleReference(sourceNumber: entry.sourceNumber, particleId: entry.particleId))
            }
            if !seenUsageIds.contains(entry.usageId) {
                errors.append(.unresolvedUsageReference(context: "SourceEntry #\(entry.sourceNumber)", usageId: entry.usageId))
            }
            if entry.reviewStatus == .unreviewed, let usage = usageById[entry.usageId], usage.jlptLevel != nil {
                errors.append(.unverifiedJLPTLevelAssigned(usageId: entry.usageId))
            }
        }

        if requireAll188Numbers {
            let expectedNumbers = Set(1...188)
            let missing = expectedNumbers.subtracting(seenSourceNumbers).sorted()
            if !missing.isEmpty || db.sourceEntries.count != 188 {
                errors.append(.missingSourceNumbers(missing))
            }
        }

        // 4. Validate Particle.usageIds resolve
        for p in db.particles {
            for uid in p.usageIds {
                if !seenUsageIds.contains(uid) {
                    errors.append(.unresolvedUsageReference(context: "Particle '\(p.id)'", usageId: uid))
                }
            }
        }

        // 5. Validate ParticleUsage.relatedUsageIds and grammarPointIds resolve
        for u in db.usages {
            for relatedId in u.relatedUsageIds {
                if !seenUsageIds.contains(relatedId) {
                    errors.append(.unresolvedUsageReference(context: "Usage '\(u.id)' relatedUsageIds", usageId: relatedId))
                }
            }
            if let grammarIds = knownGrammarPointIds {
                for gid in u.grammarPointIds {
                    if !grammarIds.contains(gid) {
                        errors.append(.unresolvedGrammarReference(usageId: u.id, grammarPointId: gid))
                    }
                }
            }
        }

        return ParticleImportValidationResult(
            isValid: errors.isEmpty,
            particleCount: db.particles.count,
            usageCount: db.usages.count,
            sourceEntryCount: db.sourceEntries.count,
            errors: errors
        )
    }

    // MARK: - Idempotent Import (Preserves Progress & Review Records)
    @discardableResult
    func importDatabase(from jsonString: String, requireAll188Numbers: Bool = true) -> ParticleImportValidationResult {
        guard let data = jsonString.data(using: .utf8) else {
            return ParticleImportValidationResult(
                isValid: false,
                particleCount: 0,
                usageCount: 0,
                sourceEntryCount: 0,
                errors: [.parsingFailure("Invalid UTF-8 encoding")]
            )
        }
        return importDatabaseData(data, requireAll188Numbers: requireAll188Numbers)
    }

    @discardableResult
    func importDatabaseData(_ data: Data, requireAll188Numbers: Bool = true) -> ParticleImportValidationResult {
        do {
            let incoming = try JSONDecoder().decode(ParticleDatabase.self, from: data)
            return importDatabase(incoming, requireAll188Numbers: requireAll188Numbers)
        } catch {
            return ParticleImportValidationResult(
                isValid: false,
                particleCount: 0,
                usageCount: 0,
                sourceEntryCount: 0,
                errors: [.parsingFailure(error.localizedDescription)]
            )
        }
    }

    @discardableResult
    func importDatabase(_ incoming: ParticleDatabase, requireAll188Numbers: Bool = true) -> ParticleImportValidationResult {
        let validation = validateDatabase(incoming, requireAll188Numbers: requireAll188Numbers)
        guard validation.isValid else {
            return validation
        }

        // Merge particles by id without creating duplicates
        var mergedParticles = database.particles
        for p in incoming.particles {
            if let idx = mergedParticles.firstIndex(where: { $0.id == p.id }) {
                mergedParticles[idx] = p
            } else {
                mergedParticles.append(p)
            }
        }

        // Merge usages by id without creating duplicates
        var mergedUsages = database.usages
        for u in incoming.usages {
            if let idx = mergedUsages.firstIndex(where: { $0.id == u.id }) {
                mergedUsages[idx] = u
            } else {
                mergedUsages.append(u)
            }
        }

        // Merge sourceEntries by (sourceId + sourceNumber) or id without creating duplicates
        var mergedEntries = database.sourceEntries
        for entry in incoming.sourceEntries {
            if let idx = mergedEntries.firstIndex(where: {
                $0.id == entry.id || ($0.sourceId == entry.sourceId && $0.sourceNumber == entry.sourceNumber)
            }) {
                mergedEntries[idx] = entry
            } else {
                mergedEntries.append(entry)
            }
        }
        mergedEntries.sort { $0.sourceNumber < $1.sourceNumber }

        self.database = ParticleDatabase(
            schemaVersion: incoming.schemaVersion,
            particles: mergedParticles,
            usages: mergedUsages,
            sourceEntries: mergedEntries
        )
        // Note: progressByKey and SRSStorageService review records are intentionally preserved!
        saveDatabase()

        return ParticleImportValidationResult(
            isValid: true,
            particleCount: database.particles.count,
            usageCount: database.usages.count,
            sourceEntryCount: database.sourceEntries.count,
            errors: []
        )
    }

    // MARK: - Lookup Helpers
    func particle(forId id: String) -> Particle? {
        database.particles.first { $0.id == id }
    }

    func usage(forId id: String) -> ParticleUsage? {
        database.usages.first { $0.id == id }
    }

    func usages(forParticleId particleId: String) -> [ParticleUsage] {
        guard let particle = particle(forId: particleId) else { return [] }
        let usageMap = Dictionary(uniqueKeysWithValues: database.usages.map { ($0.id, $0) })
        return particle.usageIds.compactMap { usageMap[$0] }
    }

    func particle(forUsageId usageId: String) -> Particle? {
        if let entry = database.sourceEntries.first(where: { $0.usageId == usageId }) {
            return particle(forId: entry.particleId)
        }
        return database.particles.first { $0.usageIds.contains(usageId) }
    }

    func sourceEntry(forUsageId usageId: String) -> ParticleSourceEntry? {
        database.sourceEntries.first { $0.usageId == usageId }
    }

    func sourceEntry(forNumber number: Int) -> ParticleSourceEntry? {
        database.sourceEntries.first { $0.sourceNumber == number }
    }

    // MARK: - Search & Filter (Section 7 Requirement)
    func searchParticles(
        query: String = "",
        category: ParticleCategory? = nil,
        jlptLevel: JLPTLevel? = nil
    ) -> [Particle] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let usageMap = Dictionary(uniqueKeysWithValues: database.usages.map { ($0.id, $0) })
        let sourceByUsage = Dictionary(uniqueKeysWithValues: database.sourceEntries.map { ($0.usageId, $0) })

        return database.particles.filter { p in
            let pUsages = p.usageIds.compactMap { usageMap[$0] }

            if let cat = category {
                let matchesParticleCat = p.categories.contains(cat)
                let matchesUsageCat = pUsages.contains { $0.tags.contains(cat.rawValue) }
                if !matchesParticleCat && !matchesUsageCat {
                    return false
                }
            }

            if let level = jlptLevel, level != .all {
                let hasVerifiedLevel = pUsages.contains { $0.jlptLevel == level }
                if !hasVerifiedLevel {
                    return false
                }
            }

            if !trimmed.isEmpty {
                let matchesJapanese = p.japanese.lowercased().contains(trimmed)
                let matchesRomaji = p.romaji.lowercased().contains(trimmed)
                let matchesAlt = p.alternativeReadings?.contains(where: { $0.lowercased().contains(trimmed) }) ?? false
                let matchesCat = p.categories.contains { $0.displayName.lowercased().contains(trimmed) || $0.rawValue.lowercased().contains(trimmed) }
                let matchesUsage = pUsages.contains { u in
                    u.meaning.lowercased().contains(trimmed) ||
                    u.explanation.lowercased().contains(trimmed) ||
                    (u.jlptLevel?.rawValue.lowercased() == trimmed) ||
                    (sourceByUsage[u.id]?.originalMeaning.lowercased().contains(trimmed) ?? false)
                }
                if !matchesJapanese && !matchesRomaji && !matchesAlt && !matchesCat && !matchesUsage {
                    return false
                }
            }

            return true
        }
    }

    // MARK: - Progress Tracking (Per Particle Usage)
    func reference(particleId: String, usageId: String) -> LearningItemReference {
        LearningItemReference(domain: .particles, contentId: particleId, subContentId: usageId)
    }

    func progress(for reference: LearningItemReference) -> LearningItemProgress {
        let key = reference.reviewIdentityKey
        return progressByKey[key] ?? LearningItemProgress(identityKey: key)
    }

    func progress(particleId: String, usageId: String) -> LearningItemProgress {
        progress(for: reference(particleId: particleId, usageId: usageId))
    }

    /// Aggregate difficulty for a Particle across its usages (Hard if any usage is Hard, else Medium if any is Medium, else Easy)
    func aggregateDifficulty(for particle: Particle) -> VocabDifficulty {
        let diffs = particle.usageIds.map { progress(particleId: particle.id, usageId: $0).difficulty }
        if diffs.contains(.hard) { return .hard }
        if diffs.contains(.medium) { return .medium }
        return .easy
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

