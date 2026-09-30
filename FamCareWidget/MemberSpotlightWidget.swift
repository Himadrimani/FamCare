//
//  MemberSpotlightWidget.swift
//  FamCareWidget
//
//  Widget #2: "Member Spotlight"
//  Focuses on a single family member's vitals and wellness score.
//  Rotates through members on each timeline refresh.
//
//  Small  – Ring + member name
//  Medium – Ring + name + vital pills (HR, steps)
//  Large  – Ring + name + full vital breakdown table
//

import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct MemberSpotlightEntry: TimelineEntry {
    let date: Date
    let member: WidgetMemberData?
}

// MARK: - Timeline Provider

struct MemberSpotlightProvider: TimelineProvider {
    func placeholder(in context: Context) -> MemberSpotlightEntry {
        MemberSpotlightEntry(date: .now, member: WidgetFamilyPayload.sample.members.first)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (MemberSpotlightEntry) -> Void) {
        let payload = WidgetDataLoader.loadFamilyPayload()
        let member = payload?.members.first ?? WidgetFamilyPayload.sample.members.first
        completion(MemberSpotlightEntry(date: .now, member: member))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<MemberSpotlightEntry>) -> Void) {
        let payload = WidgetDataLoader.loadFamilyPayload()
        let members = payload?.members ?? WidgetFamilyPayload.sample.members
        
        // Create one entry per member, rotating every 30 minutes
        var entries: [MemberSpotlightEntry] = []
        let now = Date()
        for (index, member) in members.enumerated() {
            let entryDate = Calendar.current.date(byAdding: .minute, value: 30 * index, to: now)!
            entries.append(MemberSpotlightEntry(date: entryDate, member: member))
        }
        
        let nextUpdate = Calendar.current.date(
            byAdding: .minute,
            value: 30 * max(members.count, 1),
            to: now
        )!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget Definition

struct MemberSpotlightWidget: Widget {
    let kind = "MemberSpotlightWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MemberSpotlightProvider()) { entry in
            MemberSpotlightWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0.15, green: 0.15, blue: 0.15)
                }
        }
        .configurationDisplayName("Member Spotlight")
        .description("Focus on one family member's vitals.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Main View

struct MemberSpotlightWidgetView: View {
    let entry: MemberSpotlightEntry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
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
    
    // MARK: - Small (2×2)
    
    private var smallView: some View {
        VStack(spacing: 8) {
            Spacer()
            
            WellnessRingView(
                score: entry.member?.wellnessScore ?? 0,
                size: 66,
                lineWidth: 6,
                showLabel: true,
                fontSize: 15
            )
            
            Text(entry.member?.displayName ?? "—")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Medium (4×2)
    
    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left: Ring
            WellnessRingView(
                score: entry.member?.wellnessScore ?? 0,
                size: 56,
                lineWidth: 5,
                showLabel: true,
                fontSize: 13
            )
            
            // Right: Name + vitals pills
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.member?.displayName ?? "—")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                HStack(spacing: 6) {
                    if let hr = entry.member?.heartRate {
                        VitalPillView(
                            value: "\(hr) bpm",
                            color: Color(red: 0.85, green: 0.30, blue: 0.35)
                        )
                    }
                    if let steps = entry.member?.steps {
                        let formatted = steps >= 1000
                            ? String(format: "%.1fk", Double(steps) / 1000.0)
                            : "\(steps)"
                        VitalPillView(
                            value: formatted,
                            color: Color(red: 0.18, green: 0.65, blue: 0.45)
                        )
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
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 12) {
                WellnessRingView(
                    score: entry.member?.wellnessScore ?? 0,
                    size: 46,
                    lineWidth: 5,
                    showLabel: true,
                    fontSize: 12
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.member?.displayName ?? "—")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Wellness score")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Vitals table
            VStack(spacing: 10) {
                vitalRow(label: "Heart rate", value: entry.member?.heartRate.map { "\($0) bpm" } ?? "—")
                vitalRow(label: "HRV", value: entry.member?.hrv.map { "\($0) ms" } ?? "—")
                vitalRow(
                    label: "Distance",
                    value: {
                        if let d = entry.member?.distance {
                            let goal = entry.member?.distanceGoal ?? 10
                            return String(format: "%.1f km / %d km", d / 1000.0, goal)
                        }
                        return "—"
                    }()
                )
                vitalRow(
                    label: "Steps",
                    value: {
                        if let s = entry.member?.steps {
                            let goal = entry.member?.stepGoal ?? 10000
                            return "\(s.formatted()) / \(goal.formatted())"
                        }
                        return "—"
                    }()
                )
                vitalRow(
                    label: "Calories",
                    value: {
                        if let c = entry.member?.calories {
                            let goal = entry.member?.caloriesGoal ?? 500
                            return "\(c) / \(goal)"
                        }
                        return "—"
                    }()
                )
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Vital Row
    
    private func vitalRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    MemberSpotlightWidget()
} timeline: {
    MemberSpotlightEntry(date: .now, member: WidgetFamilyPayload.sample.members.first!)
}

#Preview("Medium", as: .systemMedium) {
    MemberSpotlightWidget()
} timeline: {
    MemberSpotlightEntry(date: .now, member: WidgetFamilyPayload.sample.members.first!)
}

#Preview("Large", as: .systemLarge) {
    MemberSpotlightWidget()
} timeline: {
    MemberSpotlightEntry(date: .now, member: WidgetFamilyPayload.sample.members.first!)
}
