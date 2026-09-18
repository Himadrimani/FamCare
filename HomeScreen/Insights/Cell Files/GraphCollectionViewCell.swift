//
//  GraphCollectionViewCell.swift
//  Insight
//
//  Created by Mohd Kushaad on 12/02/26.
//

import UIKit
import DGCharts

protocol GraphCollectionViewCellDelegate: AnyObject {
    func graphCell(_ cell: GraphCollectionViewCell, didDoubleTapBarAt index: Int)
}

class GraphCollectionViewCell: UICollectionViewCell {

    private var barChartView: BarChartView!
    private var days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
    private var storedDays = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
    private var storedDates = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10",
                               "11", "12", "13", "14", "15", "16", "17", "18", "19", "20",
                               "21", "22", "23", "24", "25", "26", "27", "28", "29", "30",
                               "31"]
    var xLabel: [String] = []
    var isWeek: Bool = true
    weak var delegate: GraphCollectionViewCellDelegate?
    
    @IBOutlet weak var graphView: UIView!
    @IBOutlet weak var comparisonLabel: UILabel!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupCardStyle()
        setupBarChart()
    }

    // Color legend (matches wellness ring exactly)
    private func colorForScore(_ score: Int) -> UIColor {
        switch score {
        case 75...100: return .systemGreen
        case 50..<75:  return .systemYellow
        case 25..<50:  return .systemOrange
        case 0..<25:   return .systemRed
        default:       return .clear // for -1
        }
    }

    private func setupCardStyle() {
        self.contentView.layer.cornerRadius = 20
        self.contentView.layer.masksToBounds = true
        self.contentView.backgroundColor = .white

        self.layer.masksToBounds = false
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.08
        self.layer.shadowOffset = CGSize(width: 0, height: 4)
        self.layer.shadowRadius = 12
        self.layer.shadowPath = UIBezierPath(roundedRect: self.bounds, cornerRadius: 20).cgPath
    }
    
    private func setupBarChart() {
        barChartView = BarChartView()
        barChartView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        graphView.addSubview(barChartView)
        
        barChartView.legend.enabled = false
        barChartView.rightAxis.enabled = false
        
        let leftAxis = barChartView.leftAxis
        leftAxis.enabled = true
        leftAxis.drawLabelsEnabled = false
        leftAxis.drawGridLinesEnabled = false
        leftAxis.drawAxisLineEnabled = false
        leftAxis.axisMinimum = 0
        leftAxis.axisMaximum = 105 // Set slightly above 100 to ensure the line is visible and not clipped
        
        let limitLine = ChartLimitLine(limit: 100, label: "")
        limitLine.lineWidth = 1.0
        limitLine.lineColor = UIColor.systemGreen.withAlphaComponent(0.6)
        limitLine.lineDashLengths = [2, 2] // Dotted pattern
        leftAxis.addLimitLine(limitLine)
        
        barChartView.drawGridBackgroundEnabled = false
        barChartView.drawBordersEnabled = false
        
        let xAxis = barChartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.drawGridLinesEnabled = false
        xAxis.drawAxisLineEnabled = false
        xAxis.labelTextColor = .systemGray
        xAxis.labelFont = .systemFont(ofSize: 12, weight: .medium)
        
        // Use custom renderer for rounded corners
        let renderer = RoundedBarChartRenderer(dataProvider: barChartView, animator: barChartView.chartAnimator, viewPortHandler: barChartView.viewPortHandler)
        renderer.radius = 5
        barChartView.renderer = renderer
        
        barChartView.isUserInteractionEnabled = true
        barChartView.highlightPerTapEnabled = true
        barChartView.doubleTapToZoomEnabled = false
        barChartView.pinchZoomEnabled = false
        barChartView.scaleXEnabled = false
        barChartView.scaleYEnabled = false
        barChartView.delegate = self

        // Add Double Tap Gesture
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        barChartView.addGestureRecognizer(doubleTap)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: barChartView)
        if let highlight = barChartView.getHighlightByTouchPoint(location) {
            let index = Int(highlight.x)
            delegate?.graphCell(self, didDoubleTapBarAt: index)
        }
    }

    func configureCell(score: [Int], comparison: String, isWeek: Bool) {
        self.isWeek = isWeek
        if isWeek {
            xLabel = days
        } else {
            xLabel = (1...score.count).map { "\($0)" }
        }
        
        let todayDay = Calendar.current.component(.day, from: Date())
        let todayIndex = isWeek ? (Calendar.current.component(.weekday, from: Date()) - 1) : (todayDay - 1)
        let safeIndex = max(0, min(todayIndex, score.count - 1))
        
        titleLabel.text = "Today's Performance"
        let currentScore = score[safeIndex]
        progressLabel.text = currentScore >= 0 ? "\(currentScore)%" : "--%"

        // Color and Symbol based on score direction (Stock market style)
        // Keep a visible value even when comparison source is temporarily empty.
        let trimmedComparison = comparison.trimmingCharacters(in: .whitespacesAndNewlines)
        let isLower = trimmedComparison.contains("lower") || trimmedComparison.contains("↓")
        let isNeutral = trimmedComparison == "—"
        
        let cleanComparison: String = {
            if trimmedComparison.isEmpty { return "0%" }
            if isNeutral { return "—" }
            let stripped = trimmedComparison
                .replacingOccurrences(of: "↓", with: "")
                .replacingOccurrences(of: "↑", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return stripped.isEmpty ? "0%" : stripped
        }()
        
        let color: UIColor = isNeutral ? .systemGray : (isLower ? .systemRed : .systemGreen)
        comparisonLabel.textColor = color
        
        let attributedString = NSMutableAttributedString()
        
        if isNeutral {
            comparisonLabel.isHidden = true
            attributedString.append(NSAttributedString(string: ""))
        } else {
            comparisonLabel.isHidden = false
            let symbol: String = isLower ? "arrow.down.right" : "arrow.up.right"
            let config = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
            let image = UIImage(systemName: symbol, withConfiguration: config)
            
            let attachment = NSTextAttachment()
            attachment.image = image?.withTintColor(color)
            attachment.bounds = CGRect(x: 0, y: -1, width: 11, height: 11)
            
            attributedString.append(NSAttributedString(attachment: attachment))
            attributedString.append(NSAttributedString(string: " " + cleanComparison, attributes: [.foregroundColor: color]))
        }
        
        comparisonLabel.attributedText = attributedString
        
        let entries = score.enumerated().compactMap { (index, value) -> BarChartDataEntry? in
            guard value >= 0 else { return nil } // Skip future days completely
            return BarChartDataEntry(x: Double(index), y: Double(value))
        }
        
        let dataSet = BarChartDataSet(entries: entries)

        // Each bar gets its own color based on its score value
        dataSet.colors = entries.map { colorForScore(Int($0.y)) }
        dataSet.drawValuesEnabled = false
        
        let data = BarChartData(dataSet: dataSet)
        if isWeek {
            data.barWidth = 0.45
        } else {
            data.barWidth = entries.count <= 1 ? 0.35 : 0.41
        }
        
        barChartView.data = data
        barChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: xLabel)
        barChartView.xAxis.granularity = 1
        if isWeek {
            barChartView.xAxis.axisMinimum = -0.5
            barChartView.xAxis.axisMaximum = 6.5
        } else {
            // Lock month range to full number of days so first-day bar stays on left and thin.
            let monthSlots = max(score.count, 1)
            barChartView.xAxis.axisMinimum = -0.5
            barChartView.xAxis.axisMaximum = Double(monthSlots) - 0.5
        }
        barChartView.animate(yAxisDuration: 1.0, easingOption: .easeOutBack)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        barChartView.frame = graphView.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        barChartView.data = nil
        delegate = nil
    }
}

