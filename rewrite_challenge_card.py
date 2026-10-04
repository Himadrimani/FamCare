import re

with open('/Users/mani16/Downloads/ProjectiOS 2/HomeScreen/Messages/Views/SharedCardView.swift', 'r') as f:
    content = f.read()

# 1. Properties
# Remove old challenge properties
properties_to_remove = [
    "    private let iconBgView = UIView()",
    "    private let iconImageView = UIImageView()",
    "    private let categoryLabel = UILabel()",
    "    private let timePillView = UIView()",
    "    private let timeLabel = UILabel()",
    "    private let titleLabel = UILabel()",
    "    private let statContainer = UIView()",
    "    private let bigStatLabel = UILabel()",
    "    private let smallStatLabel = UILabel()",
    "    private let rightStatLabel = UILabel()",
    "    private let progressBarBg = UIView()",
    "    private let progressBarFill = UIView()",
    "    private var progressWidthConstraint: NSLayoutConstraint?",
    "    private let avatarStackView = UIStackView()",
    "    private let participantsLabel = UILabel()",
    "    private let viewButton = UIButton(type: .system)"
]

for p in properties_to_remove:
    content = content.replace(p, "")

new_challenge_properties = """
    // Challenge Specific UI
    private let challengeBgImageView = UIImageView()
    private let challengeCategoryLabel = UILabel()
    private let challengeTimePill = UIView()
    private let challengeTimeLabel = UILabel()
    private let challengeTitleLabel = UILabel()
    
    private let trackStartIconBg = UIView()
    private let trackStartIcon = UIImageView()
    private let trackDottedLine = UIView()
    private let trackFlagIcon = UIImageView()
    
    private let challengePercentLabel = UILabel()
    private let challengeInfoLabel = UILabel()
    
    private let challengeAvatarStack = UIStackView()
    private let challengeViewButton = UIButton(type: .system)
"""

content = content.replace("    private let oldChallengeContainer = UIView()", "    private let oldChallengeContainer = UIView()\n" + new_challenge_properties)

# 2. SetupUI
# The old setupUI manually configured all those removed properties.
# I will write a regex to find the block configuring the old properties and replace it with `setupChallengeUI()` call.
# The block starts right after `oldChallengeContainer.translatesAutoresizingMaskIntoConstraints = false`
# and ends before `setupNewInsightUI()`

