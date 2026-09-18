import UIKit

class MemberWellnessViewController: UIViewController {

    var profile: Profile?
    var selectedDate: Date = Date()
    @IBOutlet weak var collectionView: UICollectionView!

    private var wellnessCards: [WellnessCard] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let profile else { return }
        view.backgroundColor = .systemGray6
        let isSelf = profile.profileId == DataManager.shared.currentUser?.profileId
        title = isSelf ? "My Wellness" : "\(profile.displayName)'s Wellness"
        setupNavigationBar()
        setupCollectionView()
        loadWellnessData()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataManagerUpdate), name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleDataManagerUpdate() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let profileId = self.profile?.profileId else { return }
            if profileId == DataManager.shared.currentUser?.profileId {
                self.profile = DataManager.shared.currentUser
            } else if let updated = DataManager.shared.allProfiles.first(where: { $0.profileId == profileId }) {
                self.profile = updated
            }
            let isSelf = self.profile?.profileId == DataManager.shared.currentUser?.profileId
            self.title = isSelf ? "My Wellness" : "\(self.profile?.displayName ?? "User")'s Wellness"
            self.loadWellnessData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadWellnessData() // refresh data
    }
    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Edit",
            style: .plain,
            target: self,
            action: #selector(editTapped)
        )
    }

    @objc private func editTapped() {
        let editVC = EditWellnessViewController()
        editVC.profile = profile
        editVC.delegate = self
        editVC.modalPresentationStyle = .pageSheet
        self.present(editVC, animated: true)
    }

    @IBAction func cancelTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }

    private func loadWellnessData() {
        guard let profile else { return }
        wellnessCards = WellnessDataProvider.getWellnessCards(for: profile, date: selectedDate)
        collectionView.reloadData()
    }

    private func setupCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self

        // Only register WellnessCardCell — insight cell removed
        collectionView.register(
            UINib(nibName: "WellnessCardCell", bundle: nil),
            forCellWithReuseIdentifier: "wellness_cell"
        )

        collectionView.setCollectionViewLayout(generateLayout(), animated: false)
    }

    private func generateLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .absolute(150)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = .init(top: 0, leading: 6, bottom: 0, trailing: 6)

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(150)
            ),
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        section.contentInsets = .init(top: 16, leading: 16, bottom: 20, trailing: 16)
        
        return UICollectionViewCompositionalLayout(section: section)
    }
}

extension MemberWellnessViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return wellnessCards.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // All cards use plain WellnessCardCell
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "wellness_cell",
            for: indexPath
        ) as! WellnessCardCell
        cell.configure(with: wellnessCards[indexPath.item])
        return cell
    }
}

extension MemberWellnessViewController: EditWellnessViewControllerDelegate {
    func editWellnessViewControllerDidUpdate(_ controller: EditWellnessViewController, visibleMetricIds: [String]) {
        profile?.visibleMetricIds = visibleMetricIds
        loadWellnessData()
        collectionView.reloadData()
    }
}
