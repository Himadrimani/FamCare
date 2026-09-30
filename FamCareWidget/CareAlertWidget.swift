//
//  CareAlertWidget.swift
//  FamCareWidget
//
//  Widget #3: "Care Alert"
//  Surfaces only when someone's vitals suggest they need a check-in.
//  Falls back to "Everyone is doing fine" when there are no alerts.
//
//  Small  – Avatar + alert message
//  Medium – Avatar + alert message + action deep-link pills
//  Large  – Full alert message + action pills + healthy members row
//

import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct CareAlertEntry: TimelineEntry {
    let date: Date
    let alert: WidgetCareAlertData?
    let healthyMembers: [WidgetMemberData]
}

// MARK: - Timeline Provider

struct CareAlertProvider: TimelineProvider {
    func placeholder(in context: Context) -> CareAlertEntry {
        CareAlertEntry(
            date: .now,
            alert: .sample,
            healthyMembers: Array(WidgetFamilyPayload.sample.members.dropFirst())
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CareAlertEntry) -> Void) {
        let alerts = WidgetDataLoader.loadCareAlerts()
        let payload = WidgetDataLoader.loadFamilyPayload()
        
        let alertedIds = Set(alerts.map { $0.profileId })
        let healthy = (payload?.members ?? []).filter { !alertedIds.contains($0.profileId) }
        
        completion(CareAlertEntry(
            date: .now,
            alert: alerts.first ?? .sample,
            healthyMembers: healthy
        ))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CareAlertEntry>) -> Void) {
        let alerts = WidgetDataLoader.loadCareAlerts()
        let payload = WidgetDataLoader.loadFamilyPayload()
        
        let alertedIds = Set(alerts.map { $0.profileId })
        let healthy = (payload?.members ?? []).filter { !alertedIds.contains($0.profileId) }
        
        let entry = CareAlertEntry(
            date: .now,
            alert: alerts.first,
            healthyMembers: healthy
        )
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget Definition

struct CareAlertWidget: Widget {
    let kind = "CareAlertWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CareAlertProvider()) { entry in
            CareAlertWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    if entry.alert != nil {
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.94, blue: 0.90),
                                Color(red: 0.98, green: 0.88, blue: 0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        LinearGradient(
                            colors: [
                                Color(red: 0.92, green: 0.97, blue: 0.93),
                                Color(red: 0.88, green: 0.95, blue: 0.90)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
        }
        .configurationDisplayName("Care Alert")
        .description("Notifies you when a family member's vitals need attention.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Main View

struct CareAlertWidgetView: View {
    let entry: CareAlertEntry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        if entry.alert == nil {
            // No alerts — show "Everyone is fine"
            noAlertView
        } else {
            switch family {
            case .systemSmall:
                smallAlertView
            case .systemMedium:
                mediumAlertView
            case .systemLarge:
                largeAlertView
            default:
                smallAlertView
            }
        }
    }
    
    // MARK: - No Alert State
    
    private var noAlertView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(Color(red: 0.18, green: 0.65, blue: 0.45))
            Text("Everyone is doing fine")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Small (2×2)
    
    private var smallAlertView: some View {
        VStack(spacing: 8) {
            Spacer()
            
            ProfileAvatarView(
                profileId: entry.alert!.profileId,
                displayName: entry.alert!.displayName,
                size: 44
            )
            
            Text("\(entry.alert!.displayName) needs\na check-in")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Medium (4×2)
    
    private var mediumAlertView: some View {
        HStack(spacing: 12) {
            ProfileAvatarView(
                profileId: entry.alert!.profileId,
                displayName: entry.alert!.displayName,
                size: 40
            )
            
            VStack(alignment: .leading, spacing: 6) {
                Text("\(entry.alert!.displayName) might need care")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Action deep-link pills
                HStack(spacing: 8) {
                    Link(destination: URL(string: "homescreenapp://call/\(entry.alert!.profileId)")!) {
                        Text("Call")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 0.55, green: 0.30, blue: 0.25))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.7))
                            )
                    }
                    
                    Link(destination: URL(string: "homescreenapp://message/\(entry.alert!.profileId)")!) {
                        Text("Message")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 0.55, green: 0.30, blue: 0.25))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.7))
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
    
    private var largeAlertView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Alert header
            HStack(spacing: 10) {
                ProfileAvatarView(
                    profileId: entry.alert!.profileId,
                    displayName: entry.alert!.displayName,
                    size: 36
                )
                
                Text(entry.alert!.alertMessage)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Spacer()
            }
            
            // Action pills
            HStack(spacing: 8) {
                Link(destination: URL(string: "homescreenapp://call/\(entry.alert!.profileId)")!) {
                    Text("Plan a call")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 0.55, green: 0.30, blue: 0.25))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.7))
                            )
                }
                
                Link(destination: URL(string: "homescreenapp://care/\(entry.alert!.profileId)")!) {
                    Text("Send flowers")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 0.55, green: 0.30, blue: 0.25))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.7))
                        )
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Healthy members section
            Text("Everyone else is doing fine")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                ForEach(Array(entry.healthyMembers.prefix(5).enumerated()), id: \.offset) { _, member in
                    ProfileAvatarView(
                        profileId: member.profileId,
                        displayName: member.displayName,
                        size: 32
                    )
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#Preview("Small - Alert", as: .systemSmall) {
    CareAlertWidget()
} timeline: {
    CareAlertEntry(date: .now, alert: .sample, healthyMembers: Array(WidgetFamilyPayload.sample.members.dropFirst()))
}

#Preview("Medium - Alert", as: .systemMedium) {
    CareAlertWidget()
} timeline: {
    CareAlertEntry(date: .now, alert: .sample, healthyMembers: Array(WidgetFamilyPayload.sample.members.dropFirst()))
}

#Preview("Large - Alert", as: .systemLarge) {
    CareAlertWidget()
} timeline: {
    CareAlertEntry(date: .now, alert: .sample, healthyMembers: Array(WidgetFamilyPayload.sample.members.dropFirst()))
}

#Preview("No Alert", as: .systemSmall) {
    CareAlertWidget()
} timeline: {
    CareAlertEntry(date: .now, alert: nil, healthyMembers: WidgetFamilyPayload.sample.members)
}
