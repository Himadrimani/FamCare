//
//  StatRowCell.swift
//  HomeScreen
//
//  Created by Himadri  on 30/03/26.
//

import UIKit

class StartRowCell: UICollectionViewCell {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var iconContainer: UIView!
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var targetLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!

    override func awakeFromNib() {
        super.awakeFromNib()
        containerView.backgroundColor = .secondarySystemGroupedBackground
        containerView.layer.cornerRadius = 20
        iconContainer.layer.cornerRadius = 9
        iconView.contentMode = .scaleAspectFit
        titleLabel.font      = .systemFont(ofSize: 14, weight: .bold)
        titleLabel.textColor = .secondaryLabel
        valueLabel.font      = .systemFont(ofSize: 22, weight: .bold)
        targetLabel.font     = .systemFont(ofSize: 13, weight: .medium)
        targetLabel.textColor = .tertiaryLabel
        progressView.layer.cornerRadius = 3
        progressView.clipsToBounds = true
    }

    func configure(icon: String, color: UIColor, title: String,
                   value: String, target: String, progress: CGFloat?) {
        iconView.image           = UIImage(systemName: icon)
        iconView.tintColor       = color
        iconContainer.backgroundColor = color.withAlphaComponent(0.15)
        titleLabel.text  = title.uppercased()
        valueLabel.text  = value
        targetLabel.text = target

        if let p = progress {
            progressView.isHidden       = false
            progressView.progress       = Float(p)
            progressView.progressTintColor = color
            progressView.trackTintColor    = color.withAlphaComponent(0.15)
        } else {
            progressView.isHidden = true
        }
    }
}
