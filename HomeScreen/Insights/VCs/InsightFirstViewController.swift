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
    private var animatedChartKeys: Set<String> = []
    override func viewDidLoad() {
        super.viewDidLoad()

        graphCollectionView.register(UINib(nibName: "GraphCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "graph_view_cell")
        graphCollectionView.register(TopInsightCardCell.self, forCellWithReuseIdentifier: topInsightCellId)
        graphCollectionView.register(InsightSectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "header_view")
        graphCollectionView.collectionViewLayout = generateLayout()
        graphCollectionView.dataSource = self
        graphCollectionView.delegate = self
        graphCollectionView.contentInsetAdjustmentBehavior = .never
        NotificationCenter.default.addObserver(self, selector: #selector(handleHealthDataUpdate), name: .HealthDataDidUpdate, object: nil)
        refreshFromDataManager()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Use the navigation bar's maxY and add padding to position the collection
        // view content below the segment control (32pt) with a visible gap.
        let topPadding: CGFloat = 80
        let navBarMaxY = navigationController?.navigationBar.frame.maxY ?? view.safeAreaInsets.top
        let topInset = navBarMaxY + topPadding
        
        let bottomInset = view.safeAreaInsets.bottom + 20
        graphCollectionView.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: bottomInset, right: 0)
        graphCollectionView.scrollIndicatorInsets = UIEdgeInsets(top: topInset, left: 0, bottom: bottomInset, right: 0)
    }

    private var refreshWorkItem: DispatchWorkItem?

    deinit {
        refreshWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleHealthDataUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.scheduleCoalescedRefresh()
        }
    }

    private func scheduleCoalescedRefresh() {
        refreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshFromDataManager()
        }
        refreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }

    private func refreshFromDataManager() {
        let profiles = ([DataManager.shared.currentUser].compactMap { $0 } + DataManager.shared.allProfiles)

        // Offload SQLite queries and score calculations entirely to background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for profile in profiles {
                DataManager.shared.ensureHealthDataLoaded(for: profile.profileId)
            }

            // Batch-prefetch all scores across all family members in 3 range queries
            let dates = FamilyMemberScores.relevantInsightDates()
            Profile.prefetchWellnessScores(for: profiles, dates: dates)

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.applyLoadedDataAndReloadUI()
            }
        }
    }

    private func applyLoadedDataAndReloadUI() {
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
        let storyboard = UIStoryboard(name: "Challenges", bundle: nil)
        if let addNav = storyboard.instantiateViewController(withIdentifier: "AddChallengeNavController") as? UINavigationController {
            self.present(addNav, animated: true)
        }
    }

    // Pulls dynamic comparison from shared rule-based InsightEngine.
    private func comparisonText(for profile: Profile, isWeek: Bool) -> String {
        return InsightEngine.shared.comparisonText(for: profile, isWeek: isWeek)
    }

    @objc private func toggleDisclaimer(_ sender: UITapGestureRecognizer) {
        guard let headerRow = sender.view else { return }
        // The headerRow is inside a disclaimerContainer stack view
        guard let container = headerRow.superview else { return }
        // Find the tagged views
        guard let disclaimerLabel = container.viewWithTag(8001),
              let chevronView = container.viewWithTag(8002) else { return }
        
        let willShow = disclaimerLabel.isHidden
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            disclaimerLabel.isHidden = !willShow
            disclaimerLabel.alpha = willShow ? 1 : 0
            chevronView.transform = willShow ? CGAffineTransform(rotationAngle: .pi) : .identity
        } completion: { [weak self] _ in
            self?.graphCollectionView.collectionViewLayout.invalidateLayout()
        }
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
                topSection.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0)
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
        animatedChartKeys.removeAll()
        graphCollectionView.reloadData() // Update charts immediately
        loadTopInsight() // Load AI insight in background
    }

    @objc private func inlineSegmentChanged(_ sender: UISegmentedControl) {
        isWeek = sender.selectedSegmentIndex == 0
        animatedChartKeys.removeAll()
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
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: topInsightCellId, for: indexPath) as! TopInsightCardCell
            cell.configure(
                title: topInsightTitleText,
                body: topInsightBodyText,
                buttonText: topInsightButtonText,
                showButton: showTopChallengeButton,
                buttonAction: { [weak self] in
                    self?.openChallengesTab()
                },
                toggleDisclaimerAction: { [weak self] in
                    self?.graphCollectionView.collectionViewLayout.invalidateLayout()
                }
            )
            return cell
        }

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "graph_view_cell", for: indexPath) as! GraphCollectionViewCell
        let memberData = data[indexPath.section - 1]
        let comp = comparisonText(for: memberData.profile, isWeek: isWeek)

        let chartKey = "\(memberData.profile.profileId.uuidString)-\(isWeek ? "W" : "M")"
        let shouldAnimate = !animatedChartKeys.contains(chartKey)
        if shouldAnimate {
            animatedChartKeys.insert(chartKey)
        }

        if isWeek {
            cell.configureCell(score: memberData.scoreWeekly, comparison: comp, isWeek: true, profileId: memberData.profile.profileId, animated: shouldAnimate)
        } else {
            cell.configureCell(score: memberData.scoreMonthly, comparison: comp, isWeek: false, profileId: memberData.profile.profileId, animated: shouldAnimate)
        }

        cell.layer.cornerRadius = 12
        cell.delegate = self
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header_view", for: indexPath) as! InsightSectionHeaderView
            if indexPath.section == 0 {
                header.titleLabel.text = ""
                return header
            }

            header.titleLabel.text = data[indexPath.section - 1].name
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
    
    func graphCellDidTapShare(_ cell: GraphCollectionViewCell) {
        guard let indexPath = graphCollectionView.indexPath(for: cell) else { return }
        let memberData = data[indexPath.section - 1]
        let name = memberData.profile.firstName
        
        let scores = isWeek ? memberData.scoreWeekly : memberData.scoreMonthly
        let todayDay = Calendar.current.component(.day, from: Date())
        let todayIndex = isWeek ? (Calendar.current.component(.weekday, from: Date()) - 1) : (todayDay - 1)
        let safeIndex = max(0, min(todayIndex, scores.count - 1))
        let score = scores.isEmpty ? 0 : scores[safeIndex]
        
        let title = "\(name)'s Insight"
        let comp = comparisonText(for: memberData.profile, isWeek: isWeek)
        let message = "[SHARE_CARD:INSIGHT|\(name)|\(score)%|\(isWeek ? "Weekly" : "Monthly")|\(comp)]"
        
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
}