// MARK: - Custom Renderer for Rounded Bars
class RoundedBarChartRenderer: BarChartRenderer {
    nonisolated(unsafe) var radius: CGFloat = 0
    
    nonisolated override init(dataProvider: BarChartDataProvider, animator: Animator, viewPortHandler: ViewPortHandler) {
        super.init(dataProvider: dataProvider, animator: animator, viewPortHandler: viewPortHandler)
    }
    
    nonisolated override func drawDataSet(context: CGContext, dataSet: BarChartDataSetProtocol, index: Int) {
        guard let dataProvider = dataProvider else { return }
        
        let transformer = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        let phaseY = animator.phaseY
        let barWidth = dataProvider.barData?.barWidth ?? 0.85
        let barWidthHalf = barWidth / 2.0
        
        for i in 0..<dataSet.entryCount {
            guard let entry = dataSet.entryForIndex(i) as? BarChartDataEntry else { continue }
            
            let x = entry.x
            let y = entry.y
            
            let left = x - barWidthHalf
            let right = x + barWidthHalf
            let top = y >= 0 ? y * phaseY : 0
            let bottom = y <= 0 ? y * phaseY : 0
            
            var rect = CGRect(x: left, y: top, width: right - left, height: bottom - top)
            transformer.rectValueToPixel(&rect)
            
            // Limit radius to half of bar width
            let barRadius = min(radius, rect.width / 2.0)
            
            let path = UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: barRadius, height: barRadius))
            
            context.saveGState()
            context.addPath(path.cgPath)
            context.setFillColor(dataSet.color(atIndex: i).cgColor)
            context.fillPath()
            context.restoreGState()
        }
    }
}

// MARK: - ChartViewDelegate
extension GraphCollectionViewCell: ChartViewDelegate {
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        let index = Int(entry.x)
        let score = Int(entry.y)
        
        if isWeek {
            if index < storedDays.count {
                let dayName = storedDays[index]
                titleLabel.text = "\(dayName)'s Performance"
                progressLabel.text = "\(score)%"
            }
        } else {
            // For month view, index is 0...daysInMonth-1
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
            
            if let date = calendar.date(byAdding: .day, value: index, to: monthStart) {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d" // e.g. Apr 14
                let dateStr = formatter.string(from: date)
                titleLabel.text = "\(dateStr)'s Performance"
                progressLabel.text = "\(score)%"
            }
        }
    }
    
    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        titleLabel.text = "Overall Performance"
    }
}
