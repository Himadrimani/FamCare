//
//  WidgetDataProvider.swift
//  HomeScreen
//
//  Bridges the main app's data layer with the Widget Extension.
//  All data is serialized to the App Group shared UserDefaults container
//  so the widget can read it without importing the full data stack.
//

import Foundation
import UIKit
import WidgetKit

// MARK: - Shared Constants

/// The App Group identifier shared between the main app and the widget extension.
/// Must match the value in both entitlement files.
let kAppGroupIdentifier = "group.com.namanmittal.famcare"

/// UserDefaults keys used by the widget.
enum WidgetDataKey {
    static let familyWellness = "widget_family_wellness"
    static let memberSpotlight = "widget_member_spotlight"
    static let careAlert = "widget_care_alert"
    static let lastUpdated = "widget_last_updated"
}

// MARK: - Codable Transfer Objects

/// Lightweight codable model for a single family member's widget data.
struct WidgetMemberData: Codable {
    let profileId: String
    let displayName: String
    let profilePicURL: String
    let wellnessScore: Double        // 0.0–1.0
    let heartRate: Int?              // bpm
    let hrv: Int?                    // ms
    let steps: Int?
    let stepGoal: Int
    let calories: Int?
    let caloriesGoal: Int
    let distance: Double?
    let distanceGoal: Int
}

/// Lightweight codable model for an abnormal-vital care alert.
struct WidgetCareAlertData: Codable {
    let profileId: String
    let displayName: String
    let profilePicURL: String
    let alertMessage: String
    let alertType: String            // "high_hr", "low_hr", "low_hrv"
    let alertValue: Double
}

/// Top-level container written to UserDefaults.
struct WidgetFamilyPayload: Codable {
    let familyName: String
    let familyWellnessScore: Double  // 0.0–1.0
    let members: [WidgetMemberData]
    let lastUpdated: Date
}

// MARK: - WidgetDataProvider

final class WidgetDataProvider {
    static let shared = WidgetDataProvider()
    