// MARK: - InsightGradientCardView
private class InsightGradientCardView: UIView {
    let gradientLayer = CAGradientLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }
    
    private func setupGradient() {
        gradientLayer.locations = [0.0, 0.4, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    func updateColors(isAttention: Bool) {
        if isAttention {
            // Attention state: slightly deeper blue gradient with subtle warmth
            gradientLayer.colors = [
                UIColor.systemBlue.withAlphaComponent(0.12).cgColor,
                UIColor.systemBlue.withAlphaComponent(0.06).cgColor,
                UIColor.systemBackground.cgColor
            ]
        } else {
            // Positive state: serene light blue gradient
            gradientLayer.colors = [
                UIColor.systemBlue.withAlphaComponent(0.08).cgColor,
                UIColor(red: 0.85, green: 0.93, blue: 1.0, alpha: 1.0).cgColor,
                UIColor.systemBackground.cgColor
            ]
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = layer.cornerRadius
    }
}

// MARK: - Section Header View
final class InsightSectionHeaderView: UICollectionReusableView {
    let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        titleLabel.font = .systemFont(ofSize: 25, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

// MARK: - Top Insight Card Cell
final class TopInsightCardCell: UICollectionViewCell {
    private let card = InsightGradientCardView()
    private let titleLabel = UILabel()
    private let separator = UIView()
    private let bodyLabel = UILabel()
    private let button = UIButton()
    private let disclaimerContainer = UIStackView()
    private let headerRow = UIView()
    private let infoIcon = UIImageView()
    private let headerLabel = UILabel()
    private let chevronView = UIImageView()
    private let disclaimerLabel = UILabel()
    private let accentCircle = UIView()
    private let smallCircle = UIView()

    private var onButtonTapped: (() -> Void)?
    private var onToggleDisclaimer: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        layer.masksToBounds = false
        layer.shadowColor = UIColor.systemBlue.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 16

        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = 22
        card.layer.masksToBounds = true
        contentView.addSubview(card)

        accentCircle.translatesAutoresizingMaskIntoConstraints = false
        accentCircle.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.06)
        accentCircle.layer.cornerRadius = 50
        card.addSubview(accentCircle)

        smallCircle.translatesAutoresizingMaskIntoConstraints = false
        smallCircle.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.04)
        smallCircle.layer.cornerRadius = 30
        card.addSubview(smallCircle)

        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1

        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)

        bodyLabel.font = .systemFont(ofSize: 15, weight: .medium)
        bodyLabel.textColor = .label.withAlphaComponent(0.75)
        bodyLabel.numberOfLines = 0
        bodyLabel.lineBreakMode = .byWordWrapping

        var btnConfig = UIButton.Configuration.filled()
        btnConfig.baseBackgroundColor = .systemBlue
        btnConfig.baseForegroundColor = .white
        btnConfig.cornerStyle = .capsule
        btnConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
        btnConfig.attributedTitle = AttributedString("Start Challenge", attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 14, weight: .bold)]))
        button.configuration = btnConfig
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

        disclaimerContainer.axis = .vertical
        disclaimerContainer.alignment = .leading
        disclaimerContainer.spacing = 6

        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.isUserInteractionEnabled = true
        headerRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleDisclaimerTapped)))

        infoIcon.image = UIImage(systemName: "info.circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        infoIcon.tintColor = .tertiaryLabel
        infoIcon.translatesAutoresizingMaskIntoConstraints = false
        infoIcon.setContentHuggingPriority(.required, for: .horizontal)

        headerLabel.text = "About FamCare Insights"
        headerLabel.font = .systemFont(ofSize: 11, weight: .medium)
        headerLabel.textColor = .tertiaryLabel
        headerLabel.translatesAutoresizingMaskIntoConstraints = false

        chevronView.image = UIImage(systemName: "chevron.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: 9, weight: .semibold))
        chevronView.tintColor = .tertiaryLabel
        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.setContentHuggingPriority(.required, for: .horizontal)

        headerRow.addSubview(infoIcon)
        headerRow.addSubview(headerLabel)
        headerRow.addSubview(chevronView)

        disclaimerLabel.text = StandardInsightConfig.medicalDisclaimer
        disclaimerLabel.font = .systemFont(ofSize: 10.5, weight: .regular)
        disclaimerLabel.textColor = .tertiaryLabel
        disclaimerLabel.numberOfLines = 0
        disclaimerLabel.lineBreakMode = .byWordWrapping
        disclaimerLabel.isHidden = true
        disclaimerLabel.alpha = 0
        disclaimerLabel.tag = 8001
        chevronView.tag = 8002

        disclaimerContainer.addArrangedSubview(headerRow)
        disclaimerContainer.addArrangedSubview(disclaimerLabel)

        let stack = UIStackView(arrangedSubviews: [titleLabel, separator, bodyLabel, button, disclaimerContainer])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.setCustomSpacing(8, after: titleLabel)
        stack.setCustomSpacing(12, after: separator)
        stack.setCustomSpacing(14, after: bodyLabel)
        stack.setCustomSpacing(10, after: button)
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            accentCircle.widthAnchor.constraint(equalToConstant: 100),
            accentCircle.heightAnchor.constraint(equalToConstant: 100),
            accentCircle.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: 30),
            accentCircle.topAnchor.constraint(equalTo: card.topAnchor, constant: -30),

            smallCircle.widthAnchor.constraint(equalToConstant: 60),
            smallCircle.heightAnchor.constraint(equalToConstant: 60),
            smallCircle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: -20),
            smallCircle.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: 20),

            infoIcon.leadingAnchor.constraint(equalTo: headerRow.leadingAnchor),
            infoIcon.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: infoIcon.trailingAnchor, constant: 5),
            headerLabel.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            chevronView.leadingAnchor.constraint(equalTo: headerLabel.trailingAnchor, constant: 4),
            chevronView.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            chevronView.trailingAnchor.constraint(lessThanOrEqualTo: headerRow.trailingAnchor),
            headerRow.heightAnchor.constraint(equalToConstant: 24),

            separator.heightAnchor.constraint(equalToConstant: 1),
            separator.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let cardRect = bounds.inset(by: UIEdgeInsets(top: 4, left: 16, bottom: 8, right: 16))
        layer.shadowPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 22).cgPath
    }

    func configure(title: String, body: String, buttonText: String, showButton: Bool, buttonAction: @escaping () -> Void, toggleDisclaimerAction: @escaping () -> Void) {
        titleLabel.text = title
        bodyLabel.text = body
        card.updateColors(isAttention: showButton)
        button.isHidden = !showButton
        var config = button.configuration ?? UIButton.Configuration.filled()
        config.attributedTitle = AttributedString(buttonText, attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 14, weight: .bold)]))
        button.configuration = config
        self.onButtonTapped = buttonAction
        self.onToggleDisclaimer = toggleDisclaimerAction
    }

    @objc private func buttonTapped() {
        onButtonTapped?()
    }

    @objc private func toggleDisclaimerTapped() {
        let willShow = disclaimerLabel.isHidden
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.disclaimerLabel.isHidden = !willShow
            self.disclaimerLabel.alpha = willShow ? 1 : 0
            self.chevronView.transform = willShow ? CGAffineTransform(rotationAngle: .pi) : .identity
        } completion: { [weak self] _ in
            self?.onToggleDisclaimer?()
        }
    }
}
