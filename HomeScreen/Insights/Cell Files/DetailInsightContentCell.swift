import UIKit
import DGCharts

class DetailInsightContentCell: UICollectionViewCell {

    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var chartView: BarChartView!
    
    private var infoLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.text = "Tap a bar to see details"
        return label
    }()
    
    private var currentType: InsightType = .steps
    private var currentProfile: Profile?
    private var currentDates: [Date] = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
        setupChart()
    }

    private func setupUI() {
        contentView.addSubview(infoLabel)
        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            infoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            infoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
        
        segmentedControl.removeAllSegments()
        segmentedControl.insertSegment(withTitle: "Today", at: 0, animated: false)
        segmentedControl.insertSegment(withTitle: "Week", at: 1, animated: false)
        segmentedControl.insertSegment(withTitle: "Month", at: 2, animated: false)

        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
    }

    private func setupChart() {
        chartView.delegate = self
        chartView.backgroundColor = .clear
        chartView.chartDescription.enabled = false
        chartView.legend.enabled = false
        chartView.isUserInteractionEnabled = true // Enable interaction
        
        chartView.rightAxis.enabled = false
        let leftAxis = chartView.leftAxis
        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridColor = UIColor.separator.withAlphaComponent(0.3)
        leftAxis.drawAxisLineEnabled = false
        leftAxis.labelFont = .systemFont(ofSize: 9)
        leftAxis.labelTextColor = .secondaryLabel
        leftAxis.labelCount = 5

        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.drawAxisLineEnabled = false
        xAxis.drawGridLinesEnabled = false
        xAxis.labelFont = .systemFont(ofSize: 9, weight: .medium)
        xAxis.labelTextColor = .secondaryLabel
        xAxis.granularity = 1
        xAxis.granularityEnabled = true
        
        // Highlight styling
        chartView.highlightFullBarEnabled = true
        chartView.drawBarShadowEnabled = false
        
        // Use custom renderer for rounded corners
        let renderer = RoundedBarChartRenderer(dataProvider: chartView, animator: chartView.chartAnimator, viewPortHandler: chartView.viewPortHandler)
        renderer.radius = 5
        chartView.renderer = renderer
    }

    // Called when user changes segment (Today / Week / Month)
    @objc private func segmentChanged() {
        guard let profile = currentProfile else { return }
        updateChart(for: currentType, profile: profile)
    }

    // Configure cell with selected type and profile
    func configure(with type: InsightType, profile: Profile, filter: TimeFilter? = nil, showSegment: Bool = true) {
        currentType = type
        currentProfile = profile
        
        segmentedControl.isHidden = !showSegment
        if let filter = filter {
            segmentedControl.selectedSegmentIndex = filter.rawValue
        }
        
        updateChart(for: type, profile: profile)
    }

    private func updateChart(for type: InsightType, profile: Profile) {
        // Get selected filter from segmented control
        let filter = TimeFilter(rawValue: segmentedControl.selectedSegmentIndex) ?? .today

        // Fetch values and labels for chart
        let (values, labels, dates) = getChartData(filter: filter, type: type, profile: profile)
        self.currentDates = dates
        infoLabel.text = "Tap a bar to see details"

        // Assign color based on insight type
        let color: UIColor = {
            switch type {
            case .steps:     return .systemGreen
            case .sleep:     return .systemIndigo
            case .calories:  return .systemOrange
            case .heartRate: return .systemPink
            case .distance:  return .systemTeal
            case .hrv:       return .systemPurple
            }
        }()

        renderChart(values: values, labels: labels, color: color)
    }

    private func renderChart(values: [Double], labels: [String], color: UIColor) {
        guard values.count == labels.count else {
            chartView.data = nil
            return
        }

        let entries = values.enumerated().map {
            BarChartDataEntry(x: Double($0.offset), y: $0.element)
        }

        let dataSet = BarChartDataSet(entries: entries)
        
        // Use a solid color with an alpha for a modern look
        dataSet.colors = [color.withAlphaComponent(0.85)]
        dataSet.drawValuesEnabled = false
        dataSet.highlightColor = color.withAlphaComponent(0.4)
        dataSet.highlightAlpha = 1.0

        let data = BarChartData(dataSet: dataSet)
        data.barWidth = values.count > 12 ? 0.5 : 0.7

        chartView.data = data
        
        let xAxis = chartView.xAxis
        xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        xAxis.labelFont = .systemFont(ofSize: 7, weight: .medium)
        xAxis.labelPosition = .bottom
        xAxis.drawGridLinesEnabled = false
        xAxis.granularity = 1
        xAxis.granularityEnabled = true
        xAxis.centerAxisLabelsEnabled = false
        
        // Rotate labels if many (Daily view)
        if labels.count > 12 {
            xAxis.labelRotationAngle = -45
            xAxis.setLabelCount(labels.count, force: false) // Let it manage count if rotated
        } else {
            xAxis.labelRotationAngle = 0
            xAxis.setLabelCount(labels.count, force: true)
        }
        
        xAxis.axisMinimum = -0.5
        xAxis.axisMaximum = Double(labels.count) - 0.5

        chartView.fitBars = true
        chartView.animate(yAxisDuration: 1.0, easingOption: .easeOutQuart)
    }
}

