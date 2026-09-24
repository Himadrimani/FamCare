//
//  AddChallengeFirstViewController.swift
//  HomeScreen
//
//  Created by Mohd Kushaad on 27/04/26.
//

import UIKit
import FoundationModels

class AddChallengeFirstViewController: UIViewController {

    @IBOutlet weak var quickSelectCollectionView: UICollectionView!
    @IBOutlet weak var userPromptTextView: UITextView!
    @IBOutlet weak var familyTaskCardView: UIView!
    @IBOutlet weak var fitnessCardView: UIView!
    @IBOutlet weak var generateChallengeButton: UIButton!
    
    private var loadingIndicator: UIActivityIndicatorView!
    
    private var generatedChallenge: ChallengeDetails?
    private var generatedProgress: [ChallengeProgress] = []
    
    private var titleTextField: UITextField!
    private var createChallengeButton: UIButton!
    
    struct QuickChallenge {
        let name: String
        let description: String
    }
    
    // Default challenges for the quick start section
    var defaultChallenges: [QuickChallenge] = []
    
    // Selection state for cards
    enum SelectedCard {
        case fitness
        case familyTask
    }
    var selectedCard: SelectedCard = .fitness
    var lastTappedSource: String?
    
    let selectedColor = UIColor(red: 0/255, green: 136/255, blue: 255/255, alpha: 1) // #0088FF
    let unselectedColor = UIColor.systemBackground
    
