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
    
    private var isAIAvailable: Bool = false
    private var loadingIndicator: UIActivityIndicatorView!
    
    private var generatedChallenge: ChallengeDetails?
    private var generatedProgress: [ChallengeProgress] = []
    
    private var titleTextField: UITextField!
    private var createChallengeButton: UIButton!
    private var aiContainer: UIStackView!
    private var aiButton: UIButton!
    
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
    
    let selectedColor = UIColor(red: 0/255, green: 136/255, blue: 255/255, alpha: 1) // #0088FF
    let unselectedColor = UIColor.systemBackground
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        setupCollectionView()
        loadDefaultChallenges()
        updateCardSelection()
        
        setupLoadingIndicator()
        checkAIAvailability()
    }
    
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
    
    private func checkAIAvailability() {
        Task {
            let availability = SystemLanguageModel.default.availability
            DispatchQueue.main.async {
                switch availability {
                case .available:
                    self.isAIAvailable = true
                    self.aiContainer?.isHidden = false
                default:
                    self.isAIAvailable = false
                    self.aiContainer?.isHidden = true
                }
            }
        }
    }

    private func setupViews() {
        // Setup Cards
        fitnessCardView.layer.cornerRadius = 16
        familyTaskCardView.layer.cornerRadius = 16
        
        // Add shadow for unselected cards look
        addShadow(to: fitnessCardView)
        addShadow(to: familyTaskCardView)
        
        // Add gesture recognizers
        let fitnessTap = UITapGestureRecognizer(target: self, action: #selector(fitnessCardTapped))
        fitnessCardView.addGestureRecognizer(fitnessTap)
        
        let familyTap = UITapGestureRecognizer(target: self, action: #selector(familyCardTapped))
        familyTaskCardView.addGestureRecognizer(familyTap)
        
        // Keyboard dismiss gestures
        let tapToDismiss = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapToDismiss.cancelsTouchesInView = false
        view.addGestureRecognizer(tapToDismiss)
        
        let swipeDownToDismiss = UISwipeGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        swipeDownToDismiss.direction = .down
        swipeDownToDismiss.cancelsTouchesInView = false
        view.addGestureRecognizer(swipeDownToDismiss)
        
        setupModernUI()
    }
    
    private func setupModernUI() {
        // Hide the original storyboard elements to make space for the polished UI
        userPromptTextView.isHidden = true
        generateChallengeButton.isHidden = true
        
        // 1. Title Text Field
        titleTextField = UITextField()
        titleTextField.placeholder = "Title of challenge"
        titleTextField.borderStyle = .none
        titleTextField.layer.cornerRadius = 12
        titleTextField.layer.borderWidth = 1
        titleTextField.layer.borderColor = UIColor.systemGray4.cgColor
        titleTextField.font = .systemFont(ofSize: 16)
        titleTextField.backgroundColor = .systemBackground
        titleTextField.translatesAutoresizingMaskIntoConstraints = false
        
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 50))
        titleTextField.leftView = paddingView
        titleTextField.leftViewMode = .always
        
        titleTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        view.addSubview(titleTextField)
        
        // 2. Primary Create Challenge Button
        createChallengeButton = UIButton(type: .system)
        createChallengeButton.setTitle("Create Challenge", for: .normal)
        createChallengeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        createChallengeButton.backgroundColor = selectedColor
        createChallengeButton.setTitleColor(.white, for: .normal)
        createChallengeButton.layer.cornerRadius = 14
        createChallengeButton.translatesAutoresizingMaskIntoConstraints = false
        createChallengeButton.addTarget(self, action: #selector(createManualChallenge), for: .touchUpInside)
        view.addSubview(createChallengeButton)
        
        // 3. Optional AI Section
        aiContainer = UIStackView()
        aiContainer.axis = .vertical
        aiContainer.alignment = .center
        aiContainer.spacing = 16
        aiContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let orLabel = UILabel()
        orLabel.text = "—— OR ——"
        orLabel.textColor = .systemGray3
        orLabel.font = .systemFont(ofSize: 13, weight: .bold)
        
        aiButton = UIButton(type: .system)
        aiButton.setTitle("Generate with AI ✨", for: .normal)
        aiButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        aiButton.setTitleColor(selectedColor, for: .normal)
        aiButton.backgroundColor = selectedColor.withAlphaComponent(0.1)
        aiButton.layer.cornerRadius = 12
        aiButton.addTarget(self, action: #selector(generateChallengeButtonPressed(_:)), for: .touchUpInside)
        aiButton.translatesAutoresizingMaskIntoConstraints = false
        aiButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        aiButton.widthAnchor.constraint(equalToConstant: 220).isActive = true
        
        aiContainer.addArrangedSubview(orLabel)
        aiContainer.addArrangedSubview(aiButton)
        view.addSubview(aiContainer)
        
        // Constraints
        NSLayoutConstraint.activate([
            titleTextField.topAnchor.constraint(equalTo: fitnessCardView.bottomAnchor, constant: 24),
            titleTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            titleTextField.heightAnchor.constraint(equalToConstant: 54),
            
            createChallengeButton.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 24),
            createChallengeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            createChallengeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            createChallengeButton.heightAnchor.constraint(equalToConstant: 54),
            
            aiContainer.topAnchor.constraint(equalTo: createChallengeButton.bottomAnchor, constant: 28),
            aiContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        updateCreateButtonState()
    }
    
    @objc private func textFieldDidChange() {
        updateCreateButtonState()
    }
    
    private func updateCreateButtonState() {
        let hasText = !(titleTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        
        createChallengeButton.isEnabled = hasText
        createChallengeButton.alpha = hasText ? 1.0 : 0.5
        
        if let aiBtn = aiButton {
            aiBtn.isEnabled = hasText
            aiBtn.alpha = hasText ? 1.0 : 0.5
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func addShadow(to view: UIView) {
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.05
        view.layer.shadowRadius = 8
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
    }
    
    @objc private func fitnessCardTapped() {
        selectedCard = .fitness
        updateCardSelection()
    }
    
    @objc private func familyCardTapped() {
        selectedCard = .familyTask
        updateCardSelection()
    }
    
    private func updateCardSelection() {
        let isFitnessSelected = selectedCard == .fitness
        
        // Animate selection
        UIView.animate(withDuration: 0.2) {
            self.styleCard(self.fitnessCardView, isSelected: isFitnessSelected)
            self.styleCard(self.familyTaskCardView, isSelected: !isFitnessSelected)
        }
    }
    
    private func styleCard(_ card: UIView, isSelected: Bool) {
        card.backgroundColor = isSelected ? selectedColor : unselectedColor
        let colorForItems: UIColor = isSelected ? .white : .label
        
        for subview in card.subviews {
            if let label = subview as? UILabel {
                label.textColor = colorForItems
            }
            if let imageView = subview as? UIImageView {
                imageView.tintColor = colorForItems
            }
        }
    }
    
    private func setupCollectionView() {
        quickSelectCollectionView.delegate = self
        quickSelectCollectionView.dataSource = self
        quickSelectCollectionView.register(UINib(nibName: "QuickSelectChallengeCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "QuickSelectChallengeCollectionViewCell")
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.estimatedItemSize = CGSize(width: 150, height: 44)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 16)
        quickSelectCollectionView.collectionViewLayout = layout
        quickSelectCollectionView.showsHorizontalScrollIndicator = false
    }
    
    private func loadDefaultChallenges() {
        defaultChallenges = [
            QuickChallenge(name: "Morning Walk", description: "A quick 15 min morning walk"),
            QuickChallenge(name: "Hydration", description: "Drink 2L of water today")
        ]
        quickSelectCollectionView.reloadData()
    }
    
    @objc private func createManualChallenge() {
        view.endEditing(true)
        guard let title = titleTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return }
        
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

    @IBAction func generateChallengeButtonPressed(_ sender: Any) {
        let assistantVC = AssistantViewController()
        let nav = UINavigationController(rootViewController: assistantVC)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }
    
    private func startAIParsing() {
        loadingIndicator.startAnimating()
        view.isUserInteractionEnabled = false
        
        let promptText = titleTextField.text ?? ""
        let currentDateString = Date().description
        
        // Assemble family names including the current user and roster
        var familyNamesArray = DataManager.shared.allProfiles.map { $0.firstName }
        if let currentUser = DataManager.shared.currentUser {
            familyNamesArray.append(currentUser.firstName)
        }
        let familyNames = familyNamesArray.joined(separator: ", ")
        
        let fullInstructionString = """
        User Request: \(promptText)
        Current System Time: \(currentDateString)
        Available Family Members: \(familyNames)
        """
        
        Task {
            do {
                let session = LanguageModelSession()
                let response = try await session.respond(to: fullInstructionString, generating: InferredChallengeOutput.self)
                let aiResult = response.content
                
                DispatchQueue.main.async {
                    self.handleGeneratedOutput(aiResult)
                    self.loadingIndicator.stopAnimating()
                    self.view.isUserInteractionEnabled = true
                    self.performSegue(withIdentifier: "showPreviewChallenge", sender: self)
                }
            } catch {
                print("AI Parsing Error: \(error)")
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.view.isUserInteractionEnabled = true
                    // If AI fails, fallback to manual creation smoothly
                    self.createManualChallenge()
                }
            }
        }
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
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "showPreviewChallenge" && isAIAvailable && sender is UIButton {
            // Block immediate transition from the storyboard to handle AI parsing manually
            return false
        }
        return true
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
                previewVC.initialPrompt = titleTextField.text ?? ""
            }
        }
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate
extension AddChallengeFirstViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return defaultChallenges.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "QuickSelectChallengeCollectionViewCell", for: indexPath) as! QuickSelectChallengeCollectionViewCell
        cell.configureCell(with: defaultChallenges[indexPath.row])
        
        // Styling the cell
        cell.layer.cornerRadius = 20
        cell.layer.borderWidth = 1
        cell.layer.borderColor = UIColor.systemGray5.cgColor
        cell.backgroundColor = .systemBackground
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let challenge = defaultChallenges[indexPath.row]
        titleTextField.text = challenge.name
        updateCreateButtonState()
    }
}
