//
//  EditProfileMainViewController.swift
//  HealthSharing
//
//  Created by Mohd Kushaad on 06/02/26.
//

import UIKit

class ProfileMainTableViewController: UITableViewController {


    var currentUser: Profile!
    var family: Family!
    var familyMembers: [Profile]!

    @IBOutlet weak var userNameTextLabel: UILabel!
    @IBOutlet weak var profilePicture: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataManagerUpdate), name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        refreshData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshData()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func refreshData() {
        if let updatedUser = DataManager.shared.currentUser {
            currentUser = updatedUser
        }
        if let updatedFamily = DataManager.shared.family {
            family = updatedFamily
        }

        var members = DataManager.shared.allProfiles
        if let current = DataManager.shared.currentUser {
            members.insert(current, at: 0)
        }
        familyMembers = members

        configureCell()
        configureConnectSection()
        setupFooterView()
        tableView.reloadData()
    }

    // MARK: - My Functions

    func configureCell() {
        guard currentUser != nil else {
            print("data not received from home to profile")
            return
        }

        ImageManager.shared.setImage(for: profilePicture, from: currentUser.profilePic)
        userNameTextLabel.text = currentUser.displayName

        profilePicture.layer.cornerRadius = profilePicture.frame.size.width / 2
        profilePicture.clipsToBounds = true
        profilePicture.layer.borderWidth = 2
        profilePicture.layer.borderColor = UIColor.white.cgColor
    }

    @objc private func handleDataManagerUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshData()
        }
    }

    private func configureConnectSection() {
        guard let currentUser else { return }

        let snapshot = HealthConnectionSnapshot.make(for: currentUser, mode: .appleHealth)

        if let appleHealthCell = tableView.cellForRow(at: IndexPath(row: 0, section: 2)) {
            var content = appleHealthCell.defaultContentConfiguration()
            content.text = "Apple Health"
            content.secondaryText = snapshot.profileSummaryText
            content.secondaryTextProperties.color = snapshot.syncedMetricCount > 0 ? .secondaryLabel : .systemOrange
            content.image = UIImage(systemName: "heart.text.square.fill")
            content.imageProperties.tintColor = .systemPink
            appleHealthCell.contentConfiguration = content

            // iOS does not expose read grant/deny, but it does tell us whether the
            // permission sheet still needs to be shown. Only surface a prompt in that
            // honest "not requested yet" case — never a false "Permission Denied".
            HealthKitService.shared.readAccessState { [weak self] state in
                guard state == .notRequested else { return }
                DispatchQueue.main.async {
                    guard let cell = self?.tableView.cellForRow(at: IndexPath(row: 0, section: 2)) else { return }
                    var refreshed = cell.defaultContentConfiguration()
                    refreshed.text = "Apple Health"
                    refreshed.secondaryText = "Tap to connect Apple Health"
                    refreshed.secondaryTextProperties.color = .systemOrange
                    refreshed.image = UIImage(systemName: "heart.text.square.fill")
                    refreshed.imageProperties.tintColor = .systemPink
                    cell.contentConfiguration = refreshed
                }
            }
        }

        if let watchCell = tableView.cellForRow(at: IndexPath(row: 1, section: 2)) {
            var content = watchCell.defaultContentConfiguration()
            content.text = "Watch"
            content.secondaryText = snapshot.watchSummaryText
            content.secondaryTextProperties.color = snapshot.syncedMetricCount > 0 ? .secondaryLabel : .systemOrange
            content.image = UIImage(systemName: "applewatch")
            content.imageProperties.tintColor = .label
            watchCell.contentConfiguration = content
        }
    }

    @IBAction func cancelButtonTapped(_ sender: Any) {
        dismiss(animated: true)
    }

    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("segue called: \(segue.identifier ?? "....")")

        if segue.identifier == "edit_profile_cell_to_edit_profile_screen" ||
            segue.identifier == "top_cell_to_edit_profile_screen" {
            if let destVC = segue.destination as? EditProfileTableViewController {
                destVC.currentUser = currentUser
                print("data sent from profile to editProfile vc")
            }
        } else if segue.identifier == "profile_main_to_family_members" {
            if let destVC = segue.destination as? FamilyMembersViewContoller {
                destVC.familyName = family.familyName
                destVC.familyMembers = familyMembers
                print("sent data from profileMain to family vc thru navVC: \(family.familyName). No of members: \(familyMembers?.count ?? 100)")
            }
        }
    }

    // MARK: - Safe Table Footer Actions & Helpers
    
    private func setupFooterView() {
        guard let currentUser = currentUser, let family = family else {
            tableView.tableFooterView = nil
            return
        }

        let isCreator = (family.createdBy == currentUser.profileId)
        
        let padding: CGFloat = 16
        let cardHeight: CGFloat = 48
        let spacing: CGFloat = 10
        let cardCount: CGFloat = isCreator ? 3 : 2
        let totalHeight = (cardHeight * cardCount) + (spacing * (cardCount - 1)) + 24
        
        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: totalHeight))
        footerView.backgroundColor = .clear
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = spacing
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        footerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: padding),
            stackView.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -padding),
            stackView.bottomAnchor.constraint(equalTo: footerView.bottomAnchor, constant: -12)
        ])
        
        if isCreator {
            let refCard = UIView()
            refCard.backgroundColor = .secondarySystemGroupedBackground
            refCard.layer.cornerRadius = 10
            refCard.clipsToBounds = true
            
            let label = UILabel()
            label.text = "Family Referral Code"
            label.font = .systemFont(ofSize: 17, weight: .regular)
            label.textColor = .label
            label.translatesAutoresizingMaskIntoConstraints = false
            refCard.addSubview(label)
            
            let codeLabel = UILabel()
            codeLabel.text = family.sharableCode
            codeLabel.font = .systemFont(ofSize: 17, weight: .regular)
            codeLabel.textColor = .secondaryLabel
            codeLabel.translatesAutoresizingMaskIntoConstraints = false
            refCard.addSubview(codeLabel)
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(copyReferralCodeFromFooter))
            refCard.addGestureRecognizer(tapGesture)
            refCard.isUserInteractionEnabled = true
            
            NSLayoutConstraint.activate([
                label.centerYAnchor.constraint(equalTo: refCard.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: refCard.leadingAnchor, constant: 16),
                
                codeLabel.centerYAnchor.constraint(equalTo: refCard.centerYAnchor),
                codeLabel.trailingAnchor.constraint(equalTo: refCard.trailingAnchor, constant: -16)
            ])
            
            stackView.addArrangedSubview(refCard)
        }
        
        let logoutCard = UIView()
        logoutCard.backgroundColor = .secondarySystemGroupedBackground
        logoutCard.layer.cornerRadius = 10
        logoutCard.clipsToBounds = true
        
        let logoutLabel = UILabel()
        logoutLabel.text = "Log Out"
        logoutLabel.font = .systemFont(ofSize: 17, weight: .regular)
        logoutLabel.textColor = .systemRed
        logoutLabel.textAlignment = .center
        logoutLabel.translatesAutoresizingMaskIntoConstraints = false
        logoutCard.addSubview(logoutLabel)
        
        let logoutTap = UITapGestureRecognizer(target: self, action: #selector(logoutTappedFromFooter))
        logoutCard.addGestureRecognizer(logoutTap)
        logoutCard.isUserInteractionEnabled = true
        
        NSLayoutConstraint.activate([
            logoutLabel.centerXAnchor.constraint(equalTo: logoutCard.centerXAnchor),
            logoutLabel.centerYAnchor.constraint(equalTo: logoutCard.centerYAnchor)
        ])
        
        stackView.addArrangedSubview(logoutCard)
        
        // --- Add Delete Profile Card ---
        let deleteCard = UIView()
        deleteCard.backgroundColor = .secondarySystemGroupedBackground
        deleteCard.layer.cornerRadius = 10
        deleteCard.clipsToBounds = true
        
        let deleteLabel = UILabel()
        deleteLabel.text = "Delete Profile"
        deleteLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        deleteLabel.textColor = .systemRed
        deleteLabel.textAlignment = .center
        deleteLabel.translatesAutoresizingMaskIntoConstraints = false
        deleteCard.addSubview(deleteLabel)
        
        let deleteTap = UITapGestureRecognizer(target: self, action: #selector(deleteProfileTappedFromFooter))
        deleteCard.addGestureRecognizer(deleteTap)
        deleteCard.isUserInteractionEnabled = true
        
        NSLayoutConstraint.activate([
            deleteLabel.centerXAnchor.constraint(equalTo: deleteCard.centerXAnchor),
            deleteLabel.centerYAnchor.constraint(equalTo: deleteCard.centerYAnchor)
        ])
        
        stackView.addArrangedSubview(deleteCard)
        
        tableView.tableFooterView = footerView
    }

    @objc private func copyReferralCodeFromFooter() {
        guard let family = family else { return }
        copyReferralCode(family.sharableCode)
    }

    @objc private func logoutTappedFromFooter() {
        promptLogout()
    }

    @objc private func deleteProfileTappedFromFooter() {
        promptDeleteProfile()
    }
    
    private func promptDeleteProfile() {
        let alert = UIAlertController(
            title: "Delete Profile",
            message: "Are you absolutely sure you want to delete your profile? This action will permanently erase your personal data from both local and remote databases and cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.confirmDeleteProfileDoubleVerification()
        })
        
        present(alert, animated: true)
    }
    
    private func confirmDeleteProfileDoubleVerification() {
        let alert = UIAlertController(
            title: "Final Confirmation Required",
            message: "Type 'DELETE' to confirm you want to permanently erase your profile and all associated data.",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "DELETE"
            textField.autocapitalizationType = .allCharacters
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Permanently Delete", style: .destructive) { [weak self] _ in
            guard let self = self,
                  let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  text == "DELETE" else {
                let errorAlert = UIAlertController(title: "Verification Failed", message: "You did not type 'DELETE' correctly. Profile was not deleted.", preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(errorAlert, animated: true)
                return
            }
            
            guard let profileId = self.currentUser?.profileId else { return }
            
            let spinnerAlert = UIAlertController(title: nil, message: "Permanently deleting your profile...", preferredStyle: .alert)
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.translatesAutoresizingMaskIntoConstraints = false
            spinner.startAnimating()
            spinnerAlert.view.addSubview(spinner)
            
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: spinnerAlert.view.centerXAnchor),
                spinner.bottomAnchor.constraint(equalTo: spinnerAlert.view.bottomAnchor, constant: -20),
                spinnerAlert.view.heightAnchor.constraint(equalToConstant: 100)
            ])
            
            self.present(spinnerAlert, animated: true)
            
            Task {
                do {
                    try await DataManager.shared.deleteProfileAndSignOut(profileId: profileId)
                    await MainActor.run {
                        spinnerAlert.dismiss(animated: true, completion: nil)
                    }
                } catch {
                    await MainActor.run {
                        spinnerAlert.dismiss(animated: true) {
                            let failAlert = UIAlertController(
                                title: "Deletion Failed",
                                message: "We couldn't delete your account right now. Please check your connection and try again.",
                                preferredStyle: .alert
                            )
                            failAlert.addAction(UIAlertAction(title: "OK", style: .default))
                            self.present(failAlert, animated: true)
                        }
                    }
                }
            }
        })
        
        present(alert, animated: true)
    }

    private func promptLogout() {
        let alert = UIAlertController(
            title: "Log Out",
            message: "Are you sure you want to log out?\n\nWe hope to see you soon — take care of yourself and your loved ones. 💛",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Stay", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Log Out", style: .destructive) { _ in
            Task { @MainActor in
                await DataManager.shared.signOut()
            }
        })
        present(alert, animated: true)
    }

    private func copyReferralCode(_ code: String) {
        UIPasteboard.general.string = code
        
        let alert = UIAlertController(
            title: "Copied!",
            message: "Referral code '\(code)' has been copied to your clipboard.",
            preferredStyle: .alert
        )
        present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            alert.dismiss(animated: true, completion: nil)
        }
    }
}

