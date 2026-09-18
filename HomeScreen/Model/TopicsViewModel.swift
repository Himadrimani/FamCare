import Foundation
import Combine

@MainActor
class TopicsViewModel: ObservableObject {
    @Published var topics: [Topic] = []
    @Published var familyMembers: [TopicProfile] = []
    
    // Store latest message per topic id for the UI preview
    @Published var latestMessages: [UUID: TopicMessage] = [:]
    
    // Tracks how many messages were visible last time the topic was opened.
    @Published var unreadCounts: [UUID: Int] = [:]
    
    init() {
        loadUnreadCounts()
        NotificationCenter.default.addObserver(self, selector: #selector(dataManagerDidUpdate), name: Notification.Name("DataManagerDidUpdate"), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func onAppear() {
        Task {
            await fetchTopicsAndMessages()
            await fetchFamilyMembers()
        }
    }
    
    @objc private func dataManagerDidUpdate() {
        Task {
            await fetchTopicsAndMessages()
        }
    }
    
    func fetchTopicsAndMessages() async {
        guard let currentUserId = DataManager.shared.currentUser?.profileId else { return }
        DataManager.shared.ensureTopicsLoadedForCurrentUser(includeMessages: true)
        
        let userTopicIds = DataManager.shared.topicMembers
            .filter { $0.userId == currentUserId }
            .map { $0.topicId }
        
        let rawTopics = DataManager.shared.topics
            .filter { userTopicIds.contains($0.id) }
        
        var latestMsgsMap: [UUID: TopicMessage] = [:]
        for topic in rawTopics {
            let latestMsg = DataManager.shared.topicMessages
                .filter { $0.topicId == topic.id }
                .sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
                .first
            if let latestMsg = latestMsg {
                latestMsgsMap[topic.id] = latestMsg
            }
        }
        
        let fetchedTopics = rawTopics.sorted {
            let aDate = latestMsgsMap[$0.id]?.createdAt ?? $0.createdAt ?? Date.distantPast
            let bDate = latestMsgsMap[$1.id]?.createdAt ?? $1.createdAt ?? Date.distantPast
            return aDate > bDate
        }
        
        self.latestMessages = latestMsgsMap
        self.topics = fetchedTopics
        recomputeUnreadCounts(for: fetchedTopics)
    }

    func deleteTopic(_ topic: Topic) {
        DataManager.shared.deleteTopic(topic)
        Task {
            await fetchTopicsAndMessages()
        }
    }
    
    func fetchFamilyMembers() async {
        guard familyMembers.isEmpty else { return }
        let localProfiles = DataManager.shared.allProfiles
        self.familyMembers = localProfiles.map { profile in
            TopicProfile(
                id: profile.profileId,
                name: profile.displayName,
                petName: DataManager.shared.personalNicknames[profile.profileId] ?? "",
                familyId: profile.familyId,
                email: profile.email,
                avatarUrl: profile.profilePic
            )
        }
    }
    
    // Create topic entirely locally offline
    func createTopic(title: String, message: String, memberIds: [UUID]) async throws -> UUID {
        guard let currentUserId = DataManager.shared.currentUser?.profileId else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No User Logged In"])
        }
        
        var membersToJoin = memberIds
        if !membersToJoin.contains(currentUserId) {
            membersToJoin.append(currentUserId)
        }
        
        let topic = DataManager.shared.createTopicLocally(title: title, creatorId: currentUserId, members: membersToJoin)
        
        let topicMessagePayload = TopicMessage(
            id: UUID(),
            topicId: topic.id,
            senderId: currentUserId,
            content: message,
            createdAt: Date()
        )
        
        DataManager.shared.insertTopicMessageLocally(topicMessagePayload)
        NotificationCenter.default.post(name: Notification.Name("DataManagerDidUpdate"), object: nil)
        await fetchTopicsAndMessages()
        
        return topic.id
    }
    
    // MARK: - Unread Count Management
    
    private let seenCountsKey = "TopicSeenMessageCounts"
    
