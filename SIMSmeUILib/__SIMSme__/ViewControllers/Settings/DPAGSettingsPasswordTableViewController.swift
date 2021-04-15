//
//  DPAGSettingsPasswordTableViewController.swift
//  SIMSme
//
//  Created by RBU on 10.04.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import LocalAuthentication
import SIMSmeCore
import UIKit

class DPAGSettingsPasswordTableViewController: DPAGSettingsTableViewControllerBase, DPAGViewControllerNavigationTitleBig {
    private enum Rows: Int, CaseCountable {
        case changePassword,
            disablePassword,
            lockDelay,
            touchId,
            deleteData,
            deleteDataTries,
            disableSimsmeRecovery
    }

    private var supportsTouchID: Bool = false
    private var supportsFaceID: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = DPAGLocalizedString("settings.password")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.performBlockInBackground { [weak self] in
            guard let strongSelf = self else { return }
            var errorPointer: NSError?
            let context = LAContext()
            strongSelf.supportsTouchID = context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: &errorPointer)
            strongSelf.supportsFaceID = strongSelf.supportsTouchID && context.biometryType == .faceID
            strongSelf.performBlockOnMainThread { [weak self] in
                self?.tableView.reloadData()
            }
        }
    }

    private func handleSetTime() {
        let actionSheet = DPAGSettingsOptionSelectViewController(style: .grouped)
        actionSheet.title = DPAGLocalizedString("settings.password.disablePassword")
        actionSheet.headerText = DPAGLocalizedString("settings.askForPassword.setTime")
        actionSheet.accessibilityIdentifier = "action_set_time"
        var options: [DPAGSettingsOptionSelectOption] = []
        var optionSelected: DPAGSettingsOptionSelectOption?
        for tryValue in DPAGSettingLockDelay.allCases {
            let format: String
            let accessibilityIdentifier: String
            if tryValue == .zero {
                format = DPAGLocalizedString("settings.askForPassword.setTime.immediately")
                accessibilityIdentifier = "settings.askForPassword.setTime.immediately"
            } else if tryValue == .one {
                format = DPAGLocalizedString("settings.askForPassword.setTime.minute")
                accessibilityIdentifier = "settings.askForPassword.setTime.minute"
            } else {
                format = DPAGLocalizedString("settings.askForPassword.setTime.minutes")
                accessibilityIdentifier = "settings.askForPassword.setTime.minutes"
            }
            let option = DPAGSettingsOptionSelectOption(titleIdentifier: String(format: format, tryValue.rawValue), action: { [weak self] in
                self?.setTimeValue(tryValue)
            }, accessibilityIdentifier: accessibilityIdentifier)
            options.append(option)
            if tryValue == DPAGApplicationFacade.preferences.applicationLockDelay {
                optionSelected = option
            }
        }
        actionSheet.options = options
        actionSheet.optionPreSelected = optionSelected
        self.navigationController?.pushViewController(actionSheet, animated: true)
    }

    private func setTimeValue(_ timeValue: DPAGSettingLockDelay) {
        DPAGApplicationFacade.preferences.applicationLockDelay = timeValue
        self.tableView.reloadData()
    }

    private func handleSetTries() {
        let actionSheet = DPAGSettingsOptionSelectViewController(style: .grouped)
        actionSheet.title = DPAGLocalizedString("settings.passwordDeleteData")
        actionSheet.headerText = DPAGLocalizedString("settings.passwordDeleteData.setTries")
        actionSheet.accessibilityIdentifier = "action_set_tries"
        var options: [DPAGSettingsOptionSelectOption] = []
        var optionSelected: DPAGSettingsOptionSelectOption?
        for tryValue in DPAGSettingPasswordRetry.allCases {
            let option: DPAGSettingsOptionSelectOption
            if tryValue.rawValue > 1 {
                option = DPAGSettingsOptionSelectOption(titleIdentifier: String(format: DPAGLocalizedString("settings.passwordDeleteData.setTries.tryTitle.plural"), tryValue.rawValue), action: { [weak self] in
                    self?.setTriesValue(tryValue)
                }, accessibilityIdentifier: "settings.passwordDeleteData.setTries.tryTitle.plural")
            } else {
                option = DPAGSettingsOptionSelectOption(titleIdentifier: String(format: DPAGLocalizedString("settings.passwordDeleteData.setTries.tryTitle.singular"), tryValue.rawValue), action: { [weak self] in
                    self?.setTriesValue(tryValue)
                }, accessibilityIdentifier: "settings.passwordDeleteData.setTries.tryTitle.singular")
            }
            options.append(option)
            if tryValue == DPAGApplicationFacade.preferences.getPasswordRetries() {
                optionSelected = option
            }
        }
        actionSheet.options = options
        actionSheet.optionPreSelected = optionSelected
        self.navigationController?.pushViewController(actionSheet, animated: true)
    }

    private func setTriesValue(_ triesValue: DPAGSettingPasswordRetry) {
        DPAGApplicationFacade.preferences.setPasswordTriesDefault(triesValue)
        self.tableView.reloadData()
    }

    @objc
    private func handleToggleDeleteData(_ sender: Any?) {
        guard let aSwitch = sender as? UISwitch else { return }
        if self.checkSettingsEnabledWithCompletion({ [weak self, weak aSwitch] in
            self?.handleToggleDeleteData(aSwitch)
        }) {
            DPAGApplicationFacade.preferences.deleteData = aSwitch.isOn
            self.tableView.beginUpdates()
            self.tableView.reloadRows(at: [IndexPath(row: Rows.deleteDataTries.rawValue, section: 0)], with: .automatic)
            self.tableView.endUpdates()
        }
    }

    private func handleChangePasswordTapped() {
        let nextVC = DPAGApplicationFacadeUISettings.changePasswordVC()
        self.navigationController?.pushViewController(nextVC, animated: true)
    }

    @objc
    private func handleToggleDisablePassword(_ sender: Any?) {
        guard let aSwitch = sender as? UISwitch else { return }
        if self.checkSettingsEnabledWithCompletion({ [weak self, weak aSwitch] in
            if let strongSelf = self {
                strongSelf.handleToggleDisablePassword(aSwitch)
            }
        }) {
            if aSwitch.isOn {
                DPAGApplicationFacade.preferences.passwordOnStartEnabled = true
                self.tableView.beginUpdates()
                self.tableView.reloadRows(at: [IndexPath(row: Rows.lockDelay.rawValue, section: 0)], with: .automatic)
                self.tableView.endUpdates()
            } else {
                let actionCancel = UIAlertAction(titleIdentifier: "registration.button.askForPassword.no", style: .cancel, handler: { [weak self] _ in
                    guard let strongSelf = self else { return }
                    DPAGApplicationFacade.preferences.passwordOnStartEnabled = true
                    strongSelf.tableView.beginUpdates()
                    strongSelf.tableView.reloadRows(at: [IndexPath(row: Rows.disablePassword.rawValue, section: 0), IndexPath(row: Rows.lockDelay.rawValue, section: 0)], with: .automatic)
                    strongSelf.tableView.endUpdates()

                })
                let actionOK = UIAlertAction(titleIdentifier: "registration.button.askForPassword.yes", style: .destructive, handler: { [weak self] _ in
                    guard let strongSelf = self else { return }
                    DPAGApplicationFacade.preferences.passwordOnStartEnabled = false
                    strongSelf.tableView.beginUpdates()
                    strongSelf.tableView.reloadRows(at: [IndexPath(row: Rows.disablePassword.rawValue, section: 0), IndexPath(row: Rows.lockDelay.rawValue, section: 0)], with: .automatic)
                    strongSelf.tableView.endUpdates()

                })
                self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "registration.dontAskForPassword.alertTitle", messageIdentifier: "registration.dontAskForPassword.alert", cancelButtonAction: actionCancel, otherButtonActions: [actionOK]))
            }
        }
    }

    @objc
    private func handleToggleTouchID(_ sender: Any?) {
        guard let aSwitch = sender as? UISwitch else { return }
        if self.checkSettingsEnabledWithCompletion({ [weak self, weak aSwitch] in
            if let strongSelf = self {
                strongSelf.handleToggleTouchID(aSwitch)
            }
        }) {
            DPAGApplicationFacade.preferences.touchIDEnabled = aSwitch.isOn
        }
    }

    @objc
    private func handleToggleSimsmeRecovery(_ sender: Any?) {
        guard let aSwitch = sender as? UISwitch else { return }
        if self.checkSettingsEnabledWithCompletion({ [weak self, weak aSwitch] in
            if let strongSelf = self {
                strongSelf.handleToggleSimsmeRecovery(aSwitch)
            }
        }) {
            DPAGApplicationFacade.preferences.simsmeRecoveryEnabled = aSwitch.isOn
        }
    }
}