extension ProfileMainTableViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section >= 4 { return 0 }
        return super.tableView(tableView, numberOfRowsInSection: section)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section >= 4 { return nil }
        return super.tableView(tableView, titleForHeaderInSection: section)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section >= 4 { return 0.1 } // Almost invisible
        return super.tableView(tableView, heightForHeaderInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section >= 4 { return 0.1 }
        return super.tableView(tableView, heightForFooterInSection: section)
    }
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 2 {
            return 76
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        let identifier = cell?.reuseIdentifier

        switch identifier {
        case "Notification":
            universalNotificationTapped()
        case "AppleHealth":
            let appleHealthVC = HealthConnectionDetailsViewController(mode: .appleHealth, profile: currentUser)
            navigationController?.pushViewController(appleHealthVC, animated: true)
        case "Watch":
            let watchVC = HealthConnectionDetailsViewController(mode: .appleWatch, profile: currentUser)
            navigationController?.pushViewController(watchVC, animated: true)
        case "CalendarStart", "Subscription":
            let title = identifier ?? "Feature"
            let alert = UIAlertController(title: title, message: "\(title) settings will be available soon.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        default:
            break
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        switch identifier {
        case "edit_profile_cell_to_edit_profile_screen",
             "top_cell_to_edit_profile_screen",
             "profile_main_to_family_members":
            return true
        default:
            return false
        }
    }
}
