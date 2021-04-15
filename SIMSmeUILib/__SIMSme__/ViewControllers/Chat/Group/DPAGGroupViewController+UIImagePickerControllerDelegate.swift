//
//  DPAGGroupViewController+UIImagePickerControllerDelegate.swift
//  Ginlo
//
//  Created by iso on 2021-01-19
//  Copyright © 2021 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import MobileCoreServices
import Photos
import SIMSmeCore
import UIKit

extension DPAGGroupViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let profileImage = UIImagePickerController.profileImage(withPickerInfo: info) {
            self.imageViewGroup.image = profileImage
            self.needsGroupImageUpdate = true
        }
        picker.dismiss(animated: true, completion: nil)
    }
}
