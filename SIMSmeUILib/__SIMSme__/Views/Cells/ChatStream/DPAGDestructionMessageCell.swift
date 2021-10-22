//
//  DPAGDestructionMessageCell.swift
// ginlo
//
//  Created by RBU on 06/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGDestructionMessageLeftCell: DPAGDestructionMessageCell, DPAGChatStreamCellLeft {
    private static let nf: NumberFormatter = {
        let nf = NumberFormatter()

        nf.numberStyle = .decimal
        nf.minimumIntegerDigits = 2

        return nf
    }()

    static let gifArray: [UIImage] = {
        var gifImageName = DPAGImageProvider.Name.kImageChatCellOverlayDestructive.rawValue

        var retVal: [UIImage] = []

        for idx in 1 ... 30 {
            if let image = DPAGImageProvider.shared[gifImageName + (DPAGDestructionMessageLeftCell.nf.string(from: NSNumber(value: idx)) ?? "00")] {
                retVal.append(image)
            } else {
                break
            }
        }

        return retVal
    }()

    override func chatTextColor() -> UIColor {
        DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
    }
}

public protocol DPAGDestructionMessageCellProtocol: DPAGMessageCellProtocol, DPAGCellWithProgress {}

class DPAGDestructionMessageCell: DPAGMessageCell, DPAGDestructionMessageCellProtocol {
    var downloadCompletionBackground: DPAGCompletion?

    @IBOutlet var labelShow: UILabel! {
        didSet {
            self.labelShow?.accessibilityIdentifier = "labelShow"
            self.labelShow?.text = nil
            self.labelShow?.textColor = chatTextColor()
        }
    }

    @IBOutlet var labelDestructionDate: UILabel! {
        didSet {
            self.labelDestructionDate?.accessibilityIdentifier = "labelDestructionDate"
            self.labelDestructionDate?.text = nil
            self.labelDestructionDate?.textColor = chatTextColor()
        }
    }

    @IBOutlet var imageViewAttachmentArrow: UIImageView? {
        didSet {
            self.imageViewAttachmentArrow?.contentMode = .scaleAspectFit
            self.imageViewAttachmentArrow?.clipsToBounds = true
            self.imageViewAttachmentArrow?.image = DPAGImageProvider.shared[.kImageAttachmentArrow]
        }
    }

    @IBOutlet var imageViewDestruction: UIImageView! {
        didSet {
            self.imageViewDestruction.contentMode = .scaleAspectFit
            self.imageViewDestruction.clipsToBounds = true
        }
    }

    @IBOutlet var viewProgress: DPAGCellProgressView?
    @IBOutlet var viewProgressActivity: UIActivityIndicatorView?

    override func layoutSubviews() {
        super.layoutSubviews()

        if let labelShow = self.labelShow {
            labelShow.preferredMaxLayoutWidth = labelShow.frame.width
        }
    }

    override func updateFonts() {
        super.updateFonts()

        self.labelShow?.font = UIFont.kFontCalloutBold
    }

