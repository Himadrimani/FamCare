import UIKit

protocol Design02Delegate: AnyObject {
    func design02DidTapShare(_ cell: design02)
    func design02DidTapCheckbox(_ cell: design02, isChecked: Bool)
}

class design02: UICollectionViewCell {
    
    weak var delegate: Design02Delegate?
    private let shareButton = UIButton(type: .system)
    
    @IBOutlet weak var container: UIView!
    @IBOutlet weak var imageContainer: UIView!
    @IBOutlet weak var userImage: UIImageView!
    @IBOutlet weak var userLabel: UILabel!
    @IBOutlet weak var userProgress: UILabel!
    @IBOutlet weak var progressBG: UIView!
    @IBOutlet weak var progressTrack: UIView!
    @IBOutlet weak var progressTrackWidth: NSLayoutConstraint!
    @IBOutlet weak var progressTextContainer: UIView!
    @IBOutlet weak var progressText: UILabel!
    
    private let checkboxButton = UIButton(type: .system)
    private var isChecked = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupStaticAppearance()
        
        if let verticalStack = progressBG.superview as? UIStackView {
            progressTextContainer.removeFromSuperview()
            
            if let hStack = verticalStack.superview {
                for constraint in hStack.constraints {
                    if constraint.firstAttribute == .width && constraint.secondAttribute == .width {
                        hStack.removeConstraint(constraint)
                    }
                }
            }
            
            progressBG.removeFromSuperview()
            
            let progressHStack = UIStackView(arrangedSubviews: [progressBG, progressTextContainer])
            progressHStack.axis = .horizontal
            progressHStack.spacing = 12
            progressHStack.alignment = .center
            progressHStack.translatesAutoresizingMaskIntoConstraints = false
            
            verticalStack.addArrangedSubview(progressHStack)
            progressBG.heightAnchor.constraint(equalToConstant: 6).isActive = true
        }
        