    // MARK: - Programmatic UI Elements
    private var fitnessCard: UIView!
    private var recreationalCard: UIView!
    private var otherTaskContainer: UIView!
    private var fitnessImageView: UIImageView!
    private var recreationalImageView: UIImageView!
    private var fitnessLabel: UILabel!
    private var recreationalLabel: UILabel!
    private var fitnessCheckmark: UIImageView!
    private var recreationalCheckmark: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hideStoryboardElements()
        buildUI()
        setupLoadingIndicator()
        updateCardSelectionState()
    }
    
    // MARK: - Hide Storyboard Elements
    
    private func hideStoryboardElements() {
        // Hide all storyboard-connected elements — we build everything programmatically
        fitnessCardView?.isHidden = true
        familyTaskCardView?.isHidden = true
        fitnessCardView?.superview?.isHidden = true // Hide the stack view wrapper
        userPromptTextView?.isHidden = true
        generateChallengeButton?.isHidden = true
        quickSelectCollectionView?.isHidden = true
        
        // Also hide the "Quick Start" label if it exists in storyboard
        for subview in view.subviews {
            if let label = subview as? UILabel, label.text == "Quick Start" {
                label.isHidden = true
            }
        }
    }
    
    // MARK: - Build UI
    
    private func buildUI() {
        // Keyboard dismiss gestures
        let tapToDismiss = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapToDismiss.cancelsTouchesInView = false
        view.addGestureRecognizer(tapToDismiss)
        
        let swipeDownToDismiss = UISwipeGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        swipeDownToDismiss.direction = .down
        swipeDownToDismiss.cancelsTouchesInView = false
        view.addGestureRecognizer(swipeDownToDismiss)
        
        // Main scroll view for adaptability
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        // --- Cards Row ---
        let cardsContainer = UIStackView()
        cardsContainer.axis = .horizontal
        cardsContainer.spacing = 16
        cardsContainer.distribution = .fillEqually
        cardsContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardsContainer)
        
        fitnessCard = createChallengeCard(
            imageName: "family_trek_challenge",
            title: "Fitness Challenge",
            isFitness: true
        )
        recreationalCard = createChallengeCard(
            imageName: "task_image",
            title: "Recreational Challenge",
            isFitness: false
        )
        
        cardsContainer.addArrangedSubview(fitnessCard)
        cardsContainer.addArrangedSubview(recreationalCard)
        
        // Tap gestures on cards
        let fitTap = UITapGestureRecognizer(target: self, action: #selector(fitnessCardTapped))
        fitnessCard.addGestureRecognizer(fitTap)
        
        let recTap = UITapGestureRecognizer(target: self, action: #selector(familyCardTapped))
        recreationalCard.addGestureRecognizer(recTap)
        
        // --- Create Challenge Button ---
        createChallengeButton = UIButton(type: .system)
        createChallengeButton.setTitle("Create Challenge", for: .normal)
        createChallengeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        createChallengeButton.backgroundColor = selectedColor
        createChallengeButton.setTitleColor(.white, for: .normal)
        createChallengeButton.layer.cornerRadius = 14
        createChallengeButton.translatesAutoresizingMaskIntoConstraints = false
        createChallengeButton.addTarget(self, action: #selector(createManualChallenge), for: .touchUpInside)
        contentView.addSubview(createChallengeButton)
        
        // --- Separator ---
        let separatorLine = UIView()
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.backgroundColor = .separator
        contentView.addSubview(separatorLine)
        
        // --- "or" label ---
        let orLabel = UILabel()
        orLabel.text = "or"
        orLabel.font = .systemFont(ofSize: 14, weight: .medium)
        orLabel.textColor = .tertiaryLabel
        orLabel.textAlignment = .center
        orLabel.backgroundColor = view.backgroundColor ?? .systemBackground
        orLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(orLabel)
        
        // --- Other Task Section ---
        otherTaskContainer = UIView()
        otherTaskContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(otherTaskContainer)
        
        // Glass plus button
        let plusButtonSize: CGFloat = 64
        let plusButton = UIView()
        plusButton.translatesAutoresizingMaskIntoConstraints = false
        plusButton.layer.cornerRadius = plusButtonSize / 2
        plusButton.clipsToBounds = true
        otherTaskContainer.addSubview(plusButton)
        
        // Glass background
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = plusButtonSize / 2
        blurView.clipsToBounds = true
        plusButton.addSubview(blurView)
        
        // Subtle border for glass effect
        plusButton.layer.borderWidth = 1
        plusButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        
        // Shadow for depth
        plusButton.layer.masksToBounds = false
        plusButton.clipsToBounds = false
        plusButton.layer.shadowColor = UIColor.black.cgColor
        plusButton.layer.shadowOpacity = 0.08
        plusButton.layer.shadowRadius = 12
        plusButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        
        // Plus icon
        let plusConfig = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        let plusIcon = UIImageView(image: UIImage(systemName: "plus", withConfiguration: plusConfig))
        plusIcon.tintColor = selectedColor
        plusIcon.translatesAutoresizingMaskIntoConstraints = false
        plusIcon.contentMode = .scaleAspectFit
        plusButton.addSubview(plusIcon)
        
        // Tap gesture for Other Task
        let otherTaskTap = UITapGestureRecognizer(target: self, action: #selector(otherTaskTapped))
        otherTaskContainer.addGestureRecognizer(otherTaskTap)
        otherTaskContainer.isUserInteractionEnabled = true
        
        // Other Task label
        let otherTaskLabel = UILabel()
        otherTaskLabel.text = "Other Task"
        otherTaskLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        otherTaskLabel.textColor = .label
        otherTaskLabel.textAlignment = .center
        otherTaskLabel.translatesAutoresizingMaskIntoConstraints = false
        otherTaskContainer.addSubview(otherTaskLabel)
        
        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Create a custom task for your family"
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        otherTaskContainer.addSubview(subtitleLabel)
        
        // Bottom spacer for scroll
        let bottomSpacer = UIView()
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bottomSpacer)
        
        // --- Constraints ---
        let horizontalPadding: CGFloat = 24
        
        NSLayoutConstraint.activate([
            // Cards
            cardsContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            cardsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalPadding),
            cardsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalPadding),
            cardsContainer.heightAnchor.constraint(equalToConstant: 200),
            
            // Create button
            createChallengeButton.topAnchor.constraint(equalTo: cardsContainer.bottomAnchor, constant: 28),
            createChallengeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalPadding),
            createChallengeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalPadding),
            createChallengeButton.heightAnchor.constraint(equalToConstant: 54),
            
            // Separator line
            separatorLine.topAnchor.constraint(equalTo: createChallengeButton.bottomAnchor, constant: 32),
            separatorLine.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalPadding + 20),
            separatorLine.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -(horizontalPadding + 20)),
            separatorLine.heightAnchor.constraint(equalToConstant: 0.5),
            
            // "or" label centered on separator
            orLabel.centerYAnchor.constraint(equalTo: separatorLine.centerYAnchor),
            orLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            orLabel.widthAnchor.constraint(equalToConstant: 40),
            
            // Other Task container
            otherTaskContainer.topAnchor.constraint(equalTo: separatorLine.bottomAnchor, constant: 32),
            otherTaskContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalPadding),
            otherTaskContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalPadding),
            
            // Plus button
            plusButton.topAnchor.constraint(equalTo: otherTaskContainer.topAnchor),
            plusButton.centerXAnchor.constraint(equalTo: otherTaskContainer.centerXAnchor),
            plusButton.widthAnchor.constraint(equalToConstant: plusButtonSize),
            plusButton.heightAnchor.constraint(equalToConstant: plusButtonSize),
            
            blurView.topAnchor.constraint(equalTo: plusButton.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: plusButton.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: plusButton.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: plusButton.bottomAnchor),
            
            plusIcon.centerXAnchor.constraint(equalTo: plusButton.centerXAnchor),
            plusIcon.centerYAnchor.constraint(equalTo: plusButton.centerYAnchor),
            
            // Other Task label
            otherTaskLabel.topAnchor.constraint(equalTo: plusButton.bottomAnchor, constant: 14),
            otherTaskLabel.centerXAnchor.constraint(equalTo: otherTaskContainer.centerXAnchor),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: otherTaskLabel.bottomAnchor, constant: 6),
            subtitleLabel.centerXAnchor.constraint(equalTo: otherTaskContainer.centerXAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: otherTaskContainer.bottomAnchor),
            
            // Bottom spacer
            bottomSpacer.topAnchor.constraint(equalTo: otherTaskContainer.bottomAnchor, constant: 40),
            bottomSpacer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bottomSpacer.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    // MARK: - Card Factory
    
    private func createChallengeCard(imageName: String, title: String, isFitness: Bool) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.backgroundColor = .secondarySystemBackground
        
        // Shadow (applied to wrapper, since card clips)
        card.layer.masksToBounds = false
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowRadius = 10
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        
        // Inner container to clip content
        let innerContainer = UIView()
        innerContainer.translatesAutoresizingMaskIntoConstraints = false
        innerContainer.clipsToBounds = true
        innerContainer.layer.cornerRadius = 20
        innerContainer.layer.cornerCurve = .continuous
        card.addSubview(innerContainer)
        
        NSLayoutConstraint.activate([
            innerContainer.topAnchor.constraint(equalTo: card.topAnchor),
            innerContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            innerContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            innerContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        
        // Image view
        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        innerContainer.addSubview(imageView)
        
        // Bottom gradient overlay for title readability
        let gradientContainer = UIView()
        gradientContainer.translatesAutoresizingMaskIntoConstraints = false
        gradientContainer.isUserInteractionEnabled = false
        innerContainer.addSubview(gradientContainer)
        
        // Title label
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        innerContainer.addSubview(label)
        
        // Selection checkmark
        let checkConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        let checkmark = UIImageView(image: UIImage(systemName: "checkmark.circle.fill", withConfiguration: checkConfig))
        checkmark.tintColor = .white
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.alpha = 0
        innerContainer.addSubview(checkmark)
        
        // Store references
        if isFitness {
            fitnessImageView = imageView
            fitnessLabel = label
            fitnessCheckmark = checkmark
        } else {
            recreationalImageView = imageView
            recreationalLabel = label
            recreationalCheckmark = checkmark
        }
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: innerContainer.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: innerContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: innerContainer.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: innerContainer.bottomAnchor),
            
            gradientContainer.leadingAnchor.constraint(equalTo: innerContainer.leadingAnchor),
            gradientContainer.trailingAnchor.constraint(equalTo: innerContainer.trailingAnchor),
            gradientContainer.bottomAnchor.constraint(equalTo: innerContainer.bottomAnchor),
            gradientContainer.heightAnchor.constraint(equalTo: innerContainer.heightAnchor, multiplier: 0.45),
            
            label.leadingAnchor.constraint(equalTo: innerContainer.leadingAnchor, constant: 14),
            label.bottomAnchor.constraint(equalTo: innerContainer.bottomAnchor, constant: -14),
            label.trailingAnchor.constraint(lessThanOrEqualTo: checkmark.leadingAnchor, constant: -8),
            
            checkmark.trailingAnchor.constraint(equalTo: innerContainer.trailingAnchor, constant: -12),
            checkmark.topAnchor.constraint(equalTo: innerContainer.topAnchor, constant: 12)
        ])
        
        // Add gradient layer after layout
        DispatchQueue.main.async {
            let gradient = CAGradientLayer()
            gradient.colors = [
                UIColor.clear.cgColor,
                UIColor.black.withAlphaComponent(0.55).cgColor
            ]
            gradient.locations = [0.0, 1.0]
            gradient.frame = gradientContainer.bounds
            gradientContainer.layer.insertSublayer(gradient, at: 0)
            
            // Observe layout changes
            gradientContainer.layer.setNeedsLayout()
        }
        
        return card
    }
    
    // MARK: - Card Selection
    
    private func updateCardSelectionState() {
        let isFitnessSelected = selectedCard == .fitness
        
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
            // Fitness card
            self.fitnessCard.transform = isFitnessSelected ? .identity : CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.fitnessCard.alpha = isFitnessSelected ? 1.0 : 0.65
            self.fitnessCheckmark.alpha = isFitnessSelected ? 1.0 : 0.0
            
            // Border highlight
            if isFitnessSelected {
                self.fitnessCard.layer.borderWidth = 2.5
                self.fitnessCard.layer.borderColor = self.selectedColor.cgColor
            } else {
                self.fitnessCard.layer.borderWidth = 0
                self.fitnessCard.layer.borderColor = UIColor.clear.cgColor
            }
            
            // Recreational card
            self.recreationalCard.transform = !isFitnessSelected ? .identity : CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.recreationalCard.alpha = !isFitnessSelected ? 1.0 : 0.65
            self.recreationalCheckmark.alpha = !isFitnessSelected ? 1.0 : 0.0
            
            if !isFitnessSelected {
                self.recreationalCard.layer.borderWidth = 2.5
                self.recreationalCard.layer.borderColor = self.selectedColor.cgColor
            } else {
                self.recreationalCard.layer.borderWidth = 0
                self.recreationalCard.layer.borderColor = UIColor.clear.cgColor
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Update gradient frames
        updateGradientFrames(in: fitnessCard)
        updateGradientFrames(in: recreationalCard)
    }
    
    private func updateGradientFrames(in card: UIView) {
        guard let innerContainer = card.subviews.first else { return }
        for subview in innerContainer.subviews {
            if let gradientLayer = subview.layer.sublayers?.first as? CAGradientLayer {
                gradientLayer.frame = subview.bounds
            }
        }
    }
    
    // MARK: - Loading Indicator
    
    private func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func fitnessCardTapped() {
        selectedCard = .fitness
        updateCardSelectionState()
    }
    
    @objc private func familyCardTapped() {
        selectedCard = .familyTask
        updateCardSelectionState()
    }
    
    @objc private func otherTaskTapped() {
        lastTappedSource = "OtherTask"
        selectedCard = .familyTask // Same type as recreational (social)
        
        let familyNamesArray: [String] = {
            var names = DataManager.shared.allProfiles.map { $0.firstName }
            if let currentUser = DataManager.shared.currentUser {
                names.append(currentUser.firstName)
            }
            return names
        }()
        
        let result = InferredChallengeOutput(
            name: "Other Task",
            description: "A custom task for the family",
            subType: "social_task",
            goalValue: 1.0,
            durationDays: 7,
            participantNames: familyNamesArray
        )
        
        handleGeneratedOutput(result)
        performSegue(withIdentifier: "showPreviewChallenge", sender: self)
    }
    

    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func createManualChallenge() {
        view.endEditing(true)
        let title = (selectedCard == .fitness) ? "Fitness Challenge" : "Recreational Challenge"
        lastTappedSource = (selectedCard == .fitness) ? "Fitness" : "Recreational"
        
        let text = title.lowercased()
        
        var fallbackType = "steps"
        var fallbackGoal = 10000.0
        if text.contains("km") || text.contains("mile") || text.contains("distance") {
            fallbackType = "distance"
            fallbackGoal = text.contains("15") ? 15.0 : 5.0
        } else if text.contains("calorie") || text.contains("burn") {
            fallbackType = "calories"
            fallbackGoal = 2000.0
        }
        
        var durationDays = 7
        if text.contains("month") { durationDays = 30 }
        else if text.contains("tomorrow") { durationDays = 1 }
        else if text.contains("weekend") { durationDays = 2 }
        
        var familyNamesArray = DataManager.shared.allProfiles.map { $0.firstName }
        if let currentUser = DataManager.shared.currentUser {
            familyNamesArray.append(currentUser.firstName)
        }
        
        let result = InferredChallengeOutput(
            name: title,
            description: "Let's achieve this together: \(title)",
            subType: fallbackType,
            goalValue: fallbackGoal,
            durationDays: durationDays,
            participantNames: familyNamesArray
        )
        
        handleGeneratedOutput(result)
        performSegue(withIdentifier: "showPreviewChallenge", sender: self)
    }

    private func handleGeneratedOutput(_ result: InferredChallengeOutput) {
        guard let familyId = DataManager.shared.currentUser?.familyId else { return }
        
        let challengeId = UUID()
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(Double(max(result.durationDays, 1)) * 86400)
        
        let selectedType = (selectedCard == .fitness) ? "physical" : "social"
        
        let parentChallenge = ChallengeDetails(
            challengeId: challengeId,
            familyId: familyId,
            name: result.name,
            description: result.description ?? "",
            type: selectedType,
            subType: result.subType,
            status: "pending",
            bgImage: "",
            startDate: startDate,
            endDate: endDate,
            lastUpdatedAt: startDate,
            isSynced: false
        )
        
        self.generatedChallenge = parentChallenge
        
        let fullRoster = [DataManager.shared.currentUser].compactMap { $0 } + DataManager.shared.allProfiles
        var progressArray: [ChallengeProgress] = []
        
        for participantName in result.participantNames {
            if let matchedProfile = fullRoster.first(where: { $0.firstName.caseInsensitiveCompare(participantName) == .orderedSame }) {
                let progress = ChallengeProgress(
                    challengeId: challengeId,
                    memberId: matchedProfile.profileId,
                    goalValue: result.goalValue,
                    currentValue: 0.0,
                    lastUpdatedAt: startDate,
                    isSynced: false
                )
                progressArray.append(progress)
            }
        }
        
        self.generatedProgress = progressArray
    }
    
    @IBAction func cancelButtonTapped(_ sender: Any) {
        dismiss(animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPreviewChallenge" {
            let targetVC: PreviewChallengeViewController?
            if let navVC = segue.destination as? UINavigationController {
                targetVC = navVC.topViewController as? PreviewChallengeViewController
            } else {
                targetVC = segue.destination as? PreviewChallengeViewController
            }
            
            if let previewVC = targetVC {
                previewVC.precompiledDetails = self.generatedChallenge
                previewVC.precompiledProgress = self.generatedProgress
                previewVC.challengeType = (selectedCard == .fitness) ? "physical" : "social"
                previewVC.initialPrompt = ""
                previewVC.sourceSelection = self.lastTappedSource
            }
        }
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate (kept for storyboard compatibility)
extension AddChallengeFirstViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 0 // Quick Start removed
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "QuickSelectChallengeCollectionViewCell", for: indexPath) as! QuickSelectChallengeCollectionViewCell
        return cell
    }
}
