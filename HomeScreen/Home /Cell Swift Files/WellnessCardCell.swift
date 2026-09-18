//
//  WellnessCardCell.swift
//  HomeScreen
//
//  Created by Himadri on 02/02/26.
//

import UIKit

class WellnessCardCell: UICollectionViewCell {
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var primaryValueLabel: UILabel!
    @IBOutlet weak var secondaryValueLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 20
    }
    
    func configure(with card: WellnessCard) { // function to populate data into cell
        titleLabel.text = card.title
        titleLabel.textColor = card.iconColor  
        iconImageView.isHidden = false
        iconImageView.image = UIImage(systemName: card.icon)
        iconImageView.tintColor = card.iconColor
        
        titleLabel.text = card.title
        primaryValueLabel.text = card.primaryValue
        
        if let secondary = card.secondaryValue,
           !secondary.isEmpty {
            secondaryValueLabel.text = secondary
            secondaryValueLabel.isHidden = false
        } else {
            secondaryValueLabel.isHidden = true 
        }
        
    }
}
