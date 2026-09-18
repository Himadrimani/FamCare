//
//  EditDOBViewController.swift
//  HealthSharing
//

import UIKit

class EditDOBViewController: UIViewController {

var currentDOB: Date = Date()

var onSave: (() -> Void)?

@IBOutlet weak var datePicker: UIDatePicker!

override func viewDidLoad() {
    super.viewDidLoad()

    guard let user = DataManager.shared.currentUser else {
        print("User missing in DOB VC")
        dismiss(animated: true)
        return
    }

    currentDOB = user.dob
    setViewControllerSizeAndData()
}

func setViewControllerSizeAndData() {

    if let sheet = self.sheetPresentationController {

        sheet.detents = [.medium()]
        sheet.prefersGrabberVisible = true
        sheet.largestUndimmedDetentIdentifier = nil
        self.isModalInPresentation = false
    }

    datePicker.maximumDate = Date()
    datePicker.date = currentDOB
}

    @IBAction func saveButtonTapped(_ sender: Any) {

    let newDate = datePicker.date

    if newDate != currentDOB {
        DataManager.shared.currentUser?.dob = newDate
        currentDOB = newDate
    }

    onSave?()
    dismiss(animated: true)

    }


@IBAction func cancelButtonTapped(_ sender: UIBarButtonItem) {
    dismiss(animated: true)
}

}
