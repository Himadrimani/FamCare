//mock_data.json
//      ↓
//DataManager loads JSON
//      ↓
//SceneDelegate calls DataManager
//      ↓
//SceneDelegate sends data into HomeViewController
//      ↓
//HomeViewController uses data
import UIKit
import DGCharts

class HomeViewController: UIViewController {
    // SceneDelegate loads JSON via DataManager and passes data into this controller
    private var selectedMember: Profile?
    var currentUser: Profile?
    var family: Family?
    var otherProfiles: [Profile] = []
    var messages: [Message] = []
    private var ongoingChallenges: [ChallengeDetails] = []
    
    //home collection view
    @IBOutlet weak var homeCollectionView: UICollectionView!

    //calendar variables
    private var dates: [Date] = []
    private var selectedDate = Date()
    private let calendar = Calendar.current
    private var didScrollToToday = false

    //dervied variables
    private var wellnessCards: [WellnessCard] = []
    private var familyMembers: [Profile] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        generateDates()
        setupRefreshControl()
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataManagerUpdate), name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        refreshFromDataManager()
        
        setupOfflineBannerObserver()
        
        // --- Notification Setup ---
        NotificationManager.shared.checkRulesAndGenerateNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(updateNotificationBadge), name: NSNotification.Name("NewNotificationAdded"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateTabBarBadge), name: NSNotification.Name("TotalUnreadMessagesChanged"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(refreshChallenges), name: NSNotification.Name("ChallengeAddedNotification"), object: nil)
    }

    private func setupRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        homeCollectionView.refreshControl = refreshControl
    }
    
    @objc private func handleRefresh() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        Task {
            await SyncManager.shared.syncAll(force: true)
            DispatchQueue.main.async { [weak self] in
                self?.refreshFromDataManager()
                self?.homeCollectionView.refreshControl?.endRefreshing()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshFromDataManager()
        updateNotificationBadgeUI()
    }

    @objc private func handleDataManagerUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshFromDataManager()
        }
    }

    private func refreshFromDataManager() {
        let dataManager = DataManager.shared
        dataManager.ensureDirectMessagesLoaded()

        currentUser = dataManager.currentUser
        family = dataManager.family
        otherProfiles = dataManager.allProfiles
        messages = dataManager.messages

        let visibleProfiles = ([currentUser].compactMap { $0 } + otherProfiles)
        for profile in visibleProfiles {
            dataManager.ensureHealthDataLoaded(for: profile.profileId)
        }

        buildFamilyMembers()
        loadWellnessData(for: selectedDate)
        refreshChallenges()
        setupProfileButton()
        homeCollectionView.reloadData()
    }
    
    @objc func refreshChallenges() {
        self.ongoingChallenges = DataManager.shared.challenges.filter { $0.status == "ongoing" }
        DispatchQueue.main.async { [weak self] in
            if self?.homeCollectionView.numberOfSections ?? 0 > 2 {
                self?.homeCollectionView.reloadSections(IndexSet(integer: 2))
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !didScrollToToday {
            scrollToToday()
            didScrollToToday = true
        }
        
        // Use the navigation bar's maxY and add extra padding to account for the large title height
        let topPadding: CGFloat = 65
        let navBarMaxY = navigationController?.navigationBar.frame.maxY ?? view.safeAreaInsets.top
        let topInset = navBarMaxY + topPadding
        let bottomInset = view.safeAreaInsets.bottom + 20
        
        homeCollectionView.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: bottomInset, right: 0)
        homeCollectionView.scrollIndicatorInsets = UIEdgeInsets(top: topInset, left: 0, bottom: bottomInset, right: 0)
    }
    
    private func setupProfileButton() {
        setupUniversalNavItems(currentUser: currentUser, profileAction: #selector(profileTapped))
    }

    @objc private func profileTapped() {
        presentProfileScreen(currentUser: currentUser, family: family, allProfiles: otherProfiles)
    }

    @objc private func updateNotificationBadge() {
        updateNotificationBadgeUI()
    }

    @objc private func updateTabBarBadge(notification: NSNotification) {
        if let count = notification.userInfo?["count"] as? Int {
            DispatchQueue.main.async { [weak self] in
                // Messages tab is at index 3 (Home=0, Insights=1, Challenges=2, Messages=3)
                if let tabBarItem = self?.tabBarController?.tabBar.items?[3] {
                    tabBarItem.badgeValue = count > 0 ? "\(count)" : nil
                }
            }
        }
    }
  
    //Data Builder
    private func buildFamilyMembers() {
        guard let currentUser else {
            familyMembers = []
            return
        }
        familyMembers = Array([currentUser] + otherProfiles).prefix(4).map { $0 }
    }

    private func loadWellnessData(for date: Date) {
        guard let currentUser else {
            wellnessCards = []
            return
        }
        wellnessCards = WellnessDataProvider.getWellnessCards(for: currentUser, date: date)
    }

    //CollectionView Setup
    private func setupCollectionView() {
        let nibs: [String: String] = [ // Dictionary mapping nib file names to their reuse identifiers
            "CalendarCollectionViewCell": "calendar_cell", 
            "FamilyActivityScoreCollectionViewCell": "family_cell",
            "NewChallengeCollectionViewCell": "challenge_cell",
            "WellnessCardCell": "wellness_cell",
        ]

        nibs.forEach { name, id in // Loop through each nib mapping
            homeCollectionView.register(UINib(nibName: name, bundle: nil), // Register nib file
                                        forCellWithReuseIdentifier: id) // Associate it with reuse identifier
        }
        

        homeCollectionView.register(
            UINib(nibName: "SectionHeaderView", bundle: nil),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "header_view"
        )
        homeCollectionView.register(
            PageControlFooterView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: "page_control_footer"
        )

        homeCollectionView.delegate = self // Set delegate to handle user interactions
        homeCollectionView.dataSource = self // Set data source to provide data for collection view
        homeCollectionView.setCollectionViewLayout(generateLayout(), animated: false)
        homeCollectionView.contentInsetAdjustmentBehavior = .never
    }

    private func generateLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { section, _ in
            switch section { // Decide layout based on section index
            case 0: return self.createCalendarSection() 
            case 1: return self.createFamilyScoreSection() 
            case 2: return self.createChallengesSection() 
            case 3: return self.createWellnessSection() 
            default: return self.createCalendarSection() 
            }
        }
    }


    private func createCalendarSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: .init(
                widthDimension: .fractionalWidth(1.0 / 7.0), // Each item takes 1/7th of width (7 days in a week)
                heightDimension: .absolute(80) // Fixed height for each item
            )
        )

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(80)),
            subitems: Array(repeating: item, count: 7)
        )

        let section = NSCollectionLayoutSection(group: group) // Create section using the group
        section.orthogonalScrollingBehavior = .groupPagingCentered // Enable horizontal scrolling with centered paging
        section.contentInsets = .init(top: 10, leading: 16, bottom: 20, trailing: 16) // Add padding around section
        section.interGroupSpacing = 0
        return section // Return configured section
    }
    

    private func createFamilyScoreSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                              heightDimension: .fractionalHeight(1.0))
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(350)),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 0, leading: 16, bottom: 20, trailing: 16)
        section.boundarySupplementaryItems = [createHeader()]
        return section
    }

    private func createChallengesSection() -> NSCollectionLayoutSection {
        // If there are no challenges, set the height to 0 to hide the section
        let sectionHeight: NSCollectionLayoutDimension = ongoingChallenges.isEmpty ? .absolute(1) : .estimated(150)
        
        let item = NSCollectionLayoutItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                              heightDimension: .fractionalHeight(1.0))
        )
        // Move horizontal insets to the item so the group can span 100% of the orthogonal scroll view
        item.contentInsets = .init(top: 0, leading: 16, bottom: 0, trailing: 16)
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(1.0), heightDimension: sectionHeight),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPaging
        section.contentInsets = .init(top: 0, leading: 0, bottom: ongoingChallenges.isEmpty ? 0 : 20, trailing: 0)
        section.interGroupSpacing = 0
        
        // Hide header if no challenges
        let headerHeight: NSCollectionLayoutDimension = ongoingChallenges.isEmpty ? .absolute(1) : .absolute(50)
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1.0), heightDimension: headerHeight),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        header.contentInsets = .init(top: 0, leading: 16, bottom: 0, trailing: 16)
        section.boundarySupplementaryItems = [header]
        
        if ongoingChallenges.count > 1 {
            let footer = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: .init(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(30)),
                elementKind: UICollectionView.elementKindSectionFooter,
                alignment: .bottom
            )
            footer.contentInsets = .init(top: 0, leading: 16, bottom: 0, trailing: 16)
            section.boundarySupplementaryItems.append(footer)
            
            section.visibleItemsInvalidationHandler = { [weak self] visibleItems, scrollOffset, environment in
                let containerWidth = environment.container.contentSize.width
                guard containerWidth > 0 else { return }
                
                let page = Int(round(scrollOffset.x / containerWidth))
                DispatchQueue.main.async {
                    if let footer = self?.homeCollectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionFooter, at: IndexPath(item: 0, section: 2)) as? PageControlFooterView {
                        footer.pageControl.currentPage = page
                    }
                }
            }
        }
        
        return section
    }

    private func createWellnessSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .absolute(150)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = .init(top: 0, leading: 6, bottom: 0, trailing: 6)

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(150)),
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        section.contentInsets = .init(top: 0, leading: 16, bottom: 20, trailing: 16)
        section.boundarySupplementaryItems = [createHeader()]
        return section
    }

    private func createHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        .init(
            layoutSize: .init(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(50)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }

    //Calendar Dates - function creates a list of dates from 30 days ago up to the end of the current week. It then stores all those dates in the dates array to show in the calendar UI.
 
    private func generateDates() {
        let today = Date()
        // Find a date roughly 30 days ago
        guard let rawStartDate = calendar.date(byAdding: .day, value: -30, to: today)
        else { return }
        
        // Find the Sunday of that week to ensure the calendar starts on Sunday
        let startWeekday = calendar.component(.weekday, from: rawStartDate)
        let daysToSubtract = startWeekday - 1 // Sunday = 1
        guard let startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: rawStartDate)
        else { return }

        // End = Saturday of current week to ensure the calendar ends on Saturday
        let weekday = calendar.component(.weekday, from: today)
        let daysToSaturday = 7 - weekday
        guard let endDate = calendar.date(byAdding: .day, value: daysToSaturday, to: today)
        else { return }

        var tempDates: [Date] = []
        var current = startDate
        while current <= endDate {
            tempDates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        dates = tempDates
    }
    
//This function finds today’s date in the calendar list and scrolls the collection view to it.
    private func scrollToToday() {
        guard let todayIndex = dates.firstIndex(where: calendar.isDateInToday) else { return } // Find index of today's date in array
        let indexPath = IndexPath(item: todayIndex, section: 0)
        DispatchQueue.main.async { [weak self] in 
            self?.homeCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false) // Scroll collection view to today's date
            self?.selectedDate = self?.dates[todayIndex] ?? Date() // Set selected date to today
            self?.homeCollectionView.reloadItems(at: [indexPath]) // Reload the specific item to update UI
        }
    }
    

    private func wellnessCell(
        for card: WellnessCard,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = homeCollectionView.dequeueReusableCell(
            withReuseIdentifier: "wellness_cell",
            for: indexPath
        ) as! WellnessCardCell
        cell.configure(with: card)
        return cell
    }

}

