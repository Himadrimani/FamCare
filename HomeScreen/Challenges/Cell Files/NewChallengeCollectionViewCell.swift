//
//  NewChallengeCollectionViewCell.swift
//  HomeScreen
//
//  Created by Mohd Kushaad on 21/05/26.
//

import UIKit

class NewChallengeCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var timeLeftLabel: UILabel!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var modelImageView: UIImageView!
    override func awakeFromNib() {
        super.awakeFromNib()
        
        contentView.backgroundColor = .systemBackground
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.systemGray6.cgColor
        
        layer.cornerRadius = 16
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowOffset = CGSize(width: 0, height: 6)
        layer.shadowRadius = 10
    }

    func configureCell(challenge: ChallengeDetails, allProgress: [ChallengeProgress]) {
        nameLabel.text = challenge.name
        
        if challenge.bgImage == "family_trek_challenge" {
            modelImageView.contentMode = .scaleAspectFill
        }
        
        modelImageView.image = UIImage(named: challenge.bgImage)
        
        let progressRecords = allProgress.filter { $0.challengeId == challenge.challengeId }
        var totalPercentage = 0.0
        
        for record in progressRecords {
            let percentage = record.goalValue > 0 ? (record.currentValue / record.goalValue) * 100.0 : 0.0
            totalPercentage += min(100.0, percentage)
        }
        
        let progress = progressRecords.isEmpty ? 0.0 : totalPercentage / Double(progressRecords.count)
        progressLabel.text = "\(Int(progress))%"
        
        let now = Date()
        let timeInterval = challenge.endDate.timeIntervalSince(now)
        var timeText = ""
        
        if progress >= 100.0 {
            timeText = "Completed"
        } else if timeInterval > 0 {
            let days = Int(timeInterval / (3600 * 24))
            if days > 1 {
                timeText = "\(days) Days Left"
            } else if days == 1 {
                timeText = "1 Day Left"
            } else {
                let hours = Int(timeInterval / 3600)
                if hours > 0 {
                    timeText = "\(hours)hrs Left"
                } else {
                    timeText = "Time Over"
                }
            }
        } else {
            timeText = "Time Over"
        }
        
        timeLeftLabel.text = timeText
    }
    
}
