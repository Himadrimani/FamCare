//
//  ChatViewController.swift
//  HealthSharing
//
//  Created by GEU on 06/02/26.
//

import UIKit

// This screen shows the full conversation between the current user and one other user.
// It displays messages in a collection view, groups them by date, and lets the user type and send new messages.
class ChatViewController: UIViewController {
    // The user ID of the person we are chatting with (set by MessageViewController before pushing this screen)
    var currentUserId: UUID?
    var otherUserId: UUID?
    
    // Raw Message objects fetched from DataManager, filtered to this conversation only
    var messages: [Message] = []
    
    // Flattened list used as the collection view's data source.
    // Each element is either a date-separator header or a chat message.
    var chatItems: [ChatItem] = []
    
    // Guard flag — ensures we only auto-scroll to the bottom once on first load,
    // not on every subsequent layout pass (keyboard show/hide, rotation, etc.)
    private var hasScrolledToBottom = false
    
    private let voiceButton = UIButton(type: .system)

    @IBOutlet weak var sendButton: UIButton! // Button to submit the typed message
    @IBOutlet weak var newMessageTextView: UITextView! // Button to submit the typed message
    @IBOutlet weak var collectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard currentUserId != nil, otherUserId != nil else {
            print("ChatViewController: missing user IDs")
            return
        }

        // Register the three cell types this collection view uses:
        // 1. A cell for messages the current user sent (shown on the right)
        // 2. A cell for messages received from the other user (shown on the left)
        // 3. A small date-separator header
        collectionView.register(UINib(nibName: "SentMessageCollectionViewCell", bundle: nil),forCellWithReuseIdentifier: "sent_message_cell")
        collectionView.register(UINib(nibName: "ReceivedMessageCollectionViewCell", bundle: nil),forCellWithReuseIdentifier: "received_message_cell")
        collectionView.register(UINib(nibName: "DateHeaderCollectionViewCell", bundle: nil),forCellWithReuseIdentifier: "date_header_cell")
        
        collectionView.register(UINib(nibName: "ChallengeSentMessageCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "challenge_sent_message_cell")
        collectionView.register(UINib(nibName: "ChallengeReceivedMessageCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "challenge_received_message_cell")
        
        // Wire up data source and delegates so UIKit knows where to ask for cells and sizes
        collectionView.dataSource = self
        collectionView.delegate = self
        newMessageTextView.delegate = self

        title = displayName(for: otherUserId)
        navigationItem.largeTitleDisplayMode = .never
        
        // Give messages a little breathing room between rows
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.minimumLineSpacing = 8
        }
        
        // Style the text input area and disable the send button until text is entered
        newMessageAreaSetUp()
        setupKeyboardLayout()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataManagerUpdate), name: NSNotification.Name("DataManagerDidUpdate"), object: nil)

        // Load and display messages.
        loadMessages()
    }
    
    @objc private func handleDataManagerUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.loadMessages()
            self?.scrollToBottom(animated: true)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = scene.delegate as? SceneDelegate {
            sceneDelegate.setAssistantButton(hidden: true)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = scene.delegate as? SceneDelegate {
            sceneDelegate.setAssistantButton(hidden: false)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // viewDidLayoutSubviews fires after cells are fully sized and placed —
    // the earliest point where the collection view knows its real content height.
    // viewWillAppear is too early (layout hasn't happened yet), which caused
    // the last 2-3 messages to remain hidden.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !hasScrolledToBottom {
            hasScrolledToBottom = true
            scrollToBottom(animated: false)
        }
    }
    
    @IBAction func sendButtonTapped(_ sender: Any) {
        let text = newMessageTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != "Type your message here" else { return }
        
        guard let currentUserId = currentUserId, let otherUserId = otherUserId else { return }
        
        let newMessage = Message(
            messageId: UUID(),
            senderId: currentUserId,
            receiverId: otherUserId,
            timestampUTC: Date(),
            message: text,
            deliveredAt: nil,
            readAt: nil,
            lastUpdatedAt: Date(),
            isSynced: false
        )
        
        // Save to local storage
        DataManager.shared.insertDirectMessage(newMessage)
        
        // Clear UI
        newMessageTextView.text = "Type your message here"
        newMessageTextView.textColor = .systemGray
        sendButton.isEnabled = false
        sendButton.backgroundColor = .clear
        sendButton.tintColor = .systemGray3
        
        // Reload list and scroll
        loadMessages()
        scrollToBottom(animated: true)
    }
    
