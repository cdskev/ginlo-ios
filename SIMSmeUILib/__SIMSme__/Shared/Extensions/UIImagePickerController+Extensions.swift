//
//  UIImagePickerController+Extensions.swift
//  SIMSmeUILib
//
//  Created by Robert Burchert on 09.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import MobileCoreServices
import Photos
import SIMSmeCore
import UIKit

extension UIImagePickerController {
    static func profileImage(withPickerInfo info: [UIImagePickerController.InfoKey: Any]) -> UIImage? {
        guard info[.mediaType] as? String == String(kUTTypeImage) else {
            return nil
        }

        var thumbnailImage: UIImage?

        if let asset = info[.phAsset] as? PHAsset {
            let options = PHImageRequestOptions()

            options.isSynchronous = true
            options.resizeMode = .exact

            PHImageManager.default().requestImage(for: asset, targetSize: DPAGConstantsGlobal.kProfileImageSize, contentMode: .aspectFill, options: options) { image, _ in

                thumbnailImage = image
            }
        } else if let originalImage = info[.originalImage] as? UIImage {
            thumbnailImage = originalImage.thumbnailImage(size: DPAGConstantsGlobal.kProfileImageSize, interpolationQuality: .high)
        }

        return thumbnailImage
    }
}