    override func configureCellWithMessage(_ decryptedMessage: DPAGDecryptedMessage, forHeightMeasurement: Bool) {
        super.configureCellWithMessage(decryptedMessage, forHeightMeasurement: forHeightMeasurement)
        var dateTypeString: String?
        var hasAttachment = false
        switch decryptedMessage.contentType {
            case .plain:
                dateTypeString = DPAGLocalizedString("chats.destructionMessageCell.textType")
            case .image:
                dateTypeString = DPAGLocalizedString("chats.destructionMessageCell.imageType")
                hasAttachment = true
            case .video:
                dateTypeString = DPAGLocalizedString("chats.destructionMessageCell.videoType")
                hasAttachment = true
            case .voiceRec:
                dateTypeString = DPAGLocalizedString("chats.destructionMessageCell.audioType")
                hasAttachment = true
            case .oooStatusMessage, .location, .contact, .file, .textRSS, .avCallInvitation, .controlMsgNG:
                break
        }
        self.labelShow.text = dateTypeString
        self.labelDestructionDate?.text = decryptedMessage.sendOptions?.timerLabelDestructionCell
        if forHeightMeasurement == false {
            self.viewProgress?.setProgress(0)
            self.viewProgressActivity?.stopAnimating()
            decryptedMessage.attachmentProgress = 0
            decryptedMessage.cellWithProgress = self
            if hasAttachment == false || AttachmentHelper.attachmentAlreadySavedForGuid(decryptedMessage.attachmentGuid) || ((decryptedMessage.isReadServerAttachment || (decryptedMessage.isOwnMessage && decryptedMessage.dateDownloaded != nil)) && DPAGApplicationFacade.preferences.isBaMandant == false) {
                self.imageViewDestruction.alpha = 1
                self.imageViewDestruction.image = nil
                self.imageViewDestruction.animationImages = DPAGDestructionMessageLeftCell.gifArray
                self.imageViewDestruction.animationDuration = 2.2
                self.imageViewDestruction.startAnimating()
                self.imageViewAttachmentArrow?.alpha = 0
                self.viewProgress?.isHidden = true
            } else {
                self.imageViewDestruction.alpha = 0
                self.imageViewDestruction.image = DPAGImageProvider.shared[DPAGImageProvider.Name.kImageChatCellOverlayDestructive.rawValue + "01"]
                self.imageViewDestruction.animationImages = nil
                self.imageViewAttachmentArrow?.alpha = 1
                self.viewProgress?.isHidden = false
            }
            self.setLongPressGestureRecognizerForView(self.viewBubble)
            self.setCellContentSelectedAction { [weak self] in
                self?.didSelectMessageWithValidBlock { [weak self] in
                    guard let strongSelf = self else { return }
                    switch strongSelf.decryptedMessage.contentType {
                        case .plain, .avCallInvitation:
                            if strongSelf.decryptedMessage.errorType != .none, strongSelf.decryptedMessage.errorType != .notChecked {
                                DPAGLog("unsupported content type \(strongSelf.decryptedMessage.contentType)")
                            } else {
                                strongSelf.didSelectValidText()
                            }
                        case .image:
                            strongSelf.didSelectValidImage()
                        case .video:
                            strongSelf.didSelectValidVideo()
                        case .location:
                            strongSelf.didSelectValidLocation()
                        case .voiceRec:
                            strongSelf.didSelectValidVoiceRec()
                        case .file:
                            strongSelf.didSelectValidFile()
                        case .contact, .oooStatusMessage, .textRSS, .controlMsgNG:
                        DPAGLog("unsupported content type \(strongSelf.decryptedMessage.contentType)")
                    }
                }
            }
            var contentTypeDescription = ""
            switch self.decryptedMessage.contentType {
                case .plain, .oooStatusMessage, .textRSS, .avCallInvitation, .controlMsgNG:
                    contentTypeDescription = DPAGLocalizedString("chats.destructionMessageCell.textType")
                case .image:
                    contentTypeDescription = DPAGLocalizedString("chat.overview.preview.imageReceived")
                case .video:
                    contentTypeDescription = DPAGLocalizedString("chat.overview.preview.videoReceived")
                case .location:
                    contentTypeDescription = DPAGLocalizedString("chat.overview.preview.locationReceived")
                case .voiceRec:
                    contentTypeDescription = DPAGLocalizedString("chat.overview.preview.VoiceReceived")
                case .contact:
                    contentTypeDescription = DPAGLocalizedString("chat.overview.preview.contactReceived")
                case .file:
                    contentTypeDescription = DPAGLocalizedString("chat.overview.preview.FileReceived")
            }
            self.accessibilityLabel = String(format: "%@ %@", self.labelInfo?.text ?? "", contentTypeDescription)
        }
    }

