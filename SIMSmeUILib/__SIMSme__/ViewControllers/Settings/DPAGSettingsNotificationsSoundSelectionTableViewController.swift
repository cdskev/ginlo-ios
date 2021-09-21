//
//  DPAGSettingsNotificationsSoundSelectionTableTableViewController.swift
//  SIMSmeUISettingsLib
//
//  Created by Robert Burchert on 28.01.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import AVKit
import SIMSmeCore
import UIKit

class DPAGSettingsNotificationsSoundSelectionTableViewController: DPAGSettingsTableViewControllerBase, DPAGViewControllerNavigationTitleBig {
    fileprivate enum Sections: Int, CaseCountable {
        case sounds
    }

    fileprivate enum RowsSounds: Int, CaseCountable {
        case `default`, simsme, astral, balaphonia, blessing, blissful, chilling, droplets, glassian, glockenspiel, kalimba, marimba, nylon, piano, strings
    }

    private var soundType: DPAGNotificationChatType
    private var currentTune: String
    private var newTune: String?
    private var selectedIndexPath = IndexPath(row: RowsSounds.default.rawValue, section: Sections.sounds.rawValue)
    var audioPlayer: AVAudioPlayer?

    init(soundType: DPAGNotificationChatType) {
        self.soundType = soundType
        switch soundType {
            case .single:
                self.currentTune = DPAGApplicationFacade.preferences[DPAGPreferences.PropString.kChatRingtone] ?? DPAGPreferences.kValueNotificationSoundDefault
            case .group:
                self.currentTune = DPAGApplicationFacade.preferences[DPAGPreferences.PropString.kGroupChatRingtone] ?? DPAGPreferences.kValueNotificationSoundDefault
            case .channel:
                self.currentTune = DPAGApplicationFacade.preferences[DPAGPreferences.PropString.kChannelChatRingtone] ?? DPAGPreferences.kValueNotificationSoundDefault
        }
        super.init(style: .grouped)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = DPAGLocalizedString("settings.notification.sounds")
        self.tableView.rowHeight = UITableView.automaticDimension
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelView))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(saveView))
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.audioPlayer?.stop()
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            DPAGLog(error, message: "audioSession error")
        }
        self.audioPlayer = nil
    }

    @objc
    private func cancelView() {
        self.dismiss(animated: true, completion: nil)
    }

    @objc
    private func saveView() {
        let oldValue = self.currentTune
        if let newValue = self.newTune, self.currentTune != newValue {
            let soundType = self.soundType
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
                switch soundType {
                    case .single:
                        DPAGApplicationFacade.preferences[DPAGPreferences.PropString.kChatRingtone] = newValue
                    case .group:
                        DPAGApplicationFacade.preferences[DPAGPreferences.PropString.kGroupChatRingtone] = newValue
                    case .channel:
                        DPAGApplicationFacade.preferences[DPAGPreferences.PropString.kChannelChatRingtone] = newValue
                }
                DPAGNotificationWorker.setNotificationSoundEnabled(true, forChatType: soundType) { [weak self] _, _, errorMessage in
                    if let errorMessage = errorMessage {
                        switch soundType {
                            case .single:
                                DPAGApplicationFacade.preferences[DPAGPreferences.PropString.kChatRingtone] = oldValue
                            case .group:
                                DPAGApplicationFacade.preferences[DPAGPreferences.PropString.kGroupChatRingtone] = oldValue
                            case .channel:
                                DPAGApplicationFacade.preferences[DPAGPreferences.PropString.kChannelChatRingtone] = oldValue
                        }
                        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                            self?.tableView.reloadData()
                            self?.presentErrorAlert(alertConfig: UIViewController.AlertConfigError(messageIdentifier: errorMessage))
                        }
                    } else {
                        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                            NotificationCenter.default.post(name: DPAGStrings.Notification.ChatStream.NOTIFICATION_SOUND_CHANGED, object: nil, userInfo: [DPAGStrings.Notification.ChatStream.NOTIFICATION_SOUND_CHANGED__USERINFO_KEY__CHAT_TYPE: soundType])
                            self?.dismiss(animated: true, completion: nil)
                        }
                    }
                }
            }
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }
}

