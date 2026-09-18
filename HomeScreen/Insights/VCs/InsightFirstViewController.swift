//
//  ViewController 2.swift
//  Insight
//
//  Created by Mohd Kushaad on 12/02/26.
//
import UIKit
class InsightFirstViewController: UIViewController {
    // Now a var, populated dynamically from DataManager
    private var data: [(
        name: String,
        profile: Profile,
        scoreWeekly: [Int],
        scoreMonthly: [Int],
        colors: [UIColor]
    )] = []
    private var isWeek = true
    // True only when there are genuinely no health records yet (drives the empty state).
    private var showEmptyState = false
    @IBOutlet weak var graphCollectionView: UICollectionView!
    private let topInsightCellId = "top_insight_cell"
    private var topInsightTitleText = "Today's Insight"
    private var topInsightBodyText = "Loading..."
    private var topInsightButtonText = "Start Challenge"
    private var showTopChallengeButton = true
    override func viewDidLoad() {
        super.viewDidLoad()

        graphCollectionView.register(UINib(nibName: "GraphCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "graph_view_cell")
        graphCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: topInsightCellId)
        graphCollectionView.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "header_view")
        graphCollectionView.collectionViewLayout = generateLayout()
        graphCollectionView.dataSource = self
        graphCollectionView.delegate = self
        graphCollectionView.contentInsetAdjustmentBehavior = .never
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataManagerUpdate), name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        refreshFromDataManager()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Similar to HomeVC, use the navigation bar's maxY and add extra padding 
        // to account for the large title height AND the segment control below it.
        let topPadding: CGFloat = 75
        let navBarMaxY = navigationController?.navigationBar.frame.maxY ?? view.safeAreaInsets.top
        let topInset = navBarMaxY + topPadding
        