// MARK: - ChartViewDelegate
extension DetailInsightContentCell: ChartViewDelegate {
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        guard let profile = currentProfile, Int(entry.x) < currentDates.count else { return }
        
        let date = currentDates[Int(entry.x)]
        let value = entry.y
        let score = profile.calculateWellnessScore(for: date)
        let percentScore = Int(score * 100)
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        let unit: String = {
            switch currentType {
            case .steps: return "steps"
            case .calories: return "kcal"
            case .sleep: return "hrs"
            case .heartRate: return "bpm"
            case .hrv: return "ms"
            case .distance: return "km"
            }
        }()
        
        let valueString = currentType == .sleep ? String(format: "%.1f", value) : "\(Int(value))"
        infoLabel.text = "\(formatter.string(from: date)): \(valueString) \(unit) | Score: \(percentScore)%"
        infoLabel.textColor = .label
    }
    
    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        infoLabel.text = "Tap a bar to see details"
        infoLabel.textColor = .secondaryLabel
    }
}

extension DetailInsightContentCell {
    //Data Routing
    private func getChartData(filter: TimeFilter, type: InsightType, profile: Profile) -> ([Double], [String], [Date]) {
        switch type {
        case .steps:     return getActivityData(filter: filter, type: .stepCount, profile: profile)
        case .calories:  return getActivityData(filter: filter, type: .caloriesBurned, profile: profile)
        case .distance:  return getActivityData(filter: filter, type: .distanceCovered, profile: profile)
        case .sleep:     return getSleepData(filter: filter, profile: profile)
        case .heartRate: return getVitalsData(filter: filter, type: .heartRate, profile: profile)
        case .hrv:       return getVitalsData(filter: filter, type: .hrv, profile: profile)
        }
    }

    //Activity Data (Steps, Calories, Distance)
    private func getActivityData(filter: TimeFilter, type: ActivityType, profile: Profile) -> ([Double], [String], [Date]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch filter {
        case .today:
            let labels = (0..<24).map { "\($0)h" }
            var values = [Double](repeating: 0, count: 24)
            var dates = [Date](repeating: today, count: 24)

            for i in 0..<24 {
                dates[i] = calendar.date(byAdding: .hour, value: i, to: today) ?? today
            }

            let todayRecords = profile.activityHourly.filter {
                $0.activityType == type && calendar.isDate($0.dateUTC, inSameDayAs: today)
            }

            for record in todayRecords {
                let hour = record.hourBucket
                if hour >= 0 && hour < 24 {
                    values[hour] = Double(record.value)
                }
            }
            return (values, labels, dates)

        case .week:
            let labels = lastNDaysLabels(n: 7)
            var values = [Double](repeating: 0, count: 7)
            var dates = [Date](repeating: today, count: 7)

            for i in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: -(6 - i), to: today) else { continue }
                dates[i] = day
                let match = profile.activityDaily.first {
                    $0.activityType == type && calendar.isDate($0.date, inSameDayAs: day)
                }
                values[i] = Double(match?.value ?? 0)
            }
            return (values, labels, dates)

        case .month:
            let labels = lastNMonthsLabels(n: 12)
            var values = [Double](repeating: 0, count: 12)
            var dates = [Date](repeating: today, count: 12)

