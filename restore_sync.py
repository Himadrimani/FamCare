import re
with open("HomeScreen/Model/SyncManager.swift", "r") as f:
    content = f.read()

replacement = """    }

    func deleteTopicRemote(id: UUID) {
        Task {
            do {
                try await client.from("Topics").delete().eq("id", value: id.uuidString).execute()
                print("SyncManager: Successfully deleted topic \(id) from Supabase.")
            } catch {
                print("SyncManager Error deleting topic remotely: \(error)")
            }
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

    func deleteChallengeDetailsRemote(challengeId: UUID) {"""

target_pattern = r"    \}\n\n    func deleteChallengeDetailsRemote\(challengeId: UUID\) \{"

if re.search(target_pattern, content):
    content = re.sub(target_pattern, replacement, content, count=1)
    with open("HomeScreen/Model/SyncManager.swift", "w") as f:
        f.write(content)
    print("Success")
else:
    print("Could not find target pattern")
