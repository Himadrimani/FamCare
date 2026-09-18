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
    
    private func setupUI() {
        guard let challenge = challenge else { return }
        challengeNameLabel.text = challenge.name
        challengeDescriptionLabel.text = challenge.description
        
        // Setup parent view styles dynamically via superview traversing
        if let timeView = challengeTimeLeftLabel.superview {
            timeView.backgroundColor = .white
            timeView.layer.cornerRadius = 16
        }
        
        if let parentView = challengeTimeLeftLabel.superview?.superview {
            parentView.backgroundColor = .systemBackground
            parentView.layer.cornerRadius = 24
            parentView.layer.borderWidth = 1
            parentView.layer.borderColor = UIColor.systemGray6.cgColor
            parentView.layer.shadowColor = UIColor.black.cgColor
            parentView.layer.shadowOpacity = 0.08
            parentView.layer.shadowOffset = CGSize(width: 0, height: 6)
            parentView.layer.shadowRadius = 12
        }
        
        // Style labels
        challengeTimeLeftLabel.textColor = UIColor(red: 70/255, green: 40/255, blue: 255/255, alpha: 1) // Deep blue-purple
        challengeDescriptionLabel.textColor = .darkGray
        
        // Find "Time Left" label and update it
        if let timeView = challengeTimeLeftLabel.superview {
            for subview in timeView.subviews {
                if let lbl = subview as? UILabel, lbl != challengeTimeLeftLabel {
                    lbl.textColor = .systemGray
                }
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
        
        var endsInLabel: UILabel?
        if let timeView = challengeTimeLeftLabel.superview {
            for subview in timeView.subviews {
                if let lbl = subview as? UILabel, lbl != challengeTimeLeftLabel {
                    endsInLabel = lbl
                }
            }
        }
        
        if timeInterval <= 0 {
            challengeTimeLeftLabel.text = "0d : 0h"
            endsInLabel?.text = "ENDED"
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
            
            challengeTimeLeftLabel.attributedText = combined
            endsInLabel?.text = "ENDS IN:"
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
        cell.configureCell(profile: member, completed: progressStats.completed, goal: progressStats.goal, metricName: progressStats.metric)
        return cell
    }
        
        func calculateMemberProgress(for member: Profile, in challenge: ChallengeDetails) -> (completed: Double, goal: Double, metric: String) {
            let progressRecord = DataManager.shared.challengeProgress.first { $0.challengeId == challenge.challengeId && $0.memberId == member.profileId }
            
            let completed = progressRecord?.currentValue ?? 0.0
            let goal = max(1.0, progressRecord?.goalValue ?? 1.0)
            
            var metric = "Completed"
            switch challenge.subType {
            case "steps": metric = "Steps"
            case "distance": metric = "km"
            case "caloriesBurned": metric = "kcal"
            case "sleepDuration": metric = "hrs Slept"
            case "activeMinutes": metric = "min Active"
            default: metric = "Completed"
            }
            
            return (completed, goal, metric)
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
    
