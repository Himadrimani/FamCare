//
//  ChallengeActivityAttributes.swift
//  HomeScreen
//
//  ActivityKit attributes and content state for the Challenge Progress
//  Live Activity that appears on the Lock Screen and Dynamic Island.
//

import Foundation
import ActivityKit

struct ChallengeActivityAttributes: ActivityAttributes {
    
    // Fixed data that doesn't change during the Live Activity lifetime
    public let challengeId: String
    public let challengeName: String
    public let challengeType: String       // e.g. "steps", "calories", "distance"
    public let endDate: Date
    
    // Dynamic data that updates as challenge progress changes
    public struct ContentState: Codable, Hashable {
        let members: [MemberProgress]
        let lastUpdated: Date
    }
    
    struct MemberProgress: Codable, Hashable {
        let profileId: String
        let displayName: String
        let goalValue: Double
        let currentValue: Double
    }
}
