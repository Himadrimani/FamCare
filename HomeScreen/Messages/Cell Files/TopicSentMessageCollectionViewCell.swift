import UIKit

class TopicSentMessageCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var bubbleView: UIView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    
    private let sharedCardView = SharedCardView()
    private var originalBubbleColor: UIColor?
    
    var onViewCardTapped: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
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
    }

    func configure(with message: TopicMessage) {
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
    }
}
