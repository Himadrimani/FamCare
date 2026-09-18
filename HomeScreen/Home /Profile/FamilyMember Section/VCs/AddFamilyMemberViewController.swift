//
//  AddFamilyMemberViewController.swift
//  HealthSharing
//
//  Created by Mohd Kushaad on 02/02/26.
//

import UIKit

class AddFamilyMemberViewController: UIViewController {

    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var codeContainerView: UIView!
    @IBOutlet weak var codeLabel: UILabel!
    @IBOutlet weak var shareButton: UIButton!

    var profile: Profile?

    private var referralCode: String {
        let activeProfile = profile ?? DataManager.shared.currentUser
        guard let p = activeProfile else { return "INVITE" }
        if p.profileId == DataManager.shared.currentUser?.profileId {
            return DataManager.shared.family?.sharableCode ?? "INVITE"
        }
        return SQLiteHelper.shared.fetchFamilies().first(where: { $0.familyId == p.familyId })?.sharableCode ?? "INVITE"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBackgroundGradient()
        applyPremiumStyling()
        setupCodeData()
        setupInteractions()
        applyEntranceAnimations()
    }

    // MARK: - Setup UI & Styling

    private func setupBackgroundGradient() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = view.bounds
        
        let startColor = UIColor(red: 242/255, green: 247/255, blue: 255/255, alpha: 1).cgColor
        let endColor = UIColor.systemBackground.cgColor
        
        gradientLayer.colors = [startColor, endColor]
        gradientLayer.locations = [0.0, 1.0]
        
