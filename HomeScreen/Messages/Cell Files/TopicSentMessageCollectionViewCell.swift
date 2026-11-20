import UIKit

class TopicSentMessageCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var bubbleView: UIView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    
    private let sharedCardView = SharedCardView()
    private let pollCardView = PollCardView()
    private var originalBubbleColor: UIColor?
    
    var onViewCardTapped: (() -> Void)?
    var onVoteTapped: ((String) -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Modern iOS 27 bubble styling
        bubbleView.layer.cornerRadius = 18
        bubbleView.layer.cornerCurve = .continuous
        bubbleView.backgroundColor = .systemBlue
        bubbleView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner]
        
        messageLabel.textColor = .white
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        
        originalBubbleColor = bubbleView.backgroundColor
        
        sharedCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sharedCardView)
        NSLayoutConstraint.activate([
            sharedCardView.topAnchor.constraint(equalTo: bubbleView.topAnchor),
            sharedCardView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor),
            sharedCardView.widthAnchor.constraint(equalToConstant: 280)
        ])
        
        sharedCardView.onViewTapped = { [weak self] in
            self?.onViewCardTapped?()
        }
        
        pollCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pollCardView)
        NSLayoutConstraint.activate([
            pollCardView.topAnchor.constraint(equalTo: bubbleView.topAnchor),
            pollCardView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor),
            pollCardView.widthAnchor.constraint(equalToConstant: 290)
        ])
        
        pollCardView.onVoteTapped = { [weak self] optionId in
            self?.onVoteTapped?(optionId)
        }
    }

    func configure(with message: TopicMessage) {
        if pollCardView.configure(with: message.content, timestamp: message.createdAt) {
            bubbleView.backgroundColor = .clear
            messageLabel.isHidden = true
            timeLabel.isHidden = true
            sharedCardView.isHidden = true
            pollCardView.isHidden = false
        } else if sharedCardView.configure(with: message.content) {
            bubbleView.backgroundColor = .clear
            messageLabel.isHidden = true
            timeLabel.isHidden = false
            pollCardView.isHidden = true
            sharedCardView.isHidden = false
        } else {
            bubbleView.backgroundColor = originalBubbleColor
            messageLabel.isHidden = false
            timeLabel.isHidden = false
            pollCardView.isHidden = true
            sharedCardView.isHidden = true
            messageLabel.text = message.content
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        timeLabel.text = formatter.string(from: message.createdAt ?? Date())
    }
}
