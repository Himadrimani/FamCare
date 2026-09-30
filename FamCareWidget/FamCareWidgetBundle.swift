//
//  FamCareWidgetBundle.swift
//  FamCareWidget
//
//  Widget extension entry point. Registers all three widget types:
//  1. Family Wellness – overall family score + member avatars
//  2. Member Spotlight – deep dive into one member's vitals
//  3. Care Alert – surfaces when someone's vitals are concerning
//

import SwiftUI
import WidgetKit

@main
struct FamCareWidgetBundle: WidgetBundle {
    var body: some Widget {
        FamilyWellnessWidget()
        MemberSpotlightWidget()
        CareAlertWidget()
        ChallengeLiveActivity()
    }
}
