//
//  DPAGVoiceMessageCell.swift
// ginlo
//
//  Created by RBU on 07/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGVoiceMessageLeftCell: DPAGVoiceMessageCell, DPAGChatStreamCellLeft {
    override var accessibilityLabel: String? {
        get {
            String(format: "%@ %@", self.labelInfo?.text ?? "", DPAGLocalizedString("chat.overview.preview.VoiceReceived"))
        }
        set {
            super.accessibilityLabel = newValue
        }
    }

    override func chatTextColor() -> UIColor {
        DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
    }
}

class DPAGVoiceMessageRightCell: DPAGVoiceMessageCell, DPAGChatStreamCellRight {
    override var accessibilityLabel: String? {
        get {
            String(format: "%@ %@", self.labelInfo?.text ?? "", DPAGLocalizedString("chat.overview.preview.VoiceSent"))
        }
        set {
            super.accessibilityLabel = newValue
        }
    }
}

public protocol DPAGVoiceMessageCellProtocol: DPAGMessageCellProtocol, DPAGAudioPlayDelegate, DPAGCellWithProgress {
    func playAudioWithData(_ data: Data)
}

class DPAGVoiceMessageCell: DPAGMessageCell, DPAGVoiceMessageCellProtocol {
    var downloadCompletionBackground: DPAGCompletion?

    static let gifArray: [UIImage]? = {
        var gifImageName = DPAGImageProvider.Name.kImageSoundAnimation.rawValue

        let screenScale = UIScreen.main.scale

        if screenScale > 1 {
            if screenScale > 2 {
                gifImageName += "@3x"
            } else {
                gifImageName += "@2x"
            }
        }

        if let fileUrl = Bundle(for: DPAGVoiceMessageCell.self).resourceURL?.appendingPathComponent(gifImageName, isDirectory: false).appendingPathExtension("gif"), let gifData = try? Data(contentsOf: fileUrl) {
            return UIImage.getGifArrayFromData(gifData)
        }
        return nil
    }()

    @IBOutlet private var labelType: UILabel! {
        didSet {
            self.labelType?.text = DPAGLocalizedString("chats.voiceMessage.title")

            self.labelType?.textAlignment = .left
            self.labelType?.textColor = chatTextColor()
        }
    }

    @IBOutlet private var labelPlay: UILabel! {
        didSet {
            self.labelPlay?.textAlignment = .left
            self.labelPlay?.textColor = chatTextColor()
        }
    }

    @IBOutlet private var imageViewAttachmentArrow: UIImageView? {
        didSet {
            self.imageViewAttachmentArrow?.contentMode = .scaleAspectFit
            self.imageViewAttachmentArrow?.clipsToBounds = true
            self.imageViewAttachmentArrow?.image = DPAGImageProvider.shared[.kImageAttachmentArrow]
        }
    }

    @IBOutlet private var imageViewPlay: UIImageView! {
        didSet {
            self.imageViewPlay.contentMode = .scaleAspectFit
            self.imageViewPlay.clipsToBounds = true
        }
    }

    @IBOutlet private var viewProgress: DPAGCellProgressView?
    @IBOutlet private var viewProgressActivity: UIActivityIndicatorView?

    private var totalDuration: TimeInterval = 0.0
    private var destructionTimeString: String?

    private var daysLeft = 0
    private var hoursLeft = 0
    private var minutesLeft = 0
    private var secondsLeft = 0
    private var hundredsLeft = 0

    override func layoutSubviews() {
        super.layoutSubviews()

        self.labelType.preferredMaxLayoutWidth = self.labelType.frame.width
        self.labelPlay.preferredMaxLayoutWidth = self.labelPlay.frame.width
    }

    override func updateFonts() {
        super.updateFonts()

        self.labelType?.font = UIFont.kFontBody

        self.labelPlay?.font = UIFont.monospacedDigitSystemFont(ofSize: UIFont.kFontCaption1.pointSize, weight: UIFont.Weight(rawValue: 0))
    }