        let bottomInset = view.safeAreaInsets.bottom + 20
        graphCollectionView.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: bottomInset, right: 0)
        graphCollectionView.scrollIndicatorInsets = UIEdgeInsets(top: topInset, left: 0, bottom: bottomInset, right: 0)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleDataManagerUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshFromDataManager()
        }
    }

    private func refreshFromDataManager() {
        let profiles = ([DataManager.shared.currentUser].compactMap { $0 } + DataManager.shared.allProfiles)
        for profile in profiles {
            DataManager.shared.ensureHealthDataLoaded(for: profile.profileId)
        }

        buildData()

        // Real data-state check: show a clean empty state only when there are
        // genuinely no health records for anyone yet. No fake data, no timers —
        // as soon as real rows sync in, insights render again automatically.
        let hasHealthData = !DataManager.shared.allActivityDaily.isEmpty
            || !DataManager.shared.allSleepDaily.isEmpty
            || !DataManager.shared.allVitalsDaily.isEmpty
        showEmptyState = !hasHealthData

        if showEmptyState {
            // Distinguish "Health unavailable", "not connected yet", and "connected but no
            // data yet" so the empty screen is actually actionable (#5). iOS cannot report a
            // read-permission DENIAL, so "requested" collapses into the generic no-data copy.
            HealthKitService.shared.readAccessState { [weak self] state in
                DispatchQueue.main.async {
                    guard let self = self, self.showEmptyState else { return }
                    let message: String
                    let icon: String
                    switch state {
                    case .unavailable:
                        message = "Health data isn't available on this device, so insights can't be generated yet."
                        icon = "heart.slash"
                    case .notRequested:
                        message = "Connect Apple Health to start seeing your family wellness insights."
                        icon = "heart.text.square"
                    case .requested:
                        message = "Your insights will appear here once your health data starts syncing."
                        icon = "chart.line.uptrend.xyaxis"
                    }
                    self.graphCollectionView.setEmptyMessage(message, iconName: icon)
                }
            }
        } else {
            graphCollectionView.restore()
        }

        graphCollectionView.reloadData()

        if !showEmptyState {
            loadTopInsight()
        }
    }

    // Build data dynamically from DataManager
    private func buildData() {
        // Combine currentUser + all other family members
        var profiles: [Profile] = []
        if let currentUser = DataManager.shared.currentUser {
            profiles.append(currentUser)
        }
        profiles.append(contentsOf: DataManager.shared.allProfiles)

        data = profiles.map { profile in
            let scores = FamilyMemberScores.from(profile: profile)
            let isCurrentUser = profile.profileId == DataManager.shared.currentUser?.profileId
            
            let nameToUse = DataManager.shared.getDisplayName(for: profile)
            
            let displayName = isCurrentUser ? "My Performance" : "\(nameToUse)'s Performance"
            return (
                name: displayName,
                profile: profile,
                scoreWeekly: scores.scoreWeekly,
                scoreMonthly: scores.scoreMonthly,
                colors: [.systemOrange, .systemYellow, .systemGreen, .systemGreen, .systemGray, .systemGray, .systemGray]
            )
        }
    }

    private func loadTopInsight() {
        // The top insight card is section 0, which only exists when we are NOT in the empty
        // state. Don't compute/reload it otherwise — reloading a non-existent section crashes.
        guard !showEmptyState else { return }

        let completion: (AIInsight?) -> Void = { [weak self] insight in
            guard let self = self else { return }
            if let insight = insight {
                topInsightTitleText = insight.title
                topInsightBodyText = insight.message
                topInsightButtonText = "Start Challenge"
                showTopChallengeButton = insight.showChallengeButton
            } else {
                topInsightTitleText = isWeek ? "Weekly Insight" : "Monthly Insight"
                topInsightBodyText = "You're all doing great! Keep staying active with your family."
                topInsightButtonText = "Start Challenge"
                showTopChallengeButton = false
            }
            // Reload the top section only if it still exists. The state can change between
            // starting this insight and its completion (e.g. a data refresh emptied the list),
            // so guard against "reload section 0 with 0 sections" crashes.
            guard !self.showEmptyState, self.graphCollectionView.numberOfSections > 0 else {
                self.graphCollectionView.reloadData()
                return
            }
            self.graphCollectionView.reloadSections(IndexSet(integer: 0))
        }
        
        if isWeek {
            InsightEngine.shared.generateWeeklyTopInsight(completed: completion)
        } else {
            InsightEngine.shared.generateMonthlyTopInsight(completed: completion)
        }
    }

    private func challengeSuggestion(for profile: Profile) -> (message: String, buttonTitle: String) {
        let insight = InsightEngine.shared.generateInsight(for: profile, isSelf: profile.profileId == DataManager.shared.currentUser?.profileId)
        return (insight.message + " " + insight.suggestion, "Start Challenge")
    }

    @objc private func openChallengesTab() {
        tabBarController?.selectedIndex = 2
        
        if let navVC = tabBarController?.viewControllers?[2] as? UINavigationController,
           let _ = navVC.viewControllers.first as? ChallengeFirstViewController {
            
            navVC.popToRootViewController(animated: false)
            
            // Allow layout to settle before presenting to avoid transition conflicts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let _ = UIStoryboard(name: "Challenges", bundle: nil)
//                if let addNav = storyboard.instantiateViewController(withIdentifier: "AddChallengeNavController") as? UINavigationController
//                   let destVC = addNav.topViewController as? AddChallengeDynamicTableViewController {
//                    
//                    destVC.defaultChallenges = challengeVC.defaultChallenges ?? []
//                    challengeVC.present(addNav, animated: true)
//                }
            }
        }
    }

    // Pulls dynamic comparison from shared rule-based InsightEngine.
    private func comparisonText(for profile: Profile, isWeek: Bool) -> String {
        return InsightEngine.shared.comparisonText(for: profile, isWeek: isWeek)
    }

    func generateLayout() -> UICollectionViewCompositionalLayout {
        return UICollectionViewCompositionalLayout { (sectionIndex, _) -> NSCollectionLayoutSection? in

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalHeight(1.0)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            if sectionIndex == 0 {
                // ── Insight card with self-sizing height ──
                let topItemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(100)
                )
                let topItem = NSCollectionLayoutItem(layoutSize: topItemSize)
                
                let topGroupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(100)
                )
                let topGroup = NSCollectionLayoutGroup.vertical(layoutSize: topGroupSize, subitems: [topItem])
                let topSection = NSCollectionLayoutSection(group: topGroup)
                topSection.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 0, bottom: 12, trailing: 0)
                return topSection
            }

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(260)
            )
            let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)

            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(40))
            let headerItem = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            section.boundarySupplementaryItems = [headerItem]
            section.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 16, bottom: 20, trailing: 16)
            section.interGroupSpacing = 10

            return section
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "detailed_insight" {
            guard let destinationVC = segue.destination as? WellnessViewController else { return }
            
            if let indexPath = sender as? IndexPath {
                let selected = data[indexPath.section - 1]
                destinationVC.currentUser = selected.profile
                destinationVC.title = selected.name
            } else if let (indexPath, date) = sender as? (IndexPath, Date) {
                let selected = data[indexPath.section - 1]
                destinationVC.currentUser = selected.profile
                destinationVC.title = selected.name
                destinationVC.initialDate = date
            }
        }
    }

    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        isWeek = sender.selectedSegmentIndex == 0
        graphCollectionView.reloadData() // Update charts immediately
        loadTopInsight() // Load AI insight in background
    }

    @objc private func inlineSegmentChanged(_ sender: UISegmentedControl) {
        isWeek = sender.selectedSegmentIndex == 0
        graphCollectionView.reloadData() // Update charts immediately
        loadTopInsight() // Load AI insight in background
    }
}

