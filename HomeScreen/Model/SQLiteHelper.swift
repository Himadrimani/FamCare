import Foundation
import SQLite3

class SQLiteHelper {
    
    static let shared = SQLiteHelper()
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.project.sqlite.queue")

    private init() {
        db = openDatabase()
        createTables()
        migrateIfNeeded()
    }

    deinit {
        sqlite3_close(db)
    }

    private func openDatabase() -> OpaquePointer? {
        let fileURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Users.sqlite")
        
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(fileURL.path, &db, flags, nil) != SQLITE_OK {
            print("Error opening DB")
            return nil
        }
        sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        print("Database opened at: \(fileURL.path)")
        return db
    }

    func createTables() {
        let createProfilesTable = """
        CREATE TABLE IF NOT EXISTS Profiles (
            profileId TEXT PRIMARY KEY,
            familyId TEXT,
            firstName TEXT,
            lastName TEXT,
            nickName TEXT,
            email TEXT,
            gender TEXT,
            dob TEXT,
            profilePic TEXT,
            heightCm REAL,
            weightKg REAL,
            timeZone TEXT,
            stepGoal INTEGER,
            caloriesGoal INTEGER,
            distanceGoal INTEGER,
            sleepGoal REAL,
            createdAt TEXT,
            lastUpdatedAt TEXT,
            visibleMetricIds TEXT,
            isSynced INTEGER DEFAULT 0,
            FOREIGN KEY (familyId) REFERENCES Families (familyId) ON DELETE CASCADE
        );
        """

        let createFamiliesTable = """
        CREATE TABLE IF NOT EXISTS Families (
            familyId TEXT PRIMARY KEY,
            familyName TEXT,
            sharableCode TEXT,
            createdBy TEXT,
            createdAt TEXT,
            lastUpdatedAt TEXT,
            isSynced INTEGER DEFAULT 0,
            FOREIGN KEY (createdBy) REFERENCES Profiles (profileId) ON DELETE SET NULL
        );
        """

        let createChallengeDetailsTable = """
        CREATE TABLE IF NOT EXISTS ChallengeDetails (
            challengeId TEXT PRIMARY KEY,
            familyId TEXT,
            name TEXT,
            description TEXT,
            type TEXT,
            subType TEXT,
            status TEXT,
            bgImage TEXT,
            startDate TEXT,
            endDate TEXT,
            lastUpdatedAt TEXT,
            isSynced INTEGER DEFAULT 0,
            FOREIGN KEY (familyId) REFERENCES Families (familyId) ON DELETE CASCADE
        );
        """

        let createChallengeProgressTable = """
        CREATE TABLE IF NOT EXISTS ChallengeProgress (
            challengeId TEXT,
            memberId TEXT,
            goalValue REAL,
            currentValue REAL,
            lastUpdatedAt TEXT,
            isSynced INTEGER DEFAULT 0,
            PRIMARY KEY (challengeId, memberId),
            FOREIGN KEY (challengeId) REFERENCES ChallengeDetails (challengeId) ON DELETE CASCADE,
            FOREIGN KEY (memberId) REFERENCES Profiles (profileId) ON DELETE CASCADE
        );
        """

        let createMessagesTable = """
        CREATE TABLE IF NOT EXISTS Messages (
            messageId TEXT PRIMARY KEY,
            senderId TEXT,
            receiverId TEXT,
            timestampUTC TEXT,
            message TEXT,
            deliveredAt TEXT,
            readAt TEXT,
            lastUpdatedAt TEXT,
            isSynced INTEGER DEFAULT 0,
            FOREIGN KEY (senderId) REFERENCES Profiles (profileId) ON DELETE CASCADE,
            FOREIGN KEY (receiverId) REFERENCES Profiles (profileId) ON DELETE CASCADE
        );
        """

        let createVitalsHourlyTable = """
        CREATE TABLE IF NOT EXISTS Health_VitalsHourly (
            id TEXT PRIMARY KEY,
            profileId TEXT,
            type TEXT,
            hourStart TEXT,
            minValue REAL,
            avgValue REAL,
            maxValue REAL,
            sampleCount INTEGER,
            createdAt TEXT,
            lastUpdatedAt TEXT,
            isSynced INTEGER DEFAULT 0,
            FOREIGN KEY (profileId) REFERENCES Profiles (profileId) ON DELETE CASCADE
        );
        """

        let createVitalsDailyTable = """
        CREATE TABLE IF NOT EXISTS Health_VitalsDaily (
            id TEXT PRIMARY KEY,
            profileId TEXT,
            type TEXT,
            date TEXT,
            minValue REAL,
            avgValue REAL,
            maxValue REAL,
            createdAt TEXT,
            lastUpdatedAt TEXT,
            isSynced INTEGER DEFAULT 0,
            FOREIGN KEY (profileId) REFERENCES Profiles (profileId) ON DELETE CASCADE
        );
        """


        let createActivityHourlyTable = """
        CREATE TABLE IF NOT EXISTS Health_ActivityHourly (
            id TEXT PRIMARY KEY,
            profileId TEXT,
            type TEXT,
            value REAL,
            hourStart TEXT,
            sampleCount INTEGER,
            createdAt TEXT,
            lastUpdatedAt TEXT,
            isSynced INTEGER DEFAULT 0,
            FOREIGN KEY (profileId) REFERENCES Profiles (profileId) ON DELETE CASCADE
        );
        """

        let createActivityDailyTable = """
        CREATE TABLE IF NOT EXISTS Health_ActivityDaily (
            id TEXT PRIMARY KEY,
            profileId TEXT,
            type TEXT,
            value REAL,
            date TEXT,
            createdAt TEXT,
            lastUpdatedAt TEXT,
            isSynced INTEGER DEFAULT 0,
            FOREIGN KEY (profileId) REFERENCES Profiles (profileId) ON DELETE CASCADE
        );
        """

        let createSleepDailyTable = """
        CREATE TABLE IF NOT EXISTS Health_SleepDaily (
            id TEXT PRIMARY KEY,
            profileId TEXT,
            date TEXT,
            totalSleep REAL,
            deepSleep REAL,
            remSleep REAL,
            lightSleep REAL,
            sleepStart TEXT,
            sleepEnd TEXT,
            createdAt TEXT,
            lastUpdatedAt TEXT,
            isSynced INTEGER DEFAULT 0,
            FOREIGN KEY (profileId) REFERENCES Profiles (profileId) ON DELETE CASCADE
        );
        """

        let createTopicsTable = """
        CREATE TABLE IF NOT EXISTS Topics (
            id TEXT PRIMARY KEY,
            title TEXT,
            createdBy TEXT,
            createdAt TEXT,
            isSynced INTEGER DEFAULT 0,
            FOREIGN KEY (createdBy) REFERENCES Profiles (profileId) ON DELETE SET NULL
        );
        """

        let createTopicMembersTable = """
        CREATE TABLE IF NOT EXISTS TopicMembers (
            id TEXT PRIMARY KEY,
            topicId TEXT,
            userId TEXT,
            isSynced INTEGER DEFAULT 0,
            FOREIGN KEY (topicId) REFERENCES Topics (id) ON DELETE CASCADE,
            FOREIGN KEY (userId) REFERENCES Profiles (profileId) ON DELETE CASCADE
        );
        """

        let createTopicMessagesTable = """
        CREATE TABLE IF NOT EXISTS TopicMessages (
            id TEXT PRIMARY KEY,
            topicId TEXT,
            senderId TEXT,
            content TEXT,
            createdAt TEXT,
            isSynced INTEGER DEFAULT 0,
            FOREIGN KEY (topicId) REFERENCES Topics (id) ON DELETE CASCADE,
            FOREIGN KEY (senderId) REFERENCES Profiles (profileId) ON DELETE CASCADE
        );
        """
        
        // Viewer-specific nicknames/relationships
        let createUserRelationshipsTable = """
        CREATE TABLE IF NOT EXISTS UserRelationships (
            viewerId TEXT,
            targetId TEXT,
            nickname TEXT,
            isSynced INTEGER DEFAULT 0,
            PRIMARY KEY (viewerId, targetId),
            FOREIGN KEY (viewerId) REFERENCES Profiles (profileId) ON DELETE CASCADE,
            FOREIGN KEY (targetId) REFERENCES Profiles (profileId) ON DELETE CASCADE
        );
        """

        let createMessagesUserIdxA = "CREATE INDEX IF NOT EXISTS idx_messages_sender_time ON Messages (senderId, timestampUTC);"
        let createMessagesUserIdxB = "CREATE INDEX IF NOT EXISTS idx_messages_receiver_time ON Messages (receiverId, timestampUTC);"
        let createTopicMembersUserIdx = "CREATE INDEX IF NOT EXISTS idx_topic_members_user_topic ON TopicMembers (userId, topicId);"
        let createTopicMessagesTopicIdx = "CREATE INDEX IF NOT EXISTS idx_topic_messages_topic_time ON TopicMessages (topicId, createdAt);"
        let createHealthActivityDailyIdx = "CREATE INDEX IF NOT EXISTS idx_activity_daily_profile_date ON Health_ActivityDaily (profileId, date);"
        let createHealthVitalsDailyIdx = "CREATE INDEX IF NOT EXISTS idx_vitals_daily_profile_date ON Health_VitalsDaily (profileId, date);"
        let createHealthSleepDailyIdx = "CREATE INDEX IF NOT EXISTS idx_sleep_daily_profile_date ON Health_SleepDaily (profileId, date);"

        let tables = [
            createProfilesTable, createFamiliesTable, createChallengeDetailsTable,
            createChallengeProgressTable, createMessagesTable, createVitalsHourlyTable,
            createVitalsDailyTable, createActivityHourlyTable,
            createActivityDailyTable, createSleepDailyTable,
            createTopicsTable, createTopicMembersTable, createTopicMessagesTable,
            createUserRelationshipsTable,
            createMessagesUserIdxA, createMessagesUserIdxB,
            createTopicMembersUserIdx, createTopicMessagesTopicIdx,
            createHealthActivityDailyIdx, createHealthVitalsDailyIdx, createHealthSleepDailyIdx
        ]

        // Ensure sleepGoal exists in existing DBs
        sqlite3_exec(db, "ALTER TABLE Profiles ADD COLUMN sleepGoal REAL DEFAULT 8.0;", nil, nil, nil)

        for sql in tables {
            execute(sql: sql)
        }
    }

