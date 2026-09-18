import UIKit

class MessageCollectionViewCell: UICollectionViewCell {
    
    private let dataManager = DataManager.shared

    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var lastMessageLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var badgeView: UIView!
    @IBOutlet weak var badgeLabel: UILabel!
    
    @IBOutlet weak var chevronImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    
    // Shared date formatter for performance
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        return formatter
    }()
    
    
    func configure(with profile: Profile, lastMessage: Message?, currentUserId: UUID?, unreadCount: Int = 0) {
        let hasUnread = unreadCount > 0

        nameLabel.text = profile.displayName
        ImageManager.shared.setImage(for: imageView, from: profile.profilePic)
        
        if let message = lastMessage {
            var displayMsg = message.message
            if displayMsg.contains("#FFF00F)") {
                let content = displayMsg.components(separatedBy: "#FFF00F)").last ?? ""
                let parts = content.components(separatedBy: "|")
                let motivatingMsg = parts.count >= 2 ? parts.dropFirst().joined(separator: "|").trimmingCharacters(in: .whitespacesAndNewlines) : content.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !motivatingMsg.isEmpty {
                    displayMsg = "🏆 Challenge Update: \(motivatingMsg)"
                } else {
                    displayMsg = "🏆 Challenge Update"
                }
            }
            lastMessageLabel.text = displayMsg
            timeLabel.text = formattedTime(from: message.timestampUTC)
        } else {
            lastMessageLabel.text = "Start a conversation"
            timeLabel.text = ""
        }
        
        // Match Topic List unread styling
        badgeView.isHidden = !hasUnread
        if hasUnread {
            badgeLabel.text = unreadCount > 99 ? "99+" : "\(unreadCount)"
            lastMessageLabel.font = .systemFont(ofSize: 15, weight: .semibold)
            lastMessageLabel.textColor = .label
        } else {
            lastMessageLabel.font = .systemFont(ofSize: 15)
            lastMessageLabel.textColor = .secondaryLabel
        }
    }
    
    private func formattedTime(from date: Date) -> String {
        let formatter = Self.dateFormatter
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: date)
    }
    
    private func displayName(for userId: UUID) -> String {
        if let profile = dataManager.allProfiles.first(where: { $0.profileId == userId }) {
            return profile.displayName
        }
        if let user = dataManager.currentUser, user.profileId == userId {
            return user.displayName
        }
        return "User"
    }

    private func profileImage(for userId: UUID) -> UIImage {
        if dataManager.allProfiles.contains(where: { $0.profileId == userId }) {
            // Custom return not possible here, let caller handle setImage if needed (will address manually if needed)
        }
        if let user = dataManager.currentUser, user.profileId == userId {
            return UIImage(named: user.profilePic) ?? UIImage(systemName: "person.fill")!
        }
        return UIImage(systemName: "person.fill")!
    }
}