setup_challenge_ui = """
    private func setupChallengeUI() {
        // Background Image
        challengeBgImageView.translatesAutoresizingMaskIntoConstraints = false
        challengeBgImageView.contentMode = .scaleAspectFill
        challengeBgImageView.alpha = 0.15
        challengeBgImageView.clipsToBounds = true
        oldChallengeContainer.addSubview(challengeBgImageView)
        
        // Category Label
        challengeCategoryLabel.translatesAutoresizingMaskIntoConstraints = false
        challengeCategoryLabel.font = .systemFont(ofSize: 14, weight: .medium)
        challengeCategoryLabel.textColor = UIColor(white: 1.0, alpha: 0.6)
        oldChallengeContainer.addSubview(challengeCategoryLabel)
        
        // Time Pill
        challengeTimePill.translatesAutoresizingMaskIntoConstraints = false
        challengeTimePill.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
        challengeTimePill.layer.cornerRadius = 12
        challengeTimePill.layer.borderWidth = 1
        challengeTimePill.layer.borderColor = UIColor(white: 1.0, alpha: 0.2).cgColor
        oldChallengeContainer.addSubview(challengeTimePill)
        
        challengeTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        challengeTimeLabel.text = "Today"
        challengeTimeLabel.font = .systemFont(ofSize: 12, weight: .medium)
        challengeTimeLabel.textColor = UIColor(white: 1.0, alpha: 0.7)
        challengeTimePill.addSubview(challengeTimeLabel)
        
        // Title Label
        challengeTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        challengeTitleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        challengeTitleLabel.textColor = .white
        challengeTitleLabel.numberOfLines = 2
        oldChallengeContainer.addSubview(challengeTitleLabel)
        
        // Track Start Icon
        trackStartIconBg.translatesAutoresizingMaskIntoConstraints = false
        trackStartIconBg.backgroundColor = UIColor(red: 0.40, green: 0.85, blue: 1.0, alpha: 1.0) // Sky Blue
        trackStartIconBg.layer.cornerRadius = 18
        oldChallengeContainer.addSubview(trackStartIconBg)
        
        trackStartIcon.translatesAutoresizingMaskIntoConstraints = false
        trackStartIcon.contentMode = .scaleAspectFit
        trackStartIcon.tintColor = .black
        trackStartIconBg.addSubview(trackStartIcon)
        
        // Dotted Line (We'll draw it in layoutSubviews or use a CAShapeLayer, for now just a placeholder view)
        trackDottedLine.translatesAutoresizingMaskIntoConstraints = false
        trackDottedLine.backgroundColor = .clear
        oldChallengeContainer.addSubview(trackDottedLine)
        
        // Flag Icon
        trackFlagIcon.translatesAutoresizingMaskIntoConstraints = false
        trackFlagIcon.contentMode = .scaleAspectFit
        trackFlagIcon.image = UIImage(systemName: "flag")
        trackFlagIcon.tintColor = UIColor(white: 1.0, alpha: 0.4)
        oldChallengeContainer.addSubview(trackFlagIcon)
        
        // Percentage
        challengePercentLabel.translatesAutoresizingMaskIntoConstraints = false
        challengePercentLabel.font = .systemFont(ofSize: 48, weight: .black)
        challengePercentLabel.textColor = .white
        oldChallengeContainer.addSubview(challengePercentLabel)
        
        // Info Label
        challengeInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        challengeInfoLabel.font = .systemFont(ofSize: 14, weight: .medium)
        challengeInfoLabel.textColor = UIColor(white: 1.0, alpha: 0.6)
        challengeInfoLabel.numberOfLines = 2
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
            
            challengeCategoryLabel.leadingAnchor.constraint(equalTo: oldChallengeContainer.leadingAnchor, constant: 20),
            challengeCategoryLabel.topAnchor.constraint(equalTo: oldChallengeContainer.topAnchor, constant: 20),
            
            challengeTimePill.trailingAnchor.constraint(equalTo: oldChallengeContainer.trailingAnchor, constant: -20),
            challengeTimePill.centerYAnchor.constraint(equalTo: challengeCategoryLabel.centerYAnchor),
            challengeTimePill.heightAnchor.constraint(equalToConstant: 24),
            
            challengeTimeLabel.leadingAnchor.constraint(equalTo: challengeTimePill.leadingAnchor, constant: 10),
            challengeTimeLabel.trailingAnchor.constraint(equalTo: challengeTimePill.trailingAnchor, constant: -10),
            challengeTimeLabel.centerYAnchor.constraint(equalTo: challengeTimePill.centerYAnchor),
            
            challengeTitleLabel.leadingAnchor.constraint(equalTo: challengeCategoryLabel.leadingAnchor),
            challengeTitleLabel.trailingAnchor.constraint(equalTo: oldChallengeContainer.trailingAnchor, constant: -20),
            challengeTitleLabel.topAnchor.constraint(equalTo: challengeCategoryLabel.bottomAnchor, constant: 4),
            
            trackStartIconBg.leadingAnchor.constraint(equalTo: oldChallengeContainer.leadingAnchor, constant: 20),
            trackStartIconBg.topAnchor.constraint(equalTo: challengeTitleLabel.bottomAnchor, constant: 24),
            trackStartIconBg.widthAnchor.constraint(equalToConstant: 36),
            trackStartIconBg.heightAnchor.constraint(equalToConstant: 36),
            
            trackStartIcon.centerXAnchor.constraint(equalTo: trackStartIconBg.centerXAnchor),
            trackStartIcon.centerYAnchor.constraint(equalTo: trackStartIconBg.centerYAnchor),
            trackStartIcon.widthAnchor.constraint(equalToConstant: 18),
            trackStartIcon.heightAnchor.constraint(equalToConstant: 18),
            
            trackFlagIcon.trailingAnchor.constraint(equalTo: oldChallengeContainer.trailingAnchor, constant: -20),
            trackFlagIcon.centerYAnchor.constraint(equalTo: trackStartIconBg.centerYAnchor),
            trackFlagIcon.widthAnchor.constraint(equalToConstant: 18),
            trackFlagIcon.heightAnchor.constraint(equalToConstant: 18),
            
            trackDottedLine.leadingAnchor.constraint(equalTo: trackStartIconBg.trailingAnchor, constant: 8),
            trackDottedLine.trailingAnchor.constraint(equalTo: trackFlagIcon.leadingAnchor, constant: -8),
            trackDottedLine.centerYAnchor.constraint(equalTo: trackStartIconBg.centerYAnchor),
            trackDottedLine.heightAnchor.constraint(equalToConstant: 2),
            
            challengePercentLabel.leadingAnchor.constraint(equalTo: oldChallengeContainer.leadingAnchor, constant: 20),
            challengePercentLabel.topAnchor.constraint(equalTo: trackStartIconBg.bottomAnchor, constant: 24),
            
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
"""

