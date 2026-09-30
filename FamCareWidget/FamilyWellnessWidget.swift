//
//  FamilyWellnessWidget.swift
//  FamCareWidget
//
//  Widget #1: "Family Wellness"
//  Shows the overall family wellness score with a ring,
//  and member avatars (profile photos) at each size.
//
//  Small  – Ring + "Family" label
//  Medium – Ring + "Family wellness" title + member avatar row
//  Large  – Ring + title + per-member rows with name, bar, and score
//

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Timeline Entry

struct FamilyWellnessEntry: TimelineEntry {
    let date: Date
    let payload: WidgetFamilyPayload?
    let selectedProfileId: String?
    let careAlert: WidgetCareAlertData?
}

// MARK: - Timeline Provider

struct FamilyWellnessProvider: TimelineProvider {
    func placeholder(in context: Context) -> FamilyWellnessEntry {
        FamilyWellnessEntry(date: .now, payload: .sample, selectedProfileId: nil, careAlert: .sample)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (FamilyWellnessEntry) -> Void) {
        let payload = WidgetDataLoader.loadFamilyPayload() ?? .sample
        let selectedId = WidgetDataLoader.selectedProfileId()
        let alerts = WidgetDataLoader.loadCareAlerts()
        completion(FamilyWellnessEntry(date: .now, payload: payload, selectedProfileId: selectedId, careAlert: alerts.first))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<FamilyWellnessEntry>) -> Void) {
        let payload = WidgetDataLoader.loadFamilyPayload()
        let selectedId = WidgetDataLoader.selectedProfileId()
        let alerts = WidgetDataLoader.loadCareAlerts()
        let entry = FamilyWellnessEntry(date: .now, payload: payload, selectedProfileId: selectedId, careAlert: alerts.first)
        
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget Background

struct WidgetBackgroundView: View {
    let entry: FamilyWellnessEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        if entry.careAlert != nil && family == .systemMedium {
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.90, blue: 0.88),
                    Color(red: 0.98, green: 0.82, blue: 0.80)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color(red: 221/255.0, green: 247/255.0, blue: 252/255.0)
        }
    }
}

// MARK: - Widget Definition

