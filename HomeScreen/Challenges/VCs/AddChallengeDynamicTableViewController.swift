//
//  AddChallengeDynamicTableViewController.swift
//  HomeScreen
//
//  Created by Mohd Kushaad on 02/04/26.
//

import UIKit

enum ChallengeFormSection: Int, CaseIterable {
    case menus          // Participation, Type, Name, Description
    case goals          // Goal Edit + Member Goals
    case dates          // Start Date, End Date
}

class AddChallengeDynamicTableViewController: UITableViewController {
    
    
    var defaultChallenges: [Challenge] = [] // Loaded from your library
    var familyMembers: [Profile] = []  // From your new Roster struct
    
    // Current Form State
    var selectedParticipation: ChallengeParticipationType = .collaborative
    var selectedType: ChallengeType = .physical
    var selectedChallenge: Challenge?
    var addOnValue: Int = 10 // Default 10%
    var startDate = Date()
    var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.backgroundColor = .systemGroupedBackground
        
        if defaultChallenges.isEmpty {
            if DataManager.shared.defaultChallenges.isEmpty {
                // Legacy loadChallengeLibrary call removed
            }
            defaultChallenges = DataManager.shared.defaultChallenges
        }
        
        if familyMembers.isEmpty {
            if let currentUser = DataManager.shared.currentUser {
                familyMembers = [currentUser] + DataManager.shared.allProfiles
            }
        }
        