    /// Resets isSynced = 0 on all health tables so they are pushed to Supabase on next sync.
    /// Needed when health data was migrated from JSON with isSynced = true already baked in.
    func resetHealthSyncFlags() {
        let healthTables = [
            "Health_ActivityDaily", "Health_ActivityHourly",
            "Health_VitalsDaily", "Health_VitalsHourly",
            "Health_SleepDaily"
        ]
        for table in healthTables {
            execute(sql: "UPDATE \"\(table)\" SET isSynced = 0;")
        }
        print("SQLiteHelper: Reset isSynced = 0 on all health tables (\(healthTables.count) tables).")
    }

    /// Marks a single profile's health rows as unsynced so they are (re-)uploaded on the
    /// next sync. Used when the user grants/re-grants family health-sharing consent.
    func markCurrentUserHealthDataUnsynced(for profileId: UUID) {
        let healthTables = [
            "Health_ActivityDaily", "Health_ActivityHourly",
            "Health_VitalsDaily", "Health_VitalsHourly",
            "Health_SleepDaily"
        ]
        let key = profileId.uuidString
        for table in healthTables {
            execute(sql: "UPDATE \"\(table)\" SET isSynced = 0 WHERE profileId = '\(key)';")
        }
    }

    func replaceHealthData(
        for profileId: UUID,
        activityDaily: [ActivityDaily],
        activityHourly: [ActivityHourly],
        vitalsDaily: [VitalsDaily],
        vitalsHourly: [VitalsHourly],
        sleepDaily: [SleepDaily]
    ) {
        // Fetch existing records first to preserve their IDs for UPSERT, and to prevent overwriting with 0s
        let existingActivityDaily = fetchActivityDaily(for: profileId)
        let existingActivityHourly = fetchActivityHourly(for: profileId)
        let existingVitalsDaily = fetchVitalsDaily(for: profileId)
        let existingVitalsHourly = fetchVitalsHourly(for: profileId)
        let existingSleepDaily = fetchSleepDaily(for: profileId)
        
        let calendar = Calendar.current
        
        var mergedActivityDaily: [ActivityDaily] = []
        for newRow in activityDaily {
            if let existing = existingActivityDaily.first(where: { $0.type == newRow.type && calendar.isDate($0.date, inSameDayAs: newRow.date) }) {
                if newRow.value > 0 {
                    var updated = newRow
                    updated.id = existing.id
                    mergedActivityDaily.append(updated)
                }
            } else if newRow.value > 0 {
                mergedActivityDaily.append(newRow)
            }
        }
        
        var mergedActivityHourly: [ActivityHourly] = []
        for newRow in activityHourly {
            if let existing = existingActivityHourly.first(where: { $0.type == newRow.type && $0.hourStart == newRow.hourStart }) {
                if newRow.value > 0 {
                    var updated = newRow
                    updated.id = existing.id
                    mergedActivityHourly.append(updated)
                }
            } else if newRow.value > 0 {
                mergedActivityHourly.append(newRow)
            }
        }
        
        var mergedVitalsDaily: [VitalsDaily] = []
        for newRow in vitalsDaily {
            if let existing = existingVitalsDaily.first(where: { $0.type == newRow.type && calendar.isDate($0.date, inSameDayAs: newRow.date) }) {
                if let avg = newRow.avgValue, avg > 0 {
                    var updated = newRow
                    updated.id = existing.id
                    mergedVitalsDaily.append(updated)
                }
            } else if let avg = newRow.avgValue, avg > 0 {
                mergedVitalsDaily.append(newRow)
            }
        }
        
        var mergedVitalsHourly: [VitalsHourly] = []
        for newRow in vitalsHourly {
            if let existing = existingVitalsHourly.first(where: { $0.type == newRow.type && $0.hourStart == newRow.hourStart }) {
                if let avg = newRow.avgValue, avg > 0 {
                    var updated = newRow
                    updated.id = existing.id
                    mergedVitalsHourly.append(updated)
                }
            } else if let avg = newRow.avgValue, avg > 0 {
                mergedVitalsHourly.append(newRow)
            }
        }
        
        var mergedSleepDaily: [SleepDaily] = []
        for newRow in sleepDaily {
            if let existing = existingSleepDaily.first(where: { calendar.isDate($0.date, inSameDayAs: newRow.date) }) {
                if newRow.totalSleep > 0 {
                    var updated = newRow
                    updated.id = existing.id
                    mergedSleepDaily.append(updated)
                }
            } else if newRow.totalSleep > 0 {
                mergedSleepDaily.append(newRow)
            }
        }
        
        // Save the valid, merged records. INSERT OR REPLACE upserts them by id.
        for row in mergedActivityDaily { saveActivityDaily(row) }
        for row in mergedActivityHourly { saveActivityHourly(row) }
        for row in mergedVitalsDaily { saveVitalsDaily(row) }
        for row in mergedVitalsHourly { saveVitalsHourly(row) }
        for row in mergedSleepDaily { saveSleepDaily(row) }

        // Deletion-aware reconciliation.
        //
        // The incoming payload is authoritative for the time window and metric types
        // it actually covers (HealthKit statistics enumerate EVERY bucket in the range,
        // so a day/hour that is missing/zero here means the samples were removed in
        // Health). Any existing local row that falls inside that window, is for a type
        // the payload covers, and is NOT among the rows we just upserted, corresponds to
        // data the user deleted — so we remove it too. Rows OUTSIDE the covered window
        // (older history, or types whose fetch failed and returned nothing) are left
        // untouched, preserving previously-synced/offline data.

        func dayWindow<T>(_ rows: [T], _ date: (T) -> Date) -> (ClosedRange<Date>)? {
            let days = rows.map { calendar.startOfDay(for: date($0)) }
            guard let lo = days.min(), let hi = days.max() else { return nil }
            return lo...hi
        }
        func window<T>(_ rows: [T], _ date: (T) -> Date) -> (ClosedRange<Date>)? {
            let ds = rows.map(date)
            guard let lo = ds.min(), let hi = ds.max() else { return nil }
            return lo...hi
        }

        // Activity daily
        if let w = dayWindow(activityDaily, { $0.date }) {
            let presentTypes = Set(activityDaily.map { $0.type })
            let keptIds = Set(mergedActivityDaily.map { $0.id })
            let staleIds = existingActivityDaily.filter {
                presentTypes.contains($0.type) &&
                w.contains(calendar.startOfDay(for: $0.date)) &&
                !keptIds.contains($0.id)
            }.map { $0.id }
            deleteHealthRows(table: "Health_ActivityDaily", ids: staleIds)
        }

        // Activity hourly
        if let w = window(activityHourly, { $0.hourStart }) {
            let presentTypes = Set(activityHourly.map { $0.type })
            let keptIds = Set(mergedActivityHourly.map { $0.id })
            let staleIds = existingActivityHourly.filter {
                presentTypes.contains($0.type) &&
                w.contains($0.hourStart) &&
                !keptIds.contains($0.id)
            }.map { $0.id }
            deleteHealthRows(table: "Health_ActivityHourly", ids: staleIds)
        }

        // Vitals daily
        if let w = dayWindow(vitalsDaily, { $0.date }) {
            let presentTypes = Set(vitalsDaily.map { $0.type })
            let keptIds = Set(mergedVitalsDaily.map { $0.id })
            let staleIds = existingVitalsDaily.filter {
                presentTypes.contains($0.type) &&
                w.contains(calendar.startOfDay(for: $0.date)) &&
                !keptIds.contains($0.id)
            }.map { $0.id }
            deleteHealthRows(table: "Health_VitalsDaily", ids: staleIds)
        }

        // Vitals hourly
        if let w = window(vitalsHourly, { $0.hourStart }) {
            let presentTypes = Set(vitalsHourly.map { $0.type })
            let keptIds = Set(mergedVitalsHourly.map { $0.id })
            let staleIds = existingVitalsHourly.filter {
                presentTypes.contains($0.type) &&
                w.contains($0.hourStart) &&
                !keptIds.contains($0.id)
            }.map { $0.id }
            deleteHealthRows(table: "Health_VitalsHourly", ids: staleIds)
        }

        // Sleep daily (single, untyped metric)
        if let w = dayWindow(sleepDaily, { $0.date }) {
            let keptIds = Set(mergedSleepDaily.map { $0.id })
            let staleIds = existingSleepDaily.filter {
                w.contains(calendar.startOfDay(for: $0.date)) &&
                !keptIds.contains($0.id)
            }.map { $0.id }
            deleteHealthRows(table: "Health_SleepDaily", ids: staleIds)
        }
    }

    /// Deletes health rows by primary-key id from the given table.
    private func deleteHealthRows(table: String, ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let inList = ids.map { "'\($0.uuidString)'" }.joined(separator: ",")
        execute(sql: "DELETE FROM \(table) WHERE id IN (\(inList));")
    }

