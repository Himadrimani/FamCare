//
//  CircularRingView.swift
//  HomeScreen
//
//  Created by GEU on 09/02/26.
//

import UIKit

class CircularRingView: UIView {
    private let iconView = UIImageView()
    private let backgroundLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let solidLayer = CAShapeLayer() // New: for solid fill mode (heart rate)

    var lineWidth: CGFloat = 6 {
        didSet {
            backgroundLayer.lineWidth = lineWidth
            progressLayer.lineWidth = lineWidth
            setNeedsLayout()
        }
    }
    
    var showIcon: Bool = true {
        didSet {
            iconView.isHidden = !showIcon
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {

        backgroundColor = .clear

        // Background track
        backgroundLayer.strokeColor = UIColor.systemGray5.cgColor
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.lineWidth = lineWidth
        layer.addSublayer(backgroundLayer)

        // Solid fill circle (hidden by default, used for heart rate)
        solidLayer.fillColor = UIColor.clear.cgColor
        solidLayer.strokeColor = UIColor.clear.cgColor
        solidLayer.isHidden = true
        layer.addSublayer(solidLayer)

        // Progress ring
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.lineWidth = lineWidth
        progressLayer.strokeEnd = 0
        progressLayer.lineCap = .round
        layer.addSublayer(progressLayer)

        // Icon
        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 8

        let path = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: 1.5 * .pi,
            clockwise: true
        )

        backgroundLayer.path = path.cgPath
        progressLayer.path = path.cgPath

        // Solid circle radius matches OUTER edge of the ring stroke
        // so it appears exactly the same size as other rings
        let solidRadius = radius + lineWidth / 2
        let solidPath = UIBezierPath(
            arcCenter: center,
            radius: solidRadius,
            startAngle: 0,
            endAngle: 2 * .pi,
            clockwise: true
        )
        solidLayer.path = solidPath.cgPath

        // smaller icon (Apple style)
        let iconInset = bounds.width * 0.25
        iconView.frame = bounds.insetBy(dx: iconInset, dy: iconInset)
        
        // Recalculate stroke end if bounds changed
        let circumference = 2 * .pi * radius
        let capPercentage = circumference > 0 ? (lineWidth / circumference) : 0
        
        if currentProgress < 1.0 {
            progressLayer.strokeEnd = max(0, currentProgress - capPercentage)
        } else {
            progressLayer.strokeEnd = 1.0
        }
    }

    private var currentProgress: CGFloat = 0

    func setProgress(_ value: CGFloat, color: UIColor) {
        // Make sure solid mode is off when using progress ring
        solidLayer.isHidden = true
        backgroundLayer.isHidden = false
        progressLayer.isHidden = false

        let clamped = max(0, min(value, 1))
        self.currentProgress = clamped
        
        let w = bounds.width > 0 ? bounds.width : 90
        let h = bounds.height > 0 ? bounds.height : 90
        let radius = min(w, h) / 2 - 8
        let circumference = 2 * .pi * radius
        let capPercentage = circumference > 0 ? (lineWidth / circumference) : 0
        
        let adjustedEnd: CGFloat
        if clamped == 1.0 {
            adjustedEnd = 1.0
        } else {
            adjustedEnd = max(0, clamped - capPercentage)
        }

        progressLayer.strokeColor = color.cgColor
        progressLayer.strokeEnd = adjustedEnd

        // icon matches ring color
        iconView.tintColor = color

        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0
        animation.toValue = adjustedEnd
        animation.duration = 0.8
        progressLayer.add(animation, forKey: "progress")
    }

    // Solid filled circle with white icon — used for heart rate
    func setSolid(color: UIColor, icon: String) {
        // Hide the ring track and progress arc
        backgroundLayer.isHidden = true
        progressLayer.isHidden = true

        // Show solid filled circle — sized to match other rings
        solidLayer.isHidden = false
        solidLayer.fillColor = color.cgColor
        solidLayer.strokeColor = UIColor.clear.cgColor

        // White icon stands out on solid background
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = .white
    }

    func setIcon(_ name: String) {
        iconView.image = UIImage(systemName: name)
    }
}
