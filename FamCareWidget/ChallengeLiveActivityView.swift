//
//  ChallengeLiveActivityView.swift
//  FamCareWidgetExtension
//
//  SwiftUI views for the Challenge Live Activity.
//  Renders on the Lock Screen.
//

import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - Live Activity Configuration

struct ChallengeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChallengeActivityAttributes.self) { context in
            // Lock Screen / Banner view
            ChallengeLockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.97, green: 0.98, blue: 0.97))
                .activitySystemActionForegroundColor(Color(red: 0.10, green: 0.16, blue: 0.28))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Leading: Icon + Challenge Name
                DynamicIslandExpandedRegion(.leading, priority: 1.0) {
                    HStack(spacing: 7) {
                        dynamicIslandIcon(
                            isFamilyCompleted: context.state.isFamilyCompleted,
                            completedMembersCount: context.state.completedMembersCount,
                            size: 24
                        )
                        Text(context.state.challengeName)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .padding(.leading, 6)
                }
                
                // Expanded Trailing: "Completed" (green) or Time Remaining (gray)
                DynamicIslandExpandedRegion(.trailing, priority: 0.0) {
                    if context.state.isFamilyCompleted {
                        Text("Completed")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 0.25, green: 0.65, blue: 0.37))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.trailing, 6)
                    } else if !context.state.timeRemainingText.isEmpty {
                        Text(context.state.timeRemainingText)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.trailing, 6)
                    }
                }
                
                // Expanded Bottom: Progress Bar + Members Row + Open FamCare Action Pill
                DynamicIslandExpandedRegion(.bottom) {
                    let members = islandDisplayMembers(from: context)
                    VStack(spacing: 6) {
                        // 1. Horizontal Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 4)
                                
                                if context.state.completedMembersCount > 0 && context.state.progressFraction > 0 {
                                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                                        .fill(Color(red: 0.99, green: 0.77, blue: 0.43))
                                        .frame(
                                            width: max(0, min(geo.size.width * CGFloat(context.state.progressFraction), geo.size.width)),
                                            height: 4
                                        )
                                }
                            }
                        }
                        .frame(height: 4)
                        
                        // 2. Members Row with Badges + "X of Y done"
                        HStack(alignment: .center) {
                            if !members.isEmpty {
                                HStack(spacing: -5) {
                                    ForEach(Array(members.prefix(8).enumerated()), id: \.element.profileId) { index, member in
                                        let badgeType: MemberBadgeType = {
                                            if isLastCompleter(for: member, in: members, isFamilyCompleted: context.state.isFamilyCompleted) {
                                                return .shield
                                            } else if member.isCompleted {
                                                return .goldTrophy
                                            } else {
                                                return .greyTrophy
                                            }
                                        }()
                                        DynamicIslandMemberAvatarView(
                                            profileId: member.profileId,
                                            displayName: member.displayName,
                                            badgeType: badgeType,
                                            size: 24
                                        )
                                        .zIndex(Double(members.count - index))
                                    }
                                }
                            }
                            
                            Spacer(minLength: 8)
                            
                            Text("\(context.state.completedMembersCount) of \(context.state.totalMembersCount) done")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.75))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        
                        // 3. Open FamCare Action Pill
                        Link(destination: URL(string: "homescreenapp://challenge/\(context.attributes.challengeId)")!) {
                            HStack {
                                Text("Open FamCare")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.55))
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color.white.opacity(0.12))
                            )
                        }
                        .padding(.horizontal, 2)
                    }
                    .padding(.top, 2)
                    .padding(.bottom, 2)
                }
            } compactLeading: {
                dynamicIslandIcon(
                    isFamilyCompleted: context.state.isFamilyCompleted,
                    completedMembersCount: context.state.completedMembersCount,
                    size: 19
                )
                .padding(.leading, 2)
            } compactTrailing: {
                DynamicIslandProgressRingView(
                    progress: context.state.progressFraction,
                    isCompleted: context.state.isFamilyCompleted,
                    completedMembersCount: context.state.completedMembersCount
                )
                .frame(width: 17, height: 17)
                .padding(.trailing, 2)
            } minimal: {
                dynamicIslandIcon(
                    isFamilyCompleted: context.state.isFamilyCompleted,
                    completedMembersCount: context.state.completedMembersCount,
                    size: 18
                )
            }
            .widgetURL(URL(string: "homescreenapp://challenge/\(context.attributes.challengeId)"))
        }
    }
    
    private func islandDisplayMembers(from context: ActivityViewContext<ChallengeActivityAttributes>) -> [ChallengeActivityAttributes.FamilyMemberAvatar] {
        if !context.state.familyMembers.isEmpty {
            return context.state.familyMembers
        }
        if !context.attributes.userProfileId.isEmpty {
            return [
                ChallengeActivityAttributes.FamilyMemberAvatar(
                    profileId: context.attributes.userProfileId,
                    displayName: context.attributes.userDisplayName,
                    isCompleted: context.state.isUserCompleted,
                    isLastCompleter: context.state.isFamilyCompleted
                )
            ]
        }
        return []
    }
    
    private func isLastCompleter(
        for member: ChallengeActivityAttributes.FamilyMemberAvatar,
        in members: [ChallengeActivityAttributes.FamilyMemberAvatar],
        isFamilyCompleted: Bool
    ) -> Bool {
        guard isFamilyCompleted else { return false }
        if member.isLastCompleter {
            return true
        }
        // Fallback: If isLastCompleter was not explicitly set on any member, pick the last completed member in the list
        let anyExplicit = members.contains(where: { $0.isLastCompleter })
        if !anyExplicit {
            let lastCompleted = members.filter { $0.isCompleted }.last
            return lastCompleted?.profileId == member.profileId
        }
        return false
    }
}

