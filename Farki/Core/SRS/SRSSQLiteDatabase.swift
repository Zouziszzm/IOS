import Foundation
import SQLite3

// MARK: - UTC Date Formatter Helper
private final class UTCDateFormatter {
    static let shared: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static func string(from date: Date) -> String {
        return shared.string(from: date)
    }

    static func date(from string: String) -> Date? {
        if let d = shared.date(from: string) {
            return d
        }
        // Fallback without fractional seconds
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        fallback.timeZone = TimeZone(secondsFromGMT: 0)
        return fallback.date(from: string)
    }
}

// MARK: - SQLite Database Manager
final class SRSSQLiteDatabase {
    static let shared = SRSSQLiteDatabase()

    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.farki.srs.database", qos: .userInitiated)
    private let currentSchemaVersion: Int32 = 1

    init(inMemory: Bool = false) {
        if inMemory {
            openInMemory()
        } else {
            openDiskDatabase()
        }
        runMigrations()
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    // MARK: - Open Database
    private func openInMemory() {
        if sqlite3_open(":memory:", &db) != SQLITE_OK {
            print("Failed to open in-memory SQLite database: \(errorMessage)")
        }
    }

    private func openDiskDatabase() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            openInMemory()
            return
        }

        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let dbUrl = appSupport.appendingPathComponent("farki_srs_v1.sqlite3")

