//
//  DPAGSettingsChatTableViewController.swift
// ginlo
//
//  Created by RBU on 11.04.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import MobileCoreServices
import SIMSmeCore
import UIKit

class DPAGSettingsChatTableViewController: DPAGSettingsTableViewControllerBase, DPAGViewControllerNavigationTitleBig {
    private enum Sections: Int, CaseCountable {
        case sending, background, audio, backup, debug
    }

    private enum RowsSending: Int, CaseCountable {
        case imageQuality, videoQuality, proximityVoiceRecording, autoSaveToCameraRoll, shareExtension
    }

    private enum RowsBackground: Int, CaseCountable {
        case transparent, image
    }

    private enum RowsAudio: Int, CaseCountable {
        case playSelfDestructionAudio,
            playSendAudio,
            playReceiveAudio
    }

    private enum RowsBackup: Int, CaseCountable {
        case backup
    }

    private enum RowsDebug: Int, CaseCountable {
        case testDateReset
    }

    private lazy var formatterVideoTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "mm:ss"
        return formatter
    }()

    private var couplingStep = 0
    private var reloadOnAppear = false

    private let iCloudQuery = NSMetadataQuery()
    private var backupItems: [DPAGBackupFileInfo] = []

    deinit {
        self.iCloudQuery.stop()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = DPAGLocalizedString("settings.chat")
        self.iCloudQuery.operationQueue = OperationQueue.main
        self.iCloudQuery.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        self.iCloudQuery.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemDisplayNameKey, ascending: true)]
        NotificationCenter.default.addObserver(self, selector: #selector(didFinishGatheringMetadata), name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: nil)
        self.iCloudQuery.start()

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.reloadOnAppear {
            self.reloadOnAppear = false
            self.tableView.reloadData()
        }
    }

    var lastDateMetadataUpdate = Date.distantPast

    @objc
    private func didFinishGatheringMetadata() {
        guard self.lastDateMetadataUpdate.compare(Date().addingTimeInterval(TimeInterval(-1))) == .orderedAscending else { return }
        self.iCloudQuery.disableUpdates()
        self.lastDateMetadataUpdate = Date()
        DPAGLog("didFinishGatheringMetadata")
        let results = self.iCloudQuery.results
        self.performBlockInBackground { [weak self] in
            guard let strongSelf = self else { return }
            if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) {
                do {
                    strongSelf.backupItems = try DPAGApplicationFacade.backupWorker.listBackups(accountIDs: [contact.accountID ?? "???"], orPhone: contact.phoneNumber, queryResults: results, checkContent: true).sorted(by: { (fi1, fi2) -> Bool in
                        if let d1 = fi1.backupDate {
                            if let d2 = fi2.backupDate {
                                return d1 > d2
                            }
                            return true
                        }
                        return false
                    })
                } catch {
                    DPAGLog(error)
                }
            }
            NotificationCenter.default.addObserver(strongSelf, selector: #selector(DPAGSettingsChatTableViewController.didFinishGatheringMetadata), name: NSNotification.Name.NSMetadataQueryDidUpdate, object: nil)
            DPAGLog("didFinishGatheringMetadataFile")
            strongSelf.iCloudQuery.enableUpdates()
            strongSelf.performBlockOnMainThread { [weak self] in
                self?.refreshBackupCell()
            }
        }
    }

    private func handleSetSentImageQuality() {
        let actionSheet = DPAGSettingsOptionSelectViewController(style: .grouped)
        actionSheet.title = DPAGLocalizedString("settings.sentImageQuality.title")
        actionSheet.accessibilityIdentifier = "action_quality_sent_image"
        var options: [DPAGSettingsOptionSelectOption] = []
        var optionSelected: DPAGSettingsOptionSelectOption?
        var optionDefault: DPAGSettingsOptionSelectOption?
        for qualityValue in DPAGSettingSentImageQuality.allCases {
            let qualityTitle = String(format: "settings.sentImageQuality.title.imageQualitySetting%@", String(qualityValue.rawValue))
            let qualityTitleLocalized = DPAGLocalizedString(qualityTitle)
            let option = DPAGSettingsOptionSelectOption(titleIdentifier: qualityTitleLocalized, action: { [weak self] in
                DPAGApplicationFacade.preferences.sentImageQuality = qualityValue
                self?.tableView.reloadRows(at: [IndexPath(row: RowsSending.imageQuality.rawValue, section: Sections.sending.rawValue)], with: .automatic)
            })
            options.append(option)
            if qualityValue == DPAGApplicationFacade.preferences.sentImageQuality {
                optionSelected = option
            }
            if qualityValue == DPAGApplicationFacade.preferences.defaultSentImageQuality {
                optionDefault = option
            }
        }
        actionSheet.options = options
        actionSheet.optionPreSelected = optionSelected
        actionSheet.optionDefault = optionDefault
        actionSheet.optionReset = DPAGSettingsOptionSelectOption(titleIdentifier: "settings.backup.delautDownloadSetting.title", action: { [weak self] in
            DPAGApplicationFacade.preferences.resetSentImageQuality()
            self?.tableView.reloadRows(at: [IndexPath(row: RowsSending.imageQuality.rawValue, section: Sections.sending.rawValue)], with: .automatic)
        })
        self.navigationController?.pushViewController(actionSheet, animated: true)
    }

    private func handleSetSentVideoQuality() {
        let actionSheet = DPAGSettingsOptionSelectViewController(style: .grouped)
        actionSheet.title = DPAGLocalizedString("settings.sentVideoQuality.title")
        actionSheet.accessibilityIdentifier = "action_quality_sent_videos"
        var options: [DPAGSettingsOptionSelectOption] = []
        var optionSelected: DPAGSettingsOptionSelectOption?
        var optionDefault: DPAGSettingsOptionSelectOption?
        for qualityValue in DPAGSettingSentVideoQuality.allCases {
            let qualityTitle = String(format: "settings.sentVideoQuality.title.videoQualitySetting%@", String(qualityValue.rawValue))
            let qualityTitleLocalized = DPAGLocalizedString(qualityTitle)
            var timeComponents = DateComponents()
            timeComponents.second = Int(DPAGApplicationFacade.preferences.maxLengthForSentVideos(videoQuality: qualityValue))
            let timeComponentsDate = Calendar.current.date(from: timeComponents)
            let qualityTitleLocalizedExtended = String(format: qualityTitleLocalized, formatterVideoTime.string(from: timeComponentsDate ?? Date()))
            let option = DPAGSettingsOptionSelectOption(titleIdentifier: qualityTitleLocalizedExtended, action: { [weak self] in
                DPAGApplicationFacade.preferences.sentVideoQuality = qualityValue
                self?.tableView.reloadRows(at: [IndexPath(row: RowsSending.videoQuality.rawValue, section: Sections.sending.rawValue)], with: .automatic)
            })
            options.append(option)
            if qualityValue == DPAGApplicationFacade.preferences.sentVideoQuality {
                optionSelected = option
            }
            if qualityValue == DPAGApplicationFacade.preferences.defaultSentVideoQuality {
                optionDefault = option
            }
        }
        actionSheet.options = options
        actionSheet.optionPreSelected = optionSelected
        actionSheet.optionDefault = optionDefault
        actionSheet.optionReset = DPAGSettingsOptionSelectOption(titleIdentifier: "settings.backup.delautDownloadSetting.title", action: { [weak self] in
            DPAGApplicationFacade.preferences.resetSentVideoQuality()
            self?.tableView.reloadRows(at: [IndexPath(row: RowsSending.videoQuality.rawValue, section: Sections.sending.rawValue)], with: .automatic)
        })
        self.navigationController?.pushViewController(actionSheet, animated: true)
    }

    @objc
    fileprivate func handleSwitchForShareExtensionTapped(_ sender: Any?) {
        guard let aSwitch = sender as? UISwitch else { return }
        let enable = aSwitch.isOn
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            if enable {
                try? DPAGApplicationFacade.devicesWorker.createShareExtensionDevice { [weak self] _, _, errorMessage in
                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self, weak aSwitch] in
                        if let strongSelf = self, let strongSwitch = aSwitch, let errorMessage = errorMessage {
                            strongSwitch.toggle()
                            strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                        } else {
                            DPAGLog("SaveShareExtension started ")
                            do {
                                try DPAGApplicationFacade.sharedContainerSending.saveData(config: DPAGApplicationFacade.preferences.sharedContainerConfig)
                            } catch {
                                DPAGLog(error)
                            }
                            DPAGLog("SaveShareExtension finished ")
                        }
                    }
                }
            } else if let shareExtensionDeviceGuid = DPAGApplicationFacade.preferences.shareExtensionDeviceGuid {
                DPAGApplicationFacade.devicesWorker.deleteDevice(shareExtensionDeviceGuid) { _, _, errorMessage in
                    if errorMessage == nil {
                        DPAGApplicationFacade.preferences.isShareExtensionEnabled = enable
                    }
                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self, weak aSwitch] in

                        if let strongSelf = self, let strongSwitch = aSwitch, let errorMessage = errorMessage {
                            strongSwitch.toggle()
                            strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                        }
                    }
                }
            } else {
                DPAGProgressHUD.sharedInstance.hide(true)
            }
        }
    }

    @objc
    private func handleToggleProximityMonitoringTapped(_ sender: Any?) {
        guard let aSwitch = sender as? UISwitch else { return }
        let recordPermission = AVAudioSession.sharedInstance().recordPermission
        switch recordPermission {
            case .undetermined:
                AVAudioSession.sharedInstance().requestRecordPermission({ [weak self] _ in
                    self?.performBlockOnMainThread { [weak self] in
                        self?.handleToggleProximityMonitoringTapped(nil)
                    }
                })
            case .granted:
                DPAGApplicationFacade.preferences.proximityMonitoringEnabled = aSwitch.isOn
            case .denied:
                aSwitch.isEnabled = false
            @unknown default:
                DPAGLog("Switch with unknown value: \(recordPermission.rawValue)", level: .warning)
        }
    }

    @objc
    private func handleToggleSaveImagesTapped(_ sender: Any?) {
        guard let aSwitch = sender as? UISwitch else { return }
        DPAGApplicationFacade.preferences.saveImagesToCameraRoll = aSwitch.isOn
    }

    @objc
    private func handleToggleInvisibleBackgroundTapped(_ sender: Any?) {
        guard let aSwitch = sender as? UISwitch else { return }
        DPAGApplicationFacade.preferences.cameraBackgroundEnabled = aSwitch.isOn
        if aSwitch.isOn {
            self.presentErrorAlert(alertConfig: AlertConfigError(titleIdentifier: "settings.chat.invisibleBackground.warning.title", messageIdentifier: "settings.chat.invisibleBackground.warning"))
        }
    }

    private func handleChangeBackgroundTapped() {
        if let indexPathForSelectedRow = self.tableView.indexPathForSelectedRow {
            self.tableView.deselectRow(at: indexPathForSelectedRow, animated: true)
        }
        let nextVC = DPAGApplicationFacadeUISettings.simsMeBackgroundsVC()
        self.navigationController?.pushViewController(nextVC, animated: true)
    }

    @objc
    private func handleTogglePlaySelfDestructionAudioTapped(_ sender: Any?) {
        guard let aSwitch = sender as? UISwitch else { return }
        DPAGApplicationFacade.preferences.skipPlayingSelfDestructionAudio = !aSwitch.isOn
    }

    @objc
    private func handleTogglePlaySendAudioTapped(_ sender: Any?) {
        guard let aSwitch = sender as? UISwitch else { return }
        DPAGApplicationFacade.preferences.skipPlayingSendAudio = !aSwitch.isOn
    }

    @objc
    private func handleTogglePlayReceiveAudioTapped(_ sender: Any?) {
        guard let aSwitch = sender as? UISwitch else { return }
        DPAGApplicationFacade.preferences.skipPlayingReceiveAudio = !aSwitch.isOn
    }

    @objc
    private func refreshBackupCell() {
        if let cellBackup = self.tableView.cellForRow(at: IndexPath(row: RowsBackup.backup.rawValue, section: Sections.backup.rawValue)) {
            self.configureBackupCell(cell: cellBackup)
        }
    }

    private func configureBackupCell(cell: UITableViewCell?) {
        if self.iCloudQuery.isGathering {
            cell?.detailTextLabel?.text = "..."
            cell?.detailTextLabel?.accessibilityIdentifier = "settings.backup.no.backup"
        } else if let backupItem = self.backupItems.first {
            let date = DateFormatter.localizedString(from: backupItem.backupDate ?? Date(), dateStyle: .short, timeStyle: .short)
            let size = DPAGFormatter.fileSize.string(fromByteCount: backupItem.fileSize?.int64Value ?? 0)
            let isSavedText = backupItem.isUploaded ? DPAGLocalizedString("setting.backup.info.synced") : DPAGLocalizedString("setting.backup.info.notsynced")
            cell?.detailTextLabel?.text = String(format: DPAGLocalizedString("settings.backup.info.hint2"), date, size, isSavedText)
            cell?.detailTextLabel?.accessibilityIdentifier = "settings.backup.have.backup"
        }
        else if let lastDate = DPAGApplicationFacade.preferences.backupLastDate, let lastSize = DPAGApplicationFacade.preferences.backupLastFileSize {
            let date = DateFormatter.localizedString(from: lastDate, dateStyle: .short, timeStyle: .short)
            let size = DPAGFormatter.fileSize.string(fromByteCount: lastSize.int64Value)
            let isSavedText = DPAGLocalizedString("setting.backup.info.notsynced")
            cell?.detailTextLabel?.text = String(format: DPAGLocalizedString("settings.backup.info.hint2"), date, size, isSavedText)
            cell?.detailTextLabel?.accessibilityIdentifier = "settings.backup.have.backup"
        } else {
            cell?.detailTextLabel?.text = DPAGLocalizedString("settings.backup.info.hint")
            cell?.detailTextLabel?.accessibilityIdentifier = "settings.backup.no.backup"
        }
    }
}

extension DPAGSettingsChatTableViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        if DPAGApplicationFacade.preferences.isBackupDisabled {
            return Sections.caseCount - 2
        } else {
            switch AppConfig.buildConfigurationMode {
                case .DEBUG, .TEST:
                    return Sections.caseCount
                case .ADHOC, .BETA, .RELEASE:
                    return Sections.caseCount - 1
            }
        }
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Sections.forIndex(section) {
            case .sending:
                return RowsSending.caseCount
            case .background:
                return RowsBackground.caseCount
            case .audio:
                return RowsAudio.caseCount
            case .backup:
                return RowsBackup.caseCount
            case .debug:
                return RowsDebug.caseCount
        }
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell?
        var cellSwitch: (UITableViewCell & DPAGSwitchTableViewCellProtocol)?
        switch Sections.forIndex(indexPath.section) {
            case .sending:
                switch RowsSending.forIndex(indexPath.row) {
                    case .imageQuality:
                        cell = self.cellForDisclosureRow(indexPath)
                        cell?.accessibilityIdentifier = "cell-settings.sentImageQuality.title"
                        cell?.textLabel?.text = DPAGLocalizedString("settings.sentImageQuality.title")
                        let qualityValue = DPAGApplicationFacade.preferences.sentImageQuality.rawValue
                        let qualityTitle = "settings.sentImageQuality.title.imageQuality\(qualityValue)"
                        cell?.detailTextLabel?.text = DPAGLocalizedString(qualityTitle) + " "
                    case .videoQuality:
                        cell = self.cellForDisclosureRow(indexPath)
                        cell?.accessibilityIdentifier = "cell-settings.sentVideoQuality.title"
                        cell?.textLabel?.text = DPAGLocalizedString("settings.sentVideoQuality.title")
                        let qualityValue = DPAGApplicationFacade.preferences.sentVideoQuality.rawValue
                        let qualityTitle = "settings.sentVideoQuality.title.videoQuality\(qualityValue)"
                        cell?.detailTextLabel?.text = DPAGLocalizedString(qualityTitle) + " "
                    case .shareExtension:
                        cellSwitch = self.cellForSwitchRow(indexPath)
                        cellSwitch?.textLabel?.text = DPAGLocalizedString("settings.shareExtension")
                        cellSwitch?.detailTextLabel?.text = nil
                        cellSwitch?.aSwitch?.addTarget(self, action: #selector(handleSwitchForShareExtensionTapped(_:)), for: .valueChanged)
                        cellSwitch?.aSwitch?.isOn = DPAGApplicationFacade.preferences.isShareExtensionEnabled
                        cellSwitch?.aSwitch.isEnabled = true
                        cellSwitch?.enabled = cellSwitch?.aSwitch.isEnabled ?? false
                    case .proximityVoiceRecording:
                        cellSwitch = self.cellForSwitchRow(indexPath)
                        cell?.accessibilityIdentifier = "cell-settings.chat.proximityMonitoring"
                        cellSwitch?.textLabel?.text = DPAGLocalizedString("settings.chat.proximityMonitoring")
                        cellSwitch?.detailTextLabel?.text = nil
                        cellSwitch?.aSwitch?.addTarget(self, action: #selector(handleToggleProximityMonitoringTapped(_:)), for: .valueChanged)
                        cellSwitch?.aSwitch?.setOn(DPAGApplicationFacade.preferences.proximityMonitoringEnabled, animated: false)
                        let granted = AVAudioSession.sharedInstance().recordPermission != .denied
                        cellSwitch?.aSwitch?.isEnabled = granted
                        cellSwitch?.enabled = granted
                    case .autoSaveToCameraRoll:
                        guard DPAGApplicationFacade.preferences.canSetAutoSaveMedia else { break }
                        cellSwitch = self.cellForSwitchRow(indexPath)
                        cell?.accessibilityIdentifier = "cell-settings.chat.imagesInCameraRoll"
                        cellSwitch?.textLabel?.text = DPAGLocalizedString("settings.chat.imagesInCameraRoll")
                        cellSwitch?.detailTextLabel?.text = nil
                        cellSwitch?.aSwitch?.addTarget(self, action: #selector(handleToggleSaveImagesTapped(_:)), for: .valueChanged)
                        cellSwitch?.aSwitch?.setOn(DPAGApplicationFacade.preferences.saveImagesToCameraRoll, animated: false)
                        cellSwitch?.aSwitch?.isEnabled = DPAGApplicationFacade.preferences.autoSaveMedia
                    }
            case .background:
                switch RowsBackground.forIndex(indexPath.row) {
                    case .transparent:
                        cellSwitch = self.cellForSwitchRow(indexPath)
                        cell?.accessibilityIdentifier = "cell-settings.chat.invisibleBackground"
                        cellSwitch?.textLabel?.text = DPAGLocalizedString("settings.chat.invisibleBackground")
                        cellSwitch?.detailTextLabel?.text = nil
                        cellSwitch?.aSwitch?.addTarget(self, action: #selector(handleToggleInvisibleBackgroundTapped(_:)), for: .valueChanged)
                        cellSwitch?.aSwitch?.setOn(DPAGApplicationFacade.preferences.cameraBackgroundEnabled, animated: false)
                    case .image:
                        cell = self.cellForDisclosureRow(indexPath)
                        cell?.accessibilityIdentifier = "cell-settings.chat.background"
                        cell?.textLabel?.text = DPAGLocalizedString("settings.chat.background")
                        cell?.detailTextLabel?.text = nil
                }
            case .audio:
                switch RowsAudio.forIndex(indexPath.row) {
                    case .playSelfDestructionAudio:
                        cellSwitch = self.cellForSwitchRow(indexPath)
                        cell?.accessibilityIdentifier = "cell-settings.chat.playSelfDestructionAudio"
                        cellSwitch?.textLabel?.text = DPAGLocalizedString("settings.chat.playSelfDestructionAudio")
                        cellSwitch?.detailTextLabel?.text = nil
                        cellSwitch?.aSwitch?.addTarget(self, action: #selector(handleTogglePlaySelfDestructionAudioTapped(_:)), for: .valueChanged)
                        cellSwitch?.aSwitch?.setOn(DPAGApplicationFacade.preferences.skipPlayingSelfDestructionAudio == false, animated: false)
                    case .playSendAudio:
                        cellSwitch = self.cellForSwitchRow(indexPath)
                        cell?.accessibilityIdentifier = "cell-settings.chat.playSendAudio"
                        cellSwitch?.textLabel?.text = DPAGLocalizedString("settings.chat.playSendAudio")
                        cellSwitch?.detailTextLabel?.text = nil
                        cellSwitch?.aSwitch?.addTarget(self, action: #selector(handleTogglePlaySendAudioTapped(_:)), for: .valueChanged)
                        cellSwitch?.aSwitch?.setOn(DPAGApplicationFacade.preferences.skipPlayingSendAudio == false, animated: false)
                    case .playReceiveAudio:
                        cellSwitch = self.cellForSwitchRow(indexPath)
                        cell?.accessibilityIdentifier = "cell-settings.chat.playReceiveAudio"
                        cellSwitch?.textLabel?.text = DPAGLocalizedString("settings.chat.playReceiveAudio")
                        cellSwitch?.detailTextLabel?.text = nil
                        cellSwitch?.aSwitch?.addTarget(self, action: #selector(handleTogglePlayReceiveAudioTapped(_:)), for: .valueChanged)
                        cellSwitch?.aSwitch?.setOn(DPAGApplicationFacade.preferences.skipPlayingReceiveAudio == false, animated: false)
                }
            case .backup:
                switch RowsBackup.forIndex(indexPath.row) {
                    case .backup:
                        cell = self.cellForDisclosureSubtitleRow(indexPath)
                        cell?.accessibilityIdentifier = "cell-settings.backup.info"
                        cell?.textLabel?.text = DPAGLocalizedString("settings.backup.info")
                        self.configureBackupCell(cell: cell)
                }
            case .debug:
                switch RowsDebug.forIndex(indexPath.row) {
                    case .testDateReset:
                        cell = self.cellForDefaultRow(indexPath)
                        cell?.accessibilityIdentifier = "cell-testDateReset"
                        cell?.textLabel?.text = "Dienstcheck-Datum zurücksetzen"
                        cell?.detailTextLabel?.text = ""
            }
        }
        cell = cell ?? cellSwitch
        cell?.backgroundColor = DPAGColorProvider.shared[.settingsBackground]
        return cell ?? self.cellForHiddenRow(indexPath)
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Sections.forIndex(section) {
            case .sending:
                return nil
            case .background:
                return DPAGLocalizedString("settings.chat.backgroundSection")
            case .audio:
                return DPAGLocalizedString("settings.chat.audioSection")
            case .backup:
                return DPAGLocalizedString("settings.chat.backupSection")
            case .debug:
                return DPAGLocalizedString("settings.chat.debug")
        }
    }
}

extension DPAGSettingsChatTableViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Sections.forIndex(indexPath.section) {
            case .sending:
                switch RowsSending.forIndex(indexPath.row) {
                    case .imageQuality:
                        self.handleSetSentImageQuality()
                    case .videoQuality:
                        self.handleSetSentVideoQuality()
                    case .proximityVoiceRecording, .autoSaveToCameraRoll, .shareExtension:
                        break
                }
            case .background:
                switch RowsBackground.forIndex(indexPath.row) {
                    case .image:
                        self.handleChangeBackgroundTapped()
                    case .transparent:
                        break
                }
            case .audio:
                break
            case .backup:
                switch RowsBackup.forIndex(indexPath.row) {
                    case .backup:
                        let nextVC = DPAGApplicationFacadeUISettings.backupVC()
                        self.navigationController?.pushViewController(nextVC, animated: true)
                        self.reloadOnAppear = true
                }
            case .debug:
                switch RowsDebug.forIndex(indexPath.row) {
                    case .testDateReset:
                        DPAGApplicationFacade.preferences.resetDates()
                        NotificationCenter.default.post(name: DPAGStrings.Notification.Application.RESET_DATES, object: nil)
                        let actionOK = UIAlertAction(titleIdentifier: "OK", style: .default, handler: { _ in
                        })
                        self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "Fertig", messageIdentifier: "Getan", cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
                }
        }
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Sections.forIndex(indexPath.section) {
            case .sending:
                switch RowsSending.forIndex(indexPath.row) {
                    case .imageQuality, .videoQuality, .shareExtension, .proximityVoiceRecording:
                        break
                    case .autoSaveToCameraRoll:
                        guard DPAGApplicationFacade.preferences.canSetAutoSaveMedia else { return 0 }
                }
            case .background, .audio, .backup, .debug:
                break
        }
        return UITableView.automaticDimension
    }
}
