//
//  DPAGVideoMessageCell.swift
//  SIMSme
//
//  Created by RBU on 06/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGVideoMessageLeftCell: DPAGVideoMessageCell, DPAGChatStreamCellLeft {
    override var accessibilityLabel: String? {
        get {
            String(format: "%@ %@", self.labelInfo?.text ?? "", DPAGLocalizedString("chat.overview.preview.videoReceived"))
        }
        set {
            super.accessibilityLabel = newValue
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if let labelDesc = self.labelDesc {
            labelDesc.preferredMaxLayoutWidth = self.contentView.frame.width - 128
        }
    }

    override func chatTextColor() -> UIColor {
        DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
    }
}

class DPAGVideoMessageRightCell: DPAGVideoMessageCell, DPAGChatStreamCellRight {
    override var accessibilityLabel: String? {
        get {
            String(format: "%@ %@", self.labelInfo?.text ?? "", DPAGLocalizedString("chat.overview.preview.videoSent"))
        }
        set {
            super.accessibilityLabel = newValue
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if let labelDesc = self.labelDesc {
            labelDesc.preferredMaxLayoutWidth = self.contentView.frame.width - 128
        }
    }
}

public protocol DPAGVideoMessageCellProtocol: DPAGImageMessageCellProtocol {}

class DPAGVideoMessageCell: DPAGImageMessageCell, DPAGVideoMessageCellProtocol {
    @IBOutlet private var viewPlay: UIImageView? {
        didSet {
            self.viewPlay?.image = DPAGImageProvider.shared[.kImageChatCellOverlayVideoPlay]
            self.viewPlay?.tintColor = DPAGColorProvider.shared[.buttonOverlayTint]
            self.viewPlay?.backgroundColor = DPAGColorProvider.shared[.buttonOverlayBackground]
            self.viewPlay?.layer.cornerRadius = (self.viewPlay?.bounds.size.width ?? 0) / 2
            self.viewPlay?.layer.masksToBounds = true
        }
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.viewPlay?.tintColor = DPAGColorProvider.shared[.buttonOverlayTint]
                self.viewPlay?.backgroundColor = DPAGColorProvider.shared[.buttonOverlayBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    override func configContentViews() {
        super.configContentViews()
        self.viewProgress?.fillImage = DPAGImageProvider.shared[.kImageChatCellOverlayVideoLoading]
    }

    override func configureCellWithMessage(_ decryptedMessage: DPAGDecryptedMessage, forHeightMeasurement: Bool) {
        super.configureCellWithMessage(decryptedMessage, forHeightMeasurement: forHeightMeasurement)

        if forHeightMeasurement == false {
            if AttachmentHelper.attachmentAlreadySavedForGuid(decryptedMessage.attachmentGuid) || ((decryptedMessage.isReadServerAttachment || (decryptedMessage.isOwnMessage && decryptedMessage.dateDownloaded != nil)) && DPAGApplicationFacade.preferences.isBaMandant == false) {
                self.viewPlay?.isHidden = false
            } else {
                self.viewPlay?.isHidden = true
            }
            self.setCellContentSelectedAction { [weak self] in
                self?.didSelectMessageWithValidBlock({ [weak self] in
                    self?.didSelectValidVideo()
                })
            }
            self.viewImage?.accessibilityLabel = DPAGLocalizedString("chats.destructionMessageCell.videoType")
        }
    }

    override func hideWorkInProgress() {
        super.hideWorkInProgress()

        self.viewPlay?.isHidden = false
    }

    override func forwardSelectedCell() {
        if self.decryptedCheckedMessage() {
            return
        }
        let previewImage = self.viewImage?.image
        self.streamDelegate?.loadAttachmentVideoWithMessage(self.decryptedMessage, cell: self, previewImage: previewImage)
    }
}
