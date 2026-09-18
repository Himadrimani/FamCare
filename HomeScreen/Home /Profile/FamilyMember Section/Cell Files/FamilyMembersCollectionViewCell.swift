//
//  FamilyMembersCollectionViewCell.swift
//  HealthSharing
//
//  Created by Mohd Kushaad on 01/02/26.
//

import UIKit

class FamilyMembersCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var realNameTextLabel: UILabel!
    @IBOutlet weak var nickNameTextLabel: UILabel!
    @IBOutlet weak var profilePictureImage: UIImageView!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func configureCell(with member: Profile) {
        realNameTextLabel.text = member.firstName + " " + member.lastName
        realNameTextLabel.textColor = .secondaryLabel
        realNameTextLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        
        nickNameTextLabel.text = member.displayName
        nickNameTextLabel.textColor = .label
        nickNameTextLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        
        ImageManager.shared.setImage(for: profilePictureImage, from: member.profilePic)
        profilePictureImage.layer.cornerRadius = 40 // Half of width/height (80)
        profilePictureImage.clipsToBounds = true
        profilePictureImage.layer.borderWidth = 2
        profilePictureImage.layer.borderColor = UIColor.systemGray5.cgColor

        self.backgroundColor = .secondarySystemGroupedBackground
        self.layer.cornerRadius = 16
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.06
        self.layer.shadowOffset = CGSize(width: 0, height: 4)
        self.layer.shadowRadius = 8
        self.layer.masksToBounds = false
    }

}
