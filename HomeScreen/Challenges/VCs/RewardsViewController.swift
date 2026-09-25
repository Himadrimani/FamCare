import UIKit
import LinkPresentation

enum AchievementType: Codable {
    case individual
    case family
}

struct EarnedReward: Codable {
    let id: String
    let type: AchievementType
    let challengeId: String?
    let challengeTitle: String?
    let challengeType: String?
    let participantsCount: Int?
    let dateEarned: Date
}

class RewardsManager {
    static let shared = RewardsManager()
    private var key: String {
        let profileId = DataManager.shared.currentUser?.profileId.uuidString ?? "default"
        return "FamCare_EarnedRewards_v4_\(profileId)"
    }
    
    var rewards: [EarnedReward] {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([EarnedReward].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: key)
            }
        }
    }
    
    func hasReward(type: AchievementType, challengeId: String?) -> Bool {
        guard let challengeId = challengeId else { return false }
        return rewards.contains(where: { $0.challengeId == challengeId && $0.type == type })
    }
    
    func addReward(type: AchievementType, challengeId: String?, challengeTitle: String?, challengeType: String?, participantsCount: Int?) {
        var current = rewards
        if let challengeId = challengeId {
            if current.contains(where: { $0.challengeId == challengeId && $0.type == type }) {
                return
            }
        }
        let reward = EarnedReward(id: UUID().uuidString, type: type, challengeId: challengeId, challengeTitle: challengeTitle, challengeType: challengeType, participantsCount: participantsCount, dateEarned: Date())
        current.insert(reward, at: 0)
        rewards = current
    }
}

class RewardsViewController: UIViewController {

    private let achievementType: AchievementType
    private let challengeId: String?
    private let challengeTitle: String?
    private let challengeType: String?
    private let participantsCount: Int?
    
