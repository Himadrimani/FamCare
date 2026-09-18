//
//  WellnessHeaderCell.swift
//  HomeScreen
//
//  Created by GEU on 09/02/26.
//

import UIKit

class WellnessHeaderCell: UICollectionViewCell {
    @IBOutlet weak var stepsValueLabel: UILabel!
    @IBOutlet weak var stepsSubtitleLabel: UILabel!

    @IBOutlet weak var sleepValueLabel: UILabel!
    @IBOutlet weak var sleepSubtitleLabel: UILabel!

    @IBOutlet weak var activityValueLabel: UILabel!
    @IBOutlet weak var activitySubtitleLabel: UILabel!

    @IBOutlet weak var heartValueLabel: UILabel!
    @IBOutlet weak var heartSubtitleLabel: UILabel!

    @IBOutlet weak var stepsRing: CircularRingView!
    @IBOutlet weak var sleepRing: CircularRingView!
    @IBOutlet weak var activityRing: CircularRingView!
    @IBOutlet weak var heartRing: CircularRingView!

    @IBOutlet weak var wellnessLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    func configure(with profile: Profile) {

        // Wellness score

        let score = profile.calculateWellnessScore(for: Date())
        let percent = Int(score * 100)

        wellnessLabel.text = "Wellness Score \(percent)%"

        //Icons

        stepsRing.setIcon("shoeprints.fill")
        sleepRing.setIcon("moon.fill")
        activityRing.setIcon("flame.fill")
        // Heart ring icon is set inside setSolid()

        // STEPS

        let steps = profile.activityDaily
            .first(where: { $0.activityType == .stepCount })?
            .value ?? 0

        let stepGoal = max(profile.stepGoal, 1)

        let stepProgress =
            CGFloat(steps) / CGFloat(stepGoal)

        stepsRing.setProgress(stepProgress, color: .systemGreen)

        stepsValueLabel.text = "\(steps)"
        stepsSubtitleLabel.text = "of \(stepGoal)"

       //SLEEP

        let sleepMinutes =
            profile.sleep.first?.totalSleepMinutes ?? 0

        let sleepGoal = max(Int(profile.sleepGoal * 60.0), 1)

        let sleepProgress =
            CGFloat(sleepMinutes) / CGFloat(sleepGoal)

        sleepRing.setProgress(sleepProgress, color: .systemBlue)

        // Convert to hours + minutes
        let hours = sleepMinutes / 60
        let minutes = sleepMinutes % 60
        let goalHours = Int(profile.sleepGoal)
        let goalMinutes = Int((profile.sleepGoal - Double(goalHours)) * 60)
        let goalText = goalMinutes > 0 ? "\(goalHours)h \(goalMinutes)m" : "\(goalHours)h"

        sleepValueLabel.text = "\(hours)h \(minutes)m"
        sleepSubtitleLabel.text = "of \(goalText)"

        //CALORIES

        let calories = profile.activityDaily
            .first(where: { $0.activityType == .caloriesBurned })?
            .value ?? 0

        let calorieGoal = max(profile.caloriesGoal, 1)

        let calorieProgress =
            CGFloat(calories) / CGFloat(calorieGoal)

        activityRing.setProgress(calorieProgress,
                                 color: .systemOrange)

        activityValueLabel.text = "\(calories)"
        activitySubtitleLabel.text = "of \(calorieGoal)"

        //HEART RATE

        let heart = profile.vitalDaily
            .first(where: { $0.vitalType == .heartRate })?
            .avgValue ?? 0

        // Solid filled circle — no ring track, white icon stands out
        heartRing.setSolid(color: .systemRed, icon: "heart.fill")

        heartValueLabel.text = "\(heart)"
        heartSubtitleLabel.text = "bpm"
    }
}
