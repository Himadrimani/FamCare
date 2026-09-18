//
//  AppleHealthTableViewController.swift
//  HealthSharing
//
//  Created by Mohd Kushaad on 01/02/26.
//

import UIKit

enum HealthConnectionMode {
    case appleHealth
    case appleWatch

    var navigationTitle: String {
        switch self {
        case .appleHealth:
            return "Apple Health"
        case .appleWatch:
            return "Apple Watch"
        }
    }

    var manageRowTitle: String {
        switch self {
        case .appleHealth:
            return "Open Health App"
        case .appleWatch:
            return "Watch sync guide"
        }
    }

    var subtitle: String {
        switch self {
        case .appleHealth:
            return "This app reads your wellness data from Apple Health and refreshes it here automatically."
        case .appleWatch:
            return "Apple Watch data appears here once the watch writes it into Apple Health on this iPhone."
        }
    }

    var systemImageName: String {
        switch self {
        case .appleHealth:
            return "heart.text.square.fill"
        case .appleWatch:
            return "applewatch"
        }
    }
}

struct HealthConnectionMetric {
    let title: String
    let subtitle: String
    let valueText: String
    let isAvailable: Bool
}

struct HealthConnectionSnapshot {
    let mode: HealthConnectionMode
    let isLinkedToCurrentProfile: Bool
    let activityMetrics: [HealthConnectionMetric]
    let healthMetrics: [HealthConnectionMetric]
    let latestSyncDate: Date?

    var allMetrics: [HealthConnectionMetric] {
        activityMetrics + healthMetrics
    }

    var syncedMetricCount: Int {
        allMetrics.filter(\.isAvailable).count
    }

    var totalMetricCount: Int {
        allMetrics.count
    }

    var profileSummaryText: String {
        if syncedMetricCount > 0 {
            return "\(syncedMetricCount)/\(totalMetricCount) metrics available"
        }
        if isLinkedToCurrentProfile {
            return "Ready to sync"
        }
        return "Not connected"
    }

    var statusSummaryText: String {
        if syncedMetricCount > 0 {
            let latest = latestSyncDate.map { Self.relativeFormatter.localizedString(for: $0, relativeTo: Date()) } ?? "recently"
            return "\(syncedMetricCount) of \(totalMetricCount) metrics are available. Last refresh \(latest)."
        }
        if isLinkedToCurrentProfile {
            return "Connection is set up for this profile, but no health samples have been synced yet."
        }
        return "Health sync is not linked to this profile on this device yet."
    }