        setupShareButton()
    }
    
    private func setupShareButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let shareIcon = UIImage(systemName: "bubble", withConfiguration: config)
        shareButton.setImage(shareIcon, for: .normal)
        shareButton.tintColor = .systemBlue
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        
        container.addSubview(shareButton)
        
        NSLayoutConstraint.activate([
            shareButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            shareButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            shareButton.widthAnchor.constraint(equalToConstant: 24),
            shareButton.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // Setup Checkbox
        let checkConfig = UIImage.SymbolConfiguration(pointSize: 26, weight: .regular)
        checkboxButton.setImage(UIImage(systemName: "square", withConfiguration: checkConfig), for: .normal)
        checkboxButton.setImage(UIImage(systemName: "checkmark.square.fill", withConfiguration: checkConfig), for: .selected)
        checkboxButton.tintColor = .systemBlue
        checkboxButton.translatesAutoresizingMaskIntoConstraints = false
        checkboxButton.addTarget(self, action: #selector(checkboxTapped), for: .touchUpInside)
        
        container.addSubview(checkboxButton)
        
        NSLayoutConstraint.activate([
            checkboxButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            checkboxButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            checkboxButton.widthAnchor.constraint(equalToConstant: 32),
            checkboxButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    @objc private func shareTapped() {
        delegate?.design02DidTapShare(self)
    }
    
    @objc private func checkboxTapped() {
        isChecked.toggle()
        checkboxButton.isSelected = isChecked
        delegate?.design02DidTapCheckbox(self, isChecked: isChecked)
    }

    private func setupStaticAppearance() {
        
        container.backgroundColor = UIColor(red: 242/255, green: 247/255, blue: 255/255, alpha: 1)
        container.layer.cornerRadius = 20
        container.layer.cornerCurve = .continuous
        container.layer.borderWidth = 0.5
        container.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        
        if #available(iOS 16.0, *) {
            container.layer.shadowColor = UIColor.black.cgColor
            container.layer.shadowOpacity = 0.06
            container.layer.shadowRadius = 12
            container.layer.shadowOffset = CGSize(width: 0, height: 4)
        }
        imageContainer.layer.cornerRadius = imageContainer.frame.width / 2
        imageContainer.layer.cornerCurve = .circular
        imageContainer.clipsToBounds = false
        imageContainer.layer.borderWidth = 2.5
        userImage.layer.cornerRadius = userImage.frame.width / 2
        userImage.layer.cornerCurve = .circular
        userImage.clipsToBounds = true
        userImage.contentMode = .scaleAspectFill

        progressBG.layer.cornerRadius = progressBG.frame.height / 2
        progressBG.layer.cornerCurve = .continuous
        progressBG.clipsToBounds = true
        progressBG.backgroundColor = UIColor.systemFill

        progressTrack.layer.cornerRadius = progressTrack.frame.height / 2
        progressTrack.layer.cornerCurve = .continuous
        progressTrack.clipsToBounds = true

        progressTextContainer.layer.cornerRadius = 12.5 // Perfect pill for height 25
        progressTextContainer.layer.cornerCurve = .continuous
        progressTextContainer.clipsToBounds = true
        
        progressText.font = .systemFont(ofSize: 13, weight: .bold)
        progressTextContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
    }
    
    func configureCell(profile: Profile, completed: Double, goal: Double, metricName: String, isSocial: Bool = false) {
        
        let currentUserId = DataManager.shared.currentUser?.profileId
        let rawPercent = (goal > 0) ? (completed / goal) * 100.0 : 0
        let percent = min(rawPercent, 100.0)
        let isComplete = percent >= 100.0
        
        ImageManager.shared.setImage(for: userImage, from: profile.profilePic)
        userLabel.text = profile.displayName
        
        if isSocial {
            shareButton.isHidden = true
            checkboxButton.isHidden = false
            progressBG.superview?.isHidden = true
            userProgress.isHidden = true
            
            isChecked = isComplete
            checkboxButton.isSelected = isChecked
            checkboxButton.isUserInteractionEnabled = (profile.profileId == currentUserId)
            checkboxButton.alpha = checkboxButton.isUserInteractionEnabled ? 1.0 : 0.4
            
            let accentColor: UIColor = isComplete ? .systemGreen : .systemBlue
            imageContainer.layer.borderColor = accentColor.cgColor
            checkboxButton.tintColor = accentColor
            
            UIView.animate(withDuration: 0.4) {
                self.container.backgroundColor = isComplete
                    ? UIColor.systemGreen.withAlphaComponent(0.08)
                    : UIColor(red: 242/255, green: 247/255, blue: 255/255, alpha: 1)
            }
            return
        }
        
        shareButton.isHidden = (profile.profileId == currentUserId)
        checkboxButton.isHidden = true
        progressBG.superview?.isHidden = false
        userProgress.isHidden = false

        if metricName == "Completed" || metricName == "Not Completed" {
            userProgress.text = isComplete ? "Completed!" : "Not Completed"
        } else if isComplete {
            userProgress.text = "Completed!"
        } else {
            let useDecimal = metricName == "km" || metricName == "hrs Slept"
            let compStr = useDecimal ? String(format: "%.1f", completed) : "\(Int(completed))"
            let goalStr = useDecimal ? String(format: "%.1f", goal) : "\(Int(goal))"
            userProgress.text = "\(compStr)/\(goalStr) \(metricName)"
        }
        let accentColor: UIColor = isComplete ? .systemGreen : .systemBlue
        let tintBG = isComplete
            ? UIColor.systemGreen.withAlphaComponent(0.15)
            : UIColor.systemBlue.withAlphaComponent(0.15)

        imageContainer.layer.borderColor = accentColor.cgColor
        
        progressTrack.backgroundColor = accentColor
        animateProgressBar(to: percent)

        progressTextContainer.backgroundColor = tintBG
        progressText.textColor = accentColor
        
        if isComplete {
            let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            let checkmark = UIImage(systemName: "checkmark", withConfiguration: config)
            let attachment = NSTextAttachment()
            attachment.image = checkmark?.withTintColor(accentColor, renderingMode: .alwaysOriginal)
            progressText.attributedText = NSAttributedString(attachment: attachment)
        } else {
            progressText.attributedText = nil
            progressText.text = "\(Int(percent))%"
        }
        UIView.animate(withDuration: 0.4) {
            self.container.backgroundColor = isComplete
                ? UIColor.systemGreen.withAlphaComponent(0.08)
                : UIColor(red: 242/255, green: 247/255, blue: 255/255, alpha: 1)
        }
    }
    
    private func animateProgressBar(to percent: Double) {
        guard let parent = progressBG.superview else { return }
        
        parent.layoutIfNeeded()
        
        let maxWidth = progressBG.frame.width
        let targetWidth = maxWidth * CGFloat(percent / 100.0)
        
        progressTrackWidth.constant = targetWidth
        
        UIView.animate(
            withDuration: 0.6,
            delay: 0.1,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.3,
            options: .curveEaseOut
        ) {
            parent.layoutIfNeeded()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageContainer.layer.cornerRadius = imageContainer.frame.width / 2
        userImage.layer.cornerRadius = userImage.frame.width / 2
        progressBG.layer.cornerRadius = progressBG.frame.height / 2
        progressTrack.layer.cornerRadius = progressTrack.frame.height / 2
    }
}