//UICollectionViewDataSource
extension HomeViewController: UICollectionViewDataSource {
    
    // Handles navigation between screens and passes required data to destination view controllers
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "home_to_profile_" {
            // Destination is a navigation controller, get its top view controller
            if let navVC = segue.destination as? UINavigationController,
               let destinationVC = navVC.topViewController as? ProfileMainTableViewController {
                destinationVC.currentUser = currentUser // Pass current user data
                destinationVC.family = family // Pass family data
                destinationVC.familyMembers = familyMembers // Pass family members list
            }
        }
        if segue.identifier == "home_to_member_wellness" {
            if let nav = segue.destination as? UINavigationController,
               let destination = nav.topViewController as? MemberWellnessViewController,
               let profile = sender as? Profile {

                destination.profile = profile
                destination.selectedDate = selectedDate // pass selected date
            }
        }
    }
    
    // Returns total number of sections in collection view (Calendar, Family Score, Challenges, Wellness)
    func numberOfSections(in collectionView: UICollectionView) -> Int { 4 }

    // Returns number of items in each section based on section type
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0: return dates.count 
        case 2: return ongoingChallenges.count
        case 3: return wellnessCards.count 
        default: return 1 
        }
    }

    // Configures and returns appropriate cell for each section and index
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch indexPath.section {
        case 0:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "calendar_cell", for: indexPath) as! CalendarCollectionViewCell
            let date = dates[indexPath.item]
            cell.configure(with: date, isSelected: calendar.isDate(date, inSameDayAs: selectedDate), isToday: calendar.isDateInToday(date))
            return cell

        case 1:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "family_cell", for: indexPath) as! FamilyActivityScoreCollectionViewCell
            cell.configure(members: familyMembers, for: selectedDate)
            cell.delegate = self
            return cell

        case 2:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "challenge_cell", for: indexPath) as! NewChallengeCollectionViewCell
            let challenge = ongoingChallenges[indexPath.item]
            cell.configureCell(challenge: challenge, allProgress: DataManager.shared.challengeProgress)
            cell.layer.cornerRadius = 12
            return cell

        case 3:
            return wellnessCell(for: wellnessCards[indexPath.item], indexPath: indexPath)

        default:
        
            return UICollectionViewCell() // Return empty cell for safety
        }
    }

    // Provides header view for each section and configures title and edit button visibility
    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        
        if kind == UICollectionView.elementKindSectionFooter {
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "page_control_footer", for: indexPath) as! PageControlFooterView
            footer.pageControl.numberOfPages = ongoingChallenges.count
            return footer
        }
        
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header_view", for: indexPath) as! SectionHeaderView // Dequeue header view
        let titles = ["", "Family Wellness", "Challenge of the day", "My Wellness"]
        
        // If it's the challenge section and there are no challenges, show an empty title
        let title = (indexPath.section == 2 && ongoingChallenges.isEmpty) ? "" : titles[indexPath.section]
        
        let showEdit = (indexPath.section == 3)
        header.configure(withTitle: title, showEditButton: showEdit)
        header.delegate = self
        
        return header
    }
}

