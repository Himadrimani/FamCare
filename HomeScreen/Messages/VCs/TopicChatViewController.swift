import UIKit
import Combine

class TopicChatViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var inputStackView: UIStackView!
    @IBOutlet weak var messageTextView: UITextView!
    @IBOutlet weak var sendButton: UIButton!
    
    var viewModel: TopicChatViewModel!
    private var cancellables = Set<AnyCancellable>()
    private var hasScrolledToBottom = false
    private let voiceButton = UIButton(type: .system)
    
    // Flattened items for the collection view, including messages and date headers
    private var chatItems: [TopicChatItem] = []
    
    enum TopicChatItem {
        case dateHeader(String)
        case message(TopicMessage)
    }
    
    // We remove the custom init(topic:) as it's not compatible with Storyboard Segues.
    // The viewModel is now injected in prepare(for:sender:) in MessageViewController.

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if viewModel == nil { return }
        title = viewModel.topic.title
        
        newMessageAreaSetUp()
        
        // Register custom NIB cells
        collectionView.register(UINib(nibName: "TopicSentMessageCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "TopicSentCell")
        collectionView.register(UINib(nibName: "TopicReceivedMessageCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "TopicReceivedCell")
        collectionView.register(UINib(nibName: "DateHeaderCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "date_header_cell")

        // Tap to dismiss keyboard
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        collectionView.addGestureRecognizer(tap)
        
        setupBindings()
        setupKeyboardObservers()
        viewModel.onAppear()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = true
        // Force small title (as in ChatViewController)
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.setNavigationBarHidden(false, animated: true)
        
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = scene.delegate as? SceneDelegate {
            sceneDelegate.setAssistantButton(hidden: true)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tabBarController?.tabBar.isHidden = false
        // Restore large titles for MessageViewController
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.setNavigationBarHidden(true, animated: true)
        
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = scene.delegate as? SceneDelegate {
            sceneDelegate.setAssistantButton(hidden: false)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !hasScrolledToBottom, !chatItems.isEmpty {
            hasScrolledToBottom = true
            scrollToBottom(animated: false)
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func setupBindings() {
        viewModel.$messages
            .receive(on: RunLoop.main)
            .sink { [weak self] msgs in
                guard let self = self else { return }
                self.buildChatItems(from: msgs)
                self.collectionView.reloadData()
                if self.hasScrolledToBottom {
                    self.scrollToBottom(animated: true)
                }
            }
            .store(in: &cancellables)
    }
    
    @IBAction func sendTapped() {
        let text = messageTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != "Type your message here" else { return }
        
        Task {
            await viewModel.sendMessage(content: text)
            // Use same "clear" logic as ChatViewController
            messageTextView.text = ""
            textViewDidChange(messageTextView)
            
            // Explicitly reset send button style for disabled state
            sendButton.backgroundColor = .systemGray6
            sendButton.tintColor = .systemGray3
        }
    }
    
    // Exact same setup as ChatViewController, now with screenshot-matched colors
    // Initial setup for message input area
    private func newMessageAreaSetUp() {
        messageTextView.isScrollEnabled = true
        messageTextView.textContainer.lineBreakMode = .byWordWrapping
        messageTextView.textContainer.maximumNumberOfLines = 0
        messageTextView.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        
        messageTextView.layer.cornerRadius = 16
        messageTextView.layer.borderWidth = 1
        messageTextView.layer.borderColor = UIColor.systemGray4.cgColor
        
        messageTextView.text = "Type your message here"
        messageTextView.textColor = .systemGray
        
        // Setup Voice Button
        voiceButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        voiceButton.tintColor = .systemBlue
        voiceButton.translatesAutoresizingMaskIntoConstraints = false
        voiceButton.addTarget(self, action: #selector(voiceTapped), for: .touchUpInside)
        
        // Add Voice Button to stack view
        if !inputStackView.arrangedSubviews.contains(voiceButton) {
            inputStackView.insertArrangedSubview(voiceButton, at: 0)
            NSLayoutConstraint.activate([
                voiceButton.widthAnchor.constraint(equalToConstant: 40)
            ])
        }
        
        // Setup Send Button
        sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        sendButton.setTitle("", for: .normal)
        
        // Size the send button image larger
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        sendButton.setPreferredSymbolConfiguration(config, forImageIn: .normal)
        sendButton.isEnabled = false
        sendButton.backgroundColor = .clear
        sendButton.tintColor = .systemGray3
    }
    
    @objc private func voiceTapped() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        if VoiceRecognitionService.shared.getIsRecording() {
            VoiceRecognitionService.shared.stopRecording()
            voiceButton.tintColor = .systemBlue
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
            self.voiceButton.tintColor = .systemRed
            if self.messageTextView.text == "Type your message here" || self.messageTextView.text.isEmpty {
                self.messageTextView.text = "Listening..."
                self.messageTextView.textColor = .systemGray
            }
        }
        
        VoiceRecognitionService.shared.onPartialTranscription = { [weak self] text in
            guard let self = self else { return }
            self.messageTextView.text = text
            self.messageTextView.textColor = .label
            self.textViewDidChange(self.messageTextView)
        }
        
        VoiceRecognitionService.shared.onFinalTranscription = { [weak self] text in
            guard let self = self else { return }
            self.messageTextView.text = text
            self.messageTextView.textColor = .label
            self.voiceButton.tintColor = .systemBlue
            self.textViewDidChange(self.messageTextView)
        }
        
        VoiceRecognitionService.shared.onError = { [weak self] error in
            print("Voice recognition error: \(error.localizedDescription)")
            self?.voiceButton.tintColor = .systemBlue
        }
        
        do {
            try VoiceRecognitionService.shared.startRecording()
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            voiceButton.tintColor = .systemBlue
        }
    }
    
    private func scrollToBottom(animated: Bool) {
        let itemCount = chatItems.count
        if itemCount > 0 {
            let indexPath = IndexPath(item: itemCount - 1, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .bottom, animated: animated)
        }
    }
    
    // Group messages by date and insert headers
    private func buildChatItems(from messages: [TopicMessage]) {
        chatItems.removeAll()
        let calendar = Calendar.current
        var lastDate: Date?

        for msg in messages {
            let createdAt = msg.createdAt ?? Date()
            let date = calendar.startOfDay(for: createdAt)
            if lastDate == nil || date != lastDate {
                let title = formattedDateTitle(for: createdAt)
                chatItems.append(.dateHeader(title))
                lastDate = date
            }
            chatItems.append(.message(msg))
        }
    }
    
    private func formattedDateTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
    
    // MARK: - Keyboard Handling
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
           let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
            
            let window = UIApplication.shared.windows.first
            let bottomPadding = window?.safeAreaInsets.bottom ?? 0
            
            UIView.animate(withDuration: duration) {
                self.additionalSafeAreaInsets.bottom = keyboardSize.height - bottomPadding
                self.view.layoutIfNeeded()
                self.scrollToBottom(animated: false)
            }
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        if let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
            UIView.animate(withDuration: duration) {
                self.additionalSafeAreaInsets.bottom = 0
                self.view.layoutIfNeeded()
            }
        }
    }
}

extension TopicChatViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return chatItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = chatItems[indexPath.item]
        
        switch item {
        case .dateHeader(let title):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "date_header_cell", for: indexPath) as! DateHeaderCollectionViewCell
            cell.configure(title: title)
            return cell
            
        case .message(let msg):
            let currentUserId = DataManager.shared.currentUser?.profileId
            let isCurrentUser = (msg.senderId == currentUserId)
            
            if isCurrentUser {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TopicSentCell", for: indexPath) as! TopicSentMessageCollectionViewCell
                cell.configure(with: msg)
                cell.onViewCardTapped = { [weak self] in
                    self?.handleViewCardTapped(message: msg.content)
                }
                return cell
            } else {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TopicReceivedCell", for: indexPath) as! TopicReceivedMessageCollectionViewCell
                let profile = viewModel.profiles[msg.senderId]
                let showInfo = shouldShowSenderInfo(at: indexPath.item)
                cell.configure(with: msg, profile: profile, showSenderInfo: showInfo)
                cell.onViewCardTapped = { [weak self] in
                    self?.handleViewCardTapped(message: msg.content)
                }
                return cell
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let item = chatItems[indexPath.item]
        let width = collectionView.bounds.width
        
        switch item {
        case .dateHeader(_):
            return CGSize(width: width, height: 40)
            
        case .message(let msg):
            let currentUserId = DataManager.shared.currentUser?.profileId
            let isCurrentUser = (msg.senderId == currentUserId)
            
            if msg.content.hasPrefix("[SHARE_CARD:") {
                if msg.content.hasPrefix("[SHARE_CARD:INSIGHT") {
                    return CGSize(width: width, height: 206)
                } else if msg.content.hasPrefix("[SHARE_CARD:CHALLENGE") {
                    return CGSize(width: width, height: 243)
                }
                return CGSize(width: width, height: 243)
            }
            
            // Dynamic height calculation for regular text
            let maxWidth = width * 0.75
            let padding: CGFloat = 32
            let font = UIFont.systemFont(ofSize: 17)
            let textHeight = msg.content.height(withConstrainedWidth: maxWidth - padding, font: font)
            
            // Vertical space breakdown:
            // Bubble internal padding + time label + margins = ~60
            let verticalPadding: CGFloat = 60
            return CGSize(width: width, height: textHeight + verticalPadding)
        }
    }
    
    private func shouldShowSenderInfo(at index: Int) -> Bool {
        guard case .message(let currentMsg) = chatItems[index] else { return false }
        if index == 0 { return true }
        
        // Find previous message (skip headers)
        for i in (0..<index).reversed() {
            if case .message(let prev) = chatItems[i] {
                return currentMsg.senderId != prev.senderId
            }
        }
        return true
    }
}

// Exactly same delegate behaviour as ChatViewController
extension TopicChatViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == "Type your message here" {
            textView.text = ""
            textView.textColor = .label
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            textView.text = "Type your message here"
            textView.textColor = .lightGray
            sendButton.isEnabled = false
            sendButton.alpha = 0.4
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        let hasRealText = textView.text != "Type your message here" && !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        sendButton.isEnabled = hasRealText
        
        if hasRealText {
            sendButton.tintColor = .systemBlue
            textView.textColor = .label
        } else {
            sendButton.tintColor = .systemGray3
        }
    }
}

extension TopicChatViewController {
    private func handleViewCardTapped(message: String) {
        guard message.hasPrefix("[SHARE_CARD:CHALLENGE|") else { return }
        let content = String(message.dropFirst("[SHARE_CARD:".count).dropLast())
        let components = content.split(separator: "|").map { String($0) }
        guard components.count > 3 else { return }
        
        let challengeName = components[3]
        
        let allChallenges = DataManager.shared.challenges
        guard let challenge = allChallenges.first(where: { $0.name == challengeName }) else {
            print("Challenge not found: \(challengeName)")
            return
        }
        
        let storyboard = UIStoryboard(name: "Challenges", bundle: nil)
        if let destinationVC = storyboard.instantiateViewController(withIdentifier: "ViewChallengeViewController") as? ViewChallengeViewController {
            destinationVC.challenge = challenge
            destinationVC.familyMembers = DataManager.shared.allProfiles.filter { $0.profileId != DataManager.shared.currentUser?.profileId }
            self.navigationController?.pushViewController(destinationVC, animated: true)
        }
    }
}
