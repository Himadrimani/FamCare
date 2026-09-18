//
//  FamilyActivityScoreCollectionViewCell.swift
//  HomeScreen
//
//  Created by Himadri on 01/02/26.
//
import UIKit
import SpriteKit

// FLOW OF THIS CELL
// Home View Controller sends family members data to this cell
// Cell calculates wellness score for each member
// Rings are drawn using CAShapeLayer based on scores
// Avatars are placed on rings and can be tapped
// Delegate notifies controller when a member is tapped

protocol FamilyMemberTapDelegate: AnyObject {
    func didTapMember(_ profile: Profile)
}

class FamilyActivityScoreCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var infoButton: UIButton!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var ringsContainer: UIView!
    weak var delegate: FamilyMemberTapDelegate?
    private var membersData: [Profile] = []
    private var progressLayers: [CAShapeLayer] = []
    
    //constants for ring
    private let ringWidth: CGFloat = 28
    private let ringGap: CGFloat = 5
    private let avatarSize: CGFloat = 45
    private let startingRadiusMultiplier: CGFloat = 0.42
    private let minimumRadius: CGFloat = 15
    private let cornerRadius: CGFloat = 32
    private let avatarBorderWidth: CGFloat = 2
    private let trackAlpha: CGFloat = 0.15

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    @IBAction func infoTapped(_ sender: UIButton) {
        showLegendOverlay(from: sender)
    }

    private func showLegendOverlay(from source: UIView) {
        // Using a small custom view for the legend to control width precisely
        let legendVC = LegendViewController()
        legendVC.modalPresentationStyle = .popover
        legendVC.preferredContentSize = CGSize(width: 140, height: 160)
        
        if let popover = legendVC.popoverPresentationController {
            popover.sourceView = source
            popover.sourceRect = source.bounds
            popover.permittedArrowDirections = .any
            popover.delegate = legendVC // To force popover style on iPhone
            popover.backgroundColor = .systemBackground
        }
        
        if let vc = self.parentViewController {
            vc.present(legendVC, animated: true)
        }
    }

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = cornerRadius
        
        ringsContainer.isUserInteractionEnabled = true
        let containerTap = UITapGestureRecognizer(target: self, action: #selector(containerTapped(_:)))
        ringsContainer.addGestureRecognizer(containerTap)
    }

    func configure(members: [Profile], for date: Date = Date()) {
        // Main entry point to populate cell
        guard ringsContainer != nil else { return }
        membersData = members
        // Stores data for tap use
        ringsContainer.subviews.forEach { $0.removeFromSuperview() }
        // Removes old avatar views
        ringsContainer.layer.sublayers?.forEach {
            $0.removeFromSuperlayer()
        }
        // Removes old ring layers
        progressLayers.removeAll()
        layoutIfNeeded()
        // Ensures container size is ready $0 represent current item in the loop
        let scoredMembers = members.map {
            ($0, $0.calculateWellnessScore(for: date))
        }
        // Pairs each member with score
        let sorted = scoredMembers.sorted { $0.1 > $1.1 }
        // Sorts highest score first
        var colorMap: [UUID: UIColor] = [:]
        // Stores ranking color per member
        for (_, item) in sorted.enumerated() {
            let score = item.1  // score is 0.0 to 1.0
            let percent = Int(score * 100)
            
            let color: UIColor
            switch percent {
            case 75...100: color = .systemGreen   // High
            case 50..<75:  color = .systemYellow
            case 25..<50:  color = .systemOrange
            default:       color = .systemRed     // Low
            }

            colorMap[item.0.profileId] = color
        }

        let center = CGPoint(
            x: ringsContainer.bounds.midX,
            y: ringsContainer.bounds.midY
        )
        // Center point for rings
        var currentRadius =
            ringsContainer.bounds.width * startingRadiusMultiplier
        // Starting radius
        for (index, member) in members.enumerated() {

            if currentRadius < minimumRadius { currentRadius = minimumRadius }
            // Ensure rings don't disappear
            let progress = member.calculateWellnessScore(for: date)
            // Member score (0–1)
            let ringColor =
                colorMap[member.profileId] ?? .systemGray
            let startAngle = -CGFloat.pi / 2
            // Top starting point
            let endAngle =
                startAngle + (2 * .pi * progress)

            let path = UIBezierPath(
                arcCenter: center,
                radius: currentRadius,
                startAngle: startAngle,
                endAngle: startAngle + 2 * .pi,
                clockwise: true
            )
            // Full circular path
            let track = CAShapeLayer()
            // Background ring
            track.path = path.cgPath
            track.strokeColor =
                ringColor.withAlphaComponent(trackAlpha).cgColor
            track.lineWidth = ringWidth
            track.lineCap = .round
            track.fillColor = UIColor.clear.cgColor

            ringsContainer.layer.addSublayer(track)

            let progressPath = UIBezierPath(
                arcCenter: center,
                radius: currentRadius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: true
            )
            
            let progressLayer = CAShapeLayer()
            // Foreground progress arc
            progressLayer.path = progressPath.cgPath
            progressLayer.strokeColor =
                ringColor.cgColor
            progressLayer.lineWidth = ringWidth
            progressLayer.lineCap = .round
            progressLayer.fillColor =
                UIColor.clear.cgColor
            progressLayer.strokeEnd = 1.0 // Fully fill the arc path
            
            // Set up shadow for glow effect (contained precisely to the ring stroke)
            progressLayer.shadowColor = ringColor.cgColor
            // This creates a shadow path that matches the actual filled area of the stroke
            progressLayer.shadowPath = progressPath.cgPath.copy(strokingWithWidth: ringWidth, lineCap: .round, lineJoin: .round, miterLimit: 10)
            progressLayer.shadowOffset = .zero
            progressLayer.shadowRadius = 0
            progressLayer.shadowOpacity = 0

            ringsContainer.layer.addSublayer(progressLayer)
            progressLayers.append(progressLayer)

            let avatarCenter = CGPoint(
                x: center.x +
                    currentRadius * cos(endAngle),
                y: center.y +
                    currentRadius * sin(endAngle)
            )
            // Position of avatar
            let imageView = UIImageView(
                frame: CGRect(
                    x: 0,
                    y: 0,
                    width: avatarSize,
                    height: avatarSize
                )
            )
            ImageManager.shared.setImage(for: imageView, from: member.profilePic)
            imageView.contentMode = .scaleAspectFill
            imageView.layer.cornerRadius =
                avatarSize / 2
            imageView.layer.borderWidth = avatarBorderWidth
            imageView.layer.borderColor =
                UIColor.white.cgColor
            imageView.clipsToBounds = true
            imageView.center = avatarCenter
            imageView.tag = index
            imageView.isUserInteractionEnabled = true
            // Check for abnormal vitals to apply a red glow boldly
            if member.getAbnormalVital(on: Date()) != nil {
                let shadowView = UIView(frame: CGRect(x: 0, y: 0, width: avatarSize, height: avatarSize))
                shadowView.center = avatarCenter
                shadowView.backgroundColor = .clear
                shadowView.layer.shadowColor = UIColor.systemRed.cgColor
                shadowView.layer.shadowRadius = 16 // Glow boldly
                shadowView.layer.shadowOpacity = 1.0
                shadowView.layer.shadowOffset = .zero
                shadowView.layer.masksToBounds = false
                shadowView.layer.shadowPath = UIBezierPath(ovalIn: shadowView.bounds).cgPath
                ringsContainer.addSubview(shadowView)
            }


            let tap = UITapGestureRecognizer(
                target: self,
                action: #selector(avatarTapped(_:))
            )
            // Tap recognizer
            imageView.addGestureRecognizer(tap)

            ringsContainer.addSubview(imageView)
            // Adds avatar to view

            currentRadius -=
                (ringWidth + ringGap)
            // Moves inward for next ring
        }

        containerView.bringSubviewToFront(infoButton)
        // Keeps info button visible
    }

    @objc private func containerTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: ringsContainer)
        let center = CGPoint(x: ringsContainer.bounds.midX, y: ringsContainer.bounds.midY)
        
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx*dx + dy*dy)
        
        // Find which ring was tapped based on distance from center
        var targetRadius = ringsContainer.bounds.width * startingRadiusMultiplier
        let tolerance = ringWidth / 2 + 10 // Wide enough hit area
        
        for index in 0..<membersData.count {
            if abs(distance - targetRadius) <= tolerance {
                // Ring match! Trigger only a hint (no modal)
                triggerRingTap(at: index, isFullAction: false)
                return
            }
            targetRadius -= (ringWidth + ringGap)
        }
    }

    @objc private func avatarTapped(
        _ gesture: UITapGestureRecognizer
    ) {
        guard let imageView = gesture.view as? UIImageView else { return }
        // Avatar match! Trigger full action (with modal)
        triggerRingTap(at: imageView.tag, isFullAction: true)
    }
    
    private func triggerRingTap(at index: Int, isFullAction: Bool) {
        guard index < membersData.count, index < progressLayers.count else { return }
        
        let member = membersData[index]
        let layer = progressLayers[index]
        
        // Find the corresponding avatar view
        let avatarView = ringsContainer.subviews.compactMap { $0 as? UIImageView }.first { $0.tag == index }
        
        // Only open modal if it's a full action (tap on avatar)
        if isFullAction {
            delegate?.didTapMember(member)
        }
        
        // Perform Tap Animation (slight popup for hint, bigger for action)
        performInteractiveAnimation(for: layer, imageView: avatarView, isFullAction: isFullAction)
        
        // Sprinkle some SpriteKit magic only for full action or a lighter one for hint
        if let avatar = avatarView {
            addParticleBurst(at: avatar.center, 
                             color: (member.calculateWellnessScore(for: Date()) > 0.5 ? .systemGreen : .systemOrange),
                             intensityMultiplier: isFullAction ? 1.0 : 0.4)
        }
    }
    
    private func addParticleBurst(at point: CGPoint, color: UIColor, intensityMultiplier: CGFloat) {
        // Create an SKView for the burst
        let skView = SKView(frame: ringsContainer.bounds)
        skView.backgroundColor = .clear
        skView.isUserInteractionEnabled = false
        ringsContainer.addSubview(skView)
        
        let scene = SKScene(size: ringsContainer.bounds.size)
        scene.backgroundColor = .clear
        skView.presentScene(scene)
        
        // Basic particle burst
        let emitter = SKEmitterNode()
        emitter.particleTexture = SKTexture(image: UIImage(systemName: "sparkle") ?? UIImage())
        emitter.particleBirthRate = 500 * intensityMultiplier
        emitter.numParticlesToEmit = Int(30 * intensityMultiplier)
        emitter.particleLifetime = 0.6
        emitter.particlePositionRange = CGVector(dx: 10, dy: 10)
        emitter.particleSpeed = 80
        emitter.particleSpeedRange = 40
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 0.8
        emitter.particleAlphaSpeed = -1.0
        emitter.particleScale = 0.1
        emitter.particleScaleRange = 0.1
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1.0
        
        emitter.position = point
        scene.addChild(emitter)
        
        // Clean up
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            skView.removeFromSuperview()
        }
    }
    
    private func performInteractiveAnimation(for layer: CAShapeLayer, imageView: UIImageView?, isFullAction: Bool) {
        // 1. Popup Animation for Avatar
        if let iv = imageView {
            let scale: CGFloat = isFullAction ? 1.3 : 1.15
            UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut], animations: {
                iv.transform = CGAffineTransform(scaleX: scale, y: scale)
            }) { _ in
                UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [], animations: {
                    iv.transform = .identity
                }, completion: nil)
            }
        }
        
        // 2. Glow Animation for the Ring (Precise 1 second duration)
        let glowAnimation = CABasicAnimation(keyPath: "shadowRadius")
        glowAnimation.fromValue = 0
        glowAnimation.toValue = 8 // More concentrated to stay on the ring
        glowAnimation.duration = 0.5
        glowAnimation.autoreverses = true
        glowAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        let opacityAnimation = CABasicAnimation(keyPath: "shadowOpacity")
        opacityAnimation.fromValue = 0
        opacityAnimation.toValue = 0.8
        opacityAnimation.duration = 0.5
        opacityAnimation.autoreverses = true
        opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        layer.add(glowAnimation, forKey: "glow")
        layer.add(opacityAnimation, forKey: "glowOpacity")
        
        // 3. Precise Pulse Animation 
        let pulseAnimation = CABasicAnimation(keyPath: "lineWidth")
        pulseAnimation.fromValue = ringWidth
        pulseAnimation.toValue = ringWidth + 2 // Subtle pulse
        pulseAnimation.duration = 0.2
        pulseAnimation.autoreverses = true
        layer.add(pulseAnimation, forKey: "pulse")
        
        // Haptic feedback for extra premium feel
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

// MARK: - Helper Legend VC
class LegendViewController: UIViewController, UIPopoverPresentationControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        
        // Ranking Section
        let rankingTitle = UILabel()
        rankingTitle.font = .systemFont(ofSize: 12, weight: .bold)
        rankingTitle.textColor = .secondaryLabel
        rankingTitle.text = "COLOR LEGEND"
        stack.addArrangedSubview(rankingTitle)
        
        let items = [
            ("🟢", "High"),
            ("🟡", "Good"),
            ("🟠", "Medium"),
            ("🔴", "Low")
        ]
        
        for (emoji, text) in items {
            let label = UILabel()
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.text = "\(emoji) \(text)"
            stack.addArrangedSubview(label)
        }
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16)
        ])
    }
    
    // Force popover style on iPhone
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}

//parentViewController is used to present the alert from the correct ViewController. Since a UIView cannot present alerts directly, it finds its parent ViewController using the responder chain and presents the popup from it.
extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder?.next
            if let vc =
                parentResponder as? UIViewController {
                return vc
            }
        }
        return nil
    }
}
