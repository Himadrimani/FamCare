/*
  InsightEngine.swift
  This is the "Brain" of the app. It looks at family health data and decides what advice to give.
  
  FLOW:
  Raw Health Data -> Check Thresholds -> Pick Motivational Text -> Create Insight
*/

import Foundation
import UIKit
//Standard Rule-Based Insight Engine
//This system uses deterministic logic based on health metrics and wellness scores.
class InsightEngine {
    static let shared = InsightEngine() // Makes this accessible from anywhere in the app
    private let calendar = Calendar.current // Used for date calculations
    
    // MARK: - Weekly Insight Logic
    func generateWeeklyTopInsight(completed: @escaping (AIInsight?) -> Void) {
        //Get the current user
        guard let currentUser = DataManager.shared.currentUser else { completed(nil); return }
        
        //  Get all other family members (strictly excluding current user)
        let otherMembers = DataManager.shared.allProfiles.filter { $0.profileId != currentUser.profileId }
        let now = Date() // Current time
        
        // Variables to track who is struggling
        var laggingMember: Profile? // The person with the lowest score
        var lowestScore: Double = 1.0 // Start with high score to find the lowest
        
        // Loop through family to find who needs help
        for member in otherMembers {
            let avgScore = getAverageWellnessScore(for: member, daysBack: 7, from: now) // Get 7-day average
            if avgScore > 0 && avgScore < StandardInsightConfig.laggingThreshold && avgScore < lowestScore {
                lowestScore = avgScore // Update with new lowest
                laggingMember = member // Identify the lagging person
            }
        }
        
        // Get overall family average
        let familyAvg = getFamilyAverage(daysBack: 7, from: now)
        let seed = Int(familyAvg * 100) // stable seed for deterministic wording
        var message = "" // Single paragraph shown in top insight card
        let suggestion = "" // Kept empty for weekly/monthly top insight
        var showButton = false // Should we show the challenge button?
        var targetProfile = currentUser // Default target is the user
        
        // Decide what to say based on data
        if familyAvg >= StandardInsightConfig.laggingThreshold {
            // Achievement insight only when overall score is healthy.
            message = "\(getMotivation(isSuccess: true, seed: seed)) Family wellness score is \(Int(familyAvg * 100))% this week."
            showButton = false
        } else {
            let intro = getMotivation(isSuccess: false, seed: seed)
            message = "\(intro) Family wellness score is \(Int(familyAvg * 100))% this week."
            
            if let lagging = laggingMember {
                let name = lagging.displayName
                if getIsLaggingInSteps(for: lagging, daysBack: 7, from: now) {
                    message += " \(name) is lagging behind in steps, so start a family challenge."
                } else {
                    message += " \(name) is lagging behind this week, so start a family challenge."
                }
                showButton = true
                targetProfile = lagging
            } else {
                message += " Start a family challenge to improve consistency."
                showButton = true
            }
        }
        
        // Step 7: Send the completed insight back to the UI
        completed(AIInsight(
            title: "Weekly Insight",
            message: message,
            suggestion: suggestion,
            showChallengeButton: showButton,
            challengeType: "steps",
            targetProfile: targetProfile
        ))
    }
    
