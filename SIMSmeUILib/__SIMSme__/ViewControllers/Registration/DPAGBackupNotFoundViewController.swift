//
//  DPAGBackupNotFoundViewController.swift
//  SIMSme
//
//  Created by RBU on 26/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGBackupNotFoundViewController: DPAGViewControllerBackground {
    @IBOutlet private var labelHeadline: UILabel! {
        didSet {
            self.labelHeadline.font = UIFont.kFontTitle1
            self.labelHeadline.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelDescription: UILabel! {
        didSet {
            self.labelDescription.font = UIFont.kFontSubheadline
            self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelInfo: UILabel! {
        didSet {
            self.labelInfo.font = UIFont.kFontHeadline
            self.labelInfo.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelStep1: UILabel! {
        didSet {
            self.labelStep1.text = "1"
            self.configureLabelStep(self.labelStep1)
        }
    }

    @IBOutlet private var labelStep2: UILabel! {
        didSet {
            self.labelStep2.text = "2"
            self.configureLabelStep(self.labelStep2)
        }
    }

    @IBOutlet private var labelStep3: UILabel! {
        didSet {
            self.labelStep3.text = "3"
            self.configureLabelStep(self.labelStep3)
        }
    }

    @IBOutlet private var labelStepInfo1: UILabel! {
        didSet {
            self.labelStepInfo1.font = UIFont.kFontSubheadline
            self.labelStepInfo1.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelStepInfo2: UILabel! {
        didSet {
            self.labelStepInfo2.font = UIFont.kFontSubheadline
            self.labelStepInfo2.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelStepInfo3: UILabel! {
        didSet {
            self.labelStepInfo3.font = UIFont.kFontSubheadline
            self.labelStepInfo3.textColor = DPAGColorProvider.shared[.labelText]
        }
    }
    
    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelHeadline.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.labelInfo.textColor = DPAGColorProvider.shared[.labelText]
                self.labelStepInfo1.textColor = DPAGColorProvider.shared[.labelText]
                self.labelStepInfo2.textColor = DPAGColorProvider.shared[.labelText]
                self.labelStepInfo3.textColor = DPAGColorProvider.shared[.labelText]
                self.configureLabelStep(self.labelStep1)
                self.configureLabelStep(self.labelStep2)
                self.configureLabelStep(self.labelStep3)
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.accessibilityIdentifier = "btnNext"
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("registration.backup.not_found.btnNext"), for: .normal)
            self.viewButtonNext.button.addTarget(self, action: #selector(handleProceedWithoutBackup), for: .touchUpInside)
        }
    }

    private var iCloudActivated = false
    private let oldAccountID: String?

    init(oldAccountID: String?) {
        self.oldAccountID = oldAccountID
        super.init(nibName: "DPAGBackupNotFoundViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = DPAGLocalizedString("registration.backup.not_found.title")
        self.iCloudActivated = (try? DPAGApplicationFacade.backupWorker.isICloudEnabled()) ?? false
        let bundleIdentifier = DPAGMandant.default.name
        if self.iCloudActivated {
            self.labelHeadline.text = DPAGLocalizedString("registration.backup.not_found.headline")
            self.labelDescription.text = String(format: DPAGLocalizedString("registration.backup.not_found.description"), bundleIdentifier)
            self.labelInfo.text = DPAGLocalizedString("registration.backup.not_found.info")
            self.labelStepInfo1.text = String(format: DPAGLocalizedString("registration.backup.not_found.step1"), bundleIdentifier)
            self.labelStepInfo2.text = String(format: DPAGLocalizedString("registration.backup.not_found.step2"), bundleIdentifier)
            self.labelStepInfo3.text = String(format: DPAGLocalizedString("registration.backup.not_found.step3"), bundleIdentifier)
        } else {
            self.labelHeadline.text = DPAGLocalizedString("registration.backup.not_found.headline_no_cloud")
            self.labelDescription.text = String(format: DPAGLocalizedString("registration.backup.not_found.description_no_cloud"), bundleIdentifier)
            self.labelInfo.text = DPAGLocalizedString("registration.backup.not_found.info_no_cloud")

            self.labelStepInfo1.text = String(format: DPAGLocalizedString("registration.backup.not_found.step1_no_cloud"), bundleIdentifier)
            self.labelStepInfo2.text = String(format: DPAGLocalizedString("registration.backup.not_found.step2_no_cloud"), bundleIdentifier)
            self.labelStepInfo3.text = String(format: DPAGLocalizedString("registration.backup.not_found.step3_no_cloud"), bundleIdentifier)
        }
    }

    private func configureLabelStep(_ label: UILabel) {
        label.font = UIFont.kFontCounter
        label.textAlignment = .center
        label.textColor = DPAGColorProvider.shared[.labelTextForBackgroundInverted]
        label.backgroundColor = DPAGColorProvider.shared[.defaultViewBackgroundInverted]
        label.layer.cornerRadius = 15
        label.layer.masksToBounds = true
    }

    override func viewFirstAppear(_ animated: Bool) {
        super.viewFirstAppear(animated)
    }

    @objc
    private func handleProceedWithoutBackup() {
        if DPAGApplicationFacade.preferences.bootstrappingSkipWarningOverrideAccount {
            if let code = DPAGApplicationFacade.preferences.bootstrappingConfirmationCode {
                DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                    DPAGApplicationFacade.accountManager.confirmAccount(code: code, responseBlock: { _, _, errorMessage in
                        if let errorMessage = errorMessage {
                            if errorMessage == "service.error499" {
                                self.handleServiceError("service.error499.createAccount")
                            } else {
                                self.handleServiceError(errorMessage)
                            }
                        } else {
                            self.handleServiceSuccessNoBackup()
                        }
                    })
                }
            }
        } else {
            let vc = DPAGApplicationFacadeUIRegistration.confirmAccountOverrideVC(oldAccountID: self.oldAccountID)
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    private func handleServiceError(_ message: String) {
        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
            if let strongSelf = self {
                if message == "service.ERR-0062" {
                    strongSelf.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: message, okActionHandler: { [weak self] _ in
                        if let strongSelf = self {
                            let controllers = strongSelf.navigationController?.viewControllers
                            if (controllers?.count ?? 0) < 2 {
                                strongSelf.popToPasswortInitialisation()
                            } else {
                                strongSelf.dismissViewController()
                            }
                        }
                    }))
                } else {
                    strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: message))
                }
            }
        }
    }

    @objc
    private func dismissViewController() {
        _ = self.navigationController?.popViewController(animated: true)
    }

    private func popToPasswortInitialisation() {
        DPAGApplicationFacade.accountManager.resetDatabase()
        let initialPasswordViewController = DPAGApplicationFacadeUIRegistration.initialPasswordVC(initialPasswordJob: .createAccount)
        self.navigationController?.setViewControllers([initialPasswordViewController], animated: true)
    }

    @objc
    private func handleServiceSuccessNoBackup() {
        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
            guard let strongSelf = self, let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let accountID = contact.accountID else {
                return
            }
            DPAGApplicationFacade.preferences.shouldInviteFriendsAfterInstall = true
            DPAGApplicationFacade.preferences.shouldInviteFriendsAfterChatPrivateCreation = true
            DPAGApplicationFacade.preferences.didAskForCompanyEmail = contact.eMailAddress != nil
            DPAGApplicationFacade.preferences.migrationVersion = .versionCurrent
            if DPAGApplicationFacade.preferences.isBaMandant {
                let vc = DPAGApplicationFacadeUIRegistration.welcomeVC(account: account.guid, accountID: accountID, phoneNumber: contact.phoneNumber, emailAddress: contact.eMailAddress, emailDomain: contact.eMailDomain, checkUsage: true)
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            } else {
                let vc = DPAGApplicationFacadeUIRegistration.welcomeVC(account: account.guid, accountID: accountID, phoneNumber: contact.phoneNumber, emailAddress: contact.eMailAddress, emailDomain: contact.eMailDomain, checkUsage: false)
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
}
