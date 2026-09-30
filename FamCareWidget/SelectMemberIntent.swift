//
//  SelectMemberIntent.swift
//  FamCareWidgetExtension
//
//  An AppIntent that allows the user to interactively toggle between
//  the Family Wellness overview and a specific member's detailed stats.
//

import AppIntents
import WidgetKit
import Foundation

@available(iOS 17.0, *)
struct SelectMemberIntent: AppIntent {
    static var title: LocalizedStringResource = "Select Family Member"
    static var description = IntentDescription("Shows detailed stats for a specific family member in the widget.")
    
    // The profile ID of the member to select. If empty, returns to family view.
    @Parameter(title: "Profile ID")
    var profileId: String
    
    init() {
        self.profileId = ""
    }
    
    init(profileId: String) {
        self.profileId = profileId
    }
    
    func perform() async throws -> some IntentResult {
        // Save the selection to the shared App Group UserDefaults
        if let defaults = UserDefaults(suiteName: kWidgetAppGroupIdentifier) {
            if profileId.isEmpty {
                defaults.removeObject(forKey: WidgetSharedDataKey.selectedProfileId)
            } else {
                defaults.set(profileId, forKey: WidgetSharedDataKey.selectedProfileId)
            }
        }
        return .result()
    }
}