    func clearHealthData(for profileId: UUID) {
        let profileKey = profileId.uuidString
        let deletions = [
            "DELETE FROM Health_ActivityDaily WHERE profileId = '\(profileKey)';",
            "DELETE FROM Health_ActivityHourly WHERE profileId = '\(profileKey)';",
            "DELETE FROM Health_VitalsDaily WHERE profileId = '\(profileKey)';",
            "DELETE FROM Health_VitalsHourly WHERE profileId = '\(profileKey)';",
            "DELETE FROM Health_SleepDaily WHERE profileId = '\(profileKey)';"
        ]

        queue.sync {
            for sql in deletions {
                var statement: OpaquePointer?
                if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_step(statement)
                }
                sqlite3_finalize(statement)
            }
        }
    }
    
    /// Ensures existing databases get new columns without requiring a full reset.
    private func migrateIfNeeded() {
        let columnsToAdd = [
            ("Profiles", "nickName", "TEXT"),
            ("Families", "createdBy", "TEXT"),
            ("Challenges", "isSynced", "INTEGER DEFAULT 0"),
            ("ChallengeCompleted", "isSynced", "INTEGER DEFAULT 0"),
            ("UserRelationships", "isSynced", "INTEGER DEFAULT 0")
        ]
        
        for (table, column, type) in columnsToAdd {
            if !columnExists(column, in: table) {
                execute(sql: "ALTER TABLE \(table) ADD COLUMN \(column) \(type);")
                print("SQLiteHelper: Migrated \(table) table — added \(column) column.")
            }
        }

        execute(sql: "DROP INDEX IF EXISTS idx_challenge_identity;")
        execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS idx_challenge_identity ON ChallengeCompleted (familyId, challengeId, startDate);")

        // Cleanup redundant table
        execute(sql: "DROP TABLE IF EXISTS Health_ActivityCurrent;")
    }

    private func execute(sql: String) {
        queue.sync {
            if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("SQLiteHelper error executing SQL: \(errmsg)")
                print("SQL: \(sql)")
            }
        }
    }

    /// Saves Family + Profile together with FK constraints OFF to break the circular
    /// dependency: Profiles.familyId → Families AND Families.createdBy → Profiles.
    /// Both FKs are re-enabled immediately after the two INSERTs complete.
    func bootstrapSaveIdentity(family: Family, profile: Profile) {
        queue.sync {
            // Turn off FK enforcement for this connection temporarily
            sqlite3_exec(db, "PRAGMA foreign_keys = OFF;", nil, nil, nil)
            defer { sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil) }

            // --- Save Family ---
            let familySql = """
            INSERT OR REPLACE INTO Families (
                familyId, familyName, sharableCode, createdBy, createdAt, lastUpdatedAt, isSynced
            ) VALUES (?, ?, ?, ?, ?, ?, ?);
            """
            var famStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, familySql, -1, &famStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(famStmt, 1, (family.familyId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(famStmt, 2, (family.familyName as NSString).utf8String, -1, nil)
                sqlite3_bind_text(famStmt, 3, (family.sharableCode as NSString).utf8String, -1, nil)
                if let cb = family.createdBy {
                    sqlite3_bind_text(famStmt, 4, (cb.uuidString as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(famStmt, 4)
                }
                sqlite3_bind_text(famStmt, 5, (formatDate(family.createdAt) as NSString).utf8String, -1, nil)
                sqlite3_bind_text(famStmt, 6, (formatDate(family.lastUpdatedAt) as NSString).utf8String, -1, nil)
                sqlite3_bind_int(famStmt, 7, (family.isSynced ?? false) ? 1 : 0)
                if sqlite3_step(famStmt) != SQLITE_DONE {
                    print("SQLiteHelper [bootstrap]: ❌ Error saving family — \(String(cString: sqlite3_errmsg(db)!))")
                } else {
                    print("SQLiteHelper [bootstrap]: ✅ Family '\(family.familyName)' saved.")
                }
            }
            sqlite3_finalize(famStmt)

            // --- Save Profile ---
            let insertProfile = """
            INSERT OR REPLACE INTO Profiles (
                profileId, familyId, firstName, lastName, nickName, email, gender, dob, profilePic,
                heightCm, weightKg, timeZone, stepGoal, caloriesGoal, distanceGoal, sleepGoal,
                createdAt, lastUpdatedAt, visibleMetricIds, isSynced
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            var profStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, insertProfile, -1, &profStmt, nil) == SQLITE_OK {
                let nicknameToPersist = nonEmptyNickname(profile.nickName)
                    ?? existingNicknameForProfileLocked(profile.profileId)
                sqlite3_bind_text(profStmt, 1, (profile.profileId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(profStmt, 2, (profile.familyId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(profStmt, 3, (profile.firstName as NSString).utf8String, -1, nil)
                sqlite3_bind_text(profStmt, 4, (profile.lastName as NSString).utf8String, -1, nil)
                if let nickName = nicknameToPersist {
                    sqlite3_bind_text(profStmt, 5, (nickName as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(profStmt, 5)
                }
                sqlite3_bind_text(profStmt, 6, (profile.email as NSString).utf8String, -1, nil)
                sqlite3_bind_text(profStmt, 7, (profile.gender.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_text(profStmt, 8, (formatDate(profile.dob) as NSString).utf8String, -1, nil)
                sqlite3_bind_text(profStmt, 9, (profile.profilePic as NSString).utf8String, -1, nil)
                sqlite3_bind_double(profStmt, 10, profile.heightCm)
                sqlite3_bind_double(profStmt, 11, profile.weightKg)
                sqlite3_bind_text(profStmt, 12, (profile.timeZone as NSString).utf8String, -1, nil)
                sqlite3_bind_int(profStmt, 13, Int32(profile.stepGoal))
                sqlite3_bind_int(profStmt, 14, Int32(profile.caloriesGoal))
                sqlite3_bind_int(profStmt, 15, Int32(profile.distanceGoal))
                sqlite3_bind_double(profStmt, 16, profile.sleepGoal)
                sqlite3_bind_text(profStmt, 17, (formatDate(profile.createdAt) as NSString).utf8String, -1, nil)
                sqlite3_bind_text(profStmt, 18, (formatDate(profile.lastUpdatedAt) as NSString).utf8String, -1, nil)
                if let metricIds = profile.visibleMetricIds,
                   let data = try? JSONEncoder().encode(metricIds),
                   let json = String(data: data, encoding: .utf8) {
                    sqlite3_bind_text(profStmt, 19, (json as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(profStmt, 19)
                }
                sqlite3_bind_int(profStmt, 20, (profile.isSynced ?? false) ? 1 : 0)
                if sqlite3_step(profStmt) != SQLITE_DONE {
                    print("SQLiteHelper [bootstrap]: ❌ Error saving profile — \(String(cString: sqlite3_errmsg(db)!))")
                } else {
                    print("SQLiteHelper [bootstrap]: ✅ Profile '\(profile.firstName)' saved.")
                }
            }
            sqlite3_finalize(profStmt)
        }
    }
    
    private func columnExists(_ column: String, in table: String) -> Bool {
        var exists = false
        queue.sync {
            let sql = "PRAGMA table_info(\(table));"
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    if let colName = sqlite3_column_text(statement, 1) {
                        if String(cString: colName) == column {
                            exists = true
                            break
                        }
                    }
                }
            }
            sqlite3_finalize(statement)
        }
        return exists
    }
    
    /// Returns the latest timestamp found in a table's lastUpdatedAt column.
    /// Used for delta-syncing health records and messages.
    func fetchLatestUpdatedAt(for table: String, column: String = "lastUpdatedAt", profileId: UUID? = nil) -> Date? {
        var sql = "SELECT MAX(\(column)) FROM \(table)"
        if let pid = profileId {
            sql += " WHERE profileId = '\(pid.uuidString)'"
        }
        
        var latestDate: Date? = nil
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                if sqlite3_step(statement) == SQLITE_ROW {
                    if let dateStr = sqlite3_column_text(statement, 0) {
                        latestDate = parseDate(String(cString: dateStr))
                    }
                }
            }
            sqlite3_finalize(statement)
        }
        return latestDate
    }

    // MARK: - CRUD Operations for Profile

    private func nonEmptyNickname(_ nickname: String?) -> String? {
        guard let nickname else { return nil }
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func existingNicknameForProfileLocked(_ profileId: UUID) -> String? {
        let sql = "SELECT nickName FROM Profiles WHERE profileId = ? LIMIT 1;"
        var nickname: String?
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (profileId.uuidString as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                nickname = nonEmptyNickname(sqlite3_column_text(statement, 0).map { String(cString: $0) })
            }
        }

        sqlite3_finalize(statement)
        return nickname
    }

    func saveProfile(_ profile: Profile) {
        let sql = """
        INSERT OR REPLACE INTO Profiles (
            profileId, familyId, firstName, lastName, nickName, email, gender, dob, profilePic,
            heightCm, weightKg, timeZone, stepGoal, caloriesGoal, distanceGoal, sleepGoal, createdAt, lastUpdatedAt, 
            visibleMetricIds, isSynced
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        queue.sync {
            let nicknameToPersist = nonEmptyNickname(profile.nickName)
                ?? existingNicknameForProfileLocked(profile.profileId)
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (profile.profileId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (profile.familyId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (profile.firstName as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 4, (profile.lastName as NSString).utf8String, -1, nil)
                if let nickName = nicknameToPersist {
                    sqlite3_bind_text(statement, 5, (nickName as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(statement, 5)
                }
                sqlite3_bind_text(statement, 6, (profile.email as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 7, (profile.gender.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 8, (formatDate(profile.dob) as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 9, (profile.profilePic as NSString).utf8String, -1, nil)
                sqlite3_bind_double(statement, 10, profile.heightCm)
                sqlite3_bind_double(statement, 11, profile.weightKg)
                sqlite3_bind_text(statement, 12, (profile.timeZone as NSString).utf8String, -1, nil)
                sqlite3_bind_int(statement, 13, Int32(profile.stepGoal))
                sqlite3_bind_int(statement, 14, Int32(profile.caloriesGoal))
                sqlite3_bind_int(statement, 15, Int32(profile.distanceGoal))
                sqlite3_bind_double(statement, 16, profile.sleepGoal)
                sqlite3_bind_text(statement, 17, (formatDate(profile.createdAt) as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 18, (formatDate(profile.lastUpdatedAt) as NSString).utf8String, -1, nil)
                
                // Encode visibleMetricIds
                if let metricIds = profile.visibleMetricIds,
                   let data = try? JSONEncoder().encode(metricIds),
                   let json = String(data: data, encoding: .utf8) {
                    sqlite3_bind_text(statement, 19, (json as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(statement, 19)
                }
                
                sqlite3_bind_int(statement, 20, (profile.isSynced ?? false) ? 1 : 0)

                if sqlite3_step(statement) != SQLITE_DONE {
                    print("Error saving profile")
                }
            }
            sqlite3_finalize(statement)
        }
    }

    func fetchProfiles() -> [Profile] {
        let sql = "SELECT profileId, familyId, firstName, lastName, nickName, email, gender, dob, profilePic, heightCm, weightKg, timeZone, stepGoal, caloriesGoal, distanceGoal, sleepGoal, createdAt, lastUpdatedAt, visibleMetricIds, isSynced FROM Profiles;"
        var profiles: [Profile] = []
        
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    let profileIdStr = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? ""
                    let profileId = UUID(uuidString: profileIdStr) ?? UUID()
                    let familyIdStr = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
                    let familyId = UUID(uuidString: familyIdStr) ?? UUID()
                    let firstName = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? ""
                    let lastName = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? ""
                    let nickName = sqlite3_column_text(statement, 4).map { String(cString: $0) }
                    let email = sqlite3_column_text(statement, 5).map { String(cString: $0) } ?? ""
                    let genderStr = sqlite3_column_text(statement, 6).map { String(cString: $0) } ?? "others"
                    let gender = Gender(rawValue: genderStr) ?? .others
                    let dobStr = sqlite3_column_text(statement, 7).map { String(cString: $0) } ?? ""
                    let dob = parseDate(dobStr) ?? Date()
                    let profilePic = sqlite3_column_text(statement, 8).map { String(cString: $0) } ?? ""
                    let height = sqlite3_column_double(statement, 9)
                    let weight = sqlite3_column_double(statement, 10)
                    let timeZone = sqlite3_column_text(statement, 11).map { String(cString: $0) } ?? "UTC"
                    let stepGoal = Int(sqlite3_column_int(statement, 12))
                    let caloriesGoal = Int(sqlite3_column_int(statement, 13))
                    let distanceGoal = Int(sqlite3_column_int(statement, 14))
                    let sleepGoal = sqlite3_column_double(statement, 15)
                    let createdAtStr = sqlite3_column_text(statement, 16).map { String(cString: $0) } ?? ""
                    let createdAt = parseDate(createdAtStr) ?? Date()
                    let lastUpdStr = sqlite3_column_text(statement, 17).map { String(cString: $0) } ?? ""
                    let lastUpdatedAt = parseDate(lastUpdStr) ?? Date()
                    
                    var metricIds: [String]? = nil
                    if let jsonStr = sqlite3_column_text(statement, 18) {
                        let data = String(cString: jsonStr).data(using: .utf8)!
                        metricIds = try? JSONDecoder().decode([String].self, from: data)
                    }
                    
                    let isSynced = sqlite3_column_int(statement, 19) == 1

                    let profile = Profile(
                        profileId: profileId, familyId: familyId, firstName: firstName, lastName: lastName,
                        nickName: nickName,
                        email: email, gender: gender, dob: dob, profilePic: profilePic,
                        heightCm: height, weightKg: weight, timeZone: timeZone, stepGoal: stepGoal,
                        caloriesGoal: caloriesGoal, distanceGoal: distanceGoal, sleepGoal: sleepGoal, createdAt: createdAt,
                        lastUpdatedAt: lastUpdatedAt, visibleMetricIds: metricIds, isSynced: isSynced
                    )
                    profiles.append(profile)
                }
            }
            sqlite3_finalize(statement)
        }
        return profiles
    }

    // MARK: - CRUD for ActivityDaily

    func saveActivityDaily(_ activity: ActivityDaily) {
        let sql = """
        INSERT OR REPLACE INTO Health_ActivityDaily (
            id, profileId, type, value, date, createdAt, lastUpdatedAt, isSynced
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (activity.id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (activity.profileId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (activity.type.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_double(statement, 4, activity.value)
                sqlite3_bind_text(statement, 5, (formatDate(activity.date) as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 6, (formatDate(activity.createdAt) as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 7, (formatDate(activity.lastUpdatedAt) as NSString).utf8String, -1, nil)
                sqlite3_bind_int(statement, 8, (activity.isSynced ?? false) ? 1 : 0)

                if sqlite3_step(statement) != SQLITE_DONE {
                    print("Error saving activity")
                }
            }
            sqlite3_finalize(statement)
        }
    }

    // MARK: - CRUD for Family

    func saveFamily(_ family: Family) {
        let sql = """
        INSERT OR REPLACE INTO Families (
            familyId, familyName, sharableCode, createdBy, createdAt, lastUpdatedAt, isSynced
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (family.familyId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (family.familyName as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (family.sharableCode as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 4, family.createdBy?.uuidString != nil ? (family.createdBy!.uuidString as NSString).utf8String : nil, -1, nil)
                sqlite3_bind_text(statement, 5, (formatDate(family.createdAt) as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 6, (formatDate(family.lastUpdatedAt) as NSString).utf8String, -1, nil)
                sqlite3_bind_int(statement, 7, (family.isSynced ?? false) ? 1 : 0)

                if sqlite3_step(statement) != SQLITE_DONE {
                    print("Error saving family")
                }
            }
            sqlite3_finalize(statement)
        }
    }

    // MARK: - CRUD for Health Data (Vitals)

    func saveVitalsDaily(_ vital: VitalsDaily) {
        let sql = """
        INSERT OR REPLACE INTO Health_VitalsDaily (
            id, profileId, type, date, minValue, avgValue, maxValue, createdAt, lastUpdatedAt, isSynced
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (vital.id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (vital.profileId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (vital.type.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 4, (formatDate(vital.date) as NSString).utf8String, -1, nil)
                sqlite3_bind_double(statement, 5, vital.minValue ?? 0.0)
                sqlite3_bind_double(statement, 6, vital.avgValue ?? 0.0)
                sqlite3_bind_double(statement, 7, vital.maxValue ?? 0.0)
                sqlite3_bind_text(statement, 8, (formatDate(vital.createdAt) as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 9, (formatDate(vital.lastUpdatedAt) as NSString).utf8String, -1, nil)
                sqlite3_bind_int(statement, 10, (vital.isSynced ?? false) ? 1 : 0)

                if sqlite3_step(statement) != SQLITE_DONE {
                    print("Error saving vitals: \(String(cString: sqlite3_errmsg(db)!))")
                }
            }
            sqlite3_finalize(statement)
        }
    }

    // MARK: - CRUD for Sleep Data

    func saveSleepDaily(_ sleep: SleepDaily) {
        let sql = """
        INSERT OR REPLACE INTO Health_SleepDaily (
            id, profileId, date, totalSleep, deepSleep, remSleep, lightSleep, sleepStart, sleepEnd, createdAt, lastUpdatedAt, isSynced
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (sleep.id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (sleep.profileId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (formatDate(sleep.date) as NSString).utf8String, -1, nil)
                sqlite3_bind_double(statement, 4, sleep.totalSleep)
                sqlite3_bind_double(statement, 5, sleep.deepSleep)
                sqlite3_bind_double(statement, 6, sleep.remSleep)
                sqlite3_bind_double(statement, 7, sleep.lightSleep)
                sqlite3_bind_text(statement, 8, (formatDate(sleep.sleepStart) as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 9, (formatDate(sleep.sleepEnd) as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 10, (formatDate(sleep.createdAt) as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 11, (formatDate(sleep.lastUpdatedAt) as NSString).utf8String, -1, nil)
                sqlite3_bind_int(statement, 12, (sleep.isSynced ?? false) ? 1 : 0)

                if sqlite3_step(statement) != SQLITE_DONE {
                    print("Error saving sleep data")
                }
            }
            sqlite3_finalize(statement)
        }
    }

    // MARK: - CRUD for Messages

    func saveMessage(_ message: Message) {
        let sql = """
        INSERT OR REPLACE INTO Messages (
            messageId, senderId, receiverId, timestampUTC, message, deliveredAt, readAt, lastUpdatedAt, isSynced
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (message.messageId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (message.senderId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (message.receiverId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 4, (formatDate(message.timestampUTC) as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 5, (message.message as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 6, message.deliveredAt != nil ? (formatDate(message.deliveredAt!) as NSString).utf8String : nil, -1, nil)
                sqlite3_bind_text(statement, 7, message.readAt != nil ? (formatDate(message.readAt!) as NSString).utf8String : nil, -1, nil)
                sqlite3_bind_text(statement, 8, (formatDate(message.lastUpdatedAt) as NSString).utf8String, -1, nil)
                sqlite3_bind_int(statement, 9, (message.isSynced ?? false) ? 1 : 0)

                if sqlite3_step(statement) != SQLITE_DONE {
                    print("Error saving message")
                }
            }
            sqlite3_finalize(statement)
        }
    }

    // MARK: - CRUD for Challenges

    func saveChallengeDetails(_ details: ChallengeDetails) {
        let sql = """
        INSERT OR REPLACE INTO ChallengeDetails (
            challengeId, familyId, name, description, type, subType,
            status, bgImage, startDate, endDate, lastUpdatedAt, isSynced
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (details.challengeId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (details.familyId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (details.name as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 4, (details.description as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 5, (details.type as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 6, (details.subType as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 7, (details.status as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 8, (details.bgImage as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 9, (formatDate(details.startDate) as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 10, (formatDate(details.endDate) as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 11, (formatDate(details.lastUpdatedAt) as NSString).utf8String, -1, nil)
                sqlite3_bind_int(statement, 12, (details.isSynced ?? false) ? 1 : 0)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }

    func saveChallengeProgress(_ progress: ChallengeProgress) {
        let sql = """
        INSERT OR REPLACE INTO ChallengeProgress (
            challengeId, memberId, goalValue, currentValue, lastUpdatedAt, isSynced
        ) VALUES (?, ?, ?, ?, ?, ?);
        """
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (progress.challengeId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (progress.memberId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_double(statement, 3, progress.goalValue)
                sqlite3_bind_double(statement, 4, progress.currentValue)
                sqlite3_bind_text(statement, 5, (formatDate(progress.lastUpdatedAt) as NSString).utf8String, -1, nil)
                sqlite3_bind_int(statement, 6, (progress.isSynced ?? false) ? 1 : 0)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }

    func updateChallengeProgress(challengeId: UUID, memberId: UUID, currentValue: Double) {
        let sql = """
        UPDATE ChallengeProgress 
        SET currentValue = ?, isSynced = 0, lastUpdatedAt = CURRENT_TIMESTAMP 
        WHERE challengeId = ? AND memberId = ?;
        """
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_double(statement, 1, currentValue)
                sqlite3_bind_text(statement, 2, (challengeId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (memberId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }

    // MARK: - CRUD for Vitals Hourly

    func saveVitalsHourly(_ vital: VitalsHourly) {
        let sql = """
        INSERT OR REPLACE INTO Health_VitalsHourly (
            id, profileId, type, hourStart, minValue, avgValue, maxValue, sampleCount, createdAt, lastUpdatedAt, isSynced
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (vital.id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (vital.profileId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (vital.type.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 4, (formatDate(vital.hourStart) as NSString).utf8String, -1, nil)
                sqlite3_bind_double(statement, 5, vital.minValue ?? 0.0)
                sqlite3_bind_double(statement, 6, vital.avgValue ?? 0.0)
                sqlite3_bind_double(statement, 7, vital.maxValue ?? 0.0)
                sqlite3_bind_int(statement, 8, Int32(vital.sampleCount))
                sqlite3_bind_text(statement, 9, (formatDate(vital.createdAt) as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 10, (formatDate(vital.lastUpdatedAt) as NSString).utf8String, -1, nil)
                sqlite3_bind_int(statement, 11, (vital.isSynced ?? false) ? 1 : 0)

                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }

    // MARK: - CRUD for Activity Current & Hourly


    func saveActivityHourly(_ activity: ActivityHourly) {
        let sql = """
        INSERT OR REPLACE INTO Health_ActivityHourly (
            id, profileId, type, value, hourStart, sampleCount, createdAt, lastUpdatedAt, isSynced
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (activity.id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (activity.profileId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (activity.type.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_double(statement, 4, activity.value)
                sqlite3_bind_text(statement, 5, (formatDate(activity.hourStart) as NSString).utf8String, -1, nil)
                sqlite3_bind_int(statement, 6, Int32(activity.sampleCount))
                sqlite3_bind_text(statement, 7, (formatDate(activity.createdAt) as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 8, (formatDate(activity.lastUpdatedAt) as NSString).utf8String, -1, nil)
                sqlite3_bind_int(statement, 9, (activity.isSynced ?? false) ? 1 : 0)

                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }

    func fetchFamilies() -> [Family] {
        let sql = "SELECT familyId, familyName, sharableCode, createdBy, createdAt, lastUpdatedAt, isSynced FROM Families;"
        var families: [Family] = []
        
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    let familyIdString = String(cString: sqlite3_column_text(statement, 0))
                    let familyId = UUID(uuidString: familyIdString)!
                    let familyName = String(cString: sqlite3_column_text(statement, 1))
                    let sharableCode = String(cString: sqlite3_column_text(statement, 2))
                    
                    var createdBy: UUID? = nil
                    if let cbStr = sqlite3_column_text(statement, 3) {
                        createdBy = UUID(uuidString: String(cString: cbStr))
                    }
                    
                    let createdAt = parseDate(String(cString: sqlite3_column_text(statement, 4))) ?? Date()
                    let lastUpdatedAt = parseDate(String(cString: sqlite3_column_text(statement, 5))) ?? Date()
                    let isSynced = sqlite3_column_int(statement, 6) == 1

                    let family = Family(
                        familyId: familyId,
                        familyName: familyName,
                        sharableCode: sharableCode,
                        createdBy: createdBy,
                        createdAt: createdAt,
                        lastUpdatedAt: lastUpdatedAt,
                        isSynced: isSynced
                    )
                    families.append(family)
                }
            }
            sqlite3_finalize(statement)
        }
        return families
    }

    // MARK: - Fetch Health Data

    func fetchActivityDaily(for profileId: UUID) -> [ActivityDaily] {
        let sql = "SELECT * FROM Health_ActivityDaily WHERE profileId = ? ORDER BY date DESC;"
        var activities: [ActivityDaily] = []
        
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (profileId.uuidString as NSString).utf8String, -1, nil)
                while sqlite3_step(statement) == SQLITE_ROW {
                    let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
                    let type = ActivityType(rawValue: String(cString: sqlite3_column_text(statement, 2))) ?? .steps
                    let value = sqlite3_column_double(statement, 3)
                    let date = parseDate(String(cString: sqlite3_column_text(statement, 4))) ?? Date()
                    let createdAt = parseDate(String(cString: sqlite3_column_text(statement, 5))) ?? Date()
                    let lastUpdatedAt = parseDate(String(cString: sqlite3_column_text(statement, 6))) ?? Date()
                    let isSynced = sqlite3_column_int(statement, 7) == 1

                    let activity = ActivityDaily(
                        id: id, profileId: profileId, type: type, value: value,
                        date: date, createdAt: createdAt, lastUpdatedAt: lastUpdatedAt, isSynced: isSynced
                    )
                    activities.append(activity)
                }
            }
            sqlite3_finalize(statement)
        }
        return activities
    }

    func fetchActivityDaily(for profileId: UUID, on date: Date) -> [ActivityDaily] {
        let bounds = dayBounds(for: date)
        let sql = """
        SELECT * FROM Health_ActivityDaily
        WHERE profileId = ? AND date >= ? AND date < ?
        ORDER BY date DESC;
        """
        var activities: [ActivityDaily] = []

        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (profileId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (bounds.start as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (bounds.end as NSString).utf8String, -1, nil)
                while sqlite3_step(statement) == SQLITE_ROW {
                    let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
                    let type = ActivityType(rawValue: String(cString: sqlite3_column_text(statement, 2))) ?? .steps
                    let value = sqlite3_column_double(statement, 3)
                    let rowDate = parseDate(String(cString: sqlite3_column_text(statement, 4))) ?? Date()
                    let createdAt = parseDate(String(cString: sqlite3_column_text(statement, 5))) ?? Date()
                    let lastUpdatedAt = parseDate(String(cString: sqlite3_column_text(statement, 6))) ?? Date()
                    let isSynced = sqlite3_column_int(statement, 7) == 1

                    activities.append(
                        ActivityDaily(
                            id: id,
                            profileId: profileId,
                            type: type,
                            value: value,
                            date: rowDate,
                            createdAt: createdAt,
                            lastUpdatedAt: lastUpdatedAt,
                            isSynced: isSynced
                        )
                    )
                }
            }
            sqlite3_finalize(statement)
        }

        return activities
    }

    func fetchLatestActivityDaily(for profileId: UUID, type: ActivityType) -> ActivityDaily? {
        let sql = """
        SELECT * FROM Health_ActivityDaily
        WHERE profileId = ? AND type = ?
        ORDER BY date DESC
        LIMIT 1;
        """
        var activity: ActivityDaily?

        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (profileId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (type.rawValue as NSString).utf8String, -1, nil)
                if sqlite3_step(statement) == SQLITE_ROW {
                    let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
                    let value = sqlite3_column_double(statement, 3)
                    let rowDate = parseDate(String(cString: sqlite3_column_text(statement, 4))) ?? Date()
                    let createdAt = parseDate(String(cString: sqlite3_column_text(statement, 5))) ?? Date()
                    let lastUpdatedAt = parseDate(String(cString: sqlite3_column_text(statement, 6))) ?? Date()
                    let isSynced = sqlite3_column_int(statement, 7) == 1

                    activity = ActivityDaily(
                        id: id,
                        profileId: profileId,
                        type: type,
                        value: value,
                        date: rowDate,
                        createdAt: createdAt,
                        lastUpdatedAt: lastUpdatedAt,
                        isSynced: isSynced
                    )
                }
            }
            sqlite3_finalize(statement)
        }

        return activity
    }

    func fetchVitalsDaily(for profileId: UUID) -> [VitalsDaily] {
        let sql = "SELECT * FROM Health_VitalsDaily WHERE profileId = ? ORDER BY date DESC;"
        var vitals: [VitalsDaily] = []
        
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (profileId.uuidString as NSString).utf8String, -1, nil)
                while sqlite3_step(statement) == SQLITE_ROW {
                    let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
                    let type = VitalType(rawValue: String(cString: sqlite3_column_text(statement, 2))) ?? .heartRate
                    let date = parseDate(String(cString: sqlite3_column_text(statement, 3))) ?? Date()
                    let minValue = sqlite3_column_double(statement, 4)
                    let avgValue = sqlite3_column_double(statement, 5)
                    let maxValue = sqlite3_column_double(statement, 6)
                    let createdAt = parseDate(String(cString: sqlite3_column_text(statement, 7))) ?? Date()
                    let lastUpdatedAt = parseDate(String(cString: sqlite3_column_text(statement, 8))) ?? Date()
                    let isSynced = sqlite3_column_int(statement, 9) == 1

                    let vital = VitalsDaily(
                        id: id, profileId: profileId, type: type, date: date,
                        minValue: minValue, avgValue: avgValue, maxValue: maxValue,
                        createdAt: createdAt, lastUpdatedAt: lastUpdatedAt, isSynced: isSynced
                    )
                    vitals.append(vital)
                }
            }
            sqlite3_finalize(statement)
        }
        return vitals
    }

    func fetchVitalsDaily(for profileId: UUID, on date: Date) -> [VitalsDaily] {
        let bounds = dayBounds(for: date)
        let sql = """
        SELECT * FROM Health_VitalsDaily
        WHERE profileId = ? AND date >= ? AND date < ?
        ORDER BY date DESC;
        """
        var vitals: [VitalsDaily] = []

        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (profileId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (bounds.start as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (bounds.end as NSString).utf8String, -1, nil)
                while sqlite3_step(statement) == SQLITE_ROW {
                    let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
                    let type = VitalType(rawValue: String(cString: sqlite3_column_text(statement, 2))) ?? .heartRate
                    let rowDate = parseDate(String(cString: sqlite3_column_text(statement, 3))) ?? Date()
                    let minValue = sqlite3_column_double(statement, 4)
                    let avgValue = sqlite3_column_double(statement, 5)
                    let maxValue = sqlite3_column_double(statement, 6)
                    let createdAt = parseDate(String(cString: sqlite3_column_text(statement, 7))) ?? Date()
                    let lastUpdatedAt = parseDate(String(cString: sqlite3_column_text(statement, 8))) ?? Date()
                    let isSynced = sqlite3_column_int(statement, 9) == 1

                    vitals.append(
                        VitalsDaily(
                            id: id,
                            profileId: profileId,
                            type: type,
                            date: rowDate,
                            minValue: minValue,
                            avgValue: avgValue,
                            maxValue: maxValue,
                            createdAt: createdAt,
                            lastUpdatedAt: lastUpdatedAt,
                            isSynced: isSynced
                        )
                    )
                }
            }
            sqlite3_finalize(statement)
        }

        return vitals
    }

    func fetchLatestVitalsDaily(for profileId: UUID, type: VitalType) -> VitalsDaily? {
        let sql = """
        SELECT * FROM Health_VitalsDaily
        WHERE profileId = ? AND type = ?
        ORDER BY date DESC
        LIMIT 1;
        """
        var vital: VitalsDaily?

        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (profileId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (type.rawValue as NSString).utf8String, -1, nil)
                if sqlite3_step(statement) == SQLITE_ROW {
                    let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
                    let rowDate = parseDate(String(cString: sqlite3_column_text(statement, 3))) ?? Date()
                    let minValue = sqlite3_column_double(statement, 4)
                    let avgValue = sqlite3_column_double(statement, 5)
                    let maxValue = sqlite3_column_double(statement, 6)
                    let createdAt = parseDate(String(cString: sqlite3_column_text(statement, 7))) ?? Date()
                    let lastUpdatedAt = parseDate(String(cString: sqlite3_column_text(statement, 8))) ?? Date()
                    let isSynced = sqlite3_column_int(statement, 9) == 1

                    vital = VitalsDaily(
                        id: id,
                        profileId: profileId,
                        type: type,
                        date: rowDate,
                        minValue: minValue,
                        avgValue: avgValue,
                        maxValue: maxValue,
                        createdAt: createdAt,
                        lastUpdatedAt: lastUpdatedAt,
                        isSynced: isSynced
                    )
                }
            }
            sqlite3_finalize(statement)
        }

        return vital
    }

    func fetchSleepDaily(for profileId: UUID) -> [SleepDaily] {
        let sql = "SELECT * FROM Health_SleepDaily WHERE profileId = ? ORDER BY date DESC;"
        var sleepEntries: [SleepDaily] = []
        
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (profileId.uuidString as NSString).utf8String, -1, nil)
                while sqlite3_step(statement) == SQLITE_ROW {
                    let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
                    let date = parseDate(String(cString: sqlite3_column_text(statement, 2))) ?? Date()
                    let totalSleep = sqlite3_column_double(statement, 3)
                    let deepSleep = sqlite3_column_double(statement, 4)
                    let remSleep = sqlite3_column_double(statement, 5)
                    let lightSleep = sqlite3_column_double(statement, 6)
                    let sleepStart = parseDate(String(cString: sqlite3_column_text(statement, 7))) ?? Date()
                    let sleepEnd = parseDate(String(cString: sqlite3_column_text(statement, 8))) ?? Date()
                    let createdAt = parseDate(String(cString: sqlite3_column_text(statement, 9))) ?? Date()
                    let lastUpdatedAt = parseDate(String(cString: sqlite3_column_text(statement, 10))) ?? Date()
                    let isSynced = sqlite3_column_int(statement, 11) == 1

                    let sleep = SleepDaily(
                        id: id, profileId: profileId, date: date, totalSleep: totalSleep,
                        deepSleep: deepSleep, remSleep: remSleep, lightSleep: lightSleep,
                        sleepStart: sleepStart, sleepEnd: sleepEnd,
                        createdAt: createdAt, lastUpdatedAt: lastUpdatedAt, isSynced: isSynced
                    )
                    sleepEntries.append(sleep)
                }
            }
            sqlite3_finalize(statement)
        }
        return sleepEntries
    }

    func fetchSleepDaily(for profileId: UUID, on date: Date) -> SleepDaily? {
        let bounds = dayBounds(for: date)
        let sql = """
        SELECT * FROM Health_SleepDaily
        WHERE profileId = ? AND date >= ? AND date < ?
        ORDER BY date DESC
        LIMIT 1;
        """
        var sleepEntry: SleepDaily?

        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (profileId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (bounds.start as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (bounds.end as NSString).utf8String, -1, nil)
                if sqlite3_step(statement) == SQLITE_ROW {
                    let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
                    let rowDate = parseDate(String(cString: sqlite3_column_text(statement, 2))) ?? Date()
                    let totalSleep = sqlite3_column_double(statement, 3)
                    let deepSleep = sqlite3_column_double(statement, 4)
                    let remSleep = sqlite3_column_double(statement, 5)
                    let lightSleep = sqlite3_column_double(statement, 6)
                    let sleepStart = parseDate(String(cString: sqlite3_column_text(statement, 7))) ?? Date()
                    let sleepEnd = parseDate(String(cString: sqlite3_column_text(statement, 8))) ?? Date()
                    let createdAt = parseDate(String(cString: sqlite3_column_text(statement, 9))) ?? Date()
                    let lastUpdatedAt = parseDate(String(cString: sqlite3_column_text(statement, 10))) ?? Date()
                    let isSynced = sqlite3_column_int(statement, 11) == 1

                    sleepEntry = SleepDaily(
                        id: id,
                        profileId: profileId,
                        date: rowDate,
                        totalSleep: totalSleep,
                        deepSleep: deepSleep,
                        remSleep: remSleep,
                        lightSleep: lightSleep,
                        sleepStart: sleepStart,
                        sleepEnd: sleepEnd,
                        createdAt: createdAt,
                        lastUpdatedAt: lastUpdatedAt,
                        isSynced: isSynced
                    )
                }
            }
            sqlite3_finalize(statement)
        }

        return sleepEntry
    }

    func fetchLatestSleepDaily(for profileId: UUID) -> SleepDaily? {
        let sql = """
        SELECT * FROM Health_SleepDaily
        WHERE profileId = ?
        ORDER BY date DESC
        LIMIT 1;
        """
        var sleepEntry: SleepDaily?

        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (profileId.uuidString as NSString).utf8String, -1, nil)
                if sqlite3_step(statement) == SQLITE_ROW {
                    let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
                    let rowDate = parseDate(String(cString: sqlite3_column_text(statement, 2))) ?? Date()
                    let totalSleep = sqlite3_column_double(statement, 3)
                    let deepSleep = sqlite3_column_double(statement, 4)
                    let remSleep = sqlite3_column_double(statement, 5)
                    let lightSleep = sqlite3_column_double(statement, 6)
                    let sleepStart = parseDate(String(cString: sqlite3_column_text(statement, 7))) ?? Date()
                    let sleepEnd = parseDate(String(cString: sqlite3_column_text(statement, 8))) ?? Date()
                    let createdAt = parseDate(String(cString: sqlite3_column_text(statement, 9))) ?? Date()
                    let lastUpdatedAt = parseDate(String(cString: sqlite3_column_text(statement, 10))) ?? Date()
                    let isSynced = sqlite3_column_int(statement, 11) == 1

                    sleepEntry = SleepDaily(
                        id: id,
                        profileId: profileId,
                        date: rowDate,
                        totalSleep: totalSleep,
                        deepSleep: deepSleep,
                        remSleep: remSleep,
                        lightSleep: lightSleep,
                        sleepStart: sleepStart,
                        sleepEnd: sleepEnd,
                        createdAt: createdAt,
                        lastUpdatedAt: lastUpdatedAt,
                        isSynced: isSynced
                    )
                }
            }
            sqlite3_finalize(statement)
        }

        return sleepEntry
    }

    func fetchVitalsHourly(for profileId: UUID) -> [VitalsHourly] {
        let sql = "SELECT * FROM Health_VitalsHourly WHERE profileId = ? ORDER BY hourStart DESC;"
        var vitals: [VitalsHourly] = []
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (profileId.uuidString as NSString).utf8String, -1, nil)
                while sqlite3_step(statement) == SQLITE_ROW {
                    let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
                    let pId = UUID(uuidString: String(cString: sqlite3_column_text(statement, 1)))!
                    let type = VitalType(rawValue: String(cString: sqlite3_column_text(statement, 2))) ?? .heartRate
                    let hour = parseDate(String(cString: sqlite3_column_text(statement, 3))) ?? Date()
                    let min = sqlite3_column_double(statement, 4)
                    let avg = sqlite3_column_double(statement, 5)
                    let max = sqlite3_column_double(statement, 6)
                    let count = Int(sqlite3_column_int(statement, 7))
                    let created = parseDate(String(cString: sqlite3_column_text(statement, 8))) ?? Date()
                    let updated = parseDate(String(cString: sqlite3_column_text(statement, 9))) ?? Date()
                    let synced = sqlite3_column_int(statement, 10) == 1
                    
                    vitals.append(VitalsHourly(
                        id: id, profileId: pId, type: type, hourStart: hour,
                        minValue: min, avgValue: avg, maxValue: max, sampleCount: count,
                        createdAt: created, lastUpdatedAt: updated, isSynced: synced
                    ))
                }
            }
            sqlite3_finalize(statement)
        }
        return vitals
    }

    func fetchActivityHourly(for profileId: UUID) -> [ActivityHourly] {
        let sql = "SELECT * FROM Health_ActivityHourly WHERE profileId = ? ORDER BY hourStart DESC;"
        var activities: [ActivityHourly] = []
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (profileId.uuidString as NSString).utf8String, -1, nil)
                while sqlite3_step(statement) == SQLITE_ROW {
                    let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
                    let pId = UUID(uuidString: String(cString: sqlite3_column_text(statement, 1)))!
                    let type = ActivityType(rawValue: String(cString: sqlite3_column_text(statement, 2))) ?? .steps
                    let val = sqlite3_column_double(statement, 3)
                    let hour = parseDate(String(cString: sqlite3_column_text(statement, 4))) ?? Date()
                    let hCount = Int(sqlite3_column_int(statement, 5))
                    let created = parseDate(String(cString: sqlite3_column_text(statement, 6))) ?? Date()
                    let updated = parseDate(String(cString: sqlite3_column_text(statement, 7))) ?? Date()
                    let synced = sqlite3_column_int(statement, 8) == 1
                    
                    activities.append(ActivityHourly(
                        id: id, profileId: pId, type: type, value: val, hourStart: hour, sampleCount: hCount,
                        createdAt: created, lastUpdatedAt: updated, isSynced: synced
                    ))
                }
            }
            sqlite3_finalize(statement)
        }
        return activities
    }

    func fetchActivityHourly(for profileId: UUID, on date: Date, type: ActivityType) -> [ActivityHourly] {
        let bounds = dayBounds(for: date)
        let sql = """
        SELECT * FROM Health_ActivityHourly
        WHERE profileId = ? AND type = ? AND hourStart >= ? AND hourStart < ?
        ORDER BY hourStart ASC;
        """
        var activities: [ActivityHourly] = []

        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (profileId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (type.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (bounds.start as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 4, (bounds.end as NSString).utf8String, -1, nil)
                while sqlite3_step(statement) == SQLITE_ROW {
                    let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
                    let pId = UUID(uuidString: String(cString: sqlite3_column_text(statement, 1)))!
                    let hourStart = parseDate(String(cString: sqlite3_column_text(statement, 4))) ?? Date()
                    let value = sqlite3_column_double(statement, 3)
                    let sampleCount = Int(sqlite3_column_int(statement, 5))
                    let createdAt = parseDate(String(cString: sqlite3_column_text(statement, 6))) ?? Date()
                    let lastUpdatedAt = parseDate(String(cString: sqlite3_column_text(statement, 7))) ?? Date()
                    let isSynced = sqlite3_column_int(statement, 8) == 1

                    activities.append(
                        ActivityHourly(
                            id: id,
                            profileId: pId,
                            type: type,
                            value: value,
                            hourStart: hourStart,
                            sampleCount: sampleCount,
                            createdAt: createdAt,
                            lastUpdatedAt: lastUpdatedAt,
                            isSynced: isSynced
                        )
                    )
                }
            }
            sqlite3_finalize(statement)
        }

        return activities
    }

    // MARK: - Fetch Messages

    func fetchAllMessages() -> [Message] {
        let sql = "SELECT messageId, senderId, receiverId, timestampUTC, message, deliveredAt, readAt, lastUpdatedAt, isSynced FROM Messages ORDER BY timestampUTC ASC;"
        var messages: [Message] = []
        
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    let messageIdStr = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? ""
                    let messageId = UUID(uuidString: messageIdStr) ?? UUID()
                    let storedSenderIdStr = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
                    let storedSenderId = UUID(uuidString: storedSenderIdStr) ?? UUID()
                    let storedReceiverIdStr = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? ""
                    let storedReceiverId = UUID(uuidString: storedReceiverIdStr) ?? UUID()
                    let timestampUTCStr = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? ""
                    let timestampUTC = parseDate(timestampUTCStr) ?? Date()
                    let messageText = sqlite3_column_text(statement, 4).map { String(cString: $0) } ?? ""
                    let deliveredAtStr = sqlite3_column_text(statement, 5).map { String(cString: $0) }
                    let deliveredAt = deliveredAtStr != nil ? parseDate(deliveredAtStr!) : nil
                    let readAtStr = sqlite3_column_text(statement, 6).map { String(cString: $0) }
                    let readAt = readAtStr != nil ? parseDate(readAtStr!) : nil
                    let lastUpdatedAtStr = sqlite3_column_text(statement, 7).map { String(cString: $0) } ?? ""
                    let lastUpdatedAt = parseDate(lastUpdatedAtStr) ?? Date()
                    let isSynced = sqlite3_column_int(statement, 8) == 1

                    let message = Message(
                        messageId: messageId, senderId: storedSenderId, receiverId: storedReceiverId,
                        timestampUTC: timestampUTC, message: messageText,
                        deliveredAt: deliveredAt, readAt: readAt, lastUpdatedAt: lastUpdatedAt, isSynced: isSynced
                    )
                    messages.append(message)
                }
            }
            sqlite3_finalize(statement)
        }
        return messages
    }

    func fetchMessages(between senderId: UUID, and receiverId: UUID) -> [Message] {
        let sql = "SELECT messageId, senderId, receiverId, timestampUTC, message, deliveredAt, readAt, lastUpdatedAt, isSynced FROM Messages WHERE (senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?) ORDER BY timestampUTC ASC;"
        var messages: [Message] = []
        
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (senderId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (receiverId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (receiverId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 4, (senderId.uuidString as NSString).utf8String, -1, nil)
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let messageIdStr = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? ""
                    let messageId = UUID(uuidString: messageIdStr) ?? UUID()
                    let storedSenderIdStr = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
                    let storedSenderId = UUID(uuidString: storedSenderIdStr) ?? UUID()
                    let storedReceiverIdStr = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? ""
                    let storedReceiverId = UUID(uuidString: storedReceiverIdStr) ?? UUID()
                    let timestampUTCStr = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? ""
                    let timestampUTC = parseDate(timestampUTCStr) ?? Date()
                    let messageText = sqlite3_column_text(statement, 4).map { String(cString: $0) } ?? ""
                    let deliveredAtText = sqlite3_column_text(statement, 5).map { String(cString: $0) }
                    let deliveredAt = deliveredAtText != nil ? parseDate(deliveredAtText!) : nil
                    let readAtText = sqlite3_column_text(statement, 6).map { String(cString: $0) }
                    let readAt = readAtText != nil ? parseDate(readAtText!) : nil
                    let lastUpdStr = sqlite3_column_text(statement, 7).map { String(cString: $0) } ?? ""
                    let lastUpdatedAt = parseDate(lastUpdStr) ?? Date()
                    let isSynced = sqlite3_column_int(statement, 8) == 1

                    let message = Message(
                        messageId: messageId, senderId: storedSenderId, receiverId: storedReceiverId,
                        timestampUTC: timestampUTC, message: messageText,
                        deliveredAt: deliveredAt, readAt: readAt, lastUpdatedAt: lastUpdatedAt, isSynced: isSynced
                    )
                    messages.append(message)
                }
            }
            sqlite3_finalize(statement)
        }
        return messages
    }

    func fetchMessages(for userId: UUID) -> [Message] {
        let sql = """
        SELECT messageId, senderId, receiverId, timestampUTC, message, deliveredAt, readAt, lastUpdatedAt, isSynced
        FROM Messages
        WHERE senderId = ? OR receiverId = ?
        ORDER BY timestampUTC ASC;
        """
        var messages: [Message] = []

        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (userId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (userId.uuidString as NSString).utf8String, -1, nil)

                while sqlite3_step(statement) == SQLITE_ROW {
                    let messageIdStr = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? ""
                    let messageId = UUID(uuidString: messageIdStr) ?? UUID()
                    let senderIdStr = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
                    let senderId = UUID(uuidString: senderIdStr) ?? UUID()
                    let receiverIdStr = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? ""
                    let receiverId = UUID(uuidString: receiverIdStr) ?? UUID()
                    let timestampUTCStr = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? ""
                    let timestampUTC = parseDate(timestampUTCStr) ?? Date()
                    let messageText = sqlite3_column_text(statement, 4).map { String(cString: $0) } ?? ""
                    let deliveredAtStr = sqlite3_column_text(statement, 5).map { String(cString: $0) }
                    let deliveredAt = deliveredAtStr != nil ? parseDate(deliveredAtStr!) : nil
                    let readAtStr = sqlite3_column_text(statement, 6).map { String(cString: $0) }
                    let readAt = readAtStr != nil ? parseDate(readAtStr!) : nil
                    let lastUpdatedAtStr = sqlite3_column_text(statement, 7).map { String(cString: $0) } ?? ""
                    let lastUpdatedAt = parseDate(lastUpdatedAtStr) ?? Date()
                    let isSynced = sqlite3_column_int(statement, 8) == 1

                    messages.append(
                        Message(
                            messageId: messageId,
                            senderId: senderId,
                            receiverId: receiverId,
                            timestampUTC: timestampUTC,
                            message: messageText,
                            deliveredAt: deliveredAt,
                            readAt: readAt,
                            lastUpdatedAt: lastUpdatedAt,
                            isSynced: isSynced
                        )
                    )
                }
            }
            sqlite3_finalize(statement)
        }

        return messages
    }

    // MARK: - CRUD for Topics

    func saveTopic(_ topic: Topic) {
        let sql = "INSERT OR REPLACE INTO Topics (id, title, createdBy, createdAt, isSynced) VALUES (?, ?, ?, ?, ?);"
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (topic.id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (topic.title as NSString).utf8String, -1, nil)
                if let createdBy = topic.createdBy {
                    sqlite3_bind_text(statement, 3, (createdBy.uuidString as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(statement, 3)
                }
                if let createdAt = topic.createdAt {
                    sqlite3_bind_text(statement, 4, (formatDate(createdAt) as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(statement, 4)
                }
                sqlite3_bind_int(statement, 5, (topic.isSynced ?? false) ? 1 : 0)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }

    func fetchTopics() -> [Topic] {
        let sql = "SELECT id, title, createdBy, createdAt, isSynced FROM Topics ORDER BY createdAt DESC;"
        var topics: [Topic] = []
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
                    let title = String(cString: sqlite3_column_text(statement, 1))
                    let createdBy = sqlite3_column_text(statement, 2).map { UUID(uuidString: String(cString: $0)) } ?? nil
                    let createdAt = sqlite3_column_text(statement, 3).map { parseDate(String(cString: $0)) } ?? nil
                    let isSynced = sqlite3_column_int(statement, 4) == 1
                    topics.append(Topic(id: id, createdBy: createdBy, title: title, createdAt: createdAt, isSynced: isSynced))
                }
            }
            sqlite3_finalize(statement)
        }
        return topics
    }

    // MARK: - CRUD for Topic Members

    func saveTopicMember(_ member: TopicMember) {
        let sql = "INSERT OR REPLACE INTO TopicMembers (id, topicId, userId, isSynced) VALUES (?, ?, ?, ?);"
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (member.id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (member.topicId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (member.userId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_int(statement, 4, (member.isSynced ?? false) ? 1 : 0)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }

    func fetchTopicMembers(for topicId: UUID) -> [TopicMember] {
        let sql = "SELECT id, topicId, userId, isSynced FROM TopicMembers WHERE topicId = ?;"
        var members: [TopicMember] = []
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (topicId.uuidString as NSString).utf8String, -1, nil)
                while sqlite3_step(statement) == SQLITE_ROW {
                    let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
                    let userId = UUID(uuidString: String(cString: sqlite3_column_text(statement, 2)))!
                    let isSynced = sqlite3_column_int(statement, 3) == 1
                    var m = TopicMember(id: id, topicId: topicId, userId: userId)
                    m.isSynced = isSynced
                    members.append(m)
                }
            }
            sqlite3_finalize(statement)
        }
        return members
    }

    // MARK: - CRUD for Topic Messages

    func saveTopicMessage(_ msg: TopicMessage) {
        let sql = "INSERT OR REPLACE INTO TopicMessages (id, topicId, senderId, content, createdAt, isSynced) VALUES (?, ?, ?, ?, ?, ?);"
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (msg.id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (msg.topicId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (msg.senderId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 4, (msg.content as NSString).utf8String, -1, nil)
                if let createdAt = msg.createdAt {
                    sqlite3_bind_text(statement, 5, (formatDate(createdAt) as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(statement, 5)
                }
                sqlite3_bind_int(statement, 6, (msg.isSynced ?? false) ? 1 : 0)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }

    func fetchTopicMessages(for topicId: UUID) -> [TopicMessage] {
        let sql = "SELECT id, topicId, senderId, content, createdAt, isSynced FROM TopicMessages WHERE topicId = ? ORDER BY createdAt ASC;"
        var msgs: [TopicMessage] = []
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (topicId.uuidString as NSString).utf8String, -1, nil)
                while sqlite3_step(statement) == SQLITE_ROW {
                    let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
                    let senderId = UUID(uuidString: String(cString: sqlite3_column_text(statement, 2)))!
                    let content = String(cString: sqlite3_column_text(statement, 3))
                    let createdAt = sqlite3_column_text(statement, 4).map { parseDate(String(cString: $0)) } ?? nil
                    let isSynced = sqlite3_column_int(statement, 5) == 1
                    msgs.append(TopicMessage(id: id, topicId: topicId, senderId: senderId, content: content, createdAt: createdAt, isSynced: isSynced))
                }
            }
            sqlite3_finalize(statement)
        }
        return msgs
    }

    func fetchChallengeDetails() -> [ChallengeDetails] {
        let sql = "SELECT * FROM ChallengeDetails;"
        var detailsList: [ChallengeDetails] = []
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    let idStr = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? ""
                    let id = UUID(uuidString: idStr) ?? UUID()
                    let fIdStr = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
                    let fId = UUID(uuidString: fIdStr) ?? UUID()
                    let name = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? ""
                    let desc = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? ""
                    let type = sqlite3_column_text(statement, 4).map { String(cString: $0) } ?? "physical"
                    let subType = sqlite3_column_text(statement, 5).map { String(cString: $0) } ?? "steps"
                    let status = sqlite3_column_text(statement, 6).map { String(cString: $0) } ?? "ongoing"
                    let bg = sqlite3_column_text(statement, 7).map { String(cString: $0) } ?? ""
                    let startDate = sqlite3_column_text(statement, 8).flatMap { parseDate(String(cString: $0)) } ?? Date()
                    let endDate = sqlite3_column_text(statement, 9).flatMap { parseDate(String(cString: $0)) } ?? Date()
                    let lastUpdatedAt = sqlite3_column_text(statement, 10).flatMap { parseDate(String(cString: $0)) } ?? Date()
                    let isSynced = sqlite3_column_int(statement, 11) == 1

                    var details = ChallengeDetails(
                        challengeId: id, familyId: fId, name: name, description: desc,
                        type: type, subType: subType, status: status, bgImage: bg,
                        startDate: startDate, endDate: endDate, lastUpdatedAt: lastUpdatedAt
                    )
                    details.isSynced = isSynced
                    detailsList.append(details)
                }
            }
            sqlite3_finalize(statement)
        }
        return detailsList
    }

    func fetchChallengeProgress() -> [ChallengeProgress] {
        let sql = "SELECT * FROM ChallengeProgress;"
        var progressList: [ChallengeProgress] = []
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    let idStr = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? ""
                    let id = UUID(uuidString: idStr) ?? UUID()
                    let mIdStr = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
                    let mId = UUID(uuidString: mIdStr) ?? UUID()
                    let goalValue = sqlite3_column_double(statement, 2)
                    let currentValue = sqlite3_column_double(statement, 3)
                    let lastUpdatedAt = sqlite3_column_text(statement, 4).flatMap { parseDate(String(cString: $0)) } ?? Date()
                    let isSynced = sqlite3_column_int(statement, 5) == 1

                    var progress = ChallengeProgress(
                        challengeId: id, memberId: mId, goalValue: goalValue,
                        currentValue: currentValue, lastUpdatedAt: lastUpdatedAt
                    )
                    progress.isSynced = isSynced
                    progressList.append(progress)
                }
            }
            sqlite3_finalize(statement)
        }
        return progressList
    }

    // MARK: - Sync Helpers

    func fetchUnsyncedIds(tableName: String) -> [UUID] {
        let idColumn: String
        switch tableName {
        case "Profiles": idColumn = "profileId"
        case "Messages": idColumn = "messageId"
        case "Families": idColumn = "familyId"
        case "ChallengeDetails": idColumn = "challengeId"
        default: idColumn = "id"
        }
        
        let sql = "SELECT \(idColumn) FROM \(tableName) WHERE isSynced = 0;"
        var ids: [UUID] = []
        
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    if let cString = sqlite3_column_text(statement, 0) {
                        if let uuid = UUID(uuidString: String(cString: cString)) {
                            ids.append(uuid)
                        }
                    }
                }
            }
            sqlite3_finalize(statement)
        }
        return ids
    }

    func markAsSynced(id: UUID, tableName: String) {
        let idColumn: String
        switch tableName {
        case "Profiles": idColumn = "profileId"
        case "Messages": idColumn = "messageId"
        case "Families": idColumn = "familyId"
        case "ChallengeDetails": idColumn = "challengeId"
        default: idColumn = "id"
        }
        
        let sql = "UPDATE \(tableName) SET isSynced = 1 WHERE \(idColumn) = ?;"
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }

    func markAsSyncedBatch(table: String, idColumn: String, ids: [String]) {
        guard !ids.isEmpty else { return }
        let idsString = ids.map { "'\($0)'" }.joined(separator: ",")
        let sql = "UPDATE \(table) SET isSynced = 1 WHERE \(idColumn) IN (\(idsString));"
        execute(sql: sql)
    }

    func markChallengeProgressAsSynced(challengeId: UUID, memberId: UUID) {
        queue.sync {
            let sql = """
            UPDATE ChallengeProgress
            SET isSynced = 1
            WHERE challengeId = ? AND memberId = ?;
            """

            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (challengeId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (memberId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }

    func hasUnsyncedRows(table: String) -> Bool {
        let sql = "SELECT 1 FROM \(table) WHERE isSynced = 0 LIMIT 1;"
        var exists = false

        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                exists = sqlite3_step(statement) == SQLITE_ROW
            }
            sqlite3_finalize(statement)
        }

        return exists
    }

    // MARK: - Date Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }

    private func dayBounds(for date: Date) -> (start: String, end: String) {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        return (formatDate(startDate), formatDate(endDate))
    }

    // MARK: - Relative Nicknames
    
    func saveRelationshipNickname(viewerId: UUID, targetId: UUID, nickname: String) {
        let sql = "INSERT OR REPLACE INTO UserRelationships (viewerId, targetId, nickname, isSynced) VALUES (?, ?, ?, ?);"
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (viewerId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (targetId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (nickname as NSString).utf8String, -1, nil)
                sqlite3_bind_int(statement, 4, 0)
                let result = sqlite3_step(statement)
                if result == SQLITE_DONE {
                    print("SQLite: ✅ Saved nickname '\(nickname)' for targetId \(targetId)")
                } else {
                    print("SQLite: ❌ Failed to save nickname — error code \(result)")
                }
            } else {
                print("SQLite: ❌ Failed to prepare saveRelationshipNickname statement")
            }
            sqlite3_finalize(statement)
        }
    }
    
    func fetchRelationshipNicknames(for viewerId: UUID) -> [UUID: String] {
        let sql = "SELECT targetId, nickname FROM UserRelationships WHERE viewerId = ?;"
        var nicknames: [UUID: String] = [:]
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (viewerId.uuidString as NSString).utf8String, -1, nil)
                while sqlite3_step(statement) == SQLITE_ROW {
                    if let targetIdStr = sqlite3_column_text(statement, 0),
                       let targetId = UUID(uuidString: String(cString: targetIdStr)) {
                        let nick = String(cString: sqlite3_column_text(statement, 1))
                        nicknames[targetId] = nick
                    }
                }
            }
            sqlite3_finalize(statement)
        }
        print("SQLite: fetchRelationshipNicknames for \(viewerId) → found \(nicknames.count) nicknames: \(nicknames.values.joined(separator: ", "))")
        return nicknames
    }

    func fetchUnsyncedRelationshipNicknames() -> [UserRelationshipNickname] {
        let sql = "SELECT viewerId, targetId, nickname FROM UserRelationships WHERE isSynced = 0;"
        var rows: [UserRelationshipNickname] = []

        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    guard let viewerCString = sqlite3_column_text(statement, 0),
                          let targetCString = sqlite3_column_text(statement, 1),
                          let viewerId = UUID(uuidString: String(cString: viewerCString)),
                          let targetId = UUID(uuidString: String(cString: targetCString)) else {
                        continue
                    }

                    let nickname = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? ""
                    rows.append(UserRelationshipNickname(viewerId: viewerId, targetId: targetId, nickname: nickname))
                }
            }
            sqlite3_finalize(statement)
        }

        return rows
    }

    func markRelationshipNicknamesAsSynced(rows: [UserRelationshipNickname]) {
        guard !rows.isEmpty else { return }

        queue.sync {
            let sql = """
            UPDATE UserRelationships
            SET isSynced = 1
            WHERE viewerId = ? AND targetId = ?;
            """

            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                for row in rows {
                    sqlite3_reset(statement)
                    sqlite3_clear_bindings(statement)
                    sqlite3_bind_text(statement, 1, (row.viewerId.uuidString as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(statement, 2, (row.targetId.uuidString as NSString).utf8String, -1, nil)
                    sqlite3_step(statement)
                }
            }
            sqlite3_finalize(statement)
        }
    }

    func replaceRelationshipNicknames(for viewerId: UUID, rows: [UserRelationshipNickname]) {
        queue.sync {
            // Use INSERT OR REPLACE so Supabase data is always reflected locally.
            // The push path now always runs first in syncAll, so Supabase is the source of truth.
            let insertSQL = "INSERT OR REPLACE INTO UserRelationships (viewerId, targetId, nickname, isSynced) VALUES (?, ?, ?, 1);"
            var insertStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, insertSQL, -1, &insertStatement, nil) == SQLITE_OK {
                for row in rows {
                    sqlite3_reset(insertStatement)
                    sqlite3_clear_bindings(insertStatement)
                    sqlite3_bind_text(insertStatement, 1, (row.viewerId.uuidString as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(insertStatement, 2, (row.targetId.uuidString as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(insertStatement, 3, (row.nickname as NSString).utf8String, -1, nil)
                    sqlite3_step(insertStatement)
                }
            }
            sqlite3_finalize(insertStatement)
        }
    }

    // MARK: - Deletions

    func deleteMessage(id: UUID) {
        let sql = "DELETE FROM Messages WHERE messageId = ?;"
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }

    func deleteTopicMessage(id: UUID) {
        let sql = "DELETE FROM TopicMessages WHERE id = ?;"
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }

    func deleteTopic(id: UUID) {
        let sql = "DELETE FROM Topics WHERE id = ?;"
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }

    func deleteTopicMember(id: UUID) {
        let sql = "DELETE FROM TopicMembers WHERE id = ?;"
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }

    func deleteProfile(id: UUID) {
        let sql = "DELETE FROM Profiles WHERE profileId = ?;"
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }

    func deleteChallengeDetails(challengeId: UUID) {
        let sql = "DELETE FROM ChallengeDetails WHERE challengeId = ?;"
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (challengeId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }

    func deleteChallengeProgress(challengeId: UUID, memberId: UUID) {
        let sql = "DELETE FROM ChallengeProgress WHERE challengeId = ? AND memberId = ?;"
        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (challengeId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (memberId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }

    // MARK: - Clear All Data
    func clearAllData() {
        let tables = [
            "Profiles",
            "Families",
            "ChallengeDetails",
            "ChallengeProgress",
            "Messages",
            "Health_VitalsHourly",
            "Health_VitalsDaily",
            "Health_ActivityHourly",
            "Health_ActivityDaily",
            "Health_SleepDaily",
            "Topics",
            "TopicMembers",
            "TopicMessages",
            "UserRelationships"
        ]

        queue.sync {
            // Turn off FK enforcement temporarily to allow deleting everything without cascading issues
            sqlite3_exec(db, "PRAGMA foreign_keys = OFF;", nil, nil, nil)
            defer { sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil) }

            for table in tables {
                let sql = "DELETE FROM \(table);"
                if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
                    let errmsg = String(cString: sqlite3_errmsg(db))
                    print("SQLiteHelper: Error deleting data from \(table): \(errmsg)")
                } else {
                    print("SQLiteHelper: Cleared data from \(table)")
                }
            }
        }
    }

    func clearHealthTables() {
        let tables = [
            "Health_VitalsHourly",
            "Health_VitalsDaily",
            "Health_ActivityHourly",
            "Health_ActivityDaily",
            "Health_SleepDaily"
        ]

        queue.sync {
            sqlite3_exec(db, "PRAGMA foreign_keys = OFF;", nil, nil, nil)
            defer { sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil) }

            for table in tables {
                let sql = "DELETE FROM \(table);"
                if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
                    let errmsg = String(cString: sqlite3_errmsg(db))
                    print("SQLiteHelper: Error deleting health data from \(table): \(errmsg)")
                } else {
                    print("SQLiteHelper: Cleared health data from \(table)")
                }
            }
        }
    }
}
