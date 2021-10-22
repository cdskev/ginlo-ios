//
//  DPAGMediaContentFileViewController.swift
// ginlo
//
//  Created by RBU on 03/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGMediaContentFileViewController: DPAGMediaContentViewController, DPAGMediaContentFileViewControllerProtocol {
    private weak var labelFileName: UILabel?

    override func setUpGui() {
        self.view.backgroundColor = UIColor.clear

        let labelFileName = UILabel(frame: self.view.frame)
        self.labelFileName = labelFileName

        labelFileName.backgroundColor = UIColor.clear
        labelFileName.translatesAutoresizingMaskIntoConstraints = false

        self.view.addSubview(labelFileName)

        NSLayoutConstraint.activate([
            self.view.constraintCenterX(subview: labelFileName),
            self.view.constraintCenterY(subview: labelFileName),

            self.view.constraintTrailing(subview: labelFileName),
            self.view.constraintBottomGreaterThan(subview: labelFileName),

            self.view.constraintLeading(subview: labelFileName),
            self.view.constraintTrailing(subview: labelFileName)
        ])

        let singleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))

        singleTapRecognizer.numberOfTapsRequired = 1

        self.view.addGestureRecognizer(singleTapRecognizer)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.labelFileName?.textColor = (self.navigationController?.isNavigationBarHidden ?? true) ? DPAGColorProvider.shared[.labelTextForBackgroundInverted] : DPAGColorProvider.shared[.labelText]
    }

    override func preparePresentationWithZoomingRect(_: CGRect) {
        self.customDelegate?.updateBackgroundColor(UIColor.clear)
    }

    override func animatePresentationZoomingRect(_: CGRect) {
        self.customDelegate?.updateBackgroundColor(DPAGColorProvider.shared[.defaultViewBackground])
    }

    override func completePresentationZoomingRect(_: CGRect) {
        // self.handleOpenButtonPressed()
    }

    override func prepareDismissalWithZoomingRect(_: CGRect) {}

    override func animateDismissalZoomingRect(_: CGRect) {
        self.customDelegate?.updateBackgroundColor(UIColor.clear)
    }

    override func completeDismissalZoomingRect(_: CGRect) {}

    override func updateMediaResource() {
        super.updateMediaResource()

        if self.mediaResource.additionalData != nil, self.mediaResource.mediaType == .file {
            let fileName = self.mediaResource.additionalData?.fileName

            self.labelFileName?.text = fileName
            /*
             if let fileSizeStr = mediaResource.additionalData![SIMS_MESSAGE_KEY_FILE_SIZE] as? String, fileSize = Int64(fileSizeStr)
             {
                 self.labelFileSize?.text = DPAGFormatter.fileSize.stringFromByteCount(fileSize)
             }
             else if let fileSizeNum = decryptedMessage.additionalData![SIMS_MESSAGE_KEY_FILE_SIZE] as? NSNumber
             {
             self.labelFileSize?.text = DPAGFormatter.fileSize.stringFromByteCount(fileSizeNum.longLongValue)
             }*/
        }
    }

    override func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
        super.handleSingleTap(recognizer)

        self.labelFileName?.textColor = (self.navigationController?.isNavigationBarHidden ?? true) ? DPAGColorProvider.shared[.labelTextForBackgroundInverted] : DPAGColorProvider.shared[.labelText]
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelFileName?.textColor = (self.navigationController?.isNavigationBarHidden ?? true) ? DPAGColorProvider.shared[.labelTextForBackgroundInverted] : DPAGColorProvider.shared[.labelText]
                self.customDelegate?.updateBackgroundColor(DPAGColorProvider.shared[.defaultViewBackground])
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
