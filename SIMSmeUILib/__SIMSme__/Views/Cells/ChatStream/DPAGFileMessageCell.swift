//
//  DPAGFileMessageCell.swift
//  SIMSme
//
//  Created by RBU on 29/01/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGFileMessageLeftCell: DPAGFileMessageCell, DPAGChatStreamCellLeft {
    override var accessibilityLabel: String? {
        get {
            String(format: "%@ %@", self.labelFileName?.text ?? "", DPAGLocalizedString("chat.overview.preview.FileReceived"))
        }
        set {
            super.accessibilityLabel = newValue
        }
    }

    override func chatTextColor() -> UIColor {
        DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
    }
}

class DPAGFileMessageRightCell: DPAGFileMessageCell, DPAGChatStreamCellRight {
    override var accessibilityLabel: String? {
        get {
            String(format: "%@ %@", self.labelFileName?.text ?? "", DPAGLocalizedString("chat.overview.preview.FileSent"))
        }
        set {
            super.accessibilityLabel = newValue
        }
    }
}

public protocol DPAGFileMessageCellProtocol: DPAGMessageCellProtocol, DPAGCellWithProgress {}

class DPAGFileMessageCell: DPAGMessageCell, DPAGFileMessageCellProtocol {
    var downloadCompletionBackground: DPAGCompletion?

    @IBOutlet var labelFileName: UILabel! {
        didSet {
            self.labelFileName.textColor = chatTextColor()
            self.labelFileName.lineBreakMode = .byTruncatingMiddle
            self.labelFileName.text = nil
        }
    }

    @IBOutlet var labelFileSize: UILabel! {
        didSet {
            self.labelFileSize.textColor = chatTextColor()
            self.labelFileSize.textAlignment = .left
            self.labelFileSize.text = nil
        }
    }

    @IBOutlet var imageViewAttachmentArrow: UIImageView? {
        didSet {
            self.imageViewAttachmentArrow?.contentMode = .scaleAspectFit
            self.imageViewAttachmentArrow?.clipsToBounds = true
            self.imageViewAttachmentArrow?.image = DPAGImageProvider.shared[.kImageAttachmentArrow]
        }
    }

    @IBOutlet var imageViewFileType: UIImageView! {
        didSet {
            self.imageViewFileType.contentMode = .scaleAspectFit
            self.imageViewFileType.clipsToBounds = true
        }
    }

    @IBOutlet var viewProgress: DPAGCellProgressView?
    @IBOutlet var viewProgressActivity: UIActivityIndicatorView?

    override func layoutSubviews() {
        super.layoutSubviews()

        self.labelFileName.preferredMaxLayoutWidth = self.labelFileName.frame.width
        self.labelFileSize.preferredMaxLayoutWidth = self.labelFileSize.frame.width
    }

    override func updateFonts() {
        super.updateFonts()

        self.labelFileName.font = UIFont.kFontBody
        self.labelFileSize.font = UIFont.kFontCaption1
    }

