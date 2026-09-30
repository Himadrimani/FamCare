//
//  WidgetSharedModels.swift
//  FamCareWidget
//
//  Duplicated lightweight Codable models used by the widget to decode
//  data from the shared App Group container.
//  These must stay in sync with the models in WidgetDataProvider.swift.
//

import Foundation

// MARK: - Shared Constants

let kWidgetAppGroupIdentifier = "group.com.namanmittal.famcare"

enum WidgetSharedDataKey {
    static let familyWellness = "widget_family_wellness"
    static let careAlert = "widget_care_alert"
    static let lastUpdated = "widget_last_updated"
    static let selectedProfileId = "widget_selected_profile_id"
}

// MARK: - Codable Transfer Models

struct WidgetMemberData: Codable {
    let profileId: String
    let displayName: String
    let profilePicURL: String
    let wellnessScore: Double
    let heartRate: Int?
    let hrv: Int?
    let steps: Int?
    let stepGoal: Int
    let calories: Int?
    let caloriesGoal: Int
    let distance: Double?
    let distanceGoal: Int
}

struct WidgetCareAlertData: Codable {
    let profileId: String
    let displayName: String
    let profilePicURL: String
    let alertMessage: String
    let alertType: String
    let alertValue: Double
}

struct WidgetFamilyPayload: Codable {
    let familyName: String
    let familyWellnessScore: Double
    let members: [WidgetMemberData]
    let lastUpdated: Date
}

// MARK: - Data Loading Utility

struct WidgetDataLoader {
    
    static func loadFamilyPayload() -> WidgetFamilyPayload? {
        guard let defaults = UserDefaults(suiteName: kWidgetAppGroupIdentifier),
              let data = defaults.data(forKey: WidgetSharedDataKey.familyWellness) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetFamilyPayload.self, from: data)
    }
    
    static func loadCareAlerts() -> [WidgetCareAlertData] {
        guard let defaults = UserDefaults(suiteName: kWidgetAppGroupIdentifier),
              let data = defaults.data(forKey: WidgetSharedDataKey.careAlert) else {
            return []
        }
        let decoder = JSONDecoder()
        return (try? decoder.decode([WidgetCareAlertData].self, from: data)) ?? []
    }
    
    static func selectedProfileId() -> String? {
        guard let defaults = UserDefaults(suiteName: kWidgetAppGroupIdentifier) else { return nil }
        let id = defaults.string(forKey: WidgetSharedDataKey.selectedProfileId)
        return id?.isEmpty == true ? nil : id
    }
    
    static func lastUpdatedString() -> String {
        guard let defaults = UserDefaults(suiteName: kWidgetAppGroupIdentifier) else {
            return "Not yet"
        }
        let ts = defaults.double(forKey: WidgetSharedDataKey.lastUpdated)
        guard ts > 0 else { return "Not yet" }
        let date = Date(timeIntervalSince1970: ts)
        let diff = Date().timeIntervalSince(date)
        
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "Updated \(Int(diff / 60)) min ago" }
        if diff < 86400 { return "Updated \(Int(diff / 3600))h ago" }
        return "Updated \(Int(diff / 86400))d ago"
    }

    /// Loads a profile image from the App Group shared container.
    static func profileImagePath(for profileId: String) -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: kWidgetAppGroupIdentifier
        ) else { return nil }
        let imagePath = containerURL
            .appendingPathComponent("WidgetProfileImages", isDirectory: true)
            .appendingPathComponent("\(profileId).jpg")
        if FileManager.default.fileExists(atPath: imagePath.path) {
            return imagePath
        }
        return nil
    }
}

// MARK: - Sample Data for Previews

extension WidgetFamilyPayload {
    static let sample = WidgetFamilyPayload(
        familyName: "Family",
        familyWellnessScore: 0.78,
        members: [
            WidgetMemberData(
                profileId: "AAA", displayName: "Dad",
                profilePicURL: "", wellnessScore: 0.82,
                heartRate: 71, hrv: 44,
                steps: 10000, stepGoal: 20000, calories: 340, caloriesGoal: 500,
                distance: 6.5, distanceGoal: 10
            ),
            WidgetMemberData(
                profileId: "BBB", displayName: "Mom",
                profilePicURL: "", wellnessScore: 0.58,
                heartRate: 78, hrv: 38,
                steps: 6500, stepGoal: 10000, calories: 220, caloriesGoal: 400,
                distance: 4.2, distanceGoal: 5
            ),
            WidgetMemberData(
                profileId: "CCC", displayName: "Arjun",
                profilePicURL: "", wellnessScore: 0.91,
                heartRate: 68, hrv: 52,
                steps: 12500, stepGoal: 12000, calories: 480, caloriesGoal: 500,
                distance: 8.0, distanceGoal: 8
            ),
        ],
        lastUpdated: Date()
    )
}

extension WidgetCareAlertData {
    static let sample = WidgetCareAlertData(
        profileId: "BBB", displayName: "Mom",
        profilePicURL: "", alertMessage: "Mom's heart rate has been elevated today",
        alertType: "high_hr", alertValue: 105
    )
}
