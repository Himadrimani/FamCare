//
//  DeleteLaterViewController.swift
//  HealthSharing
//
//  Created by Mohd Kushaad on 09/02/26.
//

import UIKit

class FamilyMembersViewContoller: UIViewController {

    var familyMembers: [Profile]!
    var familyName: String!
    
    
    @IBOutlet weak var showOptionsButton: UIBarButtonItem!
    @IBOutlet weak var membersCollectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        if familyMembers == nil {
            refreshFamilyMembersFromDataManager(reloadCollectionView: false)
        }

        guard let _ = familyMembers else {
            print("didnt work either")
            return
        }
        title = familyName ?? DataManager.shared.family?.familyName ?? "Data not Received"
        
        //registering teh cell
        membersCollectionView.register(UINib(nibName: "FamilyMembersCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "family_member_cell")
        
        //setting up pull-down menu for 'filterButton'
        setShowOptionsButtonAndActions()
        
        membersCollectionView.collectionViewLayout = generateLayout()
        membersCollectionView.dataSource = self
        membersCollectionView.delegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(handleDataManagerUpdate), name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshFamilyMembersFromDataManager(reloadCollectionView: true)
    }

    @objc private func handleDataManagerUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshFamilyMembersFromDataManager(reloadCollectionView: true)
        }
    }

    private func refreshFamilyMembersFromDataManager(reloadCollectionView: Bool) {
        if let currentUserId = DataManager.shared.currentUser?.profileId {
            let localNicknames = SQLiteHelper.shared.fetchRelationshipNicknames(for: currentUserId)
            for (profileId, nickname) in localNicknames
                where !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                DataManager.shared.personalNicknames[profileId] = nickname
            }
        }

        var updatedMembers = DataManager.shared.allProfiles
        if let currentUser = DataManager.shared.currentUser {
            updatedMembers.insert(currentUser, at: 0)
        }
        if !updatedMembers.isEmpty {
            familyMembers = updatedMembers
        }

        familyName = DataManager.shared.family?.familyName ?? familyName
        title = familyName ?? "Data not Received"

        if reloadCollectionView, membersCollectionView != nil {
            membersCollectionView.reloadData()
        }
    }
    
    // MARK: - My code
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "add_member_screen" {
            if let destVC = segue.destination as? AddFamilyMemberViewController {
                destVC.profile = DataManager.shared.currentUser
            }
            return
        }

        guard let memberIndex = membersCollectionView.indexPathsForSelectedItems?.first else { return }
        let selectedMember = familyMembers[memberIndex.row]
        
        if segue.identifier == "view_member_detail" {
            guard let destVC = segue.destination as? ViewMemberTableViewController else { return }
            destVC.member = selectedMember
            print("transferred member detail to next view from familymember vc")
        } else if segue.identifier == "family_to_edit_profile_of_user" {
            guard let destVC = segue.destination as? EditProfileTableViewController else { return }
            destVC.currentUser = selectedMember
        }
    }
    
    func setShowOptionsButtonAndActions() {
        
        let menu = UIMenu(children: [
                UIAction(title: "Add a Member") { _ in
                    print("add member option selected")
//                    self.goToAddMemberScreen()
                    self.performSegue(withIdentifier: "add_member_screen", sender: nil)
                },
                UIAction(title: "Exit group") { _ in
                    print("exit grp option selected")
                }
            ])

        showOptionsButton.menu = menu
    }
    
    private func goToAddMemberScreen() {
        
        //instantiating the screen manually from pressing the button
        let storyboard = UIStoryboard(name: "Profile", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "add_member_screen")
        navigationController?.pushViewController(vc, animated: true)
        
    }
    
    func generateLayout() -> UICollectionViewLayout {
        //first thing is to create the size of the item
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
        //create the item and give the size
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
//        item.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 10)
        
        //creating group size and group
        let grpSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(150))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: grpSize, repeatingSubitem: item, count: 1)
        //adding spacing between item, since we are having multiple items
//        group.interItemSpacing = .fixed(10)
        
        
        
        //creating section
        let section = NSCollectionLayoutSection(group: group)
//        creating space between sections and groups
        section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        //creating space between cards
        section.interGroupSpacing = 10
        
        
        //creating layout
        let layout = UICollectionViewCompositionalLayout(section: section)
        
        return layout
        
    }
    
    
}

extension FamilyMembersViewContoller: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return familyMembers?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "family_member_cell", for: indexPath) as! FamilyMembersCollectionViewCell
        
        cell.configureCell(with: familyMembers[indexPath.row])
        cell.layer.borderWidth = 1
        cell.layer.cornerRadius = 12
        
        return cell
    }
    
}

extension FamilyMembersViewContoller: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let memberIndex = membersCollectionView.indexPathsForSelectedItems?.first
        let selectedMember = familyMembers[memberIndex!.row]
        if isCurrentUser(selectedMember) {
            performSegue(withIdentifier: "family_to_edit_profile_of_user", sender: nil)
        } else {
            performSegue(withIdentifier: "view_member_detail", sender: nil)
        }
    }
    
    private func isCurrentUser(_ member: Profile) -> Bool {
        return member.profileId == DataManager.shared.currentUser?.profileId
    }
}