        if sqlite3_open(dbUrl.path, &db) != SQLITE_OK {
            print("Failed to open SQLite database at \(dbUrl.path): \(errorMessage)")
        } else {
            // Enable WAL mode for high concurrency & performance
            _ = execute(sql: "PRAGMA journal_mode=WAL;")
            _ = execute(sql: "PRAGMA synchronous=NORMAL;")
        }
    }

    private var errorMessage: String {
        if let db = db {
            return String(cString: sqlite3_errmsg(db))
        }
        return "Unknown error (db is nil)"
    }

    private func execute(sql: String) -> Bool {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            if let err = err {
                print("SQLite exec error: \(String(cString: err)) for SQL: \(sql)")
                sqlite3_free(err)
            }
            return false
        }
        return true
    }

    // MARK: - Migrations
    private func runMigrations() {
        var userVersion: Int32 = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                userVersion = sqlite3_column_int(stmt, 0)
            }
        }
        sqlite3_finalize(stmt)

        if userVersion < 1 {
            applyMigrationV1()
            _ = execute(sql: "PRAGMA user_version = 1;")
        }
    }

    private func applyMigrationV1() {
        let sql = """
        CREATE TABLE IF NOT EXISTS card_states (
            card_id TEXT PRIMARY KEY,
            state TEXT NOT NULL,
            due_utc TEXT NOT NULL,
            interval_days REAL NOT NULL,
            ease REAL NOT NULL,
            reps INTEGER NOT NULL,
            lapses INTEGER NOT NULL,
            step_index INTEGER NOT NULL,
            last_reviewed_at_utc TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_card_states_due ON card_states(due_utc);
        CREATE INDEX IF NOT EXISTS idx_card_states_state ON card_states(state);

        CREATE TABLE IF NOT EXISTS review_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            card_id TEXT NOT NULL,
            timestamp_utc TEXT NOT NULL,
            rating INTEGER NOT NULL,
            state_before TEXT NOT NULL,
            interval_before REAL NOT NULL,
            interval_after REAL NOT NULL,
            ease_after REAL NOT NULL,
            duration_ms INTEGER NOT NULL,
            scope TEXT NOT NULL,
            step_index_before INTEGER NOT NULL,
            lapses_before INTEGER NOT NULL,
            reps_before INTEGER NOT NULL,
            due_before_utc TEXT NOT NULL,
            ease_before REAL NOT NULL,
            last_reviewed_at_before_utc TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_review_logs_ts ON review_logs(timestamp_utc);
        CREATE INDEX IF NOT EXISTS idx_review_logs_card_id ON review_logs(card_id);

        CREATE TABLE IF NOT EXISTS scope_presets (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            chapters_json TEXT NOT NULL,
            created_at_utc TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS srs_config (
            id INTEGER PRIMARY KEY,
            config_json TEXT NOT NULL,
            updated_at_utc TEXT NOT NULL
        );
        """
        _ = execute(sql: sql)
    }

    // MARK: - Card State CRUD
    func upsertCardState(_ card: CardState) {
        dbQueue.sync {
            let sql = """
            INSERT INTO card_states (card_id, state, due_utc, interval_days, ease, reps, lapses, step_index, last_reviewed_at_utc)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(card_id) DO UPDATE SET
                state = excluded.state,
                due_utc = excluded.due_utc,
                interval_days = excluded.interval_days,
                ease = excluded.ease,
                reps = excluded.reps,
                lapses = excluded.lapses,
                step_index = excluded.step_index,
                last_reviewed_at_utc = excluded.last_reviewed_at_utc;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (card.cardId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (card.state.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (UTCDateFormatter.string(from: card.due) as NSString).utf8String, -1, nil)
                sqlite3_bind_double(stmt, 4, card.intervalDays)
                sqlite3_bind_double(stmt, 5, card.ease)
                sqlite3_bind_int(stmt, 6, Int32(card.reps))
                sqlite3_bind_int(stmt, 7, Int32(card.lapses))
                sqlite3_bind_int(stmt, 8, Int32(card.stepIndex))

                if let lastReviewed = card.lastReviewedAt {
                    sqlite3_bind_text(stmt, 9, (UTCDateFormatter.string(from: lastReviewed) as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 9)
                }

                _ = sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    func fetchAllCardStates() -> [String: CardState] {
        return dbQueue.sync {
            var results: [String: CardState] = [:]
            let sql = "SELECT card_id, state, due_utc, interval_days, ease, reps, lapses, step_index, last_reviewed_at_utc FROM card_states;"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    guard let cardIdC = sqlite3_column_text(stmt, 0),
                          let stateC = sqlite3_column_text(stmt, 1),
                          let dueC = sqlite3_column_text(stmt, 2) else { continue }

                    let cardId = String(cString: cardIdC)
                    let stateStr = String(cString: stateC)
                    let dueStr = String(cString: dueC)

                    let state = CardStateEnum(rawValue: stateStr) ?? .new
                    let due = UTCDateFormatter.date(from: dueStr) ?? Date()
                    let intervalDays = sqlite3_column_double(stmt, 3)
                    let ease = sqlite3_column_double(stmt, 4)
                    let reps = Int(sqlite3_column_int(stmt, 5))
                    let lapses = Int(sqlite3_column_int(stmt, 6))
                    let stepIndex = Int(sqlite3_column_int(stmt, 7))

                    var lastReviewedAt: Date? = nil
                    if let lastReviewedC = sqlite3_column_text(stmt, 8) {
                        lastReviewedAt = UTCDateFormatter.date(from: String(cString: lastReviewedC))
                    }

                    results[cardId] = CardState(
                        cardId: cardId,
                        state: state,
                        due: due,
                        intervalDays: intervalDays,
                        ease: ease,
                        reps: reps,
                        lapses: lapses,
                        stepIndex: stepIndex,
                        lastReviewedAt: lastReviewedAt
                    )
                }
            }
            sqlite3_finalize(stmt)
            return results
        }
    }

    // MARK: - Review Logs CRUD
    @discardableResult
    func insertReviewLog(_ log: ReviewLog) -> Int64 {
        return dbQueue.sync {
            let sql = """
            INSERT INTO review_logs (
                card_id, timestamp_utc, rating, state_before, interval_before, interval_after,
                ease_after, duration_ms, scope, step_index_before, lapses_before, reps_before,
                due_before_utc, ease_before, last_reviewed_at_before_utc
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            var insertedId: Int64 = 0

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (log.cardId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (UTCDateFormatter.string(from: log.timestamp) as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 3, Int32(log.rating.rawValue))
                sqlite3_bind_text(stmt, 4, (log.stateBefore.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_double(stmt, 5, log.intervalBefore)
                sqlite3_bind_double(stmt, 6, log.intervalAfter)
                sqlite3_bind_double(stmt, 7, log.easeAfter)
                sqlite3_bind_int(stmt, 8, Int32(log.durationMs))
                sqlite3_bind_text(stmt, 9, (log.scope as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 10, Int32(log.stepIndexBefore))
                sqlite3_bind_int(stmt, 11, Int32(log.lapsesBefore))
                sqlite3_bind_int(stmt, 12, Int32(log.repsBefore))
                sqlite3_bind_text(stmt, 13, (UTCDateFormatter.string(from: log.dueBefore) as NSString).utf8String, -1, nil)
                sqlite3_bind_double(stmt, 14, log.easeBefore)

                if let lastRev = log.lastReviewedAtBefore {
                    sqlite3_bind_text(stmt, 15, (UTCDateFormatter.string(from: lastRev) as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 15)
                }

                if sqlite3_step(stmt) == SQLITE_DONE {
                    insertedId = sqlite3_last_insert_rowid(db)
                }
            }
            sqlite3_finalize(stmt)
            return insertedId
        }
    }

    func fetchAllReviewLogs() -> [ReviewLog] {
        return dbQueue.sync {
            var results: [ReviewLog] = []
            let sql = """
            SELECT id, card_id, timestamp_utc, rating, state_before, interval_before, interval_after,
                   ease_after, duration_ms, scope, step_index_before, lapses_before, reps_before,
                   due_before_utc, ease_before, last_reviewed_at_before_utc
            FROM review_logs ORDER BY id ASC;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = sqlite3_column_int64(stmt, 0)
                    guard let cardIdC = sqlite3_column_text(stmt, 1),
                          let tsC = sqlite3_column_text(stmt, 2),
                          let stateBeforeC = sqlite3_column_text(stmt, 4),
                          let scopeC = sqlite3_column_text(stmt, 9),
                          let dueBeforeC = sqlite3_column_text(stmt, 13) else { continue }

                    let cardId = String(cString: cardIdC)
                    let ts = UTCDateFormatter.date(from: String(cString: tsC)) ?? Date()
                    let rating = SRSRating(rawValue: Int(sqlite3_column_int(stmt, 3))) ?? .good
                    let stateBefore = CardStateEnum(rawValue: String(cString: stateBeforeC)) ?? .new
                    let intervalBefore = sqlite3_column_double(stmt, 5)
                    let intervalAfter = sqlite3_column_double(stmt, 6)
                    let easeAfter = sqlite3_column_double(stmt, 7)
                    let durationMs = Int(sqlite3_column_int(stmt, 8))
                    let scope = String(cString: scopeC)
                    let stepIndexBefore = Int(sqlite3_column_int(stmt, 10))
                    let lapsesBefore = Int(sqlite3_column_int(stmt, 11))
                    let repsBefore = Int(sqlite3_column_int(stmt, 12))
                    let dueBefore = UTCDateFormatter.date(from: String(cString: dueBeforeC)) ?? Date()
                    let easeBefore = sqlite3_column_double(stmt, 14)

                    var lastReviewedAtBefore: Date? = nil
                    if let lastRevC = sqlite3_column_text(stmt, 15) {
                        lastReviewedAtBefore = UTCDateFormatter.date(from: String(cString: lastRevC))
                    }

                    results.append(ReviewLog(
                        id: id,
                        cardId: cardId,
                        timestamp: ts,
                        rating: rating,
                        stateBefore: stateBefore,
                        intervalBefore: intervalBefore,
                        intervalAfter: intervalAfter,
                        easeAfter: easeAfter,
                        durationMs: durationMs,
                        scope: scope,
                        stepIndexBefore: stepIndexBefore,
                        lapsesBefore: lapsesBefore,
                        repsBefore: repsBefore,
                        dueBefore: dueBefore,
                        easeBefore: easeBefore,
                        lastReviewedAtBefore: lastReviewedAtBefore
                    ))
                }
            }
            sqlite3_finalize(stmt)
            return results
        }
    }

    func deleteLastReviewLog() -> ReviewLog? {
        return dbQueue.sync {
            guard let lastLog = fetchLastReviewLogInternal() else { return nil }
            if let id = lastLog.id {
                let sql = "DELETE FROM review_logs WHERE id = ?;"
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_int64(stmt, 1, id)
                    _ = sqlite3_step(stmt)
                }
                sqlite3_finalize(stmt)
            }
            return lastLog
        }
    }

    private func fetchLastReviewLogInternal() -> ReviewLog? {
        let sql = """
        SELECT id, card_id, timestamp_utc, rating, state_before, interval_before, interval_after,
               ease_after, duration_ms, scope, step_index_before, lapses_before, reps_before,
               due_before_utc, ease_before, last_reviewed_at_before_utc
        FROM review_logs ORDER BY id DESC LIMIT 1;
        """
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                guard let cardIdC = sqlite3_column_text(stmt, 1),
                      let tsC = sqlite3_column_text(stmt, 2),
                      let stateBeforeC = sqlite3_column_text(stmt, 4),
                      let scopeC = sqlite3_column_text(stmt, 9),
                      let dueBeforeC = sqlite3_column_text(stmt, 13) else { return nil }

                let cardId = String(cString: cardIdC)
                let ts = UTCDateFormatter.date(from: String(cString: tsC)) ?? Date()
                let rating = SRSRating(rawValue: Int(sqlite3_column_int(stmt, 3))) ?? .good
                let stateBefore = CardStateEnum(rawValue: String(cString: stateBeforeC)) ?? .new
                let intervalBefore = sqlite3_column_double(stmt, 5)
                let intervalAfter = sqlite3_column_double(stmt, 6)
                let easeAfter = sqlite3_column_double(stmt, 7)
                let durationMs = Int(sqlite3_column_int(stmt, 8))
                let scope = String(cString: scopeC)
                let stepIndexBefore = Int(sqlite3_column_int(stmt, 10))
                let lapsesBefore = Int(sqlite3_column_int(stmt, 11))
                let repsBefore = Int(sqlite3_column_int(stmt, 12))
                let dueBefore = UTCDateFormatter.date(from: String(cString: dueBeforeC)) ?? Date()
                let easeBefore = sqlite3_column_double(stmt, 14)

                var lastReviewedAtBefore: Date? = nil
                if let lastRevC = sqlite3_column_text(stmt, 15) {
                    lastReviewedAtBefore = UTCDateFormatter.date(from: String(cString: lastRevC))
                }

                return ReviewLog(
                    id: id,
                    cardId: cardId,
                    timestamp: ts,
                    rating: rating,
                    stateBefore: stateBefore,
                    intervalBefore: intervalBefore,
                    intervalAfter: intervalAfter,
                    easeAfter: easeAfter,
                    durationMs: durationMs,
                    scope: scope,
                    stepIndexBefore: stepIndexBefore,
                    lapsesBefore: lapsesBefore,
                    repsBefore: repsBefore,
                    dueBefore: dueBefore,
                    easeBefore: easeBefore,
                    lastReviewedAtBefore: lastReviewedAtBefore
                )
            }
        }
        return nil
    }

    // MARK: - Presets CRUD
    func upsertPreset(_ preset: ScopePreset) {
        dbQueue.sync {
            let sql = """
            INSERT INTO scope_presets (id, name, chapters_json, created_at_utc)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                chapters_json = excluded.chapters_json;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                let chaptersJson = (try? JSONEncoder().encode(preset.chapters)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
                sqlite3_bind_text(stmt, 1, (preset.id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (preset.name as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (chaptersJson as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (UTCDateFormatter.string(from: preset.createdAt) as NSString).utf8String, -1, nil)
                _ = sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    func deletePreset(id: String) {
        dbQueue.sync {
            let sql = "DELETE FROM scope_presets WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
                _ = sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    func fetchAllPresets() -> [ScopePreset] {
        return dbQueue.sync {
            var results: [ScopePreset] = []
            let sql = "SELECT id, name, chapters_json, created_at_utc FROM scope_presets ORDER BY created_at_utc ASC;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    guard let idC = sqlite3_column_text(stmt, 0),
                          let nameC = sqlite3_column_text(stmt, 1),
                          let chaptersC = sqlite3_column_text(stmt, 2),
                          let tsC = sqlite3_column_text(stmt, 3) else { continue }

                    let id = String(cString: idC)
                    let name = String(cString: nameC)
                    let chaptersStr = String(cString: chaptersC)
                    let createdAt = UTCDateFormatter.date(from: String(cString: tsC)) ?? Date()

                    let chapters = (chaptersStr.data(using: .utf8)).flatMap { try? JSONDecoder().decode([Int].self, from: $0) } ?? []
                    results.append(ScopePreset(id: id, name: name, chapters: chapters, createdAt: createdAt))
                }
            }
            sqlite3_finalize(stmt)
            return results
        }
    }

    // MARK: - SRS Config CRUD
    func saveConfig(_ config: SRSConfig) {
        dbQueue.sync {
            guard let data = try? JSONEncoder().encode(config),
                  let jsonStr = String(data: data, encoding: .utf8) else { return }

            let sql = """
            INSERT INTO srs_config (id, config_json, updated_at_utc)
            VALUES (1, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                config_json = excluded.config_json,
                updated_at_utc = excluded.updated_at_utc;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (jsonStr as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (UTCDateFormatter.string(from: Date()) as NSString).utf8String, -1, nil)
                _ = sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    func fetchConfig() -> SRSConfig? {
        return dbQueue.sync {
            let sql = "SELECT config_json FROM srs_config WHERE id = 1;"
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    if let jsonC = sqlite3_column_text(stmt, 0),
                       let data = String(cString: jsonC).data(using: .utf8) {
                        return try? JSONDecoder().decode(SRSConfig.self, from: data)
                    }
                }
            }
            return nil
        }
    }

    // MARK: - Transactional Progress & Stats Reset (Keeps Presets & Config)
    func clearAllProgressAndStats() -> Bool {
        return dbQueue.sync {
            _ = execute(sql: "BEGIN TRANSACTION;")
            _ = execute(sql: "DELETE FROM card_states;")
            _ = execute(sql: "DELETE FROM review_logs;")
            return execute(sql: "COMMIT;")
        }
    }

    // MARK: - Transactional Bulk Reset & Replace (For Backup Restore)
    func restoreAllData(cardStates: [CardState], logs: [ReviewLog], presets: [ScopePreset], config: SRSConfig) -> Bool {
        return dbQueue.sync {
            _ = execute(sql: "BEGIN TRANSACTION;")

            _ = execute(sql: "DELETE FROM card_states;")
            _ = execute(sql: "DELETE FROM review_logs;")
            _ = execute(sql: "DELETE FROM scope_presets;")
            _ = execute(sql: "DELETE FROM srs_config;")

            // Insert config
            if let data = try? JSONEncoder().encode(config),
               let jsonStr = String(data: data, encoding: .utf8) {
                let sql = "INSERT INTO srs_config (id, config_json, updated_at_utc) VALUES (1, '\(jsonStr)', '\(UTCDateFormatter.string(from: Date()))');"
                _ = execute(sql: sql)
            }

            // Insert presets
            for p in presets {
                let chJson = (try? JSONEncoder().encode(p.chapters)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
                let sql = "INSERT INTO scope_presets (id, name, chapters_json, created_at_utc) VALUES ('\(p.id)', '\(p.name.replacingOccurrences(of: "'", with: "''"))', '\(chJson)', '\(UTCDateFormatter.string(from: p.createdAt))');"
                _ = execute(sql: sql)
            }

            // Insert card states
            for card in cardStates {
                let lastRevStr = card.lastReviewedAt.map { "'\(UTCDateFormatter.string(from: $0))'" } ?? "NULL"
                let sql = """
                INSERT INTO card_states (card_id, state, due_utc, interval_days, ease, reps, lapses, step_index, last_reviewed_at_utc)
                VALUES ('\(card.cardId)', '\(card.state.rawValue)', '\(UTCDateFormatter.string(from: card.due))', \(card.intervalDays), \(card.ease), \(card.reps), \(card.lapses), \(card.stepIndex), \(lastRevStr));
                """
                _ = execute(sql: sql)
            }

            // Insert logs
            for log in logs {
                let lastRevStr = log.lastReviewedAtBefore.map { "'\(UTCDateFormatter.string(from: $0))'" } ?? "NULL"
                let sql = """
                INSERT INTO review_logs (
                    card_id, timestamp_utc, rating, state_before, interval_before, interval_after,
                    ease_after, duration_ms, scope, step_index_before, lapses_before, reps_before,
                    due_before_utc, ease_before, last_reviewed_at_before_utc
                ) VALUES (
                    '\(log.cardId)', '\(UTCDateFormatter.string(from: log.timestamp))', \(log.rating.rawValue),
                    '\(log.stateBefore.rawValue)', \(log.intervalBefore), \(log.intervalAfter), \(log.easeAfter),
                    \(log.durationMs), '\(log.scope)', \(log.stepIndexBefore), \(log.lapsesBefore), \(log.repsBefore),
                    '\(UTCDateFormatter.string(from: log.dueBefore))', \(log.easeBefore), \(lastRevStr)
                );
                """
                _ = execute(sql: sql)
            }

            return execute(sql: "COMMIT;")
        }
    }
}
