//
//  FamilyActivityScoreCollectionViewCell.swift
//  HomeScreen
//
//  Created by Himadri on 1/02/26.
//
import UIKit

// FLOW OF THIS CELL
// CollectionViewController fetches challenge data
// Controller calls configure() and passes data to this cell
// Cell updates title, progress value and avatars
// Progress bar width is adjusted using Auto Layout constraint
// Cell renders as a challenge card in the collection view

class ChallengesCollectionViewCell: UICollectionViewCell {

    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var avatarStackView: UIStackView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var progressBarBackground: UIView!
    @IBOutlet weak var progressBarFill: UIView!

    @IBOutlet weak var progressBarFillWidthConstraint: NSLayoutConstraint!

    private var currentProgress: Double = 0.0
    // Stores progress value normalized between 0 and 1

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    private func setupUI() {

        containerView.layer.cornerRadius = 32
        containerView.layer.masksToBounds = true

        backgroundImageView.layer.cornerRadius = 32

        progressBarBackground.layer.cornerRadius = 6
        progressBarFill.layer.cornerRadius = 6
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateProgressBar()
    }

    func configure(
        with challengeDetails: ChallengeDetails,
        percentageCompleted: Double,
        familyMembers: [Profile]
    ) {

        titleLabel.text = challengeDetails.name
        // Sets challenge title
        backgroundImageView.image = UIImage(named: challengeDetails.bgImage)
            
        if percentageCompleted > 1 {
            // Checks if value is in 0–100 format
            currentProgress =
                percentageCompleted / 100
            // Converts to 0–1 range
        } else {
            currentProgress =
                percentageCompleted
            // Already normalized
        }

        progressLabel.text =
            "\(Int(currentProgress * 100))% Completed"
        // Shows percentage text

//        configureAvatars(   // Builds avatar views
//            familyMembers: familyMembers,
//            memberProgress:
//                challengeCompleted.memberProgress
//        )

        updateProgressBar()   // Updates progress bar width
    }

    private func updateProgressBar() {   // Adjusts fill width

        guard progressBarBackground.bounds.width > 0 else { return }
        // Ensures layout size is available

        let fillWidth =
            progressBarBackground.bounds.width *
            CGFloat(currentProgress)
        // Calculates new width

        progressBarFillWidthConstraint.constant =
            max(10, fillWidth)
        // Applies width to constraint, keeping it valid for layout constraints
    }

    private func configureAvatars(   // Creates avatar views
        familyMembers: [Profile],
        memberProgress: [String: Double]
    ) {

        avatarStackView.arrangedSubviews.forEach {
            // Removes old avatar views
            avatarStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let sortedMembers = familyMembers.sorted {
            let p1 = memberProgress[$0.profileId.uuidString] ?? 0
            let p2 = memberProgress[$1.profileId.uuidString] ?? 0
            return p1 > p2
        }

        for profile in sortedMembers {
            // Adds avatars in sorted order
            let avatarView =
                createAvatarView(profilePic:
                    profile.profilePic)

            avatarStackView.addArrangedSubview(avatarView)
        }
    }

    private func createAvatarView(
        profilePic: String
    ) -> UIView {

        let size: CGFloat = 50   // Avatar size constant

        let containerView = UIView()   // Wrapper view
        containerView.translatesAutoresizingMaskIntoConstraints = false
        // Enables Auto Layout

        let ringView = UIView()   // Circular border view
        ringView.translatesAutoresizingMaskIntoConstraints = false
        ringView.backgroundColor = .clear
        ringView.layer.cornerRadius = size / 2   // Makes circle
        ringView.layer.borderWidth = 3   // Border thickness
        ringView.layer.borderColor = UIColor.white.cgColor
        // Border color

        let imageView = UIImageView()   // Profile image
        imageView.translatesAutoresizingMaskIntoConstraints = false
        ImageManager.shared.setImage(for: imageView, from: profilePic)
        // Loads image from assets
        imageView.contentMode = .scaleAspectFill
        // Fills circle properly
        imageView.backgroundColor = .lightGray
        // Placeholder color
        imageView.layer.cornerRadius = (size - 6) / 2
        // Inner circle radius
        imageView.clipsToBounds = true
        // Crops image to circle

        containerView.addSubview(ringView)
        // Adds ring to container
        ringView.addSubview(imageView)

        // Constraints must be programmatic as avatars are created dynamically based on member count
        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(
                equalToConstant: size),
            containerView.heightAnchor.constraint(
                equalToConstant: size),

            ringView.widthAnchor.constraint(
                equalToConstant: size),
            ringView.heightAnchor.constraint(
                equalToConstant: size),
            ringView.centerXAnchor.constraint(
                equalTo: containerView.centerXAnchor),
            ringView.centerYAnchor.constraint(
                equalTo: containerView.centerYAnchor),

            imageView.widthAnchor.constraint(
                equalToConstant: size - 6),
            imageView.heightAnchor.constraint(
                equalToConstant: size - 6),
            imageView.centerXAnchor.constraint(
                equalTo: ringView.centerXAnchor),
            imageView.centerYAnchor.constraint(
                equalTo: ringView.centerYAnchor)
        ])

        return containerView
    }
}
