//
//  PreviewChallengeViewController.swift
//  HomeScreen
//
//  Created by Mohd Kushaad on 03/05/26.
//

import UIKit

class PreviewChallengeViewController: UIViewController {

    var challengeType: String = "physical"
    var initialPrompt: String = ""
    var familyMembers: [Profile] = []
    
    // Properties to catch AI-generated or pre-filled sandbox content
    var precompiledDetails: ChallengeDetails?
    var precompiledProgress: [ChallengeProgress]?
    
    // UI Elements
    let scrollView = UIScrollView()
    let contentView = UIStackView()
    
    let nameTextField = UITextField()
    let descriptionTextField = UITextField()
    let subtypeSegment = UISegmentedControl(items: ["Steps", "Calories", "Distance"])
    
    let participantsStack = UIStackView()
    var memberSwitches: [UUID: UISwitch] = [:]
    var memberGoalTextFields: [UUID: UITextField] = [:]
    
    let startDatePicker = UIDatePicker()
    let endDatePicker = UIDatePicker()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        self.title = "Preview Challenge"
        
        // Always ensure a Save button exists in the nav bar
        // (when presented programmatically, the storyboard bar button isn't created)
        if navigationItem.rightBarButtonItem == nil {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .save,
                target: self,
                action: #selector(savebuttonPressed(_:))
            )
        }
        
        // Fetch members
        if let currentUser = DataManager.shared.currentUser {
            familyMembers.append(currentUser)
        }
        familyMembers.append(contentsOf: DataManager.shared.allProfiles)
        
        if let details = precompiledDetails {
            challengeType = details.type
        }
        
        setupUI()
        prefillData()
    }
    
    private func setupUI() {
        // Keyboard dismiss gestures
        let tapToDismiss = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapToDismiss.cancelsTouchesInView = false
        view.addGestureRecognizer(tapToDismiss)
        
        let swipeDownToDismiss = UISwipeGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        swipeDownToDismiss.direction = .down
        swipeDownToDismiss.cancelsTouchesInView = false
        view.addGestureRecognizer(swipeDownToDismiss)
        
        // ScrollView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Content StackView
        contentView.axis = .vertical
        contentView.spacing = 20
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
        
        // --- Name ---
        let nameLabel = UILabel()
        nameLabel.text = "Challenge Name"
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        contentView.addArrangedSubview(nameLabel)
        
        nameTextField.borderStyle = .roundedRect
        nameTextField.placeholder = "Enter challenge name"
        contentView.addArrangedSubview(nameTextField)
        
        // --- Description ---
        let descLabel = UILabel()
        descLabel.text = "Description"
        descLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        contentView.addArrangedSubview(descLabel)
        
        descriptionTextField.borderStyle = .roundedRect
        descriptionTextField.placeholder = "Enter description"
        contentView.addArrangedSubview(descriptionTextField)
        
        // --- Subtype ---
        if challengeType != "social" {
            let subtypeLabel = UILabel()
            subtypeLabel.text = "Subtype"
            subtypeLabel.font = .systemFont(ofSize: 16, weight: .semibold)
            contentView.addArrangedSubview(subtypeLabel)
            
            subtypeSegment.selectedSegmentIndex = 0
            subtypeSegment.addTarget(self, action: #selector(subtypeChanged), for: .valueChanged)
            contentView.addArrangedSubview(subtypeSegment)
        }
        
        // --- Participants ---
        let participantsLabel = UILabel()
        participantsLabel.text = (challengeType == "social") ? "Participants" : "Participants & Goals"
        participantsLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        contentView.addArrangedSubview(participantsLabel)
        
        participantsStack.axis = .vertical
        participantsStack.spacing = 15
        contentView.addArrangedSubview(participantsStack)
        
        for member in familyMembers {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 10
            rowStack.alignment = .center
            
            let imgView = UIImageView()
            imgView.translatesAutoresizingMaskIntoConstraints = false
            imgView.widthAnchor.constraint(equalToConstant: 40).isActive = true
            imgView.heightAnchor.constraint(equalToConstant: 40).isActive = true
            imgView.layer.cornerRadius = 20
            imgView.clipsToBounds = true
            ImageManager.shared.setImage(for: imgView, from: member.profilePic)
            rowStack.addArrangedSubview(imgView)
            
            let nameLbl = UILabel()
            nameLbl.text = member.displayName
            rowStack.addArrangedSubview(nameLbl)
            
            let goalTF = UITextField()
            goalTF.borderStyle = .roundedRect
            goalTF.keyboardType = .numberPad
            goalTF.textAlignment = .right
            goalTF.translatesAutoresizingMaskIntoConstraints = false
            goalTF.widthAnchor.constraint(equalToConstant: 80).isActive = true
            memberGoalTextFields[member.profileId] = goalTF
            
            if challengeType == "social" {
                goalTF.isHidden = true
            }
            rowStack.addArrangedSubview(goalTF)
            
            let toggle = UISwitch()
            toggle.isOn = (member.profileId == DataManager.shared.currentUser?.profileId)
            let action = UIAction { _ in
                goalTF.isEnabled = toggle.isOn
            }
            toggle.addAction(action, for: .valueChanged)
            goalTF.isEnabled = toggle.isOn
            memberSwitches[member.profileId] = toggle
            rowStack.addArrangedSubview(toggle)
            
            participantsStack.addArrangedSubview(rowStack)
        }
        
        // --- Dates ---
        let startDateLabel = UILabel()
        startDateLabel.text = "Start Date"
        startDateLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        contentView.addArrangedSubview(startDateLabel)
        
        startDatePicker.datePickerMode = .date
        if #available(iOS 14.0, *) {
            startDatePicker.preferredDatePickerStyle = .compact
        }
        startDatePicker.minimumDate = Date()
        startDatePicker.addTarget(self, action: #selector(startDateChanged), for: .valueChanged)
        contentView.addArrangedSubview(startDatePicker)
        
        let endDateLabel = UILabel()
        endDateLabel.text = "End Date"
        endDateLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        contentView.addArrangedSubview(endDateLabel)
        
        endDatePicker.datePickerMode = .date
        if #available(iOS 14.0, *) {
            endDatePicker.preferredDatePickerStyle = .compact
        }
        endDatePicker.minimumDate = Calendar.current.date(byAdding: .day, value: 1, to: startDatePicker.date)
        endDatePicker.date = Calendar.current.date(byAdding: .day, value: 7, to: startDatePicker.date) ?? Date()
        contentView.addArrangedSubview(endDatePicker)
        
        // --- Spacer ---
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        contentView.addArrangedSubview(spacer)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func prefillData() {
        if let details = precompiledDetails {
            nameTextField.text = details.name
            descriptionTextField.text = details.description
            challengeType = details.type
            
            // Set Subtype
            if challengeType != "social" {
                let subTypeLower = details.subType.lowercased()
                if subTypeLower == "steps" {
                    subtypeSegment.selectedSegmentIndex = 0
                } else if subTypeLower == "calories" || subTypeLower == "caloriesburned" {
                    subtypeSegment.selectedSegmentIndex = 1
                } else if subTypeLower == "distance" {
                    subtypeSegment.selectedSegmentIndex = 2
                }
            }
            
            startDatePicker.date = details.startDate
            endDatePicker.date = details.endDate
            
            // Populate internal arrays / update UI based on precompiledProgress
            if let progressList = precompiledProgress {
                for member in familyMembers {
                    if let progress = progressList.first(where: { $0.memberId == member.profileId }) {
                        memberSwitches[member.profileId]?.isOn = true
                        memberGoalTextFields[member.profileId]?.isEnabled = true
                        memberGoalTextFields[member.profileId]?.text = "\(Int(progress.goalValue))"
                    } else {
                        memberSwitches[member.profileId]?.isOn = false
                        memberGoalTextFields[member.profileId]?.isEnabled = false
                    }
                }
            }
        } else {
            if !initialPrompt.isEmpty {
                nameTextField.text = initialPrompt
            }
            subtypeChanged() // Prefill goals
        }
    }
    
    @objc private func startDateChanged() {
        let minEndDate = Calendar.current.date(byAdding: .day, value: 1, to: startDatePicker.date)
        endDatePicker.minimumDate = minEndDate
        if let minDate = minEndDate, endDatePicker.date < minDate {
            endDatePicker.setDate(minDate, animated: true)
        }
    }
    
    @objc private func subtypeChanged() {
        if challengeType == "social" { return }
        let selectedIndex = subtypeSegment.selectedSegmentIndex
        
        for member in familyMembers {
            guard let tf = memberGoalTextFields[member.profileId] else { continue }
            var goalValue = 10000
            if selectedIndex == 0 { // Steps
                goalValue = member.stepGoal
            } else if selectedIndex == 1 { // Calories
                goalValue = member.caloriesGoal
            } else if selectedIndex == 2 { // Distance
                goalValue = member.distanceGoal
            }
            tf.text = "\(goalValue)"
        }
    }
    
    @IBAction func savebuttonPressed(_ sender: Any) {
        guard let name = nameTextField.text, !name.isEmpty else {
            // Show alert
            let alert = UIAlertController(title: "Missing Name", message: "Please enter a challenge name.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        let desc = descriptionTextField.text ?? ""
        var subTypeStr = "steps"
        if challengeType != "social" {
            let index = subtypeSegment.selectedSegmentIndex
            if index == 1 { subTypeStr = "calories" }
            else if index == 2 { subTypeStr = "distance" }
        } else {
            subTypeStr = "social_task"
        }
        
        // Adjust start date to current time if today
        var finalStartDate = startDatePicker.date
        if Calendar.current.isDateInToday(finalStartDate) {
            finalStartDate = Date()
        }
        
        let challengeId = UUID()
        let familyId = DataManager.shared.family?.familyId ?? UUID()
        
        var bgImageValue = "challenge_bg_1"
        if challengeType == "social" {
            bgImageValue = "task_image"
        } else {
            switch subTypeStr {
            case "calories":
                bgImageValue = "family_trek_challenge"
            case "steps":
                bgImageValue = "family_trek_challenge"
            case "distance":
                bgImageValue = "family_trek_challenge"
            default:
                bgImageValue = "task_image"
            }
        }
        
        
        
        let details = ChallengeDetails(
            challengeId: challengeId,
            familyId: familyId,
            name: name,
            description: desc,
            type: challengeType,
            subType: subTypeStr,
            status: "ongoing",
            bgImage: bgImageValue,
            startDate: finalStartDate,
            endDate: endDatePicker.date,
            lastUpdatedAt: Date(),
            isSynced: false
        )
        
        var progressList: [ChallengeProgress] = []
        for member in familyMembers {
            guard let toggle = memberSwitches[member.profileId], toggle.isOn else { continue }
            
            var goalVal: Double = 1.0 // Default for social
            if challengeType != "social" {
                if let tf = memberGoalTextFields[member.profileId], let text = tf.text, let val = Double(text) {
                    goalVal = val
                }
            }
            
            let progress = ChallengeProgress(
                challengeId: challengeId,
                memberId: member.profileId,
                goalValue: goalVal,
                currentValue: 0.0,
                lastUpdatedAt: Date(),
                isSynced: false
            )
            progressList.append(progress)
        }
        
        saveChallenge(details: details, progressList: progressList)
    }
    
    // Save the new challenge to the database and trigger sync
    func saveChallenge(details: ChallengeDetails, progressList: [ChallengeProgress]) {
        print("====== NEW CHALLENGE CREATED ======")
        print("Details: \(details)")
        print("Progress List: \(progressList)")
        print("===================================")
        
        // 1. Update DataManager caches
        DataManager.shared.challenges.append(details)
        DataManager.shared.challengeProgress.append(contentsOf: progressList)
        
        // 2. Save locally to SQLite
        SQLiteHelper.shared.saveChallengeDetails(details)
        for progress in progressList {
            SQLiteHelper.shared.saveChallengeProgress(progress)
        }
        
        // 3. Post notification for UI updates
        NotificationCenter.default.post(name: NSNotification.Name("ChallengeAddedNotification"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        
        // 4. Trigger remote sync
        Task {
            await SyncManager.shared.pushUnsyncedData()
        }
        
        // 5. Dismiss UI
        // Check if embedded in NavController
        if let nav = self.navigationController {
            nav.dismiss(animated: true)
        } else {
            self.dismiss(animated: true)
        }
    }

    @IBAction func saveButtonPressed(_ sender: Any) {
    }
}
