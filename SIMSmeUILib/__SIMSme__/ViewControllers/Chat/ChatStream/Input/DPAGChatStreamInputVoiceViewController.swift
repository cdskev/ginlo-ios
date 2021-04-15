//
//  DPAGChatStreamInputVoiceViewController.swift
//  SIMSme
//
//  Created by RBU on 18/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import HPGrowingTextView
import SIMSmeCore
import UIKit

protocol DPAGChatStreamInputVoiceViewControllerDelegate: DPAGChatStreamInputBaseViewControllerDelegate {
    func inputContainerSendVoiceRec(_ data: Data)

    func inputContainerCanExecuteVoiceRecStart() -> Bool

    func isProximityMonitoringEnabled() -> Bool

    func inputContainerIsVoiceEnabled() -> Bool
}

protocol DPAGChatStreamInputVoiceViewControllerProtocol: DPAGChatStreamInputBaseViewControllerProtocol {
    var audioData: Data? { get }
    var audioDuration: TimeInterval { get set }

    var inputVoiceDelegate: (DPAGChatStreamInputVoiceViewControllerDelegate & DPAGChatStreamSendOptionsContentViewDelegate)? { get set }

    func updateVoiceRecData(_ data: Data)
}

class DPAGChatStreamInputVoiceViewController: DPAGChatStreamInputBaseViewController, DPAGAudioRecordDelegate, DPAGAudioPlayDelegate, DPAGChatStreamInputVoiceViewControllerProtocol {
    private static let nf: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumIntegerDigits = 2
        return nf
    }()

    @IBOutlet var viewVoiceWav: UIImageView! {
        didSet {
            var animationImages: [UIImage] = []
            for idx in 1 ... 30 {
                if let image = DPAGImageProvider.shared[DPAGImageProvider.Name.kImageSoundAnimationInput.rawValue + "_" + (DPAGChatStreamInputVoiceViewController.nf.string(from: NSNumber(value: idx)) ?? "00")] {
                    animationImages.append(image)
                } else {
                    break
                }
            }
            self.viewVoiceWav.image = nil
            self.viewVoiceWav.animationImages = animationImages
            self.viewVoiceWav.animationRepeatCount = 0
        }
    }

    @IBOutlet var btnVoiceDelete: UIButton! {
        didSet {
            self.btnVoiceDelete.accessibilityIdentifier = "btnVoiceDelete"
            self.btnVoiceDelete.accessibilityLabel = DPAGLocalizedString("chats.deleteAttachment.actionSheetDelete")
            self.btnVoiceDelete.setImage(DPAGImageProvider.shared[.kImageChatTrash]?.imageWithTintColor(DPAGColorProvider.shared[.labelText]), for: .normal)
            self.btnVoiceDelete.addTarget(self, action: #selector(handleVoiceTrashButtonPressed), for: .touchUpInside)
        }
    }

    @IBOutlet var btnVoicePlay: UIButton! {
        didSet {
            self.btnVoicePlay.accessibilityIdentifier = "btnVoicePlay"
            self.btnVoicePlay.accessibilityLabel = DPAGLocalizedString("chats.voiceMessage.play")
            self.btnVoicePlay.setImage(DPAGImageProvider.shared[.kImageChatSoundPlay]?.imageWithTintColor(DPAGColorProvider.shared[.labelText]), for: .normal)
            self.btnVoicePlay.addTarget(self, action: #selector(handleVoicePlayButtonPressed), for: .touchUpInside)
        }
    }

    @IBOutlet var btnRecord: UIButton! {
        didSet {
            self.btnRecord.accessibilityIdentifier = "btnRecord"
            self.btnRecord.accessibilityLabel = DPAGLocalizedString("chat.button.record.accessibility.label")
            self.btnRecord.accessibilityHint = DPAGLocalizedString("chat.button.record.accessibility.hint")
            self.btnRecord.setImage(DPAGImageProvider.shared[.kImageChatSoundRecord]?.imageWithTintColor(DPAGColorProvider.shared[.labelText]), for: .normal)
            self.btnRecord.addTarget(self, action: #selector(handleVoiceRecStopped(_:)), for: [.touchCancel, .touchUpInside, .touchUpOutside])
            self.btnRecord.addTarget(self, action: #selector(handleVoiceRecStarted(_:)), for: .touchDown)
        }
    }

    @IBOutlet var btnVoiceStop: UIButton! {
        didSet {
            self.btnVoiceStop.accessibilityIdentifier = "btnVoiceStop"
            self.btnVoiceStop.setImage(DPAGImageProvider.shared[.kImageChatSoundStop]?.imageWithTintColor(DPAGColorProvider.shared[.labelText]), for: .normal)
            self.btnVoiceStop.addTarget(self, action: #selector(handleVoicePlayStopped), for: .touchUpInside)
        }
    }

    @IBOutlet var labelVoiceDuration: UILabel! {
        didSet {
            self.labelVoiceDuration.textColor = DPAGColorProvider.shared[.labelText]
            self.labelVoiceDuration.font = UIFont.kFontCounter
            self.labelVoiceDuration.isHidden = true
        }
    }

    override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.labelVoiceDuration.textColor = DPAGColorProvider.shared[.labelText]
        self.btnVoiceDelete.setImage(DPAGImageProvider.shared[.kImageChatTrash]?.imageWithTintColor(DPAGColorProvider.shared[.labelText]), for: .normal)
        self.btnVoicePlay.setImage(DPAGImageProvider.shared[.kImageChatSoundPlay]?.imageWithTintColor(DPAGColorProvider.shared[.labelText]), for: .normal)
        self.btnRecord.setImage(DPAGImageProvider.shared[.kImageChatSoundRecord]?.imageWithTintColor(DPAGColorProvider.shared[.labelText]), for: .normal)
        self.btnVoiceStop.setImage(DPAGImageProvider.shared[.kImageChatSoundStop]?.imageWithTintColor(DPAGColorProvider.shared[.labelText]), for: .normal)
    }

    var microphoneAccessGranted = false

    var audioDuration: TimeInterval = 0
    var audioData: Data?

    weak var inputVoiceDelegate: (DPAGChatStreamInputVoiceViewControllerDelegate & DPAGChatStreamSendOptionsContentViewDelegate)? {
        didSet {
            self.inputDelegate = self.inputVoiceDelegate
        }
    }

    init() {
        super.init(nibName: "DPAGChatStreamInputVoiceViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func configureGui() {
        super.configureGui()
        self.btnVoiceStop.isHidden = true
        self.btnVoiceDelete.isHidden = true
        self.viewVoiceWav.isHidden = true
        self.btnVoicePlay.isHidden = true
    }

    override func updateSendButtonState() {
        let textViewIsEmpty = self.textView?.text?.isEmpty ?? true
        let isDictation = (self.textView?.internalTextView.textInputMode?.primaryLanguage == "dictation")
        self.btnSend?.isHidden = (textViewIsEmpty && self.microphoneAccessGranted && self.audioData == nil) && ((self.inputVoiceDelegate?.inputContainerIsVoiceEnabled() ?? false) == true)
        self.btnSend.isEnabled = isDictation == false && (textViewIsEmpty == false || self.audioData != nil) && DPAGHelperEx.isNetworkReachable()
    }

    func updateRecordButtonState() {
        let textViewIsEmpty = self.textView?.text?.isEmpty ?? true
        let isDictation = (self.textView?.internalTextView.textInputMode?.primaryLanguage == "dictation")
        self.btnRecord?.isHidden = ((self.inputVoiceDelegate?.inputContainerIsVoiceEnabled() ?? false) && textViewIsEmpty && self.microphoneAccessGranted && self.audioData == nil) == false
        self.btnRecord.isEnabled = isDictation == false && DPAGHelperEx.isNetworkReachable()
    }

    override func updateAddButtonState() {
        let isDictation = (self.textView?.internalTextView.textInputMode?.primaryLanguage == "dictation")
        self.btnAdd?.isHidden = self.audioData != nil
        self.btnAdd?.isEnabled = DPAGHelperEx.isNetworkReachable() && DPAGApplicationFacade.preferences.canSendMedia && isDictation == false
    }

    override func afterSendMessageTapped() {
        super.afterSendMessageTapped()
        if self.lastMessageWasAudio == false {
            self.textView?.becomeFirstResponder()
        }
    }

    override func updateButtonStates() {
        super.updateButtonStates()
        self.updateRecordButtonState()
    }

    override func configureCitation(for decryptedMessage: DPAGDecryptedMessage) {
        super.configureCitation(for: decryptedMessage)
        if self.audioData != nil {
            self.handleVoiceTrashButtonPressed()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.microphoneAccessGranted = DPAGApplicationFacade.preferences.canSendMedia && !DPAGApplicationFacade.preferences.sendMicrophoneDisabled
        self.updateButtonStates()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if DPAGApplicationFacade.preferences.canSendMedia, !DPAGApplicationFacade.preferences.sendMicrophoneDisabled {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                self?.microphoneAccessGranted = granted
                self?.performBlockOnMainThread { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.updateButtonStates()
                    if granted, strongSelf.isProximityMonitoringEnabled() {
                        DPAGApplicationFacadeUIBase.proximityHelper.startMotionMonitoring()
                    }
                }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DPAGApplicationFacadeUIBase.audioHelper.stopPlaying()
        DPAGApplicationFacadeUIBase.proximityHelper.stopMotionMonitoring()
    }

    @objc
    func handleVoiceRecStarted(_: Any?) {
        if (self.inputVoiceDelegate?.inputContainerCanExecuteVoiceRecStart() ?? true) == false {
            return
        }
        self.audioData = nil
        DPAGApplicationFacadeUIBase.audioHelper.startRecordingWithDelegateRecord(self)
    }

    func didStartRecording() {
        self.btnVoiceStop?.isHidden = true
        self.textView?.isHidden = true
        self.updateVoiceDurationLabel(0)
        self.labelVoiceDuration.isHidden = false
        self.btnVoicePlay.isHidden = true
        self.btnVoiceDelete.isHidden = true
        self.viewVoiceWav.isHidden = false
        self.viewVoiceWav.startAnimating()
        self.updateButtonStates()
        self.btnAdd?.isHidden = true
    }

    @objc
    func handleVoiceRecStopped(_ sender: Any?) {
        let isButtonHidden = ((sender as? UIButton)?.isHidden ?? false)
        if isButtonHidden {
            return
        }
        DPAGApplicationFacadeUIBase.audioHelper.stopRecording()
    }

    func didStopRecording() {
        self.audioDuration = DPAGApplicationFacadeUIBase.audioHelper.timeLastRecording
        if let path = DPAGFunctionsGlobal.pathForVoiceRecording() {
            self.audioData = try? Data(contentsOf: path)
        }

        DPAGHelperEx.clearTempFolderFiles(withExtension: "m4a")
        self.handleVoiceRecStoppedInternal()
    }

    func handleVoiceRecStoppedInternal() {
        self.btnVoicePlay.isHidden = false
        self.viewVoiceWav.stopAnimating()
        self.viewVoiceWav.isHidden = true
        self.btnVoiceStop?.isHidden = true
        self.btnVoiceDelete.isHidden = false
        if self.audioDuration < 1 {
            self.handleVoiceTrashButtonPressed()
        } else {
            self.textView?.resignFirstResponder()
            self.updateButtonStates()
            self.inputDelegate?.inputContainerTextViewDidChange()
        }
    }

    @objc
    func handleVoicePlayButtonPressed() {
        if let audioData = self.audioData {
            DPAGApplicationFacadeUIBase.audioHelper.startPlayingWithDelegatePlay(self, data: audioData)
        }
    }

    func didStartPlaying() {
        self.viewVoiceWav.isHidden = false
        self.viewVoiceWav.startAnimating()
        self.btnVoicePlay.isHidden = true
        self.btnVoiceStop.isHidden = false
        self.didPlayAudioForTime(TimeInterval(0))
    }

    @objc
    func handleVoicePlayStopped() {
        DPAGApplicationFacadeUIBase.audioHelper.stopPlaying()
    }

    func didStopPlaying() {
        if self.audioData != nil {
            self.updateVoiceDurationLabel(self.audioDuration)
            self.viewVoiceWav.stopAnimating()
            self.btnVoicePlay.isHidden = false
            self.btnVoiceStop.isHidden = true
        }
    }

    @objc
    func handleVoiceTrashButtonPressed() {
        DPAGApplicationFacadeUIBase.audioHelper.stopPlaying()
        self.audioData = nil
        self.labelVoiceDuration.isHidden = true
        self.btnVoicePlay.isHidden = true
        self.btnVoiceDelete.isHidden = true
        self.textView?.isHidden = false
        self.resetSendOptions()
        self.updateButtonStates()
    }

    func handleMuteButtonPressed() {}

    func didPlayAudioForTime(_ time: TimeInterval) {
        self.updateVoiceDurationLabel(time)
    }

    func didRecordAudioForTime(_ time: TimeInterval) {
        self.updateVoiceDurationLabel(time)
    }

    func updateVoiceRecData(_ data: Data) {
        DPAGApplicationFacadeUIBase.audioHelper.stopRecording()
        self.didStartRecording()
        if let audioPlayer = try? AVAudioPlayer(data: data) {
            self.audioDuration = audioPlayer.duration
            self.updateVoiceDurationLabel(self.audioDuration)
        }
        self.audioData = data
        self.handleVoiceRecStoppedInternal()
        self.isVoiceMediaLoaded = true
    }

    func updateVoiceDurationLabel(_ interval: TimeInterval) {
        self.labelVoiceDuration.text = String(format: "%02li:%02li", lround(floor(interval / 60.0)) % 60, lround(floor(interval)) % 60)
    }

    // War die letzte Nachricht eine Audionachricht
    var lastMessageWasAudio: Bool = false

    override func executeSendTapped() {
        if let audioData = self.audioData {
            self.lastMessageWasAudio = true
            DPAGApplicationFacadeUIBase.audioHelper.stopPlaying()
            self.inputVoiceDelegate?.inputContainerSendVoiceRec(audioData)
            self.audioData = nil
            self.labelVoiceDuration.isHidden = true
            self.btnVoicePlay.isHidden = true
            self.btnVoiceDelete.isHidden = true
            self.textView?.isHidden = false
            self.resetSendOptions()
            self.updateButtonStates()
        } else {
            self.lastMessageWasAudio = false
            super.executeSendTapped()
        }
    }

    override func growingTextView(_ growingTextView: HPGrowingTextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let isRecording = (DPAGApplicationFacadeUIBase.audioHelper.audioRecorder?.isRecording ?? false)
        if isRecording {
            return false
        }
        return growingTextView.text != nil ? (growingTextView.text.count - range.length + text.count < 4_000) : true
    }

    func isProximityMonitoringEnabled() -> Bool {
        DPAGApplicationFacade.preferences.proximityMonitoringEnabled && self.microphoneAccessGranted && (self.inputVoiceDelegate?.isProximityMonitoringEnabled() ?? false)
    }

    override func addObserverForNotifications() {
        super.addObserverForNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(proximityStateChanged(_:)), name: UIDevice.proximityStateDidChangeNotification, object: nil)
    }

    override func removeObserverForNotifications() {
        super.removeObserverForNotifications()
        NotificationCenter.default.removeObserver(self, name: UIDevice.proximityStateDidChangeNotification, object: nil)
    }

    @objc
    func proximityStateChanged(_ aNotification: Notification?) {
        guard let device = aNotification?.object as? UIDevice else { return }
        if device.proximityState {
            if (DPAGApplicationFacadeUIBase.audioHelper.audioPlayer?.isPlaying ?? false) == false, self.audioData == nil, (DPAGApplicationFacadeUIBase.audioHelper.audioRecorder?.isRecording ?? false) == false, (DPAGSendMessageViewOptions.sharedInstance.selfDestructionEnabled ?? false) == false, self.textView?.text?.isEmpty ?? true {
                self.handleVoiceRecStarted(nil)
            }
        } else {
            if self.audioData == nil, DPAGApplicationFacadeUIBase.audioHelper.audioRecorder?.isRecording ?? false {
                self.handleVoiceRecStopped(nil)
            }
        }
    }
}
