//
//  ChallengeFirstViewController.swift
//  HealthSharing
//
//  Created by Mohd Kushaad on 07/02/26.
//

import UIKit

class ChallengeFirstViewController: UIViewController {
    
    var challenges: [ChallengeDetails]?
    var familyMembers: [Profile]?
    var filteredChallenges: [ChallengeDetails] = []
    
    @IBOutlet weak var segmentControl: UISegmentedControl!
    @IBOutlet weak var challengeCV: UICollectionView!
    
    enum PastChallengeFilter: String {
        case recentlyCompleted = "Recently Completed"
        case allCompleted = "All Completed"
        case expired = "Expired / Not Completed"
    }

    private let filterButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        button.setImage(UIImage(systemName: "line.3.horizontal.decrease.circle", withConfiguration: config), for: .normal)
        button.tintColor = .black
        button.translatesAutoresizingMaskIntoConstraints = false
        button.showsMenuAsPrimaryAction = true
        button.isHidden = true
        return button
    }()
    
    private var currentPastFilter: PastChallengeFilter? = nil
  
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    
//        title = "Challenges"
        
        //registering the cell
        challengeCV.register(UINib(nibName: "NewChallengeCollectionViewCell", bundle: nil),
                             forCellWithReuseIdentifier: "challenge_cell")
        
        //dividing challenges into ongoing and past
        divideChallenges()
        
        let layout = generateLayout()
        challengeCV.collectionViewLayout = layout
        
        challengeCV.dataSource = self
        challengeCV.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataManagerUpdate), name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        refreshFromDataManager(resetSegment: true)
        
        NotificationCenter.default.addObserver(self, selector: #selector(refreshChallenges), name: NSNotification.Name("ChallengeAddedNotification"), object: nil)
        
        challengeCV.contentInsetAdjustmentBehavior = .never
        setupRefreshControl()
        setupFilterButton()
        setupTrophyButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkAndPresentPendingFamilyRewards()
    }
    
    private func checkAndPresentPendingFamilyRewards() {
        guard let currentUser = DataManager.shared.currentUser else { return }
        
        let allChallenges = DataManager.shared.challenges
        let progressRecords = DataManager.shared.challengeProgress
        let existingRewards = RewardsManager.shared.rewards
        
        for challenge in allChallenges {
            let records = progressRecords.filter { $0.challengeId == challenge.challengeId }
            let isFamilyChallenge = records.count > 1
            if !isFamilyChallenge { continue }
            
            // User must be part of the challenge to care
            let currentUserParticipated = records.contains { $0.memberId == currentUser.profileId }
            if !currentUserParticipated { continue }
            
            // Check if this family reward is already shown and saved
            if existingRewards.contains(where: { $0.challengeId == challenge.challengeId.uuidString && $0.type == .family }) {
                continue
            }
            
            var allComplete = true
            for record in records {
                if record.goalValue > 0 && record.currentValue < record.goalValue {
                    allComplete = false
                    break
                }
            }
            
            if allComplete {
                let overlay = RewardsViewController(
                    achievementType: .family,
                    challengeId: challenge.challengeId.uuidString,
                    challengeTitle: challenge.name,
                    challengeType: challenge.type,
                    participantsCount: records.count
                )
                self.present(overlay, animated: true)
                break // Only show one at a time so they don't stack awkwardly
            }
        }
    }
    
    private func setupFilterButton() {
        view.addSubview(filterButton)
        NSLayoutConstraint.activate([
            filterButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            filterButton.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 8),
            filterButton.widthAnchor.constraint(equalToConstant: 32),
            filterButton.heightAnchor.constraint(equalToConstant: 32)
        ])
        setupFilterMenu()
    }
    
    private func setupFilterMenu() {
        let recentlyAction = UIAction(title: "Recently Completed", state: currentPastFilter == .recentlyCompleted ? .on : .off) { [weak self] _ in
            self?.currentPastFilter = .recentlyCompleted
            self?.setupFilterMenu()
            self?.divideChallenges()
        }
        
        let allCompletedAction = UIAction(title: "All Completed", state: currentPastFilter == .allCompleted ? .on : .off) { [weak self] _ in
            self?.currentPastFilter = .allCompleted
            self?.setupFilterMenu()
            self?.divideChallenges()
        }
        
        let expiredAction = UIAction(title: "Expired / Not Completed", state: currentPastFilter == .expired ? .on : .off) { [weak self] _ in
            self?.currentPastFilter = .expired
            self?.setupFilterMenu()
            self?.divideChallenges()
        }
        
        var children: [UIMenuElement] = [recentlyAction, allCompletedAction, expiredAction]
        
        let clearAction = UIAction(title: "Clear Filter", attributes: .destructive) { [weak self] _ in
            self?.currentPastFilter = nil
            self?.setupFilterMenu()
            self?.divideChallenges()
        }
        children.append(clearAction)
        
        let menu = UIMenu(title: "Filter Past Challenges", options: .displayInline, children: children)
        filterButton.menu = menu
    }
    
    private func setupTrophyButton() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        container.backgroundColor = .systemGray6
        container.layer.cornerRadius = 20
        container.clipsToBounds = true
        
        let imageView = UIImageView(image: UIImage(named: "trophy_button_image"))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 34),
            imageView.heightAnchor.constraint(equalToConstant: 34)
        ])
        
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        button.addTarget(self, action: #selector(trophyTapped), for: .touchUpInside)
        
        let trophyBarButtonItem = UIBarButtonItem(customView: container)
        
        if let existingItems = navigationItem.rightBarButtonItems, !existingItems.isEmpty {
            var items = existingItems
            items.append(trophyBarButtonItem)
            navigationItem.rightBarButtonItems = items
        } else if let existingItem = navigationItem.rightBarButtonItem {
            navigationItem.rightBarButtonItems = [existingItem, trophyBarButtonItem]
        } else {
            navigationItem.rightBarButtonItem = trophyBarButtonItem
        }
    }
    
    @objc private func trophyTapped() {
        let rewardsVC = RewardsCollectionViewController()
        navigationController?.pushViewController(rewardsVC, animated: true)
    }
    
    
    private func setupRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        challengeCV.refreshControl = refreshControl
    }
    
    @objc private func handleRefresh() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        Task {
            await SyncManager.shared.syncAll(force: true)
            DispatchQueue.main.async { [weak self] in
                self?.refreshFromDataManager(resetSegment: false)
                self?.challengeCV.refreshControl?.endRefreshing()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure cells start below the segment control
        let topPadding: CGFloat = filterButton.isHidden ? 10 : 45
        let topInset = segmentControl.frame.maxY + topPadding
        challengeCV.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: 20, right: 0)
        challengeCV.scrollIndicatorInsets = UIEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - My code
    
    @objc func refreshChallenges() {
        refreshFromDataManager(resetSegment: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshFromDataManager(resetSegment: true)
    }

    @objc private func handleDataManagerUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshFromDataManager(resetSegment: false)
        }
    }

    private func refreshFromDataManager(resetSegment: Bool) {
        let dataManager = DataManager.shared
        challenges = dataManager.challenges

        var members = dataManager.allProfiles
        if let currentUser = dataManager.currentUser,
           !members.contains(where: { $0.profileId == currentUser.profileId }) {
            members.append(currentUser)
        }
        familyMembers = members

        if resetSegment {
            segmentControl.selectedSegmentIndex = 0
        }
        divideChallenges()
    }
    
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        print("segment called/changed")
        divideChallenges()
    }
    
    func divideChallenges() {
        // Auto-expire challenges whose date has passed
        var currentChallenges = DataManager.shared.challenges
        var didUpdate = false
        let now = Date()
        
        let allProgress = DataManager.shared.challengeProgress
        
        for i in 0..<currentChallenges.count {
            if currentChallenges[i].status == "ongoing" {
                // Check if ALL members have hit their goal
                let relatedProgress = allProgress.filter { $0.challengeId == currentChallenges[i].challengeId }
                let isGoalMet = !relatedProgress.isEmpty && relatedProgress.allSatisfy { $0.currentValue >= $0.goalValue && $0.goalValue > 0 }
                
                if isGoalMet {
                    currentChallenges[i].status = "completed"
                    DataManager.shared.updateChallenge(currentChallenges[i])
                    didUpdate = true
                }
                // Else check if time expired
                else if currentChallenges[i].endDate.timeIntervalSince(now) <= 0 {
                    currentChallenges[i].status = "past"
                    DataManager.shared.updateChallenge(currentChallenges[i])
                    didUpdate = true
                }
            }
        }
        
        if didUpdate {
            self.challenges = DataManager.shared.challenges
        }
        
        guard let challenges else { return }
        //divide code by 'status'
        if segmentControl.selectedSegmentIndex == 0 {
            //ongoing
            filterButton.isHidden = true
            filteredChallenges = challenges.filter { $0.status == "ongoing" }
        } else {
            //past and completed
            filterButton.isHidden = false
            let pastChallenges = challenges.filter { $0.status == "past" || $0.status == "completed" }
            
            if let filter = currentPastFilter {
                switch filter {
                case .recentlyCompleted:
                    let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                    filteredChallenges = pastChallenges.filter { $0.status == "completed" && $0.lastUpdatedAt >= oneWeekAgo }
                case .allCompleted:
                    filteredChallenges = pastChallenges.filter { $0.status == "completed" }
                case .expired:
                    filteredChallenges = pastChallenges.filter { $0.status == "past" }
                }
            } else {
                filteredChallenges = pastChallenges
            }
        }
        
        view.setNeedsLayout()
        challengeCV.reloadData()
    }
    
    func generateLayout() -> UICollectionViewLayout {
        //first thing is to create the size of the item
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
        //create the item and give the size
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
//        item.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 10)
        
        //creating group size and group
        let grpSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(150))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: grpSize, repeatingSubitem: item, count: 1)
        //adding spacing between item, since we are having multiple items
