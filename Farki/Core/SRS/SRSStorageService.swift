import Foundation
import Combine

extension Notification.Name {
    static let srsDataUpdated = Notification.Name("srsDataUpdated")
}

// MARK: - Backup Payload
struct SRSBackupData: Codable {
    let version: Int
    let exportedAt: Date
    let config: SRSConfig
    let cardStates: [CardState]
    let reviewLogs: [ReviewLog]
    let presets: [ScopePreset]
}

// MARK: - SRS Storage Service (Single Source of Truth Coordinator)
final class SRSStorageService: ObservableObject {
    static let shared = SRSStorageService()

    private let db: SRSSQLiteDatabase

    @Published private(set) var cardStates: [String: CardState] = [:]
    @Published private(set) var reviewLogs: [ReviewLog] = []
    @Published private(set) var presets: [ScopePreset] = []
    @Published private(set) var config: SRSConfig = SRSConfig()

    init(database: SRSSQLiteDatabase = .shared) {
        self.db = database
        loadInitialData()
    }

    func loadInitialData() {
        self.cardStates = db.fetchAllCardStates()
        self.reviewLogs = db.fetchAllReviewLogs()
        self.presets = db.fetchAllPresets()
        if let savedConfig = db.fetchConfig() {
            self.config = savedConfig
        }
    }

    // MARK: - Card State Query
    func getCardState(for cardId: String) -> CardState {
        if let existing = cardStates[cardId] {
            return existing
        }
        let fresh = CardState(cardId: cardId, state: .new)
        return fresh
    }

    // MARK: - Record Review
    @discardableResult
    func recordReview(
        cardId: String,
        rating: SRSRating,
        durationMs: Int,
        scope: String,
        now: Date = Date()
    ) -> CardState {
        let beforeState = getCardState(for: cardId)

        // Schedule new card state using active scheduler engine (SM-2 or FSRS)
        let afterState = SRSEngine.schedule(
            card: beforeState,
            rating: rating,
            now: now,
            config: config
        )

        // Create append-only review log with before snapshot for undo
        let log = ReviewLog(
            cardId: cardId,
            timestamp: now,
            rating: rating,
            stateBefore: beforeState.state,
            intervalBefore: beforeState.intervalDays,
            intervalAfter: afterState.intervalDays,
            easeAfter: afterState.ease,
            durationMs: durationMs,
            scope: scope,
            stepIndexBefore: beforeState.stepIndex,
            lapsesBefore: beforeState.lapses,
            repsBefore: beforeState.reps,
            dueBefore: beforeState.due,
            easeBefore: beforeState.ease,
            lastReviewedAtBefore: beforeState.lastReviewedAt
        )

        // Persist to SQLite
        db.upsertCardState(afterState)
        let insertedId = db.insertReviewLog(log)
        var persistedLog = log
        persistedLog.id = insertedId

        // Update in-memory state
        cardStates[cardId] = afterState
        reviewLogs.append(persistedLog)

        NotificationCenter.default.post(name: .srsDataUpdated, object: nil)
        return afterState
    }

    // MARK: - Undo Last Review
    @discardableResult
    func undoLastReview() -> (restoredCard: CardState, undoneLog: ReviewLog)? {
        guard let lastLog = db.deleteLastReviewLog() else { return nil }

        // Restore CardState from log's before-snapshot
        let restoredCard = CardState(
            cardId: lastLog.cardId,
            state: lastLog.stateBefore,
            due: lastLog.dueBefore,
            intervalDays: lastLog.intervalBefore,
            ease: lastLog.easeBefore,
            reps: lastLog.repsBefore,
            lapses: lastLog.lapsesBefore,
            stepIndex: lastLog.stepIndexBefore,
            lastReviewedAt: lastLog.lastReviewedAtBefore
        )

        // Persist restored state
        db.upsertCardState(restoredCard)

        // Update in-memory collections
        cardStates[restoredCard.cardId] = restoredCard
        if let idx = reviewLogs.lastIndex(where: { $0.id == lastLog.id }) {
            reviewLogs.remove(at: idx)
        } else if !reviewLogs.isEmpty {
            reviewLogs.removeLast()
        }

        NotificationCenter.default.post(name: .srsDataUpdated, object: nil)
        return (restoredCard, lastLog)
    }

    // MARK: - Presets Management
    @discardableResult
    func savePreset(name: String, chapters: [Int]) -> ScopePreset {
        let preset = ScopePreset(name: name, chapters: chapters.sorted())
        db.upsertPreset(preset)
        if let idx = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[idx] = preset
        } else {
            presets.append(preset)
        }
        return preset
    }

    func deletePreset(id: String) {
        db.deletePreset(id: id)
        presets.removeAll { $0.id == id }
    }

    // MARK: - Config Management
    func updateConfig(_ newConfig: SRSConfig) {
        self.config = newConfig
        db.saveConfig(newConfig)
        NotificationCenter.default.post(name: .srsDataUpdated, object: nil)
    }

    // MARK: - Progress & Stats Reset (Keeps Config & Presets)
    func resetAllProgressAndStats() {
        _ = db.clearAllProgressAndStats()
        self.cardStates = [:]
        self.reviewLogs = []
        NotificationCenter.default.post(name: .srsDataUpdated, object: nil)
    }

    // MARK: - JSON Export & Import (Backup & Restore)
    func exportBackupData() -> Result<Data, Error> {
        let backup = SRSBackupData(
            version: 1,
            exportedAt: Date(),
            config: config,
            cardStates: Array(cardStates.values),
            reviewLogs: reviewLogs,
            presets: presets
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(backup)
            return .success(data)
        } catch {
            return .failure(error)
        }
    }

    func importBackupData(data: Data) -> Result<Int, Error> {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let backup = try decoder.decode(SRSBackupData.self, from: data)
            let success = db.restoreAllData(
                cardStates: backup.cardStates,
                logs: backup.reviewLogs,
                presets: backup.presets,
                config: backup.config
            )

            if success {
                loadInitialData()
                NotificationCenter.default.post(name: .srsDataUpdated, object: nil)
                return .success(backup.cardStates.count)
            } else {
                return .failure(NSError(domain: "com.farki.srs", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to restore backup into SQLite"]))
            }
        } catch {
            return .failure(error)
        }
    }
}
