import Foundation

final class VocabDataService {
    static let shared = VocabDataService()

    private let storageKey = "farki_vocab_repository_v5"
    private(set) var items: [VocabItem] = []

    private init() {
        loadItems()
    }

    // MARK: - Persistence
    private func loadItems() {
        // Clean up previous v4 cache to ensure fresh start with Chapter 1
        UserDefaults.standard.removeObject(forKey: "farki_vocab_repository_v4")

        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([VocabItem].self, from: data),
           !saved.isEmpty {
            self.items = saved
        } else {
            // Feed chapter_01.json in its exact order (75 items, #1..#75)
            self.items = loadChapter01Items() ?? []
            saveItems()
        }

        // Auto-discover and import any chapter JSON files bundled with the app
        loadBundledChapterJSONs()

        // Maintain strict chapter and number sequence
        self.items.sort {
            if $0.chapterNumber == $1.chapterNumber {
                return $0.number < $1.number
            }
            return $0.chapterNumber < $1.chapterNumber
        }
    }

    /// Robust discovery and loading of chapter_01.json across app bundle, resources folder, and filesystem
    func loadChapter01Items() -> [VocabItem]? {
        guard let data = findChapter01JSONData() else {
            return nil
        }
        guard let sheet = try? JSONDecoder().decode(ChapterVocabSheet.self, from: data) else {
            return nil
        }
        return parseEntries(from: sheet)
    }

    private func findChapter01JSONData() -> Data? {
        // 1. Bundle resource at root
        if let url = Bundle.main.url(forResource: "chapter_01", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        // 2. Bundle resource in Vocabulary subdirectory
        if let url = Bundle.main.url(forResource: "chapter_01", withExtension: "json", subdirectory: "Vocabulary"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        // 3. Bundle resource in Resources/Vocabulary subdirectory
        if let url = Bundle.main.url(forResource: "chapter_01", withExtension: "json", subdirectory: "Resources/Vocabulary"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        // 4. Any bundle matching "chapter_01.json"
        if let rootUrls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            if let match = rootUrls.first(where: { $0.lastPathComponent == "chapter_01.json" }),
               let data = try? Data(contentsOf: match) {
                return data
            }
        }
        // 5. Source path relative to #filePath (Works reliably in Simulator, Previews, CLI tests)
        let thisFileUrl = URL(fileURLWithPath: #filePath)
        let candidatePath = thisFileUrl.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Vocabulary/chapter_01.json")
        if let data = try? Data(contentsOf: candidatePath) {
            return data
        }
        // 6. Absolute path fallback
        let absolutePath = "/Users/static/Documents/projects/farki/Farki/Resources/Vocabulary/chapter_01.json"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: absolutePath)) {
            return data
        }
        return nil
    }

    /// Automatically scans the app bundle for any chapter JSON files and multi-chapter OpenJLPT sheets
    func loadBundledChapterJSONs() {
        var didImport = false
        var jsonUrls: [URL] = []

        if let rootUrls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            jsonUrls.append(contentsOf: rootUrls)
        }
        if let vocabUrls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Vocabulary") {
            jsonUrls.append(contentsOf: vocabUrls)
        }

        for url in jsonUrls {
            if let data = try? Data(contentsOf: url) {
                // If it's a single chapter sheet, import and merge it
                if case .success = importChapterJson(data: data) {
                    didImport = true
                }
            }
        }

        // Also load the bundled multi-chapter OpenJLPT dataset (Chapters 2–50)
        if let multiData = findOpenJLPTVocabJSONData(),
           let sheets = try? JSONDecoder().decode([ChapterVocabSheet].self, from: multiData) {
            let existingChapters = Set(items.map(\.chapterNumber))
            for sheet in sheets {
                if !existingChapters.contains(sheet.chapterNumber) {
                    let parsed = parseEntries(from: sheet)
                    items.append(contentsOf: parsed)
                    didImport = true
                }
            }
        }