content = re.sub(r'        iconBgView\.translatesAutoresizingMaskIntoConstraints.*?\]\)', '        setupChallengeUI()', content, flags=re.DOTALL)

content = content.replace("    private func setupNewInsightUI() {", setup_challenge_ui + "\n    private func setupNewInsightUI() {")


# 3. Handle dashed line drawing
# We need to add a dashed line to `trackDottedLine`
dashed_line_code = """
    private var dashedLayer: CAShapeLayer?
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Draw dotted line
        if dashedLayer == nil {
            let layer = CAShapeLayer()
            layer.strokeColor = UIColor(white: 1.0, alpha: 0.2).cgColor
            layer.lineWidth = 3
            layer.lineDashPattern = [2, 6]
            layer.lineCap = .round
            trackDottedLine.layer.addSublayer(layer)
            dashedLayer = layer
        }
        
        if let dashedLayer = dashedLayer {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: trackDottedLine.bounds.height / 2))
            path.addLine(to: CGPoint(x: trackDottedLine.bounds.width, y: trackDottedLine.bounds.height / 2))
            dashedLayer.path = path.cgPath
            dashedLayer.frame = trackDottedLine.bounds
        }
    }
"""

content = content.replace("    private func setupAvatar", dashed_line_code + "\n    private func setupAvatar")


# 4. configure() logic for Challenge
configure_challenge = """
        } else if type == "CHALLENGE" {
            oldChallengeContainer.isHidden = false
            
            let challengeName = components.count > 3 ? components[3] : "Step Challenge with \\(name)"
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
                category = matchedChallenge.category.rawValue.capitalized + " challenge"
                switch matchedChallenge.category {
                case .sleep:
                    iconName = "moon.zzz.fill"
                    totalDesc = "hours"
                case .fitness:
                    iconName = "figure.run"
                    totalDesc = "calories"
                case .steps:
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
            
            challengeCategoryLabel.text = category
            let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
            trackStartIcon.image = UIImage(systemName: iconName, withConfiguration: config)
            
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
                moreLabel.text = "+\\(moreCount)"
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
            challengePercentLabel.text = "\\(val)%"
            
            let friendsCount = max(0, participants.count - 1)
            let friendText = friendsCount == 1 ? "1 friend" : "\\(friendsCount) friends"
            
            // Just a fallback since we don't know the goal from the message string alone
            challengeInfoLabel.text = "completed · with \\(friendText)"
"""

content = re.sub(r'        } else if type == "CHALLENGE" \{.*', configure_challenge + "\n        }\n        \n        return true\n    }\n}", content, flags=re.DOTALL)

with open('/Users/mani16/Downloads/ProjectiOS 2/HomeScreen/Messages/Views/SharedCardView.swift', 'w') as f:
    f.write(content)

