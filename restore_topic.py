import re
with open("HomeScreen/Model/DataManager.swift", "r") as f:
    content = f.read()

replacement = """    func deleteTopicMessage(_ message: TopicMessage) {
        topicMessages.removeAll(where: { $0.id == message.id })
        SQLiteHelper.shared.deleteTopicMessage(id: message.id)
        NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        SyncManager.shared.deleteTopicMessageRemote(id: message.id)
    }
    
    func leaveTopic(topicId: UUID, memberId: UUID) {
        if let member = topicMembers.first(where: { $0.topicId == topicId && $0.userId == memberId }) {
            topicMembers.removeAll(where: { $0.id == member.id })
            SQLiteHelper.shared.deleteTopicMember(id: member.id)
            NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
            SyncManager.shared.leaveTopicRemote(memberId: member.id)
        }
    }
    
    func deleteTopic(_ topic: Topic) {
        topics.removeAll(where: { $0.id == topic.id })
        SQLiteHelper.shared.deleteTopic(id: topic.id)
        NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        SyncManager.shared.deleteTopicRemote(id: topic.id)
    }"""

target_pattern = r"    func deleteTopicMessage\(_ message: TopicMessage\) \{\n        topicMessages.removeAll\(where: \{ \$0.id == message.id \}\)\n        SQLiteHelper.shared.deleteTopicMessage\(id: message.id\)\n        NotificationCenter.default.post\(name: NSNotification.Name\(\"DataManagerDidUpdate\"\), object: nil\)\n        SyncManager.shared.deleteTopicMessageRemote\(id: message.id\)\n    \}"

if re.search(target_pattern, content):
    content = re.sub(target_pattern, replacement, content, count=1)
    with open("HomeScreen/Model/DataManager.swift", "w") as f:
        f.write(content)
    print("Success")
else:
    print("Could not find target pattern")
