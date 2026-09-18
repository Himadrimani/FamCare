//
//  MemberProgressCollectionViewCell.swift
//  HealthSharing
//
//  Created by Mohd Kushaad on 08/02/26.
//

import UIKit

class MemberProgressCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var progressPercentLabel: UILabel!
    @IBOutlet weak var progressPercentView: UIView!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var progressNumbersLabel: UILabel!
    @IBOutlet weak var memberName: UILabel!
    @IBOutlet weak var memberImage: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func configureCell(profile: Profile, completed: Double, goal: Double, metricName: String) {
    
        ImageManager.shared.setImage(for: memberImage, from: profile.profilePic)
        
        let rawProgressPercentage = (goal > 0) ? (completed / goal) * 100.0 : 0
        let progressToUse = min(rawProgressPercentage, 100.0)
        
        setImageToRound(progress: progressToUse)
        
        // Safely handle nickname or first name
        memberName.text = profile.displayName
        
        if metricName == "Completed" || metricName == "Not Completed" {
             if completed >= goal {
                 progressNumbersLabel.text = "Completed!"
             } else {
                 progressNumbersLabel.text = "Not Completed"
             }
        } else {
             if progressToUse >= 100 {
                 progressNumbersLabel.text = "Completed!"
             } else {
                 let compStr = (metricName == "km" || metricName == "hrs Slept") ? String(format: "%.1f", completed) : "\(Int(completed))"
                 let goalStr = (metricName == "km" || metricName == "hrs Slept") ? String(format: "%.1f", goal) : "\(Int(goal))"
                 progressNumbersLabel.text = "\(compStr)/\(goalStr) \(metricName)"
             }
        }
        
        // UIProgressView expects a Float between 0.0 and 1.0
        progressBar.progress = Float(progressToUse / 100.0)
        
        if progressToUse >= 100 {
            progressBar.progressTintColor = UIColor.systemGreen
        } else {
            progressBar.progressTintColor = UIColor.systemBlue
        }
        
        setProgressPercent(progress: progressToUse)
    }
    
    
    func setImageToRound(progress: Double) {
        memberImage.layer.cornerRadius = 32
        memberImage.clipsToBounds = true
        memberImage.layer.borderWidth = 1
        
        if progress == 100 {
            memberImage.layer.borderColor = UIColor.systemGreen.cgColor
        } else {
            memberImage.layer.borderColor = UIColor.systemBlue.cgColor
        }
    }
    
    
    func setProgressPercent(progress: Double) {
        
        progressPercentView.layer.cornerRadius = 12
        
        if progress == 100 {
            
            progressPercentView.backgroundColor = UIColor.systemGreen
            
            let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            
            if let symbolImage = UIImage(systemName: "checkmark.circle.fill", withConfiguration: symbolConfiguration) {
                
                let attachment = NSTextAttachment()
                attachment.image = symbolImage
                
                let attachmentString = NSAttributedString(attachment: attachment)
                
                progressPercentLabel.attributedText = attachmentString
            }
            
            return
        }
        
        progressPercentLabel.text = "\(Int(progress))%"
    }
    
    

}
