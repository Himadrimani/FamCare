import UIKit

class TopicSentMessageCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var bubbleView: UIView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    func configure(with message: TopicMessage) {
        messageLabel.text = message.content
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        timeLabel.text = formatter.string(from: message.createdAt ?? Date())
    }
}
