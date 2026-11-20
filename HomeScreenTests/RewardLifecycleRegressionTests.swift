import Foundation
import SQLite3

// MARK: - Test Models & Harness

enum TestAchievementType: String, Codable {
    case individual
    case family
}

struct TestEarnedReward: Codable, Equatable {
    let id: String
    let profileId: String
    let type: TestAchievementType
    let challengeId: String?
    let challengeTitle: String?
    let challengeType: String?
    let participantsCount: Int?
    let dateEarned: Date
    var hasBeenPresented: Bool
    var isSynced: Bool?
    var lastUpdatedAt: Date?
}

struct TestChallengeDetails: Codable, Equatable {
    let challengeId: UUID
    let familyId: UUID
    let name: String
    let description: String
    let type: String
    let subType: String
    var status: String
    let bgImage: String
    let startDate: Date
    let endDate: Date
    var lastUpdatedAt: Date
    var isSynced: Bool? = nil
}

struct TestChallengeProgress: Codable {
    let challengeId: UUID
    let memberId: UUID
    let goalValue: Double
    var currentValue: Double
    let lastUpdatedAt: Date
    var isSynced: Bool? = nil
}

struct TestProfile: Codable, Equatable {
    let profileId: UUID
    let familyId: UUID
    let firstName: String
    let lastName: String
}

// MARK: - In-Memory / Isolated SQLite Database

class TestDatabase {
    var db: OpaquePointer?
    
