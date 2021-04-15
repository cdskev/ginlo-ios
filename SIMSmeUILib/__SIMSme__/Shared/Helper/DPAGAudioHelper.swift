//
//  DPAGAudioHelper.swift
//  SIMSme
//
//  Created by RBU on 08/11/2016.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import SIMSmeCore
import UIKit

public protocol DPAGAudioPlayDelegate: AnyObject {
    func didStartPlaying()
    func didStopPlaying()
    func didPlayAudioForTime(_ time: TimeInterval)
}

public protocol DPAGAudioRecordDelegate: AnyObject {
    func didStartRecording()
    func didStopRecording()
    func didRecordAudioForTime(_ time: TimeInterval)
}

public protocol DPAGAudioHelperProtocol: AnyObject {
    var audioRecorder: AVAudioRecorder? { get }
    var audioPlayer: AVAudioPlayer? { get }

    var timeLastRecording: TimeInterval { get }

    var delegatePlay: DPAGAudioPlayDelegate? { get set }
    var delegatePlayMessage: DPAGDecryptedMessage? { get set }

    func startPlayingWithDelegatePlay(_ delegatePlay: DPAGAudioPlayDelegate, data: Data)
    func stopPlaying()

    func startRecordingWithDelegateRecord(_ delegateRecord: DPAGAudioRecordDelegate)
    func stopRecording()
}

class DPAGAudioHelper: NSObject, DPAGAudioHelperProtocol {
    private var dataPlayer: Data?

    private var microphoneAccessGranted = false

    var audioRecorder: AVAudioRecorder?
    var audioPlayer: AVAudioPlayer?

    weak var delegatePlay: DPAGAudioPlayDelegate?
    weak var delegatePlayMessage: DPAGDecryptedMessage?
    private weak var delegateRecord: DPAGAudioRecordDelegate?

    var timeLastRecording: TimeInterval = TimeInterval(0)

    private var backgroundObserver: NSObjectProtocol?

    private var timerPlay: Timer?
    private var timerRecord: Timer?

    override init() {
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(proximityStateChanged(_:)), name: UIDevice.proximityStateDidChangeNotification, object: nil)

        self.backgroundObserver = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Application.WILL_RESIGN_ACTIVE, object: nil, queue: .main, using: { [weak self] _ in

            self?.stopAll()
        })
    }

    deinit {
        if let backgroundObserver = self.backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
        NotificationCenter.default.removeObserver(self, name: UIDevice.proximityStateDidChangeNotification, object: nil)
    }

    func startPlayingWithDelegatePlay(_ delegatePlay: DPAGAudioPlayDelegate, data: Data) {
        self.stopAll()

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)

            self.audioPlayer = try AVAudioPlayer(data: data, fileTypeHint: "m4a")

            self.audioPlayer?.delegate = self
            self.audioPlayer?.prepareToPlay()
            self.audioPlayer?.play()

            DPAGApplicationFacadeUIBase.proximityHelper.startProximityMonitoring()

            self.delegatePlay = delegatePlay

            delegatePlay.didStartPlaying()

            self.timerPlay = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(timerPlayUpdate), userInfo: nil, repeats: true)
        } catch {
            DPAGLog(error, message: "audioSession error")
        }
    }

    func stopPlaying() {
        self.stopAll()

        DPAGApplicationFacadeUIBase.proximityHelper.stopProximityMonitoring()
    }

    @objc
    private func timerPlayUpdate() {
        if self.audioPlayer?.isPlaying ?? false {
            self.delegatePlay?.didPlayAudioForTime(self.audioPlayer?.currentTime ?? TimeInterval(0))
        } else {
            self.timerPlay?.invalidate()
            self.timerPlay = nil
        }
    }

    func startRecordingWithDelegateRecord(_ delegateRecord: DPAGAudioRecordDelegate) {
        self.stopAll()

        guard let outputUrl = DPAGFunctionsGlobal.pathForVoiceRecording() else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, policy: .default, options: .defaultToSpeaker)
            try AVAudioSession.sharedInstance().setActive(true)

            let recordSettings: [String: Any] = [
                AVFormatIDKey: NSNumber(value: kAudioFormatMPEG4AAC),
                AVEncoderAudioQualityKey: NSNumber(value: AVAudioQuality.min.rawValue),
                AVNumberOfChannelsKey: NSNumber(value: 1),
                AVSampleRateKey: NSNumber(value: 8_000.0)
            ]

            self.audioRecorder = try AVAudioRecorder(url: outputUrl, settings: recordSettings)
            self.audioRecorder?.prepareToRecord()

            self.audioRecorder?.record()

            DPAGApplicationFacadeUIBase.proximityHelper.stopProximityMonitoring()

            DPAGApplicationFacade.preferences.alreadyAskedForMic = true

            AppConfig.setIdleTimerDisabled(true)

            self.delegateRecord = delegateRecord

            self.delegateRecord?.didStartRecording()

            self.timerRecord = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(timerRecordUpdate), userInfo: nil, repeats: true)
        } catch {
            DPAGLog(error, message: "audioSession setActive error")
        }
    }

    func stopRecording() {
        self.stopAll()
    }

    @objc
    private func timerRecordUpdate() {
        if self.audioRecorder?.isRecording ?? false {
            self.delegateRecord?.didRecordAudioForTime(self.audioRecorder?.currentTime ?? TimeInterval(0))
        } else {
            self.timerRecord?.invalidate()
            self.timerRecord = nil
        }
    }

    private func stopAll() {
        if self.audioPlayer?.isPlaying ?? false {
            self.audioPlayer?.stop()
            self.timerPlay?.invalidate()
            self.timerPlay = nil
            self.delegatePlay?.didStopPlaying()
        }

        if self.audioRecorder?.isRecording ?? false {
            self.timeLastRecording = self.audioRecorder?.currentTime ?? TimeInterval(0)
            self.timerRecord?.invalidate()
            self.timerRecord = nil
            self.audioRecorder?.stop()
            self.delegateRecord?.didStopRecording()
        }

        self.delegatePlay = nil
        self.delegatePlayMessage = nil

        self.delegateRecord = nil

        AppConfig.setIdleTimerDisabled(false)

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            DPAGLog(error, message: "audioSession error")
        }

        self.audioPlayer = nil
        self.audioRecorder = nil
    }

    @objc
    private func proximityStateChanged(_ aNotification: Notification?) {
        guard let device = aNotification?.object as? UIDevice else {
            return
        }

        if device.proximityState {
            if self.audioPlayer?.isPlaying ?? false {
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, policy: .default, options: .defaultToSpeaker)
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                } catch {
                    DPAGLog(error, message: "audioSession error")
                }
            }
        } else {
            if self.audioPlayer?.isPlaying ?? false {
                do {
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                } catch {
                    DPAGLog(error, message: "audioSession error")
                }
            }
        }
    }
}

extension DPAGAudioHelper: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            DPAGLog(error, message: "audioSession error")
        }
        if self.delegatePlay != nil {
            self.delegatePlay?.didStopPlaying()
            self.delegatePlay = nil
        }
    }

    func audioPlayerDecodeErrorDidOccur(_: AVAudioPlayer, error: Error?) {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            DPAGLog(error, message: "audioSession error")
        }
        if self.delegatePlay != nil {
            self.delegatePlay?.didStopPlaying()
            self.delegatePlay = nil
        }
    }
}
