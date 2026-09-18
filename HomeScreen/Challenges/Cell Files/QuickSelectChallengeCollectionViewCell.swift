//
//  QuickSelectChallengeCollectionViewCell.swift
//  HomeScreen
//
//  Created by Mohd Kushaad on 27/04/26.
//

import UIKit

class QuickSelectChallengeCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var challengeNameLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func configureCell(with challenge: AddChallengeFirstViewController.QuickChallenge) {
        challengeNameLabel.text = challenge.name
    }

}
