//
//  WellnessViewController.swift
//  HomeScreen
//

import UIKit
import DGCharts

class WellnessViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    var currentUser: Profile?
    var initialDate: Date?

    private var daysData: [DayData] = []
    private var selectedDayIndex: Int = 29

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        prepareData()
        setupCollectionView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollToToday()
    }

    private func setupNavigationBar() {
        let isSelf = currentUser?.profileId == DataManager.shared.currentUser?.profileId
        if isSelf {
            title = "My Performance"
        } else {
            let name = currentUser?.displayName ?? "Wellness"
            title = "\(name)'s Performance"
        }
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    private func prepareData() {
        guard let user = currentUser else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        daysData = (0..<30).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -(29 - offset), to: today) else { return nil }
            return DayData.fetch(for: user, on: date)
        }
        
        if let initialDate = initialDate {
            let startOfInitial = calendar.startOfDay(for: initialDate)
            if let index = daysData.firstIndex(where: { calendar.startOfDay(for: $0.date) == startOfInitial }) {
                selectedDayIndex = index
            } else {
                selectedDayIndex = daysData.count - 1
            }
        } else {
            selectedDayIndex = daysData.count - 1
        }
    }

    private func setupCollectionView() {
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(UINib(nibName: "DayPickerCell",  bundle: nil), forCellWithReuseIdentifier: "DayPickerCell")
        collectionView.register(UINib(nibName: "MainRingCell",   bundle: nil), forCellWithReuseIdentifier: "MainRingCell")
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "InsightCell")
        collectionView.register(UINib(nibName: "StartRowCell",   bundle: nil), forCellWithReuseIdentifier: "StartRowCell")
        collectionView.collectionViewLayout = createLayout()
    }

    private func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { sectionIndex, _ in
            switch sectionIndex {
            case 0:
                let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(60), heightDimension: .absolute(90))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 8
                section.orthogonalScrollingBehavior = .continuous
                section.contentInsets = .init(top: 10, leading: 16, bottom: 10, trailing: 16)
                return section
            case 1:
                let item  = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(320)))
                let group = NSCollectionLayoutGroup.vertical(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(320)), subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = .init(top: 0, leading: 0, bottom: 20, trailing: 0)
                return section
            case 2:
                // Insight Card
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(160))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = .init(top: 0, leading: 0, bottom: 20, trailing: 0)
                return section
            case 3:
                let item  = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(80)))
                let group = NSCollectionLayoutGroup.vertical(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(80)), subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 12
                section.contentInsets = .init(top: 0, leading: 16, bottom: 30, trailing: 16)
                return section
            default:
                return nil
            }
        }
    }

    private func scrollToToday() {
        let indexPath = IndexPath(item: selectedDayIndex, section: 0)
        DispatchQueue.main.async {
            self.collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
        }
    }

    @objc private func editTapped() {
        let editVC = EditWellnessViewController()
        editVC.profile = currentUser
        editVC.modalPresentationStyle = .pageSheet
        present(editVC, animated: true)
    }
}

