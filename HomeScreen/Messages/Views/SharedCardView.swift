import UIKit

class SharedCardView: UIView {
    

    private let oldChallengeContainer = UIView()

    // Challenge Specific UI
    private let challengeBgImageView = UIImageView()
    private let challengeTitleLabel = UILabel()
    
    private let challengePercentLabel = UILabel()
    private let challengeInfoLabel = UILabel()
    
    private let challengeAvatarStack = UIStackView()
    private let challengeViewButton = UIButton(type: .system)

    
    // Insight Specific UI
    private let newInsightContainer = UIView()
    private let insightCategoryLabel = UILabel()
    private let insightNameLabel = UILabel()
    private let insightIconBgView = UIView()
    private let insightIconImageView = UIImageView()
    private let insightRingView = CircularRingView()
    private let insightScoreLabel = UILabel()
    private let insightPeriodLabel = UILabel()
    private let insightTrendLabel = UILabel()

    // Top Row
    private let bgView = UIView()





    
    // Title

    
    // Stats




    
    // Progress



    
    // Bottom Row



    
    var onViewTapped: (() -> Void)?
    var challengeData: (String, UUID)? // Store challenge name/family ID or anything if needed
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        self.backgroundColor = .clear
        
        // Background
        bgView.translatesAutoresizingMaskIntoConstraints = false
        bgView.layer.cornerRadius = 24
        bgView.layer.cornerCurve = .continuous
        bgView.backgroundColor = UIColor(red: 0.08, green: 0.17, blue: 0.30, alpha: 1.0)
        bgView.clipsToBounds = true
        self.addSubview(bgView)

