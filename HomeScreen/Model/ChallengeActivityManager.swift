//
//  ChallengeActivityManager.swift
//  HomeScreen
//
//  Manages starting, updating, and ending Live Activities
//  for family challenge progress on the Lock Screen.
//

import Foundation
import ActivityKit
import UIKit

@available(iOS 16.2, *)
final class ChallengeActivityManager {
    static let shared = ChallengeActivityManager()
    
    private init() {
        // Listen for data updates to refresh the Live Activity
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DataManagerDidUpdate"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateLiveActivities()
        }
    }
    
    // MARK: - Start a Live Activity for a challenge
    
    /// Starts a Live Activity for the given active challenge.
    /// Call this when a challenge becomes active or the user opens the app.
    func startLiveActivity(for challenge: ChallengeDetails) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("ChallengeActivityManager: Live Activities are not enabled.")
            return
        }
        
        // Don't start duplicates
        let existing = Activity<ChallengeActivityAttributes>.activities
        if existing.contains(where: { $0.attributes.challengeId == challenge.challengeId.uuidString }) {
            print("ChallengeActivityManager: Activity already running for \(challenge.name)")
            updateLiveActivities()
            return
        }
        
        let dm = DataManager.shared
        let progressItems = dm.challengeProgress.filter { $0.challengeId == challenge.challengeId }
        let allProfiles = ([dm.currentUser].compactMap { $0 }) + dm.allProfiles
        
        let memberProgresses = progressItems.compactMap { progress -> ChallengeActivityAttributes.MemberProgress? in
            guard let profile = allProfiles.first(where: { $0.profileId == progress.memberId }) else {
                return nil
            }
            return ChallengeActivityAttributes.MemberProgress(
                profileId: profile.profileId.uuidString,
                displayName: profile.displayName,
                goalValue: progress.goalValue,
                currentValue: progress.currentValue
            )
        }
        
        let attributes = ChallengeActivityAttributes(
            challengeId: challenge.challengeId.uuidString,
            challengeName: challenge.name,
            challengeType: challenge.subType,
            endDate: challenge.endDate
        )
        
        let state = ChallengeActivityAttributes.ContentState(
            members: memberProgresses,
            lastUpdated: Date()
        )
        
        let content = ActivityContent(state: state, staleDate: Calendar.current.date(byAdding: .hour, value: 1, to: Date()))
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            print("ChallengeActivityManager: Started Live Activity '\(activity.id)' for '\(challenge.name)'")
        } catch {
            print("ChallengeActivityManager: Failed to start Live Activity: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Update all running Live Activities
    
    func updateLiveActivities() {
        let dm = DataManager.shared
        let allProfiles = ([dm.currentUser].compactMap { $0 }) + dm.allProfiles
        
        for activity in Activity<ChallengeActivityAttributes>.activities {
            guard let challengeId = UUID(uuidString: activity.attributes.challengeId) else { continue }
            
            let progressItems = dm.challengeProgress.filter { $0.challengeId == challengeId }
            
            let memberProgresses = progressItems.compactMap { progress -> ChallengeActivityAttributes.MemberProgress? in
                guard let profile = allProfiles.first(where: { $0.profileId == progress.memberId }) else {
                    return nil
                }
                return ChallengeActivityAttributes.MemberProgress(
                    profileId: profile.profileId.uuidString,
                    displayName: profile.displayName,
                    goalValue: progress.goalValue,
                    currentValue: progress.currentValue
                )
            }
            
            let state = ChallengeActivityAttributes.ContentState(
                members: memberProgresses,
                lastUpdated: Date()
            )
            
            let content = ActivityContent(state: state, staleDate: Calendar.current.date(byAdding: .hour, value: 1, to: Date()))
            
            Task {
                await activity.update(content)
            }
        }
    }
    
    // MARK: - End Live Activity for a challenge
    
    func endLiveActivity(for challengeId: UUID) {
        for activity in Activity<ChallengeActivityAttributes>.activities {
            if activity.attributes.challengeId == challengeId.uuidString {
                Task {
                    await activity.end(nil, dismissalPolicy: .immediate)
                    print("ChallengeActivityManager: Ended Live Activity for challenge \(challengeId)")
                }
            }
        }
    }
    
    // MARK: - Auto-start for active challenges
    
    /// Call this on app launch to auto-start Live Activities for any active challenges.
    func startActivitiesForActiveChallenges() {
        let dm = DataManager.shared
        let activeChallenges = dm.challenges.filter { $0.status == "active" && $0.endDate > Date() }
        
        for challenge in activeChallenges {
            startLiveActivity(for: challenge)
        }
    }
}
