//
//  DPAGSettingsNotificationsTableViewController.swift
//  SIMSme
//
//  Created by RBU on 11.04.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit
import UserNotifications

class DPAGSettingsNotificationsTableViewController: DPAGSettingsTableViewControllerBase, DPAGViewControllerNavigationTitleBig {
    private enum Sections: Int, CaseCountable {
        case chats, groups, channels, others
    }

    private enum RowsChats: Int, CaseCountable {
        case showNotifications, playNotificationSound, selectNotificationSound
    }

    private enum RowsGroups: Int, CaseCountable {
        case showNotifications, playNotificationSound, selectNotificationSound
    }

    private enum RowsChannels: Int, CaseCountable {
        case showNotifications, playNotificationSound, selectNotificationSound
    }

    private enum RowsServices: Int, CaseCountable {
        case showNotifications, playNotificationSound, selectNotificationSound
    }

    private enum RowsOthers: Int, CaseCountable {
        case systemPushNotificationsDisabled, showInAppNotifiactions, showSystemPushNotificationDecrypted
    }

    private var options: UNNotificationSettings? {
        didSet {
            showOptions = options != nil
        }
    }

    private var showOptions: Bool = false

    private var isSoundForPushNotificationsEnabled: Bool {
        options?.soundSetting == .enabled
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.ChatStream.NOTIFICATION_SOUND_CHANGED, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        AppConfig.currentUserNotificationSettings { settings in
            self.options = settings
        }
        self.navigationItem.title = DPAGLocalizedString("settings.notifications")
        NotificationCenter.default.addObserver(self, selector: #selector(notificationSoundChanged(_:)), name: DPAGStrings.Notification.ChatStream.NOTIFICATION_SOUND_CHANGED, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.foregroundObserver = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Application.WILL_ENTER_FOREGROUND, object: nil, queue: .main, using: { [weak self] _ in
            self?.checkNotifications()
        })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.checkNotifications()
    }

    @objc
    private func notificationSoundChanged(_ aNotification: Notification) {
        if let chatType = aNotification.userInfo?[DPAGStrings.Notification.ChatStream.NOTIFICATION_SOUND_CHANGED__USERINFO_KEY__CHAT_TYPE] as? DPAGNotificationChatType {
            switch chatType {
                case .single:
                    self.tableView.reloadRows(at: [IndexPath(row: RowsChats.selectNotificationSound.rawValue, section: Sections.chats.rawValue)], with: .automatic)
                case .group:
                    self.tableView.reloadRows(at: [IndexPath(row: RowsGroups.selectNotificationSound.rawValue, section: Sections.groups.rawValue)], with: .automatic)
                case .channel:
                    self.tableView.reloadRows(at: [IndexPath(row: RowsChannels.selectNotificationSound.rawValue, section: Sections.channels.rawValue)], with: .automatic)
            }
        }
    }

    private func checkNotifications() {
        let optionsBefore = self.showOptions
        AppConfig.currentUserNotificationSettings { settings in
            self.options = settings
            if self.showOptions != optionsBefore {
                DispatchQueue.main.async { self.tableView.reloadData() }
            }
        }
    }

    private func handleSwitchForNotificationTapped(_ sender: Any?, preferencesTogglePushKey: DPAGPreferences.PropString, chatType: DPAGNotificationChatType) {
        guard let aSwitch = sender as? UISwitch else { return }
        let enabled = aSwitch.isOn
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            let responseBlock: DPAGServiceResponseBlock = { [weak self] _, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self, weak aSwitch] in
                    if let strongSelf = self, let strongSwitch = aSwitch {
                        if let errorMessage = errorMessage {
                            strongSwitch.toggle()
                            strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                        } else {
                            DPAGApplicationFacade.preferences[preferencesTogglePushKey] = (enabled ? DPAGPreferences.kValueNotificationEnabled : DPAGPreferences.kValueNotificationDisabled)
                            strongSelf.tableView.reloadData()
                        }
                    }
                }
            }
            DPAGNotificationWorker.setNotificationEnabled(enabled, forChatType: chatType, withResponse: responseBlock)
        }
    }

    private func handleSwitchForSoundTapped(_ sender: Any?, preferencesToggleSoundKey: DPAGPreferences.PropString, chatType: DPAGNotificationChatType) {
        guard let aSwitch = sender as? UISwitch else { return }
        let enabled = aSwitch.isOn
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            DPAGNotificationWorker.setNotificationSoundEnabled(enabled, forChatType: chatType) { [weak self] _, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self, weak aSwitch] in
                    if let strongSelf = self, let strongSwitch = aSwitch {
                        if let errorMessage = errorMessage {
                            strongSwitch.toggle()
                            strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                        } else {
                            DPAGApplicationFacade.preferences[preferencesToggleSoundKey] = (enabled ? DPAGPreferences.kValueNotificationSoundDefault : DPAGPreferences.kValueNotificationSoundNone)
                            strongSelf.tableView.reloadData()
                        }
                    }
                }
            }
        }
    }

    @objc
    fileprivate func handleSwitchForChatNotificationTapped(_ sender: Any?) {
        self.handleSwitchForNotificationTapped(sender, preferencesTogglePushKey: .kNotificationChatEnabled, chatType: .single)
    }

    @objc
    fileprivate func handleSwitchForGroupChatNotificationTapped(_ sender: Any?) {
        self.handleSwitchForNotificationTapped(sender, preferencesTogglePushKey: .kNotificationGroupChatEnabled, chatType: .group)
    }

    @objc
    fileprivate func handleSwitchForChannelChatNotificationTapped(_ sender: Any?) {
        self.handleSwitchForNotificationTapped(sender, preferencesTogglePushKey: .kNotificationChannelChatEnabled, chatType: .channel)
    }

    @objc
    fileprivate func handleSwitchForChatNotificationSoundTapped(_ sender: Any?) {
        self.handleSwitchForSoundTapped(sender, preferencesToggleSoundKey: .kChatRingtone, chatType: .single)
    }

    @objc
    fileprivate func handleSwitchForGroupChatNotificationSoundTapped(_ sender: Any?) {
        self.handleSwitchForSoundTapped(sender, preferencesToggleSoundKey: .kGroupChatRingtone, chatType: .group)
    }

    @objc
    fileprivate func handleSwitchForChannelChatNotificationSoundTapped(_ sender: Any?) {
        self.handleSwitchForSoundTapped(sender, preferencesToggleSoundKey: .kChannelChatRingtone, chatType: .channel)
    }

    @objc
    fileprivate func handleSwitchForInAppPushNotificationsTapped(_ sender: Any?) {
        guard let aSwitch = sender as? UISwitch else { return }
        DPAGApplicationFacade.preferences.isInAppNotificationEnabled = aSwitch.isOn
    }

    @objc
    fileprivate func handleSwitchForPreviewPushNotificationsTapped(_ sender: Any?) {
        guard let aSwitch = sender as? UISwitch else { return }
        let enable = aSwitch.isOn
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            DPAGNotificationWorker.setPreviewPushNotificationEnabled(enable) { [weak self] _, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self, weak aSwitch] in
                    if let strongSelf = self, let strongSwitch = aSwitch {
                        if let errorMessage = errorMessage {
                            strongSwitch.toggle()
                            strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                        } else {
                            DPAGApplicationFacade.preferences.previewPushNotification = enable
                        }
                    }
                }
            }
        }
    }
}

extension DPAGSettingsNotificationsTableViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        Sections.caseCount
    }
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Sections.forIndex(section) {
            case .chats:
                return RowsChats.caseCount
            case .groups:
                return RowsGroups.caseCount
            case .channels:
                return RowsChannels.caseCount
            case .others:
                return RowsOthers.caseCount
        }
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell?
        var cellSwitch: (UITableViewCell & DPAGSwitchTableViewCellProtocol)?
        switch Sections.forIndex(indexPath.section) {
            case .chats:
                guard self.showOptions else { break }
                switch RowsChats.forIndex(indexPath.row) {
                    case .showNotifications:
                        cellSwitch = self.cellNotification(for: indexPath, action: #selector(handleSwitchForChatNotificationTapped(_:)), preferencesKeyNotification: .kNotificationChatEnabled, preferencesKeySound: .kChatRingtone, textLabel: DPAGLocalizedString("settings.notification.chat.notifications"), detailTextLabel: DPAGLocalizedString("settings.notification.chat.notifications.hint"), isSound: false)
                    case .playNotificationSound:
                        cellSwitch = self.cellNotification(for: indexPath, action: #selector(handleSwitchForChatNotificationSoundTapped(_:)), preferencesKeyNotification: .kNotificationChatEnabled, preferencesKeySound: .kChatRingtone, textLabel: DPAGLocalizedString("settings.notification.chat.newMessageTune"), detailTextLabel: DPAGLocalizedString("settings.notification.chat.newMessageTune.hint"), isSound: true)
                    case .selectNotificationSound:
                        cell = self.cellForDisclosureRow(indexPath)
                        self.configureCellForNotificationSoundSelection(cell: cell, textIdent: "settings.notification.chat.selectTune", detailTextPropString: .kChatRingtone, preferencesKeyNotification: .kNotificationChatEnabled, preferencesKeySound: .kChatRingtone)
                }
            case .groups:
                guard self.showOptions else { break }
                switch RowsChats.forIndex(indexPath.row) {
                    case .showNotifications:
                        cellSwitch = self.cellNotification(for: indexPath, action: #selector(handleSwitchForGroupChatNotificationTapped(_:)), preferencesKeyNotification: .kNotificationGroupChatEnabled, preferencesKeySound: .kGroupChatRingtone, textLabel: DPAGLocalizedString("settings.notification.groupChat.notifications"), detailTextLabel: DPAGLocalizedString("settings.notification.groupChat.notifications.hint"), isSound: false)
                    case .playNotificationSound:
                        cellSwitch = self.cellNotification(for: indexPath, action: #selector(handleSwitchForGroupChatNotificationSoundTapped(_:)), preferencesKeyNotification: .kNotificationGroupChatEnabled, preferencesKeySound: .kGroupChatRingtone, textLabel: DPAGLocalizedString("settings.notification.groupChat.newMessageTune"), detailTextLabel: DPAGLocalizedString("settings.notification.groupChat.newMessageTune.hint"), isSound: true)
                    case .selectNotificationSound:
                        cell = self.cellForDisclosureRow(indexPath)
                        self.configureCellForNotificationSoundSelection(cell: cell, textIdent: "settings.notification.groupChat.selectTune", detailTextPropString: .kGroupChatRingtone, preferencesKeyNotification: .kNotificationGroupChatEnabled, preferencesKeySound: .kGroupChatRingtone)
                }
            case .channels:
                guard self.showOptions, DPAGApplicationFacade.preferences.isChannelsAllowed || DPAGApplicationFacade.preferences.isCompanyManagedState else { break }
                switch RowsChats.forIndex(indexPath.row) {
                    case .showNotifications:
                        cellSwitch = self.cellNotification(for: indexPath, action: #selector(handleSwitchForChannelChatNotificationTapped(_:)), preferencesKeyNotification: .kNotificationChannelChatEnabled, preferencesKeySound: .kChannelChatRingtone, textLabel: DPAGLocalizedString("settings.notification.channelChat.notifications"), detailTextLabel: DPAGLocalizedString("settings.notification.channelChat.notifications.hint"), isSound: false)
                    case .playNotificationSound:
                        cellSwitch = self.cellNotification(for: indexPath, action: #selector(handleSwitchForChannelChatNotificationSoundTapped(_:)), preferencesKeyNotification: .kNotificationChannelChatEnabled, preferencesKeySound: .kChannelChatRingtone, textLabel: DPAGLocalizedString("settings.notification.channelChat.newMessageTune"), detailTextLabel: DPAGLocalizedString("settings.notification.channelChat.newMessageTune.hint"), isSound: true)
                    case .selectNotificationSound:
                        cell = self.cellForDisclosureRow(indexPath)
                        self.configureCellForNotificationSoundSelection(cell: cell, textIdent: "settings.notification.channelChat.selectTune", detailTextPropString: .kChannelChatRingtone, preferencesKeyNotification: .kNotificationChannelChatEnabled, preferencesKeySound: .kChannelChatRingtone)
                }
            case .others:
                switch RowsOthers.forIndex(indexPath.row) {
                    case .systemPushNotificationsDisabled:
                        if self.showOptions == false {
                            cell = self.cellForDefaultRow(indexPath)
                            if DPAGApplicationFacade.preferences.notificationRegistrationState == .failed, let notificationRegistrationError = DPAGApplicationFacade.preferences.notificationRegistrationError, notificationRegistrationError.isEmpty == false {
                                cell?.textLabel?.text = notificationRegistrationError
                            } else {
                                cell?.textLabel?.text = DPAGLocalizedString("settings.notification.unknownError")
                            }
                            cell?.selectionStyle = .none
                        }
                    case .showInAppNotifiactions:
                        cellSwitch = self.cellForSwitchRow(indexPath)
                        cellSwitch?.textLabel?.text = DPAGLocalizedString("settings.notification.inapp.notifications")
                        cellSwitch?.detailTextLabel?.text = nil
                        cellSwitch?.aSwitch?.addTarget(self, action: #selector(handleSwitchForInAppPushNotificationsTapped(_:)), for: .valueChanged)
                        cellSwitch?.aSwitch?.isOn = DPAGApplicationFacade.preferences.isInAppNotificationEnabled
                    case .showSystemPushNotificationDecrypted:
                        if DPAGApplicationFacade.preferences.isPushPreviewDisabled == false {
                            cellSwitch = self.cellForSwitchRow(indexPath)
                            cellSwitch?.textLabel?.text = DPAGLocalizedString("settings.notification.previewPush")
                            cellSwitch?.detailTextLabel?.text = nil
                            cellSwitch?.aSwitch?.addTarget(self, action: #selector(handleSwitchForPreviewPushNotificationsTapped(_:)), for: .valueChanged)
                            cellSwitch?.aSwitch?.isOn = DPAGApplicationFacade.preferences.backgroundAccessTokenSyncEnabled && DPAGApplicationFacade.preferences.previewPushNotification
                            cellSwitch?.aSwitch.isEnabled = DPAGApplicationFacade.preferences.backgroundAccessTokenSyncEnabled
                            cellSwitch?.enabled = cellSwitch?.aSwitch.isEnabled ?? false
                        }
                }

        }
        cell = cell ?? cellSwitch
        cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)"
        cell?.backgroundColor = DPAGColorProvider.shared[.settingsBackground]
        return cell ?? self.cellForHiddenRow(indexPath)
    }

    private func configureCellForNotificationSoundSelection(cell: UITableViewCell?, textIdent: String, detailTextPropString: DPAGPreferences.PropString, preferencesKeyNotification: DPAGPreferences.PropString, preferencesKeySound: DPAGPreferences.PropString) {
        cell?.textLabel?.text = DPAGLocalizedString(textIdent)
        cell?.detailTextLabel?.text = DPAGLocalizedString("settings.notification.selectedTune." + (DPAGApplicationFacade.preferences[detailTextPropString]?.prefix(while: { (c) -> Bool in
            c != "."
        }) ?? "none")) + " "
        cell?.selectionStyle = .default
        let isOn = (DPAGApplicationFacade.preferences[preferencesKeySound] != DPAGPreferences.kValueNotificationSoundNone)
        var soundIsEnabled = self.isSoundForPushNotificationsEnabled
        if soundIsEnabled {
            let soundSetting = DPAGApplicationFacade.preferences[preferencesKeyNotification]
            soundIsEnabled = soundSetting != DPAGPreferences.kValueNotificationDisabled
        }
        (cell as? DPAGBaseTableViewCellProtocol)?.enabled = isOn && soundIsEnabled
    }

    private func cellNotification(for indexPath: IndexPath, action: Selector, preferencesKeyNotification: DPAGPreferences.PropString, preferencesKeySound: DPAGPreferences.PropString, textLabel: String, detailTextLabel _: String, isSound: Bool) -> (UITableViewCell & DPAGSwitchTableViewCellProtocol)? {
        var isOn: Bool = false
        var switchIsON: String?
        let cellSwitch = self.cellForSwitchRow(indexPath)
        cellSwitch?.selectionStyle = .none
        cellSwitch?.textLabel?.text = textLabel
        cellSwitch?.detailTextLabel?.text = nil // detailTextLabel
        cellSwitch?.aSwitch?.addTarget(self, action: action, for: .valueChanged)
        if isSound {
            switchIsON = DPAGApplicationFacade.preferences[preferencesKeySound]
            isOn = (switchIsON != DPAGPreferences.kValueNotificationSoundNone)
            var soundIsEnabled = self.isSoundForPushNotificationsEnabled
            if soundIsEnabled {
                let soundSetting = DPAGApplicationFacade.preferences[preferencesKeyNotification]
                soundIsEnabled = soundSetting != DPAGPreferences.kValueNotificationDisabled
            } else {
                cellSwitch?.detailTextLabel?.text = DPAGLocalizedString("settings.notification.soundIsDisabled")
            }
            cellSwitch?.aSwitch?.isEnabled = soundIsEnabled
            cellSwitch?.enabled = soundIsEnabled
        } else {
            switchIsON = DPAGApplicationFacade.preferences[preferencesKeyNotification]
            isOn = (switchIsON != DPAGPreferences.kValueNotificationDisabled)
        }
        cellSwitch?.aSwitch?.setOn(isOn, animated: false)
        return cellSwitch
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Sections.forIndex(section) {
            case .others:
                return " "
            case .chats:
                guard self.showOptions else { return nil }
                return DPAGLocalizedString("settings.notification.chatSection")
            case .groups:
                guard self.showOptions else { return nil }
                return DPAGLocalizedString("settings.notification.groupChatSection")
            case .channels:
                guard self.showOptions, DPAGApplicationFacade.preferences.isChannelsAllowed || DPAGApplicationFacade.preferences.isCompanyManagedState else { return nil }
                return DPAGLocalizedString("settings.notification.channelChatSection")
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == tableView.numberOfSections - 1 {
            return DPAGLocalizedString("settings.notification.previewPush.hint")
        }
        return nil
    }
}

extension DPAGSettingsNotificationsTableViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Sections.forIndex(indexPath.section) {
            case .chats:
                switch RowsChats.forIndex(indexPath.row) {
                    case .selectNotificationSound:
                        let nextVC = DPAGApplicationFacadeUISettings.soundSelectionVC(soundType: .single)
                        let navVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: nextVC)
                        self.navigationController?.present(navVC, animated: true)
                    case .showNotifications, .playNotificationSound:
                        break
                }
            case .groups:
                switch RowsGroups.forIndex(indexPath.row) {
                    case .selectNotificationSound:
                        let nextVC = DPAGApplicationFacadeUISettings.soundSelectionVC(soundType: .group)
                        let navVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: nextVC)
                        self.navigationController?.present(navVC, animated: true)
                    case .showNotifications, .playNotificationSound:
                        break
                }
            case .channels:
                switch RowsChannels.forIndex(indexPath.row) {
                    case .selectNotificationSound:
                        let nextVC = DPAGApplicationFacadeUISettings.soundSelectionVC(soundType: .channel)
                        let navVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: nextVC)
                        self.navigationController?.present(navVC, animated: true)
                    case .showNotifications, .playNotificationSound:
                        break
                }
            case .others:
                break
        }
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch Sections.forIndex(section) {
            case .chats, .groups:
                guard self.showOptions else { return 0 }
            case .channels:
                guard self.showOptions, DPAGApplicationFacade.preferences.isChannelsAllowed || DPAGApplicationFacade.preferences.isCompanyManagedState else { return 0 }
            case .others:
                break
        }
        return 38 // UITableViewAutomaticDimension
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == tableView.numberOfSections - 1 {
            return UITableView.automaticDimension
        }
        return 0
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Sections.forIndex(indexPath.section) {
            case .others:
                switch RowsOthers.forIndex(indexPath.row) {
                    case .systemPushNotificationsDisabled:
                        if self.showOptions {
                            return 0
                        }
                    case .showInAppNotifiactions:
                        break
                    case .showSystemPushNotificationDecrypted:
                        if DPAGApplicationFacade.preferences.isPushPreviewDisabled {
                            return 0
                        }
                }
            case .chats:
                guard self.showOptions else { return 0 }
            case .groups:
                guard self.showOptions else { return 0 }
            case .channels:
                guard self.showOptions, DPAGApplicationFacade.preferences.isChannelsAllowed || DPAGApplicationFacade.preferences.isCompanyManagedState else { return 0 }
        }
        return UITableView.automaticDimension
    }
}
