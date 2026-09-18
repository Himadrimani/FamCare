//
//  MessageViewController.swift
//  HealthSharing
//
//  Created by GEU on 02/02/26.
//

import UIKit
import SwiftUI

class MessageViewController: UIViewController {
    
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var addTopicButton: UIButton!
    
    var topicsVC: TopicsViewController?
    var topicsViewModel = TopicsViewModel()

    
    // All messages in the app (sent and received by the current user)
    var allMessages: [Message] = []
    
    // One entry per conversation partner.
    // This is what the collection view actually displays.
    var conversationList: [(profile: Profile, lastMessage: Message?)] = []
    // Line 20 - change Int? to UUID?
    var currentUserId: UUID?
    
    // MARK: - Unread Count Tracking (Direct Messages)
    // Key: otherUserId string → Value: count of messages seen last time that chat was opened
    private let dmSeenCountsKey = "DMSeenMessageCounts"
    
    private func dmUnreadCount(for otherUserId: UUID) -> Int {
        return DataManager.shared.messages.filter { msg in
            msg.senderId == otherUserId && msg.receiverId == currentUserId && msg.readAt == nil
        }.count
    }
    
    private func dmSeenCount(for otherUserId: UUID) -> Int {
        let data = UserDefaults.standard.data(forKey: dmSeenCountsKey)
        guard let data,
              let dict = try? JSONDecoder().decode([String: Int].self, from: data) else { return 0 }
        return dict[otherUserId.uuidString] ?? 0
    }
    
    private func markDMSeen(for otherUserId: UUID) {
        let unreadMessages = DataManager.shared.messages.filter { msg in
            msg.senderId == otherUserId && msg.receiverId == currentUserId && msg.readAt == nil
        }
        
        for var msg in unreadMessages {
            msg.readAt = Date()
            DataManager.shared.updateDirectMessage(msg)
        }
        
        Task {
            await topicsVC?.viewModel.fetchTopicsAndMessages()
        }
    }
    

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var topicsContainerView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // title = "Message" // Native title replaced by custom Label for layout
        
        // Register the cell XIB so the collection view knows how to dequeue "message_cell"
        collectionView.register(UINib(nibName: "MessageCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "message_cell")
        
        // UI Updates: Rename title and segments
        titleLabel.text = "Connect"
        segmentedControl.setTitle("Members", forSegmentAt: 0)
        segmentedControl.setTitle("Groups", forSegmentAt: 1)
        
        collectionView.dataSource = self
        collectionView.delegate = self
        
        // Initial visibility
        addTopicButton.isHidden = true
        topicsContainerView.isHidden = true
        
        setupTopicsVC()
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataManagerUpdate), name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        refreshFromDataManager()
    }
    
