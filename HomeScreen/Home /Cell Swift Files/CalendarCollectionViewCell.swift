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
    
    private let activityDotView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.35, green: 0.65, blue: 0.95, alpha: 1)
        v.layer.cornerRadius = 2.5
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private static let dayFormatterLock = NSLock()
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        f.locale = Locale.current
        f.calendar = Calendar.current
        return f
    }()

    private static func formatDayName(_ date: Date) -> String {
        dayFormatterLock.lock()
        defer { dayFormatterLock.unlock() }
        return dayFormatter.string(from: date)
    }

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
        
        contentView.addSubview(activityDotView)
        NSLayoutConstraint.activate([
            activityDotView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            activityDotView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            activityDotView.widthAnchor.constraint(equalToConstant: 5),
            activityDotView.heightAnchor.constraint(equalToConstant: 5)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Ensure perfect circle
        let size = min(selectionBackgroundView.bounds.width,
                       selectionBackgroundView.bounds.height)

        selectionBackgroundView.layer.cornerRadius = size / 2
    }

    func configure(with date: Date, isSelected: Bool, isToday: Bool, hasActivity: Bool = false) {
        let calendar = Calendar.current
        
        activityDotView.isHidden = !hasActivity

        let isFuture = date > calendar.startOfDay(for: Date()) &&
                       !calendar.isDateInToday(date)

        // Day name (small letters for aesthetic)
        dayNameLabel.text = Self.formatDayName(date).uppercased()

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