    private func loadUnreadCounts() {
        if let data = UserDefaults.standard.data(forKey: seenCountsKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            var counts: [UUID: Int] = [:]
            for (key, value) in decoded {
                if let uuid = UUID(uuidString: key) {
                    counts[uuid] = value
                }
            }
            self.unreadCounts = computeUnreadFrom(seenCounts: counts)
        }
    }
    
    private func recomputeUnreadCounts(for topics: [Topic]) {
        var seenCounts: [UUID: Int] = [:]
        if let data = UserDefaults.standard.data(forKey: seenCountsKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            for (key, value) in decoded {
                if let uuid = UUID(uuidString: key) {
                    seenCounts[uuid] = value
                }
            }
        }
        
        var newCounts: [UUID: Int] = [:]
        let currentUserId = DataManager.shared.currentUser?.profileId
        for topic in topics {
            let totalReceived = DataManager.shared.topicMessages
                .filter { $0.topicId == topic.id && $0.senderId != currentUserId }
                .count
            let seen = seenCounts[topic.id] ?? 0
            newCounts[topic.id] = max(0, totalReceived - seen)
        }
        self.unreadCounts = newCounts
        
        // ALSO count unread Direct Messages
        DataManager.shared.ensureDirectMessagesLoaded()
        let unreadDMs = DataManager.shared.messages
            .filter { $0.receiverId == currentUserId && $0.readAt == nil }
            .count
        
        let total = newCounts.values.reduce(0, +) + unreadDMs
        NotificationCenter.default.post(name: NSNotification.Name("TotalUnreadMessagesChanged"), object: total)
    }
    
    private func computeUnreadFrom(seenCounts: [UUID: Int]) -> [UUID: Int] {
        let currentUserId = DataManager.shared.currentUser?.profileId
        var counts: [UUID: Int] = [:]
        for (topicId, seen) in seenCounts {
            let total = DataManager.shared.topicMessages
                .filter { $0.topicId == topicId && $0.senderId != currentUserId }
                .count
            counts[topicId] = max(0, total - seen)
        }
        return counts
    }
    
    func markTopicAsSeen(topicId: UUID) {
        let currentUserId = DataManager.shared.currentUser?.profileId
        let currentCount = DataManager.shared.topicMessages
            .filter { $0.topicId == topicId && $0.senderId != currentUserId }
            .count
        
        var seenCounts: [String: Int] = [:]
        if let data = UserDefaults.standard.data(forKey: seenCountsKey),
           let existing = try? JSONDecoder().decode([String: Int].self, from: data) {
            seenCounts = existing
        }
        seenCounts[topicId.uuidString] = currentCount
        if let encoded = try? JSONEncoder().encode(seenCounts) {
            UserDefaults.standard.set(encoded, forKey: seenCountsKey)
        }
        
        recomputeUnreadCounts(for: topics)
    }
    
    func unreadCount(for topicId: UUID) -> Int {
        return unreadCounts[topicId] ?? 0
    }
    
    func getMembers(for topicId: UUID) -> [TopicProfile] {
        let memberIds = DataManager.shared.topicMembers
            .filter { $0.topicId == topicId }
            .map { $0.userId }
        
        let localProfiles = DataManager.shared.allProfiles
        var profiles = localProfiles.filter { memberIds.contains($0.profileId) }.map { profile in
            TopicProfile(
                id: profile.profileId,
                name: profile.displayName,
                petName: DataManager.shared.personalNicknames[profile.profileId] ?? "",
                familyId: profile.familyId,
                email: profile.email,
                avatarUrl: profile.profilePic
            )
        }

        if let currentUser = DataManager.shared.currentUser, memberIds.contains(currentUser.profileId) {
            profiles.append(
                TopicProfile(
                    id: currentUser.profileId,
                    name: currentUser.displayName,
                    petName: DataManager.shared.personalNicknames[currentUser.profileId] ?? "",
                    familyId: currentUser.familyId,
                    email: currentUser.email,
                    avatarUrl: currentUser.profilePic
                )
            )
        }

        return profiles
    }
}
