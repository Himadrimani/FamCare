//
//  ChallengeCollectionViewCell.swift
//  HealthSharing
//
//  Created by Mohd Kushaad on 08/02/26.
//

import UIKit

class ChallengeCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var challengeProgressView: UIProgressView!
    @IBOutlet weak var challengeNameLabel: UILabel!
    @IBOutlet weak var bgImage: UIImageView!
    @IBOutlet weak var timeLeftLabel: UILabel!
    
    let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
    let avatarsStackView = UIStackView()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Add Blur Effect
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.alpha = 0.6
        bgImage.addSubview(blurEffectView)
        NSLayoutConstraint.activate([
            blurEffectView.topAnchor.constraint(equalTo: bgImage.topAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: bgImage.bottomAnchor),
            blurEffectView.leadingAnchor.constraint(equalTo: bgImage.leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: bgImage.trailingAnchor)
        ])
        
        // Setup Avatars Stack View
        avatarsStackView.axis = .horizontal
        avatarsStackView.spacing = -10
        avatarsStackView.distribution = .fillEqually
        avatarsStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(avatarsStackView)
        
        NSLayoutConstraint.activate([
            avatarsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            avatarsStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
            avatarsStackView.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // Progress Bar Aesthetics
        challengeProgressView.progressTintColor = .systemGreen
        challengeProgressView.trackTintColor = .systemGray4
        challengeProgressView.layer.cornerRadius = 3
        challengeProgressView.clipsToBounds = true
        challengeProgressView.transform = CGAffineTransform(scaleX: 1.0, y: 3.0)
        
        // Make cell look a bit round
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
    }

    func configureCell(challenge: ChallengeDetails, allProgress: [ChallengeProgress]) {
        
        let name = challenge.name
        
        // Compute progress dynamically
        let progressRecords = allProgress.filter { $0.challengeId == challenge.challengeId }
        var totalPercentage = 0.0
        
        for record in progressRecords {
            let percentage = record.goalValue > 0 ? (record.currentValue / record.goalValue) * 100.0 : 0.0
            totalPercentage += min(100.0, percentage)
        }
        
        let progress = progressRecords.isEmpty ? 0.0 : totalPercentage / Double(progressRecords.count)
        
        challengeNameLabel.text = name //update name label
        challengeProgressView.progress = Float(progress) / 100.0
        progressLabel.text = "\(Int(progress))% Completed"
        bgImage.image = UIImage(named: challenge.bgImage)
        
        // Configure Time Left Label
        let now = Date()
        let timeInterval = challenge.endDate.timeIntervalSince(now)
        var timeText = ""
        var isCompleted = false
        
        if progress >= 100.0 {
            timeText = "Completed "
            isCompleted = true
            timeLeftLabel.textColor = .systemGreen
        } else if timeInterval > 0 {
            let days = Int(timeInterval / (3600 * 24))
            if days > 0 {
                timeText = "\(days) days "
            } else {
                let hours = Int(timeInterval / 3600)
                timeText = "\(hours) hrs "
            }
            timeLeftLabel.textColor = .label
        } else {
            timeText = "Ended "
            timeLeftLabel.textColor = .systemRed
        }
        
        let attachment = NSTextAttachment()
        if isCompleted {
            attachment.image = UIImage(systemName: "checkmark.circle.fill")?.withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
        } else {
            attachment.image = UIImage(systemName: "clock.fill")?.withTintColor(timeLeftLabel.textColor, renderingMode: .alwaysOriginal)
        }
        
        let imageString = NSAttributedString(attachment: attachment)
        let textString = NSMutableAttributedString(string: timeText)
        textString.append(imageString)
        timeLeftLabel.attributedText = textString
        
        // Configure Profile Pictures
        avatarsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let memberIDs = progressRecords.map { $0.memberId.uuidString }
        var displayProfiles: [Profile] = []
        if let user = DataManager.shared.currentUser {
            let allFamily = [user] + DataManager.shared.allProfiles
            for pid in memberIDs {
                if let p = allFamily.first(where: { $0.profileId.uuidString == pid }) {
                    displayProfiles.append(p)
                }
            }
        }
        
        // Display profiles (if individual, progressRecords should only have 1 entry)
        for profile in displayProfiles {
            let imageView = UIImageView()
                            ImageManager.shared.setImage(for: imageView, from: profile.profilePic)
            imageView.contentMode = .scaleAspectFill
            imageView.layer.cornerRadius = 15 // half of height 30
            imageView.layer.masksToBounds = true
            imageView.layer.borderWidth = 1.5
            
            let progressRecord = progressRecords.first { $0.memberId == profile.profileId }
            let memberScore = progressRecord.map { $0.goalValue > 0 ? ($0.currentValue / $0.goalValue) * 100.0 : 0.0 } ?? 0.0
            
            if memberScore >= 100.0 {
                imageView.layer.borderColor = UIColor.systemGreen.cgColor
            } else {
                imageView.layer.borderColor = UIColor.white.cgColor
            }
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalToConstant: 30).isActive = true
            avatarsStackView.addArrangedSubview(imageView)
        }
    }
}
