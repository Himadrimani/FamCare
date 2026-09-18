//
//  SectionHeaderView.swift
//  HomeScreen
//
//  Created by Himadri  on 30/01/26.
//

import UIKit

protocol SectionHeaderViewDelegate: AnyObject {
    func sectionHeaderDidTapEdit(_ header: SectionHeaderView)
}

class SectionHeaderView: UICollectionReusableView {
    @IBOutlet weak var editButton: UIButton!
    @IBOutlet weak var headerLabel: UILabel!
    
    weak var delegate: SectionHeaderViewDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        editButton.addTarget(self, action: #selector(editButtonTapped(_:)), for: .touchUpInside)
    }
    
    func configure(withTitle title: String, showEditButton: Bool = false) {
        headerLabel.text = title
        editButton.isHidden = !showEditButton
    }
    
    @objc @IBAction func editButtonTapped(_ sender: UIButton) {
        delegate?.sectionHeaderDidTapEdit(self)
    }
}
