//
//  EditProfileTableViewController.swift
//  HealthSharing
//
//  Created by Mohd Kushaad on 27/01/26.
//

import UIKit
import PhotosUI

class EditProfileTableViewController: UITableViewController, PHPickerViewControllerDelegate {

    
    var currentUser: Profile!
    var currentName: String!
    private var isUploadingImage = false
    
    
    @IBOutlet weak var nameLabelSection0: UILabel!
    @IBOutlet weak var firstNameTextField: UITextField!
    @IBOutlet weak var lastNameTextField: UITextField!
    @IBOutlet weak var dobValue: UILabel!
    @IBOutlet weak var heightValue: UILabel!
    @IBOutlet weak var weightValue: UILabel!
    @IBOutlet weak var genderValue: UILabel!
    @IBOutlet weak var profilePicture: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()

        if currentUser != nil  {
            print("data loaded from ProfileMain in editProfile vc")
        } else {  print("data not loaded in editProfile vc"); return }
        
        configureProfileCell()
        firstNameTextField.delegate = self
        lastNameTextField.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataManagerUpdate), name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
    }
    
    @objc private func handleDataManagerUpdate() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isUploadingImage else { return }
            if let updatedUser = DataManager.shared.currentUser {
                self.currentUser = updatedUser
            }
            self.populateUserDataInTheView()
            self.tableView.reloadData()
        }
    }

    // MARK: - My functions
    
    //here prepare function works as a messenger, which tells this vc to reload screen
    //which then automatically calls viewWillAppear(), which reloads new data
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // if weight is called
        if segue.identifier == "toEditWeight" {
            // casting to nav controller first
            if let navVC = segue.destination as? UINavigationController,
               let destVC = navVC.viewControllers.first as? EditWeightViewController {
                
                destVC.onSave = { [weak self] in
                    self?.refreshProfileData() //if save is pressed then this is called
                }
            }
        } else if segue.identifier == "toEditHeight" {
            if let navVC = segue.destination as? UINavigationController,
               let destVC = navVC.viewControllers.first as? EditHeightViewController {
                
                destVC.onSave = { [weak self] in
                    self?.refreshProfileData()
                }
            }
        } else if segue.identifier == "toEditDOB" {
            if let navVC = segue.destination as? UINavigationController,
               let destVC = navVC.viewControllers.first as? EditDOBViewController {
                destVC.onSave = { [weak self] in
                    self?.refreshProfileData()
                }
            }
        }
    }
    
    //used to reload new data when save is tapped in weight/height/dob picker
    private func refreshProfileData() {
        print("DEBUG: Refreshing profile data now.")
        DispatchQueue.main.async {
            if let updatedUser = DataManager.shared.currentUser {
                DataManager.shared.updateProfile(updatedUser)
                self.currentUser = updatedUser
            }
            self.populateUserDataInTheView()
            self.tableView.reloadData()
            print("Data refreshed and Table reloaded")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        //updating variable everytime view appears to have the latest values
        refreshProfileData()
        configureProfileCell()
    }
    
    func populateUserDataInTheView() {
        nameLabelSection0.text = "\(currentUser.firstName) \(currentUser.lastName)"
        ImageManager.shared.setImage(for: profilePicture, from: currentUser.profilePic)
        
        firstNameTextField.text = currentUser.firstName
        lastNameTextField.text = currentUser.lastName
        heightValue.text = "\(Int(currentUser.heightCm)) cm"
        weightValue.text = "\(Int(currentUser.weightKg)) kg"
        genderValue.text = currentUser.gender.rawValue.capitalized
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        dobValue.text = formatter.string(from: currentUser.dob)
    }
    
    func configureProfileCell() {
//        profileName.text = "Admin" //change to take input from data model, later
        
        //turning hte image view into circle
        profilePicture.layer.cornerRadius = profilePicture.frame.size.width / 2
        profilePicture.clipsToBounds = true
        profilePicture.layer.borderWidth = 2
        profilePicture.layer.borderColor = UIColor.white.cgColor
        
        profilePicture.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(profilePictureTapped))
        profilePicture.addGestureRecognizer(tap)
    }
    
    @objc private func profilePictureTapped() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        
        provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            guard let self = self, let image = image as? UIImage else { return }
            DispatchQueue.main.async {
                self.isUploadingImage = true
                self.profilePicture.image = image
                self.showLoadingHUD()
                Task {
                    if let uploadedURL = await ImageManager.shared.uploadImageToSupabase(image, for: self.currentUser.profileId) {
                        var user = self.currentUser!
                        user.profilePic = uploadedURL
                        DataManager.shared.updateProfile(user)
                        self.currentUser = user
                    }
                    DispatchQueue.main.async {
                        self.isUploadingImage = false
                        self.hideLoadingHUD()
                    }
                }
            }
        }
    }
    
    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 && indexPath.row == 4 {
            tableView.deselectRow(at: indexPath, animated: true)
            genderRowTapped()
        }
        
        if indexPath.section == 2 {
            tableView.deselectRow(at: indexPath, animated: true)
            switch indexPath.row {
            case 0:
                promptToChangeGoal(title: "Steps", currentGoal: currentUser.stepGoal) { [weak self] newValue in
                    guard var user = self?.currentUser else { return }
                    user.stepGoal = newValue
                    DataManager.shared.updateProfile(user)
                    self?.currentUser = user
                    tableView.reloadData()
                }
            case 1:
                promptToChangeGoal(title: "Distance", currentGoal: currentUser.distanceGoal) { [weak self] newValue in
                    guard var user = self?.currentUser else { return }
                    user.distanceGoal = newValue
                    DataManager.shared.updateProfile(user)
                    self?.currentUser = user
                    tableView.reloadData()
                }
            case 2:
                promptToChangeGoal(title: "Calories", currentGoal: currentUser.caloriesGoal) { [weak self] newValue in
                    guard var user = self?.currentUser else { return }
                    user.caloriesGoal = newValue
                    DataManager.shared.updateProfile(user)
                    self?.currentUser = user
                    tableView.reloadData()
                }
            case 3:
                promptToChangeGoal(title: "Sleep", currentGoal: Int(currentUser.sleepGoal)) { [weak self] newValue in
                    guard var user = self?.currentUser else { return }
                    user.sleepGoal = Double(newValue)
                    DataManager.shared.updateProfile(user)
                    self?.currentUser = user
                    tableView.reloadData()
                }
            default:
                break
            }
        }
    }

    private func promptToChangeGoal(title: String, currentGoal: Int, onSave: @escaping (Int) -> Void) {
        let alert = UIAlertController(title: "Change \(title) Goal", message: "Enter your new \(title.lowercased()) goal.", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.keyboardType = .numberPad
            textField.text = "\(currentGoal)"
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let text = alert.textFields?.first?.text, let newValue = Int(text) {
                onSave(newValue)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.section == 2 {
            if indexPath.row == 0 {
                cell.detailTextLabel?.text = "\(currentUser.stepGoal) steps"
            } else if indexPath.row == 1 {
                cell.detailTextLabel?.text = "\(currentUser.distanceGoal) m"
            } else if indexPath.row == 2 {
                cell.detailTextLabel?.text = "\(currentUser.caloriesGoal) kcal"
            } else if indexPath.row == 3 {
                cell.detailTextLabel?.text = "\(Int(currentUser.sleepGoal)) hrs"
            }
        }
    }
    
    @objc private func genderRowTapped() {
        let alert = UIAlertController(title: "Select Gender", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Male", style: .default) { [weak self] _ in
            self?.updateGender(.male)
        })
        alert.addAction(UIAlertAction(title: "Female", style: .default) { [weak self] _ in
            self?.updateGender(.female)
        })
        alert.addAction(UIAlertAction(title: "Others", style: .default) { [weak self] _ in
            self?.updateGender(.others)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func updateGender(_ gender: Gender) {
        guard var user = DataManager.shared.currentUser else { return }
        user.gender = gender
        DataManager.shared.updateProfile(user)
        self.currentUser = user
        genderValue.text = gender.rawValue.capitalized
    }

    /*
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)

        // Configure the cell...

        return cell
    }
    */

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


}

extension EditProfileTableViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        guard var user = DataManager.shared.currentUser else { return }
        
        if textField === firstNameTextField {
            let newFirst = (textField.text ?? "").trimmingCharacters(in: .whitespaces)
            guard !newFirst.isEmpty else { return }
            user.firstName = newFirst
        } else if textField === lastNameTextField {
            let newLast = (textField.text ?? "").trimmingCharacters(in: .whitespaces)
            user.lastName = newLast
        }
        
        DataManager.shared.updateProfile(user)
        self.currentUser = user
        nameLabelSection0.text = "\(user.firstName) \(user.lastName)"
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === firstNameTextField {
            lastNameTextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}
