//
//  DataHeaderCollectionViewCell.swift
//  HealthSharing
//
//  Created by GEU on 07/02/26.
//

import UIKit

class DateHeaderCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    func configure(title: String) {
        titleLabel.text = title
    }

}
