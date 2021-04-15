//
//  DPAGTableViewCellTextField.swift
//  SIMSme
//
//  Created by RBU on 15/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

public protocol DPAGTableViewCellTextFieldProtocol: AnyObject {
    var textField: UITextField! { get }
}

class DPAGTableViewCellTextField: UITableViewCell, DPAGTableViewCellTextFieldProtocol {
    @IBOutlet public private(set) var textField: UITextField! {
        didSet {
            self.textField.configureDefault()
            self.textField.clearButtonMode = .whileEditing
            self.textField.returnKeyType = .done
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code

        self.selectionStyle = .none
    }
}
