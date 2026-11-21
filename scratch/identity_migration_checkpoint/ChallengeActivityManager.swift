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
@MainActor
final class ChallengeActivityManager {
    static let shared = ChallengeActivityManager()
    
    private init() {
        // Listen for data updates to reconcile the Live Activity
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DataManagerDidUpdate"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reconcileLiveActivity()
        }
        
        // Listen for user logout to immediately terminate all running activities
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserDidLogOut"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.endAllActivities()
        }
    }
    
    // MARK: - Challenge Selection
    
    /// Returns all challenges that belong to the current user's family and are genuinely ongoing.
    func findOngoingChallenges() -> [ChallengeDetails] {
        let dm = DataManager.shared
        guard let currentUser = dm.currentUser else { return [] }
        
        let now = Date()
        let allProgress = dm.challengeProgress
        
        let ongoingChallenges = dm.challenges.filter { challenge in
            // 1. Must belong to the current user's family
            guard challenge.familyId == currentUser.familyId else { return false }
            
            // 2. Status flag must be "ongoing" (FamCare's real status for active challenges)
            guard challenge.status == "ongoing" else { return false }
            
            // 3. Must not be expired
            guard challenge.endDate > now else { return false }
            
            // 4. Must not have already met all completion criteria (from divideChallenges rule)
            let relatedProgress = allProgress.filter { $0.challengeId == challenge.challengeId }
            let isGoalMet = !relatedProgress.isEmpty && relatedProgress.allSatisfy { $0.currentValue >= $0.goalValue && $0.goalValue > 0 }
            if isGoalMet {
                return false
            }
            
            return true
        }
        
        // Sort by startDate descending (most recently created), using array index as secondary tie-breaker
        return ongoingChallenges.sorted { c1, c2 in
            if c1.startDate != c2.startDate {
                return c1.startDate > c2.startDate
            }
            let idx1 = dm.challenges.firstIndex(of: c1) ?? 0
            let idx2 = dm.challenges.firstIndex(of: c2) ?? 0
            return idx1 > idx2
        }
    }
    
    /// Selects the single most recently created challenge that is still genuinely ongoing (backward-compatibility).
    func findMostRecentOngoingChallenge() -> ChallengeDetails? {
        findOngoingChallenges().first
    }
    
    // MARK: - Profile Image & Logo Sharing
    
    private func ensureFamilyAvatarsCached(profiles: [Profile]) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.naman9045.famcare"
        ) else { return }
        
        let widgetImagesDir = containerURL.appendingPathComponent("WidgetProfileImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: widgetImagesDir, withIntermediateDirectories: true)
        
        // 1. Cache downscaled FamCare app logo (156x156 px = 52pt @ 3x) for the Live Activity header
        let logoFile = widgetImagesDir.appendingPathComponent("famcare_logo.png")
        if let rawLogo = UIImage(named: "LaunchAppIcon") ?? UIImage(named: "AppIcon") {
            let targetLogoSize = CGSize(width: 156, height: 156)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            let renderer = UIGraphicsImageRenderer(size: targetLogoSize, format: format)
            let downscaledLogo = renderer.image { _ in
                rawLogo.draw(in: CGRect(origin: .zero, size: targetLogoSize))
            }
            if let pngData = downscaledLogo.pngData() {
                try? pngData.write(to: logoFile, options: .atomic)
            }
        }
        
        // 2. Cache downscaled profile avatars (120x120 px = 40pt @ 3x) for all family members
        for profile in profiles {
            let destFile = widgetImagesDir.appendingPathComponent("\(profile.profileId.uuidString).jpg")
            
            var sourceImage: UIImage? = ImageManager.shared.resolveImageForMigration(path: profile.profilePic)
            if sourceImage == nil && !profile.profilePic.isEmpty {
                sourceImage = UIImage(named: profile.profilePic)
            }
            
            if let image = sourceImage {
                let targetSize = CGSize(width: 120, height: 120)
                let format = UIGraphicsImageRendererFormat()
                format.scale = 1.0
                let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
                let downscaled = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: targetSize))
                }
                if let jpegData = downscaled.jpegData(compressionQuality: 0.8) {
                    try? jpegData.write(to: destFile, options: .atomic)
                }
            } else if profile.profilePic.starts(with: "http"), let url = URL(string: profile.profilePic) {
                // If remote photo, download, downscale to thumbnail, and trigger refresh
                URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                    guard let data = data, let downloadedImage = UIImage(data: data) else { return }
                    let targetSize = CGSize(width: 120, height: 120)
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 1.0
                    let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
                    let downscaled = renderer.image { _ in
                        downloadedImage.draw(in: CGRect(origin: .zero, size: targetSize))
                    }
                    if let jpegData = downscaled.jpegData(compressionQuality: 0.8) {
                        try? jpegData.write(to: destFile, options: .atomic)
                        DispatchQueue.main.async {
                            self?.reconcileLiveActivity()
                        }
                    }
                }.resume()
            }
        }
        
        // 3. Render original transparent trophy and shield stickers to App Group container for WidgetKit
        let trophyGoldFile = widgetImagesDir.appendingPathComponent("trophy_gold.png")
        let trophyDimmedFile = widgetImagesDir.appendingPathComponent("trophy_dimmed.png")
        let shieldFile = widgetImagesDir.appendingPathComponent("shield.png")
        
        let targetIconSize = CGSize(width: 96, height: 96)
        let iconFormat = UIGraphicsImageRendererFormat()
        iconFormat.scale = 1.0
        iconFormat.opaque = false
        let iconRenderer = UIGraphicsImageRenderer(size: targetIconSize, format: iconFormat)
        
        if let rawTrophy = UIImage(named: "trophy_button_image") {
            let croppedTrophy = rawTrophy.trimmingTransparentPixels()
            let trophyImage = iconRenderer.image { _ in
                croppedTrophy.draw(in: CGRect(origin: .zero, size: targetIconSize))
            }
            if let trophyData = trophyImage.pngData() {
                try? trophyData.write(to: trophyGoldFile, options: .atomic)
            }
        }
        
        if let rawGrey = UIImage(named: "grey_trophy") {
            let croppedGrey = rawGrey.trimmingTransparentPixels()
            let greyImage = iconRenderer.image { _ in
                croppedGrey.draw(in: CGRect(origin: .zero, size: targetIconSize))
            }
            if let greyData = greyImage.pngData() {
                try? greyData.write(to: trophyDimmedFile, options: .atomic)
            }
        }
        
        if let rawShield = UIImage(named: "shield_sticker") {
            let croppedShield = rawShield.trimmingTransparentPixels()
            let shieldImage = iconRenderer.image { _ in
                croppedShield.draw(in: CGRect(origin: .zero, size: targetIconSize))
            }
            if let shieldData = shieldImage.pngData() {
                try? shieldData.write(to: shieldFile, options: .atomic)
            }
        }
    }
    
    // MARK: - Reconcile Live Activities
    
    /// Reconciles system Live Activities with current app data.
    /// Ensures every ongoing challenge has its own active Live Activity.
    func reconcileLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("ChallengeActivityManager: Live Activities are not enabled.")
            return
        }
        
        guard let currentUser = DataManager.shared.currentUser else {
            // No user signed in: dismiss all activities
            endAllActivities()
            return
        }
        
        let ongoingChallenges = findOngoingChallenges()
        let runningActivities = Activity<ChallengeActivityAttributes>.activities
        
        if ongoingChallenges.isEmpty {
            endAllActivities()
            return
        }
        
        let dm = DataManager.shared
        // Gather actual members of the signed-in user's family
        var seenIds = Set<UUID>()
        seenIds.insert(currentUser.profileId)
        var allFamilyProfiles: [Profile] = [currentUser]
        for p in dm.allProfiles {
            if p.familyId == currentUser.familyId && !seenIds.contains(p.profileId) {
                seenIds.insert(p.profileId)
                allFamilyProfiles.append(p)
            }
        }
        
        ensureFamilyAvatarsCached(profiles: allFamilyProfiles)
        
        let allProgress = dm.challengeProgress
        let now = Date()
        let ongoingIds = Set(ongoingChallenges.map { $0.challengeId.uuidString })
        
        // 1. End any activity whose challenge is no longer ongoing
        for activity in runningActivities {
            if !ongoingIds.contains(activity.attributes.challengeId) {
                if activity.activityState == .active || activity.activityState == .stale || activity.activityState == .pending {
                    Task {
                        await activity.end(nil, dismissalPolicy: .immediate)
                    }
                }
            }
        }
        
        // 2. Start or update an independent Live Activity for every ongoing challenge
        for challenge in ongoingChallenges {
            let targetId = challenge.challengeId.uuidString
            let relatedProgress = allProgress.filter { $0.challengeId == challenge.challengeId }
            
            struct MemberCompletionInfo {
                let profile: Profile
                let isDone: Bool
                let lastUpdatedAt: Date
            }
            
            var completedCount = 0
            var memberInfos: [MemberCompletionInfo] = []
            
            for profile in allFamilyProfiles {
                let progress = relatedProgress.first(where: { $0.memberId == profile.profileId })
                let isMemberDone: Bool
                if challenge.status == "completed" {
                    isMemberDone = true
                } else if let progress = progress, progress.goalValue > 0 {
                    isMemberDone = progress.currentValue >= progress.goalValue
                } else {
                    isMemberDone = false
                }
                
                if isMemberDone {
                    completedCount += 1
                }
                
                memberInfos.append(MemberCompletionInfo(
                    profile: profile,
                    isDone: isMemberDone,
                    lastUpdatedAt: progress?.lastUpdatedAt ?? Date.distantPast
                ))
            }
            
            let currentUserDone: Bool
            if challenge.status == "completed" {
                currentUserDone = true
            } else if let myProg = relatedProgress.first(where: { $0.memberId == currentUser.profileId }), myProg.goalValue > 0 {
                currentUserDone = myProg.currentValue >= myProg.goalValue
            } else {
                currentUserDone = false
            }
            
            let totalCount = allFamilyProfiles.count
            let isFamilyDone = challenge.status == "completed" || (totalCount > 0 && completedCount >= totalCount)
            
            // Determine which member was the last to complete when the family challenge is done
            var lastCompleterProfileId: UUID? = nil
            if isFamilyDone && completedCount > 0 {
                let completedMembers = memberInfos.filter { $0.isDone }
                if let latest = completedMembers.max(by: { $0.lastUpdatedAt < $1.lastUpdatedAt }) {
                    lastCompleterProfileId = latest.profile.profileId
                }
            }
            
            var memberAvatars: [ChallengeActivityAttributes.FamilyMemberAvatar] = []
            for info in memberInfos {
                let isLast = isFamilyDone && (info.profile.profileId == lastCompleterProfileId)
                memberAvatars.append(
                    ChallengeActivityAttributes.FamilyMemberAvatar(
                        profileId: info.profile.profileId.uuidString,
                        displayName: info.profile.displayName,
                        isCompleted: info.isDone,
                        isLastCompleter: isLast
                    )
                )
            }
            
            let fraction: Double
            if isFamilyDone {
                fraction = 1.0
            } else if totalCount > 0 {
                fraction = Double(completedCount) / Double(totalCount)
            } else {
                fraction = 0.0
            }
            
            let timeRemainingText: String
            if isFamilyDone {
                timeRemainingText = "Completed"
            } else if challenge.endDate <= now {
                timeRemainingText = "Ended"
            } else {
                let diff = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: challenge.endDate)
                if let days = diff.day, days > 0 {
                    timeRemainingText = "\(days)d left"
                } else if let hours = diff.hour, hours > 0 {
                    timeRemainingText = "\(hours)h left"
                } else if let minutes = diff.minute, minutes > 0 {
                    timeRemainingText = "\(minutes)m left"
                } else {
                    timeRemainingText = "Ends soon"
                }
            }
            
            let state = ChallengeActivityAttributes.ContentState(
                challengeName: challenge.name,
                familyMembers: memberAvatars,
                isUserCompleted: currentUserDone,
                isFamilyCompleted: isFamilyDone,
                progressFraction: fraction,
                completedMembersCount: completedCount,
                totalMembersCount: totalCount,
                timeRemainingText: timeRemainingText,
                lastUpdated: Date()
            )
            let content = ActivityContent(state: state, staleDate: challenge.endDate)
            
            let matchingActivities = runningActivities.filter { $0.attributes.challengeId == targetId }
            
            // If the user swiped to dismiss this challenge's Live Activity, respect that action
            if matchingActivities.contains(where: { $0.activityState == .dismissed }) {
                continue
            }
            
            if let activeActivity = matchingActivities.first(where: { $0.activityState == .active || $0.activityState == .stale || $0.activityState == .pending }) {
                // Update running activity if state changed
                Task {
                    await activeActivity.update(content)
                }
                // End any duplicate active activities for this same challenge
                for duplicate in matchingActivities where duplicate.id != activeActivity.id && (duplicate.activityState == .active || duplicate.activityState == .stale || duplicate.activityState == .pending) {
                    Task {
                        await duplicate.end(nil, dismissalPolicy: .immediate)
                    }
                }
            } else {
                // Start a Live Activity for this challenge
                let attributes = ChallengeActivityAttributes(
                    challengeId: targetId,
                    userProfileId: currentUser.profileId.uuidString,
                    userDisplayName: currentUser.displayName
                )
                
                do {
                    let activity = try Activity.request(
                        attributes: attributes,
                        content: content,
                        pushType: nil
                    )
                    print("ChallengeActivityManager: Started Live Activity '\(activity.id)' for '\(challenge.name)'")
                } catch {
                    print("ChallengeActivityManager: Failed to start Live Activity for '\(challenge.name)': \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - End All Activities
    
    func endAllActivities() {
        for activity in Activity<ChallengeActivityAttributes>.activities {
            if activity.activityState == .active || activity.activityState == .stale || activity.activityState == .pending {
                Task {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
    }
    
    // MARK: - Backward-Compatibility Methods
    
    func startActivitiesForActiveChallenges() {
        reconcileLiveActivity()
    }
    
    func updateLiveActivities() {
        reconcileLiveActivity()
    }
    
    func startLiveActivity(for challenge: ChallengeDetails) {
        reconcileLiveActivity()
    }
    
    func endLiveActivity(for challengeId: UUID) {
        let targetId = challengeId.uuidString
        for activity in Activity<ChallengeActivityAttributes>.activities {
            if activity.attributes.challengeId == targetId {
                Task {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
    }
}

// MARK: - Image Pixel Trimming Helper

private extension UIImage {
    /// Crops transparent pixels from outer margins so glyphs cleanly fill their frame.
    func trimmingTransparentPixels(paddingRatio: CGFloat = 0.04) -> UIImage {
        guard let cgImage = self.cgImage else { return self }
        let width = cgImage.width
        let height = cgImage.height
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return self }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var minX = width
        var maxX = 0
        var minY = height
        var maxY = 0
        var hasOpaque = false
        
        for y in 0..<height {
            let rowOffset = y * bytesPerRow
            for x in 0..<width {
                let alpha = rawData[rowOffset + x * bytesPerPixel + 3]
                if alpha > 15 {
                    hasOpaque = true
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
        
        guard hasOpaque, minX <= maxX, minY <= maxY else { return self }
        
        let padX = Int(CGFloat(maxX - minX + 1) * paddingRatio)
        let padY = Int(CGFloat(maxY - minY + 1) * paddingRatio)
        let cropMinX = max(0, minX - padX)
        let cropMinY = max(0, minY - padY)
        let cropMaxX = min(width - 1, maxX + padX)
        let cropMaxY = min(height - 1, maxY + padY)
        let cropRect = CGRect(
            x: cropMinX,
            y: cropMinY,
            width: cropMaxX - cropMinX + 1,
            height: cropMaxY - cropMinY + 1
        )
        
        guard let croppedCg = cgImage.cropping(to: cropRect) else { return self }
        return UIImage(cgImage: croppedCg, scale: self.scale, orientation: self.imageOrientation)
    }
}

