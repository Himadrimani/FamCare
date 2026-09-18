import UIKit

class design02: UICollectionViewCell {
    
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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupStaticAppearance()
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

        progressTextContainer.layer.cornerRadius = 14
        progressTextContainer.layer.cornerCurve = .continuous
        progressTextContainer.clipsToBounds = true
    }
    
    func configureCell(profile: Profile, completed: Double, goal: Double, metricName: String) {
        
        ImageManager.shared.setImage(for: userImage, from: profile.profilePic)
        userLabel.text = profile.displayName
        
        let rawPercent = (goal > 0) ? (completed / goal) * 100.0 : 0
        let percent = min(rawPercent, 100.0)
        let isComplete = percent >= 100.0

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