    private let celebrationImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "celebration_sticker"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 28)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let shareButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Share achievement", for: .normal)
        button.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        button.backgroundColor = .secondarySystemGroupedBackground
        button.tintColor = .systemBlue
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 14
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemGray5.cgColor
        
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 0)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let doneButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Done", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 14
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    init(achievementType: AchievementType, challengeId: String? = nil, challengeTitle: String? = nil, challengeType: String? = nil, participantsCount: Int? = nil) {
        self.achievementType = achievementType
        self.challengeId = challengeId
        self.challengeTitle = challengeTitle
        self.challengeType = challengeType
        self.participantsCount = participantsCount
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .pageSheet
        if let sheet = self.sheetPresentationController {
            if #available(iOS 16.0, *) {
                sheet.detents = [.custom(resolver: { context in
                    return 550
                }), .large()]
            } else {
                sheet.detents = [.medium(), .large()]
            }
            sheet.prefersGrabberVisible = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupUI()
        configureContent()
        
        RewardsManager.shared.addReward(
            type: achievementType,
            challengeId: challengeId,
            challengeTitle: challengeTitle,
            challengeType: challengeType,
            participantsCount: participantsCount
        )
    }
    
    private func setupUI() {
        view.addSubview(celebrationImageView)
        view.addSubview(iconImageView)
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        
        let buttonStack = UIStackView(arrangedSubviews: [shareButton, doneButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = 16
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonStack)
        
        NSLayoutConstraint.activate([
            celebrationImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            celebrationImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            celebrationImageView.widthAnchor.constraint(equalToConstant: 240),
            celebrationImageView.heightAnchor.constraint(equalToConstant: 240),
            
            iconImageView.centerXAnchor.constraint(equalTo: celebrationImageView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: celebrationImageView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 160),
            iconImageView.heightAnchor.constraint(equalToConstant: 160),
            
            titleLabel.topAnchor.constraint(equalTo: celebrationImageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            buttonStack.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 32),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            shareButton.heightAnchor.constraint(equalToConstant: 54),
            doneButton.heightAnchor.constraint(equalToConstant: 54)
        ])
        
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
    }
    
    private func configureContent() {
        switch achievementType {
        case .individual:
            iconImageView.image = UIImage(named: "trophy_button_image")
            iconImageView.tintColor = nil
            titleLabel.text = "You did it!"
            descriptionLabel.text = "You've successfully completed your part of the challenge.\nGreat job!"
        case .family:
            iconImageView.image = UIImage(named: "shield_sticker")
            iconImageView.tintColor = nil
            let famName = DataManager.shared.family?.familyName ?? "Your family"
            titleLabel.text = "\(famName) did it!"
            descriptionLabel.text = "Every member completed the challenge.\nYou've earned a family shield."
        }
    }
    
    @objc private func shareTapped() {
        let snapshotImage = generateShareImage()
        
        let challengeNameStr = challengeTitle ?? (achievementType == .individual ? "a challenge" : "a family challenge")
        let text = "I just completed '\(challengeNameStr)' on FamCare! 🎉"
        
        // Create the custom item source for LinkPresentation (App Icon and App Name)
        let itemSource = AchievementActivityItemSource(
            title: "FamCare",
            message: text,
            iconImage: UIImage(named: "LaunchAppIcon") ?? UIImage(named: "trophy_button_image")
        )
        
        // Pass both the item source (metadata + text) and the beautiful snapshot image
        let activityVC = UIActivityViewController(activityItems: [itemSource, snapshotImage], applicationActivities: nil)
        
        // Support for iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        
        present(activityVC, animated: true)
    }
    
    private func generateShareImage() -> UIImage {
        let cardWidth: CGFloat = 400
        let cardHeight: CGFloat = 620
        
        // Create a standalone canvas
        let container = UIView(frame: CGRect(x: 0, y: 0, width: cardWidth, height: cardHeight))
        container.backgroundColor = UIColor(red: 253/255, green: 248/255, blue: 240/255, alpha: 1.0)
        container.layer.cornerRadius = 24
        container.layer.masksToBounds = true
        
        // 1. App Header (Icon + Name)
        let appIcon = UIImageView(image: UIImage(named: "LaunchAppIcon") ?? UIImage(named: "AppIcon") ?? UIImage(named: "trophy_button_image"))
        appIcon.contentMode = .scaleAspectFill
        appIcon.layer.cornerRadius = 8
        appIcon.clipsToBounds = true
        appIcon.frame = CGRect(x: 32, y: 32, width: 36, height: 36)
        container.addSubview(appIcon)
        
        let appName = UILabel()
        appName.text = "FamCare"
        appName.font = .systemFont(ofSize: 22, weight: .bold)
        appName.textColor = .black
        appName.frame = CGRect(x: 78, y: 32, width: 200, height: 36)
        container.addSubview(appName)
        
        // 2. Profile Name
        let nameLabel = UILabel()
        if let user = DataManager.shared.currentUser {
            nameLabel.text = "\(user.firstName) \(user.lastName)"
        } else {
            nameLabel.text = "FamCare User"
        }
        nameLabel.font = .systemFont(ofSize: 20, weight: .regular)
        nameLabel.textColor = .darkGray
        nameLabel.textAlignment = .center
        nameLabel.frame = CGRect(x: 24, y: 85, width: cardWidth - 48, height: 28)
        container.addSubview(nameLabel)
        
        // 3. Trophy & Celebration
        let sticker = UIImageView(image: UIImage(named: "celebration_sticker"))
        sticker.contentMode = .scaleAspectFit
        sticker.frame = CGRect(x: (cardWidth - 320)/2, y: 110, width: 320, height: 320)
        container.addSubview(sticker)
        
        let trophy = UIImageView()
        if achievementType == .individual {
            trophy.image = UIImage(named: "trophy_button_image")
            trophy.tintColor = nil
        } else {
            trophy.image = UIImage(named: "shield_sticker")
            trophy.tintColor = nil
        }
        trophy.contentMode = .scaleAspectFit
        trophy.frame = CGRect(x: (cardWidth - 170)/2, y: 175, width: 170, height: 170)
        container.addSubview(trophy)
        
        // 4. Motivational Line
        let mainTitle = UILabel()
        mainTitle.text = titleLabel.text
        mainTitle.font = .boldSystemFont(ofSize: 36)
        mainTitle.textColor = .black
        mainTitle.textAlignment = .center
        mainTitle.frame = CGRect(x: 24, y: 430, width: cardWidth - 48, height: 44)
        container.addSubview(mainTitle)
        
        let desc = UILabel()
        var textToSet = descriptionLabel.text ?? ""
        textToSet = textToSet.replacingOccurrences(of: "\nGreat job!", with: "")
        textToSet = textToSet.replacingOccurrences(of: "\nYou've earned a family shield.", with: "")
        desc.text = textToSet
        desc.font = .systemFont(ofSize: 18, weight: .regular)
        desc.textColor = .darkGray
        desc.textAlignment = .center
        desc.numberOfLines = 0
        desc.frame = CGRect(x: 32, y: 480, width: cardWidth - 64, height: 50)
        container.addSubview(desc)
        
        // 5. Challenge Details (Blue box at the bottom)
        let challengeBox = UIView(frame: CGRect(x: 32, y: 540, width: cardWidth - 64, height: 50))
        challengeBox.backgroundColor = UIColor(red: 228/255, green: 242/255, blue: 255/255, alpha: 1.0)
        challengeBox.layer.cornerRadius = 14
        
        let challengeNameLabel = UILabel()
        let cName = challengeTitle ?? (achievementType == .individual ? "Individual Challenge" : "Family Challenge")
        challengeNameLabel.text = "🏆 \(cName)"
        challengeNameLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        challengeNameLabel.textColor = .systemBlue
        challengeNameLabel.textAlignment = .center
        challengeNameLabel.frame = challengeBox.bounds
        challengeBox.addSubview(challengeNameLabel)
        
        container.addSubview(challengeBox)
        
        // Force layout and render exactly what's constructed with transparent rounded corners
        container.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(bounds: container.bounds, format: format)
        return renderer.image { ctx in
            container.layer.render(in: ctx.cgContext)
        }
    }
    
    @objc private func doneTapped() {
        dismiss(animated: true, completion: nil)
    }
}

