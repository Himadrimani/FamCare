import re

with open('/Users/mani16/Downloads/ProjectiOS 2/HomeScreen/Home /VCs/HomeViewController.swift', 'r') as f:
    content = f.read()

# Fix refreshChallenges to not reload immediately if we pass a flag, or just aggregate it.
# Actually, we can just change refreshChallenges to NOT reload UI automatically, or we change refreshFromDataManager to call reloadData.
# Let's see:

update_logic = """
        let oldFamilyMembers = familyMembers
        buildFamilyMembers()
        
        let oldWellnessCards = wellnessCards
        loadWellnessData(for: selectedDate)
        
        let oldChallengesCount = ongoingChallenges.count
        self.ongoingChallenges = DataManager.shared.challenges.filter { $0.status == "ongoing" }
        
        setupProfileButton()
        
        var sectionsToReload = IndexSet()
        
        if oldWellnessCards != wellnessCards {
            if oldWellnessCards.count == wellnessCards.count {
                for (index, newCard) in wellnessCards.enumerated() {
                    if oldWellnessCards[index] != newCard {
                        let indexPath = IndexPath(item: index, section: 3)
                        if let cell = homeCollectionView.cellForItem(at: indexPath) as? WellnessCardCell {
                            cell.configure(with: newCard)
                        }
                    }
                }
            } else {
                sectionsToReload.insert(3)
            }
        }
        
        if oldFamilyMembers != familyMembers {
            sectionsToReload.insert(1)
        } else {
            let isPulling = homeCollectionView.refreshControl?.isRefreshing ?? false
            if !isPulling {
                let indexPath = IndexPath(item: 0, section: 1)
                if let cell = homeCollectionView.cellForItem(at: indexPath) as? FamilyActivityScoreCollectionViewCell {
                    cell.configure(members: familyMembers, for: selectedDate)
                }
            }
        }
        
        if ongoingChallenges.count != oldChallengesCount {
            sectionsToReload.insert(2)
        } else {
            // optionally reload section 2 if contents changed
            sectionsToReload.insert(2)
        }
        
        if !sectionsToReload.isEmpty {
            UIView.performWithoutAnimation {
                self.homeCollectionView.reloadSections(sectionsToReload)
            }
        }
    }
    
    @objc func refreshChallenges() {
        self.ongoingChallenges = DataManager.shared.challenges.filter { $0.status == "ongoing" }
        DispatchQueue.main.async { [weak self] in
            if self?.homeCollectionView.numberOfSections ?? 0 > 2 {
                UIView.performWithoutAnimation {
                    self?.homeCollectionView.reloadSections(IndexSet(integer: 2))
                }
            }
        }
    }
"""

# Replace from `let oldFamilyMembers = familyMembers` to the end of `refreshChallenges()`
content = re.sub(r'        let oldFamilyMembers = familyMembers.*?    @objc func refreshChallenges\(\) \{.*?    \}', update_logic, content, flags=re.DOTALL)

with open('/Users/mani16/Downloads/ProjectiOS 2/HomeScreen/Home /VCs/HomeViewController.swift', 'w') as f:
    f.write(content)