extension DPAGSettingsNotificationsSoundSelectionTableViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        Sections.caseCount
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Sections.forIndex(section) {
            case .sounds:
                return RowsSounds.caseCount
        }
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell?
        if Sections.forIndex(indexPath.section) == .sounds {
            cell = self.cellForDefaultRow(indexPath)
            var rowTune = DPAGPreferences.kValueNotificationSoundDefault
            switch RowsSounds.forIndex(indexPath.row) {
                case .default:
                    rowTune = DPAGPreferences.kValueNotificationSoundDefault
                case .simsme:
                    rowTune = DPAGChatRingtones.SIMSme.rawValue
                case .astral:
                    rowTune = DPAGChatRingtones.Astral.rawValue
                case .balaphonia:
                    rowTune = DPAGChatRingtones.Balaphonia.rawValue
                case .blessing:
                    rowTune = DPAGChatRingtones.Blessing.rawValue
                case .blissful:
                    rowTune = DPAGChatRingtones.Blissful.rawValue
                case .chilling:
                    rowTune = DPAGChatRingtones.Chilling.rawValue
                case .droplets:
                    rowTune = DPAGChatRingtones.Droplets.rawValue
                case .glassian:
                    rowTune = DPAGChatRingtones.Glassian.rawValue
                case .glockenspiel:
                    rowTune = DPAGChatRingtones.Glockenspiel.rawValue
                case .kalimba:
                    rowTune = DPAGChatRingtones.Kalimba.rawValue
                case .marimba:
                    rowTune = DPAGChatRingtones.Marimba.rawValue
                case .nylon:
                    rowTune = DPAGChatRingtones.Nylon.rawValue
                case .piano:
                    rowTune = DPAGChatRingtones.Piano.rawValue
                case .strings:
                    rowTune = DPAGChatRingtones.Strings.rawValue
            }
            cell?.textLabel?.text = DPAGLocalizedString("settings.notification.selectedTune." + rowTune.prefix(while: { (c) -> Bool in
                c != "."
            }))
            if rowTune == (self.newTune ?? self.currentTune) {
                cell?.accessoryType = .checkmark
                self.selectedIndexPath = indexPath
            } else {
                cell?.accessoryType = .none
            }
        }
        cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)"
        cell?.backgroundColor = DPAGColorProvider.shared[.settingsBackground]
        return cell ?? self.cellForHiddenRow(indexPath)
    }
}

extension DPAGSettingsNotificationsSoundSelectionTableViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.cellForRow(at: self.selectedIndexPath)?.accessoryType = .none
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        self.selectedIndexPath = indexPath
        self.audioPlayer?.stop()
        if Sections.forIndex(indexPath.section) == .sounds {
            let newValue: String
            switch RowsSounds.forIndex(indexPath.row) {
                case .default:
                    newValue = DPAGPreferences.kValueNotificationSoundDefault
                case .simsme:
                    newValue = DPAGChatRingtones.SIMSme.rawValue
                case .astral:
                    newValue = DPAGChatRingtones.Astral.rawValue
                case .balaphonia:
                    newValue = DPAGChatRingtones.Balaphonia.rawValue
                case .blessing:
                    newValue = DPAGChatRingtones.Blessing.rawValue
                case .blissful:
                    newValue = DPAGChatRingtones.Blissful.rawValue
                case .chilling:
                    newValue = DPAGChatRingtones.Chilling.rawValue
                case .droplets:
                    newValue = DPAGChatRingtones.Droplets.rawValue
                case .glassian:
                    newValue = DPAGChatRingtones.Glassian.rawValue
                case .glockenspiel:
                    newValue = DPAGChatRingtones.Glockenspiel.rawValue
                case .kalimba:
                    newValue = DPAGChatRingtones.Kalimba.rawValue
                case .marimba:
                    newValue = DPAGChatRingtones.Marimba.rawValue
                case .nylon:
                    newValue = DPAGChatRingtones.Nylon.rawValue
                case .piano:
                    newValue = DPAGChatRingtones.Piano.rawValue
                case .strings:
                    newValue = DPAGChatRingtones.Strings.rawValue
            }
            self.newTune = newValue
            if newValue == DPAGPreferences.kValueNotificationSoundDefault {
                AudioServicesPlaySystemSound(1_307)
            } else if let urlTune = Bundle.main.url(forResource: newValue, withExtension: nil) {
                do {
                    self.audioPlayer = try AVAudioPlayer(contentsOf: urlTune, fileTypeHint: "aiff")
                    try AVAudioSession.sharedInstance().setCategory(.playback)
                    self.audioPlayer?.delegate = self
                    self.audioPlayer?.play()
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                } catch {
                    DPAGLog(error, message: "audioSession error")
                }
            }
        }
    }
}

extension DPAGSettingsNotificationsSoundSelectionTableViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            DPAGLog(error, message: "audioSession error")
        }
    }

    func audioPlayerDecodeErrorDidOccur(_: AVAudioPlayer, error: Error?) {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            DPAGLog(error, message: "audioSession error")
        }
    }
}
