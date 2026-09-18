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
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tabBarController?.tabBar.isHidden = false
        // Restore large titles for MessageViewController
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.setNavigationBarHidden(true, animated: true)
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
        
        sendButton.isEnabled = false
        sendButton.backgroundColor = .systemGray6
        sendButton.tintColor = .systemGray3
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
                return cell
            } else {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TopicReceivedCell", for: indexPath) as! TopicReceivedMessageCollectionViewCell
                let profile = viewModel.profiles[msg.senderId]
                let showInfo = shouldShowSenderInfo(at: indexPath.item)
                cell.configure(with: msg, profile: profile, showSenderInfo: showInfo)
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
            // Dynamic height calculation
            let maxWidth = width * 0.75
            let padding: CGFloat = 32
            let font = UIFont.systemFont(ofSize: 17)
            let textHeight = msg.content.height(withConstrainedWidth: maxWidth - padding, font: font)
            
            // Vertical space breakdown for received cell (worst case with sender info):
            // senderName top (4) + senderName (~14) + gap (4) + bubble top (10)
            // + message-to-time gap (4) + timeLabel (~12) + bubble bottom (8) + cell bottom (4) = ~60
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
            sendButton.backgroundColor = .systemBlue
            sendButton.tintColor = .white
            textView.textColor = .label
        } else {
            sendButton.backgroundColor = .systemGray6
            sendButton.tintColor = .systemGray3
        }
    }
}