    override func configureCellWithMessage(_ decryptedMessage: DPAGDecryptedMessage, forHeightMeasurement: Bool) {
        let updateDuration = self.decryptedMessage != decryptedMessage

        super.configureCellWithMessage(decryptedMessage, forHeightMeasurement: forHeightMeasurement)

        if updateDuration {
            self.updateDuration()
        }

        self.labelPlay?.text = AudioDurationToString(self.duration)
        self.destructionTimeString = nil

        if forHeightMeasurement == false {
            self.viewProgress?.setProgress(0)
            self.viewProgressActivity?.stopAnimating()
            decryptedMessage.attachmentProgress = 0
            decryptedMessage.cellWithProgress = self

            self.imageViewPlay.image = DPAGImageProvider.shared[.kImageChatSoundPlay]
            self.imageViewPlay.tintColor = chatTextColor()

            if AttachmentHelper.attachmentAlreadySavedForGuid(decryptedMessage.attachmentGuid) || ((decryptedMessage.isReadServerAttachment || (decryptedMessage.isOwnMessage && decryptedMessage.dateDownloaded != nil)) && DPAGApplicationFacade.preferences.isBaMandant == false) {
                self.imageViewPlay.alpha = 1
                self.imageViewAttachmentArrow?.alpha = 0
                self.viewProgress?.isHidden = true
            } else {
                self.imageViewPlay.alpha = 0
                self.imageViewAttachmentArrow?.alpha = 1
                self.viewProgress?.isHidden = false
            }

            self.setLongPressGestureRecognizerForView(self.viewBubble)

            self.viewBubble?.accessibilityLabel = String(format: "%@, %@", self.labelType?.text ?? "", self.labelPlay?.text ?? "")

            self.setCellContentSelectedAction { [weak self] in
                self?.didSelectMessageWithValidBlock({ [weak self] in
                    self?.didSelectValidVoiceRec()
                })
            }
        }
    }

    func didSelectValidVoiceRec() {
        if self.decryptedCheckedMessage() {
            return
        }

        self.streamDelegate?.didSelectValidVoiceRec(self.decryptedMessage, cell: self)
    }

    func playAudioWithData(_ data: Data) {
        if DPAGApplicationFacadeUIBase.audioHelper.audioPlayer?.isPlaying ?? false, DPAGApplicationFacadeUIBase.audioHelper.delegatePlay === self {
            DPAGApplicationFacadeUIBase.audioHelper.stopPlaying()
        } else {
            DPAGApplicationFacadeUIBase.audioHelper.startPlayingWithDelegatePlay(self, data: data)
        }
    }

    func didStartPlaying() {
        self.imageViewPlay?.image = DPAGImageProvider.shared[.kImageChatSoundStop]

        self.totalDuration = DPAGApplicationFacadeUIBase.audioHelper.audioPlayer?.duration ?? 0

        self.labelPlay?.text = AudioDurationToString(self.totalDuration)

        DPAGApplicationFacadeUIBase.audioHelper.delegatePlayMessage = self.decryptedMessage
    }

    func didStopPlaying() {
        self.imageViewPlay?.image = DPAGImageProvider.shared[.kImageChatSoundPlay]

        self.decryptedMessage.markDecryptedMessageAsReadAttachment()

        if self.destructionTimeString == nil {
            self.labelPlay?.text = AudioDurationToString(self.duration)
        } else {
            self.labelPlay?.text = self.destructionTimeString
        }
    }

    func didPlayAudioForTime(_: TimeInterval) {
        let currentDuration = self.totalDuration - (DPAGApplicationFacadeUIBase.audioHelper.audioPlayer?.currentTime ?? 0)
        self.labelPlay?.text = AudioDurationToString(currentDuration)
    }

    var duration: TimeInterval = TimeInterval(0)

    func updateDuration() {
        guard let data = self.decryptedMessage.content?.data(using: .utf8) else {
            self.duration = 0.0
            return
        }

        do {
            if let contentDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [AnyHashable: Any], let durationNum = contentDictionary["duration"] as? NSNumber {
                self.duration = TimeInterval(durationNum.doubleValue)
                return
            }
        } catch {
            DPAGLog(error)
        }

        self.duration = 0
    }

    func showWorkInProgress() {
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
        self.imageViewPlay.alpha = 1
        self.imageViewAttachmentArrow?.alpha = 0
    }

    func hideWorkInProgressWithCompletion(_ completion: @escaping DPAGCompletion) {
        self.viewProgressActivity?.stopAnimating()
        self.viewProgress?.setProgress(1)
        self.imageViewPlay?.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)

        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: { [weak self] in
            guard self != nil else { return }

            self?.imageViewPlay?.alpha = 1
            self?.imageViewPlay?.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }, completion: { [weak self] _ in
            guard self != nil else { return }

            self?.viewProgress?.setProgress(0)
            self?.viewProgress?.isHidden = true
            self?.imageViewAttachmentArrow?.alpha = 0

            UIView.animate(withDuration: TimeInterval(0.2), delay: 0, options: .curveEaseOut, animations: { [weak self] in
                guard self != nil else { return }

                self?.imageViewPlay?.transform = .identity
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

    func AudioDurationToString(_ currentDuration: TimeInterval) -> String {
        String(format: "%02li:%02li", lround(floor(currentDuration / 60.0)) % 60, lround(floor(currentDuration)) % 60)
    }

    override func canPerformForward() -> Bool {
        false
    }
}