    var watchSummaryText: String {
        if syncedMetricCount > 0 {
            return "Watch-supported metrics are flowing through Apple Health."
        }
        if isLinkedToCurrentProfile {
            return "Waiting for Apple Watch data to appear in Apple Health."
        }
        return "Link Apple Health first to review Apple Watch-backed metrics."
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    static func make(for profile: Profile?, mode: HealthConnectionMode) -> HealthConnectionSnapshot {
        guard let profile else {
            return HealthConnectionSnapshot(
                mode: mode,
                isLinkedToCurrentProfile: false,
                activityMetrics: [],
                healthMetrics: [],
                latestSyncDate: nil
            )
        }

        let isLinked = DataManager.shared.isCurrentUserHealthKitLinked()
        let activityRows = profile.activityDaily
        let sleepRows = profile.sleep
        let vitalRows = profile.vitalDaily

        let steps = latestMeaningfulActivity(.steps, in: activityRows)
        let distance = latestMeaningfulActivity(.distance, in: activityRows)
        let calories = latestMeaningfulActivity(.calories, in: activityRows)
        let sleep = latestMeaningfulSleep(in: sleepRows)
        let heartRate = latestMeaningfulVital(.heartRate, in: vitalRows)
        let hrv = latestMeaningfulVital(.hrv, in: vitalRows)

        let activityMetrics = [
            HealthConnectionMetric(
                title: "Steps",
                subtitle: steps == nil ? "No walking data yet" : "Latest daily total",
                valueText: steps.map { Self.integerFormatter.string(from: NSNumber(value: Int($0.value))) ?? "\(Int($0.value))" } ?? "No data",
                isAvailable: steps != nil
            ),
            HealthConnectionMetric(
                title: "Distance",
                subtitle: distance == nil ? "No walking or running distance yet" : "Latest daily total",
                valueText: distance.map { String(format: "%.2f km", $0.value / 1000.0) } ?? "No data",
                isAvailable: distance != nil
            ),
            HealthConnectionMetric(
                title: "Active energy",
                subtitle: calories == nil ? "No calories burned yet" : "Latest daily total",
                valueText: calories.map { "\(Int($0.value.rounded())) kcal" } ?? "No data",
                isAvailable: calories != nil
            ),
            HealthConnectionMetric(
                title: "Sleep",
                subtitle: sleep == nil ? "No sleep analysis yet" : "Most recent sleep session",
                valueText: sleep.map { String(format: "%.1f hr", $0.totalSleep) } ?? "No data",
                isAvailable: sleep != nil
            )
        ]

        let healthMetrics = [
            HealthConnectionMetric(
                title: "Heart rate",
                subtitle: heartRate == nil ? "No heart rate samples yet" : "Latest daily average",
                valueText: heartRate.flatMap { $0.avgValue }.map { "\(Int($0.rounded())) bpm" } ?? "No data",
                isAvailable: heartRate != nil
            ),
            HealthConnectionMetric(
                title: "HRV",
                subtitle: hrv == nil ? "No variability samples yet" : "Latest daily average",
                valueText: hrv.flatMap { $0.avgValue }.map { "\(Int($0.rounded())) ms" } ?? "No data",
                isAvailable: hrv != nil
            )
        ]

        let timestamps = activityRows.map(\.lastUpdatedAt) + sleepRows.map(\.lastUpdatedAt) + vitalRows.map(\.lastUpdatedAt)

        return HealthConnectionSnapshot(
            mode: mode,
            isLinkedToCurrentProfile: isLinked,
            activityMetrics: activityMetrics,
            healthMetrics: healthMetrics,
            latestSyncDate: timestamps.max()
        )
    }

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    private static func latestMeaningfulActivity(_ type: ActivityType, in rows: [ActivityDaily]) -> ActivityDaily? {
        let filtered = rows.filter { $0.type == type }
        return filtered.first(where: { $0.value > 0 }) ?? filtered.first
    }

    private static func latestMeaningfulSleep(in rows: [SleepDaily]) -> SleepDaily? {
        rows.first(where: { $0.totalSleep > 0 }) ?? rows.first
    }

    private static func latestMeaningfulVital(_ type: VitalType, in rows: [VitalsDaily]) -> VitalsDaily? {
        let filtered = rows.filter { $0.type == type }
        return filtered.first(where: { ($0.avgValue ?? 0) > 0 || ($0.maxValue ?? 0) > 0 || ($0.minValue ?? 0) > 0 }) ?? filtered.first
    }
}

final class HealthConnectionDetailsViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case connection
        case sharing
        case activity
        case health
    }

    private let mode: HealthConnectionMode
    private var snapshot: HealthConnectionSnapshot

    init(mode: HealthConnectionMode, profile: Profile?) {
        self.mode = mode
        self.snapshot = HealthConnectionSnapshot.make(for: profile, mode: mode)
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        self.mode = .appleHealth
        self.snapshot = HealthConnectionSnapshot.make(for: DataManager.shared.currentUser, mode: .appleHealth)
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = mode.navigationTitle
        tableView.backgroundColor = .systemGroupedBackground
        NotificationCenter.default.addObserver(self, selector: #selector(reloadSnapshot), name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func reloadSnapshot() {
        snapshot = HealthConnectionSnapshot.make(for: DataManager.shared.currentUser, mode: mode)
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .connection:
            return 2
        case .sharing:
            return 1
        case .activity:
            return snapshot.activityMetrics.count
        case .health:
            return snapshot.healthMetrics.count
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        switch section {
        case .connection:
            return mode == .appleHealth ? "Connection" : "Watch sync"
        case .sharing:
            return "Family sharing"
        case .activity:
            return "Activity & habits"
        case .health:
            return "Health metrics"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        if section == .connection && mode == .appleWatch {
            return "Apple Watch pairing and complications are managed by Apple's Watch app. This screen shows whether watch-backed data has reached Apple Health and is visible in this app."
        }
        if section == .sharing {
            return "When on, your wellness data (steps, distance, active energy, sleep, heart rate and HRV) is uploaded so your family members can see it. When off, your data stays on this device only and previously shared data is removed from the server."
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        }

        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.selectionStyle = .none
        cell.detailTextLabel?.numberOfLines = 0
        cell.textLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        cell.detailTextLabel?.font = .systemFont(ofSize: 13, weight: .regular)
        cell.detailTextLabel?.textColor = .secondaryLabel

        switch section {
        case .connection:
            configureConnectionCell(cell, row: indexPath.row)
        case .sharing:
            configureSharingCell(cell)
        case .activity:
            configureMetricCell(cell, metric: snapshot.activityMetrics[indexPath.row], iconName: activityIconName(for: indexPath.row))
        case .health:
            configureMetricCell(cell, metric: snapshot.healthMetrics[indexPath.row], iconName: healthIconName(for: indexPath.row))
        }

        return cell
    }

    private func configureSharingCell(_ cell: UITableViewCell) {
        var content = cell.defaultContentConfiguration()
        content.text = "Share health data with family"
        content.image = UIImage(systemName: "person.2.fill")
        content.imageProperties.tintColor = .systemPink
        cell.contentConfiguration = content
        cell.selectionStyle = .none

        let toggle = UISwitch()
        toggle.isOn = DataManager.shared.isFamilyHealthSharingConsented
        toggle.addTarget(self, action: #selector(sharingToggleChanged(_:)), for: .valueChanged)
        cell.accessoryView = toggle
    }

    @objc private func sharingToggleChanged(_ sender: UISwitch) {
        DataManager.shared.setFamilyHealthSharingConsent(sender.isOn)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == Section.connection.rawValue else { return }

        if indexPath.row == 0 {
            handleManageAction()
        } else if snapshot.isLinkedToCurrentProfile {
            // Connected to this profile: a manual refresh is the useful action.
            DataManager.shared.refreshCurrentUserHealthDataFromHealthKit()
        } else {
            // Connection required. We cannot (and must not) fake read authorization,
            // and iOS won't let the app re-present the permission sheet once it's been
            // handled, so we guide the user to the supported Settings / Health locations.
            presentConnectionRequiredGuidance()
        }
    }

    private func presentConnectionRequiredGuidance() {
        let alert = UIAlertController(
            title: "Connection Required",
            message: "FamCare reads Sleep, Heart Rate, HRV, Steps, Distance and Active Energy from Apple Health. If your data isn't appearing, enable access for FamCare:\n\n• Health app → your profile → Privacy → Apps → FamCare, or\n• Settings → Privacy & Security → Health → FamCare\n\nThen turn on the categories you want to share.",
            preferredStyle: .alert
        )
        if let settingsURL = URL(string: UIApplication.openSettingsURLString),
           UIApplication.shared.canOpenURL(settingsURL) {
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                UIApplication.shared.open(settingsURL)
            })
        }
        if let healthURL = URL(string: "x-apple-health://") {
            alert.addAction(UIAlertAction(title: "Open Health", style: .default) { [weak self] _ in
                UIApplication.shared.open(healthURL) { success in
                    guard !success else { return }
                    self?.presentHealthFallbackAlert()
                }
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func configureConnectionCell(_ cell: UITableViewCell, row: Int) {
        var content = cell.defaultContentConfiguration()
        content.secondaryTextProperties.numberOfLines = 0

        if row == 0 {
            content.text = mode.manageRowTitle
            content.secondaryText = mode == .appleHealth ? snapshot.statusSummaryText : snapshot.watchSummaryText
            content.image = UIImage(systemName: mode.systemImageName)
            content.imageProperties.tintColor = mode == .appleHealth ? .systemPink : .label
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        } else {
            content.text = snapshot.isLinkedToCurrentProfile ? "Sync status" : "Connection required"
            content.secondaryText = mode.subtitle
            content.image = UIImage(systemName: snapshot.isLinkedToCurrentProfile ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            content.imageProperties.tintColor = snapshot.isLinkedToCurrentProfile ? .systemGreen : .systemOrange
            cell.accessoryType = .none
            cell.selectionStyle = .default
        }

        cell.contentConfiguration = content
    }

    private func configureMetricCell(_ cell: UITableViewCell, metric: HealthConnectionMetric, iconName: String) {
        var content = cell.defaultContentConfiguration()
        content.text = metric.title
        content.secondaryText = metric.subtitle
        content.secondaryTextProperties.color = .secondaryLabel
        content.secondaryTextProperties.numberOfLines = 0
        content.image = UIImage(systemName: iconName)
        content.imageProperties.tintColor = .secondaryLabel
        cell.contentConfiguration = content
        cell.accessoryView = makeStatusAccessory(valueText: metric.valueText, isAvailable: metric.isAvailable)
    }

    private func makeStatusAccessory(valueText: String, isAvailable: Bool) -> UIView {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = isAvailable ? .label : .secondaryLabel
        label.text = valueText
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        let imageView = UIImageView(image: UIImage(systemName: isAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"))
        imageView.tintColor = isAvailable ? .systemGreen : .systemOrange
        imageView.contentMode = .scaleAspectFit
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [label, imageView])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }

    private func activityIconName(for index: Int) -> String {
        switch index {
        case 0:
            return "figure.walk"
        case 1:
            return "location"
        case 2:
            return "flame.fill"
        default:
            return "bed.double.fill"
        }
    }

    private func healthIconName(for index: Int) -> String {
        switch index {
        case 0:
            return "heart.fill"
        default:
            return "waveform.path.ecg"
        }
    }

    private func handleManageAction() {
        switch mode {
        case .appleHealth:
            if let url = URL(string: "x-apple-health://") {
                UIApplication.shared.open(url, options: [:]) { [weak self] success in
                    guard !success else { return }
                    self?.presentHealthFallbackAlert()
                }
            } else {
                presentHealthFallbackAlert()
            }
        case .appleWatch:
            let alert = UIAlertController(
                title: "Apple Watch Sync",
                message: "Pairing, complications, and device settings are managed in Apple's Watch app. Once your watch writes data to Apple Health on this iPhone, it will appear here automatically.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Refresh data", style: .default) { _ in
                DataManager.shared.refreshCurrentUserHealthDataFromHealthKit()
            })
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        }
    }

    private func presentHealthFallbackAlert() {
        let alert = UIAlertController(
            title: "Open Apple Health",
            message: "Open the Health app, then review this app's permissions under your profile and connected apps.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

class AppleHealthTableViewController: UITableViewController {
    private var embeddedController: HealthConnectionDetailsViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        let controller = HealthConnectionDetailsViewController(mode: .appleHealth, profile: DataManager.shared.currentUser)
        embeddedController = controller
        addChild(controller)
        view.addSubview(controller.view)
        controller.view.frame = view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        controller.didMove(toParent: self)
    }
}
