//
//  InsightDetailViewController.swift
//  HomeScreen
//
//  Created by Himadri  on 30/03/26.
//

//
//  InsightDetailViewController.swift
//  HomeScreen
//

import UIKit
import DGCharts

// MARK: - InsightDetailViewController
class InsightDetailViewController: UIViewController {

    private let scrollView      = UIScrollView()
    private let stackView       = UIStackView()
    private let titleLabel      = UILabel()
    private let timeLabel       = UILabel()
    private let segmentControl  = UISegmentedControl(items: ["D", "W", "M"])
    private let closeButton     = UIButton(type: .system)

    var insightType: InsightType!
    var profile: Profile!

    private var cards: [MetricDetailCard] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupHeader()
        setupFilters()
        setupCards()
        updateData()
    }

    private func setupHeader() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let baseTitle = insightType == .calories ? "Calories" : insightType.rawValue.capitalized
        titleLabel.text = "My \(baseTitle)"
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        view.addSubview(titleLabel)

        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.text      = "Today"
        timeLabel.font      = .systemFont(ofSize: 16, weight: .medium)
        timeLabel.textColor = .secondaryLabel
        view.addSubview(timeLabel)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .systemGray2
        closeButton.setPreferredSymbolConfiguration(.init(pointSize: 30), forImageIn: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            timeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func setupFilters() {
        segmentControl.translatesAutoresizingMaskIntoConstraints = false
        segmentControl.selectedSegmentIndex = 0
        segmentControl.backgroundColor           = .systemGray6
        segmentControl.selectedSegmentTintColor  = .systemGray
        segmentControl.setTitleTextAttributes(
            [.foregroundColor: UIColor.label,          .font: UIFont.systemFont(ofSize: 13, weight: .bold)],   for: .selected)
        segmentControl.setTitleTextAttributes(
            [.foregroundColor: UIColor.secondaryLabel, .font: UIFont.systemFont(ofSize: 13, weight: .medium)], for: .normal)
        segmentControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        view.addSubview(segmentControl)

        NSLayoutConstraint.activate([
            segmentControl.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 20),
            segmentControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            segmentControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            segmentControl.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    private func setupCards() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 40, right: 0)
        view.addSubview(scrollView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis    = .vertical
        stackView.spacing = 20
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])

        switch insightType! {
        case .steps:     addCard(title: "STEPS",       color: .systemGreen)
        case .calories:  addCard(title: "BURNED",      color: .systemOrange)
        case .sleep:     addCard(title: "TOTAL SLEEP", color: .systemBlue)
        case .heartRate: addCard(title: "HEART RATE",  color: .systemPink)
        case .hrv:       addCard(title: "HRV",         color: .systemPurple)
        case .distance:  addCard(title: "DISTANCE",    color: .systemTeal)
        }
    }

    private func addCard(title: String, color: UIColor) {
        let card = MetricDetailCard()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.setup(title: title, color: color)
        stackView.addArrangedSubview(card)
        cards.append(card)
        
        let descriptionView = MetricDescriptionView()
        descriptionView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(descriptionView)
        descriptionViews.append(descriptionView)
    }
    
    private var descriptionViews: [MetricDescriptionView] = []

    @objc private func filterChanged() {
        timeLabel.text = ["Today", "This Week", "This Month"][segmentControl.selectedSegmentIndex]
        updateData()
    }

    private func updateData() {
        guard let insightType else { return }
        let filter = TimeFilter(rawValue: segmentControl.selectedSegmentIndex) ?? .today
        cards.first?.update(profile: profile, insight: insightType, filter: filter)
        loadMemberInsight(for: filter)
    }

    private func loadMemberInsight(for filter: TimeFilter) {
        guard let profile, let insightType, let card = cards.first else { return }
        
        let cal = Calendar.current
        let today = Date()
        
        let (values, _, _) = card.getChartData(filter: filter, type: insightType, profile: profile)

        // For steps/calories/distance a period value is a running total; for sleep we use the
        // AVERAGE per night (over nights with data) so it can be compared to the nightly goal (#11).
        let value: Double
        if filter == .today {
            value = card.extractValue(type: insightType, date: today, profile: profile, cal: cal)
        } else if insightType == .sleep {
            let nights = values.filter { $0 > 0 }
            value = nights.isEmpty ? 0 : nights.reduce(0, +) / Double(nights.count)
        } else {
            value = values.reduce(0, +)
        }
        
        let multiplier: Double = {
            if filter == .today { return 1.0 }
            return Double(values.count)
        }()
        
        let goal: Double = {
            switch insightType {
            case .steps:     return Double(profile.stepGoal) * multiplier
            case .calories:  return Double(profile.caloriesGoal) * multiplier
            case .distance:  return Double(profile.distanceGoal) * multiplier
            // Sleep is compared per-night (value above is a nightly average), so no multiplier.
            case .sleep:     return profile.sleepGoal > 0 ? profile.sleepGoal : 8.0
            default:         return 0
            }
        }()
        
        let description = InsightEngine.shared.generateDetailInsight(
            type: insightType,
            value: value,
            goal: goal,
            profile: profile,
            filter: filter
        )
        
        descriptionViews.first?.setText(description, type: insightType)
    }


    private func shouldSuggestChallenge(profile: Profile, type: InsightType, filter: TimeFilter) -> Bool {
        let cal = Calendar.current
        let today = Date()
        let value = cards.first?.extractValue(type: type, date: today, profile: profile, cal: cal) ?? 0

        switch type {
        case .steps:
            return value < Double(profile.stepGoal) * (filter == .today ? 0.7 : 0.8)
        case .calories:
            return value < Double(profile.caloriesGoal) * (filter == .today ? 0.7 : 0.8)
        case .distance:
            return value < Double(profile.distanceGoal) * (filter == .today ? 0.7 : 0.8)
        case .sleep:
            return value < 7.0
        case .heartRate:
            return value > 85
        case .hrv:
            return value < 40
        }
    }

    private func openChallengesTab() {
        if let tabBar = presentingViewController?.tabBarController ?? tabBarController {
            tabBar.selectedIndex = 2
        }
        dismiss(animated: true)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}