    // MARK: - Monthly Insight Logic
    func generateMonthlyTopInsight(completed: @escaping (AIInsight?) -> Void) {
        // Get user and family list
        guard let currentUser = DataManager.shared.currentUser else { completed(nil); return }
        let otherMembers = DataManager.shared.allProfiles.filter { $0.profileId != currentUser.profileId }
        let now = Date()
        
        //Track lagging members over last 30 days
        var laggingMember: Profile?
        var lowestScore: Double = 1.0
        
        // Loop through family for monthly data
        for member in otherMembers {
            let avgScore = getAverageWellnessScore(for: member, daysBack: 30, from: now) // Get 30-day average
            if avgScore > 0 && avgScore < StandardInsightConfig.laggingThreshold && avgScore < lowestScore {
                lowestScore = avgScore
                laggingMember = member
            }
        }
        
        // Family stats and message building
        let familyAvg = getFamilyAverage(daysBack: 30, from: now)
        let seed = Int(familyAvg * 100) // stable seed for deterministic wording
        var message = "" // Single paragraph shown in top insight card
        let suggestion = "" // Kept empty for weekly/monthly top insight
        var showButton = false
        var targetProfile = currentUser
        
        if familyAvg >= StandardInsightConfig.laggingThreshold {
            // Achievement insight only when overall score is healthy.
            message = "\(getMotivation(isSuccess: true, seed: seed)) Family wellness score is \(Int(familyAvg * 100))% this month."
            showButton = false
        } else {
            let intro = getMotivation(isSuccess: false, seed: seed)
            message = "\(intro) Family wellness score is \(Int(familyAvg * 100))% this month."
            
            if let lagging = laggingMember {
                let name = lagging.displayName
                if getIsLaggingInSteps(for: lagging, daysBack: 30, from: now) {
                    message += " \(name) is lagging behind in steps, so start a family challenge."
                } else {
                    message += " \(name) is lagging behind this month, so start a family challenge."
                }
                showButton = true
                targetProfile = lagging
            } else {
                message += " Start a family challenge to improve consistency."
                showButton = true
            }
        }
        
        // Step 6: Return final result
        completed(AIInsight(
            title: "Monthly Insight",
            message: message,
            suggestion: suggestion,
            showChallengeButton: showButton,
            challengeType: "steps",
            targetProfile: targetProfile
        ))
    }
    
    // MARK: - Individual Daily Insight (Home Screen Card)
    func generateInsight(for profile: Profile, isSelf: Bool) -> AIInsight {
        // Full evaluation: score PLUS how complete today's data is (#1, #2).
        let result = profile.wellnessResult(for: Date())
        let wellnessScore = result.score
        // Decide if we use "Your" or "Name's"
        let name = isSelf ? "Your" : profile.displayName + "'s"
        let subject = isSelf ? "your" : profile.displayName + "'s"
        
        var message = ""
        let suggestion = ""
        var showButton = false
        
        if !result.hasAnyData {
            // No health data at all for today.
            message = isSelf
                ? "No health data synced for today yet. Connect Apple Health to see your daily insights."
                : "No health data synced for \(profile.displayName) today yet."
            showButton = false
        } else if !result.hasSufficientData {
            // Some data, but not enough to score confidently — don't show a misleading %.
            message = "We need a bit more of \(subject) health data today before showing a wellness score. Keep Apple Health syncing."
            showButton = false
        } else if wellnessScore < StandardInsightConfig.wellnessThreshold {
            message = "\(name) wellness score is at \(Int(wellnessScore * 100))%. Looking for a boost to hit the daily target."
            showButton = true // Suggest a challenge if score is low
        } else {
            message = "\(name) wellness is performing well at \(Int(wellnessScore * 100))% today."
            showButton = false // No nudge needed if performing well
        }
        
        // Create the UI object
        return AIInsight(
            title: "Daily Insight",
            message: message,
            suggestion: suggestion,
            showChallengeButton: showButton,
            challengeType: "steps",
            targetProfile: profile
        )
    }
    
    // MARK: - Period Comparison (used by weekly/monthly performance cards)
    /// Returns values like: "↑ 17%" / "↓ 9%" based on real historical wellness data.
    /// - Weekly: compares current week-to-date against previous week same number of days.
    /// - Monthly: compares current month-to-date against previous month same number of days.
    func comparisonText(for profile: Profile, isWeek: Bool, referenceDate: Date = Date()) -> String {
        // Returns "—" when there is no real previous-period baseline, instead of
        // fabricating a positive trend (#6).
        guard let diff = periodChangePercent(for: profile, isWeek: isWeek, referenceDate: referenceDate) else {
            return "—"
        }
        return diff >= 0 ? "↑ \(diff)%" : "↓ \(abs(diff))%"
    }

