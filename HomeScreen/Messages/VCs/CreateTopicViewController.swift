import UIKit
import Combine

class CreateTopicViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    private let titleTextField = UITextField()
    private let messageTextField = UITextField()
    
    private let viewModel = TopicsViewModel()
    private var selectedMemberIds = Set<UUID>()
    private var cancellables = Set<AnyCancellable>()
    
    var onTopicCreated: ((UUID) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        viewModel.onAppear()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        title = "New Topic"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        navigationItem.rightBarButtonItem?.isEnabled = false
        
        setupCollectionView()
    }
    
    private func setupCollectionView() {
        // Layout is handled by UICollectionLayoutListConfiguration, 
        // which we can still apply to the existing Storyboard collection view.
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        
        collectionView.setCollectionViewLayout(layout, animated: false)
        collectionView.delegate = self
        collectionView.dataSource = self
        
        // Register cells
        collectionView.register(UICollectionViewListCell.self, forCellWithReuseIdentifier: "TextFieldCell")
        collectionView.register(UICollectionViewListCell.self, forCellWithReuseIdentifier: "ButtonCell")
        collectionView.register(UICollectionViewListCell.self, forCellWithReuseIdentifier: "Cell")
        collectionView.register(UICollectionViewListCell.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "Header")
    }
    
    private func setupBindings() {
        viewModel.$familyMembers
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.addObserver(self, selector: #selector(validateForm), name: UITextField.textDidChangeNotification, object: nil)
    }
    
    @objc private func validateForm() {
        let isTitleValid = !(titleTextField.text?.isEmpty ?? true)
        let isMsgValid = !(messageTextField.text?.isEmpty ?? true)
        let hasSelection = !selectedMemberIds.isEmpty
        navigationItem.rightBarButtonItem?.isEnabled = isTitleValid && isMsgValid && hasSelection
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func doneTapped() {
        guard let title = titleTextField.text, let message = messageTextField.text else { return }
        
        showLoadingHUD()
        Task {
            do {
                let topicId = try await viewModel.createTopic(title: title, message: message, memberIds: Array(selectedMemberIds))
                hideLoadingHUD()
                dismiss(animated: true) { [weak self] in
                    self?.onTopicCreated?(topicId)
                }
            } catch {
                hideLoadingHUD()
                print("Failed to create topic: \(error)")
            }
        }
    }
}

extension CreateTopicViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? 2 : viewModel.familyMembers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = indexPath.section == 0 ? "TextFieldCell" : "Cell"
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath) as! UICollectionViewListCell
        
        if indexPath.section == 0 {
            let content = cell.defaultContentConfiguration()
            cell.contentConfiguration = content
            
            let tf = indexPath.item == 0 ? titleTextField : messageTextField
            tf.placeholder = indexPath.item == 0 ? "Title" : "Message"
            tf.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(tf)
            
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                tf.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                tf.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
                tf.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
                tf.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
            ])
        } else {
            let member = viewModel.familyMembers[indexPath.item]
            
            var content = cell.defaultContentConfiguration()
            content.text = member.displayName
            content.imageProperties.maximumSize = CGSize(width: 32, height: 32)
            content.imageProperties.cornerRadius = 16
            
            // Use a temporary UIImageView with ImageManager (the proven app-wide pattern).
            // setImage loads synchronously from memory/disk cache; for network URLs it
            // sets a placeholder synchronously and fetches async in the background.
            let tempImageView = UIImageView()
            ImageManager.shared.setImage(for: tempImageView, from: member.avatarUrl)
            content.image = tempImageView.image
            cell.contentConfiguration = content
            
            cell.accessories = selectedMemberIds.contains(member.id) ? [.checkmark()] : []
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath) as! UICollectionViewListCell
            var config = header.defaultContentConfiguration()
            if indexPath.section == 1 {
                config.text = "Choose members"
            } else {
                config.text = ""
            }
            header.contentConfiguration = config
            return header
        }
        return UICollectionReusableView()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 1 {
            let member = viewModel.familyMembers[indexPath.item]
            if selectedMemberIds.contains(member.id) {
                selectedMemberIds.remove(member.id)
            } else {
                selectedMemberIds.insert(member.id)
            }
            collectionView.reloadItems(at: [indexPath])
            validateForm()
        }
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

