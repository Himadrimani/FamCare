//
//  EditWeightViewController.swift
//  HealthSharing
//
//  Created by Mohd Kushaad on 02/02/26.
//

import UIKit


class EditWeightViewController: UIViewController{

    var currentWeight: Int! = Int(DataManager.shared.currentUser!.weightKg)
    var onSave: (() -> Void)?
    
    @IBOutlet weak var weightPicker: UIPickerView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        setViewControllerSizeAndData()
    
        weightPicker.delegate = self
        weightPicker.dataSource = self
    }
    
    // MARK: - My functions
    func setViewControllerSizeAndData() {
        // setting size
        if let sheet = self.sheetPresentationController {
            
            // define size to quarter of screen
            let quarterDetent = UISheetPresentationController.Detent.custom(identifier: .init("quarter")) { context in
                // 25% of total height
                return max(context.maximumDetentValue * 0.5, 250)
            }
            //Apply the size
            sheet.detents = [quarterDetent]
            
            //shows grabber on the view
            sheet.prefersGrabberVisible = true
            //Ensure it stays at quarter size and doesn't expand to full screen
            sheet.largestUndimmedDetentIdentifier = .init("quarter")
            
            //setting this nil, make the weightpicker vc close when tap outside of its boundary
            sheet.largestUndimmedDetentIdentifier = nil
            //sets the background vc as uninteractive
            self.isModalInPresentation = false
        }
        //setting data
        if currentWeight != 0 {
            weightPicker.selectRow(currentWeight! - 30, inComponent: 0, animated: false)
            print("current weight is: \(currentWeight!)")
        } else {
            print("weight is nil, data didnt load")
        }
    }
    
    //func to set default value when the view is opened
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // current weight is fetched form the data model
        setViewControllerSizeAndData()
        
    }
    
    @IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }
    
    
    @IBAction func saveButtonPressed(_ sender: UIBarButtonItem) {
        let newWeight = 30 + weightPicker.selectedRow(inComponent: 0)
        if newWeight != currentWeight {
            DataManager.shared.currentUser?.weightKg = Double(newWeight)
            currentWeight = newWeight
        }
        print("Save button was actually tapped")
        self.onSave?()
        dismiss(animated: true)
    }
    

}

extension EditWeightViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 100 // returns max weight value as 130kg in the picker
    }
    
    
}

extension EditWeightViewController: UIPickerViewDelegate {
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        
        let label = UILabel()
        label.textAlignment = .center
        
        label.font = .systemFont(ofSize: 26, weight: .regular)
        label.textColor = .label
        
        let value = 30 + row
        let unit = "kg"
        label.text = "\(value) \(unit)"
        
        return label
    }
}
