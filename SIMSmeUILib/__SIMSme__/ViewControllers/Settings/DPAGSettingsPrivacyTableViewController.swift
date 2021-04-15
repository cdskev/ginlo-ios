//
//  DPAGSettingsPrivacyTableViewController.swift
//  SIMSme
//
//  Created by RBU on 11.04.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGSettingsPrivacyAvailabilityView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}

class DPAGSettingsPrivacyTableViewController: DPAGSettingsTableViewControllerBase, DPAGViewControllerNavigationTitleBig {
    private enum Sections: Int, CaseCountable {
        case contacts, chat, notifications, improveUs
    }

    private enum RowsContacts: Int, CaseCountable {
        case blocked
    }

    private enum RowsChat: Int, CaseCountable {
        case confirmRead, showOnlineState
    }

    private enum RowsNotifications: Int, CaseCountable {
        case loadMessagesInBackground, messageServerAvailability, showProfilnameInNotification
    }

    private enum RowsImproveUs: Int, CaseCountable {
        case sendCrashLogs
    }

    private var blockedContacts: [DPAGContact]?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = DPAGLocalizedString("settings.chatPrivacy")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.performBlockInBackground { [weak self] in
            self?.blockedContacts = DPAGApplicationFacade.contactsWorker.blockedContacts()?.sorted(by: { (c1, c2) -> Bool in
                c1.isBeforeInSearch(c2)
            })
            self?.performBlockOnMainThread { [weak self] in
                self?.tableView.reloadRows(at: [IndexPath(row: RowsContacts.blocked.rawValue, section: Sections.contacts.rawValue)], with: .automatic)
            }
        }
    }

    @objc
    private func handleToggleMarkMessagesAsRead(_ sender: Any?) {
        guard let aSwitch = sender as? UISwitch else { return }
        let enable = aSwitch.isOn
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            DPAGApplicationFacade.profileWorker.setAutoGenerateConfirmReadMessage(enabled: enable) { [weak self] responseObject, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self, weak aSwitch] in
                    if let strongSelf = self, let strongSwitch = aSwitch {
                        if let errorMessage = errorMessage {
                            strongSwitch.toggle()
                            strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                        } else {
                            if let answer = responseObject as? [String: String], let confirmRead = answer["confirmRead"] {
                                DPAGApplicationFacade.preferences.markMessagesAsReadEnabled = (confirmRead == "1")
                                self?.tableView.reloadRows(at: [IndexPath(row: RowsChat.confirmRead.rawValue, section: Sections.chat.rawValue)], with: .automatic)
                            }
                        }
                    }
                }
            }
        }
    }

    @objc
    private func handleToggleShowOnlineState(_ sender: Any?) {
        guard let aSwitch = sender as? UISwitch else { return }
        let enable = aSwitch.isOn
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            DPAGApplicationFacade.profileWorker.setPublicOnlineState(enabled: enable) { [weak self] _, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self, weak aSwitch] in
                    if let errorMessage = errorMessage {
                        aSwitch?.toggle()
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                    } else {
                        self?.tableView.reloadRows(at: [IndexPath(row: RowsChat.showOnlineState.rawValue, section: Sections.chat.rawValue)], with: .automatic)
                    }
                }
            }
        }
    }

    @objc
    private func handleSwitchForBackgroundPushNotificationsTapped(_ sender: Any?) {
        guard let aSwitch = sender as? UISwitch else { return }
        let enable = aSwitch.isOn
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            DPAGNotificationWorker.setBackgroundPushNotificationEnabled(enable) { [weak self] _, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self, weak aSwitch] in
                    if let errorMessage = errorMessage {
                        aSwitch?.toggle()
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                    } else {
                        DPAGApplicationFacade.preferences.backgroundAccessTokenSyncEnabled = enable
                    }
                }
            }
        }
    }

    @objc
    private func handleSwitchForNicknameNotificationsTapped(_ sender: Any?) {
        guard let aSwitch = sender as? UISwitch else { return }
        DPAGApplicationFacade.preferences[.kNotificationNicknameEnabled] = (aSwitch.isOn ? DPAGPreferences.kValueNotificationEnabled : DPAGPreferences.kValueNotificationDisabled)
    }

    @objc
    private func handleSwitchForCrashReportTapped(_ uiSwitch: UISwitch) {
        let enable = uiSwitch.isOn
        DPAGApplicationFacade.preferences.isCrashReportEnabled = enable
    }
}

extension DPAGSettingsPrivacyTableViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        Sections.caseCount
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Sections.forIndex(section) {
            case .contacts:
                return RowsContacts.caseCount
            case .chat:
                return RowsChat.caseCount
            case .notifications:
                return RowsNotifications.caseCount
            case .improveUs:
                return RowsImproveUs.caseCount
        }
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if !DPAGApplicationFacade.preferences.isBaMandant, indexPath.section == Sections.notifications.rawValue, indexPath.row == RowsNotifications.messageServerAvailability.rawValue {
            return 0
        }
        return UITableView.automaticDimension
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell?
        var cellSwitch: (UITableViewCell & DPAGSwitchTableViewCellProtocol)?
        switch Sections.forIndex(indexPath.section) {
            case .contacts:
                if RowsContacts.forIndex(indexPath.row) == .blocked {
                    let blockedContactsCount = (self.blockedContacts?.count ?? 0)
                    if blockedContactsCount <= 0 {
                        cell = self.cellForDefaultRow(indexPath)
                        cell?.accessibilityIdentifier = "cell-settings.chat.blockedContacts"
                        cell?.textLabel?.text = String(format: DPAGLocalizedString("settings.chat.blockedContactsEmpty"), NSNumber(value: 0))
                    } else {
                        cell = self.cellForDisclosureRow(indexPath)
                        cell?.accessibilityIdentifier = "cell-settings.chat.blockedContacts"
                        if blockedContactsCount == 1 {
                            cell?.textLabel?.text = String(format: DPAGLocalizedString("settings.chat.blockedContactsSingle"), NSNumber(value: 1))
                        } else {
                            cell?.textLabel?.text = String(format: DPAGLocalizedString("settings.chat.blockedContactsNum"), NSNumber(value: blockedContactsCount))
                        }
                    }
                    cell?.detailTextLabel?.text = nil
                }
            case .chat:
                if RowsChat.forIndex(indexPath.row) == .confirmRead {
                    cellSwitch = self.cellForSwitchRow(indexPath)
                    cell?.accessibilityIdentifier = "cell-settings.chat.messageMarkAsRead"
                    cellSwitch?.textLabel?.text = DPAGLocalizedString("settings.chat.messageMarkAsRead")
                    cellSwitch?.detailTextLabel?.text = nil
                    cellSwitch?.aSwitch?.addTarget(self, action: #selector(handleToggleMarkMessagesAsRead(_:)), for: .valueChanged)
                    cellSwitch?.aSwitch?.setOn(DPAGApplicationFacade.preferences.markMessagesAsReadEnabled, animated: false)
                } else if RowsChat.forIndex(indexPath.row) == .showOnlineState {
                    cellSwitch = self.cellForSwitchRow(indexPath)
                    cell?.accessibilityIdentifier = "cell-settings.chat.showOnlineState"
                    cellSwitch?.textLabel?.text = DPAGLocalizedString("settings.chat.showOnlineState")
                    cellSwitch?.detailTextLabel?.text = nil
                    cellSwitch?.aSwitch?.addTarget(self, action: #selector(handleToggleShowOnlineState(_:)), for: .valueChanged)
                    cellSwitch?.aSwitch?.setOn(DPAGApplicationFacade.preferences.publicOnlineStateEnabled, animated: false)
                }
            case .notifications:
                switch RowsNotifications.forIndex(indexPath.row) {
                    case .loadMessagesInBackground:
                        cellSwitch = self.cellForSwitchRow(indexPath)
                        cell?.accessibilityIdentifier = "cell-settings.notification.background.notifications"
                        cellSwitch?.textLabel?.text = DPAGLocalizedString("settings.notification.background.notifications")
                        cellSwitch?.detailTextLabel?.text = nil // DPAGLocalizedString("settings.notification.background.notifications.hint")
                        cellSwitch?.aSwitch?.addTarget(self, action: #selector(handleSwitchForBackgroundPushNotificationsTapped(_:)), for: .valueChanged)
                        cellSwitch?.aSwitch?.isOn = DPAGApplicationFacade.preferences.backgroundAccessTokenSyncEnabled
                    case .messageServerAvailability:
                        if DPAGApplicationFacade.preferences.isBaMandant {
                            cell = self.cellForDefaultRow(indexPath)
                            cell?.accessibilityIdentifier = "cell-settings.persistMessageDays"
                            cell?.textLabel?.text = DPAGLocalizedString("settings.persistMessageDays")
                            cell?.detailTextLabel?.text = String(format: DPAGLocalizedString("settings.persistMessageDays.details"), String(DPAGApplicationFacade.preferences.persistMessageDays))
                        }
                    case .showProfilnameInNotification:
                        cellSwitch = self.cellForSwitchRow(indexPath)
                        cell?.accessibilityIdentifier = "cell-settings.chatPrivacy.notification.nickname.notifications"
                        cellSwitch?.textLabel?.text = DPAGLocalizedString("settings.chatPrivacy.notification.nickname.notifications")
                        cellSwitch?.detailTextLabel?.text = nil
                        cellSwitch?.aSwitch?.addTarget(self, action: #selector(handleSwitchForNicknameNotificationsTapped(_:)), for: .valueChanged)
                        let pref = DPAGApplicationFacade.preferences[.kNotificationNicknameEnabled]
                        cellSwitch?.aSwitch?.isOn = (pref != nil) && (pref != DPAGPreferences.kValueNotificationDisabled)
                }
            case .improveUs:
                if RowsImproveUs.forIndex(indexPath.row) == .sendCrashLogs {
                    cellSwitch = self.cellForSwitchRow(indexPath)
                    cell?.accessibilityIdentifier = "cell-settings.chat.helpusgetbesser.sendcrashlog"
                    cellSwitch?.textLabel?.text = DPAGLocalizedString("settings.chat.helpusgetbesser.sendcrashlog")
                    cellSwitch?.detailTextLabel?.text = nil
                    cellSwitch?.aSwitch?.addTarget(self, action: #selector(handleSwitchForCrashReportTapped(_:)), for: .valueChanged)
                    cellSwitch?.aSwitch?.isOn = DPAGApplicationFacade.preferences.isCrashReportEnabled
                }
        }
        cell = cell ?? cellSwitch
        cell?.backgroundColor = DPAGColorProvider.shared[.settingsBackground]
        return cell ?? self.cellForHiddenRow(indexPath)
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Sections.forIndex(section) {
            case .contacts:
                return DPAGLocalizedString("settings.chatPrivacy.contacts")
            case .chat:
                return DPAGLocalizedString("settings.chatPrivacy.chat")
            case .notifications:
                return DPAGLocalizedString("settings.chatPrivacy.notifications")
            case .improveUs:
                return DPAGLocalizedString("settings.chat.helpusgetbesser")
        }
    }
}

extension DPAGSettingsPrivacyTableViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Sections.forIndex(indexPath.section) {
            case .contacts:
                if RowsContacts.forIndex(indexPath.row) == .blocked, let blockedContacts = self.blockedContacts, blockedContacts.count > 0 {
                    let nextVC = DPAGApplicationFacadeUISettings.blockedContactsVC(blockedContacts: blockedContacts)
                    self.navigationController?.pushViewController(nextVC, animated: true)
                }
            case .chat, .notifications, .improveUs:
                break
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        tableView.estimatedRowHeight
    }
}