        setupInitialSelection()
    }

    func setupInitialSelection() {
        // Set default challenge based on initial physical/collaborative state
        selectedChallenge = defaultChallenges.first(where: {
            $0.challengeType == .physical && $0.participationType == .collaborative
        })
        addOnValue = selectedChallenge?.addOnValue ?? 10
    }

    // MARK: - Dynamic Calculation Logic
    func getCalculatedGoal(for member: Profile) -> Int {
        guard let subType = selectedChallenge?.challengeSubType else { return 10000 }
            
            // 1. Get the REAL base goal from the member's profile
            let baseGoal: Int
            switch subType {
            case .steps:
                baseGoal = member.stepGoal
            case .caloriesBurned:
                baseGoal = member.caloriesGoal
            case .distance:
                baseGoal = member.distanceGoal
            default:
                baseGoal = 10000 // Fallback
            }
            
            // 2. Apply the addOnValue percentage
            let multiplier = 1.0 + (Double(addOnValue) / 100.0)
            return Int(Double(baseGoal) * multiplier)
    }

    // MARK: - TableView Logic
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return ChallengeFormSection.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let formSection = ChallengeFormSection(rawValue: section) else { return nil }
        
        if self.tableView(tableView, numberOfRowsInSection: section) == 0 {
            return nil
        }
        
        switch formSection {
        case .menus: return "Type of Challenge"
        case .goals: return "Goal Details"
        case .dates: return "Duration"
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let rows = self.tableView(tableView, numberOfRowsInSection: section)
        return rows > 0 ? UITableView.automaticDimension : 0.1
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 20.0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let formSection = ChallengeFormSection(rawValue: section) else { return 0 }
        
        switch formSection {
        case .menus: return 4
        case .goals:
            var numRows = 0
            if selectedType == .physical {
                // Goal value cell if it's customizable
                if let challenge = selectedChallenge, challenge.isCustomizable {
                    numRows += 1
                }
                
                // Member goal cells
                if selectedParticipation == .collaborative {
                    numRows += familyMembers.count
                } else if selectedParticipation == .individual {
                    // Show just the profile user
                    if !familyMembers.isEmpty {
                        numRows += 1
                    }
                }
            }
            return numRows
        case .dates: return 2
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let formSection = ChallengeFormSection(rawValue: indexPath.section)!
        
        switch formSection {
        case .menus:
            let cell = tableView.dequeueReusableCell(withIdentifier: "MenuCell", for: indexPath)
            cell.selectionStyle = .none
            cell.accessoryType = .none
            
            let label = cell.contentView.subviews.compactMap { $0 as? UILabel }.first
            let button = cell.contentView.subviews.compactMap { $0 as? UIButton }.first
            
            button?.isHidden = false
            label?.numberOfLines = 0
            
            // Constrain text dynamically from bleeding off screen
            if let lbl = label, let btn = button {
                let hasTrailing = cell.contentView.constraints.contains {
                    ($0.firstItem === lbl && $0.firstAttribute == .trailing) ||
                    ($0.secondItem === lbl && $0.secondAttribute == .trailing)
                }
                if !hasTrailing {
                    lbl.trailingAnchor.constraint(lessThanOrEqualTo: btn.leadingAnchor, constant: -8).isActive = true
                }
            }
            
            if indexPath.row == 0 {
                label?.text = "Participation"
                let selfAction = UIAction(title: "Self", image: UIImage(systemName: "person.fill"), state: selectedParticipation == .individual ? .on : .off) { [weak self] _ in
                    self?.selectedParticipation = .individual
                    self?.selectedType = .physical
                    self?.didUpdateSelection()
                }
                let familyAction = UIAction(title: "Family", image: UIImage(systemName: "person.3.fill"), state: selectedParticipation == .collaborative ? .on : .off) { [weak self] _ in
                    self?.selectedParticipation = .collaborative
                    self?.didUpdateSelection()
                }
                button?.menu = UIMenu(title: "Participation", children: [selfAction, familyAction])
                button?.showsMenuAsPrimaryAction = true
                button?.changesSelectionAsPrimaryAction = true
                button?.setTitle(selectedParticipation == .individual ? "Self" : "Family", for: .normal)
                
            } else if indexPath.row == 1 {
                label?.text = "Activity Type"
                let physAction = UIAction(title: "Fitness", image: UIImage(systemName: "figure.walk"), state: selectedType == .physical ? .on : .off) { [weak self] _ in
                    self?.selectedType = .physical
                    self?.didUpdateSelection()
                }
                let socAction = UIAction(title: "Recreational", image: UIImage(systemName: "person.2.fill"), state: selectedType == .social ? .on : .off) { [weak self] _ in
                    self?.selectedType = .social
                    self?.didUpdateSelection()
                }
                if selectedParticipation == .individual {
                    socAction.attributes = .disabled
                }
                button?.menu = UIMenu(title: "Select Category", children: [physAction, socAction])
                button?.showsMenuAsPrimaryAction = true
                button?.changesSelectionAsPrimaryAction = true
                button?.setTitle(selectedType == .physical ? "Fitness" : "Recreational", for: .normal)
                
            } else if indexPath.row == 2 {
                label?.text = "Challenge Name"
                
                // 1. Filter challenges based on current state
                let filtered = defaultChallenges.filter {
                    $0.challengeType == self.selectedType &&
                    $0.participationType.rawValue == self.selectedParticipation.rawValue
                }
                
                // 2. Map challenges to actions
                let actions = filtered.map { chall in
                    let isSelected = selectedChallenge?.challengeId == chall.challengeId
                    return UIAction(title: chall.challengeName, state: isSelected ? .on : .off) { [weak self] action in
                        self?.selectedChallenge = chall
                        // Update the UI after selection
                        self?.didUpdateSelection()
                    }
                }
                
                // 3. Configure the button manually
                button?.menu = UIMenu(title: "Choose Challenge", children: actions)
                button?.showsMenuAsPrimaryAction = true
                
                // CRITICAL: Keep this false to prevent the crash
                button?.changesSelectionAsPrimaryAction = false
                
                // 4. Manually set the title to show the current selection
                let title = selectedChallenge?.challengeName ?? "Select"
                button?.setTitle(title, for: .normal)
            } else if indexPath.row == 3 {
                label?.text = selectedChallenge?.challengeDescription ?? "Select a challenge"
                button?.isHidden = true
            }
            return cell
            
        case .goals:
            let isCustomizable = (selectedChallenge?.challengeType == .physical && selectedChallenge?.isCustomizable == true)
            let isGoalRow = isCustomizable && (indexPath.row == 0)
            
            if isGoalRow {
                let cell = tableView.dequeueReusableCell(withIdentifier: "GoalValueCell", for: indexPath) as! GoalValueCell
                cell.selectionStyle = .none
                
                if !cell.goalTextField.isFirstResponder {
                    cell.goalTextField.text = "\(addOnValue)%"
                }
                
                cell.goalTextField.removeTarget(nil, action: nil, for: .editingChanged)
                cell.goalTextField.removeTarget(nil, action: nil, for: .editingDidEnd)
                cell.goalTextField.addTarget(self, action: #selector(goalValueTyping(_:)), for: .editingChanged)
                cell.goalTextField.addTarget(self, action: #selector(goalValueFinished(_:)), for: .editingDidEnd)
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "MemberGoalCell", for: indexPath)
                cell.selectionStyle = .none
                
                let memberIndex = isCustomizable ? (indexPath.row - 1) : indexPath.row
                
                if memberIndex < familyMembers.count {
                    let member = familyMembers[memberIndex]
                    let finalGoal = calculateFinalGoal(for: member)
                    let metric = getMetricString(for: selectedChallenge?.challengeSubType ?? .steps)
                    
                    cell.textLabel?.text = member.displayName
                    cell.detailTextLabel?.text = "\(finalGoal) \(metric)"
                }
                return cell
            }
            
        case .dates:
            let cell = tableView.dequeueReusableCell(withIdentifier: "DateCell", for: indexPath)
            cell.selectionStyle = .none
            let label = cell.contentView.subviews.compactMap { $0 as? UILabel }.first
            let button = cell.contentView.subviews.compactMap { $0 as? UIButton }.first
            
            button?.isHidden = true
            
            var datePicker = cell.contentView.subviews.compactMap { $0 as? UIDatePicker }.first
            if datePicker == nil {
                datePicker = UIDatePicker()
                datePicker?.preferredDatePickerStyle = .compact
                datePicker?.datePickerMode = .date
                datePicker?.translatesAutoresizingMaskIntoConstraints = false
                cell.contentView.addSubview(datePicker!)
                if let picker = datePicker {
                    NSLayoutConstraint.activate([
                        picker.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
                        picker.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
                    ])
                }
            }
            
            if indexPath.row == 0 {
                label?.text = "Start Date"
                datePicker?.date = startDate
                datePicker?.removeTarget(nil, action: nil, for: .valueChanged)
                datePicker?.addTarget(self, action: #selector(startDateChanged(_:)), for: .valueChanged)
            } else {
                label?.text = "End Date"
                datePicker?.date = endDate
                datePicker?.removeTarget(nil, action: nil, for: .valueChanged)
                datePicker?.addTarget(self, action: #selector(endDateChanged(_:)), for: .valueChanged)
            }
            return cell
        }
    }
    
    // MARK: -  My code
    
    func didUpdateSelection() {
        // Re-filter the available options
        let filteredOptions = defaultChallenges.filter {
            $0.challengeType == self.selectedType &&
            $0.participationType.rawValue == self.selectedParticipation.rawValue
        }
        
        // If the currently selected challenge isn't in the new filtered list, reset it
        if let current = selectedChallenge, !filteredOptions.contains(where: { $0.challengeId == current.challengeId }) {
            selectedChallenge = filteredOptions.first
        } else if selectedChallenge == nil {
            selectedChallenge = filteredOptions.first
        }
        
        // Sync the addOnValue from the newly selected challenge template if available
        if let challenge = selectedChallenge {
            self.addOnValue = challenge.addOnValue ?? 10
        }
        
        tableView.reloadData()
    }
    
    @objc func goalValueTyping(_ sender: UITextField) {
        let text = sender.text?.replacingOccurrences(of: "%", with: "") ?? ""
        if let val = Int(text) {
            self.addOnValue = val
            
            // Reload just the member rows dynamically while typing
            let numRows = tableView.numberOfRows(inSection: ChallengeFormSection.goals.rawValue)
            var indexPathsToReload = [IndexPath]()
            for i in 1..<numRows {
                indexPathsToReload.append(IndexPath(row: i, section: ChallengeFormSection.goals.rawValue))
            }
            if !indexPathsToReload.isEmpty {
                UIView.performWithoutAnimation {
                    tableView.reloadRows(at: indexPathsToReload, with: .none)
                }
            }
        }
    }
    
    @objc func goalValueFinished(_ sender: UITextField) {
        let text = sender.text?.replacingOccurrences(of: "%", with: "") ?? ""
        if let val = Int(text) {
            self.addOnValue = val
        }
        sender.text = "\(self.addOnValue)%"
    }

    @objc func startDateChanged(_ sender: UIDatePicker) {
        startDate = sender.date
        if startDate > endDate {
            endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
        }
        let indexSet = IndexSet(integer: ChallengeFormSection.dates.rawValue)
        tableView.reloadSections(indexSet, with: .none)
    }
    
    @objc func endDateChanged(_ sender: UIDatePicker) {
        endDate = sender.date
        if startDate > endDate {
            // Usually we wouldn't want to change startDate just because endDate changed,
            // but for symmetry or validation we can set startDate up to match
            startDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate)!
        }
        let indexSet = IndexSet(integer: ChallengeFormSection.dates.rawValue)
        tableView.reloadSections(indexSet, with: .none)
    }
    
    @IBAction func saveButtonTapped(_ sender: Any) {
        guard let template = selectedChallenge else { return }
            
        var progressDict: [String: Double] = [:]
        
        if selectedParticipation == .individual {
            if let userId = DataManager.shared.currentUser?.profileId {
                progressDict[userId.uuidString] = 0.0
            }
        } else {
            for member in familyMembers {
                progressDict[member.profileId.uuidString] = 0.0
            }
        }

        let finalAddOn = Double(addOnValue)

        let newChallenge = ChallengeCompleted(
            challenge: template,
            status: .ongoing,
            customGoal: finalAddOn,
            startDate: startDate,
            endDate: endDate,
            percentageCompleted: 0.0,
            memberProgress: progressDict,
            lastUpdatedAt: Date()
        )
        print("this is the new challenge: \(newChallenge)")
        DataManager.shared.addChallengeToFamily(newChallenge)
        
        NotificationCenter.default.post(name: NSNotification.Name("ChallengeAddedNotification"), object: nil)
        
        dismiss(animated: true)
    }
    
    func calculateFinalGoal(for member: Profile) -> Int {
        guard let subType = selectedChallenge?.challengeSubType else { return 0 }
        
        // Pull the base goal from the Profile struct
        let baseGoal: Int
        switch subType {
        case .steps: baseGoal = member.stepGoal
        case .caloriesBurned: baseGoal = member.caloriesGoal
        case .distance: baseGoal = member.distanceGoal
        default: baseGoal = 10000 // Fallback for types like sleep
        }
        
        // Calculate: Base + (Base * AddOn%)
        let extra = (Double(baseGoal) * Double(addOnValue)) / 100.0
        return baseGoal + Int(extra)
    }
    
    func getMetricString(for subType: ChallengeSubType) -> String {
        switch subType {
        case .distance: return "km"
        case .steps: return "steps"
        case .caloriesBurned: return "cal"
        case .sleepDuration, .sleepConsistency, .screenFreeTime: return "hrs"
        case .activeMinutes: return "mins"
        case .familyWalk: return "walks"
        case .familyDinner: return "dinners"
        case .familyMovieNight: return "nights"
        case .familyGame: return "games"
        }
    }
    
    @IBAction func cancelTapped(_ sender: Any) {
        dismiss(animated: true)
    }
}

class GoalValueCell: UITableViewCell {
    @IBOutlet weak var goalTextField: UITextField!
}