//UICollectionViewDelegate
extension HomeViewController: UICollectionViewDelegate {
    // Handles user interaction when a collection view item is selected
    //block future dates from updating rings
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let tappedDate = dates[indexPath.item]
            let todayStart = calendar.startOfDay(for: Date())

            // Do not allow selecting future dates beyond today
            guard calendar.startOfDay(for: tappedDate) <= todayStart else { return }

            let previousDate = selectedDate
            selectedDate = tappedDate

            var reload = [indexPath]
            if let prev = dates.firstIndex(where: { calendar.isDate($0, inSameDayAs: previousDate) }) {
                reload.append(IndexPath(item: prev, section: 0))
            }
            collectionView.reloadItems(at: reload)
            loadWellnessData(for: selectedDate)

            collectionView.reloadSections(IndexSet([1, 3]))// reload wellness rings and wellness cards for selected date

        } else if indexPath.section == 2 {
            // Challenge section (Section 2)
            let selectedChallenge = ongoingChallenges[indexPath.item]

            let storyboard = UIStoryboard(name: "Challenges", bundle: nil)
            if selectedChallenge.type == "social" {
                if let destinationVC = storyboard.instantiateViewController(withIdentifier: "TaskDetailViewController") as? TaskDetailViewController {
                    destinationVC.challenge = selectedChallenge
                    destinationVC.familyMembers = otherProfiles
                    self.navigationController?.pushViewController(destinationVC, animated: true)
                }
            } else {
                if let destinationVC = storyboard.instantiateViewController(withIdentifier: "ViewChallengeViewController") as? ViewChallengeViewController {
                    destinationVC.challenge = selectedChallenge
                    destinationVC.familyMembers = otherProfiles
                    self.navigationController?.pushViewController(destinationVC, animated: true)
                }
            }
        } else if indexPath.section == 3 {
            // My Wellness section (Section 3)
            let card = wellnessCards[indexPath.item]
            let type: InsightType
            
            switch card.type {
            case .steps:     type = .steps
            case .sleep:     type = .sleep
            case .calories:  type = .calories
            case .distance:  type = .distance
            case .heartRate: type = .heartRate
            case .hrv:       type = .hrv
            }
            
            let detailVC = InsightDetailViewController()
            detailVC.insightType = type
            detailVC.profile = currentUser
            detailVC.modalPresentationStyle = .pageSheet
            self.present(detailVC, animated: true)
        }
    }
}

