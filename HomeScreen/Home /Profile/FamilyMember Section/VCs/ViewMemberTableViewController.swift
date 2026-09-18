//
//  ViewMemberTableViewController.swift
//  HealthSharing
//
//  Created by Mohd Kushaad on 09/02/26.
//

import UIKit

class ViewMemberTableViewController: UITableViewController {

    var member: Profile!
    
    @IBOutlet weak var nicknameTextField: UITextField!
    @IBOutlet weak var nicknameLabel: UILabel!
    @IBOutlet weak var profilePicture: UIImageView!
    
    @IBOutlet weak var weightValue: UILabel!
    @IBOutlet weak var heightValue: UILabel!
    @IBOutlet weak var dobValue: UILabel!
    @IBOutlet weak var genderValue: UILabel!
    
    @IBOutlet weak var stepsValue: UILabel!
    @IBOutlet weak var distanceValue: UILabel!
    @IBOutlet weak var caloriesValue: UILabel!
    @IBOutlet weak var sleepValue: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureCell()
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataManagerUpdate), name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
    }
    
    @objc private func handleDataManagerUpdate() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Don't interrupt the user while they are typing a nickname
            if self.nicknameTextField.isFirstResponder { return }
            
            if let memberId = self.member?.profileId,
               let updatedMember = DataManager.shared.allProfiles.first(where: { $0.profileId == memberId }) {
                self.member = updatedMember
            } else if let current = DataManager.shared.currentUser, current.profileId == self.member?.profileId {
                self.member = current
            }
            self.configureCell()
        }
    }

    // MARK: - My Code
    
    func configureCell() {
        guard let member = member else { print("didnt receive data in view member vc"); return }

        if member.profileId == DataManager.shared.currentUser?.profileId {
            let selfName = DataManager.shared.getDisplayName(for: member)
            title = selfName
            nicknameLabel.text = selfName
            nicknameTextField.text = selfName
            nicknameTextField.isEnabled = false
            nicknameTextField.textColor = .secondaryLabel
        } else {
            title = "\(member.firstName) \(member.lastName)".trimmingCharacters(in: .whitespaces)
            let displayName = DataManager.shared.getDisplayName(for: member)
            nicknameLabel.text = displayName
            nicknameTextField.text = displayName
            nicknameTextField.isEnabled = true
            nicknameTextField.textColor = .label
        }
        nicknameTextField.delegate = self
        
        // Programmatically center the nickname label since storyboard has it fixed
        nicknameLabel.translatesAutoresizingMaskIntoConstraints = false
        nicknameLabel.centerXAnchor.constraint(equalTo: profilePicture.centerXAnchor).isActive = true
        nicknameLabel.textAlignment = .center
        
        ImageManager.shared.setImage(for: profilePicture, from: member.profilePic)
        profilePicture.layer.cornerRadius = profilePicture.frame.size.width / 2
        profilePicture.clipsToBounds = true
        profilePicture.layer.borderWidth = 2
        
        weightValue.text = "\(Int(member.weightKg)) kg"
        heightValue.text = "\(Int(member.heightCm)) cm"
        dobValue.text = formatDate(member.dob)
        genderValue.text = member.gender.rawValue.capitalized
        
        stepsValue.text = "\(member.stepGoal) steps"
        distanceValue.text = "\(member.distanceGoal) m"
        caloriesValue.text = "\(member.caloriesGoal) kcal"
        if let sleepLabel = sleepValue {
            sleepLabel.text = "\(Int(member.sleepGoal)) hrs"
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Always persist whatever is in the text field when leaving the screen
        guard let member = member,
              member.profileId != DataManager.shared.currentUser?.profileId,
              let newNick = nicknameTextField.text,
              !newNick.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let trimmed = newNick.trimmingCharacters(in: .whitespaces)
        DataManager.shared.savePersonalNickname(targetId: member.profileId, nickname: trimmed)
        print("ViewMember: viewWillDisappear — saved nickname '\(trimmed)' for \(member.firstName)")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: date)
    }
    
    // MARK: - Table view data source

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension ViewMemberTableViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let member = member,
              member.profileId != DataManager.shared.currentUser?.profileId,
              let newNick = textField.text,
              !newNick.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let trimmed = newNick.trimmingCharacters(in: .whitespaces)
        // Update label immediately for visual feedback
        nicknameLabel.text = trimmed
        // Save to DataManager (in-memory + SQLite + Supabase)
        DataManager.shared.savePersonalNickname(targetId: member.profileId, nickname: trimmed)
        print("ViewMember: textFieldDidEndEditing — saved nickname '\(trimmed)' for \(member.firstName)")
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
