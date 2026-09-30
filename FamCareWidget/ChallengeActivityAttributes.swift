//
//  ChallengeActivityAttributes.swift
//  FamCareWidgetExtension
//
//  Duplicate of the main app's attributes file.
//  Both targets must have an identical copy of this struct.
//

import Foundation
import ActivityKit

struct ChallengeActivityAttributes: ActivityAttributes {
    
    public let challengeId: String
    public let challengeName: String
    public let challengeType: String
    public let endDate: Date
    
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
