//
//  AppDelegate.swift
//  HomeScreen
//
//  Created by Himadri  on 30/01/26.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        NetworkMonitor.shared.startMonitoring()
        
        // Setup HealthKit background observers so data syncs while app is inactive
        HealthKitService.shared.setupBackgroundDelivery()
        return true
    }

    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}


extension UICollectionView {
    func setEmptyMessage(_ message: String, iconName: String = "tray") {
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(systemName: iconName)
        iconImageView.tintColor = .tertiaryLabel
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView(arrangedSubviews: [iconImageView, messageLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let emptyView = UIView(frame: CGRect(x: 0, y: 0, width: self.bounds.size.width, height: self.bounds.size.height))
        emptyView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            iconImageView.heightAnchor.constraint(equalToConstant: 60),
            iconImageView.widthAnchor.constraint(equalToConstant: 60),
            stackView.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: emptyView.centerYAnchor, constant: -20),
            stackView.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor, constant: -20)
        ])
        
        self.backgroundView = emptyView
    }
    
    func restore() {
        self.backgroundView = nil
    }
}

extension UIViewController {
    func showLoadingHUD() {
        // Prevent multiple HUDs
        if view.viewWithTag(999) != nil { return }
        
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        overlay.tag = 999
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        let container = UIView()
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = 10
        container.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(container)
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        container.addSubview(activityIndicator)
        
        let label = UILabel()
        label.text = "Loading..."
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            container.widthAnchor.constraint(equalToConstant: 120),
            container.heightAnchor.constraint(equalToConstant: 120),
            
            activityIndicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -10),
            
            label.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 12),
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        ])
        
        view.addSubview(overlay)
    }
    
    func hideLoadingHUD() {
        if let overlay = view.viewWithTag(999) {
            UIView.animate(withDuration: 0.2, animations: {
                overlay.alpha = 0
            }) { _ in
                overlay.removeFromSuperview()
            }
        }
    }
    
    func setupOfflineBannerObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleConnectivityChanged), name: NSNotification.Name("ConnectivityChanged"), object: nil)
        // Check immediately on setup
        if !NetworkMonitor.shared.isConnected {
            showOfflineBanner()
        }
    }
    
    @objc private func handleConnectivityChanged() {
        if NetworkMonitor.shared.isConnected {
            hideOfflineBanner()
        } else {
            showOfflineBanner()
        }
    }
    
    func showOfflineBanner() {
        DispatchQueue.main.async {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) else { return }
            if window.viewWithTag(888) != nil { return }
            
            let bannerHeight: CGFloat = 50
            let topPadding = window.safeAreaInsets.top
            let banner = UIView(frame: CGRect(x: 0, y: -bannerHeight - topPadding, width: window.bounds.width, height: bannerHeight + topPadding))
            banner.backgroundColor = .systemRed
            banner.tag = 888
            
            let label = UILabel()
            label.text = "No Internet Connection - Using Offline Cache"
            label.textColor = .white
            label.font = .systemFont(ofSize: 14, weight: .semibold)
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            
            banner.addSubview(label)
            NSLayoutConstraint.activate([
                label.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -10),
                label.centerXAnchor.constraint(equalTo: banner.centerXAnchor)
            ])
            
            window.addSubview(banner)
            
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
                banner.frame.origin.y = 0
            }, completion: nil)
        }
    }
    
    func hideOfflineBanner() {
        DispatchQueue.main.async {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }),
                  let banner = window.viewWithTag(888) else { return }
            
            UIView.animate(withDuration: 0.3, animations: {
                banner.frame.origin.y = -banner.frame.height
            }) { _ in
                banner.removeFromSuperview()
            }
        }
    }
}

extension UIView {
    private struct AssociatedKeys {
        static var skeletonLayer = "skeletonLayer"
    }
    
    private var skeletonLayer: CAGradientLayer? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.skeletonLayer) as? CAGradientLayer
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.skeletonLayer, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func showSkeleton() {
        if skeletonLayer != nil { return } // Already showing
        
        self.layoutIfNeeded()
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = self.bounds
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        
        let lightColor = UIColor.systemGray5.cgColor
        let darkColor = UIColor.systemGray4.cgColor
        
        gradientLayer.colors = [lightColor, darkColor, lightColor]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-1.0, -0.5, 0.0]
        animation.toValue = [1.0, 1.5, 2.0]
        animation.duration = 1.2
        animation.repeatCount = .infinity
        
        gradientLayer.add(animation, forKey: "skeletonAnimation")
        
        self.layer.addSublayer(gradientLayer)
        self.skeletonLayer = gradientLayer
        
        // Hide subviews temporarily while skeleton is shown
        for subview in self.subviews {
            subview.alpha = 0
        }
    }
    
    func hideSkeleton() {
        skeletonLayer?.removeFromSuperlayer()
        skeletonLayer = nil
        
        UIView.animate(withDuration: 0.3) {
            for subview in self.subviews {
                subview.alpha = 1.0
            }
        }
    }
}

import Network

class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")

    private(set) var isConnected: Bool = true {
        didSet {
            if oldValue != isConnected {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("ConnectivityChanged"), object: nil)
                }
            }
        }
    }

    private init() {}

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
        }
        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        monitor.cancel()
    }
}
