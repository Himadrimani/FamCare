import Foundation
import Supabase

class SyncManager {
    static let shared = SyncManager()

    private let client = SupabaseManager.shared.client
    private let db = SQLiteHelper.shared
    private let daysBack = 30

    // Maintain a reference to keep websocket channels and listeners alive
    private var channels: [RealtimeChannelV2] = []
    private var observationTokens: [Any] = []

    // Periodic background sync timer
    private var periodicSyncTask: Task<Void, Never>?
    private var realtimeRefreshTask: Task<Void, Never>?
    private var lastSuccessfulSyncAt: Date?
    private var lastRealtimePullAt: Date?
    private var lastDeferredPullAt: Date?
    private var hasRealtimeSubscriptions = false
    private var isPullingRealtimeData = false
    private var realtimeRefreshNeeded = false
    private let realtimeSafetyPullInterval: TimeInterval = 2 * 60
    #if targetEnvironment(simulator)
    private let deferredPullInterval: TimeInterval = 15 // 15 seconds for faster testing
    #else
    private let deferredPullInterval: TimeInterval = 15 * 60 // 15 min for production
    #endif
    private let directMessageBroadcastEvent = "direct-message-changed"
    private let topicMessageBroadcastEvent = "topic-message-changed"
    private let topicCreatedBroadcastEvent = "topic-created"

    // Grace period: recently created topic IDs are protected from reconciliation pruning
    // for 60 seconds to give the Supabase push time to complete.
    private var recentlyCreatedTopicIds: [UUID: Date] = [:]
    private let topicGracePeriod: TimeInterval = 60

    private init() {}
    // MARK: - Core Two-Way Sync
    func syncAll(force: Bool = false) async {
        let hasRealtimeLocalChanges = hasPendingRealtimeLocalChanges()
        let hasDeferredLocalChanges = hasPendingDeferredLocalChanges()
        #if targetEnvironment(simulator)
        let shouldPullDeferred = true 
        #else
        let shouldPullDeferred = force || shouldRunDeferredPull()
        #endif

        DispatchQueue.main.async {
            DataManager.shared.refreshCurrentUserHealthDataFromHealthKit()
        }

        if !force && !hasRealtimeLocalChanges && !hasDeferredLocalChanges && hasRealtimeSubscriptions && !shouldPullDeferred {
            print("SyncManager: Skipping sync (no local changes and realtime is active).")
            return
        }

        print("SyncManager: Starting two-way sync...")
        if hasRealtimeLocalChanges || hasDeferredLocalChanges {
            await pushUnsyncedData(includeDeferred: true)
        } else {
            print("SyncManager: No local unsynced rows. Skipping push phase.")
        }
        await pullRealtimeData()
        if shouldPullDeferred {
            await pullDeferredData()
            lastDeferredPullAt = Date()
        }
        lastRealtimePullAt = Date()
        lastSuccessfulSyncAt = Date()
        print("SyncManager: Sync complete.")
    }


    // MARK: - Periodic Sync (every 10 minutes)