    override func configureCellWithMessage(_ decryptedMessage: DPAGDecryptedMessage, forHeightMeasurement: Bool) {
        super.configureCellWithMessage(decryptedMessage, forHeightMeasurement: forHeightMeasurement)

        let fileName = decryptedMessage.additionalData?.fileName ?? ""

        if let additionalData = decryptedMessage.additionalData {
            self.labelFileName.text = fileName

            if let fileSizeStr = additionalData.fileSize, let fileSize = Int64(fileSizeStr) {
                self.labelFileSize.text = DPAGFormatter.fileSize.string(fromByteCount: fileSize)
            } else if let fileSizeNum = additionalData.fileSizeNum {
                self.labelFileSize.text = DPAGFormatter.fileSize.string(fromByteCount: fileSizeNum.int64Value)
            }
        } else {
            self.labelFileName.text = DPAGLocalizedString("chats.fileMessageCell.title")
            self.labelFileSize.text = ""
        }

        if forHeightMeasurement == false {
            var fileExt = ""
            if let rangeExtension = fileName.range(of: ".", options: .backwards) {
                fileExt = String(fileName[rangeExtension.upperBound...])
            }
            self.imageViewFileType.image = DPAGImageProvider.shared.imageForFileExtension(fileExt)
            self.viewProgress?.setProgress(0)
            self.viewProgressActivity?.stopAnimating()
            decryptedMessage.attachmentProgress = 0
            decryptedMessage.cellWithProgress = self
            if AttachmentHelper.attachmentAlreadySavedForGuid(decryptedMessage.attachmentGuid) || ((decryptedMessage.isReadServerAttachment || (decryptedMessage.isOwnMessage && decryptedMessage.dateDownloaded != nil)) && DPAGApplicationFacade.preferences.isBaMandant == false) {
                self.imageViewFileType?.alpha = 1
                self.imageViewAttachmentArrow?.alpha = 0
                self.viewProgress?.isHidden = true
            } else {
                self.imageViewFileType?.alpha = 0
                self.imageViewAttachmentArrow?.alpha = 1
                self.viewProgress?.isHidden = true
            }
            self.setLongPressGestureRecognizerForView(self.viewBubble)
            self.setCellContentSelectedAction { [weak self] in
                self?.didSelectMessageWithValidBlock({ [weak self] in
                    if DPAGApplicationFacade.preferences.canExportMedia {
                        self?.didSelectValidFile()
                    }
                })
            }
        }
    }

    func showWorkInProgress() {
        self.viewProgress?.setProgress(0)
        self.viewProgress?.isHidden = false
        self.viewProgressActivity?.startAnimating()
        self.isLoadingAttachment = true
    }

    func updateDownloadProgress(_ progress: Progress, isAutoDownload: Bool) {
        if (self.viewProgress?.progressValue ?? -1) == progress.fractionCompleted {
            return
        }

        self.isLoadingAttachment = true
        self.viewProgress?.setProgress(progress.fractionCompleted)

        if progress.fractionCompleted == 1 {
            if isAutoDownload {
                if self.isLoadingAttachment {
                    self.isLoadingAttachment = false
                    self.hideWorkInProgressWithCompletion {}
                }
            } else if (self.viewProgressActivity?.isAnimating ?? false) == false {
                self.viewProgressActivity?.startAnimating()
            }
        } else {
            self.viewProgressActivity?.stopAnimating()
        }
    }

    func cancelWorkInProgress() {
        self.viewProgressActivity?.stopAnimating()
        self.viewProgress?.setProgress(0)
    }

    func hideWorkInProgress() {
        self.viewProgressActivity?.stopAnimating()
        self.viewProgress?.setProgress(0)
        self.viewProgress?.isHidden = true
        self.imageViewFileType?.alpha = 1
        self.imageViewAttachmentArrow?.alpha = 0
    }

    func hideWorkInProgressWithCompletion(_ completion: @escaping DPAGCompletion) {
        self.viewProgressActivity?.stopAnimating()
        self.viewProgress?.setProgress(1)
        self.imageViewFileType?.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)

        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: { [weak self] in
            guard self != nil else { return }

            self?.imageViewFileType?.alpha = 1
            self?.imageViewFileType?.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }, completion: { [weak self] _ in
            guard self != nil else { return }

            self?.viewProgress?.setProgress(0)
            self?.viewProgress?.isHidden = true
            self?.imageViewAttachmentArrow?.alpha = 0

            UIView.animate(withDuration: TimeInterval(0.2), delay: 0, options: .curveEaseOut, animations: { [weak self] in
                guard self != nil else { return }

                self?.imageViewFileType?.transform = .identity
            }, completion: { [weak self] _ in
                guard let strongSelf = self else { return }

                if let downloadCompletionBackground = strongSelf.downloadCompletionBackground {
                    strongSelf.downloadCompletionBackground = nil
                    strongSelf.performBlockInBackground(downloadCompletionBackground)
                }
                completion()
            })
        })
    }

    override func forwardSelectedCell() {
        if self.decryptedCheckedMessage() {
            return
        }

        self.streamDelegate?.loadAttachmentFileWithMessage(decryptedMessage, cell: self)
    }
}