        // Insert gradient layer at index 0 as background
        view.layer.insertSublayer(gradientLayer, at: 0)
    }

    private func applyPremiumStyling() {
        // Style Description
        descriptionLabel.font = .systemFont(ofSize: 15, weight: .regular)
        descriptionLabel.textColor = .secondaryLabel
        
        // Code container view: dynamic size & glassmorphism/elevated card style
        codeContainerView.translatesAutoresizingMaskIntoConstraints = false
        codeContainerView.backgroundColor = .secondarySystemGroupedBackground
        codeContainerView.layer.cornerRadius = 16
        codeContainerView.layer.borderWidth = 1.0
        codeContainerView.layer.borderColor = UIColor.separator.cgColor
        
        // Gentle card shadow
        codeContainerView.layer.shadowColor = UIColor.black.cgColor
        codeContainerView.layer.shadowOffset = CGSize(width: 0, height: 6)
        codeContainerView.layer.shadowOpacity = 0.06
        codeContainerView.layer.shadowRadius = 12
        
        // Activate container height constraint
        codeContainerView.heightAnchor.constraint(equalToConstant: 74).isActive = true
        
        // Code Label styling inside container
        codeLabel.font = .monospacedSystemFont(ofSize: 24, weight: .bold)
        codeLabel.textColor = .label
        codeLabel.textAlignment = .center
        codeLabel.letterSpacing = 1.5 // Custom spacing helper
        
        codeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            codeLabel.centerXAnchor.constraint(equalTo: codeContainerView.centerXAnchor),
            codeLabel.centerYAnchor.constraint(equalTo: codeContainerView.centerYAnchor)
        ])
        
        // Share Button: Custom wide brand capsule button
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Remove conflicting storyboard leading/trailing constraints
        for constraint in view.constraints {
            if let firstItem = constraint.firstItem as? UIButton, firstItem === shareButton {
                if constraint.firstAttribute == .leading || constraint.firstAttribute == .trailing {
                    constraint.isActive = false
                }
            }
            if let secondItem = constraint.secondItem as? UIButton, secondItem === shareButton {
                if constraint.secondAttribute == .leading || constraint.secondAttribute == .trailing {
                    constraint.isActive = false
                }
            }
        }
        
        NSLayoutConstraint.activate([
            shareButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shareButton.widthAnchor.constraint(equalToConstant: 240),
            shareButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        shareButton.setTitle("  Share Invite Code", for: .normal)
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        shareButton.tintColor = .white
        shareButton.backgroundColor = .systemIndigo
        shareButton.layer.cornerRadius = 25
        shareButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        
        // Button shadow for modern floating look
        shareButton.layer.shadowColor = UIColor.systemIndigo.cgColor
        shareButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        shareButton.layer.shadowOpacity = 0.3
        shareButton.layer.shadowRadius = 8
    }

    private func setupCodeData() {
        codeLabel.text = referralCode
    }

    private func setupInteractions() {
        // 1. Copy-on-Tap gesture on Code card
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(copyCodeTapped))
        codeContainerView.addGestureRecognizer(tapGesture)
        codeContainerView.isUserInteractionEnabled = true
        
        // 2. Share Button Action
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc private func copyCodeTapped() {
        UIPasteboard.general.string = referralCode
        
        // Trigger haptic tap
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.prepare()
        haptic.impactOccurred()
        
        // Soft button tap bounce micro-animation
        UIView.animate(withDuration: 0.1, animations: {
            self.codeContainerView.transform = CGAffineTransform.identity.scaledBy(x: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.codeContainerView.transform = .identity
            }
        }
        
        // Display premium brief HUD alert
        showCopiedToast()
    }

    @objc private func shareButtonTapped() {
        let code = referralCode
        let shareText = "Hey! Join my family health sharing group on HealthSharing using my family invite code: \(code) 💞"
        
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        // iPad Popover adaptation
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        
        present(activityVC, animated: true, completion: nil)
    }

    // MARK: - Animations & Toast HUD

    private func applyEntranceAnimations() {
        // Hide card and button initially for a clean fade-in entry
        codeContainerView.alpha = 0
        codeContainerView.transform = CGAffineTransform(translationX: 0, y: 20)
        
        shareButton.alpha = 0
        shareButton.transform = CGAffineTransform(translationX: 0, y: 20)
        
        UIView.animate(withDuration: 0.8, delay: 0.2, options: .curveEaseOut, animations: {
            self.codeContainerView.alpha = 1
            self.codeContainerView.transform = .identity
        }, completion: nil)
        
        UIView.animate(withDuration: 0.8, delay: 0.35, options: .curveEaseOut, animations: {
            self.shareButton.alpha = 1
            self.shareButton.transform = .identity
        }, completion: nil)
    }

    private func showCopiedToast() {
        let toastView = UIView()
        toastView.backgroundColor = UIColor.label.withAlphaComponent(0.85)
        toastView.layer.cornerRadius = 20
        toastView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = "Invite code copied to clipboard! 📋"
        label.textColor = .systemBackground
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        toastView.addSubview(label)
        view.addSubview(toastView)
        
        NSLayoutConstraint.activate([
            toastView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            toastView.heightAnchor.constraint(equalToConstant: 40),
            
            label.leadingAnchor.constraint(equalTo: toastView.leadingAnchor, constant: 18),
            label.trailingAnchor.constraint(equalTo: toastView.trailingAnchor, constant: -18),
            label.centerYAnchor.constraint(equalTo: toastView.centerYAnchor)
        ])
        
        // Animate Toast
        toastView.alpha = 0
        toastView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut, animations: {
            toastView.alpha = 1
            toastView.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.35, delay: 1.5, options: .curveEaseIn, animations: {
                toastView.alpha = 0
                toastView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            }) { _ in
                toastView.removeFromSuperview()
            }
        }
    }
}

// MARK: - Typography Spacing Extension

private extension UILabel {
    var letterSpacing: CGFloat {
        get { return 0 }
        set {
            guard let text = self.text else { return }
            let attributedString = NSMutableAttributedString(string: text)
            attributedString.addAttribute(.kern, value: newValue, range: NSRange(location: 0, length: attributedString.length))
            self.attributedText = attributedString
        }
    }
}
