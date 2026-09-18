//
//  TaskDetailFamilyMemberCollectionViewCell.swift
//  HomeScreen
//
//  Created by Mohd Kushaad on 27/04/26.
//

import UIKit

class TaskDetailFamilyMemberCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var progressView: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var profilePicture: UIImageView!
    override func awakeFromNib() {
        super.awakeFromNib()
        progressView.layer.cornerRadius = 16
        profilePicture.layer.cornerRadius = 22
        profilePicture.clipsToBounds = true
    }

}