// MARK: - UITableViewDataSource

extension DPAGSettingsPasswordTableViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        DPAGSettingsPasswordTableViewController.Rows.caseCount
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell?
        var cellSwitch: (UITableViewCell & DPAGSwitchTableViewCellProtocol)?
        let hasFaceId = LAContext().biometryType == LABiometryType.faceID
        switch Rows.forIndex(indexPath.row) {
            case .changePassword:
                cell = self.cellForDisclosureRow(indexPath)
                if DPAGApplicationFacade.preferences.hasSystemGeneratedPassword {
                    cell?.textLabel?.text = DPAGLocalizedString("settings.password.setPassword")
                } else {
                    cell?.textLabel?.text = DPAGLocalizedString("settings.password.changePassword")
                }
                cell?.detailTextLabel?.text = nil
            case .disablePassword:
                guard DPAGApplicationFacade.preferences.canDisablePasswordLogin else { break }
                cellSwitch = self.cellForSwitchRow(indexPath)
                cellSwitch?.textLabel?.text = DPAGLocalizedString("settings.password.disablePassword")
                cellSwitch?.detailTextLabel?.text = nil
                cellSwitch?.aSwitch?.addTarget(self, action: #selector(handleToggleDisablePassword(_:)), for: .valueChanged)
                cellSwitch?.aSwitch?.setOn(DPAGApplicationFacade.preferences.passwordOnStartEnabled, animated: false)
                cellSwitch?.aSwitch?.isEnabled = DPAGApplicationFacade.preferences.canDisablePasswordLogin && !DPAGApplicationFacade.preferences.hasSystemGeneratedPassword
                cellSwitch?.enabled = DPAGApplicationFacade.preferences.canDisablePasswordLogin
            case .lockDelay:
                guard DPAGApplicationFacade.preferences.passwordOnStartEnabled, DPAGApplicationFacade.preferences.canSetApplicationLockDelay() else { break }
                cell = self.cellForDisclosureRow(indexPath)
                cell?.textLabel?.text = DPAGLocalizedString("settings.askForPassword.setTime")
                let lockDelay = DPAGApplicationFacade.preferences.applicationLockDelay
                if lockDelay.rawValue > 0 {
                    cell?.detailTextLabel?.text = "\(lockDelay.rawValue)"
                } else {
                    cell?.detailTextLabel?.text = DPAGLocalizedString("settings.askForPassword.setTime.immediately")
                }
            case .touchId:
                guard DPAGApplicationFacade.preferences.canSetTouchId else { break }
                cellSwitch = self.cellForSwitchRow(indexPath)
                cellSwitch?.textLabel?.text = hasFaceId || self.supportsFaceID ? DPAGLocalizedString("settings.password.enableFaceID") : DPAGLocalizedString("settings.password.enableTouchID")
                cellSwitch?.detailTextLabel?.text = nil
                cellSwitch?.aSwitch?.addTarget(self, action: #selector(handleToggleTouchID(_:)), for: .valueChanged)
                cellSwitch?.aSwitch?.setOn(DPAGApplicationFacade.preferences.touchIDEnabled, animated: false)
                cellSwitch?.aSwitch?.isEnabled = self.supportsTouchID && !DPAGApplicationFacade.preferences.hasSystemGeneratedPassword
                cellSwitch?.enabled = self.supportsTouchID
            case .deleteData:
                guard DPAGApplicationFacade.preferences.canSetPasswordRetries else { break }
                cellSwitch = self.cellForSwitchRow(indexPath)
                cellSwitch?.textLabel?.text = DPAGLocalizedString("settings.passwordDeleteData")
                cellSwitch?.detailTextLabel?.text = nil
                cellSwitch?.aSwitch?.addTarget(self, action: #selector(handleToggleDeleteData(_:)), for: .valueChanged)
                cellSwitch?.aSwitch?.setOn(DPAGApplicationFacade.preferences.deleteData, animated: false)
                cellSwitch?.aSwitch?.isEnabled = !DPAGApplicationFacade.preferences.hasSystemGeneratedPassword
            case .deleteDataTries:
                guard DPAGApplicationFacade.preferences.deleteData, DPAGApplicationFacade.preferences.canSetPasswordRetries else { break }
                cell = self.cellForDisclosureRow(indexPath)
                cell?.textLabel?.text = DPAGLocalizedString("settings.passwordDeleteData.setTries")
                cell?.detailTextLabel?.text = "\(DPAGApplicationFacade.preferences.getPasswordRetries().rawValue)"
            case .disableSimsmeRecovery:
                guard DPAGApplicationFacade.preferences.isBaMandant, DPAGApplicationFacade.preferences.canSetSimsmeRecovery else { break }
                cellSwitch = self.cellForSwitchRow(indexPath)
                cellSwitch?.textLabel?.text = DPAGLocalizedString("settings.password.disableSimsmeRecovery")
                cellSwitch?.detailTextLabel?.text = nil
                cellSwitch?.aSwitch?.addTarget(self, action: #selector(handleToggleSimsmeRecovery(_:)), for: .valueChanged)
                cellSwitch?.aSwitch?.setOn(DPAGApplicationFacade.preferences.simsmeRecoveryEnabled, animated: false)
                cellSwitch?.aSwitch?.isEnabled = !DPAGApplicationFacade.preferences.hasSystemGeneratedPassword
        }
        cell = cell ?? cellSwitch
        cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)"
        cell?.backgroundColor = DPAGColorProvider.shared[.settingsBackground]
        return cell ?? self.cellForHiddenRow(indexPath)
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == tableView.numberOfSections - 1, DPAGApplicationFacade.preferences.isBaMandant, DPAGApplicationFacade.preferences.canSetSimsmeRecovery {
            return DPAGLocalizedString("settings.password.disableSimsmeRecovery.hint")
        }
        return nil
    }
}

// MARK: - UITableViewDelegate

extension DPAGSettingsPasswordTableViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.checkSettingsEnabledWithCompletion({ [weak self] in
            self?.tableView(tableView, didSelectRowAt: indexPath)
        }) {
            switch Rows.forIndex(indexPath.row) {
                case .changePassword:
                    self.handleChangePasswordTapped()
                case .lockDelay:
                    self.handleSetTime()
                case .deleteDataTries:
                    self.handleSetTries()
                case .deleteData, .disablePassword, .disableSimsmeRecovery, .touchId:
                    break
            }
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == tableView.numberOfSections - 1, DPAGApplicationFacade.preferences.canSetSimsmeRecovery {
            return UITableView.automaticDimension
        }
        return 0
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Rows.forIndex(indexPath.row) {
            case .changePassword:
                break
            case .disablePassword:
                guard DPAGApplicationFacade.preferences.canDisablePasswordLogin else { return 0 }
            case .lockDelay:
                guard DPAGApplicationFacade.preferences.passwordOnStartEnabled, DPAGApplicationFacade.preferences.canSetApplicationLockDelay() else { return 0 }
            case .touchId:
                guard DPAGApplicationFacade.preferences.canSetTouchId else { return 0 }
            case .deleteData:
                guard DPAGApplicationFacade.preferences.canSetPasswordRetries else { return 0 }
            case .deleteDataTries:
                guard DPAGApplicationFacade.preferences.deleteData, DPAGApplicationFacade.preferences.canSetPasswordRetries else { return 0 }
            case .disableSimsmeRecovery:
                guard DPAGApplicationFacade.preferences.isBaMandant, DPAGApplicationFacade.preferences.canSetSimsmeRecovery else { return 0 }
        }
        return UITableView.automaticDimension
    }
}
