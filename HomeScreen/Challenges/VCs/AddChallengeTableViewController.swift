import UIKit

class AddChallengeTableViewController: UITableViewController {

    @IBOutlet weak var challengeDescription: UILabel!
    
    var defaultChallenges: [ChallengeDetails] = []
    var selectedType: String = "physical"
    var selectedChallenge: ChallengeDetails?
    var goalValuesForEachMember: [String: Int] = [:]
    
    // Tracks current participation choice
    var selectedParticipation: String = "Family"
    
    
    @IBOutlet weak var endDateButton: UIButton!
    @IBOutlet weak var startDateButton: UIButton!
    @IBOutlet weak var selectParticipationButton: UIButton!
    @IBOutlet weak var selectTypeOfChallengeButton: UIButton!
    @IBOutlet weak var selectChallengeName: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //setting up buttons
        configureParticipationButton()
        configureChallengeTypeButton()
        updateChallengeNameMenu()    }

    // MARK: - Menu Configuration
    
    func configureParticipationButton() {
        let selfAction = UIAction(title: "Self", image: UIImage(systemName: "person.fill")) { _ in
            self.selectedParticipation = "Self"
            // Requirement: Force Physical and refresh menus
            self.selectedType = "physical"
            self.configureChallengeTypeButton()
            self.updateChallengeNameMenu()
        }
        
        let familyAction = UIAction(title: "Family", image: UIImage(systemName: "person.3.fill")) { _ in
            self.selectedParticipation = "Family"
            self.configureChallengeTypeButton()
        }

        let menu = UIMenu(title: "Participation", children: [selfAction, familyAction])
        
        selectParticipationButton.menu = menu
        selectParticipationButton.showsMenuAsPrimaryAction = true
        selectParticipationButton.changesSelectionAsPrimaryAction = true
    }
    
    func configureChallengeTypeButton() {
        let physicalAction = UIAction(title: "Physical", image: UIImage(systemName: "figure.walk")) { _ in
            self.selectedType = "physical"
            self.updateChallengeNameMenu()
        }
        
        let socialAction = UIAction(title: "Social", image: UIImage(systemName: "person.2.fill")) { _ in
            self.selectedType = "social"
            self.updateChallengeNameMenu()
        }

        // Requirement: Disable Social if "Self" is selected
        if selectedParticipation == "Self" {
            socialAction.attributes = .disabled
        }

        let menu = UIMenu(title: "Select Category", children: [physicalAction, socialAction])
        
        selectTypeOfChallengeButton.menu = menu
        selectTypeOfChallengeButton.showsMenuAsPrimaryAction = true
        selectTypeOfChallengeButton.changesSelectionAsPrimaryAction = true
        
        // Ensure button title reflects the forced 'Physical' state if needed
        if selectedParticipation == "Self" {
            selectTypeOfChallengeButton.setTitle("Physical", for: .normal)
        }
    }

    func updateChallengeNameMenu() {
        let filteredOptions = defaultChallenges.filter { $0.type == selectedType }
        
        let menuActions = filteredOptions.map { challenge in
            return UIAction(title: challenge.name) { [weak self] _ in
                self?.selectedChallenge = challenge
                // Requirement: Update the label with the selected challenge's description
                self?.challengeDescription.text = challenge.description
            }
        }

        let menu = UIMenu(title: "Choose Challenge", children: menuActions)
        selectChallengeName.menu = menu
        selectChallengeName.showsMenuAsPrimaryAction = true
        selectChallengeName.changesSelectionAsPrimaryAction = true
        
        // Auto-select the first one and set initial description
        if let firstChallenge = filteredOptions.first {
            self.selectedChallenge = firstChallenge
            self.challengeDescription.text = firstChallenge.description
            // Manually set button title since it doesn't change automatically on first load
            selectChallengeName.setTitle(firstChallenge.name, for: .normal)
        }
    }

    
    @IBAction func cancelButtonTapped(_ sender: Any) {
        dismiss(animated: true)
    }
}



















//import UIKit
//
//class AddChallengeTableViewController: UITableViewController {
//
//    @IBOutlet weak var challengeDescription: UILabel!
//    var defaultChallenges: [Challenge] = []
//    // Track the currently selected category and specific challenge
//    var selectedType: ChallengeType = .physical
//    var selectedChallenge: Challenge?
//    
//    @IBOutlet weak var selectParticipationButton: UIButton!
//    @IBOutlet weak var selectTypeOfChallengeButton: UIButton!
//    @IBOutlet weak var selectChallengeName: UIButton!
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        
//        // Initial setup
//        configureChallengeTypeButton()
//        updateChallengeNameMenu() // Load initial physical challenges
//    }
//
//    // MARK: - Menu Configuration
//    
//    func configureChallengeTypeButton() {
//        // Use your Enum cases for the type selection
//        let physicalAction = UIAction(title: "Physical", image: UIImage(systemName: "figure.walk")) { _ in
//            self.selectedType = .physical
//            self.updateChallengeNameMenu()
//        }
//        
//        let socialAction = UIAction(title: "Social", image: UIImage(systemName: "person.2.fill")) { _ in
//            self.selectedType = .social
//            self.updateChallengeNameMenu()
//        }
//
//        let menu = UIMenu(title: "Select Category", children: [physicalAction, socialAction])
//        
//        selectTypeOfChallengeButton.menu = menu
//        selectTypeOfChallengeButton.showsMenuAsPrimaryAction = true
//        selectTypeOfChallengeButton.changesSelectionAsPrimaryAction = true
//    }
//
//    func updateChallengeNameMenu() {
//        // 1. Filter the library based on the selected type (Physical or Social)
//        let filteredOptions = defaultChallenges.filter { $0.challengeType == selectedType }
//        
//        // 2. Create actions for the filtered list
//        let menuActions = filteredOptions.map { challenge in
//            return UIAction(title: challenge.challengeName) { [weak self] _ in
//                self?.selectedChallenge = challenge
//                print("Ready to start: \(challenge.challengeName)")
//            }
//        }
//
//        // 3. Update the menu on the second button
//        let menu = UIMenu(title: "Choose Challenge", children: menuActions)
//        selectChallengeName.menu = menu
//        selectChallengeName.showsMenuAsPrimaryAction = true
////        selectChallengeName.changesSelectionAsPrimaryAction = true
//        
//        // Auto-select the first one in the list as default
//        self.selectedChallenge = filteredOptions.first
//    }
//    
//    // MARK: - Save Logic
//    
////    @IBAction func startChallengeTapped(_ sender: Any) {
////        guard let challengeTemplate = selectedChallenge else { return }
////        
////        // Create a new ChallengeCompleted instance based on your data model
////        let newChallenge = ChallengeCompleted(
////            challengeId: challengeTemplate,
////            status: .ongoing,
////            customGoal: nil, // You can add an input field for this later
////            startDate: Date(),
////            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!, // 1 week default
////            percentageCompleted: 0.0,
//            memberProgress: [DataManager.shared.currentUser?.profileId.uuidString ?? "": 0.0],
////            lastUpdatedAt: Date()
////        )
////        
////        // Add to DataManager
////        DataManager.shared.family?.challenge.append(newChallenge)
////        
////        dismiss(animated: true)
////    }
//
//    @IBAction func cancelButtonTapped(_ sender: Any) {
//        dismiss(animated: true)
//    }
//}