//SectionHeaderViewDelegate
extension HomeViewController: SectionHeaderViewDelegate {
    func sectionHeaderDidTapEdit(_ header: SectionHeaderView) {
        let editVC = EditWellnessViewController()
        editVC.profile = currentUser
        editVC.delegate = self
        editVC.modalPresentationStyle = .pageSheet
        self.present(editVC, animated: true)
    }
}

//EditWellnessViewControllerDelegate
extension HomeViewController: EditWellnessViewControllerDelegate {
    func editWellnessViewControllerDidUpdate(_ controller: EditWellnessViewController, visibleMetricIds: [String]) {
        currentUser?.visibleMetricIds = visibleMetricIds
        loadWellnessData(for: selectedDate)
        homeCollectionView.reloadSections(IndexSet(integer: 3))
    }
}

//FamilyMemberTapDelegate
extension HomeViewController: FamilyMemberTapDelegate {
    func didTapMember(_ profile: Profile) {
        if profile.profileId == currentUser?.profileId {
            // Scroll to "My Wellness" (Section 3) instead of opening modal
            let indexPath = IndexPath(item: 0, section: 3)
            homeCollectionView.scrollToItem(at: indexPath, at: .top, animated: true)
        } else {
            performSegue(withIdentifier: "home_to_member_wellness", sender: profile)
        }
    }
}