    // MARK: - Keyboard Handling
    private func setupKeyboardLayout() {
        guard let stack = newMessageTextView.superview as? UIStackView else { return }
        
        let constraintsToRemove = view.constraints.filter { 
            ($0.firstItem as? UIView == stack && $0.firstAttribute == .bottom) ||
            ($0.secondItem as? UIView == stack && $0.secondAttribute == .bottom) ||
            ($0.firstItem as? UILayoutGuide != nil && $0.secondItem as? UIView == stack && $0.secondAttribute == .bottom) ||
            ($0.secondItem as? UILayoutGuide != nil && $0.firstItem as? UIView == stack && $0.firstAttribute == .bottom)
        }
        NSLayoutConstraint.deactivate(constraintsToRemove)
        
        stack.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -10).isActive = true
    }
    
    //Setup
    
    // Configures the appearance and initial state of the message input area.
    func newMessageAreaSetUp() {
        // Allow the text view to scroll if the user types more than a few lines
        newMessageTextView.isScrollEnabled = true
        newMessageTextView.textContainer.lineBreakMode = .byWordWrapping
        newMessageTextView.textContainer.maximumNumberOfLines = 0
        newMessageTextView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        
        // Remove old borders from text view
        newMessageTextView.layer.borderWidth = 0
        newMessageTextView.backgroundColor = .clear
        
        // Placeholder text — replaced with real text when the user taps inside

        newMessageTextView.text = "Type your message here"
        newMessageTextView.textColor = .secondaryLabel
        
        if let stack = newMessageTextView.superview as? UIStackView {
            // Style the stack view as the unified container
            // Style the stack view as the unified container using Liquid Glass
            stack.backgroundColor = .clear
            stack.layer.borderWidth = 0
            stack.isLayoutMarginsRelativeArrangement = true
            stack.layoutMargins = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
            stack.alignment = .center
            
            if stack.viewWithTag(999) == nil {
                let blurEffect = UIBlurEffect(style: .systemMaterial)
                let effectView = UIVisualEffectView(effect: blurEffect)
                effectView.tag = 999
                effectView.layer.cornerRadius = 20
                effectView.layer.cornerCurve = .continuous
                effectView.layer.borderWidth = 0.5
                effectView.layer.borderColor = UIColor.separator.withAlphaComponent(0.5).cgColor
                effectView.clipsToBounds = true
                effectView.translatesAutoresizingMaskIntoConstraints = false
                
                stack.insertSubview(effectView, at: 0)
                NSLayoutConstraint.activate([
                    effectView.topAnchor.constraint(equalTo: stack.topAnchor),
                    effectView.bottomAnchor.constraint(equalTo: stack.bottomAnchor),
                    effectView.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
                    effectView.trailingAnchor.constraint(equalTo: stack.trailingAnchor)
                ])
            }
            
            var config = UIButton.Configuration.plain()
            config.image = UIImage(systemName: "waveform", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular))
            config.baseForegroundColor = .systemBlue
            voiceButton.configuration = config
            voiceButton.accessibilityLabel = "Voice message"
            voiceButton.translatesAutoresizingMaskIntoConstraints = false
            voiceButton.addTarget(self, action: #selector(voiceTapped), for: .touchUpInside)
            
            if !stack.arrangedSubviews.contains(voiceButton) {
                stack.addArrangedSubview(voiceButton)
                NSLayoutConstraint.activate([
                    voiceButton.widthAnchor.constraint(equalToConstant: 36),
                    voiceButton.heightAnchor.constraint(equalToConstant: 36)
                ])
            }
        }
        
        // Send button starts rounded and disabled
        var sendConfig = UIButton.Configuration.plain()
        sendConfig.image = UIImage(systemName: "arrow.up.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold))
        sendConfig.baseForegroundColor = .systemBlue
        sendButton.configuration = sendConfig
        sendButton.accessibilityLabel = "Send message"
        
        // Constrain send button
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sendButton.widthAnchor.constraint(equalToConstant: 36),
            sendButton.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        // Initial state: Waveform visible, Send hidden (since they share the trailing slot)
        sendButton.isHidden = true
        voiceButton.isHidden = false
    }
    
    @objc private func voiceTapped() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        if VoiceRecognitionService.shared.getIsRecording() {
            VoiceRecognitionService.shared.stopRecording()
            voiceButton.configuration?.baseForegroundColor = .systemBlue
        } else {
            VoiceRecognitionService.shared.requestPermissions { [weak self] granted in
                guard let self = self else { return }
                if granted {
                    self.startVoiceRecording()
                } else {
                    print("Voice permissions not granted")
                }
            }
        }
    }
    
    private func startVoiceRecording() {
        DispatchQueue.main.async {
            self.voiceButton.configuration?.baseForegroundColor = .systemRed
            if self.newMessageTextView.text == "Type your message here" || self.newMessageTextView.text.isEmpty {
                self.newMessageTextView.text = "Listening..."
                self.newMessageTextView.textColor = .systemGray
            }
        }
        
        VoiceRecognitionService.shared.onPartialTranscription = { [weak self] text in
            guard let self = self else { return }
            self.newMessageTextView.text = text
            self.newMessageTextView.textColor = .label
            self.textViewDidChange(self.newMessageTextView)
        }
        
        VoiceRecognitionService.shared.onFinalTranscription = { [weak self] text in
            guard let self = self else { return }
            self.newMessageTextView.text = text
            self.newMessageTextView.textColor = .label
            self.voiceButton.configuration?.baseForegroundColor = .systemBlue
            self.textViewDidChange(self.newMessageTextView)
        }
        
        VoiceRecognitionService.shared.onError = { [weak self] error in
            print("Voice recognition error: \(error.localizedDescription)")
            self?.voiceButton.configuration?.baseForegroundColor = .systemBlue
        }
        
        do {
            try VoiceRecognitionService.shared.startRecording()
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            voiceButton.configuration?.baseForegroundColor = .systemBlue
        }
    }
    
    //Data Loading
     
    // Fetches messages for this conversation from DataManager, builds chatItems, and reloads the collection view.
    func loadMessages() {
        DataManager.shared.ensureDirectMessagesLoaded()

        // Filter the global message list to only the messages between these two users,
        // then sort them oldest-first so they appear in chronological order.
        messages = DataManager.shared.messages
            .filter {
                ($0.senderId == currentUserId && $0.receiverId == otherUserId) ||
                ($0.senderId == otherUserId && $0.receiverId == currentUserId)
            }
            .sorted { $0.timestampUTC < $1.timestampUTC }
            
        for i in 0..<messages.count {
            var msg = messages[i]
            if msg.receiverId == currentUserId && msg.senderId == otherUserId {
                var modified = false
                if msg.deliveredAt == nil {
                    msg.deliveredAt = Date()
                    modified = true
                }
                if msg.readAt == nil {
                    msg.readAt = Date()
                    modified = true
                }
                if modified {
                    messages[i] = msg
                    DataManager.shared.updateDirectMessage(msg)
                }
            }
        }

        // Convert the flat message array into chatItems (inserting date headers as needed)
        buildChatItems(from: messages)
        collectionView.reloadData()
    }
    
    //Scroll
    
    // Scrolls the collection view to the very last item (most recent message).
    func scrollToBottom(animated: Bool = false) {
        // Force any pending layout to finish so numberOfItems returns the correct count
        collectionView.layoutIfNeeded()

        let section = 0
        let itemCount = collectionView.numberOfItems(inSection: section)
        guard itemCount > 0 else { return } // Nothing to scroll to if the chat is empty

        let indexPath = IndexPath(item: itemCount - 1, section: section)
        collectionView.scrollToItem(at: indexPath, at: .bottom, animated: animated)
    }

    //Helper
    
    // Returns a display name for any user ID — prefers nickname, falls back to first name.
    func displayName(for userId: UUID?) -> String {
        guard let userId else { return "User" }
        let dm = DataManager.shared

        if let profile = dm.allProfiles.first(where: { $0.profileId == userId }) {
            return profile.displayName
        }
        
        if let user = dm.currentUser, user.profileId == userId {
            return user.displayName
        }

        return "User"
    }
    
    //ChatItem
    
    // Represents one row in the collection view.
    // A conversation is displayed as a mix of date separators and messages.
    enum ChatItem {
        case dateHeader(String)
        case message(Message)
    }
    
    // Converts a sorted array of Messages into chatItems by inserting a date header whenever the conversation crosses a day boundary.
    func buildChatItems(from messages: [Message]) {
        chatItems.removeAll()

        let calendar = Calendar.current

        // Sort oldest-first (messages passed in should already be sorted, but this is defensive)
        let sortedMessages = messages.sorted {
            $0.timestampUTC < $1.timestampUTC
        }

        var lastDate: Date? // Tracks the date of the previous message to detect day changes

        for message in sortedMessages {
            // Strip the time component so we can compare just the calendar day
            let messageDate = calendar.startOfDay(for: message.timestampUTC)

            // If this message falls on a different day than the previous one, insert a header
            if lastDate == nil || messageDate != lastDate {
                let title = formattedDateTitle(for: message.timestampUTC)
                chatItems.append(.dateHeader(title))
                lastDate = messageDate
            }

            chatItems.append(.message(message))
        }
    }
    
    // Produces a human-friendly string for a date to use in a date separator header.
    // Returns: "Today", "Yesterday", or a formatted date like "12 Mar 2025".
    func formattedDateTitle(for date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        }
        
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    
}

