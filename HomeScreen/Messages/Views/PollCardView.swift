import UIKit

class PollCardView: UIView {
    
    // Callbacks
    var onVoteTapped: ((String) -> Void)?
    
    // UI Elements
    private let cardContainer = UIView()
    private let questionLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let optionsStackView = UIStackView()
    private let separatorView = UIView()
    private let footerStackView = UIStackView()
    private let totalVotesLabel = UILabel()
    private let timeLabel = UILabel()
    
    private var currentPoll: PollData?
    private var optionRowViews: [UIView] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        // Card Container
        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.backgroundColor = .secondarySystemGroupedBackground
        cardContainer.layer.cornerRadius = 16
        cardContainer.layer.cornerCurve = .continuous
        cardContainer.layer.borderWidth = 0.5
        cardContainer.layer.borderColor = UIColor.separator.withAlphaComponent(0.4).cgColor
        cardContainer.clipsToBounds = true
        addSubview(cardContainer)
        
        NSLayoutConstraint.activate([
            cardContainer.topAnchor.constraint(equalTo: topAnchor),
            cardContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            cardContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardContainer.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        
        // Question Label
        questionLabel.font = .systemFont(ofSize: 16, weight: .bold)
        questionLabel.textColor = .label
        questionLabel.numberOfLines = 0
        questionLabel.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(questionLabel)
        
        // Subtitle Label
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(subtitleLabel)
        
        // Options Stack
        optionsStackView.axis = .vertical
        optionsStackView.spacing = 8
        optionsStackView.alignment = .fill
        optionsStackView.distribution = .fill
        optionsStackView.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(optionsStackView)
        
        // Separator
        separatorView.backgroundColor = UIColor.separator.withAlphaComponent(0.3)
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(separatorView)
        
        // Footer Stack
        footerStackView.axis = .horizontal
        footerStackView.alignment = .center
        footerStackView.distribution = .equalSpacing
        footerStackView.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(footerStackView)
        
        totalVotesLabel.font = .systemFont(ofSize: 12, weight: .medium)
        totalVotesLabel.textColor = .secondaryLabel
        footerStackView.addArrangedSubview(totalVotesLabel)
        
        timeLabel.font = .systemFont(ofSize: 11, weight: .regular)
        timeLabel.textColor = .tertiaryLabel
        footerStackView.addArrangedSubview(timeLabel)
        
        NSLayoutConstraint.activate([
            questionLabel.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 14),
            questionLabel.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 14),
            questionLabel.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -14),
            
            subtitleLabel.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: questionLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: questionLabel.trailingAnchor),
            
            optionsStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            optionsStackView.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 14),
            optionsStackView.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -14),
            
            separatorView.topAnchor.constraint(equalTo: optionsStackView.bottomAnchor, constant: 12),
            separatorView.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 14),
            separatorView.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -14),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5),
            
            footerStackView.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: 8),
            footerStackView.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 14),
            footerStackView.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -14),
            footerStackView.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -10)
        ])
    }
    
    @discardableResult
    func configure(with messageContent: String, timestamp: Date? = nil) -> Bool {
        guard let poll = PollData.parse(from: messageContent) else {
            return false
        }
        self.currentPoll = poll
        
        questionLabel.text = poll.question
        subtitleLabel.text = poll.allowsMultipleAnswers ? "Select one or more" : "Select one"
        
        let totalVotes = poll.totalVotes
        totalVotesLabel.text = totalVotes == 1 ? "1 vote" : "\(totalVotes) votes"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        timeLabel.text = formatter.string(from: timestamp ?? poll.createdAt)
        
        let currentUserId = DataManager.shared.currentUser?.profileId
        let maxVotesInAnyOption = poll.options.map { $0.voteCount }.max() ?? 0
        
        // Rebuild option rows
        optionsStackView.arrangedSubviews.forEach {
            optionsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        optionRowViews.removeAll()
        
        for option in poll.options {
            let row = createOptionRow(
                option: option,
                totalVotes: totalVotes,
                maxVotes: maxVotesInAnyOption,
                isVotedByMe: currentUserId != nil && option.voterIds.contains(currentUserId!)
            )
            optionsStackView.addArrangedSubview(row)
            optionRowViews.append(row)
        }
        
        return true
    }
    
    private func createOptionRow(
        option: PollData.PollOption,
        totalVotes: Int,
        maxVotes: Int,
        isVotedByMe: Bool
    ) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.layer.cornerRadius = 10
        container.layer.cornerCurve = .continuous
        container.clipsToBounds = true
        container.backgroundColor = .systemGray6
        container.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        // Progress fill
        let progressView = UIView()
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.backgroundColor = isVotedByMe
            ? UIColor.systemBlue.withAlphaComponent(0.18)
            : UIColor.systemGray4.withAlphaComponent(0.4)
        container.addSubview(progressView)
        
        let fraction: CGFloat = totalVotes > 0 ? CGFloat(option.voteCount) / CGFloat(totalVotes) : 0.0
        
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: container.topAnchor),
            progressView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            progressView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            progressView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: fraction)
        ])
        
        // Border highlight if user voted for this option
        if isVotedByMe {
            container.layer.borderWidth = 1.5
            container.layer.borderColor = UIColor.systemBlue.cgColor
        } else {
            container.layer.borderWidth = 0.5
            container.layer.borderColor = UIColor.separator.withAlphaComponent(0.3).cgColor
        }
        
        // Content Stack
        let contentStack = UIStackView()
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.isUserInteractionEnabled = false
        container.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: container.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            contentStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10)
        ])
        
        // Checkmark / Radio Icon
        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        let iconName = isVotedByMe ? "checkmark.circle.fill" : "circle"
        iconView.image = UIImage(systemName: iconName)
        iconView.tintColor = isVotedByMe ? .systemBlue : .systemGray3
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20)
        ])
        contentStack.addArrangedSubview(iconView)
        
        // Option Text
        let label = UILabel()
        label.text = option.text
        label.font = .systemFont(ofSize: 14, weight: isVotedByMe ? .semibold : .medium)
        label.textColor = .label
        label.lineBreakMode = .byTruncatingTail
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentStack.addArrangedSubview(label)
        
        // Trailing: Avatar Stack + Vote Count
        let trailingStack = UIStackView()
        trailingStack.axis = .horizontal
        trailingStack.alignment = .center
        trailingStack.spacing = 6
        
        if option.voteCount > 0 {
            // Mini voter avatars
            let avatarsContainer = makeMiniAvatarStack(for: option.voterIds)
            trailingStack.addArrangedSubview(avatarsContainer)
            
            let countLabel = UILabel()
            countLabel.text = "\(option.voteCount)"
            countLabel.font = .systemFont(ofSize: 13, weight: .semibold)
            countLabel.textColor = isVotedByMe ? .systemBlue : .secondaryLabel
            trailingStack.addArrangedSubview(countLabel)
        }
        
        contentStack.addArrangedSubview(trailingStack)
        
        // Tap Gesture
        let tap = UITapGestureRecognizer(target: self, action: #selector(optionTapped(_:)))
        container.addGestureRecognizer(tap)
        container.accessibilityIdentifier = option.id
        container.isUserInteractionEnabled = true
        
        return container
    }
    
    private func makeMiniAvatarStack(for voterIds: [UUID]) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        var profileMap: [UUID: Profile] = [:]
        for p in SQLiteHelper.shared.fetchProfiles() {
            profileMap[p.profileId] = p
        }
        for p in DataManager.shared.allProfiles {
            profileMap[p.profileId] = p
        }
        if let current = DataManager.shared.currentUser {
            profileMap[current.profileId] = current
        }
        
        let displayVoterIds = Array(voterIds.prefix(6))
        let avatarSize: CGFloat = 16
        let overlap: CGFloat = 5
        let count = displayVoterIds.count
        let totalWidth = count > 0 ? (CGFloat(count) * (avatarSize - overlap) + overlap) : avatarSize
        
        container.widthAnchor.constraint(equalToConstant: max(avatarSize, totalWidth)).isActive = true
        container.heightAnchor.constraint(equalToConstant: avatarSize).isActive = true
        
        for (index, id) in displayVoterIds.enumerated() {
            let iv = UIImageView()
            iv.frame = CGRect(x: CGFloat(index) * (avatarSize - overlap), y: 0, width: avatarSize, height: avatarSize)
            iv.layer.cornerRadius = avatarSize / 2
            iv.clipsToBounds = true
            iv.layer.borderWidth = 1
            iv.layer.borderColor = UIColor.systemBackground.cgColor
            iv.contentMode = .scaleAspectFill
            
            if let profile = profileMap[id] {
                ImageManager.shared.setImage(for: iv, from: profile.profilePic)
            } else {
                iv.image = UIImage(systemName: "person.circle.fill")
                iv.tintColor = .systemGray3
            }
            container.addSubview(iv)
        }
        
        return container
    }
    
    @objc private func optionTapped(_ sender: UITapGestureRecognizer) {
        guard let optionId = sender.view?.accessibilityIdentifier else { return }
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        onVoteTapped?(optionId)
    }
    
    // MARK: - Dynamic Height Calculation
    static func calculateHeight(for messageContent: String, width: CGFloat) -> CGFloat {
        guard let poll = PollData.parse(from: messageContent) else { return 200 }
        
        let cardWidth = min(width - 40, 290)
        let contentWidth = cardWidth - 28 // 14pt padding on each side
        
        let questionFont = UIFont.systemFont(ofSize: 16, weight: .bold)
        let constraintRect = CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
        let boundingBox = poll.question.boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: questionFont],
            context: nil
        )
        let questionHeight = ceil(boundingBox.height)
        
        let subtitleHeight: CGFloat = 16
        let optionsHeight = CGFloat(poll.options.count) * 44 + CGFloat(max(0, poll.options.count - 1)) * 8
        let separatorHeight: CGFloat = 1
        let footerHeight: CGFloat = 20
        let verticalPaddings: CGFloat = 14 + 4 + 12 + 12 + 8 + 10 // Pinned constraints
        
        let total = questionHeight + subtitleHeight + optionsHeight + separatorHeight + footerHeight + verticalPaddings
        return total + 16 // Margin buffer for cell
    }
}
