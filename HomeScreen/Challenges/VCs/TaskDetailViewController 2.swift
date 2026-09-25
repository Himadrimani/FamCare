//
//  TaskDetailViewController.swift
//  HomeScreen
//
//  Created by Mohd Kushaad on 02/05/26.
//

import UIKit

class TaskDetailViewController: UIViewController {

    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var timeLeftLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var familyMembersCollectionView: UICollectionView!
    
    var challenge: ChallengeDetails?
    var familyMembers: [Profile]?
    var sortedMembers: [Profile] = []
    private var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupCollectionView()
        startTimer()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataManagerUpdate), name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        refreshData()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
        
        var members = allPossibleMembers.filter { participantIds.contains($0.profileId) }
        if members.isEmpty {
            members = allPossibleMembers
        }
        
        sortedMembers = members.sorted { m1, m2 in
            let prog1 = DataManager.shared.challengeProgress.first(where: { $0.challengeId == challenge.challengeId && $0.memberId == m1.profileId })
            let prog2 = DataManager.shared.challengeProgress.first(where: { $0.challengeId == challenge.challengeId && $0.memberId == m2.profileId })
            let val1 = prog1?.currentValue ?? 0
            let val2 = prog2?.currentValue ?? 0
            
            if val1 != val2 {
                return val1 > val2 // 1 (Completed) first, 0 (Pending) last
            }
            if let current = DataManager.shared.currentUser {
                if m1.profileId == current.profileId { return true }
                if m2.profileId == current.profileId { return false }
            }
            return DataManager.shared.getDisplayName(for: m1) < DataManager.shared.getDisplayName(for: m2)
        }
        
        familyMembersCollectionView.reloadData()
        setupUI()
    }
    
    private func setupUI() {
        guard let challenge = challenge else { return }
        nameLabel.text = challenge.name
        descriptionLabel.text = challenge.description
        
        guard let parentView = nameLabel.superview else { return }

        if parentView.tag != 999 {
            parentView.tag = 999

            let strongNameLabel = nameLabel!
            let strongDescLabel = descriptionLabel!
            let strongTimeLabel = timeLabel!
            let strongTimeLeftLabel = timeLeftLabel!

            parentView.subviews.forEach { $0.removeFromSuperview() }

            parentView.backgroundColor = .systemBackground
            parentView.layer.cornerRadius = 16
            parentView.layer.borderWidth = 1
            parentView.layer.borderColor = UIColor.systemGray6.cgColor
            parentView.layer.masksToBounds = false
            parentView.layer.shadowColor = UIColor.black.cgColor
            parentView.layer.shadowOpacity = 0.08
            parentView.layer.shadowOffset = CGSize(width: 0, height: 6)
            parentView.layer.shadowRadius = 10

            let imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.image = UIImage(named: challenge.bgImage)
            imageView.contentMode = (challenge.bgImage == "family_trek_challenge" || challenge.bgImage == "sleep_challenge") ? .scaleAspectFill : .scaleAspectFit
            imageView.layer.cornerRadius = 16
            imageView.clipsToBounds = true
            parentView.addSubview(imageView)

            let progressLabel = UILabel()
            progressLabel.tag = 998
            progressLabel.translatesAutoresizingMaskIntoConstraints = false
            progressLabel.font = .systemFont(ofSize: 40)
            progressLabel.textColor = .label
            parentView.addSubview(progressLabel)

            strongNameLabel.translatesAutoresizingMaskIntoConstraints = false
            strongDescLabel.translatesAutoresizingMaskIntoConstraints = false
            strongTimeLabel.translatesAutoresizingMaskIntoConstraints = false
            strongTimeLeftLabel.translatesAutoresizingMaskIntoConstraints = false

            strongNameLabel.font = .systemFont(ofSize: 22, weight: .bold)
            strongNameLabel.textColor = .label
            strongDescLabel.font = .systemFont(ofSize: 15, weight: .regular)
            strongDescLabel.textColor = .secondaryLabel
            strongDescLabel.numberOfLines = 0
            strongTimeLeftLabel.text = "ENDS IN:"
            strongTimeLeftLabel.font = .systemFont(ofSize: 14, weight: .semibold)
            strongTimeLeftLabel.textColor = .systemGray
            strongTimeLabel.textColor = UIColor(red: 70/255, green: 40/255, blue: 255/255, alpha: 1)

            parentView.addSubview(strongNameLabel)
            parentView.addSubview(strongDescLabel)
            parentView.addSubview(strongTimeLeftLabel)
            parentView.addSubview(strongTimeLabel)

            NSLayoutConstraint.activate([
                imageView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
                imageView.topAnchor.constraint(equalTo: parentView.topAnchor, constant: 16),
                imageView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -16),
                imageView.widthAnchor.constraint(equalTo: parentView.widthAnchor, multiplier: 0.5),

                strongNameLabel.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 20),
                strongNameLabel.topAnchor.constraint(equalTo: parentView.topAnchor, constant: 20),
                strongNameLabel.trailingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: -10),

                strongDescLabel.leadingAnchor.constraint(equalTo: strongNameLabel.leadingAnchor),
                strongDescLabel.topAnchor.constraint(equalTo: strongNameLabel.bottomAnchor, constant: 8),
                strongDescLabel.trailingAnchor.constraint(equalTo: strongNameLabel.trailingAnchor),

                strongTimeLeftLabel.leadingAnchor.constraint(equalTo: strongNameLabel.leadingAnchor),
                strongTimeLeftLabel.topAnchor.constraint(equalTo: strongDescLabel.bottomAnchor, constant: 24),

                strongTimeLabel.leadingAnchor.constraint(equalTo: strongNameLabel.leadingAnchor),
                strongTimeLabel.topAnchor.constraint(equalTo: strongTimeLeftLabel.bottomAnchor, constant: 4),

                progressLabel.leadingAnchor.constraint(equalTo: strongNameLabel.leadingAnchor),
                progressLabel.bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -20)
            ])
        }

        let progressRecords = DataManager.shared.challengeProgress.filter { $0.challengeId == challenge.challengeId }
        var totalPercentage = 0.0
        for record in progressRecords {
            let percentage = record.goalValue > 0 ? (record.currentValue / record.goalValue) * 100.0 : 0.0
            totalPercentage += min(100.0, percentage)
        }
        let progress = progressRecords.isEmpty ? 0.0 : totalPercentage / Double(progressRecords.count)
        if let progressLabel = parentView.viewWithTag(998) as? UILabel {
            progressLabel.text = "\(Int(progress))%"
        }
        
        // Find Mark Done button and Family Status label
        var markDoneButton: UIButton?
        var familyStatusLabel: UILabel?
        
        for subview in view.subviews {
            if let btn = subview as? UIButton, btn.titleLabel?.text == "Mark Done" || btn.configuration?.title == "Mark Done" {
                markDoneButton = btn
            }
            if let lbl = subview as? UILabel, lbl.text == "Family Status" {
                familyStatusLabel = lbl
            }
        }
        
        if let currentUser = DataManager.shared.currentUser {
            let progressRecord = DataManager.shared.challengeProgress.first(where: { $0.challengeId == challenge.challengeId && $0.memberId == currentUser.profileId })
            let isUserInChallenge = progressRecord != nil
            let userProgress = (progressRecord?.goalValue ?? 0 > 0) ? (progressRecord!.currentValue / progressRecord!.goalValue) * 100.0 : 0.0
            
            if !isUserInChallenge {
                markDoneButton?.isHidden = true
                for constraint in view.constraints {
                    if let first = constraint.firstItem as? UILabel, first == familyStatusLabel, constraint.firstAttribute == .top {
                        constraint.constant = -35
                    }
                }
            } else if userProgress >= 100.0 {
                markDoneButton?.isEnabled = false
                markDoneButton?.configuration?.title = "Completed"
                markDoneButton?.configuration?.baseBackgroundColor = .systemGreen
            }
        }
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
            timeLabel.text = "0d : 0h"
            timeLeftLabel.text = "ENDED"
            timer?.invalidate()
        } else {
            let days = Int(timeInterval) / (3600 * 24)
            let hours = (Int(timeInterval) % (3600 * 24)) / 3600
            
            // Format styling
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 28)]
            let faintColon = NSAttributedString(string: " : ", attributes: [.font: UIFont.systemFont(ofSize: 22, weight: .light), .foregroundColor: UIColor.gray])
            
            let combined = NSMutableAttributedString(string: "\(days)d", attributes: attrs)
            combined.append(faintColon)
            combined.append(NSAttributedString(string: "\(hours)h", attributes: attrs))
            
            timeLabel.attributedText = combined
            timeLeftLabel.text = "ENDS IN:"
        }
    }
    
    private func setupCollectionView() {
        familyMembersCollectionView.delegate = self
        familyMembersCollectionView.dataSource = self
        familyMembersCollectionView.register(UINib(nibName: "TaskDetailFamilyMemberCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "TaskDetailFamilyMemberCollectionViewCell")
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        familyMembersCollectionView.collectionViewLayout = layout
        familyMembersCollectionView.backgroundColor = .clear
    }
    @IBAction func markDoneButtonPressed(_ sender: Any) {
        guard let currentUser = DataManager.shared.currentUser,
              let challengeDetails = challenge else { return }
        
        if let idx = DataManager.shared.challengeProgress.firstIndex(where: { $0.challengeId == challengeDetails.challengeId && $0.memberId == currentUser.profileId }) {
            var progress = DataManager.shared.challengeProgress[idx]
            progress.currentValue = progress.goalValue // Mark as done
            progress.isSynced = false
            DataManager.shared.challengeProgress[idx] = progress
            
            SQLiteHelper.shared.saveChallengeProgress(progress)
            
            // Fetch latest progress from DataManager to determine state
            let progressRecords = DataManager.shared.challengeProgress.filter { $0.challengeId == challengeDetails.challengeId }
            
            let overlay = RewardsViewController(
                achievementType: .individual, 
                challengeId: challengeDetails.challengeId.uuidString, 
                challengeTitle: challengeDetails.name,
                challengeType: challengeDetails.type,
                participantsCount: progressRecords.count
            )
            self.present(overlay, animated: true)
            
            Task {
                await SyncManager.shared.syncAll()
            }
            
            refreshData()
        }
        
        // Hide/disable button or update its UI
        if let btn = sender as? UIButton {
            btn.isEnabled = false
            btn.configuration?.title = "Completed"
            btn.configuration?.baseBackgroundColor = .systemGreen
        }
    }
    @IBAction func editButtonTapped(_ sender: Any) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self, let targetChallenge = self.challenge else { return }
            
            DataManager.shared.challenges.removeAll { $0.challengeId == targetChallenge.challengeId }
            SQLiteHelper.shared.deleteChallengeDetails(challengeId: targetChallenge.challengeId)
            SyncManager.shared.deleteChallengeDetailsRemote(challengeId: targetChallenge.challengeId)
            DataManager.shared.saveDataLocally()
            
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

extension TaskDetailViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sortedMembers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TaskDetailFamilyMemberCollectionViewCell", for: indexPath) as! TaskDetailFamilyMemberCollectionViewCell
        
        guard let challenge = challenge else { return cell }
        let p = sortedMembers[indexPath.row]
        
        cell.nameLabel.text = DataManager.shared.getDisplayName(for: p)
        
        // Clear old initials label if any
        if let oldLabel = cell.profilePicture.viewWithTag(100) {
            oldLabel.removeFromSuperview()
        }
        cell.profilePicture.backgroundColor = .clear
        
        // Using static named image for profile pic
        ImageManager.shared.setImage(for: cell.profilePicture, from: p.profilePic)
        
        let progressRecord = DataManager.shared.challengeProgress.first(where: { $0.challengeId == challenge.challengeId && $0.memberId == p.profileId })
        let progress = (progressRecord?.goalValue ?? 0 > 0) ? (progressRecord!.currentValue / progressRecord!.goalValue) * 100.0 : 0.0
        let isCompleted = progress >= 100.0
        
        if isCompleted {
            cell.progressLabel.text = "Completed"
            cell.progressLabel.textColor = UIColor(red: 0, green: 153/255, blue: 76/255, alpha: 1) // Dark green text
            cell.progressView.backgroundColor = UIColor(red: 204/255, green: 255/255, blue: 229/255, alpha: 1) // Light green capsule
        } else {
            cell.progressLabel.text = "Pending"
            cell.progressLabel.textColor = .black // Black text
            cell.progressView.backgroundColor = .systemGray5 // Grey capsule
        }
        
        cell.layer.addBorder(edge: .bottom, color: .systemGray5, thickness: 1.0)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 60)
    }
}

extension CALayer {
    func addBorder(edge: UIRectEdge, color: UIColor, thickness: CGFloat) {
        let border = CALayer()
        switch edge {
        case .top:
            border.frame = CGRect(x: 0, y: 0, width: frame.width, height: thickness)
        case .bottom:
            border.frame = CGRect(x: 16, y: frame.height - thickness, width: frame.width - 32, height: thickness)
        case .left:
            border.frame = CGRect(x: 0, y: 0, width: thickness, height: frame.height)
        case .right:
            border.frame = CGRect(x: frame.width - thickness, y: 0, width: thickness, height: frame.height)
        default:
            break
        }
        border.backgroundColor = color.cgColor
        addSublayer(border)
    }
    
}

