//
//  ChallengeDetailCollectionViewCell.swift
//  ChallengeCell
//
//  Created by GEU on 09/02/26.
//

import UIKit

class ChallengeDetailCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var timeLeft: UILabel!
    @IBOutlet weak var progressPercentValue: UILabel!
    @IBOutlet weak var progressPercentView: UIView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var numberOfMemberCompletedLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    // time left for challenge to end removed to fix redeclaration.
    
    let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Add Blur Effect
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.alpha = 0.6
        imageView.addSubview(blurEffectView)
        NSLayoutConstraint.activate([
            blurEffectView.topAnchor.constraint(equalTo: imageView.topAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            blurEffectView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor)
        ])
        
        // Make cell slightly rounded to match other cells
//        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        
        // Initialization code
        
        descriptionLabel.numberOfLines = 0
        descriptionLabel.lineBreakMode = .byWordWrapping
        
        numberOfMemberCompletedLabel.numberOfLines = 0
        numberOfMemberCompletedLabel.lineBreakMode = .byWordWrapping
        
        timeLeft.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    func configure(with challenge: ChallengeDetails, percentageCompleted: Double, completedOverrides: Int? = nil, totalOverrides: Int? = nil) {
        descriptionLabel.text = challenge.description
        
        let completedCount = completedOverrides ?? 0
        let totalMembers = totalOverrides ?? 1
        
        numberOfMemberCompletedLabel.text = "\(completedCount)/\(totalMembers) Completed"
        
        imageView.image = UIImage(named: challenge.bgImage)
        setProgressPercent(progress: percentageCompleted)
        
        let now = Date()
        let interval = challenge.endDate.timeIntervalSince(now)
        
        if percentageCompleted >= 100 {
            timeLeft.text = "Completed"
            timeLeft.textColor = .systemGreen
        } else if interval <= 0 {
            timeLeft.text = "Expired"
            timeLeft.textColor = .systemRed
        } else {
            let days = Int(interval / (3600 * 24))
            var timeText = ""
            if days > 0 {
                timeText = "\(days) days left"
            } else {
                let hours = Int(interval / 3600)
                timeText = "\(hours) hrs left"
            }
            timeLeft.text = timeText
            timeLeft.textColor = .label
        }
    }
    
    func setProgressPercent(progress: Double) {
        progressPercentView.layer.cornerRadius = 12
        
        if progress == 100 {
            progressPercentView.backgroundColor = UIColor.systemGreen
            
            let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .black)
            if let symbolImage = UIImage(systemName: "checkmark.circle.fill", withConfiguration: symbolConfiguration) {
                
                // 2. Create the attachment
                let attachment = NSTextAttachment()
                attachment.image = symbolImage
                
                // 3. Create the attributed string
                let attachmentString = NSAttributedString(attachment: attachment)
                
                // 4. Assign it to your label
                progressPercentValue.attributedText = attachmentString
            }
            return
        }
        progressPercentValue.text = "\(Int(progress))%"
    }
    
}
