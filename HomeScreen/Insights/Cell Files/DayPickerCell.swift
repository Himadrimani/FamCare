//
//  DayPickerCell.swift
//  HomeScreen
//
//  Created by Himadri  on 30/03/26.
//



import UIKit

class DayPickerCell: UICollectionViewCell {

    @IBOutlet weak var ringView: CircularRingView!
    @IBOutlet weak var dayLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!

    private static let formatterLock = NSLock()
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        f.locale = Locale.current
        f.calendar = Calendar.current
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        f.locale = Locale.current
        f.calendar = Calendar.current
        return f
    }()

    private static func formatDay(_ date: Date) -> String {
        formatterLock.lock()
        defer { formatterLock.unlock() }
        return dayFormatter.string(from: date)
    }

    private static func formatDate(_ date: Date) -> String {
        formatterLock.lock()
        defer { formatterLock.unlock() }
        return dateFormatter.string(from: date)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        ringView.prepareForReuse()
    }

    // awakeFromNib is called AFTER IBOutlets are connected — safe to configure here
    override func awakeFromNib() {
        super.awakeFromNib()
        ringView.lineWidth = 4
        ringView.showIcon  = false
        dayLabel.font      = .systemFont(ofSize: 10, weight: .bold)
        dayLabel.textColor = .secondaryLabel
        dayLabel.textAlignment = .center
        dateLabel.font     = .systemFont(ofSize: 12, weight: .medium)
        dateLabel.textAlignment = .center
    }

    func configure(with data: DayData, isSelected: Bool) {
        dayLabel.text = Self.formatDay(data.date).uppercased()
        dateLabel.text = Self.formatDate(data.date)

        ringView.setProgress(CGFloat(data.score) / 100.0, color: colorForScore(data.score), animated: false)

        if isSelected {
            dayLabel.textColor  = .systemBlue
            dateLabel.textColor = .label
            dateLabel.font      = .systemFont(ofSize: 13, weight: .bold)
            contentView.alpha   = 1.0
        } else {
            dayLabel.textColor  = .secondaryLabel
            dateLabel.textColor = .secondaryLabel
            dateLabel.font      = .systemFont(ofSize: 12, weight: .medium)
            contentView.alpha   = 0.6
        }

        if Calendar.current.isDateInToday(data.date) {
            dateLabel.textColor = .systemBlue
        }
    }

    private func colorForScore(_ score: Int) -> UIColor {
        switch score {
        case 75...100: return .systemGreen
        case 50..<75:  return .systemYellow
        case 25..<50:  return .systemOrange
        default:       return .systemRed
        }
    }
}
