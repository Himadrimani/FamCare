import Foundation

/// Builds a rich text snapshot of the user's family health data
/// from DataManager to inject into AI Assistant conversations.
/// This eliminates the need for tool-call round trips — the AI
/// receives all context upfront and can answer naturally.
class AssistantDataProvider {
    
    static func buildContext() -> String {
        let dm = DataManager.shared
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        var context = "=== FAMCARE HEALTH DATA SNAPSHOT ===\n"
        context += "Date: \(formatDate(now))\n\n"
        
        // Current user
        guard let currentUser = dm.currentUser else {
            return context + "No user is currently logged in.\n"
        }
        
        // Family info
        if let family = dm.family {
            context += "Family: \(family.familyName)\n"
        }
        
        // Build data for each family member
        var allMembers = [currentUser]
        allMembers.append(contentsOf: dm.allProfiles.filter { $0.profileId != currentUser.profileId })
        
        context += "Family Members: \(allMembers.count)\n\n"
        
        for (index, member) in allMembers.enumerated() {
            let isMe = member.profileId == currentUser.profileId
            let label = isMe ? "\(member.displayName) (YOU)" : member.displayName
            
            context += "--- \(label) ---\n"
            context += "Age: \(ageFromDOB(member.dob))\n"
            context += "Gender: \(member.gender.rawValue)\n"
            
            // Goals
            context += "Goals: Steps=\(member.stepGoal), Calories=\(member.caloriesGoal), Distance=\(member.distanceGoal)m, Sleep=\(member.sleepGoal)h\n"
            
            // Today's wellness score
            let wellnessScore = Int(member.calculateWellnessScore(for: today) * 100)
            context += "Today's Wellness Score: \(wellnessScore)%\n"
            
            // Today's activity data
            let todaySteps = activityValue(for: member.profileId, type: .steps, on: today, calendar: calendar)
            let todayCalories = activityValue(for: member.profileId, type: .calories, on: today, calendar: calendar)
            let todayDistance = activityValue(for: member.profileId, type: .distance, on: today, calendar: calendar)
            
            context += "Today: Steps=\(Int(todaySteps)), Calories=\(Int(todayCalories)), Distance=\(Int(todayDistance))m\n"
            
            // Today's sleep
            let todaySleep = sleepData(for: member.profileId, on: today, calendar: calendar)
            if let sleep = todaySleep {
                let hours = Int(sleep.totalSleep)
                let mins = Int((sleep.totalSleep - Double(hours)) * 60)
                context += "Last Night Sleep: \(hours)h \(mins)m (Deep: \(String(format: "%.1f", sleep.deepSleep))h, REM: \(String(format: "%.1f", sleep.remSleep))h, Light: \(String(format: "%.1f", sleep.lightSleep))h)\n"
            } else {
                context += "Last Night Sleep: No data\n"
            }
            
            // Today's vitals
            let heartRate = vitalsValue(for: member.profileId, type: .heartRate, on: today, calendar: calendar)
            let hrv = vitalsValue(for: member.profileId, type: .hrv, on: today, calendar: calendar)
            
            if let hr = heartRate {
                context += "Heart Rate: \(Int(hr)) BPM\n"
            }
            if let h = hrv {
                context += "HRV: \(Int(h)) ms\n"
            }
            
            // 7-day trends
            var weekSteps: [Double] = []
            var weekScores: [Int] = []
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                weekSteps.append(activityValue(for: member.profileId, type: .steps, on: date, calendar: calendar))
                weekScores.append(Int(member.calculateWellnessScore(for: date) * 100))
            }
            
            let avgWeekSteps = weekSteps.isEmpty ? 0 : Int(weekSteps.reduce(0, +) / Double(weekSteps.count))
            let avgWeekScore = weekScores.isEmpty ? 0 : weekScores.reduce(0, +) / weekScores.count
            
            context += "7-Day Avg: Steps=\(avgWeekSteps), Wellness=\(avgWeekScore)%\n"
            
            // Insight from existing engine
            let insight = InsightEngine.shared.generateInsight(for: member, isSelf: isMe)
            context += "Insight: \(insight.message)\n"
            
            context += "\n"
        }
        
        // Active challenges
        let activeChallenges = dm.challenges.filter { $0.status == "active" || $0.status == "pending" }
        if !activeChallenges.isEmpty {
            context += "--- ACTIVE CHALLENGES ---\n"
            for challenge in activeChallenges {
                let daysLeft = max(0, calendar.dateComponents([.day], from: today, to: challenge.endDate).day ?? 0)
                context += "• \(challenge.name) (\(challenge.type)/\(challenge.subType)) — \(daysLeft) days left\n"
                
                // Progress for each participant
                let progresses = dm.challengeProgress.filter { $0.challengeId == challenge.challengeId }
                for progress in progresses {
                    let memberName = allMembers.first(where: { $0.profileId == progress.memberId })?.displayName ?? "Unknown"
                    let pct = progress.goalValue > 0 ? Int((progress.currentValue / progress.goalValue) * 100) : 0
                    context += "  - \(memberName): \(pct)% (\(Int(progress.currentValue))/\(Int(progress.goalValue)))\n"
                }
            }
            context += "\n"
        }
        
        context += "=== END DATA SNAPSHOT ===\n"
        context += "Note: This is general wellness information, not medical advice."
        
        return context
    }
    
    // MARK: - Private Helpers
    
    private static func activityValue(for profileId: UUID, type: ActivityType, on date: Date, calendar: Calendar) -> Double {
        let dm = DataManager.shared
        return dm.allActivityDaily.first { item in
            calendar.isDate(item.date, inSameDayAs: date) && item.profileId == profileId && item.type == type
        }?.value ?? 0
    }
    
    private static func sleepData(for profileId: UUID, on date: Date, calendar: Calendar) -> SleepDaily? {
        let dm = DataManager.shared
        // Sleep for "today" is typically recorded for the previous night
        // Check both today and yesterday
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        return dm.allSleepDaily.first { item in
            (calendar.isDate(item.date, inSameDayAs: date) || calendar.isDate(item.date, inSameDayAs: yesterday))
            && item.profileId == profileId
        }
    }
    
    private static func vitalsValue(for profileId: UUID, type: VitalType, on date: Date, calendar: Calendar) -> Double? {
        let dm = DataManager.shared
        let vital = dm.allVitalsDaily.first { item in
            calendar.isDate(item.date, inSameDayAs: date) && item.profileId == profileId && item.type == type
        }
        return vital?.avgValue
    }
    
    private static func ageFromDOB(_ dob: Date) -> Int {
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
    }
    
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