//        group.interItemSpacing = .fixed(10)
        
        
        
        //creating section
        let section = NSCollectionLayoutSection(group: group)
//        creating space between sections and groups
        section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        //creating space between cards
        section.interGroupSpacing = 10
        
        
        //creating layout
        let layout = UICollectionViewCompositionalLayout(section: section)
        
        return layout
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "open_challenge_details" {
            guard let destinationVC = segue.destination as? ViewChallengeViewController,
                  let indexPath = challengeCV.indexPathsForSelectedItems?.first else {
                return
            }
            
            let challenge = filteredChallenges[indexPath.row]
            destinationVC.challenge = challenge
            destinationVC.familyMembers = familyMembers
            
        } else if segue.identifier == "task_detail_segue" {
            guard let destinationVC = segue.destination as? TaskDetailViewController,
                  let indexPath = challengeCV.indexPathsForSelectedItems?.first else {
                return
            }
            
            let challenge = filteredChallenges[indexPath.row]
            destinationVC.challenge = challenge
            destinationVC.familyMembers = familyMembers
            
        }
    }

}


extension ChallengeFirstViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if filteredChallenges.isEmpty {
            let message = segmentControl.selectedSegmentIndex == 0 ? "No active challenges. Tap + to start one!" : "No expired challenges found."
            collectionView.setEmptyMessage(message, iconName: "flag.slash")
        } else {
            collectionView.restore()
        }
        return filteredChallenges.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "challenge_cell", for: indexPath) as! NewChallengeCollectionViewCell
        
        let challenge = filteredChallenges[indexPath.row]
        let allProgress = DataManager.shared.challengeProgress
        cell.configureCell(challenge: challenge, allProgress: allProgress)
        
        cell.layer.cornerRadius = 12
        
        return cell
        
    }
}

extension ChallengeFirstViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedChallenge = filteredChallenges[indexPath.row]
        
        if selectedChallenge.type == "social" {
            performSegue(withIdentifier: "task_detail_segue", sender: nil)
        } else {
            performSegue(withIdentifier: "open_challenge_details", sender: nil)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let challenge = filteredChallenges[indexPath.row]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let deleteAction = UIAction(title: "Delete Challenge", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                let alert = UIAlertController(title: "Delete Challenge", message: "Are you sure you want to permanently delete this challenge for everyone?", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                    DataManager.shared.deleteChallenge(challenge)
                })
                self?.present(alert, animated: true)
            }
            return UIMenu(title: "", children: [deleteAction])
        }
    }
}