// UICollectionViewDataSource
extension InsightFirstViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return showEmptyState ? 0 : data.count + 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: topInsightCellId, for: indexPath)
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            cell.backgroundColor = .clear

            // ── Insight card (Week or Month) ──────────
            let card = UIView()
            card.translatesAutoresizingMaskIntoConstraints = false
            card.backgroundColor = .systemBackground
            card.layer.cornerRadius = 20
            card.layer.borderWidth = 1.2
            card.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.08).cgColor
            card.layer.shadowColor = UIColor.systemBlue.cgColor
            card.layer.shadowOpacity = 0.08
            card.layer.shadowOffset = CGSize(width: 0, height: 6)
            card.layer.shadowRadius = 12
            
            // Subtle tinted background for 'premium' look
            let tintView = UIView()
            tintView.translatesAutoresizingMaskIntoConstraints = false
            tintView.backgroundColor = .systemBlue.withAlphaComponent(0.03)
            tintView.layer.cornerRadius = 20
            card.addSubview(tintView)
            
            cell.contentView.addSubview(card)

            let title = UILabel()
            title.text = topInsightTitleText
            title.font = .systemFont(ofSize: 17, weight: .bold)
            title.textColor = .label
            title.numberOfLines = 1

            let body = UILabel()
            body.text = topInsightBodyText
            body.font = .systemFont(ofSize: 14, weight: .semibold)
            body.textColor = .label.withAlphaComponent(0.7)
            body.numberOfLines = 0 // Allow multiline insight text
            body.lineBreakMode = .byWordWrapping

            var config = UIButton.Configuration.filled()
            config.title = topInsightButtonText
            config.baseBackgroundColor = .systemBlue
            config.baseForegroundColor = .white
            config.cornerStyle = .capsule
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            config.attributedTitle = AttributedString(topInsightButtonText, attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 13, weight: .bold)]))

            let button = UIButton(configuration: config, primaryAction: UIAction(handler: { [weak self] _ in
                self?.openChallengesTab()
            }))
            button.isHidden = !showTopChallengeButton

            // Wellness-not-medical-advice footer (#10).
            let disclaimer = UILabel()
            disclaimer.text = StandardInsightConfig.medicalDisclaimer
            disclaimer.font = .systemFont(ofSize: 11, weight: .regular)
            disclaimer.textColor = .tertiaryLabel
            disclaimer.numberOfLines = 0
            
            let stack = UIStackView(arrangedSubviews: [title, body, button, disclaimer])
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.axis = .vertical
            stack.alignment = .leading
            stack.spacing = 10
            card.addSubview(stack)

            NSLayoutConstraint.activate([
                card.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 6),
                card.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                card.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                card.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
                
                tintView.topAnchor.constraint(equalTo: card.topAnchor),
                tintView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                tintView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                tintView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
                
                stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
                stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
                stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
                stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
            ])

            return cell
        }

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "graph_view_cell", for: indexPath) as! GraphCollectionViewCell
        let memberData = data[indexPath.section - 1]
        let comp = comparisonText(for: memberData.profile, isWeek: isWeek)

        if isWeek {
            cell.configureCell(score: memberData.scoreWeekly, comparison: comp, isWeek: true)
        } else {
            cell.configureCell(score: memberData.scoreMonthly, comparison: comp, isWeek: false)
        }

        cell.layer.cornerRadius = 12
        cell.delegate = self
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header_view", for: indexPath)
            header.subviews.forEach { $0.removeFromSuperview() }
            if indexPath.section == 0 { return header }

            let label = UILabel()
            label.text = data[indexPath.section - 1].name
            label.font = .systemFont(ofSize: 25, weight: .semibold)
            label.textColor = .label
            label.frame = CGRect(x: 0, y: 0, width: header.frame.width, height: header.frame.height)
            header.addSubview(label)

            return header
        }
        return UICollectionReusableView()
    }
}

// UICollectionViewDelegate
extension InsightFirstViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section > 0 else { return }
        performSegue(withIdentifier: "detailed_insight", sender: indexPath)
    }

}

extension InsightFirstViewController: GraphCollectionViewCellDelegate {
    func graphCell(_ cell: GraphCollectionViewCell, didDoubleTapBarAt index: Int) {
        guard let indexPath = graphCollectionView.indexPath(for: cell) else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let targetDate: Date
        if isWeek {
            let weekday = calendar.component(.weekday, from: today)
            let daysFromSunday = weekday - 1
            guard let weekStart = calendar.date(byAdding: .day, value: -daysFromSunday, to: today) else { return }
            targetDate = calendar.date(byAdding: .day, value: index, to: weekStart) ?? today
        } else {
            // Month view shows current month starting from the 1st (index 0)
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else { return }
            targetDate = calendar.date(byAdding: .day, value: index, to: monthStart) ?? today
        }
        
        // Double check it's not a future date
        if targetDate > today { return }
        
        performSegue(withIdentifier: "detailed_insight", sender: (indexPath, targetDate))
    }
}
