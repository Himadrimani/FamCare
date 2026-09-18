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
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        dayLabel.text = formatter.string(from: data.date).uppercased()
        formatter.dateFormat = "d"
        dateLabel.text = formatter.string(from: data.date)

        ringView.setProgress(CGFloat(data.score) / 100.0, color: colorForScore(data.score))

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
