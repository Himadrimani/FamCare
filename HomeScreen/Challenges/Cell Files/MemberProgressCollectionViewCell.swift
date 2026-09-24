//
//  MemberProgressCollectionViewCell.swift
//  HealthSharing
//
//  Created by Mohd Kushaad on 08/02/26.
//

import UIKit

protocol MemberProgressCellDelegate: AnyObject {
    func memberProgressCellDidTapShare(_ cell: MemberProgressCollectionViewCell)
}

class MemberProgressCollectionViewCell: UICollectionViewCell {
    
    weak var delegate: MemberProgressCellDelegate?
    
    private let shareButton = UIButton(type: .system)
    private let topHighlightView = UIView()
    
    @IBOutlet weak var progressPercentLabel: UILabel!
    @IBOutlet weak var progressPercentView: UIView!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var progressNumbersLabel: UILabel!
    @IBOutlet weak var memberName: UILabel!
    @IBOutlet weak var memberImage: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        contentView.clipsToBounds = true
        topHighlightView.translatesAutoresizingMaskIntoConstraints = false
        topHighlightView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.06)
        topHighlightView.layer.cornerRadius = 60
        contentView.insertSubview(topHighlightView, at: 0)
        
        NSLayoutConstraint.activate([
            topHighlightView.widthAnchor.constraint(equalToConstant: 120),
            topHighlightView.heightAnchor.constraint(equalToConstant: 120),
            topHighlightView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 40),
            topHighlightView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: -40)
        ])
        
        setupShareButton()
    }
    
    private func setupShareButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let shareIcon = UIImage(systemName: "bubble", withConfiguration: config)
        shareButton.setImage(shareIcon, for: .normal)
        shareButton.tintColor = .systemBlue
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        
        contentView.addSubview(shareButton)
        
        NSLayoutConstraint.activate([
            shareButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            shareButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            shareButton.widthAnchor.constraint(equalToConstant: 30),
            shareButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    @objc private func shareTapped() {
        delegate?.memberProgressCellDidTapShare(self)
    }
    
    func configureCell(profile: Profile, completed: Double, goal: Double, metricName: String) {
    
        let currentUserId = DataManager.shared.currentUser?.profileId
        shareButton.isHidden = (profile.profileId == currentUserId)
    
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
