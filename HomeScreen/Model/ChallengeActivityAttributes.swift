//
//  ChallengeActivityAttributes.swift
//  HomeScreen
//
//  ActivityKit attributes and content state for the Challenge
//  Live Activity that appears on the Lock Screen.
//

import Foundation
import ActivityKit

struct ChallengeActivityAttributes: ActivityAttributes {
    
    // Stable attributes for the Live Activity
    public let challengeId: String
    public let userProfileId: String
    public let userDisplayName: String
    
    // Lightweight member avatar representation for Live Activity Lock Screen & Dynamic Island
    public struct FamilyMemberAvatar: Codable, Hashable, Sendable {
        public let profileId: String
        public let displayName: String
        public let isCompleted: Bool
        public let isLastCompleter: Bool
        
        public init(profileId: String, displayName: String, isCompleted: Bool = false, isLastCompleter: Bool = false) {
            self.profileId = profileId
            self.displayName = displayName
            self.isCompleted = isCompleted
            self.isLastCompleter = isLastCompleter
        }
        
        enum CodingKeys: String, CodingKey {
            case profileId
            case displayName
            case isCompleted
            case isLastCompleter
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.profileId = try container.decode(String.self, forKey: .profileId)
            self.displayName = try container.decode(String.self, forKey: .displayName)
            self.isCompleted = (try? container.decodeIfPresent(Bool.self, forKey: .isCompleted)) ?? false
            self.isLastCompleter = (try? container.decodeIfPresent(Bool.self, forKey: .isLastCompleter)) ?? false
        }
    }
    
    // Dynamic data that updates as challenge state changes
    public struct ContentState: Codable, Hashable, Sendable {
        public let challengeName: String
        public let familyMembers: [FamilyMemberAvatar]
        public let isUserCompleted: Bool
        public let isFamilyCompleted: Bool
        public let progressFraction: Double
        public let completedMembersCount: Int
        public let totalMembersCount: Int
        public let timeRemainingText: String
        public let lastUpdated: Date
        
        public init(
            challengeName: String,
            familyMembers: [FamilyMemberAvatar] = [],
            isUserCompleted: Bool = false,
            isFamilyCompleted: Bool = false,
            progressFraction: Double = 0.0,
            completedMembersCount: Int = 0,
            totalMembersCount: Int = 0,
            timeRemainingText: String = "",
            lastUpdated: Date = Date()
        ) {
            self.challengeName = challengeName
            self.familyMembers = familyMembers
            self.isUserCompleted = isUserCompleted
            self.isFamilyCompleted = isFamilyCompleted
            self.progressFraction = progressFraction
            self.completedMembersCount = completedMembersCount
            self.totalMembersCount = totalMembersCount
            self.timeRemainingText = timeRemainingText
            self.lastUpdated = lastUpdated
        }
        
        enum CodingKeys: String, CodingKey {
            case challengeName
            case familyMembers
            case isUserCompleted
            case isFamilyCompleted
            case progressFraction
            case completedMembersCount
            case totalMembersCount
            case timeRemainingText
            case lastUpdated
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.challengeName = try container.decode(String.self, forKey: .challengeName)
            self.familyMembers = (try? container.decodeIfPresent([FamilyMemberAvatar].self, forKey: .familyMembers)) ?? []
            self.isUserCompleted = (try? container.decodeIfPresent(Bool.self, forKey: .isUserCompleted)) ?? false
            self.isFamilyCompleted = (try? container.decodeIfPresent(Bool.self, forKey: .isFamilyCompleted)) ?? false
            self.progressFraction = (try? container.decodeIfPresent(Double.self, forKey: .progressFraction)) ?? 0.0
            self.completedMembersCount = (try? container.decodeIfPresent(Int.self, forKey: .completedMembersCount)) ?? 0
            self.totalMembersCount = (try? container.decodeIfPresent(Int.self, forKey: .totalMembersCount)) ?? 0
            self.timeRemainingText = (try? container.decodeIfPresent(String.self, forKey: .timeRemainingText)) ?? ""
            self.lastUpdated = (try? container.decodeIfPresent(Date.self, forKey: .lastUpdated)) ?? Date()
        }
    }
    
    public init(challengeId: String, userProfileId: String = "", userDisplayName: String = "") {
        self.challengeId = challengeId
        self.userProfileId = userProfileId
        self.userDisplayName = userDisplayName
    }
}
