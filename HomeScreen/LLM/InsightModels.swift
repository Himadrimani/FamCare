/*
 InsightModels.swift
 Defines the "Language" of the Insight system so all data follows the same rules.
*/

import Foundation
import UIKit

// This tells the app if we are looking at data for Today, a Week, or a Month
enum TimeFilter: Int {
    case today = 0
    case week = 1
    case month = 2
}

// Key settings that the entire engine uses to decide if someone is doing "good" or "bad".

//
// This is the SINGLE source of truth for every wellness/insight threshold in the app.
// Do not hardcode these numbers anywhere else — read them from here so the daily card,
// the weekly/monthly insights, the notification rules and the score all stay consistent.
struct StandardInsightConfig {

    // MARK: Score thresholds (all on a 0.0–1.0 scale)

    /// Below this a single day's wellness is considered "needs a boost" (daily card).
    static let wellnessThreshold: Double = 0.7

    /// Below this a member is considered to be "lagging" over a week/month, and the
    /// overall family is nudged toward a challenge.
    static let laggingThreshold: Double = 0.75

    /// Below this we raise a low-wellness performance notification for a member.
    static let lowWellnessNotificationThreshold: Double = 0.6

    /// Average (steps / stepGoal) below this over a period counts as "lagging in steps".
    static let stepLagThreshold: Double = 0.7

    // MARK: Data completeness

    /// Fraction of the total scoring weight that must have real data before we treat a
    /// wellness score as trustworthy. Below this we show an "insufficient data" state
    /// instead of a misleading low percentage. (0.0–1.0)
    static let minimumDataCompleteness: Double = 0.4

    // MARK: Metric-specific rule thresholds

    /// Nightly sleep (hours) below which we flag "short sleep".
    static let shortSleepHours: Double = 6.5

    // MARK: Medical-safety framing (#10)

    /// Shown wherever wellness insights are presented. FamCare insights are
    /// general wellness guidance, not medical advice.
    static let medicalDisclaimer =
        "FamCare insights are general wellness guidance based on your activity data — not medical advice. For any health concern, talk to a qualified professional."
}

// This is the final package of text and buttons that the user sees on their screen
struct AIInsight {
    let title: String
    let message: String
    let suggestion: String
    let showChallengeButton: Bool
    let challengeType: String
    let targetProfile: Profile?
}


// Helps the UI draw the lines and bars in the charts
struct FamilyMemberScores {
    var profile: String
    var scoreWeekly: [Int]
    var scoreMonthly: [Int]
}

extension FamilyMemberScores {
    // This function converts a User Profile into a Score object for the UI
    static func from(profile: Profile) -> FamilyMemberScores {
        // Get the name to display via the central resolver
        // (viewer nickname → profile nickname → firstName; never the legacy "Me").
        let name = profile.displayName

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date()) // Get the start of today
        let weekday = calendar.component(.weekday, from: today) // Get today's day of week
        let daysFromSunday = weekday - 1 // Calculate how many days since Sunday
        
        // Find the date of the most recent Sunday
        guard let weekStart = calendar.date(byAdding: .day, value: -daysFromSunday, to: today) else {
            // If date math fails, return empty scores
            return FamilyMemberScores(profile: name, scoreWeekly: Array(repeating: 0, count: 7), scoreMonthly: Array(repeating: 0, count: 31))
        }

        // Loop 7 times to get wellness scores for every day this week
        let weeklyScores: [Int] = (0..<7).map { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return 0 }
            guard date <= today else { return 0 }
            return wellnessScore(for: profile, on: date, calendar: calendar) // Calculate daily score
        }

        // Get start of current month
        guard let monthRange = calendar.range(of: .day, in: .month, for: today),
              let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else {
            return FamilyMemberScores(profile: name, scoreWeekly: weeklyScores, scoreMonthly: Array(repeating: 0, count: 31))
        }
        
        let numDaysInMonth = monthRange.count
        let monthlyScores: [Int] = (0..<numDaysInMonth).map { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: monthStart) else { return 0 }
            if date > today {
                return -1 // Special value for 'No Data/Future'
            }
            return wellnessScore(for: profile, on: date, calendar: calendar)
        }

        // Return the final score package to the UI
        return FamilyMemberScores(profile: name, scoreWeekly: weeklyScores, scoreMonthly: monthlyScores)
    }

    // Small helper to turn 0.0-1.0 score into a 0-100 integer for the graph
    private static func wellnessScore(for profile: Profile, on date: Date, calendar: Calendar) -> Int {
        return Int(profile.calculateWellnessScore(for: date) * 100.0) // Multiply by 100
    }
}
