//
//  DPAGShowVoiceRecViewController.swift
// ginlo
//
//  Created by RBU on 12/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import SIMSmeCore
import UIKit

protocol DPAGShowVoiceRecViewControllerProtocol: DPAGDestructionViewControllerProtocol {}

class DPAGShowVoiceRecViewController: DPAGDestructionViewController, DPAGAudioPlayDelegate, DPAGShowVoiceRecViewControllerProtocol {
    private weak var imageView: UIImageView?
    private weak var imageViewBack: UIImageView?

    private var voiceData: Data?

    override init(messageGuid: String, decMessage: DPAGDecryptedMessage, fromStream streamGuid: String) {
        super.init(messageGuid: messageGuid, decMessage: decMessage, fromStream: streamGuid)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.configureSelfDestruction()

        self.setUpVoiceRecView()

        self.readyToStart = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        let isPlayingAudio = (DPAGApplicationFacadeUIBase.audioHelper.audioPlayer?.isPlaying ?? false)

        if isPlayingAudio {
            DPAGApplicationFacadeUIBase.audioHelper.stopPlaying()
        }

        self.removeContent()
    }

    override func removeContent() {
        self.stopAudio()
        self.imageView?.removeFromSuperview()
        self.imageViewBack?.removeFromSuperview()
    }

    private func setUpVoiceRecView() {
        var gifImageName = DPAGImageProvider.Name.kImageSoundAnimation.rawValue

        let screenScale = UIScreen.main.scale

        if screenScale > 1 {
            if screenScale > 2 {
                gifImageName += "@3x"
            } else {
                gifImageName += "@2x"
            }
        }

        gifImageName += ".gif"

        var gifArray: [UIImage]?

        if let resourcePath = Bundle(for: type(of: self)).resourcePath, let gifData = try? Data(contentsOf: URL(fileURLWithPath: String(format: "%@/%@", resourcePath, gifImageName))) {
            gifArray = UIImage.getGifArrayFromData(gifData)
        }

        if let imageBackground = DPAGImageProvider.shared[.kImageSoundBackground] { // TODO: check image neccessary
            let imageViewBack = UIImageView(image: imageBackground.imageWithTintColor(DPAGColorProvider.shared[.buttonBackground]))

            imageViewBack.translatesAutoresizingMaskIntoConstraints = false

            let imageView = UIImageView(frame: imageViewBack.frame)

            imageView.contentMode = .scaleToFill
            imageView.translatesAutoresizingMaskIntoConstraints = false

            imageView.animationImages = gifArray
            imageView.animationRepeatCount = 0
            imageView.image = nil

            self.contentView.addSubview(imageViewBack)
            self.contentView.addSubview(imageView)

            NSLayoutConstraint.activate([
                self.contentView.constraintCenterX(subview: imageViewBack),
                self.contentView.constraintCenterY(subview: imageViewBack),

                self.contentView.constraintCenterX(subview: imageView),
                self.contentView.constraintCenterY(subview: imageView),

                imageViewBack.constraintWidth(imageBackground.size.width),
                imageViewBack.constraintHeight(imageBackground.size.height),

                imageView.constraintWidth(imageBackground.size.width),
                imageView.constraintHeight(imageBackground.size.height)
            ])

            self.imageView = imageView
            self.imageViewBack = imageViewBack
        }
    }

    private func didSelectCell() {
        let isPlayingAudio = (DPAGApplicationFacadeUIBase.audioHelper.audioPlayer?.isPlaying ?? false)

        if isPlayingAudio {
            self.stopAudio()
        } else {
            if self.voiceData == nil {
                self.performBlockInBackground { [weak self] in

                    let responseBlock: DPAGServiceResponseBlock = { [weak self] responseObject, _, errorMessage in

                        if let strongSelf = self {
                            if let errorMessage = errorMessage {
                                strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                            } else if responseObject as? String != nil, let attachment = strongSelf.decryptedMessage.decryptedAttachment {
                                DPAGAttachmentWorker.decryptMessageAttachment(attachment: attachment) { data, errorMessage in

                                    if data != nil {
                                        strongSelf.voiceData = data
                                        strongSelf.decryptedMessage.markDecryptedMessageAsReadAttachment()

                                        strongSelf.performBlockOnMainThread { [weak self] in

                                            self?.startAudio()
                                        }
                                    } else if let errorMessage = errorMessage {
                                        strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                                    }
                                }
                            }
                        }
                    }

                    DPAGAttachmentWorker.loadAttachment(self?.decryptedMessage.attachmentGuid, forMessageGuid: self?.decryptedMessage.messageGuid, progress: nil, withResponse: responseBlock)
                }
            } else {
                self.startAudio()
            }
        }
    }

    private func startAudio() {
        if let voiceData = self.voiceData {
            DPAGApplicationFacadeUIBase.audioHelper.startPlayingWithDelegatePlay(self, data: voiceData)

            DPAGApplicationFacadeUIBase.audioHelper.audioPlayer?.numberOfLoops = -1
        }
    }

    func didStartPlaying() {
        self.imageView?.startAnimating()
    }

    private func stopAudio() {
        DPAGApplicationFacadeUIBase.audioHelper.stopPlaying()
    }

    func didStopPlaying() {
        self.imageView?.stopAnimating()
    }

    func didPlayAudioForTime(_: TimeInterval) {}

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        if !self.hasSelfDestructionStarted, self.readyToStart {
            if !self.messageDeleted, self.decryptedMessage.sendOptions?.countDownSelfDestruction != nil {
                self.countDownStarted()
            }

            self.updateTouchState(true)

            if !(self.countdownTimer?.isValid ?? false), !self.hasSelfDestructionStarted {
                self.countdownTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updateCountdownLabel), userInfo: nil, repeats: true)
            }

            self.didSelectCell()
        }
    }

    override func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {
        if !self.hasSelfDestructionStarted {
            self.updateTouchState(false)
        }

        self.didSelectCell()
    }

    override func touchesEnded(_: Set<UITouch>, with _: UIEvent?) {
        if !self.hasSelfDestructionStarted {
            self.updateTouchState(false)
        }

        self.didSelectCell()
    }
}
