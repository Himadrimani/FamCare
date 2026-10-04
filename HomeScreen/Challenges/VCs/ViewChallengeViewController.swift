//
//  ViewChallengeViewController.swift
//  HealthSharing
//
//  Created by Mohd Kushaad on 08/02/26.
//

import UIKit

class ViewChallengeViewController: UIViewController {

    var challenge: ChallengeDetails!
    var familyMembers: [Profile]!
    var sortedMembers: [Profile] = []
    private var timer: Timer?
    
    @IBOutlet weak var memberProgressCV: UICollectionView!
    @IBOutlet weak var challengeDescriptionLabel: UILabel!
    @IBOutlet weak var challengeNameLabel: UILabel!
    @IBOutlet weak var challengeTimeLeftLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        title = ""
        
        guard let _ = challenge,
              let _ = familyMembers else {
                    print("didnt receive challenge or family members in ViewChallengeViewController"); return }
        
        //registering cells
        registerCell(ofKind: "design02", with: "member_progress_cell")
        
        memberProgressCV.collectionViewLayout = generateLayout()
        
        memberProgressCV.dataSource = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataManagerUpdate), name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        setupUI()
        startTimer()
        refreshData()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard let challenge = challenge,
              let currentUser = DataManager.shared.currentUser else { return }
        
        let participantIds = DataManager.shared.challengeProgress
            .filter { $0.challengeId == challenge.challengeId }
            .map { $0.memberId }
            
        if participantIds.contains(currentUser.profileId) {
            HealthKitManager.shared.updateLocalChallengeProgress(challenge: challenge)
        }
    }
    
    @objc private func handleDataManagerUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshData()
        }
    }
    
    private func refreshData() {
        guard let challenge = challenge else { return }
        
        let participantIds = DataManager.shared.challengeProgress
            .filter { $0.challengeId == challenge.challengeId }
            .map { $0.memberId }
            
        var allPossibleMembers = familyMembers ?? []
        if let currentUser = DataManager.shared.currentUser, !allPossibleMembers.contains(where: { $0.profileId == currentUser.profileId }) {
            allPossibleMembers.append(currentUser)
        }
        
        let members = allPossibleMembers.filter { participantIds.contains($0.profileId) }
        
        sortedMembers = members.sorted { m1, m2 in
            let stats1 = calculateMemberProgress(for: m1, in: challenge)
            let stats2 = calculateMemberProgress(for: m2, in: challenge)
            let pct1 = stats1.goal > 0 ? (stats1.completed / stats1.goal) * 100.0 : 0
            let pct2 = stats2.goal > 0 ? (stats2.completed / stats2.goal) * 100.0 : 0
            
            if pct1 != pct2 {
                return pct1 > pct2
            }
            if let current = DataManager.shared.currentUser {
                if m1.profileId == current.profileId { return true }
                if m2.profileId == current.profileId { return false }
            }
            return DataManager.shared.getDisplayName(for: m1) < DataManager.shared.getDisplayName(for: m2)
        }
        
        memberProgressCV.reloadData()
    }
    
    // MARK: - Custom UI Elements
    private var backgroundImageView: UIImageView?
    private var daysPillView: UIView?
    private var hoursPillView: UIView?
    private var daysValueLabel: UILabel?
    private var daysSuffixLabel: UILabel?
    private var hoursValueLabel: UILabel?
    private var hoursSuffixLabel: UILabel?
    private var endsInLabel: UILabel?
    
    private func setupUI() {
        guard let challenge = challenge else { return }
        challengeNameLabel.text = challenge.name
        challengeDescriptionLabel.text = challenge.description
        
        guard let cardView = challengeTimeLeftLabel.superview?.superview else { return }
        let timeContainerView = challengeTimeLeftLabel.superview!
        
        // ── Card container styling ──
        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 20
        cardView.clipsToBounds = true
        cardView.layer.borderWidth = 0.5
        cardView.layer.borderColor = UIColor.separator.cgColor
        
        // ── Background image from challenge card ──
        let bgImageView = UIImageView()
        bgImageView.image = UIImage(named: challenge.bgImage)
        bgImageView.contentMode = .scaleAspectFit
        bgImageView.clipsToBounds = true
        bgImageView.alpha = 0.25
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        // Prevent the image from driving the card's size
        bgImageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        bgImageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        bgImageView.setContentCompressionResistancePriority(UILayoutPriority(1), for: .vertical)
        bgImageView.setContentCompressionResistancePriority(UILayoutPriority(1), for: .horizontal)
        cardView.insertSubview(bgImageView, at: 0)
        
        NSLayoutConstraint.activate([
            bgImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -4),
            bgImageView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -4),
            bgImageView.widthAnchor.constraint(equalTo: cardView.widthAnchor, multiplier: 0.45),
            bgImageView.heightAnchor.constraint(equalTo: cardView.heightAnchor, multiplier: 0.7),
        ])
        self.backgroundImageView = bgImageView
        
        // Bring text labels to front so they're always readable
        cardView.bringSubviewToFront(challengeNameLabel)
        cardView.bringSubviewToFront(challengeDescriptionLabel)
        cardView.bringSubviewToFront(timeContainerView)
        
        // ── Style title label ──
        challengeNameLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        challengeNameLabel.textColor = .label
        
        // ── Style description label ──
        challengeDescriptionLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        challengeDescriptionLabel.textColor = .secondaryLabel
        
        // ── Restyle the time container ──
        // Hide the original storyboard time container and its labels
        timeContainerView.backgroundColor = .clear
        timeContainerView.subviews.forEach { $0.isHidden = true }
        challengeTimeLeftLabel.isHidden = true
        
        // Find and hide the original "Time Left" label
        for subview in timeContainerView.subviews {
            if let lbl = subview as? UILabel {
                lbl.isHidden = true
            }
        }
        
        // Build custom "Ends in" label + pill containers
        let endsLabel = UILabel()
        endsLabel.text = "Ends in"
        endsLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        endsLabel.textColor = .secondaryLabel
        endsLabel.translatesAutoresizingMaskIntoConstraints = false
        self.endsInLabel = endsLabel
        
        // Days pill
        let daysPill = createTimePill()
        self.daysPillView = daysPill.container
        self.daysValueLabel = daysPill.valueLabel
        self.daysSuffixLabel = daysPill.suffixLabel
        
        // Hours pill
        let hoursPill = createTimePill()
        self.hoursPillView = hoursPill.container
        self.hoursValueLabel = hoursPill.valueLabel
        self.hoursSuffixLabel = hoursPill.suffixLabel
        
        // Pills stack
        let pillsStack = UIStackView(arrangedSubviews: [daysPill.container, hoursPill.container])
        pillsStack.axis = .horizontal
        pillsStack.spacing = 10
        pillsStack.distribution = .fillEqually
        pillsStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Vertical stack for "Ends in" + pills
        let timerStack = UIStackView(arrangedSubviews: [endsLabel, pillsStack])
        timerStack.axis = .vertical
        timerStack.spacing = 8
        timerStack.alignment = .leading
        timerStack.translatesAutoresizingMaskIntoConstraints = false
        
        timeContainerView.addSubview(timerStack)
        
        NSLayoutConstraint.activate([
            timerStack.topAnchor.constraint(equalTo: timeContainerView.topAnchor, constant: 4),
            timerStack.leadingAnchor.constraint(equalTo: timeContainerView.leadingAnchor),
            timerStack.bottomAnchor.constraint(lessThanOrEqualTo: timeContainerView.bottomAnchor, constant: -4),
            
            daysPill.container.widthAnchor.constraint(equalToConstant: 64),
            daysPill.container.heightAnchor.constraint(equalToConstant: 44),
            hoursPill.container.widthAnchor.constraint(equalToConstant: 64),
            hoursPill.container.heightAnchor.constraint(equalToConstant: 44),
        ])
    }
    
    private func createTimePill() -> (container: UIView, valueLabel: UILabel, suffixLabel: UILabel) {
        let container = UIView()
        container.backgroundColor = UIColor.systemGray6
        container.layer.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = UILabel()
        valueLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        valueLabel.textColor = .label
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let suffixLabel = UILabel()
        suffixLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        suffixLabel.textColor = .tertiaryLabel
        suffixLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(valueLabel)
        container.addSubview(suffixLabel)
        
        NSLayoutConstraint.activate([
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            valueLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            
            suffixLabel.lastBaselineAnchor.constraint(equalTo: valueLabel.lastBaselineAnchor),
            suffixLabel.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: 2),
            suffixLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -6),
        ])
        
        return (container, valueLabel, suffixLabel)
    }
    
    private func startTimer() {
        updateTimer()
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
    }
    
    @objc private func updateTimer() {
        guard let challenge = challenge else { return }
        let now = Date()
        let endDate = challenge.endDate
        let timeInterval = endDate.timeIntervalSince(now)
        
        if timeInterval <= 0 {
            daysValueLabel?.text = "0"
            daysSuffixLabel?.text = "d"
            hoursValueLabel?.text = "0"
            hoursSuffixLabel?.text = "h"
            endsInLabel?.text = "Ended"
            endsInLabel?.textColor = .systemRed
            daysPillView?.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
            hoursPillView?.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
            daysValueLabel?.textColor = .systemRed
            hoursValueLabel?.textColor = .systemRed
            timer?.invalidate()
        } else {
            let days = Int(timeInterval) / (3600 * 24)
            let hours = (Int(timeInterval) % (3600 * 24)) / 3600
            
            daysValueLabel?.text = "\(days)"
            daysSuffixLabel?.text = "d"
            hoursValueLabel?.text = "\(hours)"
            hoursSuffixLabel?.text = "h"
            endsInLabel?.text = "Ends in"
            endsInLabel?.textColor = .secondaryLabel
            
            // Use Apple system colors — indigo for urgency
            if days <= 1 {
                daysPillView?.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.12)
                hoursPillView?.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.12)
                daysValueLabel?.textColor = .systemOrange
                hoursValueLabel?.textColor = .systemOrange
            } else {
                daysPillView?.backgroundColor = UIColor.systemGray6
                hoursPillView?.backgroundColor = UIColor.systemGray6
                daysValueLabel?.textColor = .label
                hoursValueLabel?.textColor = .label
            }
        }
    }
    
    // MARK: - My code
    
    func registerCell(ofKind cell: String, with identifier: String) {
        memberProgressCV.register(UINib(nibName: cell, bundle: nil), forCellWithReuseIdentifier: identifier)
    }
    
    func generateLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout {
            (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
                
            // member progress cells
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            
            let section = NSCollectionLayoutSection(group: group)
            
            section.interGroupSpacing = 10
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 10, trailing: 16)
            
            return section
        }
    }
   
    @IBAction func editButtonTapped(_ sender: Any) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self, let targetChallenge = self.challenge else { return }
            
            DataManager.shared.challenges.removeAll { $0.challengeId == targetChallenge.challengeId }
            SQLiteHelper.shared.deleteChallengeDetails(challengeId: targetChallenge.challengeId)
            SyncManager.shared.deleteChallengeDetailsRemote(challengeId: targetChallenge.challengeId)
            
            let alert = UIAlertController(title: nil, message: "Challenge Deleted", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(okAction)
            
            if let nav = self.navigationController {
                nav.popViewController(animated: true)
                
                // Show the alert on the new top view controller after the transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    nav.topViewController?.present(alert, animated: true)
                }
            } else {
                self.dismiss(animated: true)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        actionSheet.addAction(deleteAction)
        actionSheet.addAction(cancelAction)
        
        if let popoverController = actionSheet.popoverPresentationController {
            if let barButtonItem = sender as? UIBarButtonItem {
                popoverController.barButtonItem = barButtonItem
            } else if let view = sender as? UIView {
                popoverController.sourceView = view
                popoverController.sourceRect = view.bounds
            } else {
                popoverController.sourceView = self.view
                popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
        }
        
        present(actionSheet, animated: true)
    }
    
    
}

