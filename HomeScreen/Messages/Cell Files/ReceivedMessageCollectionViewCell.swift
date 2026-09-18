//
//  ReceivedMessageCollectionViewCell.swift
//  HealthSharing
//
//  Created by GEU on 06/02/26.
//

import UIKit

class ReceivedMessageCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var bubbleView: UIView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func configure(with message: Message) {
        messageLabel.text = message.message
        timeLabel.text = formatTime(message.timestampUTC)
    }
    
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let targetSize = CGSize(width: layoutAttributes.frame.width, height: 0)
        let autoLayoutSize = contentView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        let frame = CGRect(
            x: layoutAttributes.frame.origin.x,
            y: layoutAttributes.frame.origin.y,
            width: layoutAttributes.frame.width,
            height: autoLayoutSize.height
        )
        
        layoutAttributes.frame = frame
        return layoutAttributes
    }

    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

}