//UITextViewDelegate (message input box behaviour)
extension ChatViewController: UITextViewDelegate {
    
    // Called when the user taps into the text view — clears the placeholder text.
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == "Type your message here" {
            textView.text = ""
            textView.textColor = .label
        }
    }
    
    // Called when the user taps away — restores the placeholder if the field is empty.
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            textView.text = "Type your message here"
            textView.textColor = .lightGray
            sendButton.isEnabled = false
            sendButton.alpha = 0.4
        }
    }
    
    // Called on every keystroke — enables/disables the send button based on whether there is real text (not just whitespace or the placeholder).
    func textViewDidChange(_ textView: UITextView) {
        let text = textView.text ?? ""
        let hasRealText = !text.isEmpty && text != "Type your message here" && text != "Listening..."

        if hasRealText {
            sendButton.isHidden = false
            voiceButton.isHidden = true
        } else {
            sendButton.isHidden = true
            voiceButton.isHidden = false
        }
    }

}

//UICollectionViewDataSource
extension ChatViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        
        // The collection view has as many rows as there are chatItems
        // (messages + any date header rows)
        return chatItems.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let item = chatItems[indexPath.item]

        switch item {

        case .dateHeader(let title):
            // Dequeue a date separator cell and fill it with the header string
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "date_header_cell",for: indexPath) as! DateHeaderCollectionViewCell
            cell.configure(title: title)
            return cell

        case .message(let message):
            let isChallengeMessage = message.message.contains("#FFF00F)")
            
            // Decide whether to show a sent (right-aligned) or received (left-aligned) bubble
            if message.senderId == currentUserId {
                if isChallengeMessage {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "challenge_sent_message_cell", for: indexPath) as! ChallengeSentMessageCollectionViewCell
                    let content = message.message.components(separatedBy: "#FFF00F)").last ?? ""
                    let challengeIdString = content.components(separatedBy: "|").first ?? ""
                    let challenge = DataManager.shared.challenges.first(where: { $0.challengeId.uuidString == challengeIdString })
                    cell.configure(with: message, challenge: challenge)
                    return cell
                } else {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "sent_message_cell",for: indexPath) as! SentMessageCollectionViewCell
                    cell.configure(with: message)
                    return cell
                }
            } else {
                if isChallengeMessage {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "challenge_received_message_cell", for: indexPath) as! ChallengeReceivedMessageCollectionViewCell
                    let content = message.message.components(separatedBy: "#FFF00F)").last ?? ""
                    let challengeIdString = content.components(separatedBy: "|").first ?? ""
                    let challenge = DataManager.shared.challenges.first(where: { $0.challengeId.uuidString == challengeIdString })
                    cell.configure(with: message, challenge: challenge)
                    return cell
                } else {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "received_message_cell",for: indexPath) as! ReceivedMessageCollectionViewCell
                    cell.configure(with: message)
                    return cell
                }
            }
        }
    }

}

