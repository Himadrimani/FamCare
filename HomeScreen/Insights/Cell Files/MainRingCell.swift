//
//  MainRingCell.swift
//  HomeScreen
//
//  Created by Himadri  on 30/03/26.
//

import UIKit

class MainRingCell: UICollectionViewCell {

    @IBOutlet weak var ringView: CircularRingView!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        ringView.lineWidth  = 18
        ringView.showIcon   = false
        scoreLabel.font     = .rounded(ofSize: 54, weight: .black)
        scoreLabel.textAlignment = .center
        titleLabel.text      = "WELLNESS SCORE"
        titleLabel.font      = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .secondaryLabel
        dateLabel.font       = .systemFont(ofSize: 15, weight: .bold)
        dateLabel.textColor  = .label
        dateLabel.textAlignment = .center
    }

    func configure(with data: DayData) {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        dateLabel.text  = formatter.string(from: data.date)
        scoreLabel.text = "\(data.score)%"
        scoreLabel.textColor = .label
        ringView.setProgress(CGFloat(data.score) / 100.0, color: colorForScore(data.score))
        ringView.setNeedsLayout()
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
