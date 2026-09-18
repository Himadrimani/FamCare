import UIKit

class ChallengeReceivedMessageCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var bubbleView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var challengeNameLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func configure(with message: Message, challenge: ChallengeDetails?) {
        var displayMsg = message.message
        if displayMsg.contains("#FFF00F)") {
            let content = displayMsg.components(separatedBy: "#FFF00F)").last ?? ""
            let parts = content.components(separatedBy: "|")
            if parts.count >= 2 {
                displayMsg = parts.dropFirst().joined(separator: "|")
            } else {
                displayMsg = content
            }
        }
        
        if let challengeInfo = challenge {
            challengeNameLabel.text = "🏆 \(challengeInfo.name)"
        } else {
            challengeNameLabel.text = "🏆 Challenge"
        }
        
        messageLabel.text = "\"\(displayMsg)\""
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

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
