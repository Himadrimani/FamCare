//
//  SceneDelegate.swift
//  HomeScreen
//
//  Created by Himadri  on 30/01/26.
//

import UIKit
import Supabase

class SceneDelegate: UIResponder, UIWindowSceneDelegate, UITabBarControllerDelegate {

    var window: UIWindow?
    private var globalAssistantButton: UIButton?

    /// Long-lived subscription to Supabase auth-state changes (token refresh, sign-out,
    /// password recovery). Cancelled when the scene disconnects.
    private var authObserverTask: Task<Void, Never>?
    /// Guards against presenting the "Set New Password" screen more than once (the deep link
    /// and the PASSWORD_RECOVERY auth event can both fire for a single recovery).
    private var isPresentingRecovery = false


    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        
        guard let windowScene = scene as? UIWindowScene else { return }
        
        window = UIWindow(windowScene: windowScene)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleUserDidLogOut), name: NSNotification.Name("UserDidLogOut"), object: nil)

        // Keep the UI in sync with the REAL Supabase session for the whole scene lifetime.
        startAuthStateObserver()

        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            showOnboarding()
        } else {
            // Show a neutral splash, then decide login vs. main from the real Supabase
            // session (source of truth) rather than a local flag.
            showLaunchLoading()
            Task { @MainActor in
                await self.routeFromRealSession()
            }
        }
        window?.makeKeyAndVisible()

        // Handle a password-reset deep link that launched the app (cold start).
        if let urlContext = connectionOptions.urlContexts.first {
            handleIncomingURL(urlContext.url)
        }
    }

    // MARK: - Session-driven launch routing

    /// Routes to the main interface only when there is a valid Supabase session AND a local
    /// identity. Otherwise drops to authentication. Offline users keep access while their stored
    /// token is still valid; an expired/invalid session cleanly returns to login.
    @MainActor
    private func routeFromRealSession() async {
        let hasSession = await DataManager.shared.hasValidSession()
        let hasLocalIdentity = UserDefaults.standard.string(forKey: "DataManagerCurrentUserId") != nil

        if hasSession && hasLocalIdentity {
            showMainInterface(animated: true)
            globalAssistantButton?.isHidden = false
        } else {
            if !hasSession {
                // No valid session: don't let a stale local flag imply "logged in".
                // Clears only the active-user pointer (keeps offline caches intact).
                DataManager.shared.clearActiveUserForInvalidSession()
            }
            showAuthentication()
            globalAssistantButton?.isHidden = true
        }
    }

    private func showLaunchLoading() {
        let loadingVC = UIViewController()
        loadingVC.view.backgroundColor = .systemBackground
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        loadingVC.view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: loadingVC.view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: loadingVC.view.centerYAnchor)
        ])
        window?.rootViewController = loadingVC
    }

    // MARK: - Supabase auth-state observer

    private func startAuthStateObserver() {
        authObserverTask?.cancel()
        authObserverTask = Task { [weak self] in
            for await change in SupabaseManager.shared.client.auth.authStateChanges {
                await MainActor.run {
                    self?.handleAuthStateChange(event: change.event)
                }
            }
        }
    }

    @MainActor
    private func handleAuthStateChange(event: AuthChangeEvent) {
        switch event {
        case .passwordRecovery:
            // A recovery session is now active — take the user straight to set a new password.
            presentSetNewPassword()
        case .signedOut:
            // Catches server-side session loss while the app is open — a failed token refresh,
            // or the account being deleted/disabled/revoked elsewhere — not just an explicit
            // in-app logout. Explicit logout already routes via UserDidLogOut, and password
            // recovery signs out intentionally, so skip those to avoid a redundant swap.
            guard !isPresentingRecovery, !isShowingAuthentication else { break }
            DataManager.shared.clearActiveUserForInvalidSession()
            showAuthentication()
        case .signedIn, .tokenRefreshed, .initialSession, .userUpdated:
            // Refresh/sign-in need no routing.
            break
        default:
            break
        }
    }

    /// Whether the login/authentication screen is already the current root, used to avoid
    /// redundant re-routing when several sign-out signals arrive together.
    @MainActor
    private var isShowingAuthentication: Bool {
        guard let nav = window?.rootViewController as? UINavigationController else { return false }
        return nav.viewControllers.first is LoginSignupViewController
    }

    // Handle a deep link while the app is already running / backgrounded.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let urlContext = URLContexts.first {
            handleIncomingURL(urlContext.url)
        }
    }

    // MARK: - Password reset deep link

    private func handleIncomingURL(_ url: URL) {
        // Only handle our auth callback scheme (e.g. homescreenapp://reset-password).
        guard url.scheme?.lowercased() == "homescreenapp" else { return }

        Task { @MainActor in
            do {
                try await DataManager.shared.completeRecovery(from: url)
                self.presentSetNewPassword()
            } catch {
                self.presentRecoveryError()
            }
        }
    }

    @MainActor
    private func presentSetNewPassword() {
        // Only valid inside a real recovery session established from the deep link.
        guard DataManager.shared.hasRecoverySession() else { return }
        // Prevent double-presentation (deep link + PASSWORD_RECOVERY event both fire).
        guard !isPresentingRecovery else { return }
        if topViewController() is SetNewPasswordViewController { return }
        if let nav = topViewController() as? UINavigationController,
           nav.viewControllers.first is SetNewPasswordViewController { return }

        isPresentingRecovery = true
        let setPasswordVC = SetNewPasswordViewController()
        setPasswordVC.onPasswordReset = { [weak self] in
            self?.isPresentingRecovery = false
            self?.dismissTopAndShowLogin()
        }
        let nav = UINavigationController(rootViewController: setPasswordVC)
        nav.modalPresentationStyle = .fullScreen
        topViewController()?.present(nav, animated: true)
    }

    @MainActor
    private func presentRecoveryError() {
        let alert = UIAlertController(
            title: "Reset Link Problem",
            message: "This password reset link is invalid or has expired. Please request a new one from the Forgot Password screen.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        topViewController()?.present(alert, animated: true)
    }

    @MainActor
    private func dismissTopAndShowLogin() {
        let finish: () -> Void = { [weak self] in
            guard let self else { return }
            self.showAuthentication()
        }
        if let presented = window?.rootViewController?.presentedViewController {
            presented.dismiss(animated: true, completion: finish)
        } else {
            finish()
        }
    }

    @MainActor
    private func topViewController() -> UIViewController? {
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    @objc private func handleUserDidLogOut() {
        showAuthentication()
    }

    private func showOnboarding() {
        let onboardingVC = OnboardingViewController()
        onboardingVC.onCompletion = { [weak self] in
            self?.showAuthentication()
        }
        window?.rootViewController = onboardingVC
    }

    private func showAuthentication() {
        let authVC = LoginSignupViewController(nibName: "LoginSignupViewController", bundle: nil)
        authVC.onAuthenticationComplete = { [weak self] in
            if DataManager.shared.isCurrentUserHealthKitLinked() {
                self?.showMainInterface(animated: true)
            } else {
                let hkVC = HealthKitOnboardingViewController()
                hkVC.onCompletion = {
                    self?.showMainInterface(animated: true)
                }
                let nav = UINavigationController(rootViewController: hkVC)
                nav.navigationBar.isHidden = true
                
                let installRoot = {
                    self?.window?.rootViewController = nav
                    self?.window?.makeKeyAndVisible()
                }
                if let window = self?.window {
                    UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve, animations: installRoot)
                }
            }
        }

        let navigationController = UINavigationController(rootViewController: authVC)
        navigationController.navigationBar.prefersLargeTitles = false
        window?.rootViewController = navigationController
    }

    private func showMainInterface(animated: Bool) {
        guard let tabBarController = UIStoryboard(name: "Main", bundle: nil)
            .instantiateInitialViewController() as? UITabBarController else {
            return
        }
        tabBarController.delegate = self

        let installRoot = {
            self.window?.rootViewController = tabBarController
            self.window?.makeKeyAndVisible()
            self.setupGlobalAssistantButton()
        }

        if animated, let window {
            UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve, animations: installRoot)
        } else {
            installRoot()
        }

        // Start loading app data only after the UI hierarchy exists.
        DataManager.shared.loadAppData()
        // Legacy loadChallengeLibrary call removed
    }
    
    private func setupGlobalAssistantButton() {
        guard let window = self.window else { return }
        
        globalAssistantButton?.removeFromSuperview()
        
        let assistantButton = UIButton(type: .system)
        assistantButton.setImage(UIImage(systemName: "sparkles"), for: .normal)
        assistantButton.tintColor = .white
        assistantButton.backgroundColor = .systemBlue
        assistantButton.layer.cornerRadius = 28
        assistantButton.layer.shadowColor = UIColor.black.cgColor
        assistantButton.layer.shadowOpacity = 0.3
        assistantButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        assistantButton.layer.shadowRadius = 4
        assistantButton.translatesAutoresizingMaskIntoConstraints = false
        
        window.addSubview(assistantButton)
        
        NSLayoutConstraint.activate([
            assistantButton.widthAnchor.constraint(equalToConstant: 56),
            assistantButton.heightAnchor.constraint(equalToConstant: 56),
            assistantButton.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -90),
            assistantButton.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -24)
        ])
        
        assistantButton.addTarget(self, action: #selector(globalAssistantButtonTapped), for: .touchUpInside)
        self.globalAssistantButton = assistantButton
    }
    
    @objc private func globalAssistantButtonTapped() {
        let assistantVC = AssistantViewController()
        let nav = UINavigationController(rootViewController: assistantVC)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        
        // Find top most view controller
        var topController = window?.rootViewController
        while let presented = topController?.presentedViewController {
            topController = presented
        }
        topController?.present(nav, animated: true)
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        authObserverTask?.cancel()
        authObserverTask = nil
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        DataManager.shared.refreshCurrentUserHealthDataFromHealthKit()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if let nav = viewController as? UINavigationController {
            nav.popToRootViewController(animated: false)
        }
    }
}