// MARK: - MetricDetailCard
class MetricDetailCard: UIView {

    private let titleLabel        = UILabel()
    private let valueLabel        = UILabel()
    private let sleepSummaryStack = UIStackView()
    private let barChartView      = BarChartView()
    private let scatterChartView  = ScatterChartView()
    private let lineChartView     = LineChartView()
    private var currentType: InsightType = .steps
    private var profile: Profile?
    var onCreateChallengeTapped: (() -> Void)?

    func setup(title: String, color: UIColor) {
        backgroundColor    = .secondarySystemBackground
        layer.cornerRadius = 24

        setupSleepSummary()
        
        [titleLabel, valueLabel, sleepSummaryStack, barChartView, scatterChartView, lineChartView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        titleLabel.text      = title
        titleLabel.font      = .systemFont(ofSize: 14, weight: .bold)
        titleLabel.textColor = color

        valueLabel.font      = .systemFont(ofSize: 32, weight: .bold)
        valueLabel.textColor = .label

        valueLabel.textColor = .label

        // Setup all charts with common styling
        [barChartView, scatterChartView, lineChartView].forEach { chart in
            chart.backgroundColor            = .clear
            chart.chartDescription.enabled   = false
            chart.legend.enabled             = false
            chart.rightAxis.enabled          = true
            chart.rightAxis.drawAxisLineEnabled = false
            chart.rightAxis.labelFont        = .systemFont(ofSize: 10)
            chart.rightAxis.labelTextColor   = .secondaryLabel
            chart.rightAxis.gridColor        = UIColor.separator.withAlphaComponent(0.15)
            chart.rightAxis.drawGridLinesEnabled = true
            chart.leftAxis.enabled           = false
            chart.xAxis.labelPosition        = .bottom
            chart.xAxis.drawGridLinesEnabled = true
            chart.xAxis.gridColor            = UIColor.separator.withAlphaComponent(0.2)
            chart.xAxis.gridLineDashLengths  = [4, 4]
            chart.xAxis.labelTextColor       = .secondaryLabel
            chart.xAxis.labelFont            = .systemFont(ofSize: 10)
            chart.xAxis.drawAxisLineEnabled  = false
            chart.extraRightOffset           = 15
            
            // Default axis formatter to clear any previous
            chart.rightAxis.valueFormatter = LargeValueAxisFormatter()
        }

        // Special renderers
        let barRenderer = RoundedBarChartRenderer(dataProvider: barChartView, animator: barChartView.chartAnimator, viewPortHandler: barChartView.viewPortHandler)
        barRenderer.radius = 4
        barChartView.renderer = barRenderer

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            sleepSummaryStack.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 15),
            sleepSummaryStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            sleepSummaryStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            barChartView.topAnchor.constraint(equalTo: sleepSummaryStack.bottomAnchor, constant: 20),
            barChartView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            barChartView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            barChartView.heightAnchor.constraint(equalToConstant: 220),

            scatterChartView.topAnchor.constraint(equalTo: barChartView.topAnchor),
            scatterChartView.leadingAnchor.constraint(equalTo: barChartView.leadingAnchor),
            scatterChartView.trailingAnchor.constraint(equalTo: barChartView.trailingAnchor),
            scatterChartView.bottomAnchor.constraint(equalTo: barChartView.bottomAnchor),

            lineChartView.topAnchor.constraint(equalTo: barChartView.topAnchor),
            lineChartView.leadingAnchor.constraint(equalTo: barChartView.leadingAnchor),
            lineChartView.trailingAnchor.constraint(equalTo: barChartView.trailingAnchor),
            lineChartView.bottomAnchor.constraint(equalTo: barChartView.bottomAnchor),

            barChartView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
        ])
    }

    private func setupSleepSummary() {
        sleepSummaryStack.axis = .horizontal
        sleepSummaryStack.distribution = .fillEqually
        sleepSummaryStack.spacing = 8
        sleepSummaryStack.isHidden = true // Hidden by default, shown for sleep card
    }

    func update(profile: Profile, insight: InsightType, filter: TimeFilter) {
        self.profile = profile
        self.currentType = insight
        
        let (values, labels, _) = getChartData(filter: filter, type: insight, profile: profile)
        
        let cal = Calendar.current
        let total: Double
        if filter == .today {
            total = extractValue(type: insight, date: Date(), profile: profile, cal: cal)
        } else {
            total = values.reduce(0, +)
        }

        switch insight {
        case .steps:
            let displayVal = total
            valueLabel.text = "\(Int(displayVal).formattedWithSeparator)"
            titleLabel.text = (filter == .today) ? "STEPS" : "TOTAL"
        case .distance:
            let displayVal = total
            valueLabel.text = String(format: "%.3f KM", displayVal / 1000.0)
            titleLabel.text = (filter == .today) ? "DISTANCE" : "TOTAL"
        case .calories:
            let displayVal = total
            valueLabel.text = "\(Int(displayVal).formattedWithSeparator) kcal"
            titleLabel.text = (filter == .today) ? "BURNED" : "TOTAL"
        case .sleep:
            if filter == .today {
                // For today, show the actual total, not an hourly average
                let h = Int(total), m = Int((total - Double(h)) * 60)
                valueLabel.text = "\(h)h \(m)m"
                
                if let s = profile.sleep.first(where: { cal.isDate($0.sleepDate, inSameDayAs: Date()) }) {
                    updateSleepSummary(s)
                    sleepSummaryStack.isHidden = false
                }
            } else {
                // For week/month, show AVERAGE sleep per night (over nights with data), not a
                // running total that reads oddly as a single figure (#11).
                let nights = values.filter { $0 > 0 }
                let avg = nights.isEmpty ? 0 : nights.reduce(0, +) / Double(nights.count)
                let h = Int(avg), m = Int((avg - Double(h)) * 60)
                valueLabel.text = "\(h)h \(m)m"
                titleLabel.text = "AVG / NIGHT"
                sleepSummaryStack.isHidden = true
            }
        case .heartRate, .hrv:
            let unit = insight == .heartRate ? "BPM" : "ms"
            if filter == .today {
                valueLabel.text = "\(Int(total)) \(unit)"
                titleLabel.text = insight == .heartRate ? "HEART RATE" : "HRV"
            } else {
                let nonZero = values.filter { $0 > 0 }
                if insight == .heartRate {
                    // Range for Heart Rate
                    let minVal = Int(nonZero.min() ?? 0)
                    let maxVal = Int(nonZero.max() ?? 0)
                    titleLabel.text = "RANGE"
                    valueLabel.text = "\(minVal)-\(maxVal) \(unit)"
                } else {
                    // Average for HRV as per screenshot
                    let avgVal = nonZero.isEmpty ? 0 : Int(nonZero.reduce(0, +) / Double(nonZero.count))
                    titleLabel.text = "AVERAGE"
                    valueLabel.text = "\(avgVal) \(unit)"
                }
            }
        }
        
        // Render with fetched data
        renderChart(values: values, labels: labels, color: colorForInsight(insight))
    }

    func setInsight(text: String, actionLabel: String, showChallengeButton: Bool) {
        // Obsolete
    }

    private func colorForInsight(_ insight: InsightType) -> UIColor {
        switch insight {
        case .steps:     return .systemGreen
        case .distance:  return .systemTeal
        case .calories:  return .systemOrange
        case .sleep:     return .systemBlue
        case .heartRate: return .systemPink
        case .hrv:       return .systemPurple
        }
    }

    private func updateSleepSummary(_ sleep: SleepDaily) {
        sleepSummaryStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let components: [(String, Int, UIColor)] = [
            ("AWAKE", sleep.awakeMinutes, .systemOrange),
            ("REM", sleep.remSleepMinutes, .systemPurple),
            ("LIGHT", sleep.lightSleepMinutes, .systemTeal),
            ("DEEP", sleep.deepSleepMinutes, .systemIndigo)
        ]
        
        for (name, mins, color) in components {
            let container = UIStackView()
            container.axis = .vertical
            container.spacing = 2
            
            let nameLabel = UILabel()
            nameLabel.text = name
            nameLabel.font = .systemFont(ofSize: 10, weight: .bold)
            nameLabel.textColor = color
            
            let valLabel = UILabel()
            let h = mins / 60, m = mins % 60
            valLabel.text = h > 0 ? "\(h)h \(m)m" : "\(m)m"
            valLabel.font = .systemFont(ofSize: 13, weight: .bold)
            valLabel.textColor = .label
            
            container.addArrangedSubview(nameLabel)
            container.addArrangedSubview(valLabel)
            sleepSummaryStack.addArrangedSubview(container)
        }
    }

    private func renderChart(values: [Double], labels: [String], color: UIColor) {
        let isScatter = currentType == .heartRate
        let isLine    = currentType == .hrv
        
        barChartView.isHidden     = isScatter || isLine
        scatterChartView.isHidden = !isScatter
        lineChartView.isHidden    = !isLine
        
        let isSleepToday = currentType == .sleep && labels.count > 10 && labels.count < 30 && labels.contains("12 AM")
        let chart: BarLineChartViewBase = isLine ? lineChartView : (isScatter ? scatterChartView : (isSleepToday ? scatterChartView : barChartView))
        
        if isSleepToday {
            // Sleep hypnogram style - using Scatter for "Point Graph" look
            scatterChartView.isHidden = false
            barChartView.isHidden = true
            lineChartView.isHidden = true
            
            var dataEntries: [ChartDataEntry] = []
            var colors: [UIColor] = []
            
            // Values here are already 1-4 (Deep, Light, REM, Awake) from getChartData
            for (i, v) in values.enumerated() {
                guard v > 0 else { continue }
                dataEntries.append(ChartDataEntry(x: Double(i), y: v))
                
                // Direct color mapping for each point
                if v == 4 { colors.append(.systemOrange) } // Awake
                else if v == 3 { colors.append(.systemPurple) } // REM
                else if v == 2 { colors.append(.systemTeal) }   // Light
                else if v == 1 { colors.append(.systemIndigo) } // Deep
                else { colors.append(.systemIndigo) }
            }
            
            let dataSet = ScatterChartDataSet(entries: dataEntries)
            dataSet.setScatterShape(.circle)
            dataSet.scatterShapeSize = 10
            dataSet.colors = colors
            dataSet.drawValuesEnabled = false
            
            scatterChartView.data = ScatterChartData(dataSet: dataSet)
            
            scatterChartView.rightAxis.axisMaximum = 4.5
            scatterChartView.rightAxis.axisMinimum = 0.5
            scatterChartView.rightAxis.setLabelCount(4, force: true)
            // Simplified Y labels: just the names, very clean
            scatterChartView.rightAxis.valueFormatter = IndexAxisValueFormatter(values: ["", "Deep", "Light", "REM", "Awake"])
            
        } else if isLine {
            let entries = values.enumerated().compactMap { (i, v) -> ChartDataEntry? in
                guard v > 0 else { return nil }
                return ChartDataEntry(x: Double(i), y: v)
            }
            let dataSet = LineChartDataSet(entries: entries, label: "")
            dataSet.colors             = [.systemRed]
            dataSet.drawCirclesEnabled = true
            dataSet.circleRadius       = 4
            dataSet.circleColors       = [.systemRed]
            dataSet.drawCircleHoleEnabled = false
            dataSet.lineWidth          = 2
            dataSet.drawValuesEnabled  = false
            dataSet.highlightEnabled   = true
            dataSet.mode               = .linear
            
            lineChartView.data = LineChartData(dataSet: dataSet)
        } else if isScatter {
            // Filter out 0/nil values to prevent dots at the bottom
            let entries = values.enumerated().compactMap { (i, v) -> ChartDataEntry? in
                guard v > 0 else { return nil }
                return ChartDataEntry(x: Double(i), y: v)
            }
            
            let dataSet = ScatterChartDataSet(entries: entries, label: "")
            dataSet.setScatterShape(.circle)
            dataSet.scatterShapeSize = 6
            dataSet.colors = [.systemRed]
            dataSet.drawValuesEnabled = false // Disable labels on dots to avoid overlap
            dataSet.highlightEnabled = true
            
            scatterChartView.data = ScatterChartData(dataSet: dataSet)
        } else {
            let entries = values.enumerated().map { BarChartDataEntry(x: Double($0.offset), y: $0.element) }
            let dataSet = BarChartDataSet(entries: entries, label: "")
            dataSet.colors             = [color.withAlphaComponent(0.9)]
            dataSet.drawValuesEnabled  = false
            dataSet.highlightEnabled   = true
            dataSet.highlightColor     = .label.withAlphaComponent(0.3)
            
            let data = BarChartData(dataSet: dataSet)
            data.barWidth = values.count > 15 ? 0.7 : 0.4
            barChartView.data = data
        }

        // Threshold calculation for Y-axis
        let filterIndex = labels.count > 25 ? 2 : (labels.count == 25 ? 0 : 1)
        let filterEnumValue = TimeFilter(rawValue: filterIndex) ?? .today

        let multiplier: Double = {
            if filterIndex == 0 { return 1.0 } // Today
            return Double(values.count)        // 7 for Week, 28-31 for Month
        }()

        let goal: Double = {
            switch currentType {
            case .steps:     return Double(profile?.stepGoal ?? 10000) * multiplier
            case .calories:  return Double(profile?.caloriesGoal ?? 2000) * multiplier
            case .distance:  return Double(profile?.distanceGoal ?? 5) * 1000.0 * multiplier
            case .sleep:     return (profile?.sleepGoal ?? 8.0) * multiplier
            case .heartRate: return 120
            case .hrv:       return 150
            }
        }()

        let maxValInChart = values.max() ?? 0
        let threshold = max(maxValInChart * 1.1, goal)

        chart.rightAxis.axisMaximum = threshold
        let minVal: Double = (isScatter || isLine) ? (isLine ? 0 : 40) : 0
        chart.rightAxis.axisMinimum = minVal
        chart.leftAxis.axisMinimum = minVal
        
        // Add units to Y-axis labels
        if currentType == .sleep && filterEnumValue != .today {
            chart.rightAxis.valueFormatter = UnitAxisValueFormatter(unit: "h")
            chart.rightAxis.setLabelCount(5, force: true)
        } else if currentType == .distance {
            chart.rightAxis.valueFormatter = DistanceAxisValueFormatter()
            chart.rightAxis.setLabelCount(5, force: true)
        } else if currentType != .sleep {
            chart.rightAxis.valueFormatter = LargeValueAxisFormatter()
            chart.rightAxis.setLabelCount(5, force: true)
        }

        chart.xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        
        if filterEnumValue == .today {
             chart.xAxis.axisMinimum = -0.7
             chart.xAxis.axisMaximum = 24.7
             chart.xAxis.setLabelCount(3, force: true)
             chart.xAxis.granularity = 12
        } else {
             chart.xAxis.axisMinimum = -0.5
             chart.xAxis.axisMaximum = Double(labels.count) - 0.5
             chart.xAxis.setLabelCount(min(labels.count, 7), force: false)
             chart.xAxis.granularity = 1
        }
        
        chart.animate(yAxisDuration: 0.6, easingOption: .easeOutQuad)
    }

    func getChartData(filter: TimeFilter, type: InsightType, profile: Profile) -> ([Double], [String], [Date]) {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())

        switch filter {
        case .today:
            var values = [Double](repeating: 0, count: 24)
            let hourlyLabels: [String] = (0..<25).map {
                switch $0 { 
                case 0: return "12 AM"
                case 6: return "6"
                case 12: return "12 PM"
                case 18: return "6"
                case 24: return "0" // End of day
                default: return "" 
                }
            }
            let dates = (0..<24).map { cal.date(byAdding: .hour, value: $0, to: today)! }

            if type == .steps || type == .calories || type == .distance {
                let actType: ActivityType = type == .steps ? .stepCount : type == .calories ? .caloriesBurned : .distanceCovered
                for r in profile.activityHourly where r.activityType == actType && cal.isDate(r.dateUTC, inSameDayAs: today) {
                    if r.hourBucket < 24 { values[r.hourBucket] = Double(r.value) }
                }
            } else if type == .heartRate || type == .hrv {
                let vitType: VitalType = type == .heartRate ? .heartRate : .hrv
                for r in profile.vitalHourly where r.vitalType == vitType && cal.isDate(r.dateUTC, inSameDayAs: today) {
                    if r.hourBucket < 24 { values[r.hourBucket] = Double(r.avgValue ?? 0) }
                }
            } else if type == .sleep {
                if let s = profile.sleep.first(where: { cal.isDate($0.sleepDate, inSameDayAs: today) }) {
                    let startH = cal.component(.hour, from: s.sleepStartUTC)
                    let totalHours = Double(s.totalSleepMinutes) / 60.0
                    
                    // Distribute stages across the sleep duration
                    let deepRatio = Double(s.deepSleepMinutes) / Double(max(s.totalSleepMinutes, 1))
                    let remRatio = Double(s.remSleepMinutes) / Double(max(s.totalSleepMinutes, 1))
                    _ = Double(s.lightSleepMinutes) / Double(max(s.totalSleepMinutes, 1))
                    
                    for h in 0..<Int(ceil(totalHours)) {
                        let hourIdx = (startH + h) % 24
                        let progress = Double(h) / totalHours
                        
                        // Fake a realistic sleep cycle: Deep at start, REM more at end
                        let stage: Double
                        if progress < deepRatio { stage = 1 } // Deep
                        else if progress > (1.0 - remRatio) { stage = 3 } // REM
                        else if h % 4 == 0 { stage = 4 } // Awake brief
                        else { stage = 2 } // Light
                        
                        values[hourIdx] = stage
                    }
                }
            }
            return (values, hourlyLabels, dates)

        case .week:
            let dates  = (0..<7).map { cal.date(byAdding: .day, value: -(6 - $0), to: today)! }
            let labels = dates.map { d -> String in let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: d) }
            var values = [Double](repeating: 0, count: 7)
            for i in 0..<7 { values[i] = extractValue(type: type, date: dates[i], profile: profile, cal: cal) }
            return (values, labels, dates)

        case .month:
            let range = cal.range(of: .day, in: .month, for: today)!
            let numDays = range.count
            guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: today)) else {
                return ([], [], [])
            }
            let dates = (0..<numDays).map { cal.date(byAdding: .day, value: $0, to: monthStart)! }
            let labels = dates.map { d -> String in
                let day = cal.component(.day, from: d)
                return [1, 8, 15, 22, 29].contains(day) ? "\(day)" : ""
            }
            var values = [Double](repeating: 0, count: numDays)
            for i in 0..<numDays { values[i] = extractValue(type: type, date: dates[i], profile: profile, cal: cal) }
            return (values, labels, dates)
        }
    }

    func extractValue(type: InsightType, date: Date, profile: Profile, cal: Calendar) -> Double {
        switch type {
        case .steps, .calories, .distance:
            let actType: ActivityType = type == .steps ? .stepCount : type == .calories ? .caloriesBurned : .distanceCovered
            return Double(profile.activityDaily.first { $0.activityType == actType && cal.isDate($0.date, inSameDayAs: date) }?.value ?? 0)
        case .heartRate, .hrv:
            let vitType: VitalType = type == .heartRate ? .heartRate : .hrv
            return Double(profile.vitalDaily.first { $0.vitalType == vitType && cal.isDate($0.date, inSameDayAs: date) }?.avgValue ?? 0)
        case .sleep:
            let s = profile.sleep.first { cal.isDate($0.sleepDate, inSameDayAs: date) }
            return Double(s?.totalSleepMinutes ?? 0) / 60.0
        }
    }
}

