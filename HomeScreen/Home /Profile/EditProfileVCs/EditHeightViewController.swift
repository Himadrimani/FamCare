//
//  EditHeightViewController.swift
//  HealthSharing
//
//  Created by Mohd Kushaad on 02/02/26.
//

import UIKit

class EditHeightViewController: UIViewController {
    //Constants
    private let baseHeight = 124
    private let pickerRowCount = 100
    private let minimumSheetHeight: CGFloat = 250
    private let sheetHeightMultiplier: CGFloat = 0.5
    private let labelFontSize: CGFloat = 26
    private let sheetIdentifier = "quarter"
    
    var currentHeight: Int! = Int(DataManager.shared.currentUser!.heightCm)
    var onSave: (() -> Void)? //this helps in telling editprofile vc that data is updated when saved is pressed
    
    @IBOutlet weak var heightPicker: UIPickerView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        setViewControllerSizeAndData()
        
        heightPicker.delegate = self
        heightPicker.dataSource = self
    }
 
    
    func setViewControllerSizeAndData() {
        //setting size
        if let sheet = self.sheetPresentationController {
            
            // define size to quarter of screen
            let quarterDetent = UISheetPresentationController.Detent.custom(identifier: .init(sheetIdentifier)) { context in
                // 25% of total height
                return max(context.maximumDetentValue * self.sheetHeightMultiplier, self.minimumSheetHeight)
            }
            
            //Apply the size
            sheet.detents = [quarterDetent]
            
            //shows grabber on the view
            sheet.prefersGrabberVisible = true
            
            //Ensure it stays at quarter size and doesn't expand to full screen
            sheet.largestUndimmedDetentIdentifier = .init(sheetIdentifier)
            
            //setting this nil, make the weightpicker vc close when tap outside of its boundary
            sheet.largestUndimmedDetentIdentifier = nil
            
            //sets the background vc as uninteractive
            self.isModalInPresentation = false
        }
        
        //setting data
        heightPicker.selectRow(currentHeight - baseHeight, inComponent: 0, animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // current weight is fetched form the data model
        setViewControllerSizeAndData()
    }
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        dismiss(animated: true)
    }
    
    @IBAction func saveButtonTapped(_ sender: Any) {
        let newHeight = heightPicker.selectedRow(inComponent: 0) + baseHeight
        
        if newHeight != currentHeight {
            //update value
            DataManager.shared.currentUser?.heightCm = Double(newHeight)
            currentHeight = newHeight
        }
        
        self.onSave?() // notifying editProfileTableVC that i have pressed save, and it needs to update the view.
        dismiss(animated: true)
    }
    
}

extension EditHeightViewController: UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.pickerRowCount
    }
    
}

extension EditHeightViewController: UIPickerViewDelegate {
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        
        let label = UILabel()
        label.textAlignment = .center
        
        label.font = .systemFont(ofSize: self.labelFontSize, weight: .regular)
        label.textColor = .label
        
        let value = self.baseHeight + row
        let unit = "cm"
        label.text = "\(value) \(unit)"
        
        return label
    }
    
}
