import re
with open("HomeScreen/Model/DataManager.swift", "r") as f:
    content = f.read()

replacement = """    // Updates a profile and persists it to SQLite, then pushes to Supabase immediately
    func updateProfile(_ profile: Profile) {
        SQLiteHelper.shared.saveProfile(profile)
        upsertProfileInMemory(profile, notify: true)
        // Immediately push profile change to Supabase
        SyncManager.shared.pushProfileUpdate(profile)
    }

    func updateChallenge(_ challenge: ChallengeDetails) {
        var updatedChallenge = challenge
        updatedChallenge.isSynced = false
        updatedChallenge.lastUpdatedAt = Date()
        
        SQLiteHelper.shared.saveChallengeDetails(updatedChallenge)
        
        if let index = challenges.firstIndex(where: { $0.challengeId == updatedChallenge.challengeId }) {
            challenges[index] = updatedChallenge
        } else {
            challenges.append(updatedChallenge)
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        
        Task {
            await SyncManager.shared.pushUnsyncedData()
        }
    }
    
    func deleteChallenge(_ challenge: ChallengeDetails) {
        challenges.removeAll(where: { $0.challengeId == challenge.challengeId })
        challengeProgress.removeAll(where: { $0.challengeId == challenge.challengeId })
        
        SQLiteHelper.shared.deleteChallengeDetails(challengeId: challenge.challengeId)
        
        NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        
        Task {
            SyncManager.shared.deleteChallengeDetailsRemote(challengeId: challenge.challengeId)
        }
    }"""

target_pattern = r"    // Updates a profile and persists it to SQLite, then pushes to Supabase immediately\n    func updateProfile\(_ profile: Profile\) \{\n        SQLiteHelper.shared.saveProfile\(profile\)\n        upsertProfileInMemory\(profile, notify: true\)\n        // Immediately push profile change to Supabase\n        SyncManager.shared.pushProfileUpdate\(profile\)\n    \}"

if re.search(target_pattern, content):
    content = re.sub(target_pattern, replacement, content, count=1)
    with open("HomeScreen/Model/DataManager.swift", "w") as f:
        f.write(content)
    print("Success")
else:
    print("Could not find target pattern")