// MARK: - Formatters
class UnitAxisValueFormatter: NSObject, AxisValueFormatter {
    let unit: String
    init(unit: String) { self.unit = unit }
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        return "\(Int(value))\(unit)"
    }
}

class DistanceAxisValueFormatter: NSObject, AxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let km = value / 1000.0
        return km.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f KM", km) : String(format: "%.1f KM", km)
    }
}

class LargeValueAxisFormatter: NSObject, AxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        if value >= 1_000_000 {
            let val = value / 1_000_000
            return val.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0fM", val) : String(format: "%.1fM", val)
        } else if value >= 1_000 {
            let val = value / 1_000
            return val.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0fK", val) : String(format: "%.1fK", val)
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        }
    }
}

// MARK: - MetricDescriptionView
class MetricDescriptionView: UIView {
    private let stackView = UIStackView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func setText(_ text: String, type: InsightType) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        for para in paragraphs {
            let container = UIStackView()
            container.axis = .horizontal
            container.spacing = 12
            container.alignment = .top
            
            let label = UILabel()
            label.numberOfLines = 0
            label.font = .systemFont(ofSize: 14, weight: .regular)
            label.textColor = .label
            
            if type == .sleep {
                let attributed = NSMutableAttributedString(string: para)
                let colorMap: [(String, UIColor)] = [
                    ("REM sleep", .systemPurple),
                    ("Deep sleep", .systemIndigo),
                    ("Light sleep", .systemTeal)
                ]
                
                for (keyword, color) in colorMap {
                    let range = (para as NSString).range(of: keyword, options: .caseInsensitive)
                    if range.location != NSNotFound {
                        attributed.addAttribute(.foregroundColor, value: color, range: range)
                        attributed.addAttribute(.font, value: UIFont.systemFont(ofSize: 14, weight: .bold), range: range)
                    }
                }
                label.attributedText = attributed
            } else {
                label.text = para
            }
            
            container.addArrangedSubview(label)
            stackView.addArrangedSubview(container)
        }
    }
}