// MARK: - UICollectionView DataSource / Delegate
extension WellnessViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func numberOfSections(in collectionView: UICollectionView) -> Int { 4 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0: return daysData.count
        case 1: return 1
        case 2: return selectedDayIndex == (daysData.count - 1) ? 1 : 0 // Only show insight for today
        case 3: return 5 // Stat Row Section
        default: return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let day = daysData[selectedDayIndex]
        switch indexPath.section {
        case 0:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "DayPickerCell", for: indexPath) as! DayPickerCell
            cell.configure(with: daysData[indexPath.item], isSelected: indexPath.item == selectedDayIndex)
            return cell
        case 1:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MainRingCell", for: indexPath) as! MainRingCell
            cell.configure(with: day)
            return cell
        case 2:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "InsightCell", for: indexPath)
            configureInsightCell(cell, for: day)
            return cell
        case 3:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StartRowCell", for: indexPath) as! StartRowCell
            configureStatCell(cell, for: indexPath.item, day: day)
            return cell
        default:
            return UICollectionViewCell()
        }
    }

    private func configureInsightCell(_ cell: UICollectionViewCell, for day: DayData) {
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundColor = .clear
        
        guard let user = currentUser else { return }
        let isSelf = user.profileId == DataManager.shared.currentUser?.profileId
        let insight = InsightEngine.shared.generateInsight(for: user, isSelf: isSelf)
        
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.05)
        container.layer.cornerRadius = 20
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.15).cgColor
        cell.contentView.addSubview(container)
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = insight.title
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .label
        container.addSubview(titleLabel)
        
        let messageLabel = UILabel()
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = insight.message
        messageLabel.font = .systemFont(ofSize: 14, weight: .medium)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        container.addSubview(messageLabel)
        
        let suggestionLabel = UILabel()
        suggestionLabel.translatesAutoresizingMaskIntoConstraints = false
        suggestionLabel.text = insight.suggestion
        suggestionLabel.font = .systemFont(ofSize: 13, weight: .regular)
        suggestionLabel.textColor = .secondaryLabel
        suggestionLabel.numberOfLines = 0
        container.addSubview(suggestionLabel)
        
        var config = UIButton.Configuration.filled()
        config.title = "Start Challenge"
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white
        config.cornerStyle = .fixed
        config.background.cornerRadius = 10
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        config.attributedTitle = AttributedString("Start Challenge", attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 14, weight: .bold)]))

        let button = UIButton(configuration: config, primaryAction: UIAction(handler: { [weak self] _ in
            self?.startChallengeTapped()
        }))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = !insight.showChallengeButton
        container.addSubview(button)

        // Wellness-not-medical-advice footer (#10).
        let disclaimerLabel = UILabel()
        disclaimerLabel.translatesAutoresizingMaskIntoConstraints = false
        disclaimerLabel.text = StandardInsightConfig.medicalDisclaimer
        disclaimerLabel.font = .systemFont(ofSize: 11, weight: .regular)
        disclaimerLabel.textColor = .tertiaryLabel
        disclaimerLabel.numberOfLines = 0
        container.addSubview(disclaimerLabel)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 0),
            container.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -10),
            
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 15),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            messageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
            
            suggestionLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 4),
            suggestionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            suggestionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
        ])
        
        if insight.showChallengeButton {
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: suggestionLabel.bottomAnchor, constant: 12),
                button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
                disclaimerLabel.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 12)
            ])
        } else {
            NSLayoutConstraint.activate([
                disclaimerLabel.topAnchor.constraint(equalTo: suggestionLabel.bottomAnchor, constant: 12)
            ])
        }
        NSLayoutConstraint.activate([
            disclaimerLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            disclaimerLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
            disclaimerLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -15)
        ])
    }

    @objc private func startChallengeTapped() {
        tabBarController?.selectedIndex = 2
    }

    private func configureStatCell(_ cell: StartRowCell, for index: Int, day: DayData) {
        switch index {
        case 0: cell.configure(icon: "shoeprints.fill", color: .systemGreen,  title: "Steps",      value: "\(day.steps)",            target: "of \(day.stepGoal)",    progress: CGFloat(day.steps)    / CGFloat(day.stepGoal))
        case 1: cell.configure(icon: "flame.fill",      color: .systemOrange, title: "Calories",   value: "\(day.calories)",         target: "of \(day.calorieGoal)", progress: CGFloat(day.calories) / CGFloat(day.calorieGoal))
        case 2:
            let h = day.sleepMinutes / 60, m = day.sleepMinutes % 60
            cell.configure(icon: "moon.fill", color: .systemBlue, title: "Sleep", value: "\(h)h \(m)m", target: "of 8h", progress: CGFloat(day.sleepMinutes) / 480.0)
        case 3: cell.configure(icon: "heart.fill",          color: .systemRed,    title: "Heart Rate", value: "\(day.hr) bpm",  target: "Avg", progress: nil)
        case 4: cell.configure(icon: "waveform.path.ecg",   color: .systemPurple, title: "HRV",        value: "\(day.hrv) ms",  target: "Avg", progress: nil)
        default: break
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            selectedDayIndex = indexPath.item
            collectionView.reloadData()
            UISelectionFeedbackGenerator().selectionChanged()
        } else if indexPath.section == 3 {
            let types: [InsightType] = [.steps, .calories, .sleep, .heartRate, .hrv]
            guard indexPath.item < types.count else { return }
            let detail = InsightDetailViewController()
            detail.insightType = types[indexPath.item]
            detail.profile = currentUser
            detail.modalPresentationStyle = .pageSheet
            present(detail, animated: true)
        }
    }
}

// MARK: - DayData Model
struct DayData {
    let date: Date
    let score: Int
    let steps: Int
    let stepGoal: Int
    let calories: Int
    let calorieGoal: Int
    let sleepMinutes: Int
    let sleepGoal: Int
    let hr: Int
    let hrv: Int

    static func fetch(for profile: Profile, on date: Date) -> DayData {
        let cal      = Calendar.current
        let dayStart = cal.startOfDay(for: date)

        let steps       = profile.activityDaily.first(where: { cal.startOfDay(for: $0.date) == dayStart && $0.activityType == .stepCount      })?.value ?? 0
        let stepGoal    = max(profile.stepGoal, 1)
        let calories    = profile.activityDaily.first(where: { cal.startOfDay(for: $0.date) == dayStart && $0.activityType == .caloriesBurned  })?.value ?? 0
        let calorieGoal = max(profile.caloriesGoal, 1)
        let sleepData   = profile.sleep.first(where: { cal.startOfDay(for: $0.sleepDate) == dayStart })
        let sleepMinutes = sleepData?.totalSleepMinutes ?? 0
        let sleepGoal = max(Int(profile.sleepGoal * 60.0), 1)
        let hr  = profile.vitalDaily.first(where: { cal.startOfDay(for: $0.date) == dayStart && $0.vitalType == .heartRate })?.avgValue ?? 0
        let hrv = profile.vitalDaily.first(where: { cal.startOfDay(for: $0.date) == dayStart && $0.vitalType == .hrv       })?.avgValue ?? 0
        let score = calculateScore(for: profile, on: date)

        return DayData(date: date, score: score,
                       steps: Int(steps), stepGoal: stepGoal,
                       calories: Int(calories), calorieGoal: calorieGoal,
                       sleepMinutes: Int(sleepMinutes), sleepGoal: sleepGoal,
                       hr: Int(hr), hrv: Int(hrv))
    }

    private static func calculateScore(for profile: Profile, on date: Date) -> Int {
        return Int(profile.calculateWellnessScore(for: date) * 100.0)
    }
}

// MARK: - Shared Helpers
extension UIFont {
    static func rounded(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        if let d = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: d, size: size)
        }
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
}

extension Int {
    var formattedWithSeparator: String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