// MARK: - Lock Screen View

struct ChallengeLockScreenView: View {
    let context: ActivityViewContext<ChallengeActivityAttributes>
    
    private var displayMembers: [ChallengeActivityAttributes.FamilyMemberAvatar] {
        if !context.state.familyMembers.isEmpty {
            return context.state.familyMembers
        }
        // Fallback to current user if state has no members list
        if !context.attributes.userProfileId.isEmpty {
            return [
                ChallengeActivityAttributes.FamilyMemberAvatar(
                    profileId: context.attributes.userProfileId,
                    displayName: context.attributes.userDisplayName
                )
            ]
        }
        return []
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Left: App logo
            if let logoPath = WidgetDataLoader.appLogoImagePath(),
               let uiImage = UIImage(contentsOfFile: logoPath.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            } else if let uiImage = UIImage(named: "LaunchAppIcon") {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            } else {
                Image("LaunchAppIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            
            // Right: Challenge name at the top, with participating members' profile pictures displayed directly below it
            VStack(alignment: .leading, spacing: 6) {
                Text(context.state.challengeName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.10, green: 0.16, blue: 0.28))
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
                
                if !displayMembers.isEmpty {
                    HStack(spacing: -6) {
                        ForEach(Array(displayMembers.prefix(8).enumerated()), id: \.element.profileId) { index, member in
                            ProfileAvatarView(
                                profileId: member.profileId,
                                displayName: member.displayName,
                                size: 32,
                                solidBackground: true
                            )
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(red: 0.97, green: 0.98, blue: 0.97), lineWidth: 2))
                            .zIndex(Double(displayMembers.count - index))
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.97, green: 0.98, blue: 0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(red: 0.84, green: 0.92, blue: 0.90), lineWidth: 1.2)
        )
        .widgetURL(URL(string: "homescreenapp://challenge/\(context.attributes.challengeId)"))
    }
}

// MARK: - Dynamic Island Helpers

@ViewBuilder
func dynamicIslandIcon(
    isFamilyCompleted: Bool,
    completedMembersCount: Int,
    size: CGFloat
) -> some View {
    if isFamilyCompleted {
        if let path = WidgetDataLoader.shieldImagePath(),
           let uiImage = UIImage(contentsOfFile: path.path) {
            Image(uiImage: uiImage)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else if let uiImage = UIImage(named: "shield_sticker") {
            Image(uiImage: uiImage)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image("shield_sticker")
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        }
    } else if completedMembersCount > 0 {
        if let path = WidgetDataLoader.trophyGoldImagePath(),
           let uiImage = UIImage(contentsOfFile: path.path) {
            Image(uiImage: uiImage)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else if let uiImage = UIImage(named: "trophy_button_image") {
            Image(uiImage: uiImage)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image("trophy_button_image")
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        }
    } else {
        // 0 members completed -> Grey Trophy
        if let path = WidgetDataLoader.trophyDimmedImagePath(),
           let uiImage = UIImage(contentsOfFile: path.path) {
            Image(uiImage: uiImage)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else if let uiImage = UIImage(named: "grey_trophy") {
            Image(uiImage: uiImage)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image("grey_trophy")
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Dynamic Island Progress Ring

struct DynamicIslandProgressRingView: View {
    let progress: Double
    let isCompleted: Bool
    let completedMembersCount: Int
    
    private let ringColor = Color(red: 0.99, green: 0.77, blue: 0.43) // Warm orange/gold #FEC56E
    
    var body: some View {
        ZStack {
            // Background track (completely grey)
            Circle()
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 2.2)
            
            // Progress arc: only shown when complete or when completedMembersCount > 0 and progress > 0
            if isCompleted {
                Circle()
                    .strokeBorder(ringColor, lineWidth: 2.2)
            } else if completedMembersCount > 0 && progress > 0 {
                Circle()
                    .inset(by: 1.1)
                    .trim(from: 0, to: CGFloat(max(0.05, min(progress, 1.0))))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

// MARK: - Dynamic Island Member Avatar

enum MemberBadgeType {
    case greyTrophy
    case goldTrophy
    case shield
}

@ViewBuilder
func memberBadgeIcon(type: MemberBadgeType, size: CGFloat) -> some View {
    switch type {
    case .shield:
        if let path = WidgetDataLoader.shieldImagePath(),
           let uiImage = UIImage(contentsOfFile: path.path) {
            Image(uiImage: uiImage)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else if let uiImage = UIImage(named: "shield_sticker") {
            Image(uiImage: uiImage)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "shield.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundColor(.orange)
        }
    case .goldTrophy:
        if let path = WidgetDataLoader.trophyGoldImagePath(),
           let uiImage = UIImage(contentsOfFile: path.path) {
            Image(uiImage: uiImage)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else if let uiImage = UIImage(named: "trophy_button_image") {
            Image(uiImage: uiImage)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "trophy.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundColor(Color(red: 0.99, green: 0.77, blue: 0.43))
        }
    case .greyTrophy:
        if let path = WidgetDataLoader.trophyDimmedImagePath(),
           let uiImage = UIImage(contentsOfFile: path.path) {
            Image(uiImage: uiImage)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else if let uiImage = UIImage(named: "grey_trophy") {
            Image(uiImage: uiImage)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "trophy.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundColor(.gray)
        }
    }
}

struct DynamicIslandMemberAvatarView: View {
    let profileId: String
    let displayName: String
    let badgeType: MemberBadgeType
    let size: CGFloat
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ProfileAvatarView(
                profileId: profileId,
                displayName: displayName,
                size: size,
                solidBackground: true
            )
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.black, lineWidth: 1.2))
            
            // Completion badge: Grey Trophy, Colorful Trophy, or Family Shield
            ZStack {
                Circle()
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                    .frame(width: 12.5, height: 12.5)
                
                memberBadgeIcon(type: badgeType, size: 9)
            }
            .overlay(Circle().stroke(Color.black, lineWidth: 1))
            .offset(x: 2, y: 2)
        }
        .frame(width: size + 2, height: size + 2)
    }
}