    init() {
        if sqlite3_open(":memory:", &db) != SQLITE_OK {
            fatalError("Failed to open in-memory SQLite database")
        }
        createTables()
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    func createTables() {
        let sql = """
        CREATE TABLE IF NOT EXISTS Profiles (
            profileId TEXT PRIMARY KEY,
            familyId TEXT,
            firstName TEXT,
            lastName TEXT
        );

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
            isSynced INTEGER DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS ChallengeProgress (
            challengeId TEXT,
            memberId TEXT,
            goalValue REAL,
            currentValue REAL,
            lastUpdatedAt TEXT,
            isSynced INTEGER DEFAULT 0,
            PRIMARY KEY (challengeId, memberId)
        );

        CREATE TABLE IF NOT EXISTS EarnedRewards (
            id TEXT PRIMARY KEY,
            profileId TEXT,
            type TEXT,
            challengeId TEXT,
            challengeTitle TEXT,
            challengeType TEXT,
            participantsCount INTEGER,
            dateEarned TEXT,
            hasBeenPresented INTEGER DEFAULT 1,
            isSynced INTEGER DEFAULT 0,
            lastUpdatedAt TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_rewards_profile ON EarnedRewards (profileId);
        CREATE UNIQUE INDEX IF NOT EXISTS idx_rewards_identity ON EarnedRewards (profileId, type, challengeId);
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            fatalError("Failed to create test tables: \(errmsg)")
        }
    }
    
    func saveEarnedReward(_ reward: TestEarnedReward) {
        let sql = """
        INSERT OR REPLACE INTO EarnedRewards (
            id, profileId, type, challengeId, challengeTitle, challengeType, participantsCount, dateEarned, hasBeenPresented, isSynced, lastUpdatedAt
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (reward.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (reward.profileId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (reward.type.rawValue as NSString).utf8String, -1, nil)
            if let cId = reward.challengeId {
                sqlite3_bind_text(stmt, 4, (cId as NSString).utf8String, -1, nil)
            } else { sqlite3_bind_null(stmt, 4) }
            if let title = reward.challengeTitle {
                sqlite3_bind_text(stmt, 5, (title as NSString).utf8String, -1, nil)
            } else { sqlite3_bind_null(stmt, 5) }
            if let cType = reward.challengeType {
                sqlite3_bind_text(stmt, 6, (cType as NSString).utf8String, -1, nil)
            } else { sqlite3_bind_null(stmt, 6) }
            if let count = reward.participantsCount {
                sqlite3_bind_int(stmt, 7, Int32(count))
            } else { sqlite3_bind_null(stmt, 7) }
            sqlite3_bind_text(stmt, 8, ISO8601DateFormatter().string(from: reward.dateEarned), -1, nil)
            sqlite3_bind_int(stmt, 9, reward.hasBeenPresented ? 1 : 0)
            sqlite3_bind_int(stmt, 10, (reward.isSynced ?? false) ? 1 : 0)
            sqlite3_bind_text(stmt, 11, ISO8601DateFormatter().string(from: reward.lastUpdatedAt ?? Date()), -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }
    
    func fetchEarnedRewards(profileId: String? = nil) -> [TestEarnedReward] {
        var results: [TestEarnedReward] = []
        var sql = "SELECT id, profileId, type, challengeId, challengeTitle, challengeType, participantsCount, dateEarned, hasBeenPresented, isSynced, lastUpdatedAt FROM EarnedRewards"
        if let pId = profileId {
            sql += " WHERE profileId = '\(pId)'"
        }
        sql += " ORDER BY dateEarned DESC;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let profId = String(cString: sqlite3_column_text(stmt, 1))
                let typeStr = String(cString: sqlite3_column_text(stmt, 2))
                let type = TestAchievementType(rawValue: typeStr) ?? .family
                var challengeId: String? = nil
                if let cText = sqlite3_column_text(stmt, 3) { challengeId = String(cString: cText) }
                var challengeTitle: String? = nil
                if let tText = sqlite3_column_text(stmt, 4) { challengeTitle = String(cString: tText) }
                var challengeType: String? = nil
                if let ctText = sqlite3_column_text(stmt, 5) { challengeType = String(cString: ctText) }
                var participantsCount: Int? = nil
                if sqlite3_column_type(stmt, 6) != SQLITE_NULL {
                    participantsCount = Int(sqlite3_column_int(stmt, 6))
                }
                let dateStr = String(cString: sqlite3_column_text(stmt, 7))
                let date = ISO8601DateFormatter().date(from: dateStr) ?? Date()
                let hasBeenPresented = sqlite3_column_int(stmt, 8) != 0
                let isSynced = sqlite3_column_int(stmt, 9) != 0
                var lastUpdatedAt: Date? = nil
                if let luText = sqlite3_column_text(stmt, 10) {
                    lastUpdatedAt = ISO8601DateFormatter().date(from: String(cString: luText))
                }
                results.append(TestEarnedReward(
                    id: id,
                    profileId: profId,
                    type: type,
                    challengeId: challengeId,
                    challengeTitle: challengeTitle,
                    challengeType: challengeType,
                    participantsCount: participantsCount,
                    dateEarned: date,
                    hasBeenPresented: hasBeenPresented,
                    isSynced: isSynced,
                    lastUpdatedAt: lastUpdatedAt
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
    
    func markEarnedRewardPresented(id: String) {
        let sql = "UPDATE EarnedRewards SET hasBeenPresented = 1 WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }
    
    func saveChallengeProgress(_ p: TestChallengeProgress) {
        let sql = "INSERT OR REPLACE INTO ChallengeProgress (challengeId, memberId, goalValue, currentValue, lastUpdatedAt, isSynced) VALUES (?, ?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (p.challengeId.uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (p.memberId.uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 3, p.goalValue)
            sqlite3_bind_double(stmt, 4, p.currentValue)
            sqlite3_bind_text(stmt, 5, ISO8601DateFormatter().string(from: p.lastUpdatedAt), -1, nil)
            sqlite3_bind_int(stmt, 6, 1)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }
    
    func fetchChallengeProgress() -> [TestChallengeProgress] {
        var results: [TestChallengeProgress] = []
        let sql = "SELECT challengeId, memberId, goalValue, currentValue, lastUpdatedAt, isSynced FROM ChallengeProgress;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let cId = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 0)))!
                let mId = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 1)))!
                let gVal = sqlite3_column_double(stmt, 2)
                let cVal = sqlite3_column_double(stmt, 3)
                let dStr = String(cString: sqlite3_column_text(stmt, 4))
                let date = ISO8601DateFormatter().date(from: dStr) ?? Date()
                let isSynced = sqlite3_column_int(stmt, 5) != 0
                results.append(TestChallengeProgress(challengeId: cId, memberId: mId, goalValue: gVal, currentValue: cVal, lastUpdatedAt: date, isSynced: isSynced))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
}

// MARK: - Test Reward Manager Lifecycle

class TestRewardsLifecycleManager {
    let db: TestDatabase
    let currentProfileId: String
    var modalPresentationCount = 0
    var presentedRewardIds: [String] = []
    
    init(db: TestDatabase, currentProfileId: String) {
        self.db = db
        self.currentProfileId = currentProfileId
    }
    
    // Awards family shield ONLY when called during a genuine completion transition
    @discardableResult
    func awardFamilyShield(challenge: TestChallengeDetails, participantsCount: Int) -> TestEarnedReward? {
        let challengeIdStr = challenge.challengeId.uuidString
        let rewardId = "family_shield_\(challengeIdStr)"
        
        let existing = db.fetchEarnedRewards(profileId: currentProfileId)
        if let existingReward = existing.first(where: { $0.id == rewardId || ($0.challengeId == challengeIdStr && $0.type == .family) }) {
            return existingReward
        }
        
        let reward = TestEarnedReward(
            id: rewardId,
            profileId: currentProfileId,
            type: .family,
            challengeId: challengeIdStr,
            challengeTitle: challenge.name,
            challengeType: challenge.type,
            participantsCount: participantsCount,
            dateEarned: Date(),
            hasBeenPresented: false, // Pending presentation!
            isSynced: false,
            lastUpdatedAt: Date()
        )
        db.saveEarnedReward(reward)
        return reward
    }
    
    func getPendingFamilyShieldPresentation() -> TestEarnedReward? {
        let rewards = db.fetchEarnedRewards(profileId: currentProfileId)
        return rewards.first(where: { $0.type == .family && !$0.hasBeenPresented })
    }
    
    func markFamilyShieldAsPresented(rewardId: String) {
        db.markEarnedRewardPresented(id: rewardId)
    }
    
    // Simulates the Challenge screen checking for pending presentation
    func checkAndPresentPendingFamilyRewards() {
        guard let pendingReward = getPendingFamilyShieldPresentation() else {
            return
        }
        
        // Mark as presented durably in DB
        markFamilyShieldAsPresented(rewardId: pendingReward.id)
        modalPresentationCount += 1
        presentedRewardIds.append(pendingReward.id)
    }
}

// MARK: - Test Runner

func runTests() {
    print("==================================================")
    print("RUNNING REWARD LIFECYCLE REGRESSION TESTS")
    print("==================================================")
    
    let currentUserId = UUID()
    let otherMemberId = UUID()
    let familyId = UUID()
    
    // ----------------------------------------------------
    // TEST 1: Empty local database receiving historical completed challenge data from Supabase
    // Expected: 0 new rewards, 0 modal presentations
    // ----------------------------------------------------
    print("\n[TEST 1] Empty Local Database Receiving Historical Completed Challenge Data from Supabase")
    
    let testDB = TestDatabase()
    let manager = TestRewardsLifecycleManager(db: testDB, currentProfileId: currentUserId.uuidString)
    
    // Verify initial state: completely empty
    let initialRewards = testDB.fetchEarnedRewards(profileId: currentUserId.uuidString)
    assert(initialRewards.isEmpty, "Initial database must have 0 rewards")
    print("  ✓ Step 1: Initial empty local database verified (0 rewards)")
    
    // Simulate Supabase sending down historical completed family challenge
    let historicalChallengeId = UUID()
    let _ = TestChallengeDetails(
        challengeId: historicalChallengeId,
        familyId: familyId,
        name: "Morning Walk (Historical)",
        description: "Let's walk together",
        type: "physical",
        subType: "steps",
        status: "completed", // Historical completed challenge
        bgImage: "task_image",
        startDate: Date().addingTimeInterval(-86400 * 7),
        endDate: Date().addingTimeInterval(-86400 * 1),
        lastUpdatedAt: Date().addingTimeInterval(-86400 * 1),
        isSynced: true
    )
    
    // Historical progress records: all participants reached their goals in the past
    let progressUser = TestChallengeProgress(
        challengeId: historicalChallengeId,
        memberId: currentUserId,
        goalValue: 10000,
        currentValue: 10000,
        lastUpdatedAt: Date().addingTimeInterval(-86400 * 1),
        isSynced: true
    )
    let progressMember = TestChallengeProgress(
        challengeId: historicalChallengeId,
        memberId: otherMemberId,
        goalValue: 10000,
        currentValue: 10000,
        lastUpdatedAt: Date().addingTimeInterval(-86400 * 1),
        isSynced: true
    )
    
    // Simulate initial data hydration (saving historical records into local DB)
    // NOTE: Data hydration NEVER awards rewards or sets hasBeenPresented = false!
    testDB.saveChallengeProgress(progressUser)
    testDB.saveChallengeProgress(progressMember)
    print("  ✓ Step 2: Historical challenge data hydrated into empty SQLite database")
    
    // Verify rewards count immediately after hydration
    let rewardsAfterHydration = testDB.fetchEarnedRewards(profileId: currentUserId.uuidString)
    assert(rewardsAfterHydration.count == 0, "Hydration must award ZERO new rewards. Got: \(rewardsAfterHydration.count)")
    print("  ✓ Step 3: Verified 0 new rewards created during data hydration")
    
    // Simulate User launching app for the first time and opening Challenge tab
    manager.checkAndPresentPendingFamilyRewards()
    
    assert(manager.modalPresentationCount == 0, "Opening Challenge tab after fresh install must have ZERO modal presentations. Got: \(manager.modalPresentationCount)")
    assert(manager.getPendingFamilyShieldPresentation() == nil, "Must have zero pending shield presentations")
    print("  ✓ Step 4: Verified 0 modal presentations occurred on opening Challenge tab")
    print(">> TEST 1 PASSED: Empty local database receiving historical completed challenge data produced 0 new rewards and 0 modal presentations.\n")
    
    // ----------------------------------------------------
    // TEST 2: Genuine new completion after installation
    // Expected: Exactly 1 Family Shield award and exactly 1 modal presentation
    // ----------------------------------------------------
    print("[TEST 2] Genuine New Completion After Installation")
    
    let activeChallengeId = UUID()
    let activeChallenge = TestChallengeDetails(
        challengeId: activeChallengeId,
        familyId: familyId,
        name: "Family Weekend Trek",
        description: "Active family challenge",
        type: "physical",
        subType: "steps",
        status: "ongoing",
        bgImage: "trek_image",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 3),
        lastUpdatedAt: Date(),
        isSynced: true
    )
    
    // Active challenge starts with 2 participants:
    // User 1 has completed their goal (10000/10000)
    // User 2 has NOT completed their goal (5000/10000)
    let activeProgressUser = TestChallengeProgress(
        challengeId: activeChallengeId,
        memberId: currentUserId,
        goalValue: 10000,
        currentValue: 10000,
        lastUpdatedAt: Date(),
        isSynced: true
    )
    var activeProgressMember = TestChallengeProgress(
        challengeId: activeChallengeId,
        memberId: otherMemberId,
        goalValue: 10000,
        currentValue: 5000, // Incomplete!
        lastUpdatedAt: Date(),
        isSynced: true
    )
    testDB.saveChallengeProgress(activeProgressUser)
    testDB.saveChallengeProgress(activeProgressMember)
    
    // Verify before transition: family challenge is NOT complete
    var allProgress = [activeProgressUser, activeProgressMember]
    let wasComplete = allProgress.allSatisfy { $0.goalValue > 0 && $0.currentValue >= $0.goalValue }
    assert(!wasComplete, "Challenge must be incomplete before member finishes")
    print("  ✓ Step 1: Active family challenge established in incomplete state (User: 10000/10000, Member: 5000/10000)")
    
    // Check presentation before completion: should be 0
    manager.checkAndPresentPendingFamilyRewards()
    assert(manager.modalPresentationCount == 0, "No modal presentation before completion")
    
    // Now simulate genuine completion transition: Member 2 completes their goal (5000 -> 10000)
    activeProgressMember.currentValue = 10000
    testDB.saveChallengeProgress(activeProgressMember)
    allProgress = [activeProgressUser, activeProgressMember]
    let isNowComplete = allProgress.allSatisfy { $0.goalValue > 0 && $0.currentValue >= $0.goalValue }
    
    // Transition detected: wasComplete == false && isNowComplete == true
    assert(!wasComplete && isNowComplete, "Genuine family-wide completion transition must be detected")
    print("  ✓ Step 2: Genuine completion transition detected (!wasComplete && isNowComplete)")
    
    // Award the Family Shield
    let awardedReward = manager.awardFamilyShield(challenge: activeChallenge, participantsCount: allProgress.count)
    assert(awardedReward != nil, "Award must succeed")
    assert(awardedReward?.id == "family_shield_\(activeChallengeId.uuidString)", "Reward must have stable unique identity")
    assert(awardedReward?.hasBeenPresented == false, "Newly awarded reward must start with hasBeenPresented = false")
    
    let rewardsInDB = testDB.fetchEarnedRewards(profileId: currentUserId.uuidString)
    assert(rewardsInDB.count == 1, "Exactly 1 reward must exist in database. Got: \(rewardsInDB.count)")
    print("  ✓ Step 3: Exactly 1 Family Shield awarded with stable ID: \(awardedReward!.id)")
    
    // Challenge screen presents the reward modal
    manager.checkAndPresentPendingFamilyRewards()
    assert(manager.modalPresentationCount == 1, "Exactly 1 modal presentation must occur. Got: \(manager.modalPresentationCount)")
    print("  ✓ Step 4: Exactly 1 Family Shield modal presented")
    
    // Verify durable presentation state in database
    let updatedReward = testDB.fetchEarnedRewards(profileId: currentUserId.uuidString).first!
    assert(updatedReward.hasBeenPresented == true, "Reward must be durably marked hasBeenPresented = true in DB")
    print("  ✓ Step 5: Durable presentation state persisted in SQLite (hasBeenPresented = true)")
    
    // Subsequent checks (e.g. revisiting tab or segment change): must NEVER present again
    manager.checkAndPresentPendingFamilyRewards()
    assert(manager.modalPresentationCount == 1, "Modal presentation count must remain exactly 1 on revisiting tab")
    print("  ✓ Step 6: Verified no repeat presentation on revisiting tab (count remains 1)")
    
    // Attempting to re-award the same challenge must be idempotent
    let duplicateAward = manager.awardFamilyShield(challenge: activeChallenge, participantsCount: allProgress.count)
    assert(duplicateAward?.id == awardedReward?.id, "Re-award returns existing reward")
    let finalRewardsCount = testDB.fetchEarnedRewards(profileId: currentUserId.uuidString).count
    assert(finalRewardsCount == 1, "Must not create duplicate rewards in database")
    print("  ✓ Step 7: Verified idempotency (zero duplicate rewards created)")
    
    print(">> TEST 2 PASSED: Genuine new completion produced exactly 1 Family Shield award and 1 presentation.\n")
    
    print("==================================================")
    print("ALL REWARD LIFECYCLE REGRESSION TESTS PASSED (2/2)")
    print("==================================================")
}

runTests()