        // Layout wrapper
        let mainStackView = UIStackView(arrangedSubviews: [oldChallengeContainer, newInsightContainer])
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        mainStackView.axis = .vertical
        bgView.addSubview(mainStackView)
        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: bgView.topAnchor),
            mainStackView.bottomAnchor.constraint(equalTo: bgView.bottomAnchor),
            mainStackView.leadingAnchor.constraint(equalTo: bgView.leadingAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: bgView.trailingAnchor)
        ])
        
        oldChallengeContainer.translatesAutoresizingMaskIntoConstraints = false
        newInsightContainer.translatesAutoresizingMaskIntoConstraints = false
        
        setupNewInsightUI()
        setupChallengeUI()
        
        NSLayoutConstraint.activate([
            bgView.topAnchor.constraint(equalTo: self.topAnchor),
            bgView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            bgView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            bgView.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        ])
    }
    


    private func setupChallengeUI() {
        // Background Image
        challengeBgImageView.translatesAutoresizingMaskIntoConstraints = false
        challengeBgImageView.contentMode = .scaleAspectFill
        challengeBgImageView.alpha = 0.15
        challengeBgImageView.clipsToBounds = true
        challengeBgImageView.setContentHuggingPriority(.init(1), for: .vertical)
        challengeBgImageView.setContentHuggingPriority(.init(1), for: .horizontal)
        challengeBgImageView.setContentCompressionResistancePriority(.init(1), for: .vertical)
        challengeBgImageView.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        oldChallengeContainer.addSubview(challengeBgImageView)
        
        // Title Label
        challengeTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        challengeTitleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        challengeTitleLabel.textColor = .white
        challengeTitleLabel.numberOfLines = 2
        oldChallengeContainer.addSubview(challengeTitleLabel)
        
        // Percentage
        challengePercentLabel.translatesAutoresizingMaskIntoConstraints = false
        challengePercentLabel.font = .systemFont(ofSize: 48, weight: .black)
        challengePercentLabel.textColor = .white
        challengePercentLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        oldChallengeContainer.addSubview(challengePercentLabel)
        
        // Info Label
        challengeInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        challengeInfoLabel.font = .systemFont(ofSize: 14, weight: .medium)
        challengeInfoLabel.textColor = UIColor(white: 1.0, alpha: 0.6)
        challengeInfoLabel.numberOfLines = 0
        challengeInfoLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        oldChallengeContainer.addSubview(challengeInfoLabel)
        
        // Avatar Stack
        challengeAvatarStack.translatesAutoresizingMaskIntoConstraints = false
        challengeAvatarStack.axis = .horizontal
        challengeAvatarStack.spacing = -12
        challengeAvatarStack.distribution = .fillEqually
        oldChallengeContainer.addSubview(challengeAvatarStack)
        
        // View Button
        challengeViewButton.translatesAutoresizingMaskIntoConstraints = false
        challengeViewButton.backgroundColor = UIColor(red: 0.40, green: 0.85, blue: 1.0, alpha: 1.0) // Sky Blue
        challengeViewButton.setTitle("View challenge", for: .normal)
        challengeViewButton.setTitleColor(.black, for: .normal)
        challengeViewButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        challengeViewButton.layer.cornerRadius = 20
        challengeViewButton.addTarget(self, action: #selector(viewButtonTapped), for: .touchUpInside)
        oldChallengeContainer.addSubview(challengeViewButton)
        
        NSLayoutConstraint.activate([
            challengeBgImageView.topAnchor.constraint(equalTo: oldChallengeContainer.topAnchor),
            challengeBgImageView.bottomAnchor.constraint(equalTo: oldChallengeContainer.bottomAnchor),
            challengeBgImageView.leadingAnchor.constraint(equalTo: oldChallengeContainer.leadingAnchor),
            challengeBgImageView.trailingAnchor.constraint(equalTo: oldChallengeContainer.trailingAnchor),
            
            challengeTitleLabel.leadingAnchor.constraint(equalTo: oldChallengeContainer.leadingAnchor, constant: 20),
            challengeTitleLabel.trailingAnchor.constraint(equalTo: oldChallengeContainer.trailingAnchor, constant: -20),
            challengeTitleLabel.topAnchor.constraint(equalTo: oldChallengeContainer.topAnchor, constant: 24),
            
            challengePercentLabel.leadingAnchor.constraint(equalTo: oldChallengeContainer.leadingAnchor, constant: 20),
            challengePercentLabel.topAnchor.constraint(equalTo: challengeTitleLabel.bottomAnchor, constant: 24),
            
            challengeInfoLabel.leadingAnchor.constraint(equalTo: challengePercentLabel.trailingAnchor, constant: 12),
            challengeInfoLabel.trailingAnchor.constraint(equalTo: oldChallengeContainer.trailingAnchor, constant: -20),
            challengeInfoLabel.centerYAnchor.constraint(equalTo: challengePercentLabel.centerYAnchor, constant: 4),
            
            challengeAvatarStack.leadingAnchor.constraint(equalTo: oldChallengeContainer.leadingAnchor, constant: 20),
            challengeAvatarStack.topAnchor.constraint(equalTo: challengePercentLabel.bottomAnchor, constant: 24),
            challengeAvatarStack.bottomAnchor.constraint(equalTo: oldChallengeContainer.bottomAnchor, constant: -24),
            challengeAvatarStack.heightAnchor.constraint(equalToConstant: 36),
            
            challengeViewButton.trailingAnchor.constraint(equalTo: oldChallengeContainer.trailingAnchor, constant: -20),
            challengeViewButton.centerYAnchor.constraint(equalTo: challengeAvatarStack.centerYAnchor),
            challengeViewButton.widthAnchor.constraint(equalToConstant: 130),
            challengeViewButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    private func setupNewInsightUI() {
        insightCategoryLabel.translatesAutoresizingMaskIntoConstraints = false
        insightCategoryLabel.text = "Health insight"
        insightCategoryLabel.font = .systemFont(ofSize: 14, weight: .medium)
        insightCategoryLabel.textColor = UIColor(white: 1.0, alpha: 0.6)
        newInsightContainer.addSubview(insightCategoryLabel)
        
        insightNameLabel.translatesAutoresizingMaskIntoConstraints = false
        insightNameLabel.font = .systemFont(ofSize: 22, weight: .bold)
        insightNameLabel.textColor = .white
        newInsightContainer.addSubview(insightNameLabel)
        
        insightIconBgView.translatesAutoresizingMaskIntoConstraints = false
        insightIconBgView.backgroundColor = UIColor(red: 0.15, green: 0.30, blue: 0.35, alpha: 1.0)
        insightIconBgView.layer.cornerRadius = 10
        newInsightContainer.addSubview(insightIconBgView)
        
        insightIconImageView.translatesAutoresizingMaskIntoConstraints = false
        insightIconImageView.contentMode = .scaleAspectFit
        insightIconImageView.tintColor = UIColor(red: 0.40, green: 0.85, blue: 0.75, alpha: 1.0)
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        insightIconImageView.image = UIImage(systemName: "chart.xyaxis.line", withConfiguration: iconConfig)
        insightIconBgView.addSubview(insightIconImageView)
        
        insightRingView.translatesAutoresizingMaskIntoConstraints = false
        insightRingView.lineWidth = 12
        insightRingView.showIcon = false
        newInsightContainer.addSubview(insightRingView)
        
        insightScoreLabel.translatesAutoresizingMaskIntoConstraints = false
        insightScoreLabel.font = .systemFont(ofSize: 24, weight: .bold)
        insightScoreLabel.textColor = .white
        insightScoreLabel.textAlignment = .center
        insightRingView.addSubview(insightScoreLabel)
        
        insightPeriodLabel.translatesAutoresizingMaskIntoConstraints = false
        insightPeriodLabel.font = .systemFont(ofSize: 14, weight: .medium)
        insightPeriodLabel.textColor = UIColor(white: 1.0, alpha: 0.6)
        insightPeriodLabel.numberOfLines = 0
        insightPeriodLabel.lineBreakMode = .byWordWrapping
        newInsightContainer.addSubview(insightPeriodLabel)
        
        insightTrendLabel.translatesAutoresizingMaskIntoConstraints = false
        insightTrendLabel.font = .systemFont(ofSize: 16, weight: .bold)
        insightTrendLabel.numberOfLines = 0
        insightTrendLabel.lineBreakMode = .byWordWrapping
        newInsightContainer.addSubview(insightTrendLabel)
        
        NSLayoutConstraint.activate([
            insightCategoryLabel.leadingAnchor.constraint(equalTo: newInsightContainer.leadingAnchor, constant: 20),
            insightCategoryLabel.topAnchor.constraint(equalTo: newInsightContainer.topAnchor, constant: 20),
            
            insightNameLabel.leadingAnchor.constraint(equalTo: insightCategoryLabel.leadingAnchor),
            insightNameLabel.topAnchor.constraint(equalTo: insightCategoryLabel.bottomAnchor, constant: 4),
            
            insightIconBgView.trailingAnchor.constraint(equalTo: newInsightContainer.trailingAnchor, constant: -20),
            insightIconBgView.topAnchor.constraint(equalTo: newInsightContainer.topAnchor, constant: 20),
            insightIconBgView.widthAnchor.constraint(equalToConstant: 36),
            insightIconBgView.heightAnchor.constraint(equalToConstant: 36),
            
            insightIconImageView.centerXAnchor.constraint(equalTo: insightIconBgView.centerXAnchor),
            insightIconImageView.centerYAnchor.constraint(equalTo: insightIconBgView.centerYAnchor),
            insightIconImageView.widthAnchor.constraint(equalToConstant: 18),
            insightIconImageView.heightAnchor.constraint(equalToConstant: 18),
            
            insightRingView.leadingAnchor.constraint(equalTo: newInsightContainer.leadingAnchor, constant: 20),
            insightRingView.topAnchor.constraint(equalTo: insightNameLabel.bottomAnchor, constant: 24),
            insightRingView.widthAnchor.constraint(equalToConstant: 90),
            insightRingView.heightAnchor.constraint(equalToConstant: 90),
            insightRingView.bottomAnchor.constraint(equalTo: newInsightContainer.bottomAnchor, constant: -24),
            
            insightScoreLabel.centerXAnchor.constraint(equalTo: insightRingView.centerXAnchor),
            insightScoreLabel.centerYAnchor.constraint(equalTo: insightRingView.centerYAnchor),
            
            insightPeriodLabel.leadingAnchor.constraint(equalTo: insightRingView.trailingAnchor, constant: 20),
            insightPeriodLabel.centerYAnchor.constraint(equalTo: insightRingView.centerYAnchor, constant: -12),
            insightPeriodLabel.trailingAnchor.constraint(equalTo: newInsightContainer.trailingAnchor, constant: -20),
            
            insightTrendLabel.leadingAnchor.constraint(equalTo: insightPeriodLabel.leadingAnchor),
            insightTrendLabel.topAnchor.constraint(equalTo: insightPeriodLabel.bottomAnchor, constant: 6),
            insightTrendLabel.trailingAnchor.constraint(equalTo: newInsightContainer.trailingAnchor, constant: -20)
        ])
    }


    override func layoutSubviews() {
        super.layoutSubviews()
    }

    private func setupAvatar(_ label: UILabel, text: String, bg: UIColor) {
        label.text = text
        label.textColor = .white
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.backgroundColor = bg
        label.layer.cornerRadius = 16
        label.layer.masksToBounds = true
        label.layer.borderWidth = 2
        label.layer.borderColor = UIColor(red: 0.08, green: 0.17, blue: 0.30, alpha: 1.0).cgColor
    }
    
    @objc private func viewButtonTapped() {
        onViewTapped?()
    }
    
    // Returns true if successfully configured, false if it's not a shared card message
    func configure(with messageContent: String) -> Bool {
        guard messageContent.hasPrefix("[SHARE_CARD:") && messageContent.hasSuffix("]") else { return false }
        
        let content = String(messageContent.dropFirst("[SHARE_CARD:".count).dropLast())
        let components = content.split(separator: "|").map { String($0) }
        
        guard components.count >= 3 else { return false }
        let type = components[0]
        let name = components[1]
        let progressStr = components[2]
        
        oldChallengeContainer.isHidden = true
        newInsightContainer.isHidden = true
        

        if type == "INSIGHT" {
            newInsightContainer.isHidden = false
            
            insightNameLabel.text = name
            insightScoreLabel.text = progressStr
            
            // Try to extract percentage for ring
            let val = progressStr.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
            let pct = (Double(val) ?? 0.0) / 100.0
            
            // Score color based on wellness level
            let scoreInt = Int(val) ?? 0
            let ringColor: UIColor
            switch scoreInt {
            case 75...100: ringColor = .systemGreen
            case 50..<75:  ringColor = .systemYellow
            case 25..<50:  ringColor = .systemOrange
            case 0..<25:   ringColor = .systemRed
            default:       ringColor = .clear
            }
            insightRingView.setProgress(CGFloat(pct), color: ringColor)
            
            if components.count >= 5 {
                let period = components[3]
                let comparison = components[4]
                insightPeriodLabel.text = "\(period.capitalized) Performance"
                
                let trimmedComparison = comparison.trimmingCharacters(in: .whitespacesAndNewlines)
                let isLower = trimmedComparison.contains("lower") || trimmedComparison.contains("↓")
                let isNeutral = trimmedComparison == "—" || trimmedComparison.isEmpty
                
                let cleanComparison: String = {
                    if trimmedComparison.isEmpty { return "0%" }
                    if isNeutral { return "—" }
                    let stripped = trimmedComparison
                        .replacingOccurrences(of: "↓", with: "")
                        .replacingOccurrences(of: "↑", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return stripped.isEmpty ? "0%" : stripped
                }()
                
                let color: UIColor = isNeutral ? .systemGray : (isLower ? .systemRed : .systemGreen)
                insightTrendLabel.textColor = color
                
                let attributedString = NSMutableAttributedString()
                
                if isNeutral {
                    insightTrendLabel.isHidden = true
                    insightTrendLabel.attributedText = nil
                } else {
                    insightTrendLabel.isHidden = false
                    let symbol: String = isLower ? "arrow.down.right" : "arrow.up.right"
                    let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
                    let image = UIImage(systemName: symbol, withConfiguration: config)
                    
                    let attachment = NSTextAttachment()
                    attachment.image = image?.withTintColor(color)
                    attachment.bounds = CGRect(x: 0, y: -1, width: 12, height: 12)
                    
                    attributedString.append(NSAttributedString(attachment: attachment))
                    
                    // Add "since last week/month" text
                    let sinceText = period.lowercased() == "weekly" ? " since last week" : " since last month"
                    attributedString.append(NSAttributedString(string: " " + cleanComparison + sinceText, attributes: [.foregroundColor: color]))
                    insightTrendLabel.attributedText = attributedString
                }
            } else {
                insightPeriodLabel.text = "Performance"
                insightTrendLabel.text = ""
            }
            

        } else if type == "CHALLENGE" {
            oldChallengeContainer.isHidden = false
            
            let challengeName = components.count > 3 ? components[3] : "Step Challenge with \(name)"
            challengeTitleLabel.text = challengeName
            self.challengeData = (challengeName, UUID())
            
            challengeAvatarStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            
            var category = "Step challenge"
            var iconName = "figure.walk"
            var totalDesc = "steps"
            
            let fullRoster = [DataManager.shared.currentUser].compactMap { $0 } + DataManager.shared.allProfiles
            var participants: [Profile] = []
            
            if let matchedChallenge = DataManager.shared.challenges.first(where: { $0.name == challengeName }) {
                // Set background image
                challengeBgImageView.image = UIImage(named: matchedChallenge.bgImage)
                

                // Determine category and icon
                let typeStr = matchedChallenge.type.lowercased()
                category = matchedChallenge.type.capitalized + " challenge"
                if typeStr == "sleep" {
                    iconName = "moon.zzz.fill"
                    totalDesc = "hours"
                } else if typeStr == "fitness" || typeStr == "distance" {
                    iconName = "figure.run"
                    totalDesc = "km"
                } else {
                    iconName = "figure.walk"
                    totalDesc = "steps"
                }

                
                let progressRecords = DataManager.shared.challengeProgress.filter { $0.challengeId == matchedChallenge.challengeId }
                let memberIds = progressRecords.map { $0.memberId }
                participants = fullRoster.filter { memberIds.contains($0.profileId) }
            } else {
                if let profile = fullRoster.first(where: { $0.displayName.lowercased() == name.lowercased() || $0.firstName.lowercased() == name.lowercased() }) {
                    participants = [profile]
                }
            }
            

            // Add participants to stack
            let maxAvatars = 3
            let displayAvatars = Array(participants.prefix(maxAvatars))
            
            for profile in displayAvatars {
                let imageView = UIImageView()
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.contentMode = .scaleAspectFill
                imageView.backgroundColor = .systemBlue
                imageView.layer.cornerRadius = 18
                imageView.layer.masksToBounds = true
                imageView.layer.borderWidth = 2
                imageView.layer.borderColor = UIColor(red: 0.08, green: 0.17, blue: 0.30, alpha: 1.0).cgColor
                imageView.widthAnchor.constraint(equalToConstant: 36).isActive = true
                imageView.heightAnchor.constraint(equalToConstant: 36).isActive = true
                
                ImageManager.shared.setImage(for: imageView, from: profile.profilePic)
                challengeAvatarStack.addArrangedSubview(imageView)
            }
            
            if participants.count > maxAvatars {
                let moreCount = participants.count - maxAvatars
                let moreLabel = UILabel()
                moreLabel.translatesAutoresizingMaskIntoConstraints = false
                moreLabel.text = "+\(moreCount)"
                moreLabel.textColor = .white
                moreLabel.textAlignment = .center
                moreLabel.font = .systemFont(ofSize: 12, weight: .bold)
                moreLabel.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
                moreLabel.layer.cornerRadius = 18
                moreLabel.layer.masksToBounds = true
                moreLabel.layer.borderWidth = 2
                moreLabel.layer.borderColor = UIColor(red: 0.08, green: 0.17, blue: 0.30, alpha: 1.0).cgColor
                moreLabel.widthAnchor.constraint(equalToConstant: 36).isActive = true
                moreLabel.heightAnchor.constraint(equalToConstant: 36).isActive = true
                challengeAvatarStack.addArrangedSubview(moreLabel)
            }
            
            let val = progressStr.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
            challengePercentLabel.text = "\(val)%"
            
            let friendsCount = max(0, participants.count - 1)
            let friendText = friendsCount == 1 ? "1 friend" : "\(friendsCount) friends"
            
            var progressText = "with \(friendText)"
            if let matchedChallenge = DataManager.shared.challenges.first(where: { $0.name == challengeName }) {
                let progressRecords = DataManager.shared.challengeProgress.filter { $0.challengeId == matchedChallenge.challengeId }
                if let senderProfile = participants.first(where: { $0.firstName.lowercased() == name.lowercased() || $0.displayName.lowercased() == name.lowercased() }),
                   let senderProgress = progressRecords.first(where: { $0.memberId == senderProfile.profileId }) {
                    let isDistance = (totalDesc == "km")
                    let currentStr = isDistance ? String(format: "%.1f", senderProgress.currentValue / 1000.0) : "\(Int(senderProgress.currentValue))"
                    let goalStr = isDistance ? String(format: "%.1f", senderProgress.goalValue / 1000.0) : "\(Int(senderProgress.goalValue))"
                    let isCompleted = senderProgress.currentValue >= senderProgress.goalValue
                    
                    if isCompleted {
                        progressText = "completed · \(currentStr) of \(goalStr) \(totalDesc) with \(friendText)"
                    } else {
                        progressText = "\(currentStr) of \(goalStr) \(totalDesc) with \(friendText)"
                    }
                }
            }
            challengeInfoLabel.text = progressText

        }
        
        return true
    }
}