//UICollectionViewDelegateFlowLayout (cell sizing)
extension ChatViewController: UICollectionViewDelegateFlowLayout {
    
    // Calculates the height each row needs so the bubble fits the message text exactly.
    func collectionView(_ collectionView: UICollectionView,
                       layout collectionViewLayout: UICollectionViewLayout,
                       sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let item = chatItems[indexPath.item]
        
        switch item {
        case .dateHeader(_):
            // Date separators are always a fixed height
            return CGSize(width: collectionView.bounds.width, height: 40)
            
        case .message(let message):
            // Message bubbles are capped at 75 % of the screen width (like iMessage)
            let maxWidth = collectionView.bounds.width * 0.75
            let padding: CGFloat = 16 // left + right padding inside bubble
            let verticalPadding: CGFloat = 26 // top + bottom + time label
            
            // Calculate text height
            let textWidth = maxWidth - padding - 24 // 24 for cell margins
            
            let isChallengeMessage = message.message.contains("#FFF00F)")
            if isChallengeMessage {
                // Return a larger fixed estimate or calculate more accurately for challenge cell
                // In iOS, auto-layout handles the height if we return automatic size, but since this
                // uses fixed size calculations, we'll provide an estimated height
                let content = message.message.components(separatedBy: "#FFF00F)").last ?? ""
                let parts = content.components(separatedBy: "|")
                let displayMsg = parts.count >= 2 ? parts.dropFirst().joined(separator: "|") : content
                
                let font = UIFont.italicSystemFont(ofSize: 15)
                let textHeight = displayMsg.height(withConstrainedWidth: textWidth, font: font)
                
                // Add extra height for the other labels: title (15), challengeName (22) + spacing
                return CGSize(width: collectionView.bounds.width, height: textHeight + verticalPadding + 8 + 60)
            }
            
            let font = UIFont.preferredFont(forTextStyle: .body)
            
            let textHeight = message.message.height(
                withConstrainedWidth: textWidth,
                font: font
            )
            
            return CGSize(
                width: collectionView.bounds.width,
                height: textHeight + verticalPadding + 8 // 8 for cell top/bottom
            )
        }
    }
}