// MARK: - Onboarding Implementation (Programmatic to ensure scope visibility)

struct OnboardingSlide {
    let title: String
    let description: String
    let image: UIImage?
}

class OnboardingSlideView: UIView {
    
    private let slideImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let gradientOverlay: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        setupGradient()
    }
    
    private func setupUI() {
        backgroundColor = .systemBackground
        
        addSubview(slideImageView)
        addSubview(gradientOverlay)
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            slideImageView.topAnchor.constraint(equalTo: topAnchor),
            slideImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            slideImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            slideImageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.65),
            
            gradientOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            gradientOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            gradientOverlay.bottomAnchor.constraint(equalTo: slideImageView.bottomAnchor),
            gradientOverlay.heightAnchor.constraint(equalTo: slideImageView.heightAnchor, multiplier: 0.4),
            
            titleLabel.topAnchor.constraint(equalTo: slideImageView.bottomAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 30),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            descriptionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40)
        ])
    }
    
    private func setupGradient() {
        let gradient = CAGradientLayer()
        gradient.frame = gradientOverlay.bounds
        gradient.colors = [
            UIColor.clear.cgColor,
            UIColor.systemBackground.withAlphaComponent(0.5).cgColor,
            UIColor.systemBackground.cgColor
        ]
        gradient.locations = [0, 0.5, 1]
        
        gradientOverlay.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        gradientOverlay.layer.insertSublayer(gradient, at: 0)
    }
    
    func configure(with slide: OnboardingSlide) {
        titleLabel.text = slide.title
        descriptionLabel.text = slide.description
        slideImageView.image = slide.image
    }
}

