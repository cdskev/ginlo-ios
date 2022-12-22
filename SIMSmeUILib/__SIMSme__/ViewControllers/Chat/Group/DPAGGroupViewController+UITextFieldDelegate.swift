//
//  DPAGGroupViewController+UITextFieldDelegate.swift
// ginlo
//
//  Created by iso on 2021-01-19
//  Copyright © 2021 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import MobileCoreServices
import Photos
import SIMSmeCore
import UIKit

extension DPAGGroupViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        var retVal = true
        if let textFieldText = textField.text {
            let text: NSString = textFieldText as NSString
            let resultedString = text.replacingCharacters(in: range, with: string)
            var groupName = resultedString.trimmingCharacters(in: .whitespaces)
            self.highlightRightButton(groupName.isEmpty == false)
            if groupName.count >= DPAGGroupViewController.MAXLENGTH_GROUP_NAME {
                groupName = String(groupName[..<groupName.index(groupName.startIndex, offsetBy: DPAGGroupViewController.MAXLENGTH_GROUP_NAME)])
                textField.text = groupName
                retVal = false
            }
            self.groupName = groupName
        }
        return retVal
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        self.groupName = textField.text?.trimmingCharacters(in: CharacterSet.whitespaces)
        textField.text = self.groupName
        if self.groupName == "" {
            self.highlightRightButton(false)
        } else {
            self.highlightRightButton(true)
        }
    }
}