    // MARK: - Group Chat Setup
    func setupTopicsVC() {
        // topicsVC is now instantiated via the 'embedTopicsSegue' in Storyboard.
        // The view visibility is handled in segmentChanged().
    }
    
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            // Direct chat
            collectionView.isHidden = false
            topicsContainerView.isHidden = true
            addTopicButton.isHidden = true
        } else {
            // Topics list
            collectionView.isHidden = true
            topicsContainerView.isHidden = false
            addTopicButton.isHidden = false
        }
    }
    
    func pushTopicChat(topic: Topic) {
        performSegue(withIdentifier: "showTopicChatSegue", sender: topic)
    }
    
    @IBAction func presentCreateTopicSheet() {
        performSegue(withIdentifier: "showCreateTopicSegue", sender: nil)
    }
    
    // Refresh the inbox every time the user navigates back to this screen
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Hide the native navigation bar because we built a custom Large Title header
        navigationController?.setNavigationBarHidden(true, animated: false)
        refreshFromDataManager()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Restore navigation bar for ChatViewController
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    // Data Processing
     
    // Collapses allMessages into one entry per conversation partner, keeping only the most recent message for each person, then sorts the resulting list newest-first (so the most active chat is at the top).
    func buildLastMessagesPerPerson() {
        
        var dict: [UUID: Message] = [:]

        for message in allMessages {
            // Figure out which side of the conversation is the "other" person
            let otherUserId = message.senderId == currentUserId ? message.receiverId : message.senderId

            // Keep whichever message is more recent
            if let existing = dict[otherUserId] {
                if message.timestampUTC > existing.timestampUTC {
                    dict[otherUserId] = message
                }
            } else {
                dict[otherUserId] = message
            }
        }

        let allProfiles = DataManager.shared.allProfiles
        
        var list: [(Profile, Message?)] = []
        for profile in allProfiles {
            list.append((profile, dict[profile.profileId]))
        }
        
        list.sort { a, b in
            if let tA = a.1?.timestampUTC, let tB = b.1?.timestampUTC {
                return tA > tB
            } else if a.1 != nil {
                return true
            } else if b.1 != nil {
                return false
            } else {
                return a.0.firstName < b.0.firstName
            }
        }

        conversationList = list
        collectionView.reloadData()
    }

    @objc private func handleDataManagerUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshFromDataManager()
        }
    }

    private func refreshFromDataManager() {
        DataManager.shared.ensureDirectMessagesLoaded()
        allMessages = DataManager.shared.messages
        currentUserId = DataManager.shared.currentUser?.profileId
        buildLastMessagesPerPerson()
    }
    
    //Navigation
    
    //Called automatically by UIKit just before performing a segue.
    //We use this to pass the correct user IDs to ChatViewController.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

        if segue.identifier == "showChatSegue",
           let indexPath = sender as? IndexPath,
           let chatVC = segue.destination as? ChatViewController,
           let currentUserId = currentUserId {
            
            let item = conversationList[indexPath.item]
            
            chatVC.otherUserId = item.profile.profileId
            chatVC.currentUserId = currentUserId
            chatVC.hidesBottomBarWhenPushed = true
            
        } else if segue.identifier == "embedTopicsSegue",
                  let topicsVC = segue.destination as? TopicsViewController {
            
            self.topicsVC = topicsVC
            topicsVC.onTopicSelected = { [weak self] topic in
                self?.pushTopicChat(topic: topic)
            }
            topicsVC.onCreateNewTopic = { [weak self] in
                self?.presentCreateTopicSheet()
            }
            
        } else if segue.identifier == "showTopicChatSegue",
                  let topicChatVC = segue.destination as? TopicChatViewController,
                  let topic = sender as? Topic {
            
            topicChatVC.viewModel = TopicChatViewModel(topic: topic)
            topicChatVC.hidesBottomBarWhenPushed = true
            
        } else if segue.identifier == "showCreateTopicSegue",
                  let nav = segue.destination as? UINavigationController,
                  let createVC = nav.topViewController as? CreateTopicViewController {
            
            createVC.onTopicCreated = { [weak self] topicId in
                if let topic = DataManager.shared.topics.first(where: { $0.id == topicId }) {
                    self?.pushTopicChat(topic: topic)
                }
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

}

//UICollectionViewDataSource
extension MessageViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if conversationList.isEmpty {
            collectionView.setEmptyMessage("No family members found to chat with.", iconName: "person.2.slash")
        } else {
            collectionView.restore()
        }
        return conversationList.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "message_cell",
            for: indexPath
        ) as! MessageCollectionViewCell
        
        let item = conversationList[indexPath.item]
        let unread = dmUnreadCount(for: item.profile.profileId)
        cell.configure(with: item.profile, lastMessage: item.lastMessage, currentUserId: currentUserId, unreadCount: unread)

        return cell
    }
}

//UICollectionViewDelegateFlowLayout (cell sizing)
extension MessageViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // All inbox rows are the same fixed height (like a standard table view cell)
        return CGSize(width: collectionView.bounds.width, height: 85)
    }
}

//UICollectionViewDelegate (tap handling)
extension MessageViewController: UICollectionViewDelegate {
    
    // When the user taps a conversation row, trigger the segue to ChatViewController.
    // We pass the indexPath as the sender so prepare(for:sender:) knows which row was tapped.
    func collectionView(_ collectionView: UICollectionView,didSelectItemAt indexPath: IndexPath) {
        let item = conversationList[indexPath.item]
        guard currentUserId != nil else { return }
        markDMSeen(for: item.profile.profileId)
        performSegue(withIdentifier: "showChatSegue", sender: indexPath)
    }
}
