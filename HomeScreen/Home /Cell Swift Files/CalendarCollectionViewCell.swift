//
//  CalendarCollectionViewCell.swift
//  HomeScreen
//
//  Created by Himadri on 30/01/26.
//


import UIKit

class CalendarCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var selectionBackgroundView: UIView!
    @IBOutlet weak var dayNameLabel: UILabel!
    @IBOutlet weak var dayNumberLabel: UILabel!

    private let primaryBlue = UIColor(red: 0.35, green: 0.65, blue: 0.95, alpha: 1)
    private let lightBlue = UIColor(red: 0.35, green: 0.65, blue: 0.95, alpha: 0.15)

    var isSelectedDay: Bool = false {
        didSet { updateSelectionState() }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    private func setupUI() {
        selectionBackgroundView.clipsToBounds = true

        // Typography (small + clean)
        dayNameLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        dayNumberLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)

        dayNameLabel.textAlignment = .center
        dayNumberLabel.textAlignment = .center
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Ensure perfect circle
        let size = min(selectionBackgroundView.bounds.width,
                       selectionBackgroundView.bounds.height)

        selectionBackgroundView.layer.cornerRadius = size / 2
    }

    func configure(with date: Date, isSelected: Bool, isToday: Bool) {
        let calendar = Calendar.current

        let isFuture = date > calendar.startOfDay(for: Date()) &&
                       !calendar.isDateInToday(date)

        // Day name (small letters for aesthetic)
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        dayNameLabel.text = dayFormatter.string(from: date).uppercased()

        // Day number
        let day = calendar.component(.day, from: date)
        dayNumberLabel.text = "\(day)"

        self.isSelectedDay = isSelected

        // Reset border
        selectionBackgroundView.layer.borderWidth = 0

        if isSelected {
            dayNameLabel.textColor = .white
            dayNumberLabel.textColor = .white

        } else if isToday {
            // Subtle ring for today
            selectionBackgroundView.layer.borderWidth = 1.5
            selectionBackgroundView.layer.borderColor = primaryBlue.cgColor

            dayNameLabel.textColor = primaryBlue
            dayNumberLabel.textColor = primaryBlue

        } else if isFuture {
            dayNameLabel.textColor = UIColor.systemGray3
            dayNumberLabel.textColor = UIColor.systemGray3

        } else {
            dayNameLabel.textColor = UIColor.systemGray
            dayNumberLabel.textColor = UIColor.label
        }
    }

    private func updateSelectionState() {
        if isSelectedDay {
            // Soft blue filled circle
            selectionBackgroundView.backgroundColor = primaryBlue
            selectionBackgroundView.layer.borderWidth = 0

            // Subtle shadow (premium feel)
            selectionBackgroundView.layer.shadowColor = primaryBlue.cgColor
            selectionBackgroundView.layer.shadowOpacity = 0.25
            selectionBackgroundView.layer.shadowOffset = CGSize(width: 0, height: 3)
            selectionBackgroundView.layer.shadowRadius = 6

        } else {
            selectionBackgroundView.backgroundColor = .clear
            selectionBackgroundView.layer.shadowOpacity = 0
        }
    }
}
