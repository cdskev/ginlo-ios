//
//  DPAGMediaPlayerViewController.swift
//  SIMSmeUIMediaLib
//
//  Created by RBU on 22.08.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import AVKit
import SIMSmeCore
import UIKit

public protocol DPAGMediaPlayerViewControllerProtocol: AnyObject {
    var transitioningDelegateTransparent: UIViewControllerTransitioningDelegate? { get set }
}

class DPAGMediaPlayerViewController: DPAGViewControllerBackground, DPAGMediaPlayerViewControllerProtocol {
    var transitioningDelegateTransparent: UIViewControllerTransitioningDelegate?

    @IBOutlet var avPlayerVC: AVPlayerViewController!
    @IBOutlet var viewPlayer: UIView!

    @IBOutlet var viewControlsBackground: UIView! {
        didSet {
            self.viewControlsBackground.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    @IBOutlet var viewControls: UIView!
    @IBOutlet var stackViewControls: UIStackView!
    @IBOutlet var buttonClose: UIButton! {
        didSet {
            self.buttonClose.setImage(DPAGImageProvider.shared[.kImageClose], for: .normal)
            self.buttonClose.tintColor = DPAGColorProvider.shared[.buttonTintNoBackground]
            self.buttonClose.addTargetClosure { [weak self] _ in
                self?.dismiss(animated: true, completion: nil)
            }
        }
    }

    @IBOutlet var labelStart: UILabel! {
        didSet {
            self.labelStart.textColor = DPAGColorProvider.shared[.labelText]
            self.labelStart.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: UIFont.Weight(rawValue: 0))
        }
    }

    @IBOutlet var labelEnd: UILabel! {
        didSet {
            self.labelEnd.textColor = DPAGColorProvider.shared[.labelText]
            self.labelEnd.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: UIFont.Weight(rawValue: 0))
        }
    }

