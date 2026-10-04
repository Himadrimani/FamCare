import re

with open('/Users/mani16/Downloads/ProjectiOS 2/HomeScreen/Messages/Views/SharedCardView.swift', 'r') as f:
    content = f.read()

# Replace bgView.addSubview with oldChallengeContainer.addSubview
new_content = content.replace("bgView.addSubview(", "oldChallengeContainer.addSubview(")

# But bgView is still created. We need to add oldChallengeContainer and newInsightContainer.
# Let's add them to the properties:
properties_addition = """
    private let oldChallengeContainer = UIView()
    
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
"""
new_content = new_content.replace("    // Top Row", properties_addition + "\n    // Top Row")

# In setupUI, setup the containers
setup_addition = """
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
"""
new_content = new_content.replace("        self.addSubview(bgView)\n", "        self.addSubview(bgView)\n" + setup_addition)

# Replace bgView constraints with oldChallengeContainer constraints for the internal elements
new_content = new_content.replace("equalTo: bgView.leadingAnchor", "equalTo: oldChallengeContainer.leadingAnchor")
new_content = new_content.replace("equalTo: bgView.trailingAnchor", "equalTo: oldChallengeContainer.trailingAnchor")
new_content = new_content.replace("equalTo: bgView.topAnchor", "equalTo: oldChallengeContainer.topAnchor")
new_content = new_content.replace("equalTo: bgView.bottomAnchor", "equalTo: oldChallengeContainer.bottomAnchor")
# Restore bgView constraints that should remain bgView
new_content = new_content.replace("bgView.topAnchor.constraint(equalTo: oldChallengeContainer.topAnchor)", "bgView.topAnchor.constraint(equalTo: self.topAnchor)")
new_content = new_content.replace("bgView.bottomAnchor.constraint(equalTo: oldChallengeContainer.bottomAnchor)", "bgView.bottomAnchor.constraint(equalTo: self.bottomAnchor)")
new_content = new_content.replace("bgView.leadingAnchor.constraint(equalTo: oldChallengeContainer.leadingAnchor)", "bgView.leadingAnchor.constraint(equalTo: self.leadingAnchor)")
new_content = new_content.replace("bgView.trailingAnchor.constraint(equalTo: oldChallengeContainer.trailingAnchor)", "bgView.trailingAnchor.constraint(equalTo: self.trailingAnchor)")
new_content = new_content.replace("mainStackView.topAnchor.constraint(equalTo: oldChallengeContainer.topAnchor)", "mainStackView.topAnchor.constraint(equalTo: bgView.topAnchor)")
new_content = new_content.replace("mainStackView.bottomAnchor.constraint(equalTo: oldChallengeContainer.bottomAnchor)", "mainStackView.bottomAnchor.constraint(equalTo: bgView.bottomAnchor)")
new_content = new_content.replace("mainStackView.leadingAnchor.constraint(equalTo: oldChallengeContainer.leadingAnchor)", "mainStackView.leadingAnchor.constraint(equalTo: bgView.leadingAnchor)")
new_content = new_content.replace("mainStackView.trailingAnchor.constraint(equalTo: oldChallengeContainer.trailingAnchor)", "mainStackView.trailingAnchor.constraint(equalTo: bgView.trailingAnchor)")

# Add setupNewInsightUI
insight_ui_setup = """
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
        newInsightContainer.addSubview(insightPeriodLabel)
        
        insightTrendLabel.translatesAutoresizingMaskIntoConstraints = false
        insightTrendLabel.font = .systemFont(ofSize: 16, weight: .bold)
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
"""
new_content = new_content.replace("    private func setupAvatar", insight_ui_setup + "\n    private func setupAvatar")

# In configure(), toggle containers and configure new insight UI
configure_start = """
        oldChallengeContainer.isHidden = true
        newInsightContainer.isHidden = true
"""

new_content = new_content.replace("        progressWidthConstraint?.isActive = false", "        progressWidthConstraint?.isActive = false\n" + configure_start)

insight_configure = """
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
                insightPeriodLabel.text = "\\(period) performance"
                
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
                    insightTrendLabel.text = "Steady gains"
                } else {
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
"""

# Replace the entire if type == "INSIGHT" block with our new one
import re
new_content = re.sub(r'        if type == "INSIGHT" \{.*?} else if type == "CHALLENGE" \{', insight_configure, new_content, flags=re.DOTALL)


with open('/Users/mani16/Downloads/ProjectiOS 2/HomeScreen/Messages/Views/SharedCardView.swift', 'w') as f:
    f.write(new_content)
