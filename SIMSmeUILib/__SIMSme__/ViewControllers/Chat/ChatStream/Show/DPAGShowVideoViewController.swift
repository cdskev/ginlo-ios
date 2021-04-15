//
//  DPAGShowVideoViewController.swift
//  SIMSme
//
//  Created by RBU on 12/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVKit
import Photos
import SIMSmeCore
import UIKit

protocol DPAGShowVideoViewControllerProtocol: DPAGDestructionViewControllerProtocol {}

class DPAGShowVideoViewController: DPAGDestructionViewController, DPAGShowVideoViewControllerProtocol {
    private var playerView: UIView?
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private var imageView: UIImageView?
    private var playerStatusBarStyle: UIStatusBarStyle?

    private var labelDesc: UILabel?
    private var imageViewDesc: UIImageView?
    private weak var playButton: UIButton?

//    private var videoData: Data
//    private var imagePreview: UIImage
    private var videoUrl: URL?

    private let mediaResource: DPAGMediaResource

    private var playbackTimeObserver: Any?

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()

        formatter.dateStyle = .none
        formatter.timeStyle = .medium

        return formatter
    }()

    init(messageGuid: String, decMessage: DPAGDecryptedMessage, fromStream streamGuid: String, mediaResource: DPAGMediaResource) {
        self.mediaResource = mediaResource

        super.init(messageGuid: messageGuid, decMessage: decMessage, fromStream: streamGuid)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        self.playerStatusBarStyle ?? super.preferredStatusBarStyle
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        do {
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .default, options: .defaultToSpeaker)

            try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
        } catch let error as NSError {
            DPAGLog(error, message: "audioSession error")
        }

        self.setUpVideoWithData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.configureSelfDestruction()

        self.playerLayer?.isHidden = true
        self.playButton?.center = self.contentView.center

        self.transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in

            if let navigationController = self?.navigationController as? (UINavigationController & DPAGNavigationControllerProtocol) {
                navigationController.copyToolBarStyle(navVCSrc: navigationController)
            }
        }, completion: { [weak self] _ in

            self?.playerView?.frame = self?.contentView.bounds ?? .zero
            self?.playerLayer?.position = self?.playerView?.center ?? .zero
        })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.playerView?.frame = self.contentView.bounds
        self.playerLayer?.position = self.playerView?.center ?? .zero
        self.playerLayer?.isHidden = false

        (self.navigationController as? DPAGNavigationControllerProtocol)?.copyToolBarStyle(navVCSrc: self.navigationController)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { [weak self] _ in

            self?.playerView?.frame = self?.contentView.bounds ?? .zero
            self?.playerLayer?.position = self?.playerView?.center ?? .zero

        }, completion: { [weak self] _ in

            self?.playerView?.frame = self?.contentView.bounds ?? .zero
            self?.playerLayer?.position = self?.playerView?.center ?? .zero
        })
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)

        if parent == nil {
            self.player?.pause()
            if let playbackTimeObserver = self.playbackTimeObserver {
                self.player?.removeTimeObserver(playbackTimeObserver)
            }

            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

            // self.moviePlayerViewController?.view.removeFromSuperview()
            // self.moviePlayerViewController = nil
            // self.viewSlider?.removeFromSuperview()

            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch let error as NSError {
                DPAGLog(error, message: "audioSession setActive error")
            }

            self.navigationController?.setNavigationBarHidden(false, animated: true)
        }
    }

    private func setUpGui() {}

    override var destructionFinishedText: String {
        DPAGLocalizedString("chats.showVideo.destroyedLabel")
    }

    override var pleaseTouchText: String {
        DPAGLocalizedString("chats.showVideo.pleaseTouch")
    }

    override func removeContent() {
        self.player?.pause()
        self.playerView?.removeFromSuperview()
        self.imageViewDesc?.removeFromSuperview()
        self.playButton?.removeFromSuperview()
    }

    private func setUpVideoWithData() {
        let imageView = UIImageView(image: self.mediaResource.preview)

        imageView.frame = self.view.frame
        imageView.autoresizingMask = [.flexibleHeight, .flexibleWidth]

        guard let videoUrl = DPAGFunctionsGlobal.pathForCustomTMPDirectory()?.appendingPathComponent("tempVideoSend", isDirectory: false).appendingPathExtension("mp4") else { return }

        try? self.mediaResource.mediaContent?.write(to: videoUrl, options: [.atomic])

        let video = AVAsset(url: videoUrl)

        if let videoTrack = video.tracks(withMediaType: AVMediaType.video).first {
            DPAGLog("video info show: fps = \(videoTrack.nominalFrameRate), size = %@, bps = \(videoTrack.estimatedDataRate)", NSCoder.string(for: videoTrack.naturalSize))
        }

        let playerView = UIView()
        let playerItem = AVPlayerItem(url: videoUrl)
        let player = AVPlayer(playerItem: playerItem)
        let playerLayer = AVPlayerLayer(player: player)

        playerView.frame = self.contentView.bounds
        playerView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        playerView.alpha = 0

        playerLayer.frame = playerView.bounds

        playerView.layer.addSublayer(playerLayer)

        self.contentView.addSubview(playerView)

        self.contentView.addSubview(imageView)

        self.playerView = playerView
        self.playerLayer = playerLayer
        self.player = player
        self.imageView = imageView
        self.videoUrl = videoUrl

        NotificationCenter.default.addObserver(self, selector: #selector(handleVideoFinished(_:)), name: .AVPlayerItemDidPlayToEndTime, object: self.player?.currentItem)

        self.readyToStart = true

        if (self.decryptedMessage.contentDesc?.isEmpty ?? true) == false {
            let labelDesc = UILabel(frame: self.contentView.bounds)
            let imageViewDesc = UIImageView(frame: labelDesc.bounds)

            labelDesc.text = self.decryptedMessage.contentDesc
            labelDesc.font = .kFontBody
            labelDesc.textColor = .lightText
            labelDesc.shadowColor = .darkText
            labelDesc.shadowOffset = UIFont.kFontShadowOffset
            labelDesc.numberOfLines = 0
            labelDesc.adjustsFontSizeToFitWidth = true

            let locations: [CGFloat] = [0.0, 0.1, 1.0]
            let components: [CGFloat] = [0, 0, 0, 0, 0, 0, 0, 0.3, 0, 0, 0, 0.9]

            imageViewDesc.image = UIImage.gradientImage(size: CGSize(width: 20, height: 30), scale: 0, locations: locations, numLocations: locations.count, components: components)

            self.contentView.addSubview(imageViewDesc)
            imageViewDesc.addSubview(labelDesc)

            labelDesc.translatesAutoresizingMaskIntoConstraints = false
            imageViewDesc.translatesAutoresizingMaskIntoConstraints = false

            [
                self.contentView.constraintLeading(subview: imageViewDesc),
                self.contentView.constraintTrailing(subview: imageViewDesc),
                self.contentView.constraintBottomToTop(bottomView: imageViewDesc, topView: self.selfdestructionFooter),
                self.contentView.topAnchor.constraint(lessThanOrEqualTo: imageViewDesc.topAnchor),
                imageViewDesc.constraintLeadingSafeArea(subview: labelDesc, padding: DPAGConstantsGlobal.kPadding),
                imageViewDesc.constraintTrailingSafeArea(subview: labelDesc, padding: DPAGConstantsGlobal.kPadding),
                imageViewDesc.constraintTopSafeArea(subview: labelDesc, padding: 5),
                imageViewDesc.constraintBottomSafeArea(subview: labelDesc, padding: DPAGConstantsGlobal.kPadding)
            ].activate()

            self.labelDesc = labelDesc
            self.imageViewDesc = imageViewDesc
        }
    }

    @objc
    private func handlePlayButtonPressed() {
        if let imageViewDesc = self.imageViewDesc {
            imageViewDesc.removeFromSuperview()
        }

        self.playerView?.alpha = 1.0
        self.playButton?.alpha = 0

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .default, options: .defaultToSpeaker)

            try AVAudioSession.sharedInstance().setActive(true)
        } catch let error as NSError {
            DPAGLog(error, message: "audioSession setActive")
        }

        self.player?.play()

        UIView.animate(withDuration: 0.02, animations: { [weak self] in

            self?.imageView?.alpha = 0
        })

        self.navigationController?.setNavigationBarHidden(true, animated: true)
        self.navigationController?.setToolbarHidden(true, animated: true)
        self.playerStatusBarStyle = .default
        self.setNeedsStatusBarAppearanceUpdate()

        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration)) { [weak self] in
            self?.contentView?.backgroundColor = .black
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        if !self.hasSelfDestructionStarted, self.readyToStart {
            if !self.messageDeleted, self.decryptedMessage.sendOptions?.countDownSelfDestruction != nil {
                self.countDownStarted()
            }

            self.updateTouchState(true)

            self.playerView?.frame = self.contentView.bounds
            self.playerView?.alpha = 1.0

            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .default, options: .defaultToSpeaker)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch let error as NSError {
                DPAGLog(error, message: "audioSession setActive error")
            }

            self.player?.play()

            UIView.animate(withDuration: 0.02, animations: { [weak self] in

                self?.imageView?.alpha = 0
            })

            if !(self.countdownTimer?.isValid ?? false), !self.hasSelfDestructionStarted {
                self.countdownTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updateCountdownLabel), userInfo: nil, repeats: true)
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)

        if !self.hasSelfDestructionStarted {
            self.updateTouchState(false)
            self.player?.pause()

            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch let error as NSError {
                DPAGLog(error, message: "audioSession setActive error")
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        if !self.hasSelfDestructionStarted {
            self.updateTouchState(false)
            self.player?.pause()

            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch let error as NSError {
                DPAGLog(error, message: "audioSession setActive error")
            }
        }
    }

    override func handleScreenshot() {
        if self.contentView.isHidden == false {
            self.player?.pause()
            self.playerView?.removeFromSuperview()

            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch let error as NSError {
                DPAGLog(error, message: "audioSession setActive error")
            }
        }
        super.handleScreenshot()
    }

    @objc
    private func handleVideoFinished(_: Notification) {
        self.player?.seek(to: CMTimeMake(value: 0, timescale: 1))

        self.player?.play()
    }

    @objc
    private func handleSingleTap(_: UITapGestureRecognizer) {
        let isHidden = self.navigationController?.isNavigationBarHidden ?? false

        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration)) { [weak self] in
            self?.contentView?.backgroundColor = isHidden ? .clear : .black
        }
        self.navigationController?.setNavigationBarHidden(!isHidden, animated: true)
        self.navigationController?.setToolbarHidden(!isHidden, animated: true)
        self.playerStatusBarStyle = isHidden ? nil : .default
        self.setNeedsStatusBarAppearanceUpdate()
    }
}
