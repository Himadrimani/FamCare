import UIKit

class AssistantViewController: UIViewController {
    
    // MARK: - UI Elements
    private let tableView = UITableView()
    private let inputContainerView = UIView()
    private let textField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let voiceButton = UIButton(type: .system)
    private let suggestionsStack = UIStackView()
    
    // MARK: - Data
    /// Only user + assistant messages (no internal context).
    private var displayMessages: [AIAssistantMessage] = []
    /// Full conversation sent to the AI (excludes context — that's injected by the service).
    private var conversationHistory: [AIAssistantMessage] = []
    
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
        
        // --- Input Container ---
        inputContainerView.backgroundColor = .secondarySystemGroupedBackground
        inputContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputContainerView)
        
        // Voice button
        voiceButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        voiceButton.tintColor = .systemBlue
        voiceButton.translatesAutoresizingMaskIntoConstraints = false
        voiceButton.addTarget(self, action: #selector(voiceTapped), for: .touchUpInside)
        inputContainerView.addSubview(voiceButton)
        
        // Text field
        textField.placeholder = "Ask anything..."
        textField.borderStyle = .roundedRect
        textField.returnKeyType = .send
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        inputContainerView.addSubview(textField)
        
        // Send button
        sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        sendButton.tintColor = .systemBlue
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        inputContainerView.addSubview(sendButton)
        
        // --- Suggestions ---
        suggestionsStack.axis = .horizontal
        suggestionsStack.spacing = 8
        suggestionsStack.alignment = .center
        suggestionsStack.translatesAutoresizingMaskIntoConstraints = false
        
        for (index, suggestion) in suggestions.enumerated() {
            let chip = UIButton(type: .system)
            chip.setTitle(suggestion, for: .normal)
            chip.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            chip.backgroundColor = .systemBlue.withAlphaComponent(0.1)
            chip.setTitleColor(.systemBlue, for: .normal)
            chip.layer.cornerRadius = 14
            chip.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
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
            inputContainerView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            voiceButton.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 16),
            voiceButton.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            voiceButton.widthAnchor.constraint(equalToConstant: 30),
            voiceButton.heightAnchor.constraint(equalToConstant: 30),
            
            textField.leadingAnchor.constraint(equalTo: voiceButton.trailingAnchor, constant: 12),
            textField.topAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: 12),
            textField.bottomAnchor.constraint(equalTo: inputContainerView.bottomAnchor, constant: -12),
            
            sendButton.leadingAnchor.constraint(equalTo: textField.trailingAnchor, constant: 12),
            sendButton.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 30),
            sendButton.heightAnchor.constraint(equalToConstant: 30),
            
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
        let greeting = AIAssistantMessage(
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
            
            if let text = textField.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sendMessage(text: text)
            }
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
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self?.sendMessage(text: text)
            }
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
    
    // MARK: - Core Message Flow
    
    private func sendMessage(text: String) {
        guard !isSending else { return }
        textField.text = ""
        textField.resignFirstResponder()
        
        // Add user message to display and history
        let userMsg = AIAssistantMessage(role: "user", content: text)
        displayMessages.append(userMsg)
        conversationHistory.append(userMsg)
        reloadAndScroll()
        
        // Show typing indicator
        showTypingIndicator()
        
        // Send to AI
        isSending = true
        sendButton.isEnabled = false
        
        Task {
            do {
                let response = try await AIAssistantService.shared.sendMessage(userMessages: conversationHistory)
                
                await MainActor.run {
                    hideTypingIndicator()
                    
                    // Handle tool calls (create challenge / create group)
                    if let toolCalls = response.tool_calls, !toolCalls.isEmpty {
                        for toolCall in toolCalls {
                            handleToolCall(toolCall)
                        }
                    }
                    
                    // Handle text content
                    if let content = response.content, !content.isEmpty {
                        appendAssistantMessage(content)
                        conversationHistory.append(AIAssistantMessage(role: "assistant", content: content))
                    } else if response.tool_calls == nil || response.tool_calls?.isEmpty == true {
                        // No content and no tool calls — shouldn't happen, but handle gracefully
                        appendAssistantMessage("I'm not sure how to respond to that. Could you rephrase?")
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
    
    // MARK: - Tool Call Handling (Actions Only)
    
    private func handleToolCall(_ toolCall: ToolCall) {
        let toolName = toolCall.function.name
        
        if toolName == "create_challenge" {
            guard let argsData = toolCall.function.arguments.data(using: .utf8),
                  let args = try? JSONDecoder().decode(CreateChallengeArgs.self, from: argsData) else {
                appendAssistantMessage("I wanted to create a challenge but couldn't parse the details. Try again?")
                return
            }
            
            self.showChallengePreview(args: args)
        } else if toolName == "create_message_group" {
            guard let argsData = toolCall.function.arguments.data(using: .utf8),
                  let args = try? JSONDecoder().decode(CreateMessageGroupArgs.self, from: argsData) else {
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
    }
    
    // MARK: - Challenge / Group Execution
    
    private func showChallengePreview(args: CreateChallengeArgs) {
        guard let familyId = DataManager.shared.currentUser?.familyId else { return }
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(Double(max(args.durationDays, 1)) * 86400)
        
        // Use the AI's description if provided, otherwise default to the challenge name
        let challengeDescription = (args.description != nil && !args.description!.isEmpty) ? args.description! : args.challengeName
        
        let challenge = ChallengeDetails(
            challengeId: UUID(),
            familyId: familyId,
            name: args.challengeName,
            description: challengeDescription,
            type: "physical",
            subType: args.metric,
            status: "pending",
            bgImage: "",
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
                goalValue: args.goalValue,
                currentValue: 0.0,
                lastUpdatedAt: Date(),
                isSynced: false
            )
            progressArray.append(progress)
        }
        
        let previewVC = PreviewChallengeViewController()
        previewVC.precompiledDetails = challenge
        previewVC.precompiledProgress = progressArray
        previewVC.challengeType = "physical"
        
        let nav = UINavigationController(rootViewController: previewVC)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        
        self.present(nav, animated: true) {
            self.appendAssistantMessage("I've set up the challenge. You can review and adjust the goals before saving!")
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
                let _ = try await viewModel.createTopic(title: args.groupName, message: "Group created by Assistant", memberIds: resolvedIds)
                
                await MainActor.run {
                    self.appendAssistantMessage("✅ Group '\(args.groupName)' has been created successfully!")
                }
            } catch {
                await MainActor.run {
                    self.appendAssistantMessage("Failed to create group: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Display Helpers
    
    private func appendAssistantMessage(_ text: String) {
        let msg = AIAssistantMessage(role: "assistant", content: text)
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
        let typing = AIAssistantMessage(role: "assistant", content: "typing...")
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
        bubbleView.layer.cornerRadius = 16
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        
        if isTyping {
            // Animated typing dots
            bubbleView.backgroundColor = .secondarySystemGroupedBackground
            
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
        label.text = msg.content ?? ""
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        cell.contentView.addSubview(bubbleView)
        bubbleView.addSubview(label)
        
        bubbleView.backgroundColor = isUser ? .systemBlue : .secondarySystemGroupedBackground
        label.textColor = isUser ? .white : .label
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            
            bubbleView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: cell.contentView.widthAnchor, multiplier: 0.78)
        ])
        
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
