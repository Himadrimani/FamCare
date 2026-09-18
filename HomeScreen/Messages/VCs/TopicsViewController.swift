import UIKit
import Combine

class TopicsViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    let viewModel = TopicsViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    var onTopicSelected: ((Topic) -> Void)?
    var onCreateNewTopic: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupBindings()
        viewModel.onAppear()
        setupProfileButton()
    }
    
    private func setupProfileButton() {
        setupUniversalNavItems(currentUser: DataManager.shared.currentUser, profileAction: #selector(profileTapped))
    }

    @objc private func profileTapped() {
        presentProfileScreen(currentUser: DataManager.shared.currentUser, family: DataManager.shared.family, allProfiles: DataManager.shared.allProfiles)
    }

    private func setupCollectionView() {
        // Layout properties can still be refined here or in Storyboard
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .vertical
            layout.minimumLineSpacing = 0
        }
        
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(UINib(nibName: "TopicListCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "TopicListCell")
        setupRefreshControl()
    }
    
    private func setupRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    @objc private func handleRefresh() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        Task {
            await SyncManager.shared.syncAll(force: true)
            DispatchQueue.main.async { [weak self] in
                self?.viewModel.onAppear() // Re-fetch
                self?.collectionView.refreshControl?.endRefreshing()
            }
        }
    }
    
    private func setupBindings() {
        viewModel.$topics
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)
            
        viewModel.$latestMessages
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)
        
        viewModel.$unreadCounts
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)
    }
}

extension TopicsViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if viewModel.topics.isEmpty {
            collectionView.setEmptyMessage("No group chats yet. Tap + to start talking with your family!", iconName: "person.3.sequence")
        } else {
            collectionView.restore()
        }
        return viewModel.topics.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TopicListCell", for: indexPath) as! TopicListCollectionViewCell
        let topic = viewModel.topics[indexPath.item]
        let latestMsg = viewModel.latestMessages[topic.id]
        let count = viewModel.unreadCount(for: topic.id)
        let members = viewModel.getMembers(for: topic.id)
        
        cell.configure(with: topic, latestMessage: latestMsg, unreadCount: count, members: members)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 100)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let topic = viewModel.topics[indexPath.item]
        viewModel.markTopicAsSeen(topicId: topic.id)
        onTopicSelected?(topic)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let topic = viewModel.topics[indexPath.item]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let deleteAction = UIAction(title: "Delete Group", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                // Alert confirmation
                let alert = UIAlertController(title: "Delete Group", message: "Are you sure you want to permanently delete this group chat for everyone?", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                    self?.viewModel.deleteTopic(topic)
                })
                self?.present(alert, animated: true)
            }
            return UIMenu(title: "", children: [deleteAction])
        }
    }
}
