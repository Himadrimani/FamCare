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
        let topPadding: CGFloat = 10
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
                // Check if anyone has hit the goal
                let relatedProgress = allProgress.filter { $0.challengeId == currentChallenges[i].challengeId }
                let isGoalMet = relatedProgress.contains { $0.currentValue >= $0.goalValue && $0.goalValue > 0 }
                
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
            filteredChallenges = challenges.filter { $0.status == "ongoing" }
        } else {
            //past and completed
            filteredChallenges = challenges.filter { $0.status == "past" || $0.status == "completed" }
        }
        
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
