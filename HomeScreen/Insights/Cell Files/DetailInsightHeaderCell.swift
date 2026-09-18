//
//  DetailInsightHeaderCell.swift
//  HomeScreen
//
//  Created by GEU on 10/02/26.
//

import UIKit

// Protocol to handle header tap action and notify delegate with index
protocol DetailInsightHeaderCellDelegate: AnyObject {
    func didTapHeader(at index: Int) // Called when header is tapped
}

// Custom collection view cell used as a header for insight sections
class DetailInsightHeaderCell: UICollectionViewCell {
    @IBOutlet weak var iconImageView: UIImageView! // Displays icon for insight type
    @IBOutlet weak var titleLabel: UILabel! // Displays title of insight
    @IBOutlet weak var chevronImageView: UIImageView! // Displays expand/collapse arrow
    @IBOutlet weak var containerView: UIView! // Background container for styling
    
    weak var delegate: DetailInsightHeaderCellDelegate? // Delegate to handle tap events
    var index: Int = 0 // Index of the cell used for identification
    
    var isExpanded: Bool = false { // Tracks whether section is expanded or collapsed
        didSet {
            updateChevron() // Update arrow direction when state changes
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI() // Initial UI setup when cell is loaded
    }
    
    // Configures UI appearance and gesture handling
    private func setupUI() {
        containerView.layer.cornerRadius = 12
        containerView.backgroundColor = .systemGray6
        
        iconImageView.tintColor = .systemBlue
        iconImageView.contentMode = .scaleAspectFit
        
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        
        chevronImageView.image = UIImage(systemName: "chevron.down")
        chevronImageView.tintColor = .systemGray
        chevronImageView.contentMode = .scaleAspectFit
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(headerTapped))
        containerView.addGestureRecognizer(tapGesture)
        containerView.isUserInteractionEnabled = true
    }
    
    // Called when header is tapped
    @objc private func headerTapped() {
        delegate?.didTapHeader(at: index)
    }
    
    // Updates chevron rotation based on expansion state
    private func updateChevron() {
        UIView.animate(withDuration: 0.3) {
            self.chevronImageView.transform = self.isExpanded
                ? CGAffineTransform(rotationAngle: .pi)
                : .identity
        }
    }
    
    // Configures cell based on insight type and expansion state
    func configure(with type: InsightType, profile: Profile, index: Int, isExpanded: Bool) {
        self.index = index // Assign index
        self.isExpanded = isExpanded // Set expansion state
        
        switch type {
        case .steps:
            configureSteps()
        case .sleep:
            configureSleep()
        case .calories:
            configureCalories()
        case .heartRate:
            configureHeartRate()
        case .distance:
            configureDistance()
        case .hrv:
            configureHRV()
        }
        updateChevron() // Ensure chevron reflects correct state
    }
    
    // Configures UI for Steps insight
    private func configureSteps() {
        iconImageView.image = UIImage(systemName: "shoeprints.fill") // Steps icon
        iconImageView.tintColor = .systemGreen // Green color
        titleLabel.text = "Steps" // Title text
    }
    
    // Configures UI for Sleep insight
    private func configureSleep() {
        iconImageView.image = UIImage(systemName: "moon.fill") // Sleep icon
        iconImageView.tintColor = .systemIndigo // Indigo color
        titleLabel.text = "Sleep Duration" // Title text
    }
    
    // Configures UI for Calories insight
    private func configureCalories() {
        iconImageView.image = UIImage(systemName: "flame.fill") // Calories icon
        iconImageView.tintColor = .systemOrange // Orange color
        titleLabel.text = "Calories Burned" // Title text
    }
    
    // Configures UI for Heart Rate insight
    private func configureHeartRate() {
        iconImageView.image = UIImage(systemName: "heart.fill") // Heart icon
        iconImageView.tintColor = .systemPink // Pink color
        titleLabel.text = "Heart Rate" // Title text
    }
    
    // Configures UI for Distance insight
    private func configureDistance() {
        iconImageView.image = UIImage(systemName: "figure.walk") // Walking icon
        iconImageView.tintColor = .systemTeal // Teal color
        titleLabel.text = "Distance" // Title text
    }
    
    // Configures UI for Heart Rate Variability insight
    private func configureHRV() {
        iconImageView.image = UIImage(systemName: "waveform.path.ecg") // ECG waveform icon
        iconImageView.tintColor = .systemPurple // Purple color
        titleLabel.text = "Heart Rate Variability" // Title text
    }
}