class AchievementActivityItemSource: NSObject, UIActivityItemSource {
    let title: String
    let message: String
    let iconImage: UIImage?
    
    init(title: String, message: String, iconImage: UIImage?) {
        self.title = title
        self.message = message
        self.iconImage = iconImage
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return message
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return message
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return title
    }
    
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        if let icon = iconImage {
            metadata.iconProvider = NSItemProvider(object: icon)
        }
        return metadata
    }
}


class RewardsCollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    private var rewards: [EarnedReward] = []
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .systemGroupedBackground
        cv.register(RewardCell.self, forCellWithReuseIdentifier: RewardCell.identifier)
        cv.dataSource = self
        cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No achievements yet. Complete challenges to earn trophies and shields!"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        
        let titleLabel = UILabel()
        titleLabel.text = "Rewards"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        navigationItem.titleView = titleLabel
        navigationItem.largeTitleDisplayMode = .never

        
        view.addSubview(collectionView)
        view.addSubview(emptyStateLabel)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
        rewards = RewardsManager.shared.rewards
        collectionView.reloadData()
        emptyStateLabel.isHidden = !rewards.isEmpty
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return rewards.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RewardCell.identifier, for: indexPath) as? RewardCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: rewards[indexPath.item])
        return cell
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding: CGFloat = 24 * 2 + 16
        let width = (collectionView.bounds.width - padding) / 2
        return CGSize(width: width, height: width * 1.35)
    }
}

class RewardCell: UICollectionViewCell {
    static let identifier = "RewardCell"
    
    private let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 16
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.05
        v.layer.shadowOffset = CGSize(width: 0, height: 4)
        v.layer.shadowRadius = 8
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(dateLabel)
        containerView.addSubview(detailsLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.5),
            iconImageView.heightAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.5),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            dateLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            detailsLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 4),
            detailsLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            detailsLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            detailsLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -12)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with reward: EarnedReward) {
        switch reward.type {
        case .individual:
            iconImageView.image = UIImage(named: "trophy_button_image")
            iconImageView.tintColor = nil
        case .family:
            iconImageView.image = UIImage(named: "shield_sticker")
            iconImageView.tintColor = nil
        }
        
        if let title = reward.challengeTitle {
            titleLabel.text = title
        } else {
            titleLabel.text = reward.type == .individual ? "Individual Trophy" : "Family Shield"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        dateLabel.text = formatter.string(from: reward.dateEarned)
        
        var detailsText = ""
        if let challengeType = reward.challengeType {
            detailsText += challengeType.capitalized
        }
        if let count = reward.participantsCount, count > 0 {
            if !detailsText.isEmpty {
                detailsText += " • "
            }
            detailsText += "\(count) Participant\(count == 1 ? "" : "s")"
        }
        detailsLabel.text = detailsText
    }
}
