import UIKit

class TopicReceivedMessageCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var avatarView: UIView!
    @IBOutlet weak var avatarLabel: UILabel!
    @IBOutlet weak var senderNameLabel: UILabel!
    @IBOutlet weak var bubbleView: UIView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    
    private let sharedCardView = SharedCardView()
    private var originalBubbleColor: UIColor?
    
    var onViewCardTapped: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Modern iOS 27 bubble styling
        bubbleView.layer.cornerRadius = 18
        bubbleView.layer.cornerCurve = .continuous
        bubbleView.backgroundColor = .secondarySystemGroupedBackground
        bubbleView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner, .layerMinXMinYCorner]
        
        messageLabel.textColor = .label
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        
        // Also ensure avatar is rounded properly
        avatarView.layer.cornerRadius = avatarView.bounds.width / 2
        avatarView.clipsToBounds = true
        
        originalBubbleColor = bubbleView.backgroundColor
        
        sharedCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sharedCardView)
        NSLayoutConstraint.activate([
            sharedCardView.topAnchor.constraint(equalTo: bubbleView.topAnchor),
            sharedCardView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
            sharedCardView.widthAnchor.constraint(equalToConstant: 280)
        ])
        
        sharedCardView.onViewTapped = { [weak self] in
            self?.onViewCardTapped?()
        }
    }

    func configure(with message: TopicMessage, profile: TopicProfile?, showSenderInfo: Bool) {
        if sharedCardView.configure(with: message.content) {
            bubbleView.backgroundColor = .clear
            messageLabel.isHidden = true
            sharedCardView.isHidden = false
        } else {
            bubbleView.backgroundColor = originalBubbleColor
            messageLabel.isHidden = false
            sharedCardView.isHidden = true
            messageLabel.text = message.content
        }
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