        if didImport {
            items.sort {
                if $0.chapterNumber == $1.chapterNumber {
                    return $0.number < $1.number
                }
                return $0.chapterNumber < $1.chapterNumber
            }
            saveItems()
        }
    }

    private func findOpenJLPTVocabJSONData() -> Data? {
        if let url = Bundle.main.url(forResource: "openjlpt_vocab_chapters", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        if let url = Bundle.main.url(forResource: "openjlpt_vocab_chapters", withExtension: "json", subdirectory: "Vocabulary"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        if let url = Bundle.main.url(forResource: "openjlpt_vocab_chapters", withExtension: "json", subdirectory: "Resources/Vocabulary"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        let thisFileUrl = URL(fileURLWithPath: #filePath)
        let candidatePath = thisFileUrl
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Vocabulary/openjlpt_vocab_chapters.json")
        if let data = try? Data(contentsOf: candidatePath) {
            return data
        }
        let absolutePath = "/Users/static/Documents/projects/farki/Farki/Resources/Vocabulary/openjlpt_vocab_chapters.json"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: absolutePath)) {
            return data
        }
        return nil
    }

    func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
            NotificationCenter.default.post(name: .vocabDataUpdated, object: nil)
        }
    }


    // MARK: - Query & Filter (Requirement 12: Filterable by Textbook, Book, Chapter, JLPT, Learning Status)
    var availableChapters: [Int] {
        Array(Set(items.map { $0.chapterNumber })).sorted()
    }

    func fetchVocabItems(filter: VocabFilter = VocabFilter()) -> [VocabItem] {
        return items.filter { item in
            if let textbook = filter.textbook, item.textbook != textbook {
                return false
            }
            if let book = filter.selectedBook, item.bookNumber != book.rawValue {
                return false
            }
            if !filter.selectedChapters.isEmpty {
                if !filter.selectedChapters.contains(item.chapterNumber) {
                    return false
                }
            } else if let chapter = filter.selectedChapter, item.chapterNumber != chapter {
                return false
            }
            if let jlpt = filter.selectedJLPTLevel, item.jlptLevel != jlpt {
                return false
            }
            if !filter.selectedSectionCategories.isEmpty {
                let matchesAnySection = filter.selectedSectionCategories.contains { $0.matches(item.wordType) }
                if !matchesAnySection {
                    return false
                }
            }
            if let status = filter.selectedLearningStatus, item.learningState != status {
                return false
            }
            if filter.troubleWordsOnly && item.difficulty == .easy {
                return false
            }
            return true
        }
    }

    // MARK: - Import Chapter Vocabulary Sheet (Requirement 12)
    @discardableResult
    func importChapter(from jsonString: String) -> VocabImportValidationResult {
        guard let data = jsonString.data(using: .utf8) else {
            return VocabImportValidationResult(
                isValid: false,
                chapterNumber: 0,
                bookNumber: 0,
                importedCount: 0,
                updatedCount: 0,
                errors: [.parsingFailure("Invalid UTF-8 encoding")],
                warnings: []
            )
        }
        switch importChapterJson(data: data) {
        case .success(let result):
            return result
        case .failure(let error):
            return VocabImportValidationResult(
                isValid: false,
                chapterNumber: 0,
                bookNumber: 0,
                importedCount: 0,
                updatedCount: 0,
                errors: [error],
                warnings: []
            )
        }
    }

    func importChapterJson(data: Data) -> Result<VocabImportValidationResult, VocabImportError> {
        do {
            let sheet = try JSONDecoder().decode(ChapterVocabSheet.self, from: data)
            return importChapterSheet(sheet)
        } catch {
            return .failure(.parsingFailure(error.localizedDescription))
        }
    }

    // MARK: - Parse Entries from Chapter Sheet
    func parseEntries(from sheet: ChapterVocabSheet) -> [VocabItem] {
        var parsedEntries: [VocabItem] = []

        for (index, entry) in sheet.entries.enumerated() {
            guard !entry.japanese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !entry.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !entry.romaji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            // Parse part of speech
            let wordType: VocabWordType
            switch entry.partOfSpeech.lowercased() {
            case "verb_group1", "v1", "group1":
                wordType = .verb(.group1)
            case "verb_group2", "v2", "group2":
                wordType = .verb(.group2)
            case "verb_group3", "v3", "group3":
                wordType = .verb(.group3)
            case "i_adjective", "i-adj", "iadjective":
                wordType = .iAdjective
            case "na_adjective", "na-adj", "naadjective":
                wordType = .naAdjective
            case "noun":
                wordType = .noun
            default:
                wordType = .other(entry.partOfSpeech)
            }

            // Parse JLPT Level: N5 or N4
            let jlptLevel: JLPTLevel
            if let rawLevel = entry.jlptLevel?.uppercased(), !rawLevel.isEmpty {
                jlptLevel = (rawLevel == "N4") ? .n4 : .n5
            } else {
                jlptLevel = (sheet.bookNumber == 1) ? .n5 : .n4
            }

            // Stable unique ID
            let stableId: String
            if let customId = entry.id, !customId.isEmpty {
                stableId = customId
            } else {
                let sanitizedWord = entry.japanese.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "\(index)"
                stableId = "mnn-b\(sheet.bookNumber)-c\(String(format: "%02d", sheet.chapterNumber))-\(sanitizedWord)"
            }

            let kana = entry.kana ?? entry.japanese
            let categoryTag = entry.categoryTag ?? (sheet.bookNumber == 1 ? "ひらがな" : "漢字")
            let position = entry.number ?? (index + 1)
            let difficulty = VocabDifficulty.from(string: entry.difficulty)

            let newItem = VocabItem(
                id: stableId,
                textbook: .minnaNoNihongo,
                bookNumber: sheet.bookNumber,
                chapterNumber: sheet.chapterNumber,
                number: position,
                japanese: entry.japanese,
                kanji: entry.kanji,
                kana: kana,
                romaji: entry.romaji,
                meaning: entry.meaning,
                wordType: wordType,
                jlptLevel: jlptLevel,
                categoryTag: categoryTag,
                difficulty: difficulty,
                bestTimeSeconds: nil,
                learningState: .unseen,
                currentStreak: 0,
                bestStreak: 0,
                examples: entry.examples ?? []
            )
            parsedEntries.append(newItem)
        }

        return parsedEntries
    }

    func importChapterSheet(_ sheet: ChapterVocabSheet) -> Result<VocabImportValidationResult, VocabImportError> {
        // 1. Validate Book Number (1 or 2)
        guard sheet.bookNumber == 1 || sheet.bookNumber == 2 else {
            return .failure(.invalidBookNumber(sheet.bookNumber))
        }

        // 2. Validate Chapter Number (1..50)
        guard (1...50).contains(sheet.chapterNumber) else {
            return .failure(.invalidChapterNumber(sheet.chapterNumber))
        }

        // 3. Validate Chapter and Book alignment
        let expectedBook = sheet.chapterNumber <= 25 ? 1 : 2
        guard sheet.bookNumber == expectedBook else {
            return .failure(.chapterBookMismatch(chapter: sheet.chapterNumber, book: sheet.bookNumber))
        }

        // 4. Validate non-empty entries
        guard !sheet.entries.isEmpty else {
            return .failure(.emptyEntries)
        }

        var importedCount = 0
        var updatedCount = 0
        let warnings: [String] = []

        // 5. Validate Entries
        for (index, entry) in sheet.entries.enumerated() {
            guard !entry.japanese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .failure(.missingRequiredField(field: "japanese", entryIndex: index))
            }
            guard !entry.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .failure(.missingRequiredField(field: "meaning", entryIndex: index))
            }
            guard !entry.romaji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .failure(.missingRequiredField(field: "romaji", entryIndex: index))
            }
        }

        let validatedEntries = parseEntries(from: sheet)

        // 6. Merge Into Existing Repository Preserving History (Requirement 12)
        for validatedItem in validatedEntries {
            if let existingIndex = items.firstIndex(where: { $0.id == validatedItem.id || ($0.chapterNumber == validatedItem.chapterNumber && $0.bookNumber == validatedItem.bookNumber && $0.japanese == validatedItem.japanese) }) {
                // Update entry while preserving learning history and streak records
                var updated = validatedItem
                updated.learningState = items[existingIndex].learningState
                updated.bestTimeSeconds = items[existingIndex].bestTimeSeconds
                updated.currentStreak = items[existingIndex].currentStreak
                updated.bestStreak = items[existingIndex].bestStreak
                items[existingIndex] = updated
                updatedCount += 1
            } else {
                items.append(validatedItem)
                importedCount += 1
            }
        }

        // Keep items strictly sorted by chapter number and word number in chapter
        items.sort {
            if $0.chapterNumber == $1.chapterNumber {
                return $0.number < $1.number
            }
            return $0.chapterNumber < $1.chapterNumber
        }

        saveItems()

        return .success(VocabImportValidationResult(
            isValid: true,
            chapterNumber: sheet.chapterNumber,
            bookNumber: sheet.bookNumber,
            importedCount: importedCount,
            updatedCount: updatedCount,
            errors: [],
            warnings: warnings
        ))
    }

    // MARK: - Update Word Progress
    func updateWordProgress(
        id: String,
        learningState: VocabLearningState,
        difficulty: VocabDifficulty? = nil,
        responseTime: TimeInterval? = nil,
        isCorrect: Bool? = nil
    ) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items[index]
        item.learningState = learningState
        if let diff = difficulty {
            item.difficulty = diff
        }
        if let correct = isCorrect {
            if correct {
                item.currentStreak += 1
                item.bestStreak = max(item.bestStreak, item.currentStreak)
            } else {
                item.currentStreak = 0
            }
        }
        if let time = responseTime {
            if let currentBest = item.bestTimeSeconds {
                if time < currentBest {
                    item.bestTimeSeconds = time
                }
            } else {
                item.bestTimeSeconds = time
            }
        }
        items[index] = item
        saveItems()
    }

    func updateItem(
        id: String,
        learningState: VocabLearningState,
        difficulty: VocabDifficulty? = nil,
        responseTime: TimeInterval? = nil,
        isCorrect: Bool? = nil
    ) {
        updateWordProgress(
            id: id,
            learningState: learningState,
            difficulty: difficulty,
            responseTime: responseTime,
            isCorrect: isCorrect
        )
    }

    // MARK: - Reset / Clear Repository
    func clearAllItems() {
        self.items = []
        saveItems()
    }

    // MARK: - Reset Progress & Stats (Keeps All Vocab Words Intact)
    /// Resets all learning progress, streaks, best times, and SRS card states while keeping all vocabulary entries intact.
    func resetProgressAndStatsKeepVocab() {
        for i in 0..<items.count {
            items[i].learningState = .unseen
            items[i].currentStreak = 0
            items[i].bestStreak = 0
            items[i].bestTimeSeconds = nil
            items[i].difficulty = .easy
        }

        items.sort {
            if $0.chapterNumber == $1.chapterNumber {
                return $0.number < $1.number
            }
            return $0.chapterNumber < $1.chapterNumber
        }

        saveItems()

        // Reset all SQLite card states and review logs
        SRSStorageService.shared.resetAllProgressAndStats()
        ParticleDataService.shared.resetProgressKeepContent()
        GrammarDataService.shared.resetProgressKeepContent()
        ExamService.shared.resetExamAttempts()
        VocabRevisionService.shared.resetAllRevisionProgress()

        NotificationCenter.default.post(name: .vocabDataUpdated, object: nil)
    }

    /// Fully resets to fresh Chapter 1 state
    func resetToFreshChapter01() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: "farki_vocab_repository_v4")

        self.items = loadChapter01Items() ?? []

        for i in 0..<items.count {
            items[i].learningState = .unseen
            items[i].currentStreak = 0
            items[i].bestStreak = 0
            items[i].bestTimeSeconds = nil
            items[i].difficulty = .easy
        }

        items.sort {
            if $0.chapterNumber == $1.chapterNumber {
                return $0.number < $1.number
            }
            return $0.chapterNumber < $1.chapterNumber
        }

        saveItems()
        SRSStorageService.shared.resetAllProgressAndStats()
        VocabRevisionService.shared.resetAllRevisionProgress()
        NotificationCenter.default.post(name: .vocabDataUpdated, object: nil)
    }

}

extension Notification.Name {
    static let vocabDataUpdated = Notification.Name("vocabDataUpdated")
}