    func startPeriodicSync() {
        periodicSyncTask?.cancel()
        periodicSyncTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2 * 60 * 1_000_000_000)
                guard !Task.isCancelled else { break }
                await syncIfNeeded(reason: "periodic timer")
            }
        }
        print("SyncManager: Periodic sync started (every 2 minutes with deferred pulls every 15 minutes).")
    }

    func stopPeriodicSync() {
        periodicSyncTask?.cancel()
        periodicSyncTask = nil
    }

    private func syncIfNeeded(reason: String) async {
        let hasRealtimeLocalChanges = hasPendingRealtimeLocalChanges()
        let hasDeferredLocalChanges = hasPendingDeferredLocalChanges()
        let shouldRunRealtimePull = shouldRunRealtimeSafetyPull()
        let shouldRunDeferred = shouldRunDeferredPull()

        guard hasRealtimeLocalChanges || hasDeferredLocalChanges || !hasRealtimeSubscriptions || shouldRunRealtimePull || shouldRunDeferred else {
            print("SyncManager: Skipping \(reason) sync (nothing pending).")
            return
        }

        print("SyncManager: \(reason.capitalized) sync triggered.")
        await syncAll(force: true)
    }

    private func hasPendingRealtimeLocalChanges() -> Bool {
        let trackedTables = [
            "Profiles", "Families", "Messages",
            "Topics", "TopicMembers", "TopicMessages",
            "ChallengeCompleted", "UserRelationships"
        ]
        return trackedTables.contains(where: { db.hasUnsyncedRows(table: $0) })
    }

    private func hasPendingDeferredLocalChanges() -> Bool {
        let trackedTables = [
            "Health_ActivityDaily", "Health_ActivityHourly",
            "Health_VitalsDaily", "Health_VitalsHourly",
            "Health_SleepDaily", "ChallengeDetails", "ChallengeProgress"
        ]
        return trackedTables.contains(where: { db.hasUnsyncedRows(table: $0) })
    }

    private func shouldRunRealtimeSafetyPull() -> Bool {
        guard let last = lastRealtimePullAt ?? lastSuccessfulSyncAt else { return true }
        return Date().timeIntervalSince(last) >= realtimeSafetyPullInterval
    }

    private func shouldRunDeferredPull() -> Bool {
        guard let last = lastDeferredPullAt else { return true }
        return Date().timeIntervalSince(last) >= deferredPullInterval
    }

    // MARK: - Immediate Push Helpers (called after local mutations)

    func pushNewDirectMessage(_ message: Message) {
        Task {
            do {
                try await client.from("Messages").upsert(message).execute()
                db.markAsSyncedBatch(table: "Messages", idColumn: "messageId", ids: [message.messageId.uuidString])
                await broadcastDirectMessageChange(message)
                print("SyncManager: Pushed new DM \(message.messageId)")
            } catch { print("SyncManager Error pushing DM: \(error)") }
        }
    }

    func pushNewTopicMessage(_ message: TopicMessage) {
        Task {
            do {
                struct TopicMsgDTO: Encodable {
                    let id: UUID; let topicId: UUID; let senderId: UUID
                    let content: String; let createdAt: String?; let isSynced: Bool?
                }
                let dto = TopicMsgDTO(id: message.id, topicId: message.topicId, senderId: message.senderId,
                                     content: message.content, createdAt: message.createdAt.map { isoString($0) }, isSynced: true)
                try await client.from("TopicMessages").insert(dto).execute()
                db.markAsSyncedBatch(table: "TopicMessages", idColumn: "id", ids: [message.id.uuidString])
                await broadcastTopicMessageChange(message)
                print("SyncManager: Pushed new TopicMessage \(message.id)")
            } catch { print("SyncManager Error pushing TopicMessage: \(error)") }
        }
    }

    func pushNewTopic(_ topic: Topic, members: [TopicMember]) {
        // Track this topic for reconciliation grace period
        recentlyCreatedTopicIds[topic.id] = Date()

        Task {
            do {
                struct TopicDTO: Encodable {
                    let id: UUID; let title: String; let createdBy: UUID?; let createdAt: String?
                }
                // Use a dedicated DTO for members to avoid sending isSynced to Supabase
                struct TopicMemberDTO: Encodable {
                    let id: UUID; let topicId: UUID; let userId: UUID
                }
                let dto = TopicDTO(id: topic.id, title: topic.title, createdBy: topic.createdBy, createdAt: topic.createdAt.map { isoString($0) })
                try await client.from("Topics").insert(dto).execute()
                db.markAsSyncedBatch(table: "Topics", idColumn: "id", ids: [topic.id.uuidString])
                if !members.isEmpty {
                    let memberDTOs = members.map { TopicMemberDTO(id: $0.id, topicId: $0.topicId, userId: $0.userId) }
                    try await client.from("TopicMembers").insert(memberDTOs).execute()
                    db.markAsSyncedBatch(table: "TopicMembers", idColumn: "id", ids: members.map { $0.id.uuidString })
                }
                print("SyncManager: ✅ Pushed new Topic '\(topic.title)' with \(members.count) members.")
                // Broadcast topic creation to other family devices for immediate visibility
                await broadcastTopicCreated(topic)
            } catch { print("SyncManager Error pushing new Topic: \(error)") }
        }
    }

    func pushProfileUpdate(_ profile: Profile) {
        Task {
            do {
                struct ProfileDTO: Encodable {
                    let profileId: UUID; let familyId: UUID; let firstName: String; let lastName: String
                    let email: String; let gender: String; let dob: String; let profilePic: String
                    let heightCm: Double; let weightKg: Double; let timeZone: String
                    let stepGoal: Int; let caloriesGoal: Int; let distanceGoal: Int; let sleepGoal: Double
                    let createdAt: String; let lastUpdatedAt: String; let isSynced: Bool?
                }
                let profileDTO = ProfileDTO(
                    profileId: profile.profileId, familyId: profile.familyId,
                    firstName: profile.firstName, lastName: profile.lastName,
                    email: profile.email, gender: profile.gender.rawValue,
                    dob: ymdString(profile.dob), profilePic: profile.profilePic,
                    heightCm: profile.heightCm, weightKg: profile.weightKg,
                    timeZone: profile.timeZone, stepGoal: profile.stepGoal,
                    caloriesGoal: profile.caloriesGoal, distanceGoal: profile.distanceGoal, sleepGoal: profile.sleepGoal,
                    createdAt: isoString(profile.createdAt), lastUpdatedAt: isoString(profile.lastUpdatedAt), isSynced: true
                )
                try await client.from("Profiles").upsert(profileDTO).execute()
                db.markAsSyncedBatch(table: "Profiles", idColumn: "profileId", ids: [profile.profileId.uuidString])
                print("SyncManager: Pushed profile update for \(profile.firstName).")
            } catch { print("SyncManager Error pushing profile update: \(error)") }
        }
    }

    func pushRelationshipNickname(viewerId: UUID, targetId: UUID, nickname: String) {
        Task {
            struct NicknameDTO: Encodable {
                // Key names must match Supabase quoted column names exactly
                let viewerId: UUID
                let targetId: UUID
                let nickname: String
            }
            let dto = NicknameDTO(viewerId: viewerId, targetId: targetId, nickname: nickname)
            do {
                try await client.from("UserRelationships").upsert(dto).execute()
                let row = UserRelationshipNickname(viewerId: viewerId, targetId: targetId, nickname: nickname)
                db.markRelationshipNicknamesAsSynced(rows: [row])
                print("SyncManager: ✅ Pushed nickname '\(nickname)' for \(viewerId) -> \(targetId).")
            } catch {
                print("SyncManager: ❌ Error pushing relationship nickname: \(error)")
            }
        }
    }

    // MARK: - Push All Unsynced Data to Supabase

    func pushUnsyncedData(includeDeferred: Bool = true) async {
        // 1. Families (Insert without createdBy to avoid circular foreign key)
        struct SupabaseFamily: Encodable {
            let familyId: UUID; let familyName: String; let sharableCode: String
            let createdBy: UUID?; let createdAt: String; let lastUpdatedAt: String; let isSynced: Bool?
        }
        let unsyncedFamilies = db.fetchFamilies().filter { ($0.isSynced ?? false) == false }
        print("SyncManager: Attempting to push \(unsyncedFamilies.count) families")
        if !unsyncedFamilies.isEmpty {
            let dtos = unsyncedFamilies.map { SupabaseFamily(familyId: $0.familyId, familyName: $0.familyName, sharableCode: $0.sharableCode, createdBy: nil, createdAt: isoString($0.createdAt), lastUpdatedAt: isoString($0.lastUpdatedAt), isSynced: true) }
            do {
                try await client.from("Families").upsert(dtos).execute()
            } catch { print("SyncManager Error pushing Families: \(error)") }
        }

        // 2. Profiles
        let unsyncedProfiles = db.fetchProfiles().filter { ($0.isSynced ?? false) == false }
        print("SyncManager: Attempting to push \(unsyncedProfiles.count) profiles")
        if !unsyncedProfiles.isEmpty {
            struct ProfileDTO: Encodable {
                let profileId: UUID; let familyId: UUID; let firstName: String; let lastName: String
                let email: String; let gender: String; let dob: String; let profilePic: String
                let heightCm: Double; let weightKg: Double; let timeZone: String
                let stepGoal: Int; let caloriesGoal: Int; let distanceGoal: Int; let sleepGoal: Double
                let createdAt: String; let lastUpdatedAt: String; let isSynced: Bool?
            }
            let dtos = unsyncedProfiles.map { p in
                ProfileDTO(profileId: p.profileId, familyId: p.familyId, firstName: p.firstName,
                           lastName: p.lastName, email: p.email, gender: p.gender.rawValue,
                           dob: ymdString(p.dob), profilePic: p.profilePic, heightCm: p.heightCm,
                           weightKg: p.weightKg, timeZone: p.timeZone, stepGoal: p.stepGoal,
                           caloriesGoal: p.caloriesGoal, distanceGoal: p.distanceGoal, sleepGoal: p.sleepGoal,
                           createdAt: isoString(p.createdAt), lastUpdatedAt: isoString(p.lastUpdatedAt), isSynced: true)
            }
            do {
                try await client.from("Profiles").upsert(dtos).execute()
                db.markAsSyncedBatch(table: "Profiles", idColumn: "profileId", ids: unsyncedProfiles.map { $0.profileId.uuidString })
            } catch { print("SyncManager Error pushing Profiles: \(error)") }
        }

        // 3. Update Families with createdBy
        if !unsyncedFamilies.isEmpty {
            let dtos = unsyncedFamilies.map { SupabaseFamily(familyId: $0.familyId, familyName: $0.familyName, sharableCode: $0.sharableCode, createdBy: $0.createdBy, createdAt: isoString($0.createdAt), lastUpdatedAt: isoString($0.lastUpdatedAt), isSynced: true) }
            do {
                try await client.from("Families").upsert(dtos).execute()
                db.markAsSyncedBatch(table: "Families", idColumn: "familyId", ids: unsyncedFamilies.map { $0.familyId.uuidString })
            } catch { print("SyncManager Error updating Families: \(error)") }
        }

        // 3. Direct Messages
        let unsyncedMessages = db.fetchAllMessages().filter { ($0.isSynced ?? false) == false }
        print("SyncManager: Attempting to push \(unsyncedMessages.count) messages")
        if !unsyncedMessages.isEmpty {
            do {
                try await client.from("Messages").upsert(unsyncedMessages).execute()
                db.markAsSyncedBatch(table: "Messages", idColumn: "messageId", ids: unsyncedMessages.map { $0.messageId.uuidString })
            } catch { print("SyncManager Error pushing Messages: \(error)") }
        }

        // 4. Topics
        let allTopics = db.fetchTopics()
        let unsyncedTopics = allTopics.filter { ($0.isSynced ?? false) == false }
        if !unsyncedTopics.isEmpty {
            struct TopicDTO: Encodable { let id: UUID; let title: String; let createdBy: UUID?; let createdAt: String?; let isSynced: Bool? }
            let dtos = unsyncedTopics.map { TopicDTO(id: $0.id, title: $0.title, createdBy: $0.createdBy, createdAt: $0.createdAt.map { isoString($0) }, isSynced: true) }
            do {
                try await client.from("Topics").insert(dtos).execute()
                db.markAsSyncedBatch(table: "Topics", idColumn: "id", ids: unsyncedTopics.map { $0.id.uuidString })
                print("SyncManager: Pushed \(dtos.count) topics.")
            } catch { print("SyncManager Error pushing Topics: \(error)") }
        }

        // 5. Topic Members — use a dedicated DTO to avoid sending isSynced to Supabase
        let unsyncedMembers = db.fetchTopics()
            .flatMap { db.fetchTopicMembers(for: $0.id) }
            .filter { ($0.isSynced ?? false) == false }
        if !unsyncedMembers.isEmpty {
            struct TopicMemberDTO: Encodable {
                let id: UUID; let topicId: UUID; let userId: UUID
            }
            let memberDTOs = unsyncedMembers.map { TopicMemberDTO(id: $0.id, topicId: $0.topicId, userId: $0.userId) }
            do {
                try await client.from("TopicMembers").insert(memberDTOs).execute()
                db.markAsSyncedBatch(table: "TopicMembers", idColumn: "id", ids: unsyncedMembers.map { $0.id.uuidString })
                print("SyncManager: Pushed \(unsyncedMembers.count) topic members.")
            } catch { print("SyncManager Error pushing TopicMembers: \(error)") }
        }

        // 6. Topic Messages
        for topic in allTopics {
            let topicMsgs = db.fetchTopicMessages(for: topic.id).filter { ($0.isSynced ?? false) == false }
            if !topicMsgs.isEmpty {
                struct TopicMsgDTO: Encodable {
                    let id: UUID; let topicId: UUID; let senderId: UUID
                    let content: String; let createdAt: String?; let isSynced: Bool?
                }
                let dtos = topicMsgs.map { TopicMsgDTO(id: $0.id, topicId: $0.topicId, senderId: $0.senderId, content: $0.content, createdAt: $0.createdAt.map { isoString($0) }, isSynced: true) }
                do {
                    try await client.from("TopicMessages").insert(dtos).execute()
                    db.markAsSyncedBatch(table: "TopicMessages", idColumn: "id", ids: topicMsgs.map { $0.id.uuidString })
                } catch { print("SyncManager Error pushing TopicMessages: \(error)") }
            }
        }

        // 7. User Relationships — push ALL local nicknames to Supabase (idempotent upsert).
        // We push all (not just isSynced=0) to recover from any previously failed/wrong-column pushes.
        if let currentUserId = DataManager.shared.currentUser?.profileId {
            let allNicknames = db.fetchRelationshipNicknames(for: currentUserId)
            if !allNicknames.isEmpty {
                struct NicknameDTO: Encodable {
                    let viewerId: UUID
                    let targetId: UUID
                    let nickname: String
                }
                let dtos = allNicknames.map { NicknameDTO(viewerId: currentUserId, targetId: $0.key, nickname: $0.value) }
                do {
                    try await client.from("UserRelationships").upsert(dtos).execute()
                    // Mark all as synced now that we've successfully pushed
                    let rows = allNicknames.map { UserRelationshipNickname(viewerId: currentUserId, targetId: $0.key, nickname: $0.value) }
                    db.markRelationshipNicknamesAsSynced(rows: rows)
                    print("SyncManager: ✅ Pushed \(dtos.count) relationship nicknames to Supabase.")
                } catch { print("SyncManager: ❌ Error pushing UserRelationships: \(error)") }
            }
        }

        // 8. ChallengeDetails
        let unsyncedChallengeDetails = db.fetchChallengeDetails().filter { ($0.isSynced ?? false) == false }
        if !unsyncedChallengeDetails.isEmpty {
            struct ChallengeDetailsDTO: Encodable {
                let challengeId: UUID; let familyId: UUID; let name: String; let description: String
                let type: String; let subType: String; let status: String; let bgImage: String
                let startDate: String; let endDate: String; let lastUpdatedAt: String; let isSynced: Bool?
            }
            let dtos = unsyncedChallengeDetails.map { c in
                ChallengeDetailsDTO(challengeId: c.challengeId, familyId: c.familyId, name: c.name,
                                    description: c.description, type: c.type, subType: c.subType,
                                    status: c.status, bgImage: c.bgImage, startDate: isoString(c.startDate),
                                    endDate: isoString(c.endDate), lastUpdatedAt: isoString(c.lastUpdatedAt), isSynced: true)
            }
            do {
                try await client.from("ChallengeDetails").upsert(dtos).execute()
                db.markAsSyncedBatch(table: "ChallengeDetails", idColumn: "challengeId", ids: unsyncedChallengeDetails.map { $0.challengeId.uuidString })
                print("SyncManager: Pushed \(dtos.count) challenge details.")
            } catch { print("SyncManager Error pushing ChallengeDetails: \(error)") }
        }

        // 9. ChallengeProgress
        let unsyncedChallengeProgress = db.fetchChallengeProgress().filter { ($0.isSynced ?? false) == false }
        if !unsyncedChallengeProgress.isEmpty {
            struct ChallengeProgressDTO: Encodable {
                let challengeId: UUID; let memberId: UUID; let goalValue: Double; let currentValue: Double
                let lastUpdatedAt: String; let isSynced: Bool?
            }
            let dtos = unsyncedChallengeProgress.map { c in
                ChallengeProgressDTO(challengeId: c.challengeId, memberId: c.memberId, goalValue: c.goalValue,
                                     currentValue: c.currentValue, lastUpdatedAt: isoString(c.lastUpdatedAt), isSynced: true)
            }
            do {
                try await client.from("ChallengeProgress").upsert(dtos).execute()
                for progress in unsyncedChallengeProgress {
                    db.markChallengeProgressAsSynced(challengeId: progress.challengeId, memberId: progress.memberId)
                }
                print("SyncManager: Pushed \(dtos.count) challenge progress.")
            } catch { print("SyncManager Error pushing ChallengeProgress: \(error)") }
        }

        guard includeDeferred else { return }

        // Privacy gate: only upload health data when the user has explicitly consented
        // to sharing it with family members. Without consent, rows stay local-only.
        guard DataManager.shared.isFamilyHealthSharingConsented else {
            #if DEBUG
            print("SyncManager: Family health-sharing consent not granted. Skipping deferred health upload.")
            #endif
            return
        }

        // 9. Health Data (with explicit DTOs to handle Swift enums correctly)
        let allProfiles = db.fetchProfiles()
        for profile in allProfiles {
            let pid = profile.profileId

            let actDaily = db.fetchActivityDaily(for: pid).filter { ($0.isSynced ?? false) == false }
            if !actDaily.isEmpty {
                struct ActDailyDTO: Encodable {
                    let id: UUID; let profileId: UUID; let type: String; let value: Double
                    let date: String; let createdAt: String; let lastUpdatedAt: String; let isSynced: Bool?
                }
                let dtos = actDaily.map { ActDailyDTO(id: $0.id, profileId: $0.profileId, type: $0.type.rawValue, value: $0.value, date: ymdString($0.date), createdAt: isoString($0.createdAt), lastUpdatedAt: isoString($0.lastUpdatedAt), isSynced: true) }
                do { try await client.from("Health_ActivityDaily").upsert(dtos).execute()
                    db.markAsSyncedBatch(table: "Health_ActivityDaily", idColumn: "id", ids: actDaily.map { $0.id.uuidString })
                } catch { print("SyncManager Error pushing ActDaily: \(error)") }
            }

            let actHourly = db.fetchActivityHourly(for: pid).filter { ($0.isSynced ?? false) == false }
            if !actHourly.isEmpty {
                struct ActHourlyDTO: Encodable {
                    let id: UUID; let profileId: UUID; let type: String; let value: Double
                    let hourStart: String; let sampleCount: Int; let createdAt: String; let lastUpdatedAt: String; let isSynced: Bool?
                }
                let dtos = actHourly.map { ActHourlyDTO(id: $0.id, profileId: $0.profileId, type: $0.type.rawValue, value: $0.value, hourStart: isoString($0.hourStart), sampleCount: $0.sampleCount, createdAt: isoString($0.createdAt), lastUpdatedAt: isoString($0.lastUpdatedAt), isSynced: true) }
                do { try await client.from("Health_ActivityHourly").upsert(dtos).execute()
                    db.markAsSyncedBatch(table: "Health_ActivityHourly", idColumn: "id", ids: actHourly.map { $0.id.uuidString })
                } catch { print("SyncManager Error pushing ActHourly: \(error)") }
            }

            let vitDaily = db.fetchVitalsDaily(for: pid).filter { ($0.isSynced ?? false) == false }
            if !vitDaily.isEmpty {
                struct VitDailyDTO: Encodable {
                    let id: UUID; let profileId: UUID; let type: String; let date: String
                    let minValue: Double?; let avgValue: Double?; let maxValue: Double?
                    let createdAt: String; let lastUpdatedAt: String; let isSynced: Bool?
                }
                let dtos = vitDaily.map { VitDailyDTO(id: $0.id, profileId: $0.profileId, type: $0.type.rawValue, date: ymdString($0.date), minValue: $0.minValue, avgValue: $0.avgValue, maxValue: $0.maxValue, createdAt: isoString($0.createdAt), lastUpdatedAt: isoString($0.lastUpdatedAt), isSynced: true) }
                do { try await client.from("Health_VitalsDaily").upsert(dtos).execute()
                    db.markAsSyncedBatch(table: "Health_VitalsDaily", idColumn: "id", ids: vitDaily.map { $0.id.uuidString })
                } catch { print("SyncManager Error pushing VitDaily: \(error)") }
            }

            let vitHourly = db.fetchVitalsHourly(for: pid).filter { ($0.isSynced ?? false) == false }
            if !vitHourly.isEmpty {
                struct VitHourlyDTO: Encodable {
                    let id: UUID; let profileId: UUID; let type: String; let hourStart: String
                    let minValue: Double?; let avgValue: Double?; let maxValue: Double?; let sampleCount: Int
                    let createdAt: String; let lastUpdatedAt: String; let isSynced: Bool?
                }
                let dtos = vitHourly.map { VitHourlyDTO(id: $0.id, profileId: $0.profileId, type: $0.type.rawValue, hourStart: isoString($0.hourStart), minValue: $0.minValue, avgValue: $0.avgValue, maxValue: $0.maxValue, sampleCount: $0.sampleCount, createdAt: isoString($0.createdAt), lastUpdatedAt: isoString($0.lastUpdatedAt), isSynced: true) }
                do { try await client.from("Health_VitalsHourly").upsert(dtos).execute()
                    db.markAsSyncedBatch(table: "Health_VitalsHourly", idColumn: "id", ids: vitHourly.map { $0.id.uuidString })
                } catch { print("SyncManager Error pushing VitHourly: \(error)") }
            }

            let sleepDaily = db.fetchSleepDaily(for: pid).filter { ($0.isSynced ?? false) == false }
            if !sleepDaily.isEmpty {
                struct SleepDailyDTO: Encodable {
                    let id: UUID; let profileId: UUID; let date: String
                    var totalSleep: Double; var deepSleep: Double; var remSleep: Double; var lightSleep: Double
                    var sleepStart: String; var sleepEnd: String; var createdAt: String; var lastUpdatedAt: String; let isSynced: Bool?
                }
                let dtos = sleepDaily.map { s in
                    SleepDailyDTO(id: s.id, profileId: s.profileId, date: ymdString(s.date),
                                  totalSleep: s.totalSleep, deepSleep: s.deepSleep, remSleep: s.remSleep, lightSleep: s.lightSleep,
                                  sleepStart: isoString(s.sleepStart), sleepEnd: isoString(s.sleepEnd), createdAt: isoString(s.createdAt), lastUpdatedAt: isoString(s.lastUpdatedAt), isSynced: true)
                }
                do { try await client.from("Health_SleepDaily").upsert(dtos).execute()
                    db.markAsSyncedBatch(table: "Health_SleepDaily", idColumn: "id", ids: sleepDaily.map { $0.id.uuidString })
                } catch { print("SyncManager Error pushing SleepDaily: \(error)") }
            }
        }


    }
    
    /// Force-pushes the logged-in user's full health dataset to Supabase.
    /// This is used right after a successful HealthKit fetch so family members
    /// can immediately see real data (not stale/mock rows) on their devices.
    func pushCurrentUserHealthDataNow() async {
        guard let currentProfileId = DataManager.shared.currentUser?.profileId else {
            print("SyncManager: No current user. Skipping immediate health push.")
            return
        }

        // Privacy gate: never upload health data to Supabase (where family members can
        // read it) unless the user has explicitly consented to family health sharing.
        guard DataManager.shared.isFamilyHealthSharingConsented else {
            #if DEBUG
            print("SyncManager: Family health-sharing consent not granted. Skipping health upload.")
            #endif
            return
        }
        
        // Only push rows that haven't been synced yet. Deterministic stable IDs keep the
        // upsert idempotent, and syncing just the changed rows avoids re-uploading the
        // entire dataset (and hitting Supabase) on every fetch/foreground/background pass.
        let actDaily = db.fetchActivityDaily(for: currentProfileId).filter { ($0.isSynced ?? false) == false }
        let actHourly = db.fetchActivityHourly(for: currentProfileId).filter { ($0.isSynced ?? false) == false }
        let vitDaily = db.fetchVitalsDaily(for: currentProfileId).filter { ($0.isSynced ?? false) == false }
        let vitHourly = db.fetchVitalsHourly(for: currentProfileId).filter { ($0.isSynced ?? false) == false }
        let sleepDaily = db.fetchSleepDaily(for: currentProfileId).filter { ($0.isSynced ?? false) == false }

        guard !actDaily.isEmpty || !actHourly.isEmpty || !vitDaily.isEmpty || !vitHourly.isEmpty || !sleepDaily.isEmpty else {
            #if DEBUG
            print("SyncManager: No unsynced health rows for \(currentProfileId). Nothing to push.")
            #endif
            return
        }
        #if DEBUG
        print("SyncManager: Immediate health push for \(currentProfileId) -> AD:\(actDaily.count), AH:\(actHourly.count), VD:\(vitDaily.count), VH:\(vitHourly.count), SD:\(sleepDaily.count)")
        #endif
        
        do {
            if !actDaily.isEmpty {
                struct ActDailyDTO: Encodable {
                    let id: UUID; let profileId: UUID; let type: String; let value: Double
                    let date: String; let createdAt: String; let lastUpdatedAt: String; let isSynced: Bool?
                }
                let dtos = actDaily.map { ActDailyDTO(id: $0.id, profileId: $0.profileId, type: $0.type.rawValue, value: $0.value, date: ymdString($0.date), createdAt: isoString($0.createdAt), lastUpdatedAt: isoString($0.lastUpdatedAt), isSynced: true) }
                try await client.from("Health_ActivityDaily").upsert(dtos).execute()
                db.markAsSyncedBatch(table: "Health_ActivityDaily", idColumn: "id", ids: actDaily.map { $0.id.uuidString })
            }
            
            if !actHourly.isEmpty {
                struct ActHourlyDTO: Encodable {
                    let id: UUID; let profileId: UUID; let type: String; let value: Double
                    let hourStart: String; let sampleCount: Int; let createdAt: String; let lastUpdatedAt: String; let isSynced: Bool?
                }
                let dtos = actHourly.map { ActHourlyDTO(id: $0.id, profileId: $0.profileId, type: $0.type.rawValue, value: $0.value, hourStart: isoString($0.hourStart), sampleCount: $0.sampleCount, createdAt: isoString($0.createdAt), lastUpdatedAt: isoString($0.lastUpdatedAt), isSynced: true) }
                try await client.from("Health_ActivityHourly").upsert(dtos).execute()
                db.markAsSyncedBatch(table: "Health_ActivityHourly", idColumn: "id", ids: actHourly.map { $0.id.uuidString })
            }
            
            if !vitDaily.isEmpty {
                struct VitDailyDTO: Encodable {
                    let id: UUID; let profileId: UUID; let type: String; let date: String
                    let minValue: Double?; let avgValue: Double?; let maxValue: Double?
                    let createdAt: String; let lastUpdatedAt: String; let isSynced: Bool?
                }
                let dtos = vitDaily.map { VitDailyDTO(id: $0.id, profileId: $0.profileId, type: $0.type.rawValue, date: ymdString($0.date), minValue: $0.minValue, avgValue: $0.avgValue, maxValue: $0.maxValue, createdAt: isoString($0.createdAt), lastUpdatedAt: isoString($0.lastUpdatedAt), isSynced: true) }
                try await client.from("Health_VitalsDaily").upsert(dtos).execute()
                db.markAsSyncedBatch(table: "Health_VitalsDaily", idColumn: "id", ids: vitDaily.map { $0.id.uuidString })
            }
            
            if !vitHourly.isEmpty {
                struct VitHourlyDTO: Encodable {
                    let id: UUID; let profileId: UUID; let type: String; let hourStart: String
                    let minValue: Double?; let avgValue: Double?; let maxValue: Double?; let sampleCount: Int
                    let createdAt: String; let lastUpdatedAt: String; let isSynced: Bool?
                }
                let dtos = vitHourly.map { VitHourlyDTO(id: $0.id, profileId: $0.profileId, type: $0.type.rawValue, hourStart: isoString($0.hourStart), minValue: $0.minValue, avgValue: $0.avgValue, maxValue: $0.maxValue, sampleCount: $0.sampleCount, createdAt: isoString($0.createdAt), lastUpdatedAt: isoString($0.lastUpdatedAt), isSynced: true) }
                try await client.from("Health_VitalsHourly").upsert(dtos).execute()
                db.markAsSyncedBatch(table: "Health_VitalsHourly", idColumn: "id", ids: vitHourly.map { $0.id.uuidString })
            }
            
            if !sleepDaily.isEmpty {
                struct SleepDailyDTO: Encodable {
                    let id: UUID; let profileId: UUID; let date: String
                    var totalSleep: Double; var deepSleep: Double; var remSleep: Double; var lightSleep: Double
                    var sleepStart: String; var sleepEnd: String; var createdAt: String; var lastUpdatedAt: String; let isSynced: Bool?
                }
                let dtos = sleepDaily.map { s in
                    SleepDailyDTO(id: s.id, profileId: s.profileId, date: ymdString(s.date),
                                  totalSleep: s.totalSleep, deepSleep: s.deepSleep, remSleep: s.remSleep, lightSleep: s.lightSleep,
                                  sleepStart: isoString(s.sleepStart), sleepEnd: isoString(s.sleepEnd), createdAt: isoString(s.createdAt), lastUpdatedAt: isoString(s.lastUpdatedAt), isSynced: true)
                }
                try await client.from("Health_SleepDaily").upsert(dtos).execute()
                db.markAsSyncedBatch(table: "Health_SleepDaily", idColumn: "id", ids: sleepDaily.map { $0.id.uuidString })
            }
            
            #if DEBUG
            print("SyncManager: Immediate health push complete for \(currentProfileId).")
            #endif
        } catch {
            #if DEBUG
            print("SyncManager Error immediate health push: \(error)")
            #endif
        }
    }

    /// Best-effort deletion of the current user's health data from Supabase.
    /// Invoked when the user revokes family health-sharing consent, so their data
    /// stops being visible to family members. RLS (`*_write_self`) already restricts
    /// deletes to the caller's own rows. Local data is preserved for on-device display.
    func deleteCurrentUserRemoteHealthData() async {
        guard let pid = DataManager.shared.currentUser?.profileId else { return }
        let tables = [
            "Health_ActivityDaily",
            "Health_ActivityHourly",
            "Health_VitalsDaily",
            "Health_VitalsHourly",
            "Health_SleepDaily"
        ]
        for table in tables {
            do {
                try await client.from(table).delete().eq("profileId", value: pid.uuidString).execute()
            } catch {
                #if DEBUG
                print("SyncManager: Failed to delete remote \(table) on consent revoke: \(error)")
                #endif
            }
        }
        // Mark local rows unsynced so they can be re-uploaded if the user re-consents.
        SQLiteHelper.shared.markCurrentUserHealthDataUnsynced(for: pid)
        #if DEBUG
        print("SyncManager: Removed remote health data for \(pid) after consent revoke.")
        #endif
    }

    // MARK: - Pull Remote Data from Supabase

    private func pullRealtimeData(targetTable: String? = nil) async {
        // --- Step 1: Resolve identity (Bootstrap if new device) ---
        var currentUserId = DataManager.shared.currentUser?.profileId
        var familyId = DataManager.shared.family?.familyId

        if familyId == nil || currentUserId == nil {
            print("SyncManager: Identity resolution needed...")

            #if DEBUG
            // Tier 1: bootstrapUserId anchor (explicit UUID for fresh installs / testing).
            // DEBUG-only: compiled out of release (App Store) builds so it can never be used
            // to adopt an arbitrary identity in production.
            if (currentUserId == nil || familyId == nil),
               let anchorIdStr = DataManager.shared.bootstrapUserId,
               !anchorIdStr.isEmpty,
               let anchorId = UUID(uuidString: anchorIdStr) {
                print("SyncManager: Attempting bootstrap using hardcoded userId \(anchorIdStr)...")
                do {
                    // 1. Fetch the anchor profile
                    let profResp = try await client.from("Profiles").select()
                        .eq("profileId", value: anchorId.uuidString).execute()

                    // ── Diagnostic: print raw Supabase response ──
                    let rawJSON = String(data: profResp.data, encoding: .utf8) ?? "<non-UTF8>"
                    print("SyncManager [Bootstrap] Raw response (\(profResp.data.count) bytes): \(rawJSON)")

                    let profiles: [Profile]
                    do {
                        profiles = try supabaseDecoder().decode([Profile].self, from: profResp.data)
                    } catch let decodeErr {
                        print("SyncManager [Bootstrap] ❌ Decoding failed: \(decodeErr)")
                        // Print per-field context if available
                        if let ctx = (decodeErr as? DecodingError) {
                            switch ctx {
                            case .keyNotFound(let key, let context):
                                print("  → Missing key '\(key.stringValue)' at \(context.codingPath.map(\.stringValue).joined(separator: "."))")
                            case .typeMismatch(let type, let context):
                                print("  → Type mismatch: expected \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))")
                            case .valueNotFound(let type, let context):
                                print("  → Value not found: \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))")
                            case .dataCorrupted(let context):
                                print("  → Data corrupted at \(context.codingPath.map(\.stringValue).joined(separator: ".")): \(context.debugDescription)")
                            @unknown default:
                                print("  → Unknown decoding error")
                            }
                        }
                        return
                    }

                    if let profile = profiles.first {
                        var p = profile; p.isSynced = true

                        // Fetch family from Supabase so we have the full Family object
                        print("SyncManager [Bootstrap]: Fetching family \(p.familyId)...")
                        let famResp = try await client.from("Families")
                            .select()
                            .eq("familyId", value: p.familyId.uuidString)
                            .execute()
                        let rawFamJSON = String(data: famResp.data, encoding: .utf8) ?? "<non-UTF8>"
                        print("SyncManager [Bootstrap] Family raw: \(rawFamJSON)")

                        if var family = try? supabaseDecoder().decode([Family].self, from: famResp.data).first {
                            family.isSynced = true
                            // ── Atomic save with FK OFF to break the circular dependency:
                            //    Profiles.familyId → Families  AND  Families.createdBy → Profiles
                            db.bootstrapSaveIdentity(family: family, profile: p)
                        } else {
                            print("SyncManager [Bootstrap]: ⚠️ Family not found — saving profile with FK disabled anyway.")
                            // Create a minimal placeholder family so the profile insert succeeds
                            let placeholderFamily = Family(
                                familyId: p.familyId, familyName: "", sharableCode: "",
                                createdBy: nil,
                                createdAt: Date(), lastUpdatedAt: Date(), isSynced: false
                            )
                            db.bootstrapSaveIdentity(family: placeholderFamily, profile: p)
                        }

                        currentUserId = p.profileId
                        familyId = p.familyId
                        UserDefaults.standard.set(p.profileId.uuidString, forKey: "DataManagerCurrentUserId")
                        await refreshLocalUI()
                        print("SyncManager: ✅ Bootstrap identity resolved — \(p.firstName) (family: \(p.familyId)).")
                    } else {
                        print("SyncManager: ❌ bootstrapUserId '\(anchorIdStr)' returned 0 rows from Supabase.")
                        print("  → Check: (1) UUID is correct, (2) RLS allows anon reads on Profiles, (3) Supabase anon sign-in is enabled.")
                    }
                } catch {
                    print("SyncManager: ❌ Bootstrap network/auth error: \(error)")
                }
            }
            #endif

            // Tier 2: UserDefaults (previously signed-in device)
            let storedIdStr = UserDefaults.standard.string(forKey: "DataManagerCurrentUserId")
            if (currentUserId == nil || familyId == nil),
               let idStr = storedIdStr,
               let storedId = UUID(uuidString: idStr) {
                do {
                    let resp = try await client.from("Profiles").select().eq("profileId", value: storedId.uuidString).execute()
                    let profiles = try supabaseDecoder().decode([Profile].self, from: resp.data)
                    if let profile = profiles.first {
                        var p = profile; p.isSynced = true
                        db.saveProfile(p)
                        currentUserId = p.profileId
                        familyId = p.familyId
                        await refreshLocalUI()
                        print("SyncManager: Identity restored from UserDefaults for \(p.firstName).")
                    }
                } catch { print("SyncManager: Identity restoration failed: \(error)") }
            }
        }

        guard let fId = familyId, let uId = currentUserId else {
            print("SyncManager: No familyId/userId found. Skipping pull.")
            return
        }

        print("SyncManager: Pulling realtime data for family \(fId) (target: \(targetTable ?? "ALL"))...")

        do {
            let dec = supabaseDecoder()
            
            // Fetch profiles at the top as multiple sections depend on it
            let profilesResp = try await client.from("Profiles").select().eq("familyId", value: fId.uuidString).execute()
            let profiles = try dec.decode([Profile].self, from: profilesResp.data)

            // --- 1. Family & Profiles ---
            if targetTable == nil || targetTable == "Families" || targetTable == "Profiles" {
                let familyResp = try await client.from("Families").select().eq("familyId", value: fId.uuidString).execute()
                if let family = try? dec.decode([Family].self, from: familyResp.data).first {
                    var f = family; f.isSynced = true; db.saveFamily(f)
                }
                for var p in profiles { p.isSynced = true; db.saveProfile(p) }
                
                // --- Safety Guard: Pruning ---
                // Only prune local profiles if we got at least one profile back from remote.
                // This prevents wiping local data if the session expired or RLS returned an empty list.
                if !profiles.isEmpty {
                    let remoteProfileIds = Set(profiles.map(\.profileId))
                    for localProfile in db.fetchProfiles() where localProfile.familyId == fId && !remoteProfileIds.contains(localProfile.profileId) {
                        // Never prune the currently logged-in user!
                        if localProfile.profileId != uId {
                            db.deleteProfile(id: localProfile.profileId)
                            print("SyncManager: Pruned local profile \(localProfile.firstName) (not found on remote).")
                        }
                    }
                }
            }

            // --- 2. Direct Messages ---
            if targetTable == nil || targetTable == "Messages" {
                let msgsQuery = client.from("Messages").select().or("senderId.eq.\(uId.uuidString),receiverId.eq.\(uId.uuidString)")
                let msgs = try dec.decode([Message].self, from: try await msgsQuery.execute().data)
                for var m in msgs { m.isSynced = true; db.saveMessage(m) }
                await reconcileMessages(userId: uId)
            }

            // --- 3. Topics & Members ---
            if targetTable == nil || targetTable == "Topics" || targetTable == "TopicMembers" || targetTable == "TopicMessages" {
                let topicsResp = try await client.from("Topics").select().execute()
                let allTopics = try dec.decode([Topic].self, from: topicsResp.data)
                let membersResp = try await client.from("TopicMembers").select().execute()
                let allMembers = try dec.decode([TopicMember].self, from: membersResp.data)
                
                let familyProfileIds = profiles.map { $0.profileId }
                let myTopicIds = Set(allMembers.filter { familyProfileIds.contains($0.userId) }.map { $0.topicId })
                let myTopics = allTopics.filter { myTopicIds.contains($0.id) }
                for t in myTopics { var lt = t; lt.isSynced = true; db.saveTopic(lt) }
                let myMembers = allMembers.filter { myTopicIds.contains($0.topicId) }
                for m in myMembers { var lm = m; lm.isSynced = true; db.saveTopicMember(lm) }
                await reconcileTopics(remoteTopics: myTopics, remoteMembers: myMembers)

                // --- 4. Topic Messages ---
                var remoteTopicMessages: [TopicMessage] = []
                for topic in myTopics {
                    let q = client.from("TopicMessages").select().eq("topicId", value: topic.id.uuidString)
                    let tMsgs = try dec.decode([TopicMessage].self, from: try await q.execute().data)
                    for var tm in tMsgs {
                        tm.isSynced = true
                        db.saveTopicMessage(tm)
                    }
                    remoteTopicMessages.append(contentsOf: tMsgs)
                }
                await reconcileTopicMessages(remoteMessages: remoteTopicMessages)
            }

            // --- 5. ChallengeCompleted ---
            if targetTable == nil || targetTable == "ChallengeCompleted" {
                await refreshChallenges(for: fId)
            }

            // --- 6. UserRelationships ---
            if targetTable == nil || targetTable == "UserRelationships" {
                let relationResp = try await client.from("UserRelationships")
                    .select()
                    .eq("viewerId", value: uId.uuidString)
                    .execute()
                let rawJSON = String(data: relationResp.data, encoding: .utf8) ?? "nil"
                print("SyncManager: UserRelationships raw JSON from Supabase: \(rawJSON)")
                let relationships = try dec.decode([UserRelationshipNickname].self, from: relationResp.data)
                print("SyncManager: Decoded \(relationships.count) relationships: \(relationships.map { $0.nickname })")
                db.replaceRelationshipNicknames(for: uId, rows: relationships)
            }

            await refreshLocalUI()

            print("SyncManager: Realtime pull complete for target: \(targetTable ?? "ALL").")
        } catch { print("SyncManager Error during realtime pull: \(error)") }
    }

    private func pullDeferredData() async {
        guard let familyId = DataManager.shared.family?.familyId ?? DataManager.shared.currentUser?.familyId else {
            print("SyncManager: No family context available for deferred pull.")
            return
        }

        print("SyncManager: Pulling deferred data for family \(familyId)...")

        do {
            let dec = supabaseDecoder()



            var uniqueProfilesById: [UUID: Profile] = [:]
            for profile in db.fetchProfiles() where profile.familyId == familyId {
                uniqueProfilesById[profile.profileId] = profile
            }
            if let current = DataManager.shared.currentUser {
                uniqueProfilesById[current.profileId] = current
            }

            for profile in uniqueProfilesById.values {
                let pid = profile.profileId
                
                // Skip remote overwrite only when current login is the HealthKit owner.
                // For non-owner logins (e.g. papa), we still pull their Supabase data.
                if pid == DataManager.shared.currentUser?.profileId && DataManager.shared.isCurrentUserHealthKitLinked() {
                    continue
                }
                
                // Always fetch full remote health snapshot for non-current members,
                // then replace local rows to avoid stale/mock duplicates.
                let adResp = try await client.from("Health_ActivityDaily").select().eq("profileId", value: pid.uuidString).execute()
                var remoteAD = try dec.decode([ActivityDaily].self, from: adResp.data)
                remoteAD = remoteAD.map { var row = $0; row.isSynced = true; return row }
                
                let ahResp = try await client.from("Health_ActivityHourly").select().eq("profileId", value: pid.uuidString).execute()
                var remoteAH = try dec.decode([ActivityHourly].self, from: ahResp.data)
                remoteAH = remoteAH.map { var row = $0; row.isSynced = true; return row }
                
                let vdResp = try await client.from("Health_VitalsDaily").select().eq("profileId", value: pid.uuidString).execute()
                var remoteVD = try dec.decode([VitalsDaily].self, from: vdResp.data)
                remoteVD = remoteVD.map { var row = $0; row.isSynced = true; return row }
                
                let vhResp = try await client.from("Health_VitalsHourly").select().eq("profileId", value: pid.uuidString).execute()
                var remoteVH = try dec.decode([VitalsHourly].self, from: vhResp.data)
                remoteVH = remoteVH.map { var row = $0; row.isSynced = true; return row }
                
                let sdResp = try await client.from("Health_SleepDaily").select().eq("profileId", value: pid.uuidString).execute()
                var remoteSD = try dec.decode([SleepDaily].self, from: sdResp.data)
                remoteSD = remoteSD.map { var row = $0; row.isSynced = true; return row }
                
                // Safe Sync: Instead of clearing everything, we use INSERT OR REPLACE (Upsert) 
                // to update existing records and add new ones, preserving local history.
                for row in remoteAD { db.saveActivityDaily(row) }
                for row in remoteAH { db.saveActivityHourly(row) }
                for row in remoteVD { db.saveVitalsDaily(row) }
                for row in remoteVH { db.saveVitalsHourly(row) }
                for row in remoteSD { db.saveSleepDaily(row) }
            }

            await refreshChallenges(for: familyId)

            await refreshLocalUI()
            print("SyncManager: Deferred pull complete.")
        } catch {
            print("SyncManager Error during deferred pull: \(error)")
        }
    }



    // MARK: - Realtime Pub/Sub Subscriptions

    func setupRealtimeSubscriptions() async {
        guard let familyId = DataManager.shared.currentUser?.familyId else { return }

        // Clean up existing channels
        for channel in channels { await channel.unsubscribe() }
        channels.removeAll()
        observationTokens.removeAll()
        hasRealtimeSubscriptions = false

        // 1. Direct Messages
        let dmChannel = client.realtimeV2.channel("public:messages")
        let token1 = dmChannel.onPostgresChange(AnyAction.self, schema: "public", table: "Messages") { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let cId = DataManager.shared.currentUser?.profileId,
                      let fId = DataManager.shared.currentUser?.familyId else { return }
                self?.scheduleRealtimeRefresh(userId: cId, familyId: fId, reason: "Messages changed")
            }
        }
        channels.append(dmChannel)
        observationTokens.append(token1)

        // 2. Topic Messages
        let topicChannel = client.realtimeV2.channel("public:topic_messages")
        let token2 = topicChannel.onPostgresChange(AnyAction.self, schema: "public", table: "TopicMessages") { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let cId = DataManager.shared.currentUser?.profileId,
                      let fId = DataManager.shared.currentUser?.familyId else { return }
                self?.scheduleRealtimeRefresh(userId: cId, familyId: fId, reason: "TopicMessages changed")
            }
        }
        channels.append(topicChannel)
        observationTokens.append(token2)

        // 3. Profiles
        let profileChannel = client.realtimeV2.channel("public:profiles")
        let token3 = profileChannel.onPostgresChange(AnyAction.self, schema: "public", table: "Profiles") { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let cId = DataManager.shared.currentUser?.profileId,
                      let fId = DataManager.shared.currentUser?.familyId else { return }
                self?.scheduleRealtimeRefresh(userId: cId, familyId: fId, reason: "Profiles changed")
            }
        }
        channels.append(profileChannel)
        observationTokens.append(token3)

        // 4. Families
        let familyChannel = client.realtimeV2.channel("public:families")
        let token4 = familyChannel.onPostgresChange(AnyAction.self, schema: "public", table: "Families") { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let cId = DataManager.shared.currentUser?.profileId,
                      let fId = DataManager.shared.currentUser?.familyId else { return }
                self?.scheduleRealtimeRefresh(userId: cId, familyId: fId, reason: "Families changed")
            }
        }
        channels.append(familyChannel)
        observationTokens.append(token4)

        // 5. ChallengeDetails
        let cdChannel = client.realtimeV2.channel("public:challenge_details")
        let token5 = cdChannel.onPostgresChange(AnyAction.self, schema: "public", table: "ChallengeDetails") { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let cId = DataManager.shared.currentUser?.profileId,
                      let fId = DataManager.shared.currentUser?.familyId else { return }
                self?.scheduleRealtimeRefresh(userId: cId, familyId: fId, reason: "ChallengeDetails changed")
            }
        }
        channels.append(cdChannel)
        observationTokens.append(token5)

        // 5.1 ChallengeProgress
        let cpChannel = client.realtimeV2.channel("public:challenge_progress")
        let token5_1 = cpChannel.onPostgresChange(AnyAction.self, schema: "public", table: "ChallengeProgress") { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let cId = DataManager.shared.currentUser?.profileId,
                      let fId = DataManager.shared.currentUser?.familyId else { return }
                self?.scheduleRealtimeRefresh(userId: cId, familyId: fId, reason: "ChallengeProgress changed")
            }
        }
        channels.append(cpChannel)
        observationTokens.append(token5_1)

        // 6. Topics
        let topicInsertChannel = client.realtimeV2.channel("public:topics")
        let token6 = topicInsertChannel.onPostgresChange(AnyAction.self, schema: "public", table: "Topics") { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let cId = DataManager.shared.currentUser?.profileId,
                      let fId = DataManager.shared.currentUser?.familyId else { return }
                self?.scheduleRealtimeRefresh(userId: cId, familyId: fId, reason: "Topics changed")
            }
        }
        channels.append(topicInsertChannel)
        observationTokens.append(token6)

        // 7. TopicMembers
        let topicMembersChannel = client.realtimeV2.channel("public:topic_members")
        let token7 = topicMembersChannel.onPostgresChange(AnyAction.self, schema: "public", table: "TopicMembers") { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let cId = DataManager.shared.currentUser?.profileId,
                      let fId = DataManager.shared.currentUser?.familyId else { return }
                self?.scheduleRealtimeRefresh(userId: cId, familyId: fId, reason: "TopicMembers changed")
            }
        }
        channels.append(topicMembersChannel)
        observationTokens.append(token7)

        // 8. UserRelationships
        let relationshipChannel = client.realtimeV2.channel("public:user_relationships")
        let token8 = relationshipChannel.onPostgresChange(AnyAction.self, schema: "public", table: "UserRelationships") { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let cId = DataManager.shared.currentUser?.profileId,
                      let fId = DataManager.shared.currentUser?.familyId else { return }
                self?.scheduleRealtimeRefresh(userId: cId, familyId: fId, reason: "UserRelationships changed")
            }
        }
        channels.append(relationshipChannel)
        observationTokens.append(token8)

        // 9. Low-latency chat broadcasts. Postgres changes remain the source of truth,
        // but this wakes every family device immediately after a message write succeeds.
        let chatChannel = client.realtimeV2.channel(chatBroadcastTopic(familyId: familyId))
        let token9 = chatChannel.onBroadcast(event: directMessageBroadcastEvent) { [weak self] payload in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let cId = DataManager.shared.currentUser?.profileId,
                      let fId = DataManager.shared.currentUser?.familyId,
                      payload["familyId"]?.stringValue == fId.uuidString else { return }
                if await self.fetchDirectMessageFromBroadcast(payload) { return }
                self.scheduleRealtimeRefresh(userId: cId, familyId: fId, reason: "Messages broadcast")
            }
        }
        let token10 = chatChannel.onBroadcast(event: topicMessageBroadcastEvent) { [weak self] payload in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let cId = DataManager.shared.currentUser?.profileId,
                      let fId = DataManager.shared.currentUser?.familyId,
                      payload["familyId"]?.stringValue == fId.uuidString else { return }
                if await self.fetchTopicMessageFromBroadcast(payload) { return }
                self.scheduleRealtimeRefresh(userId: cId, familyId: fId, reason: "TopicMessages broadcast")
            }
        }
        // 10. Topic-creation broadcast — immediately pull topics when another device creates a group
        let token11 = chatChannel.onBroadcast(event: topicCreatedBroadcastEvent) { [weak self] payload in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let cId = DataManager.shared.currentUser?.profileId,
                      let fId = DataManager.shared.currentUser?.familyId,
                      payload["familyId"]?.stringValue == fId.uuidString else { return }
                print("SyncManager: Received topic-created broadcast, triggering pull...")
                self.scheduleRealtimeRefresh(userId: cId, familyId: fId, reason: "Topics broadcast")
            }
        }
        channels.append(chatChannel)
        observationTokens.append(token9)
        observationTokens.append(token10)
        observationTokens.append(token11)

        // Connect the Realtime client
        await client.realtimeV2.connect()

        // Start all channels
        do {
            try await dmChannel.subscribeWithError()
            try await topicChannel.subscribeWithError()
            try await profileChannel.subscribeWithError()
            try await familyChannel.subscribeWithError()
            try await topicInsertChannel.subscribeWithError()
            try await topicMembersChannel.subscribeWithError()
            try await relationshipChannel.subscribeWithError()
            try await cdChannel.subscribeWithError()
            try await cpChannel.subscribeWithError()
            try await chatChannel.subscribeWithError()
        } catch {
            print("SyncManager: Error subscribing to Realtime channels: \(error)")
        }

        // Pre-warm profile picture disk cache for all family members
        let allProfiles = [DataManager.shared.currentUser].compactMap { $0 } + DataManager.shared.allProfiles
        ImageManager.shared.prefetchProfilePictures(for: allProfiles)

        hasRealtimeSubscriptions = true
        print("SyncManager: All Realtime Pub/Sub channels active (\(channels.count) channels).")

        // Start periodic background sync
        startPeriodicSync()
    }

    // MARK: - Deletion Helpers (Remote)

    func deleteMessageRemote(id: UUID) {
        Task {
            do {
                try await client.from("Messages").delete().eq("messageId", value: id.uuidString).execute()
                print("SyncManager: Successfully deleted message \(id) from Supabase.")
            } catch {
                print("SyncManager Error deleting message remotely: \(error)")
            }
        }
    }

    func deleteTopicMessageRemote(id: UUID) {
        Task {
            do {
                try await client.from("TopicMessages").delete().eq("id", value: id.uuidString).execute()
                print("SyncManager: Deleted TopicMessage from cloud")
            } catch { print("SyncManager: Failed to delete TopicMessage - \(error)") }
        }
    }

    func deleteTopicRemote(id: UUID) {
        Task {
            do {
                // TopicMessages and TopicMembers will cascade delete in Supabase if foreign keys are set.
                // Otherwise, delete explicitly if needed. Assuming cascade is on for now, or just delete topic.
                try await client.from("Topics").delete().eq("id", value: id.uuidString).execute()
                print("SyncManager: Deleted Topic from cloud")
            } catch { print("SyncManager: Failed to delete Topic - \(error)") }
        }
    }

    func leaveTopicRemote(memberId: UUID) {
        Task {
            do {
                try await client.from("TopicMembers").delete().eq("id", value: memberId.uuidString).execute()
                print("SyncManager: Successfully left topic member \(memberId) from Supabase.")
            } catch {
                print("SyncManager Error leaving topic remotely: \(error)")
            }
        }
    }

    func deleteChallengeDetailsRemote(challengeId: UUID) {
        Task {
            do {
                try await client.from("ChallengeDetails")
                    .delete()
                    .eq("challengeId", value: challengeId.uuidString)
                    .execute()
                print("SyncManager: Successfully deleted ChallengeDetails \(challengeId) from Supabase.")
            } catch {
                print("SyncManager Error deleting ChallengeDetails remotely: \(error)")
            }
        }
    }

    func deleteChallengeProgressRemote(challengeId: UUID, memberId: UUID) {
        Task {
            do {
                try await client.from("ChallengeProgress")
                    .delete()
                    .eq("challengeId", value: challengeId.uuidString)
                    .eq("memberId", value: memberId.uuidString)
                    .execute()
                print("SyncManager: Successfully deleted ChallengeProgress \(challengeId) from Supabase.")
            } catch {
                print("SyncManager Error deleting ChallengeProgress remotely: \(error)")
            }
        }
    }

    // MARK: - Reconciliation & Helper Refresh

    private func refreshLocalUI() async {
        await MainActor.run {
            DataManager.shared.refreshLoadedCachesAfterSync()
        }
    }

    private func scheduleRealtimeRefresh(userId: UUID, familyId: UUID, reason: String) {
        realtimeRefreshTask?.cancel()
        realtimeRefreshTask = Task { [weak self] in
            // 300ms debounce
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            
            print("SyncManager: Realtime refresh triggered for \(reason).")
            
            guard let self = self else { return }
            
            if self.isPullingRealtimeData {
                print("SyncManager: Pull already in progress, deferring refresh.")
                self.realtimeRefreshNeeded = true
                return
            }
            
            self.isPullingRealtimeData = true
            self.realtimeRefreshNeeded = false
            
            // Map reason to targetTable
            var targetTable: String? = nil
            if reason.contains("Messages") { targetTable = "Messages" }
            else if reason.contains("TopicMessages") { targetTable = "TopicMessages" }
            else if reason.contains("Profiles") { targetTable = "Profiles" }
            else if reason.contains("Families") { targetTable = "Families" }
            else if reason.contains("ChallengeCompleted") { targetTable = "ChallengeCompleted" }
            else if reason.contains("Topics") { targetTable = "Topics" }
            else if reason.contains("TopicMembers") { targetTable = "TopicMembers" }
            else if reason.contains("UserRelationships") { targetTable = "UserRelationships" }
            
            await self.pullRealtimeData(targetTable: targetTable)
            
            self.isPullingRealtimeData = false
            
            // If another refresh was requested while we were pulling, run it now
            if self.realtimeRefreshNeeded {
                self.scheduleRealtimeRefresh(userId: userId, familyId: familyId, reason: "Deferred refresh")
            }
        }
    }

    private func chatBroadcastTopic(familyId: UUID) -> String {
        "family:\(familyId.uuidString):chat"
    }

    private func broadcastDirectMessageChange(_ message: Message) async {
        guard let familyId = DataManager.shared.currentUser?.familyId else { return }
        do {
            let channel = client.realtimeV2.channel(chatBroadcastTopic(familyId: familyId))
            try await channel.broadcast(
                event: directMessageBroadcastEvent,
                message: [
                    "familyId": familyId.uuidString,
                    "messageId": message.messageId.uuidString,
                    "senderId": message.senderId.uuidString,
                    "receiverId": message.receiverId.uuidString
                ]
            )
        } catch {
            print("SyncManager Error broadcasting DM change: \(error)")
        }
    }

    private func broadcastTopicMessageChange(_ message: TopicMessage) async {
        guard let familyId = DataManager.shared.currentUser?.familyId else { return }
        do {
            let channel = client.realtimeV2.channel(chatBroadcastTopic(familyId: familyId))
            try await channel.broadcast(
                event: topicMessageBroadcastEvent,
                message: [
                    "familyId": familyId.uuidString,
                    "topicId": message.topicId.uuidString,
                    "messageId": message.id.uuidString,
                    "senderId": message.senderId.uuidString
                ]
            )
        } catch {
            print("SyncManager Error broadcasting TopicMessage change: \(error)")
        }
    }

    private func broadcastTopicCreated(_ topic: Topic) async {
        guard let familyId = DataManager.shared.currentUser?.familyId else { return }
        do {
            let channel = client.realtimeV2.channel(chatBroadcastTopic(familyId: familyId))
            try await channel.broadcast(
                event: topicCreatedBroadcastEvent,
                message: [
                    "familyId": familyId.uuidString,
                    "topicId": topic.id.uuidString,
                    "title": topic.title
                ]
            )
            print("SyncManager: Broadcasted topic-created for '\(topic.title)'")
        } catch {
            print("SyncManager Error broadcasting topic creation: \(error)")
        }
    }

    private func fetchDirectMessageFromBroadcast(_ payload: JSONObject) async -> Bool {
        guard let currentUserId = DataManager.shared.currentUser?.profileId,
              let messageId = uuid(from: payload["messageId"]),
              let senderId = uuid(from: payload["senderId"]),
              let receiverId = uuid(from: payload["receiverId"]),
              senderId == currentUserId || receiverId == currentUserId else {
            return false
        }

        do {
            let response = try await client.from("Messages")
                .select()
                .eq("messageId", value: messageId.uuidString)
                .execute()
            guard var message = try supabaseDecoder().decode([Message].self, from: response.data).first else {
                return false
            }
            message.isSynced = true
            db.saveMessage(message)
            await refreshLocalUI()
            print("SyncManager: Applied targeted DM fetch \(messageId)")
            return true
        } catch {
            print("SyncManager Error fetching broadcast DM \(messageId): \(error)")
            return false
        }
    }

    private func fetchTopicMessageFromBroadcast(_ payload: JSONObject) async -> Bool {
        guard let currentUserId = DataManager.shared.currentUser?.profileId,
              let messageId = uuid(from: payload["messageId"]),
              let topicId = uuid(from: payload["topicId"]),
              let senderId = uuid(from: payload["senderId"]) else {
            return false
        }

        let isMember = db.fetchTopicMembers(for: topicId).contains { $0.userId == currentUserId }
        guard isMember || senderId == currentUserId else { return false }

        do {
            let response = try await client.from("TopicMessages")
                .select()
                .eq("id", value: messageId.uuidString)
                .execute()
            guard var message = try supabaseDecoder().decode([TopicMessage].self, from: response.data).first else {
                return false
            }
            message.isSynced = true
            db.saveTopicMessage(message)
            await refreshLocalUI()
            print("SyncManager: Applied targeted TopicMessage fetch \(messageId)")
            return true
        } catch {
            print("SyncManager Error fetching broadcast TopicMessage \(messageId): \(error)")
            return false
        }
    }

    private func uuid(from value: AnyJSON?) -> UUID? {
        guard let string = value?.stringValue else { return nil }
        return UUID(uuidString: string)
    }

    private func refreshChallenges(for familyId: UUID) async {
        let dec = supabaseDecoder()

        // 1. Fetch ChallengeDetails
        do {
            let detailsResp = try await client.from("ChallengeDetails")
                .select()
                .eq("familyId", value: familyId.uuidString)
                .execute()
            let remoteDetails = try dec.decode([ChallengeDetails].self, from: detailsResp.data)
            
            for var details in remoteDetails {
                details.isSynced = true
                db.saveChallengeDetails(details)
            }

            let remoteDetailsIds = Set(remoteDetails.map { $0.challengeId })
            if !remoteDetails.isEmpty {
                let localDetails = db.fetchChallengeDetails().filter { $0.familyId == familyId }
                for local in localDetails {
                    if !remoteDetailsIds.contains(local.challengeId) {
                        db.deleteChallengeDetails(challengeId: local.challengeId)
                    }
                }
            }
        } catch {
            print("SyncManager Error pulling ChallengeDetails: \(error)")
        }

        // 2. Fetch ChallengeProgress
        do {
            let localDetails = db.fetchChallengeDetails().filter { $0.familyId == familyId }
            let challengeIds = localDetails.map { $0.challengeId.uuidString }
            if !challengeIds.isEmpty {
                let progressResp = try await client.from("ChallengeProgress")
                    .select()
                    .in("challengeId", values: challengeIds)
                    .execute()
                
                struct ProgressDTO: Decodable {
                    let challengeId: UUID; let memberId: UUID; let goalValue: Double; let currentValue: Double
                    let lastUpdatedAt: Date
                }
                let remoteProgressDTOs = try dec.decode([ProgressDTO].self, from: progressResp.data)
                let remoteProgress = remoteProgressDTOs.map {
                    ChallengeProgress(challengeId: $0.challengeId, memberId: $0.memberId,
                                      goalValue: $0.goalValue, currentValue: $0.currentValue,
                                      lastUpdatedAt: $0.lastUpdatedAt, isSynced: true)
                }

                for progress in remoteProgress {
                    db.saveChallengeProgress(progress)
                }

                let remoteProgressKeys = Set(remoteProgress.map { "\($0.challengeId)|\($0.memberId)" })
                if !remoteProgress.isEmpty {
                    let localProgress = db.fetchChallengeProgress()
                        .filter { challengeIds.contains($0.challengeId.uuidString) }
                    
                    for local in localProgress {
                        let key = "\(local.challengeId)|\(local.memberId)"
                        if !remoteProgressKeys.contains(key) {
                            db.deleteChallengeProgress(challengeId: local.challengeId, memberId: local.memberId)
                        }
                    }
                }
            }
        } catch {
            print("SyncManager Error pulling ChallengeProgress: \(error)")
        }

        let refreshedDetails = db.fetchChallengeDetails()
        let refreshedProgress = db.fetchChallengeProgress()
        await MainActor.run {
            DataManager.shared.challenges = refreshedDetails
            DataManager.shared.challengeProgress = refreshedProgress
            NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        }
    }
    
    private func reconcileMessages(userId: UUID) async {
        do {
            struct IDResult: Decodable { let messageId: UUID }
            let remoteIDs: [IDResult] = try await client.from("Messages")
                .select("messageId")
                .or("senderId.eq.\(userId.uuidString),receiverId.eq.\(userId.uuidString)")
                .execute()
                .value
            
            let remoteSet = Set(remoteIDs.map { $0.messageId })
            
            // --- Safety Guard: Pruning ---
            // Only prune local messages if Supabase returned a non-empty set of IDs.
            if !remoteSet.isEmpty {
                let localMsgs = db.fetchAllMessages()
                for m in localMsgs {
                    if !remoteSet.contains(m.messageId) {
                        db.deleteMessage(id: m.messageId)
                        print("SyncManager Reconciliation: Pruned local message \(m.messageId)")
                    }
                }
            }
        } catch { print("SyncManager reconciliation error: \(error)") }
    }

    private func reconcileTopics(remoteTopics: [Topic], remoteMembers: [TopicMember]) async {
        // Purge expired entries from the grace period map
        let now = Date()
        recentlyCreatedTopicIds = recentlyCreatedTopicIds.filter { now.timeIntervalSince($0.value) < topicGracePeriod }

        // --- Safety Guard: Pruning ---
        // Only prune local topics/members if the remote list is not empty.
        if !remoteTopics.isEmpty {
            let remoteTopicIds = Set(remoteTopics.map(\.id))
            for localTopic in db.fetchTopics() where !remoteTopicIds.contains(localTopic.id) {
                // Skip pruning topics that were recently created locally (grace period)
                if recentlyCreatedTopicIds[localTopic.id] != nil {
                    print("SyncManager: Skipping reconciliation prune for recently created topic '\(localTopic.title)' (grace period active).")
                    continue
                }
                db.deleteTopic(id: localTopic.id)
            }

            let remoteMemberIds = Set(remoteMembers.map(\.id))
            for topic in remoteTopics {
                for localMember in db.fetchTopicMembers(for: topic.id) where !remoteMemberIds.contains(localMember.id) {
                    db.deleteTopicMember(id: localMember.id)
                }
            }
        }
    }
    
    private func reconcileTopicMessages(remoteMessages: [TopicMessage]) async {
        // --- Safety Guard: Pruning ---
        // Only prune local topic messages if remote results were returned.
        if !remoteMessages.isEmpty {
            let remoteSet = Set(remoteMessages.map(\.id))
            let allTopics = db.fetchTopics()
            for topic in allTopics {
                let msgs = db.fetchTopicMessages(for: topic.id)
                for msg in msgs where !remoteSet.contains(msg.id) {
                    db.deleteTopicMessage(id: msg.id)
                    print("SyncManager Reconciliation: Pruned local topic message \(msg.id)")
                }
            }
        }
    }

    // MARK: - Proper Supabase Date Decoder

    private func supabaseDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        let fractionalISO = ISO8601DateFormatter()
        fractionalISO.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standardISO = ISO8601DateFormatter()
        standardISO.formatOptions = [.withInternetDateTime]
        
        let fallbackFormats = [
            "yyyy-MM-dd HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ssX",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssX",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd"
        ]
        let fallbackFormatters: [DateFormatter] = fallbackFormats.map { format in
            let f = DateFormatter()
            f.dateFormat = format
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            return f
        }
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines)
            
            var candidates: [String] = [raw]
            if raw.contains(" ") {
                let isoLike = raw.replacingOccurrences(of: " ", with: "T")
                candidates.append(isoLike)
                if isoLike.hasSuffix("+00") { candidates.append(isoLike + ":00") }
                if isoLike.hasSuffix("-00") { candidates.append(isoLike + ":00") }
            }
            
            for candidate in candidates {
                if let date = fractionalISO.date(from: candidate) { return date }
                if let date = standardISO.date(from: candidate) { return date }
                for formatter in fallbackFormatters {
                    if let date = formatter.date(from: candidate) { return date }
                }
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid Supabase Date: \(raw)")
        }
        return decoder
    }

    private func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func ymdString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