    // MARK: - Detail Insight (Specific advice for Charts)
    func generateDetailInsight(type: InsightType, value: Double, goal: Double, profile: Profile, filter: TimeFilter = .today) -> String {
        // Check if goal is met
        let isGoalMet = value >= goal
        //Set the time period label
        let periodName = filter == .today ? "today" : (filter == .week ? "this week" : "this month")
        
        // Pick message based on data type (Steps, Sleep, etc.)
        if value == 0 {
            return "No data recorded \(periodName)."
        }
        
        switch type {
        case .steps:
            return isGoalMet ? 
                "Stride goal achieved! You've maintained an excellent pace \(periodName)." :
                "You're slightly behind on steps \(periodName). Just \(Int(max(0, goal - value))) more to hit the target."
        case .sleep:
            // For week/month `value` is the AVERAGE sleep per night (#11), so phrase it that way.
            let h = Int(value), m = Int((value - Double(h)) * 60) // hours and minutes
            let amount = "\(h)h \(m)m"
            let perNight = filter == .today ? "" : " per night"
            let base = isGoalMet ?
                "Well rested — \(amount)\(perNight) \(periodName). That gives your body good recovery time." :
                "\(amount)\(perNight) \(periodName). Aim for your sleep goal to support recovery and focus."
            
            return base + "\n\nREM sleep supports memory and mood, deep sleep aids physical recovery, and light (core) sleep bridges these stages."
        case .calories:
            return isGoalMet ?
                "Calorie target reached \(periodName). Nice, steady activity." :
                "Activity is slightly below target \(periodName). Every extra active calorie helps."
        case .heartRate:
            // Non-diagnostic wording (#10). We describe the number, not a medical conclusion.
            return filter == .today ? 
                "Your heart rate is around \(Int(value)) BPM today. This is general wellness information, not a medical measurement." :
                "Your heart rate averaged \(Int(value)) BPM \(periodName). This is general wellness information, not a medical assessment."
        case .hrv:
            return "Your Heart Rate Variability is about \(Int(value)) ms \(periodName). HRV is generally associated with recovery and stress resilience; it is not a medical diagnosis."
        case .distance:
            let displayVal = value / 1000.0 // Convert meters to KM
            return isGoalMet ?
                "Great endurance! You covered \(String(format: "%.1f", displayVal)) KM \(periodName)." :
                "You've covered \(String(format: "%.1f", displayVal)) KM \(periodName). Keep moving to reach your goal."
        }
    }
    
    // MARK: - Private Calculation Helpers
    /// Returns the bounded percentage change vs the previous period, or `nil` when there is
    /// no usable previous-period baseline (so callers can show "—" rather than a fake trend).
    private func periodChangePercent(for profile: Profile, isWeek: Bool, referenceDate: Date) -> Int? {
        let today = calendar.startOfDay(for: referenceDate)
        let (currentAvg, previousAvg): (Double, Double)
        
        if isWeek {
            // Sunday = 1 ... Saturday = 7
            let weekday = calendar.component(.weekday, from: today)
            let daysElapsed = max(weekday, 1)
            
            guard let thisWeekStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: today),
                  let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: thisWeekStart) else {
                return nil
            }
            
