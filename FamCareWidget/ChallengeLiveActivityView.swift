//
//  ChallengeLiveActivityView.swift
//  FamCareWidgetExtension
//
//  SwiftUI views for the Challenge Progress Live Activity.
//  Renders on the Lock Screen and Dynamic Island.
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
                .padding(16)
                .activityBackgroundTint(Color(red: 0.08, green: 0.12, blue: 0.18))
                .activitySystemActionForegroundColor(.white)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 16))
                        Text(context.attributes.challengeName)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(daysLeftText(endDate: context.attributes.endDate))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.15)))
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        ForEach(Array(context.state.members.prefix(3).enumerated()), id: \.offset) { _, member in
                            dynamicIslandMemberRow(member: member)
                        }
                        
                        if let leader = context.state.members.max(by: { progressFraction($0) < progressFraction($1) }) {
                            Text("\(leader.displayName) is leading — \(Int(progressFraction(leader) * 100))% to goal")
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 14))
            } compactTrailing: {
                if let leader = context.state.members.max(by: { progressFraction($0) < progressFraction($1) }) {
                    Text("\(Int(progressFraction(leader) * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
            } minimal: {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 14))
            }
        }
    }
    
    // MARK: - Helpers
    
    private func progressFraction(_ member: ChallengeActivityAttributes.MemberProgress) -> Double {
        guard member.goalValue > 0 else { return 0 }
        return min(member.currentValue / member.goalValue, 1.0)
    }
    
    private func daysLeftText(endDate: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
        if days <= 0 { return "Ends today" }
        if days == 1 { return "1 day left" }
        return "\(days) days left"
    }
    
    private func dynamicIslandMemberRow(member: ChallengeActivityAttributes.MemberProgress) -> some View {
        HStack(spacing: 8) {
            // Compact initial circle
            Text(String(member.displayName.prefix(1)))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(colorForMember(member.profileId)))
            
            Text(member.displayName)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 50, alignment: .leading)
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorForMember(member.profileId))
                        .frame(width: geo.size.width * min(member.currentValue / max(member.goalValue, 1), 1.0))
                }
            }
            .frame(height: 6)
            
            Text("\(Int(member.currentValue).formatted())")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 45, alignment: .trailing)
        }
    }
    
    private func colorForMember(_ profileId: String) -> Color {
        let hash = abs(profileId.hashValue)
        let colors: [Color] = [.green, .blue, .orange, .pink, .purple, .cyan, .mint, .indigo]
        return colors[hash % colors.count]
    }
}

// MARK: - Lock Screen View

struct ChallengeLockScreenView: View {
    let context: ActivityViewContext<ChallengeActivityAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Challenge name + days left
            HStack(alignment: .top) {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 20))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.challengeName)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        Text(challengeTypeLabel)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                Text(daysLeftText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.15)))
            }
            
            // Member avatars row
            HStack(spacing: -6) {
                ForEach(Array(context.state.members.prefix(5).enumerated()), id: \.offset) { index, member in
                    Text(String(member.displayName.prefix(1)))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(colorForMember(member.profileId)))
                        .overlay(Circle().stroke(Color(red: 0.08, green: 0.12, blue: 0.18), lineWidth: 2))
                        .zIndex(Double(context.state.members.count - index))
                }
            }
            
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
            
            // Member progress rows
            VStack(spacing: 10) {
                ForEach(Array(context.state.members.prefix(4).enumerated()), id: \.offset) { _, member in
                    memberProgressRow(member: member)
                }
            }
            
            // Footer: who's leading
            if let leader = context.state.members.max(by: { progressFraction($0) < progressFraction($1) }) {
                Text("\(leader.displayName) is leading — \(Int(progressFraction(leader) * 100))% to goal")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    // MARK: - Member Row
    
    private func memberProgressRow(member: ChallengeActivityAttributes.MemberProgress) -> some View {
        HStack(spacing: 10) {
            // Initial avatar
            Text(String(member.displayName.prefix(1)))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(colorForMember(member.profileId)))
            
            Text(member.displayName)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 60, alignment: .leading)
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.12))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorForMember(member.profileId))
                        .frame(width: geo.size.width * CGFloat(progressFraction(member)))
                }
            }
            .frame(height: 8)
            
            // Current / Goal
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(Int(member.currentValue).formatted()) /")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("\(Int(member.goalValue).formatted())")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(width: 55, alignment: .trailing)
        }
    }
    
    // MARK: - Helpers
    
    private var daysLeftText: String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: context.attributes.endDate).day ?? 0
        if days <= 0 { return "Ends today" }
        if days == 1 { return "1 day left" }
        return "\(days) days left"
    }
    
    private var challengeTypeLabel: String {
        switch context.attributes.challengeType.lowercased() {
        case "steps": return "Step Challenge"
        case "calories": return "Calorie Challenge"
        case "distance": return "Distance Challenge"
        default: return "Family Challenge"
        }
    }
    
    private func progressFraction(_ member: ChallengeActivityAttributes.MemberProgress) -> Double {
        guard member.goalValue > 0 else { return 0 }
        return min(member.currentValue / member.goalValue, 1.0)
    }
    
    private func colorForMember(_ profileId: String) -> Color {
        let hash = abs(profileId.hashValue)
        let colors: [Color] = [.green, .blue, .orange, .pink, .purple, .cyan, .mint, .indigo]
        return colors[hash % colors.count]
    }
}