class OnboardingViewController: UIViewController {
    
    var onCompletion: (() -> Void)?
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.isPagingEnabled = true
        sv.showsHorizontalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let pageControl: UIPageControl = {
        let pc = UIPageControl()
        pc.numberOfPages = 2
        pc.currentPageIndicatorTintColor = .systemBlue
        pc.pageIndicatorTintColor = .systemGray4
        pc.translatesAutoresizingMaskIntoConstraints = false
        return pc
    }()
    
    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Next", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var slides: [OnboardingSlide] = [
        OnboardingSlide(
            title: "Stay Close, Stay Informed",
            description: "See your family's health at a glance. Know they're okay, even from a distance.",
            image: UIImage(named: "onboarding_connection")
        ),
        OnboardingSlide(
            title: "Grow Together",
            description: "Take on daily challenges as a family. Every small win counts for everyone.",
            image: UIImage(named: "onboarding_challenges")
        )
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSlides()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(scrollView)
        view.addSubview(pageControl)
        view.addSubview(actionButton)
        
        scrollView.delegate = self
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -20),
            
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: actionButton.topAnchor, constant: -20),
            
            actionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            actionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            actionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            actionButton.heightAnchor.constraint(equalToConstant: 55)
        ])
        
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
    }
    
    private func setupSlides() {
        for i in 0..<slides.count {
            let slideView = OnboardingSlideView()
            slideView.configure(with: slides[i])
            slideView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.addSubview(slideView)
            
            NSLayoutConstraint.activate([
                slideView.topAnchor.constraint(equalTo: scrollView.topAnchor),
                slideView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                slideView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
                slideView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
                slideView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: CGFloat(i) * view.frame.width)
            ])
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.contentSize = CGSize(width: view.frame.width * CGFloat(slides.count), height: scrollView.frame.height)
        
        // Final frame adjustments for slides
        for (index, subview) in scrollView.subviews.enumerated() {
            if let slide = subview as? OnboardingSlideView {
                slide.frame = CGRect(x: view.frame.width * CGFloat(index), y: 0, width: view.frame.width, height: scrollView.frame.height)
            }
        }
    }
    
    @objc private func actionButtonTapped() {
        let nextPage = pageControl.currentPage + 1
        if nextPage < slides.count {
            let offset = CGPoint(x: CGFloat(nextPage) * view.frame.width, y: 0)
            scrollView.setContentOffset(offset, animated: true)
        } else {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            onCompletion?()
        }
    }
}

extension OnboardingViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let page = Int(round(scrollView.offset.x / view.frame.width))
        pageControl.currentPage = page
        actionButton.setTitle(page == slides.count - 1 ? "Get Started" : "Next", for: .normal)
    }
}

extension UIScrollView {
    var offset: CGPoint { return contentOffset }
}
