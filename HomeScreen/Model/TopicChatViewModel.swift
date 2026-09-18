import Foundation
import Combine

@MainActor
class TopicChatViewModel: ObservableObject {
    @Published var messages: [TopicMessage] = []
    @Published var profiles: [UUID: TopicProfile] = [:]
    
    let topic: Topic
    
    init(topic: Topic) {
        self.topic = topic
        NotificationCenter.default.addObserver(self, selector: #selector(dataManagerDidUpdate), name: Notification.Name("DataManagerDidUpdate"), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func onAppear() {
        Task {
            await fetchMessages()
            await fetchProfilesForTopic()
        }
    }
    
    @objc private func dataManagerDidUpdate() {
        Task {
            await fetchMessages()
        }
    }
    
    func fetchMessages() async {
        DataManager.shared.ensureTopicMessagesLoaded(for: topic.id)
        let fetchedMessages = DataManager.shared.topicMessages
            .filter { $0.topicId == topic.id }
            .sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
        self.messages = fetchedMessages
    }
    
    func fetchProfilesForTopic() async {
        DataManager.shared.ensureTopicMembersLoaded(for: topic.id)
        let userIds = DataManager.shared.topicMembers
            .filter { $0.topicId == topic.id }
            .map { $0.userId }
        
        guard !userIds.isEmpty else { return }
        
        let allLocalProfiles = DataManager.shared.allProfiles + ([DataManager.shared.currentUser].compactMap { $0 })
        
        for id in userIds {
            if let profile = allLocalProfiles.first(where: { $0.profileId == id }) {
                self.profiles[id] = TopicProfile(
                    id: profile.profileId,
                    name: profile.displayName,
                    petName: DataManager.shared.personalNicknames[profile.profileId] ?? "",
                    familyId: profile.familyId,
                    email: profile.email,
                    avatarUrl: profile.profilePic
                )
            }
        }
    }
    
    func sendMessage(content: String) async {
        guard let currentUserId = DataManager.shared.currentUser?.profileId else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let newMessage = TopicMessage(
            id: UUID(),
            topicId: topic.id,
            senderId: currentUserId,
            content: trimmed,
            createdAt: Date()
        )
        
        DataManager.shared.insertTopicMessageLocally(newMessage)
        NotificationCenter.default.post(name: Notification.Name("DataManagerDidUpdate"), object: nil)
        await fetchMessages()
    }
}