    @IBOutlet var slider: UISlider! {
        didSet {
            self.slider.isContinuous = true
            self.slider.tintColor = DPAGColorProvider.shared[.buttonTintNoBackground]
            self.slider.thumbTintColor = DPAGColorProvider.shared[.buttonTintNoBackground]

            self.slider.addTarget(self, action: #selector(playbackSliderValueChanged(_:)), for: .valueChanged)
            self.slider.addTarget(self, action: #selector(playbackSliderTouchDown(_:)), for: .touchDown)
            self.slider.addTarget(self, action: #selector(playbackSliderTouchUp(_:)), for: .touchUpInside)
            self.slider.addTarget(self, action: #selector(playbackSliderTouchUp(_:)), for: .touchUpOutside)
        }
    }

    @IBOutlet var buttonPlay: UIButton! {
        didSet {
            self.buttonPlay.tintColor = DPAGColorProvider.shared[.buttonOverlayTint]
            self.buttonPlay.backgroundColor = DPAGColorProvider.shared[.buttonOverlayBackground]
            self.buttonPlay.layer.cornerRadius = self.buttonPlay.bounds.size.width / 2
            self.buttonPlay.setImage(DPAGImageProvider.shared[.kImageChatSoundPlay], for: .normal)
            self.buttonPlay.addTarget(self, action: #selector(handlePlayButtonPressed), for: .touchUpInside)
        }
    }

    @IBOutlet var buttonPause: UIButton! {
        didSet {
            self.buttonPause.tintColor = DPAGColorProvider.shared[.buttonOverlayTint]
            self.buttonPause.backgroundColor = DPAGColorProvider.shared[.buttonOverlayBackground]
            self.buttonPause.layer.cornerRadius = self.buttonPause.bounds.size.width / 2
            self.buttonPause.setImage(DPAGImageProvider.shared[.kImageChatSoundStop], for: .normal)
            self.buttonPause.addTarget(self, action: #selector(handlePauseButtonPressed), for: .touchUpInside)
            self.buttonPause.isHidden = true
        }
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.viewControlsBackground.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
                self.buttonClose.tintColor = DPAGColorProvider.shared[.buttonTintNoBackground]
                self.labelStart.textColor = DPAGColorProvider.shared[.labelText]
                self.slider.tintColor = DPAGColorProvider.shared[.buttonTintNoBackground]
                self.slider.thumbTintColor = DPAGColorProvider.shared[.buttonTintNoBackground]
                self.buttonPlay.tintColor = DPAGColorProvider.shared[.buttonOverlayTint]
                self.buttonPlay.backgroundColor = DPAGColorProvider.shared[.buttonOverlayBackground]
                self.buttonPause.tintColor = DPAGColorProvider.shared[.buttonOverlayTint]
                self.buttonPause.backgroundColor = DPAGColorProvider.shared[.buttonOverlayBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    private let playerItem: AVPlayerItem

    private var playbackTimeObserver: Any?

    init(playerItem: AVPlayerItem) {
        self.playerItem = playerItem

        super.init(nibName: nil, bundle: Bundle(for: DPAGMediaPlayerViewController.self))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)

        if parent == nil {
            self.close()
        }
    }

    private func close() {
        self.avPlayerVC.player?.pause()

        if let playbackTimeObserver = self.playbackTimeObserver {
            self.avPlayerVC.player?.removeTimeObserver(playbackTimeObserver)
        }

        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch let error as NSError {
            DPAGLog(error, message: "audioSession setActive error")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.avPlayerVC.view.frame = self.viewPlayer.bounds
        self.avPlayerVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.viewPlayer.addSubview(self.avPlayerVC.view)

//        do
//        {
//            try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
//            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
//            try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
//        }
//        catch let error as NSError
//        {
//            DPAGLog("audioSession error: %@", error)
//        }

        self.avPlayerVC.player = AVPlayer(playerItem: self.playerItem)

        NotificationCenter.default.addObserver(self, selector: #selector(handleVideoFinished(_:)), name: .AVPlayerItemDidPlayToEndTime, object: self.playerItem)

        self.labelStart.text = "0:00"

        let duration = CMTimeGetSeconds(self.playerItem.asset.duration)
        let minutes = Int(duration / 60)
        let seconds = Int(Int(duration) % 60)

        self.labelEnd.text = String(format: "%02i:%02i", minutes, seconds)
        self.slider.maximumValue = Float(duration)

        let interval = CMTimeMultiplyByFloat64(CMTimeMakeWithSeconds(1, preferredTimescale: 1), multiplier: 0.025)

        self.playbackTimeObserver = self.avPlayerVC.player?.addPeriodicTimeObserver(forInterval: interval, queue: nil) { [weak self] currentTime in

            guard let strongSelf = self else { return }

            let duration = CMTimeGetSeconds(strongSelf.playerItem.asset.duration)
            let current = CMTimeGetSeconds(currentTime)

            let currentSeconds = Int(Int(current) % 60)
            let currentMinutes = Int(current / 60)

            let remainingSeconds = Int(Int(duration - current) % 60)
            let remainingMinutes = Int((duration - current) / 60)

            strongSelf.labelEnd?.text = String(format: "-%02i:%02i", remainingMinutes, remainingSeconds)
            strongSelf.labelStart?.text = String(format: "%02i:%02i", currentMinutes, currentSeconds)

            if strongSelf.isSeekingBySlider == false {
                strongSelf.slider?.value = Float(current)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.handlePlayButtonPressed()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    private var isSeekingBySlider = false

    @objc
    private func playbackSliderValueChanged(_ playbackSlider: UISlider) {
        let seconds: Int64 = Int64(playbackSlider.value)
        let targetTime: CMTime = CMTimeMake(value: seconds, timescale: 1)

        self.isSeekingBySlider = true
        self.avPlayerVC.player?.seek(to: targetTime)
        self.isSeekingBySlider = false
    }

    @objc
    private func playbackSliderTouchDown(_: UISlider) {
        self.avPlayerVC.player?.pause()
    }

    @objc
    private func playbackSliderTouchUp(_: UISlider) {
        self.avPlayerVC.player?.play()
    }

    @objc
    private func handlePlayButtonPressed() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .default, options: .defaultToSpeaker)

            try AVAudioSession.sharedInstance().setActive(true)
        } catch let error as NSError {
            DPAGLog(error, message: "audioSession setActive error")
        }

        self.avPlayerVC.player?.play()

        self.buttonPlay.isHidden = true
        self.buttonPause.isHidden = false
    }

    @objc
    private func handlePauseButtonPressed() {
        self.avPlayerVC.player?.pause()

        self.buttonPlay.isHidden = false
        self.buttonPause.isHidden = true
    }

    @objc
    private func handleVideoFinished(_: Notification) {
        self.close()

        self.dismiss(animated: true, completion: nil)
    }
}