// MARK: - Notification UI Components

class NotificationTableViewController: UITableViewController {
    
    var notifications: [NotificationItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadNotifications()
        NotificationManager.shared.markAllAsRead()
        
        NotificationCenter.default.addObserver(self, selector: #selector(loadNotifications), name: NSNotification.Name("NewNotificationAdded"), object: nil)
    }
    
    private func setupUI() {
        title = "Notifications"
        tableView.register(NotificationCell.self, forCellReuseIdentifier: "NotificationCell")
        tableView.separatorStyle = .singleLine
        tableView.tableFooterView = UIView()
        
        let closeImage = UIImage(systemName: "xmark.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .bold))
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: closeImage, style: .plain, target: self, action: #selector(closeTapped))
        navigationItem.leftBarButtonItem?.tintColor = .systemGray
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Clear All", style: .plain, target: self, action: #selector(clearAllTapped))
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func loadNotifications() {
        self.notifications = NotificationManager.shared.notifications
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    @objc private func clearAllTapped() {
        NotificationManager.shared.clearAll()
        loadNotifications()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if notifications.isEmpty {
            showEmptyState()
            return 0
        } else {
            tableView.backgroundView = nil
            return notifications.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationCell", for: indexPath) as! NotificationCell
        let notification = notifications[indexPath.row]
        cell.configure(with: notification)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    private func showEmptyState() {
        let emptyLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: self.view.bounds.size.height))
        emptyLabel.text = "No notifications yet."
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        tableView.backgroundView = emptyLabel
    }
}

class NotificationCell: UITableViewCell {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .tertiaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 18
        iv.backgroundColor = .systemGray6
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(bodyLabel)
        contentView.addSubview(timeLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.widthAnchor.constraint(equalToConstant: 36),
            iconImageView.heightAnchor.constraint(equalToConstant: 36),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            bodyLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            timeLabel.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 8),
            timeLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            timeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    func configure(with notification: NotificationItem) {
        titleLabel.text = notification.title
        bodyLabel.text = notification.body
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        timeLabel.text = formatter.localizedString(for: notification.timestamp, relativeTo: Date())
        
        // Use profile image if available
        if let pid = notification.relatedProfileId,
           let member = ([DataManager.shared.currentUser] + DataManager.shared.allProfiles).compactMap({$0}).first(where: { $0.profileId == pid }) {
            ImageManager.shared.setImage(for: iconImageView, from: member.profilePic)
        } else {
            iconImageView.image = UIImage(systemName: "bell.circle.fill")
            iconImageView.tintColor = .systemBlue
        }
    }
}

// MARK: - Universal Navigation Extension

extension UIViewController {
    
    func setupUniversalNavItems(currentUser: Profile?, profileAction: Selector, notificationAction: Selector? = nil) {
        guard let user = currentUser ?? DataManager.shared.currentUser else { return }

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Notification Bell Button
        let notificationButton = UIButton(type: .system)
        let bellImage = UIImage(systemName: "bell", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium))
        notificationButton.setImage(bellImage, for: .normal)
        notificationButton.tintColor = .label
        notificationButton.backgroundColor = .systemGray6
        notificationButton.layer.cornerRadius = 18
        notificationButton.translatesAutoresizingMaskIntoConstraints = false
        notificationButton.tag = 1001 // Tag for identifying the bell button
        notificationButton.addTarget(self, action: notificationAction ?? #selector(universalNotificationTapped), for: .touchUpInside)

        // Profile Button
        let profileButton = UIButton(type: .custom)
        profileButton.translatesAutoresizingMaskIntoConstraints = false
        ImageManager.shared.setButtonImage(for: profileButton, from: user.profilePic)
        profileButton.imageView?.contentMode = .scaleAspectFill
        profileButton.clipsToBounds = true
        profileButton.layer.cornerRadius = 18
        profileButton.addTarget(self, action: profileAction, for: .touchUpInside)

        stackView.addArrangedSubview(notificationButton)
        stackView.addArrangedSubview(profileButton)

        NSLayoutConstraint.activate([
            notificationButton.widthAnchor.constraint(equalToConstant: 36),
            notificationButton.heightAnchor.constraint(equalToConstant: 36),
            profileButton.widthAnchor.constraint(equalToConstant: 36),
            profileButton.heightAnchor.constraint(equalToConstant: 36)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: stackView)
        updateNotificationBadgeUI()
    }

    @objc func universalNotificationTapped() {
        NotificationManager.shared.checkRulesAndGenerateNotifications()
        NotificationManager.shared.markAllAsRead()
        let notificationVC = NotificationTableViewController()
        let navController = UINavigationController(rootViewController: notificationVC)
        present(navController, animated: true)
    }
    
    func presentProfileScreen(currentUser: Profile?, family: Family?, allProfiles: [Profile]) {
        let storyboard = UIStoryboard(name: "Profile", bundle: nil)
        if let nav = storyboard.instantiateInitialViewController() as? UINavigationController,
           let profileVC = nav.topViewController as? ProfileMainTableViewController {
            profileVC.currentUser = currentUser ?? DataManager.shared.currentUser
            profileVC.family = family ?? DataManager.shared.family
            profileVC.familyMembers = allProfiles + [(currentUser ?? DataManager.shared.currentUser)!]
            self.present(nav, animated: true)
        }
    }

    /// Updates the red badge count on the universal notification bell icon
    func updateNotificationBadgeUI() {
        guard let stackView = navigationItem.rightBarButtonItem?.customView as? UIStackView,
              let bellButton = stackView.arrangedSubviews.filter({ ($0 as? UIButton)?.tag == 1001 }).first as? UIButton else { return }
        
        let count = NotificationManager.shared.unreadCount
        
        // Remove existing badge if any
        bellButton.subviews.filter { $0.tag == 999 }.forEach { $0.removeFromSuperview() }
        
        if count > 0 {
            let badgeSize: CGFloat = 16
            let badgeLabel = UILabel()
            badgeLabel.tag = 999
            badgeLabel.text = count > 9 ? "9+" : "\(count)"
            badgeLabel.textColor = .white
            badgeLabel.textAlignment = .center
            badgeLabel.font = .systemFont(ofSize: 10, weight: .bold)
            badgeLabel.backgroundColor = .systemRed
            badgeLabel.layer.cornerRadius = badgeSize / 2
            badgeLabel.clipsToBounds = true
            badgeLabel.translatesAutoresizingMaskIntoConstraints = false
            
            bellButton.addSubview(badgeLabel)
            
            NSLayoutConstraint.activate([
                badgeLabel.topAnchor.constraint(equalTo: bellButton.topAnchor, constant: -2),
                badgeLabel.trailingAnchor.constraint(equalTo: bellButton.trailingAnchor, constant: 2),
                badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: badgeSize),
                badgeLabel.heightAnchor.constraint(equalToConstant: badgeSize)
            ])
        }
    }
}

class PageControlFooterView: UICollectionReusableView {
    let pageControl = UIPageControl()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        addSubview(pageControl)
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.currentPageIndicatorTintColor = .darkGray
        pageControl.pageIndicatorTintColor = .systemGray4
        pageControl.isUserInteractionEnabled = false
        
        NSLayoutConstraint.activate([
            pageControl.centerXAnchor.constraint(equalTo: centerXAnchor),
            pageControl.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