struct FamilyWellnessWidget: Widget {
    let kind = "FamilyWellnessWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FamilyWellnessProvider()) { entry in
            FamilyWellnessWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackgroundView(entry: entry)
                }
        }
        .configurationDisplayName("Family Wellness")
        .description("Your family's overall wellness score at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Main View

struct FamilyWellnessWidgetView: View {
    let entry: FamilyWellnessEntry
    
    @Environment(\.widgetFamily) var family
    
    // Check if a specific member is interactively selected
    private var selectedMember: WidgetMemberData? {
        guard let id = entry.selectedProfileId,
              let payload = entry.payload else { return nil }
        return payload.members.first(where: { $0.profileId == id })
    }
    
    var body: some View {
        if let member = selectedMember {
            // Interactive mode: show specific member details inside this widget
            memberDetailView(for: member)
        } else {
            // Normal mode: family overview
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            case .systemLarge:
                largeView
            default:
                smallView
            }
        }
    }
    
    // MARK: - Interactive Detail View
    
    @ViewBuilder
    private func memberDetailView(for member: WidgetMemberData) -> some View {
        if family == .systemSmall {
            // Small detail view
            VStack(spacing: 8) {
                // Interactive back button
                HStack {
                    Button(intent: SelectMemberIntent(profileId: "")) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(4)
                            .background(Circle().fill(Color.black.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                
                WellnessRingView(
                    score: member.wellnessScore,
                    size: 56,
                    lineWidth: 6,
                    showLabel: true,
                    fontSize: 14
                )
                Text(member.displayName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        } else {
            // Medium/Large detail view (shows full vital stats)
            VStack(alignment: .leading, spacing: 10) {
                // Header with back button
                HStack(spacing: 12) {
                    Button(intent: SelectMemberIntent(profileId: "")) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(6)
                            .background(Circle().fill(Color.black.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    
                    ProfileAvatarView(profileId: member.profileId, displayName: member.displayName, size: 36)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.displayName)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Score: \(Int(member.wellnessScore * 100))%")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                
                Divider()
                
                // Vitals Grid/Table
                if family == .systemMedium {
                    // Fit in 2 columns for medium
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            vitalRow(label: "HR", value: member.heartRate.map { "\($0) bpm" } ?? "—")
                            vitalRow(label: "HRV", value: member.hrv.map { "\($0) ms" } ?? "—")
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            vitalRow(label: "Steps", value: member.steps?.formatted() ?? "—")
                            vitalRow(label: "Distance", value: member.distance.map { String(format: "%.1f km", $0 / 1000.0) } ?? "—")
                        }
                    }
                } else {
                    // Full list for large
                    VStack(spacing: 8) {
                        vitalRow(label: "Heart rate", value: member.heartRate.map { "\($0) bpm" } ?? "—")
                        vitalRow(label: "HRV", value: member.hrv.map { "\($0) ms" } ?? "—")
                        vitalRow(label: "Distance", value: member.distance.map { String(format: "%.1f km / %d km", $0 / 1000.0, member.distanceGoal) } ?? "—")
                        vitalRow(label: "Steps", value: member.steps.map { "\($0.formatted()) / \(member.stepGoal.formatted())" } ?? "—")
                        vitalRow(label: "Calories", value: member.calories.map { "\($0) / \(member.caloriesGoal)" } ?? "—")
                    }
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func vitalRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Small (2×2)
    
    private var smallView: some View {
        VStack(spacing: 8) {
            Spacer()
            WellnessRingView(
                score: entry.payload?.familyWellnessScore ?? 0,
                size: 70,
                lineWidth: 7,
                showLabel: true,
                fontSize: 16
            )
            Text("Family")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Medium (4×2)
    
    @ViewBuilder
    private var mediumView: some View {
        if let alert = entry.careAlert {
            mediumCareAlertView(for: alert)
        } else {
            defaultMediumView
        }
    }
    
    private func mediumCareAlertView(for alert: WidgetCareAlertData) -> some View {
        HStack(spacing: 16) {
            ProfileAvatarView(
                profileId: alert.profileId,
                displayName: alert.displayName,
                size: 56
            )
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Needs Attention")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.red)
                
                Text(alert.alertMessage)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Link(destination: URL(string: "homescreenapp://group")!) {
                    Text("Plan a Care")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.red))
                }
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var defaultMediumView: some View {
        HStack(spacing: 16) {
            // Left: Ring
            WellnessRingView(
                score: entry.payload?.familyWellnessScore ?? 0,
                size: 60,
                lineWidth: 6,
                showLabel: true,
                fontSize: 14
            )
            
            // Right: Title + interactive member avatars
            VStack(alignment: .leading, spacing: 8) {
                Text("Family wellness")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    ForEach(Array((entry.payload?.members ?? []).prefix(5).enumerated()), id: \.offset) { _, member in
                        if #available(iOS 17.0, *) {
                            Button(intent: SelectMemberIntent(profileId: member.profileId)) {
                                ProfileAvatarView(
                                    profileId: member.profileId,
                                    displayName: member.displayName,
                                    size: 30
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            ProfileAvatarView(
                                profileId: member.profileId,
                                displayName: member.displayName,
                                size: 30
                            )
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Large (4×4)
    
    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Ring + Title + Updated label
            HStack(spacing: 12) {
                WellnessRingView(
                    score: entry.payload?.familyWellnessScore ?? 0,
                    size: 46,
                    lineWidth: 5,
                    showLabel: true,
                    fontSize: 12
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Family wellness")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(WidgetDataLoader.lastUpdatedString())
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
                .padding(.vertical, 2)
            
            // Interactive Member rows
            VStack(spacing: 10) {
                ForEach(Array((entry.payload?.members ?? []).prefix(4).enumerated()), id: \.offset) { _, member in
                    if #available(iOS 17.0, *) {
                        Button(intent: SelectMemberIntent(profileId: member.profileId)) {
                            largeMemberRow(member: member)
                        }
                        .buttonStyle(.plain)
                    } else {
                        largeMemberRow(member: member)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func largeMemberRow(member: WidgetMemberData) -> some View {
        HStack(spacing: 10) {
            ProfileAvatarView(
                profileId: member.profileId,
                displayName: member.displayName,
                size: 28
            )
            
            Text(member.displayName)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            WellnessBarView(score: member.wellnessScore, width: 60)
            
            Text("\(Int(member.wellnessScore * 100))%")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    FamilyWellnessWidget()
} timeline: {
    FamilyWellnessEntry(date: .now, payload: .sample, selectedProfileId: nil, careAlert: nil)
}

#Preview("Medium", as: .systemMedium) {
    FamilyWellnessWidget()
} timeline: {
    FamilyWellnessEntry(date: .now, payload: .sample, selectedProfileId: nil, careAlert: .sample)
}

#Preview("Large", as: .systemLarge) {
    FamilyWellnessWidget()
} timeline: {
    FamilyWellnessEntry(date: .now, payload: .sample, selectedProfileId: nil, careAlert: nil)
}