            currentAvg = averageWellnessScore(for: profile, startDate: thisWeekStart, dayCount: daysElapsed)
            previousAvg = averageWellnessScore(for: profile, startDate: previousWeekStart, dayCount: daysElapsed)
        } else {
            guard let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                  let lastDayPreviousMonth = calendar.date(byAdding: .day, value: -1, to: thisMonthStart),
                  let previousMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: lastDayPreviousMonth)),
                  let previousMonthRange = calendar.range(of: .day, in: .month, for: previousMonthStart) else {
                return nil
            }
            
            let dayOfMonth = calendar.component(.day, from: today)
            let compareDays = max(1, min(dayOfMonth, previousMonthRange.count))
            
            currentAvg = averageWellnessScore(for: profile, startDate: thisMonthStart, dayCount: compareDays)
            previousAvg = averageWellnessScore(for: profile, startDate: previousMonthStart, dayCount: compareDays)
        }
        
        // No reliable previous-period baseline → return nil so the UI shows "—" instead of a
        // fabricated trend (#6).
        if previousAvg <= 0 {
            return nil
        }
        
        let raw = ((currentAvg - previousAvg) / previousAvg) * 100.0
        return normalizedChangePercent(from: raw)
    }
    
    private func averageWellnessScore(for profile: Profile, startDate: Date, dayCount: Int) -> Double {
        guard dayCount > 0 else { return 0 }
        
        let scores: [Double] = (0..<dayCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            return Double(profile.calculateWellnessScore(for: date) * 100.0)
        }
        
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }
    
    /// Converts any raw percentage change into a stable display range of -10...10.
    private func normalizedChangePercent(from rawPercent: Double) -> Int {
        let magnitude = abs(rawPercent)
        if magnitude < 0.5 { return 0 } // treat very small noise as flat
        
        let boundedMagnitude = max(1, min(10, Int(magnitude.rounded())))
        return rawPercent < 0 ? -boundedMagnitude : boundedMagnitude
    }

    // Gets average wellness for a profile over X days
    private func getAverageWellnessScore(for profile: Profile, daysBack: Int, from date: Date) -> Double {
        let scores: [Double] = (0..<daysBack).compactMap { offset -> Double? in
            guard let d = calendar.date(byAdding: .day, value: -offset, to: date) else { return nil }
            return Double(profile.calculateWellnessScore(for: d))
        }
        return scores.reduce(0, +) / Double(max(scores.count, 1)) // Total / count = Average
    }
    
    // Specifically checks if a member is missing Step Goals
    private func getIsLaggingInSteps(for profile: Profile, daysBack: Int, from date: Date) -> Bool {
        let scores: [Double] = (0..<daysBack).compactMap { offset -> Double? in
            guard let d = calendar.date(byAdding: .day, value: -offset, to: date) else { return nil }
            
            // Find step activity for the specific day and person
            let activity = DataManager.shared.allActivityDaily.first { item in
                let isSameDay = calendar.isDate(item.date, inSameDayAs: d)
                let isSameProfile = item.profileId == profile.profileId
                let isSteps = item.type == .steps
                return isSameDay && isSameProfile && isSteps
            }
            
            // calculate % of goal reached
            guard let stepsValue = activity?.value, 
                  let goal = profile.stepGoal as Int?, 
                  goal > 0 else { return nil }
            
            return stepsValue / Double(goal)
        }
        if scores.isEmpty { return false }
        let avg = scores.reduce(0, +) / Double(scores.count)
        return avg < StandardInsightConfig.stepLagThreshold // Is average steps below threshold?
    }
    
    // Gets the combined average for the entire family
    private func getFamilyAverage(daysBack: Int, from date: Date) -> Double {
        let currentUser = DataManager.shared.currentUser
        var members = DataManager.shared.allProfiles
        if let user = currentUser {
            members.insert(user, at: 0) // Include the main user in family stats
        }
        
        let activeMembers = members.filter { getAverageWellnessScore(for: $0, daysBack: daysBack, from: date) > 0.0 }
        let validMembers = activeMembers.isEmpty ? members : activeMembers
        
        let total = validMembers.reduce(0.0) { $0 + getAverageWellnessScore(for: $1, daysBack: daysBack, from: date) }
        return total / Double(max(validMembers.count, 1)) // Total / family size = Family Average
    }
    
    // Picks a motivational sentence DETERMINISTICALLY from a stable seed (#15). The same
    // underlying data always yields the same wording, so the insight text stops changing on
    // every reload while still varying as the family's score changes.
    private func getMotivation(isSuccess: Bool, seed: Int) -> String {
        let successLines = [
            "Brilliant coordination from everyone!",
            "Keep up this rhythm!",
            "Outstanding family effort!",
            "The energy is great!"
        ]
        let struggleLines = [
            "Let's move closer together.",
            "Stronger as a family.",
            "Focus on the goal.",
            "Push through the dip."
        ]
        let lines = isSuccess ? successLines : struggleLines
        let index = abs(seed) % lines.count
        return lines[index]
    }
}