extension ViewChallengeViewController: UICollectionViewDataSource {
    
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sortedMembers.count
    }
        
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "member_progress_cell", for: indexPath) as! design02
        
        let member = sortedMembers[indexPath.row]

        let progressStats = calculateMemberProgress(for: member, in: challenge)
        let isSocial = (challenge.type == "social")
        cell.configureCell(profile: member, completed: progressStats.completed, goal: progressStats.goal, metricName: progressStats.metric, isSocial: isSocial)
        cell.delegate = self
        return cell
    }
        
        func calculateMemberProgress(for member: Profile, in challenge: ChallengeDetails) -> (completed: Double, goal: Double, metric: String) {
            let progressRecord = DataManager.shared.challengeProgress.first { $0.challengeId == challenge.challengeId && $0.memberId == member.profileId }
            
            let completed = progressRecord?.currentValue ?? 0.0
            let goal = max(1.0, progressRecord?.goalValue ?? 1.0)
            
            var metric = "Completed"
            var displayCompleted = completed
            var displayGoal = goal
            
            switch challenge.subType {
            case "steps": metric = "Steps"
            case "distance": 
                metric = "km"
                displayCompleted = completed / 1000.0
                displayGoal = goal / 1000.0
            case "caloriesBurned": metric = "kcal"
            case "sleepDuration": metric = "hrs Slept"
            case "activeMinutes": metric = "min Active"
            default: metric = "Completed"
            }
            
            return (displayCompleted, displayGoal, metric)
        }
        
        func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
            
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath)
            
            if header.subviews.isEmpty {
                let label = UILabel(frame: CGRect(x: 0, y: 0, width: header.frame.width, height: header.frame.height))
                label.text = "Member Progress"
                label.font = .systemFont(ofSize: 18, weight: .bold)
                label.textColor = .label
                header.addSubview(label)
            }
            
            return header
        }
    }
    
