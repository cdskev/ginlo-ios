//
//  DPAGTextMessageWithImagePreviewCell.swift
//  SIMSme
//
//  Created by RBU on 07/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGTextMessageWithImagePreviewChannelLeftCell: DPAGTextMessageWithImagePreviewCell, DPAGChatStreamCellLeft {}

public protocol DPAGTextMessageWithImagePreviewCellProtocol: DPAGSimpleMessageCellProtocol, DPAGCellWithProgress {}

class DPAGTextMessageWithImagePreviewCell: DPAGSimpleMessageCell, DPAGTextMessageWithImagePreviewCellProtocol {
    var downloadCompletionBackground: DPAGCompletion?

    @IBOutlet private var viewImage: UIImageView!

    @IBOutlet private var viewProgress: DPAGCellProgressViewLargeChannel?
    @IBOutlet private var viewProgressActivity: UIActivityIndicatorView?
    @IBOutlet private var viewProgressBlur: UIVisualEffectView?

    @IBOutlet private var constraintViewImageHeight: NSLayoutConstraint?

    override func layoutSubviews() {
        super.layoutSubviews()

        if let labelText = self.labelText {
            labelText.preferredMaxLayoutWidth = self.contentView.frame.width - 72
        }
    }

    override func configContentViews() {
        super.configContentViews()

//        self.viewBubbleFrame.layer.cornerRadius = 2
//        self.viewBubbleFrame.layer.masksToBounds = true

        self.viewImage.contentMode = .scaleAspectFit
        self.viewImage.clipsToBounds = true

        self.viewProgress?.fillImage = DPAGImageProvider.shared[.kImageChatCellOverlayImageLoading]
    }

    override func configureCellWithMessage(_ decryptedMessage: DPAGDecryptedMessage, forHeightMeasurement: Bool) {
        super.configureCellWithMessage(decryptedMessage, forHeightMeasurement: forHeightMeasurement)

        var previewImage: UIImage?

        if let imageData = decryptedMessage.imagePreview {
            previewImage = UIImage(data: imageData)

            if (previewImage?.size.width ?? 0) > DPAGConstantsGlobal.kChatMaxWidthObjects {
                previewImage = UIImage(data: imageData, scale: UIScreen.main.scale)
            }
        }

        self.setPreviewImage(previewImage)

        guard forHeightMeasurement == false else { return }

        if AttachmentHelper.attachmentAlreadySavedForGuid(decryptedMessage.attachmentGuid) || ((decryptedMessage.isReadServerAttachment || (decryptedMessage.isOwnMessage && decryptedMessage.dateDownloaded != nil)) && DPAGApplicationFacade.preferences.isBaMandant == false) {
            self.viewProgress?.isHidden = true
            self.viewProgressBlur?.isHidden = true
            self.viewProgressBlur?.alpha = 0
        } else {
            self.viewProgress?.isHidden = false
            self.viewProgressBlur?.isHidden = false
            self.viewProgressBlur?.alpha = 1
        }
        self.viewProgressBlur?.isHidden = true
        self.viewProgressBlur?.alpha = 0

        self.viewProgress?.setProgress(0)
        self.viewProgressActivity?.stopAnimating()
        decryptedMessage.attachmentProgress = 0
        decryptedMessage.cellWithProgress = self

        self.setLongPressGestureRecognizerForView(self.viewBubble)

        self.setCellContentSelectedAction { [weak self] in
            self?.didSelectMessageWithValidBlock({ [weak self] in
                self?.didSelectValidImage()
            })
        }
    }

    func setPreviewImage(_ image: UIImage?) {
        guard let imagePreview = image else {
            self.viewImage.image = nil
            return
        }

        self.viewImage?.image = imagePreview

        let newHeight = min(200, imagePreview.size.height + 20)

        self.constraintViewImageHeight?.constant = newHeight
    }

    override func zoomingViewForNavigationTransition() -> UIView? {
        self.viewImage
    }

    override func chatTextColor() -> UIColor {
        DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
    }

    func showWorkInProgress() {
        self.viewProgress?.isHidden = false
        self.viewProgress?.setProgress(0)
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
            self.viewProgress?.isHidden = true

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
        self.viewProgressBlur?.alpha = 0
    }

    func hideWorkInProgressWithCompletion(_ completion: @escaping DPAGCompletion) {
        self.viewProgressActivity?.stopAnimating()
        self.viewProgress?.setProgress(1)

        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: { [weak self] in
            self?.viewProgressBlur?.alpha = 0
        }, completion: { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.hideWorkInProgress()
            completion()
        })
    }

    override func contentOfCell() -> String? {
        guard let labelText = self.labelText else {
            return nil
        }

        var forwardingText: String?

        if labelText.text != nil {
            forwardingText = labelText.text
        } else if labelText.attributedText != nil {
            forwardingText = labelText.attributedText?.string
        }

        if let forwardingText = forwardingText?.mutableCopy() as? String? {
            if let forwardingTextContent = forwardingText, forwardingTextContent.isEmpty == false {
                for textResultObj in labelText.links {
                    let range = textResultObj.0.rangeValue
                    let url = textResultObj.1
                    let urlString = url.absoluteString

                    if range.length != (urlString as NSString).length {
                        return (forwardingTextContent as NSString).replacingCharacters(in: range, with: urlString)
                    }
                }
            }
        }
        return forwardingText
    }
}
