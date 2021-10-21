//
//  DPAGLocationMessageCell.swift
// ginlo
//
//  Created by RBU on 06/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGLocationMessageLeftCell: DPAGLocationMessageCell, DPAGChatStreamCellLeft {
    override var accessibilityLabel: String? {
        get {
            String(format: "%@ %@", self.labelInfo?.text ?? "", DPAGLocalizedString("chat.overview.preview.locationReceived"))
        }
        set {
            super.accessibilityLabel = newValue
        }
    }

    override func chatTextColor() -> UIColor {
        DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
    }
}

class DPAGLocationMessageRightCell: DPAGLocationMessageCell, DPAGChatStreamCellRight {
    override var accessibilityLabel: String? {
        get {
            String(format: "%@ %@", self.labelInfo?.text ?? "", DPAGLocalizedString("chat.overview.preview.locationSent"))
        }
        set {
            super.accessibilityLabel = newValue
        }
    }
}

public protocol DPAGLocationMessageCellProtocol: DPAGMessageCellProtocol {}

class DPAGLocationMessageCell: DPAGMessageCell, DPAGLocationMessageCellProtocol {
    @IBOutlet var labelLocationInfo: UILabel? {
        didSet {
            self.labelLocationInfo?.text = DPAGLocalizedString("chat.location-cell.info-text", comment: "text displayed on location cells within chat stream")
        }
    }

    @IBOutlet var viewLocationImage: UIImageView?

    @IBOutlet var constraintViewLocationImageWidth: NSLayoutConstraint?
    @IBOutlet var constraintViewLocationImageHeight: NSLayoutConstraint?

    override func layoutSubviews() {
        super.layoutSubviews()

        if let labelLocationInfo = self.labelLocationInfo {
            self.labelLocationInfo?.preferredMaxLayoutWidth = labelLocationInfo.frame.width
        }
    }

    override func updateFonts() {
        super.updateFonts()

        self.labelLocationInfo?.font = UIFont.kFontBody
    }

    override func configureCellWithMessage(_ decryptedMessage: DPAGDecryptedMessage, forHeightMeasurement: Bool) {
        super.configureCellWithMessage(decryptedMessage, forHeightMeasurement: forHeightMeasurement)

        var locationDict: [String: Any]?

        if let data = decryptedMessage.content?.data(using: .utf8) {
            do {
                locationDict = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
            } catch {
                DPAGLog(error)
            }
        }

        if let locationDict = locationDict {
            var previewImage: UIImage?

            if let imageDataString = locationDict[DPAGStrings.JSON.Location.PREVIEW] as? String {
                if let imageData = Data(base64Encoded: imageDataString, options: .ignoreUnknownCharacters) {
                    previewImage = UIImage(data: imageData)

                    if (previewImage?.size.width ?? 0) > DPAGConstantsGlobal.kChatMaxWidthObjects {
                        previewImage = UIImage(data: imageData, scale: UIScreen.main.scale)
                    }
                }
            }

            self.setPreviewImage(previewImage)
        } else {
            self.labelLocationInfo?.text = DPAGLocalizedString("internal.error.462", comment: "location was not transmitted correctly")
        }

        if forHeightMeasurement == false {
            self.setLongPressGestureRecognizerForView(self.viewBubble)

            self.viewLocationImage?.accessibilityLabel = self.labelLocationInfo?.text

            self.labelLocationInfo?.textColor = chatTextColor()

            self.setCellContentSelectedAction { [weak self] in
                self?.didSelectMessageWithValidBlock { [weak self] in
                    self?.didSelectValidLocation()
                }
            }
        }
    }

    func setPreviewImage(_ image: UIImage?) {
        guard let imagePreview = image else {
            self.viewLocationImage?.image = nil
            return
        }

        self.viewLocationImage?.image = imagePreview

        /* let size = imagePreview.size

         if (DPAGConstantsGlobal.kChatMaxWidthObjects < size.width)
         {
             self.constraintViewLocationImageWidth?.constant = DPAGConstantsGlobal.kChatMaxWidthObjects
             self.constraintViewLocationImageHeight?.constant = size.height * (DPAGConstantsGlobal.kChatMaxWidthObjects / size.width)
         }
         else
         {
             self.constraintViewLocationImageWidth?.constant = size.width
             self.constraintViewLocationImageHeight?.constant = size.height
         } */
    }

    override func canPerformForward() -> Bool {
        false
    }
}