            for i in 0..<12 {
                guard let monthStart = calendar.date(byAdding: .month, value: -(11 - i), to: today) else { continue }
                dates[i] = monthStart
                let targetMonth = calendar.component(.month, from: monthStart)
                let targetYear  = calendar.component(.year,  from: monthStart)

                let monthRecords = profile.activityDaily.filter {
                    $0.activityType == type &&
                    calendar.component(.month, from: $0.date) == targetMonth &&
                    calendar.component(.year,  from: $0.date) == targetYear
                }
                values[i] = monthRecords.reduce(0) { $0 + Double($1.value) }
            }
            return (values, labels, dates)
        }
    }

    //Sleep Data

    //Sleep Data
    private func getSleepData(filter: TimeFilter, profile: Profile) -> ([Double], [String], [Date]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch filter {
        case .today:
            let labels = (0..<24).map { "\($0)h" }
            var values = [Double](repeating: 0, count: 24)
            var dates = [Date](repeating: today, count: 24)
            for i in 0..<24 {
                dates[i] = calendar.date(byAdding: .hour, value: i, to: today) ?? today
            }

            if let todaySleep = profile.sleep.first(where: { calendar.isDate($0.sleepDate, inSameDayAs: today) }) {
                let startHour = calendar.component(.hour, from: todaySleep.sleepStartUTC)
                let durationHours = Double(todaySleep.totalSleepMinutes) / 60.0
                let totalHours = min(Int(ceil(durationHours)), 24)

                for h in 0..<totalHours {
                    let index = (startHour + h) % 24
                    let remaining = durationHours - Double(h)
                    values[index] = min(remaining, 1.0)
                }
            }
            return (values, labels, dates)

        case .week:
            let labels = lastNDaysLabels(n: 7)
            var values = [Double](repeating: 0, count: 7)
            var dates = [Date](repeating: today, count: 7)

            for i in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: -(6 - i), to: today) else { continue }
                dates[i] = day
                let match = profile.sleep.first { calendar.isDate($0.sleepDate, inSameDayAs: day) }
                values[i] = match.map { Double($0.totalSleepMinutes) / 60.0 } ?? 0
            }
            return (values, labels, dates)

        case .month:
            let labels = lastNMonthsLabels(n: 12)
            var values = [Double](repeating: 0, count: 12)
            var dates = [Date](repeating: today, count: 12)

            for i in 0..<12 {
                guard let monthStart = calendar.date(byAdding: .month, value: -(11 - i), to: today) else { continue }
                dates[i] = monthStart
                let targetMonth = calendar.component(.month, from: monthStart)
                let targetYear  = calendar.component(.year,  from: monthStart)

                let monthRecords = profile.sleep.filter {
                    calendar.component(.month, from: $0.sleepDate) == targetMonth &&
                    calendar.component(.year,  from: $0.sleepDate) == targetYear
                }

                if !monthRecords.isEmpty {
                    let totalMinutes = monthRecords.reduce(0) { $0 + $1.totalSleepMinutes }
                    values[i] = (Double(totalMinutes) / Double(monthRecords.count)) / 60.0
                }
            }
            return (values, labels, dates)
        }
    }

    //Vitals Data (Heart Rate, HRV)

    //Vitals Data (Heart Rate, HRV)
    private func getVitalsData(filter: TimeFilter, type: VitalType, profile: Profile) -> ([Double], [String], [Date]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch filter {
        case .today:
            let labels = (0..<24).map { "\($0)h" }
            var values = [Double](repeating: 0, count: 24)
            var dates = [Date](repeating: today, count: 24)
            for i in 0..<24 {
                dates[i] = calendar.date(byAdding: .hour, value: i, to: today) ?? today
            }

            let todayRecords = profile.vitalHourly.filter {
                $0.vitalType == type && calendar.isDate($0.dateUTC, inSameDayAs: today)
            }

            for record in todayRecords {
                let hour = record.hourBucket
                if hour >= 0 && hour < 24 {
                    values[hour] = Double(record.avgValue ?? 0.0)
                }
            }
            return (values, labels, dates)

        case .week:
            let labels = lastNDaysLabels(n: 7)
            var values = [Double](repeating: 0, count: 7)
            var dates = [Date](repeating: today, count: 7)

            for i in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: -(6 - i), to: today) else { continue }
                dates[i] = day
                let match = profile.vitalDaily.first {
                    $0.vitalType == type && calendar.isDate($0.date, inSameDayAs: day)
                }
                values[i] = match.map { Double($0.avgValue ?? 0.0) } ?? 0
            }
            return (values, labels, dates)

        case .month:
            let labels = lastNMonthsLabels(n: 12)
            var values = [Double](repeating: 0, count: 12)
            var dates = [Date](repeating: today, count: 12)

            for i in 0..<12 {
                guard let monthStart = calendar.date(byAdding: .month, value: -(11 - i), to: today) else { continue }
                dates[i] = monthStart
                let targetMonth = calendar.component(.month, from: monthStart)
                let targetYear  = calendar.component(.year,  from: monthStart)

                let monthRecords = profile.vitalDaily.filter {
                    $0.vitalType == type &&
                    calendar.component(.month, from: $0.date) == targetMonth &&
                    calendar.component(.year,  from: $0.date) == targetYear
                }

                if !monthRecords.isEmpty {
                    let total = monthRecords.reduce(0.0) { $0 + ($1.avgValue ?? 0.0) }
                    values[i] = Double(total) / Double(monthRecords.count)
                }
            }
            return (values, labels, dates)
        }
    }

    //Label Helpers
    private func lastNDaysLabels(n: Int) -> [String] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"

        // Generate labels for last N days
        return (0..<n).map { i in
            let day = calendar.date(byAdding: .day, value: -(n - 1 - i), to: today) ?? today
            return formatter.string(from: day).uppercased()
        }
    }

    private func lastNMonthsLabels(n: Int) -> [String] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        // Generate labels for last N months
        return (0..<n).map { i in
            let month = calendar.date(byAdding: .month, value: -(n - 1 - i), to: today) ?? today
            return formatter.string(from: month)
        }
    }
}
