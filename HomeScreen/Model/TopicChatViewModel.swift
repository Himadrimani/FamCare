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
        NotificationCenter.default.addObserver(self, selector: #selector(dataManagerDidUpdate), name: .ChatDataDidUpdate, object: nil)
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
        DataManager.shared.reloadTopicMessages(for: topic.id)
        let fetched = DataManager.shared.topicMessages
            .filter { $0.topicId == topic.id }
            .sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
        
        // 1. Separate vote payloads from displayable messages
        var displayMessages: [TopicMessage] = []
        var pollVotesByPollId: [UUID: [PollVotePayload]] = [:]
        
        for msg in fetched {
            let c = msg.content
            if c.hasPrefix("[POLL_VOTE:") {
                if let vote = PollVotePayload.parse(from: c) {
                    pollVotesByPollId[vote.pollId, default: []].append(vote)
                }
            } else if !(c.hasPrefix("[SHARE_CARD:INSIGHT") || c.hasPrefix("[SHARE_CARD:CHALLENGE")) {
                displayMessages.append(msg)
            }
        }
        
        // 2. Apply all vote payloads chronologically to their parent polls
        for (pollId, votes) in pollVotesByPollId {
            let sortedVotes = votes.sorted { $0.timestamp < $1.timestamp }
            if let idx = displayMessages.firstIndex(where: { $0.id == pollId }) {
                var msg = displayMessages[idx]
                if var poll = PollData.parse(from: msg.content) {
                    for vote in sortedVotes {
                        poll.apply(vote: vote)
                    }
                    if let updatedContent = poll.encodeToMessageContent() {
                        msg.content = updatedContent
                        displayMessages[idx] = msg
                        SQLiteHelper.shared.saveTopicMessage(msg)
                        if let dIdx = DataManager.shared.topicMessages.firstIndex(where: { $0.id == pollId }) {
                            DataManager.shared.topicMessages[dIdx].content = updatedContent
                        }
                    }
                }
            }
        }
        
        self.messages = displayMessages
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
        NotificationCenter.default.post(
            name: .ChatDataDidUpdate,
            object: nil,
            userInfo: [NotificationPayloadKey.conversationId: topic.id.uuidString]
        )
        NotificationCenter.default.post(name: Notification.Name("DataManagerDidUpdate"), object: nil)
        await fetchMessages()
    }
    
    func sendPoll(question: String, options: [String], allowsMultiple: Bool) async {
        guard let currentUserId = DataManager.shared.currentUser?.profileId else { return }
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOptions = options.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !trimmedQuestion.isEmpty, trimmedOptions.count >= 2 else { return }
        
        let pollId = UUID()
        let pollOptions = trimmedOptions.enumerated().map { (index, text) in
            PollData.PollOption(id: "opt_\(index)_\(UUID().uuidString.prefix(6))", text: text, voterIds: [])
        }
        
        let poll = PollData(
            id: pollId,
            topicId: topic.id,
            creatorId: currentUserId,
            question: trimmedQuestion,
            options: pollOptions,
            allowsMultipleAnswers: allowsMultiple,
            createdAt: Date()
        )
        
        guard let content = poll.encodeToMessageContent() else { return }
        
        let newMessage = TopicMessage(
            id: pollId,
            topicId: topic.id,
            senderId: currentUserId,
            content: content,
            createdAt: Date()
        )
        
        DataManager.shared.insertTopicMessageLocally(newMessage)
        NotificationCenter.default.post(
            name: .ChatDataDidUpdate,
            object: nil,
            userInfo: [NotificationPayloadKey.conversationId: topic.id.uuidString]
        )
        NotificationCenter.default.post(name: Notification.Name("DataManagerDidUpdate"), object: nil)
        await fetchMessages()
    }
    
    func voteOnPoll(message: TopicMessage, optionId: String) async {
        guard let currentUserId = DataManager.shared.currentUser?.profileId else { return }
        
        // Always read the latest state from SQLite to preserve any concurrent votes
        let latestMsg = SQLiteHelper.shared.fetchTopicMessage(id: message.id) ?? message
        guard var poll = PollData.parse(from: latestMsg.content) else { return }
        
        poll.toggleVote(userId: currentUserId, optionId: optionId)
        
        guard let updatedContent = poll.encodeToMessageContent() else { return }
        
        // Build updated message — keep isSynced false until Supabase confirms
        var updatedMessage = TopicMessage(
            id: message.id,
            topicId: message.topicId,
            senderId: message.senderId,
            content: updatedContent,
            createdAt: message.createdAt,
            isSynced: false
        )
        
        // 1. Update SQLite immediately for local responsiveness
        SQLiteHelper.shared.saveTopicMessage(updatedMessage)
        
        // 2. Update DataManager in-memory list
        if let idx = DataManager.shared.topicMessages.firstIndex(where: { $0.id == message.id }) {
            DataManager.shared.topicMessages[idx] = updatedMessage
        } else {
            DataManager.shared.topicMessages.append(updatedMessage)
        }
        
        // 3. Immediately refresh local messages so the UI updates
        await fetchMessages()
        
        // 4. Notify UI
        NotificationCenter.default.post(
            name: .ChatDataDidUpdate,
            object: nil,
            userInfo: [NotificationPayloadKey.conversationId: topic.id.uuidString]
        )
        NotificationCenter.default.post(name: Notification.Name("DataManagerDidUpdate"), object: nil)
        
        // 5. Record voter's selection as a dedicated vote event message.
        // Because senderId matches current user's auth UID, Supabase INSERT RLS permits this 100%.
        let selectedOptions = poll.options.filter { $0.voterIds.contains(currentUserId) }.map { $0.id }
        let votePayload = PollVotePayload(
            pollId: message.id,
            voterId: currentUserId,
            selectedOptionIds: selectedOptions,
            timestamp: Date()
        )
        if let voteContent = votePayload.encodeToMessageContent() {
            let voteMessage = TopicMessage(
                id: UUID(),
                topicId: topic.id,
                senderId: currentUserId,
                content: voteContent,
                createdAt: Date(),
                isSynced: false
            )
            DataManager.shared.insertTopicMessageLocally(voteMessage)
        }
        
        // 6. Push to Supabase synchronously and broadcast full content to all family members
        do {
            try await SyncManager.shared.updateTopicMessageAndWait(updatedMessage)
            updatedMessage.isSynced = true
            SQLiteHelper.shared.saveTopicMessage(updatedMessage)
            if let idx = DataManager.shared.topicMessages.firstIndex(where: { $0.id == message.id }) {
                DataManager.shared.topicMessages[idx] = updatedMessage
            }
        } catch {
            print("TopicChatViewModel: Supabase poll vote update failed: \(error)")
        }
    }
}