    func didSelectValidVoiceRec() {
        if self.decryptedCheckedMessage() {
            return
        }

        if let streamGuid = self.decryptedMessage.streamGuid {
            self.streamDelegate?.loadAttachmentWithMessage(decryptedMessage, cell: self, completion: { [weak self] data, errorString in

                guard let strongSelf = self else { return }

                if let voiceData = data {
                    strongSelf.performBlockOnMainThread { [weak self] in
                        guard let strongSelf = self else { return }

                        strongSelf.streamDelegate?.setUpVoiceRecViewWithData(voiceData, messageGuid: strongSelf.decryptedMessage.messageGuid, decMessage: strongSelf.decryptedMessage, stream: streamGuid)
                    }
                } else if let errorString = errorString {
                    strongSelf.showErrorAlertCheck(alertConfig: UIViewController.AlertConfigError(messageIdentifier: errorString))
                }

            })
        }
    }

    func showWorkInProgress() {
        self.viewProgress?.setProgress(0)
        self.viewProgressActivity?.startAnimating()
        self.imageViewDestruction.image = nil
        self.imageViewDestruction.stopAnimating()
        self.isLoadingAttachment = true
    }

    func updateDownloadProgress(_ progress: Progress, isAutoDownload: Bool) {
        if (self.viewProgress?.progressValue ?? -1) == progress.fractionCompleted {
            return
        }

        self.isLoadingAttachment = true
        self.imageViewDestruction.image = nil
        self.imageViewDestruction.stopAnimating()
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
        self.imageViewDestruction.alpha = 1
        self.imageViewDestruction.image = nil
        self.imageViewDestruction.animationImages = DPAGDestructionMessageLeftCell.gifArray
        self.imageViewDestruction.animationDuration = 2.2
        self.imageViewDestruction.startAnimating()
        self.imageViewAttachmentArrow?.alpha = 0
    }

    func hideWorkInProgressWithCompletion(_ completion: @escaping DPAGCompletion) {
        self.viewProgressActivity?.stopAnimating()
        self.viewProgress?.setProgress(1)
        self.imageViewDestruction.image = DPAGImageProvider.shared[DPAGImageProvider.Name.kImageChatCellOverlayDestructive.rawValue + "01"]
        self.imageViewDestruction.animationImages = nil
        self.imageViewDestruction?.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)

        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: { [weak self] in
            guard self != nil else { return }

            self?.imageViewDestruction?.alpha = 1
            self?.imageViewDestruction?.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }, completion: { [weak self] _ in
            guard self != nil else { return }

            self?.viewProgress?.setProgress(0)
            self?.viewProgress?.isHidden = true
            self?.imageViewAttachmentArrow?.alpha = 0

            UIView.animate(withDuration: TimeInterval(0.2), delay: 0, options: .curveEaseOut, animations: { [weak self] in
                guard self != nil else { return }

                self?.imageViewDestruction?.transform = .identity
            }, completion: { [weak self] _ in
                guard let strongSelf = self else { return }

                if let downloadCompletionBackground = strongSelf.downloadCompletionBackground {
                    strongSelf.downloadCompletionBackground = nil
                    strongSelf.performBlockInBackground(downloadCompletionBackground)
                }
                self?.imageViewDestruction.image = nil
                self?.imageViewDestruction.animationImages = DPAGDestructionMessageLeftCell.gifArray
                self?.imageViewDestruction.animationDuration = 2.2
                self?.imageViewDestruction.startAnimating()
                completion()
            })
        })
    }

    override func canPerformForward() -> Bool {
        if AppConfig.buildConfigurationMode == .DEBUG {
            if self.decryptedMessage is DPAGDecryptedMessageChannel, self.decryptedMessage.contentType == .image {
                return true
            }
        }
        return false
    }

    override func forwardSelectedCell() {
        if self.decryptedCheckedMessage() {
            return
        }

        self.streamDelegate?.loadAttachmentImageWithMessage(self.decryptedMessage, cell: self)
    }
}
