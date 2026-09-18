import UIKit

class TopicReceivedMessageCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var avatarView: UIView!
    @IBOutlet weak var avatarLabel: UILabel!
    @IBOutlet weak var senderNameLabel: UILabel!
    @IBOutlet weak var bubbleView: UIView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    func configure(with message: TopicMessage, profile: TopicProfile?, showSenderInfo: Bool) {
        messageLabel.text = message.content
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        timeLabel.text = formatter.string(from: message.createdAt ?? Date())
        
        senderNameLabel.text = profile?.displayName ?? "User"
        avatarLabel.text = String(profile?.displayName.prefix(1) ?? "U").uppercased()
        
        // Toggle visibility for clustered messages
        senderNameLabel.isHidden = !showSenderInfo
        avatarView.isHidden = !showSenderInfo
    }
}