    private init() {
        // Automatically push data to the widget whenever the main app's data changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DataManagerDidUpdate"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pushToWidget()
        }
    }

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: kAppGroupIdentifier)
    }

    // MARK: - Push Data to Widget

    /// Serializes the current in-memory family data and writes it to the shared
    /// App Group container. Call this after each data refresh / sync cycle.
    func pushToWidget() {
        guard let defaults = sharedDefaults else {
            print("WidgetDataProvider: Cannot open App Group defaults.")
            return
        }

        let dm = DataManager.shared
        guard let currentUser = dm.currentUser else { return }
        let family = dm.family
        let profiles = ([currentUser] + dm.allProfiles).compactMap { $0 }
        let today = Date()

        // Build per-member payloads
        var memberPayloads: [WidgetMemberData] = []
        var careAlerts: [WidgetCareAlertData] = []

        for profile in profiles {
            let wellness = profile.wellnessResult(for: today)
            let sqlite = SQLiteHelper.shared
            let targetDay = Calendar.current.startOfDay(for: today)

            // Vitals
            let vitalRows = sqlite.fetchVitalsDaily(for: profile.profileId, on: targetDay)
            let hrRow = vitalRows.first(where: { $0.vitalType == .heartRate })
            let hrvRow = vitalRows.first(where: { $0.vitalType == .hrv })

            // Activity
            let activityRows = sqlite.fetchActivityDaily(for: profile.profileId, on: targetDay)
            let stepsValue = activityRows.first(where: { $0.activityType == .stepCount }).map { Int($0.value) }
            let caloriesValue = activityRows.first(where: { $0.activityType == .caloriesBurned }).map { Int($0.value) }
            let distanceValue = activityRows.first(where: { $0.activityType == .distanceCovered }).map { $0.value }

            let memberData = WidgetMemberData(
                profileId: profile.profileId.uuidString,
                displayName: profile.displayName,
                profilePicURL: profile.profilePic,
                wellnessScore: wellness.score,
                heartRate: hrRow?.avgValue.map { Int($0) },
                hrv: hrvRow?.avgValue.map { Int($0) },
                steps: stepsValue,
                stepGoal: profile.stepGoal,
                calories: caloriesValue,
                caloriesGoal: profile.caloriesGoal,
                distance: distanceValue,
                distanceGoal: profile.distanceGoal
            )
            memberPayloads.append(memberData)

            // Check for abnormal vitals for care alerts
            if let abnormal = profile.getAbnormalVital(on: today) {
                let alertMessage: String
                switch abnormal.type {
                case "high_hr":
                    alertMessage = "\(profile.displayName)'s heart rate has been elevated today"
                case "low_hr":
                    alertMessage = "\(profile.displayName)'s heart rate is unusually low today"
                case "low_hrv":
                    alertMessage = "\(profile.displayName)'s HRV is lower than usual today"
                default:
                    alertMessage = "\(profile.displayName) might need a check-in"
                }

                careAlerts.append(WidgetCareAlertData(
                    profileId: profile.profileId.uuidString,
                    displayName: profile.displayName,
                    profilePicURL: profile.profilePic,
                    alertMessage: alertMessage,
                    alertType: abnormal.type,
                    alertValue: abnormal.value
                ))
            }
        }

        // Calculate family-level wellness average
        let scores = memberPayloads.map { $0.wellnessScore }
        let familyAvg = scores.isEmpty ? 0.0 : scores.reduce(0, +) / Double(scores.count)

        let payload = WidgetFamilyPayload(
            familyName: family?.familyName ?? "Family",
            familyWellnessScore: familyAvg,
            members: memberPayloads,
            lastUpdated: today
        )

        // Encode and write
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(payload) {
            defaults.set(data, forKey: WidgetDataKey.familyWellness)
        }
        if let alertData = try? encoder.encode(careAlerts) {
            defaults.set(alertData, forKey: WidgetDataKey.careAlert)
        }
        defaults.set(Date().timeIntervalSince1970, forKey: WidgetDataKey.lastUpdated)

        // Also cache profile images to the shared container for the widget
        cacheProfileImagesToSharedContainer(profiles: profiles)

        // Tell WidgetKit to refresh all widget timelines
        WidgetCenter.shared.reloadAllTimelines()

        print("WidgetDataProvider: Pushed data for \(memberPayloads.count) members to widget.")
    }

    // MARK: - Profile Image Sharing

    /// Copies profile images to the App Group shared container so the widget
    /// extension can load them (widgets cannot use the main app's cache).
    private func cacheProfileImagesToSharedContainer(profiles: [Profile]) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: kAppGroupIdentifier
        ) else { return }

        let widgetImagesDir = containerURL.appendingPathComponent("WidgetProfileImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: widgetImagesDir, withIntermediateDirectories: true)

        for profile in profiles {
            let destFile = widgetImagesDir.appendingPathComponent("\(profile.profileId.uuidString).jpg")

            // Preserve only a real profile image. `loadImage(named:)` returns a generic
            // person symbol on failure, which must not replace a participant's photo.
            if let image = ImageManager.shared.resolveImageForMigration(path: profile.profilePic),
                let jpegData = image.jpegData(compressionQuality: 0.7) {
                try? jpegData.write(to: destFile, options: .atomic)
            } else if profile.profilePic.starts(with: "http"), let url = URL(string: profile.profilePic) {
                // Async download and save
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    guard let data = data, let image = UIImage(data: data),
                          let jpegData = image.jpegData(compressionQuality: 0.7) else { return }
                    try? jpegData.write(to: destFile, options: .atomic)
                    DispatchQueue.main.async {
                        ChallengeActivityManager.shared.updateLiveActivities()
                    }
                }.resume()
            }
        }
    }
}