extension ViewChallengeViewController: Design02Delegate {
    func design02DidTapShare(_ cell: design02) {
        guard let indexPath = memberProgressCV.indexPath(for: cell) else { return }
        guard let challenge = challenge else { return }
        
        let member = sortedMembers[indexPath.row]
        let name = member.firstName
        
        let progressStats = calculateMemberProgress(for: member, in: challenge)
        
        let rawPercent = (progressStats.goal > 0) ? (progressStats.completed / progressStats.goal) * 100.0 : 0
        let percent = min(rawPercent, 100.0)
        let isComplete = percent >= 100.0
        
        let percentStr = isComplete ? "100%" : "\(Int(percent))%"
        
        let title = "\(name)'s Challenge"
        let message = "[SHARE_CARD:CHALLENGE|\(name)|\(percentStr)|\(challenge.name)]"
        
        let storyboard = UIStoryboard(name: "Messages", bundle: nil)
        guard let createVC = storyboard.instantiateViewController(withIdentifier: "CreateTopicViewController") as? CreateTopicViewController else { return }
        
        createVC.prefilledTitle = title
        createVC.prefilledMessage = message
        
        let nav = UINavigationController(rootViewController: createVC)
        
        createVC.onTopicCreated = { [weak self] topicId in
            if let topic = DataManager.shared.topics.first(where: { $0.id == topicId }) {
                let chatVC = storyboard.instantiateViewController(withIdentifier: "TopicChatViewController") as! TopicChatViewController
                chatVC.viewModel = TopicChatViewModel(topic: topic)
                chatVC.hidesBottomBarWhenPushed = true
                self?.navigationController?.pushViewController(chatVC, animated: true)
            }
        }
        
        present(nav, animated: true)
    }
    
    func design02DidTapCheckbox(_ cell: design02, isChecked: Bool) {
        guard let indexPath = memberProgressCV.indexPath(for: cell) else { return }
        guard let challenge = challenge else { return }
        
        let member = sortedMembers[indexPath.row]
        
        // Find existing progress record
        if let index = DataManager.shared.challengeProgress.firstIndex(where: { $0.challengeId == challenge.challengeId && $0.memberId == member.profileId }) {
            let progress = DataManager.shared.challengeProgress[index]
            
            let updatedProgress = ChallengeProgress(
                challengeId: progress.challengeId,
                memberId: progress.memberId,
                goalValue: progress.goalValue,
                currentValue: isChecked ? 1.0 : 0.0,
                lastUpdatedAt: Date(),
                isSynced: false
            )
            
            // Update DataManager and SQLite
            DataManager.shared.challengeProgress[index] = updatedProgress
            SQLiteHelper.shared.saveChallengeProgress(updatedProgress)
            
            // Trigger Sync
            Task {
                await SyncManager.shared.pushUnsyncedData()
            }
            
            // Refresh to update UI and apply 'completed' rules globally
            NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        }
    }
}
