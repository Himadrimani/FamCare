//
//  EditWellnessViewController.swift
//  HomeScreen
//
//  Created by Himadri  on 30/03/26.
//


import UIKit

// MARK: - Delegate Protocol
protocol EditWellnessViewControllerDelegate: AnyObject {
    func editWellnessViewControllerDidUpdate(_ controller: EditWellnessViewController, visibleMetricIds: [String])
}

// MARK: - EditWellnessViewController
class EditWellnessViewController: UIViewController {

    var collectionView: UICollectionView!
    var titleLabel: UILabel!
    var doneButton: UIButton!
    var selectedDate: Date = Date()
    var profile: Profile?
    private var allCards: [WellnessCard] = []
    private var selectedIds: Set<String> = []

    weak var delegate: EditWellnessViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let profile else { return } // unwrap early
        
        view.backgroundColor = .systemGroupedBackground
        allCards = WellnessDataProvider.getAllPossibleCards(for: profile, date: selectedDate)
        selectedIds = Set(profile.visibleMetricIds ?? allCards.map { cardId(for: $0.type) })
        
        setupUI()
        setupCollectionView()
    }

    private func cardId(for type: WellnessCardType) -> String {
        switch type {
        case .steps:     return "steps"
        case .sleep:     return "sleep"
        case .calories:  return "calories"
        case .distance:  return "distance"
        case .heartRate: return "heartRate"
        case .hrv:       return "hrv"
        }
    }

    private func setupUI() {
        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Edit Dashboard"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        view.addSubview(titleLabel)

        doneButton = UIButton(type: .system)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.setTitle("Done", for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        view.addSubview(doneButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            doneButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let item = NSCollectionLayoutItem(
                layoutSize: .init(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(140)))
            item.contentInsets = .init(top: 8, leading: 8, bottom: 8, trailing: 8)
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: .init(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(140)),
                subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = .init(top: 16, leading: 12, bottom: 16, trailing: 12)
            return section
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.layer.masksToBounds = false
        collectionView.dataSource = self
        collectionView.delegate   = self
        collectionView.register(EditWellnessCell.self, forCellWithReuseIdentifier: "EditWellnessCell")
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func doneTapped() {
        delegate?.editWellnessViewControllerDidUpdate(self, visibleMetricIds: Array(selectedIds))
        dismiss(animated: true)
    }
}

// MARK: - UICollectionView DataSource / Delegate
extension EditWellnessViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return allCards.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell   = collectionView.dequeueReusableCell(withReuseIdentifier: "EditWellnessCell", for: indexPath) as! EditWellnessCell
        let card   = allCards[indexPath.item]
        let id     = cardId(for: card.type)
        cell.configure(with: card, isSelected: selectedIds.contains(id))
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let id = cardId(for: allCards[indexPath.item].type)
        if selectedIds.contains(id) { selectedIds.remove(id) } else { selectedIds.insert(id) }
        collectionView.reloadItems(at: [indexPath])
    }
}

// MARK: - EditWellnessCell
class EditWellnessCell: UICollectionViewCell {

    private let iconImageView = UIImageView()
    private let titleLabel    = UILabel()
    private let statusIcon    = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        contentView.backgroundColor    = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 16
        contentView.layer.shadowColor  = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.05
        contentView.layer.shadowOffset  = CGSize(width: 0, height: 2)
        contentView.layer.shadowRadius  = 4

        [iconImageView, titleLabel, statusIcon].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        iconImageView.contentMode = .scaleAspectFit
        titleLabel.font           = .systemFont(ofSize: 16, weight: .semibold)
        statusIcon.contentMode    = .scaleAspectFit

        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.widthAnchor.constraint(equalToConstant: 30),
            iconImageView.heightAnchor.constraint(equalToConstant: 30),

            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            statusIcon.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            statusIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            statusIcon.widthAnchor.constraint(equalToConstant: 24),
            statusIcon.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    func configure(with card: WellnessCard, isSelected: Bool) {
        iconImageView.image   = UIImage(systemName: card.icon)
        iconImageView.tintColor = card.iconColor
        titleLabel.text       = card.title
        statusIcon.image      = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
        statusIcon.tintColor  = isSelected ? .systemBlue : .systemGray3
        contentView.alpha     = isSelected ? 1.0 : 0.6
    }
}
