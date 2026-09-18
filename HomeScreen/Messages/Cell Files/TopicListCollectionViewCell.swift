import UIKit

class TopicListCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var lastMessageLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var unreadIndicator: UIView!
    @IBOutlet weak var badgeLabel: UILabel!
    
    @IBOutlet weak var avatarStackView: UIStackView!
    @IBOutlet weak var chevronImageView: UIImageView!

    private enum Layout {
        static let avatarSize: CGFloat = 32
        static let avatarOverlap: CGFloat = -10
        static let borderWidth: CGFloat = 2
    }

    override func awakeFromNib() {
        super.awakeFromNib()
    }


    func configure(with topic: Topic, latestMessage: TopicMessage?, unreadCount: Int, members: [TopicProfile] = []) {
        nameLabel.text = topic.title

        let hasUnread = unreadCount > 0
        unreadIndicator.isHidden = !hasUnread

        if hasUnread {
            badgeLabel.text = unreadCount > 99 ? "99+" : "\(unreadCount)"
        }

        if let msg = latestMessage {
            lastMessageLabel.text = msg.content
            timeLabel.text = formattedTime(from: msg.createdAt ?? Date())
            lastMessageLabel.font = hasUnread ? .systemFont(ofSize: 15, weight: .semibold) : .systemFont(ofSize: 15)
            lastMessageLabel.textColor = hasUnread ? .label : .secondaryLabel
        } else {
            lastMessageLabel.text = "No messages yet"
            lastMessageLabel.font = .italicSystemFont(ofSize: 15)
            lastMessageLabel.textColor = .secondaryLabel
            timeLabel.text = formattedTime(from: topic.createdAt ?? Date())
        }
        
        // Clear previous avatars
        avatarStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add in REVERSE order so index-0 renders on top (highest z-order = last added)
        for member in members.reversed() {
            let iv = makeAvatarImageView(for: member)
            avatarStackView.addArrangedSubview(iv)
        }

        // Raise z-index progressively so left avatars sit on top of right ones
        for (index, view) in avatarStackView.arrangedSubviews.reversed().enumerated() {
            view.layer.zPosition = CGFloat(index)
        }
    }

    // MARK: - Avatar Factory

    private func makeAvatarImageView(for member: TopicProfile) -> UIImageView {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = Layout.avatarSize / 2
        iv.layer.borderWidth = Layout.borderWidth
        iv.layer.borderColor = UIColor.systemBackground.cgColor
        iv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iv.widthAnchor.constraint(equalToConstant: Layout.avatarSize),
            iv.heightAnchor.constraint(equalToConstant: Layout.avatarSize)
        ])

        // Use ImageManager to load from cache/network/bundle (consistent with the rest of the app)
        ImageManager.shared.setImage(for: iv, from: member.avatarUrl)
        return iv
    }

    // MARK: - Helpers

    private func formattedTime(from date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: date)
    }
}
