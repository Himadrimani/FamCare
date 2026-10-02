import UIKit
import AVFoundation

class AssistantViewController: UIViewController {
    
    // MARK: - UI Elements
    private let tableView = UITableView()
    private let inputContainerView = UIView()
    private let textField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let voiceButton = UIButton(type: .system)
    private let suggestionsStack = UIStackView()
    
    // MARK: - Data
    struct DisplayMessage {
        let role: String
        let content: String
        let actionTitle: String?
        let actionURL: URL?
        
        init(role: String, content: String, actionTitle: String? = nil, actionURL: URL? = nil) {
            self.role = role
            self.content = content
            self.actionTitle = actionTitle
            self.actionURL = actionURL
        }
    }
    
    /// Only user + assistant messages (no internal context).
    private var displayMessages: [DisplayMessage] = []
    /// Full conversation sent to the AI (excludes context — that's injected by the service).
    private var conversationHistory: [AIAssistantMessage] = []
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    private var isSending = false
    private var typingIndicatorVisible = false
    
    // MARK: - Suggestion Chips
    private let suggestions = [
        "How is my family doing?",
        "My steps today",
        "Create a step challenge"
    ]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        addGreeting()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleCreateChallengeNotification(_:)), name: .didInvokeCreateChallenge, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleCreateMessageGroupNotification(_:)), name: .didInvokeCreateMessageGroup, object: nil)
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        title = "AI Assistant"
        view.backgroundColor = .systemGroupedBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "checkmark.circle.fill"),
            style: .done,
            target: self,
            action: #selector(dismissTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = .systemBlue
        
        // --- Input Container (Liquid Glass) ---
        inputContainerView.backgroundColor = .clear
        inputContainerView.layer.borderWidth = 0
        inputContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputContainerView)
        
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let effectView = UIVisualEffectView(effect: blurEffect)
        effectView.layer.cornerRadius = 20
        effectView.layer.cornerCurve = .continuous
        effectView.layer.borderWidth = 0.5
        effectView.layer.borderColor = UIColor.separator.withAlphaComponent(0.5).cgColor
        effectView.clipsToBounds = true
        effectView.translatesAutoresizingMaskIntoConstraints = false
        inputContainerView.addSubview(effectView)
        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: inputContainerView.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: inputContainerView.bottomAnchor),
            effectView.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor)
        ])
        
        // Voice button
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "waveform", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular))
        config.baseForegroundColor = .systemBlue
        voiceButton.configuration = config
        voiceButton.accessibilityLabel = "Voice message"
        voiceButton.translatesAutoresizingMaskIntoConstraints = false
        voiceButton.addTarget(self, action: #selector(voiceTapped), for: .touchUpInside)
        inputContainerView.addSubview(voiceButton)
        
        // Text field
        textField.placeholder = "Ask anything..."
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.returnKeyType = .send
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.addTarget(self, action: #selector(textDidChange), for: .editingChanged)
        inputContainerView.addSubview(textField)
        
        // Send button
        let sendConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill", withConfiguration: sendConfig), for: .normal)
        sendButton.tintColor = .systemBlue
        sendButton.accessibilityLabel = "Send message"
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        inputContainerView.addSubview(sendButton)
        
        // Initial state: Waveform visible, Send hidden (sharing trailing slot)
        sendButton.isHidden = true
        voiceButton.isHidden = false
        
        // --- Suggestions ---
        suggestionsStack.axis = .horizontal
        suggestionsStack.spacing = 8
        suggestionsStack.alignment = .center
        suggestionsStack.translatesAutoresizingMaskIntoConstraints = false
        
        for (index, suggestion) in suggestions.enumerated() {
            let chip = UIButton(type: .system)
            var config = UIButton.Configuration.tinted()
            config.title = suggestion
            config.cornerStyle = .capsule
            config.baseForegroundColor = .systemBlue
            config.baseBackgroundColor = .systemBlue
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
            chip.configuration = config
            chip.tag = index
            chip.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
            suggestionsStack.addArrangedSubview(chip)
        }
        
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(suggestionsStack)
        view.addSubview(scrollView)
        
        // --- Table View ---
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "chatCell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.keyboardDismissMode = .interactive
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        // --- Layout ---
        NSLayoutConstraint.activate([
            // Input container at bottom
            inputContainerView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -10),
            inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            
            textField.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 12),
            textField.topAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: 12),
            textField.bottomAnchor.constraint(equalTo: inputContainerView.bottomAnchor, constant: -12),
            
            sendButton.leadingAnchor.constraint(equalTo: textField.trailingAnchor, constant: 8),
            sendButton.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -8),
            sendButton.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 36),
            sendButton.heightAnchor.constraint(equalToConstant: 36),
            
            voiceButton.leadingAnchor.constraint(equalTo: sendButton.leadingAnchor),
            voiceButton.trailingAnchor.constraint(equalTo: sendButton.trailingAnchor),
            voiceButton.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor),
            voiceButton.widthAnchor.constraint(equalTo: sendButton.widthAnchor),
            voiceButton.heightAnchor.constraint(equalTo: sendButton.heightAnchor),
            
            // Suggestions above input
            scrollView.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: -4),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 40),
            
            suggestionsStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            suggestionsStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            suggestionsStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            suggestionsStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            suggestionsStack.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            
            // Table view fills remaining space
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: scrollView.topAnchor)
        ])
    }
    
    // MARK: - Greeting
    
    private func addGreeting() {
        let greeting = DisplayMessage(
            role: "assistant",
            content: "Hi! I'm your FamCare Assistant ✨\nI can help you understand your family's health data, create challenges, or start message groups. How can I help today?"
        )
        displayMessages.append(greeting)
        // Don't add greeting to conversationHistory — it's just UI decoration
    }
    
    // MARK: - Actions
    
    @objc private func dismissTapped() {
        dismiss(animated: true)
    }
    
    @objc private func suggestionTapped(_ sender: UIButton) {
        guard sender.tag < suggestions.count else { return }
        let text = suggestions[sender.tag]
        sendMessage(text: text)
        
        // Hide suggestions after first use
        UIView.animate(withDuration: 0.3) {
            self.suggestionsStack.superview?.alpha = 0
        }
    }
    
    @objc private func voiceTapped() {
        if VoiceRecognitionService.shared.getIsRecording() {
            VoiceRecognitionService.shared.stopRecording()
            voiceButton.tintColor = .systemBlue
            // Removed auto-sendMessage here. Let the user manually tap Send after reviewing the transcribed text.
        } else {
            VoiceRecognitionService.shared.requestPermissions { [weak self] granted in
                guard let self = self else { return }
                if granted {
                    self.startVoiceRecording()
                } else {
                    self.appendAssistantMessage("Microphone/Speech permissions are required for voice interaction.")
                }
            }
        }
    }
    
    private func startVoiceRecording() {
        voiceButton.tintColor = .systemRed
        textField.text = "Listening..."
        
        VoiceRecognitionService.shared.onPartialTranscription = { [weak self] text in
            self?.textField.text = text
        }
        
        VoiceRecognitionService.shared.onFinalTranscription = { [weak self] text in
            self?.textField.text = text
            self?.voiceButton.tintColor = .systemBlue
            // Removed auto-sendMessage here. Let the user manually tap Send after reviewing the transcribed text.
        }
        
        VoiceRecognitionService.shared.onError = { [weak self] error in
            self?.textField.text = ""
            self?.voiceButton.tintColor = .systemBlue
            self?.appendAssistantMessage("Voice recognition failed: \(error.localizedDescription)")
        }
        
        do {
            try VoiceRecognitionService.shared.startRecording()
        } catch {
            voiceButton.tintColor = .systemBlue
            appendAssistantMessage("Failed to start recording.")
        }
    }
    
    @objc private func sendTapped() {
        guard let text = textField.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        sendMessage(text: text)
    }
    
    @objc private func textDidChange() {
        if let text = textField.text, !text.isEmpty {
            sendButton.isHidden = false
            voiceButton.isHidden = true
        } else {
            sendButton.isHidden = true
            voiceButton.isHidden = false
        }
    }
    
    // MARK: - Core Message Flow
    
    private func sendMessage(text: String) {
        guard !isSending else { return }
        textField.text = ""
        textField.resignFirstResponder()
        
        // Add user message to display and history
        let userMsg = AIAssistantMessage(role: "user", content: text)
        let displayMsg = DisplayMessage(role: "user", content: text)
        displayMessages.append(displayMsg)
        conversationHistory.append(userMsg)
        reloadAndScroll()
        
        // Show typing indicator
        showTypingIndicator()
        
        // Send to AI
        isSending = true
        sendButton.isEnabled = false
           Task {
            do {
                if #available(iOS 18.0, *) {
                    let response = try await AppleAssistantService.shared.sendMessage(userMessages: conversationHistory)
                    
                    await MainActor.run {
                        hideTypingIndicator()
                        
                        // Handle text content
                        if let content = response.content, !content.isEmpty {
                            appendAssistantMessage(content)
                            conversationHistory.append(AIAssistantMessage(role: "assistant", content: content))
                            
                            // Speak the response aloud (Disabled per user request)
                            // speak(text: content)
                        } else {
                            appendAssistantMessage("I'm not sure how to respond to that. Could you rephrase?")
                        }
                    }
                } else {
                    await MainActor.run {
                        hideTypingIndicator()
                        appendAssistantMessage("Apple Intelligence requires iOS 18.0 or later.")
                    }
                }
            } catch {
                await MainActor.run {
                    hideTypingIndicator()
                    appendAssistantMessage("Sorry, I couldn't connect right now: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                isSending = false
                sendButton.isEnabled = true
            }
        }
    }
    
    private func speak(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        // Optional: customize rate, pitch, volume here
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        // Ensure audio session is ready for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category for speech synthesis: \(error)")
        }
        
        speechSynthesizer.speak(utterance)
    }

    // MARK: - Tool Call Handling (Actions Only)
    
    @objc private func handleCreateChallengeNotification(_ notification: Notification) {
        guard let args = notification.userInfo?["args"] as? CreateChallengeArgs else {
            appendAssistantMessage("I wanted to create a challenge but couldn't parse the details. Try again?")
            return
        }
        
        self.showChallengePreview(args: args)
    }
    
    @objc private func handleCreateMessageGroupNotification(_ notification: Notification) {
        guard let args = notification.userInfo?["args"] as? CreateMessageGroupArgs else {
            appendAssistantMessage("I wanted to create a message group but couldn't parse the details. Try again?")
            return
        }
        
        let alert = UIAlertController(
            title: "Create Group",
            message: "Create group '\(args.groupName)' with \(args.participants.joined(separator: ", "))?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.appendAssistantMessage("Group creation cancelled.")
        })
        
        alert.addAction(UIAlertAction(title: "Create", style: .default) { _ in
            self.executeCreateGroup(args: args)
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Challenge / Group Execution
    
    private func showChallengePreview(args: CreateChallengeArgs) {
        guard let familyId = DataManager.shared.currentUser?.familyId else { return }
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(Double(max(args.durationDays, 1)) * 86400)
        
        // Use the AI's description if provided, otherwise default to the challenge name
        let challengeDescription = (args.description != nil && !args.description!.isEmpty) ? args.description! : args.challengeName
        
        let metricLower = args.metric.lowercased()
        let isStandard = ["steps", "calories", "caloriesburned", "distance", "sleep"].contains(metricLower)
        let cType = isStandard ? "physical" : "social"
        let finalSubType = isStandard ? args.metric : "social_task"
        
        let challenge = ChallengeDetails(
            challengeId: UUID(),
            familyId: familyId,
            name: args.challengeName,
            description: challengeDescription,
            type: cType,
            subType: finalSubType,
            status: isStandard ? "pending" : "ongoing",
            bgImage: isStandard ? "" : "task_image",
            startDate: startDate,
            endDate: endDate,
            lastUpdatedAt: startDate,
            isSynced: false
        )
        
        // Resolve participant profiles
        var resolvedProfiles: [Profile] = []
        for p in args.participants {
            let lowerP = p.lowercased()
            if lowerP == "me" || lowerP == "my" {
                if let currentUser = DataManager.shared.currentUser { resolvedProfiles.append(currentUser) }
            } else {
                if let match = DataManager.shared.allProfiles.first(where: {
                    $0.displayName.lowercased().contains(lowerP) ||
                    (DataManager.shared.personalNicknames[$0.profileId]?.lowercased().contains(lowerP) ?? false)
                }) {
                    resolvedProfiles.append(match)
                }
            }
        }
        
        // Include self if not already
        if let currentUser = DataManager.shared.currentUser,
           !resolvedProfiles.contains(where: { $0.profileId == currentUser.profileId }) {
            resolvedProfiles.append(currentUser)
        }
        
        var progressArray: [ChallengeProgress] = []
        for profile in resolvedProfiles {
            let progress = ChallengeProgress(
                challengeId: challenge.challengeId,
                memberId: profile.profileId,
                goalValue: isStandard ? args.goalValue : 1.0,
                currentValue: 0.0,
                lastUpdatedAt: Date(),
                isSynced: false
            )
            progressArray.append(progress)
        }
        
        if isStandard {
            let previewVC = PreviewChallengeViewController()
            previewVC.precompiledDetails = challenge
            previewVC.precompiledProgress = progressArray
            previewVC.challengeType = cType
            
            let nav = UINavigationController(rootViewController: previewVC)
            nav.modalPresentationStyle = .pageSheet
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
            
            previewVC.onChallengeSaved = { [weak self] challengeId in
                let url = URL(string: "homescreenapp://challenge/\(challengeId)")
                self?.appendAssistantMessage("Challenge saved successfully!", actionTitle: "View Challenge", actionURL: url)
            }
            
            self.present(nav, animated: true) {
                self.appendAssistantMessage("I've set up the challenge. You can review and adjust the goals before saving!")
            }
        } else {
            let alert = UIAlertController(
                title: "Create Challenge",
                message: "Are you sure you want to create the challenge '\(args.challengeName)'?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                self.appendAssistantMessage("Challenge creation cancelled.")
            })
            
            alert.addAction(UIAlertAction(title: "Create", style: .default) { _ in
                let dummyVC = PreviewChallengeViewController()
                dummyVC.saveChallenge(details: challenge, progressList: progressArray)
                let url = URL(string: "homescreenapp://challenge/\(challenge.challengeId)")
                self.appendAssistantMessage("Okay, this challenge has been created. You can view it in the Challenge tab.", actionTitle: "View Challenge", actionURL: url)
            })
            
            self.present(alert, animated: true)
        }
    }
    
    private func executeCreateGroup(args: CreateMessageGroupArgs) {
        var resolvedIds: [UUID] = []
        for p in args.participants {
            let lowerP = p.lowercased()
            if lowerP == "me" || lowerP == "my" {
                if let currentUser = DataManager.shared.currentUser { resolvedIds.append(currentUser.profileId) }
            } else {
                if let match = DataManager.shared.allProfiles.first(where: {
                    $0.displayName.lowercased().contains(lowerP) ||
                    (DataManager.shared.personalNicknames[$0.profileId]?.lowercased().contains(lowerP) ?? false)
                }) {
                    resolvedIds.append(match.profileId)
                }
            }
        }
        
        if let currentId = DataManager.shared.currentUser?.profileId, !resolvedIds.contains(currentId) {
            resolvedIds.append(currentId)
        }
        
        Task {
            do {
                let viewModel = TopicsViewModel()
                let topicId = try await viewModel.createTopic(title: args.groupName, message: "Group created by Assistant", memberIds: resolvedIds)
                
                await MainActor.run {
                    let url = URL(string: "homescreenapp://group/\(topicId)")
                    self.appendAssistantMessage("✅ Group '\(args.groupName)' has been created successfully!", actionTitle: "View Group", actionURL: url)
                }
            } catch {
                await MainActor.run {
                    self.appendAssistantMessage("Failed to create group: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Display Helpers
    
    private func appendAssistantMessage(_ text: String, actionTitle: String? = nil, actionURL: URL? = nil) {
        let msg = DisplayMessage(role: "assistant", content: text, actionTitle: actionTitle, actionURL: actionURL)
        displayMessages.append(msg)
        reloadAndScroll()
    }
    
    private func reloadAndScroll() {
        tableView.reloadData()
        if !displayMessages.isEmpty {
            let indexPath = IndexPath(row: displayMessages.count - 1, section: 0)
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }
    
    // MARK: - Typing Indicator
    
    private func showTypingIndicator() {
        typingIndicatorVisible = true
        // Add a temporary "typing" message
        let typing = DisplayMessage(role: "assistant", content: "typing...")
        displayMessages.append(typing)
        reloadAndScroll()
    }
    
    private func hideTypingIndicator() {
        if typingIndicatorVisible {
            // Remove the last "typing..." message
            if let last = displayMessages.last, last.content == "typing..." {
                displayMessages.removeLast()
            }
            typingIndicatorVisible = false
        }
    }
}

// MARK: - UITableViewDataSource & Delegate

extension AssistantViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayMessages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let msg = displayMessages[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "chatCell", for: indexPath)
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        
        // Clear old views
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        let isUser = msg.role == "user"
        let isTyping = msg.content == "typing..."
        
        let bubbleView = UIView()
        bubbleView.layer.cornerRadius = 18
        bubbleView.layer.cornerCurve = .continuous
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        
        if isTyping {
            // Animated typing dots
            bubbleView.backgroundColor = .secondarySystemGroupedBackground
            bubbleView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner, .layerMinXMinYCorner]
            
            let dotsLabel = UILabel()
            dotsLabel.text = "•  •  •"
            dotsLabel.font = .systemFont(ofSize: 20, weight: .bold)
            dotsLabel.textColor = .systemGray
            dotsLabel.translatesAutoresizingMaskIntoConstraints = false
            
            cell.contentView.addSubview(bubbleView)
            bubbleView.addSubview(dotsLabel)
            
            NSLayoutConstraint.activate([
                dotsLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
                dotsLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
                dotsLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
                dotsLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
                
                bubbleView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 4),
                bubbleView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -4),
                bubbleView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                bubbleView.widthAnchor.constraint(lessThanOrEqualToConstant: 80)
            ])
            
            // Pulse animation
            UIView.animate(withDuration: 0.6, delay: 0, options: [.repeat, .autoreverse]) {
                dotsLabel.alpha = 0.3
            }
            
            return cell
        }
        
        let label = UILabel()
        label.text = msg.content
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        cell.contentView.addSubview(bubbleView)
        bubbleView.addSubview(label)
        
        if isUser {
            bubbleView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner]
            bubbleView.backgroundColor = .systemBlue
            label.textColor = .white
        } else {
            bubbleView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner, .layerMinXMinYCorner]
            bubbleView.backgroundColor = .secondarySystemGroupedBackground
            label.textColor = .label
        }
        
        var bottomAnchorConstraint = label.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12)
        
        if let actionTitle = msg.actionTitle, let actionURL = msg.actionURL {
            let actionButton = UIButton(type: .system)
            actionButton.setTitle(actionTitle, for: .normal)
            actionButton.setTitleColor(isUser ? .white : .systemBlue, for: .normal)
            actionButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
            actionButton.translatesAutoresizingMaskIntoConstraints = false
            
            let action = UIAction { [weak self] _ in
                self?.dismiss(animated: true) {
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let delegate = scene.delegate as? SceneDelegate {
                        delegate.handleIncomingURL(actionURL)
                    }
                }
            }
            actionButton.addAction(action, for: .touchUpInside)
            
            bubbleView.addSubview(actionButton)
            
            NSLayoutConstraint.activate([
                actionButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
                actionButton.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
                actionButton.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12)
            ])
            
            bottomAnchorConstraint = actionButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: -8)
        }
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            
            bubbleView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: cell.contentView.widthAnchor, multiplier: 0.78)
        ])
        
        if msg.actionTitle == nil {
            bottomAnchorConstraint.isActive = true
        }
        
        if isUser {
            bubbleView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16).isActive = true
        } else {
            bubbleView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16).isActive = true
        }
        
        return cell
    }
}

// MARK: - UITextFieldDelegate

extension AssistantViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return true
    }
}
