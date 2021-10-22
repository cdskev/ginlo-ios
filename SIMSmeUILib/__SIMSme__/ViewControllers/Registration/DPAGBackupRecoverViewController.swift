//
//  DPAGBackupRecoverViewController.swift
// ginlo
//
//  Created by RBU on 26/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGBackupRecoverViewController: DPAGViewControllerBackground {
    @IBOutlet private var btnProceedWithoutBackup: UIButton! {
        didSet {
            self.btnProceedWithoutBackup.configureButtonDestructive()
            self.btnProceedWithoutBackup.accessibilityIdentifier = "btnProceedWithoutBackup"
            self.btnProceedWithoutBackup.setTitle(DPAGLocalizedString("registration.backup.revcover.btnProceedWithoutBackup"), for: .normal)
            self.btnProceedWithoutBackup.addTarget(self, action: #selector(handleProceedWithoutBackup), for: .touchUpInside)
        }
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.isEnabled = false
            self.viewButtonNext.button.accessibilityIdentifier = "btnRecover"
            self.viewButtonNext.button.addTarget(self, action: #selector(handleProceedWithBackup), for: .touchUpInside)
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("registration.backup_recover.btnRecover.title"), for: .normal)
        }
    }

    @IBOutlet private var labelRecoverInfo: DPAGChatLabel! {
        didSet {
            self.labelRecoverInfo.font = UIFont.kFontFootnote
            self.labelRecoverInfo.textColor = DPAGColorProvider.shared[.labelText]
            if DPAGApplicationFacade.preferences.isBaMandant {
                let termsText = NSMutableAttributedString(string: DPAGLocalizedString("registration.backup_recover.footer_info.ba0"), attributes: [.font: UIFont.kFontFootnote, .foregroundColor: DPAGColorProvider.shared[.labelText]])
                let termsLink = NSAttributedString(string: DPAGLocalizedString("registration.backup_recover.footer_info.ba1"), attributes: [.font: UIFont.kFontFootnote, .foregroundColor: DPAGColorProvider.shared[.labelText]])
                let termsTextLength = (termsText.string as NSString).length
                let termsLinkLength = (termsLink.string as NSString).length
                termsText.append(termsLink)
                self.labelRecoverInfo.attributedText = termsText
                self.labelRecoverInfo.linkAttributeDefault = [.foregroundColor: DPAGColorProvider.shared[.labelLink], .underlineStyle: NSUnderlineStyle.single.rawValue]
                self.labelRecoverInfo.linkAttributeHighlight = [.foregroundColor: DPAGColorProvider.shared[.labelLink], .underlineStyle: NSUnderlineStyle.single.rawValue]

                if let url = URL(string: "https://www.ginlo.net/") {
                    self.labelRecoverInfo.setLink(url: url, for: NSRange(location: termsTextLength, length: termsLinkLength))
                }
                self.labelRecoverInfo.accessibilityIdentifier = "registration.backup_recover.footer_info.ba"
                self.labelRecoverInfo.delegate = self
            } else {
                self.labelRecoverInfo.text = DPAGLocalizedString("registration.backup_recover.footer_info")
            }
            self.labelRecoverInfo.numberOfLines = 0
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelRecoverInfo.textColor = DPAGColorProvider.shared[.labelText]
                self.labelRecoverInfo.linkAttributeDefault = [.foregroundColor: DPAGColorProvider.shared[.labelLink], .underlineStyle: NSUnderlineStyle.single.rawValue]
                self.labelRecoverInfo.linkAttributeHighlight = [.foregroundColor: DPAGColorProvider.shared[.labelLink], .underlineStyle: NSUnderlineStyle.single.rawValue]
                self.labelHeadline.textColor = DPAGColorProvider.shared[.labelText]
                self.labelSelectBackup.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var labelHeadline: UILabel! {
        didSet {
            self.labelHeadline.font = UIFont.kFontTitle1
            self.labelHeadline.textColor = DPAGColorProvider.shared[.labelText]
            self.labelHeadline.text = DPAGLocalizedString("registration.backup_recover.headline")
            self.labelHeadline.numberOfLines = 0
        }
    }

    @IBOutlet private var labelSelectBackup: UILabel! {
        didSet {
            self.labelSelectBackup.font = UIFont.kFontSubheadline
            self.labelSelectBackup.textColor = DPAGColorProvider.shared[.labelText]
            self.labelSelectBackup.text = DPAGLocalizedString("registration.backup_recover.select_backup")
            self.labelSelectBackup.numberOfLines = 0
        }
    }

    @IBOutlet private var stackViewBackupEntries: UIStackView!
    @IBOutlet private var stackViewBackupEntriesDummy: UIActivityIndicatorView!

    private let backupEntries: [DPAGBackupFileInfo]

    private let oldAccountID: String?

    private var syncHelper: DPAGSynchronizationHelperAddressbook?

    init(oldAccountID: String?, backupEntries: [DPAGBackupFileInfo]) {
        self.backupEntries = backupEntries
        self.oldAccountID = oldAccountID

        super.init(nibName: "DPAGBackupRecoverViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.title = DPAGLocalizedString("registration.backup_recover.btnRecover.title")

        for backupEntry in self.backupEntries {
            if let view = DPAGApplicationFacadeUIRegistration.viewBackupRecoverEntry() {
                view.configure(backupEntry: backupEntry)

                let tapGr = UITapGestureRecognizer(target: self, action: #selector(handleEntryTap(_:)))

                view.addGestureRecognizer(tapGr)

                self.stackViewBackupEntries.addArrangedSubview(view)
            }
        }

        self.stackViewBackupEntriesDummy.isHidden = true
    }

    private weak var sharedInstanceProgress: DPAGProgressHUDWithProgressProtocol?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        self.sharedInstanceProgress?.statusBarStyle ?? super.preferredStatusBarStyle
    }

    override func viewFirstAppear(_ animated: Bool) {
        super.viewFirstAppear(animated)
    }

    @objc
    private func handleEntryTap(_ aGestureRecognizer: UIGestureRecognizer) {
        if aGestureRecognizer.state == .ended {
            if let view = aGestureRecognizer.view as? DPAGBackupRecoverEntryViewProtocol {
                view.isSelected = !view.isSelected

                for viewArranged in self.stackViewBackupEntries.arrangedSubviews {
                    if let viewUnselect = viewArranged as? DPAGBackupRecoverEntryViewProtocol, viewUnselect !== view {
                        viewUnselect.isSelected = false
                    }
                }

                self.viewButtonNext.isEnabled = view.isSelected
            }
        }
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

                            // TODO: popBack to Passworteingbe
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

    private func dismissViewController() {
        _ = self.navigationController?.popViewController(animated: true)
    }

    private func popToPasswortInitialisation() {
        DPAGApplicationFacade.accountManager.resetDatabase()

        let initialPasswordViewController = DPAGApplicationFacadeUIRegistration.initialPasswordVC(initialPasswordJob: .createAccount)

        self.navigationController?.setViewControllers([initialPasswordViewController], animated: true)
    }

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

    @objc
    private func handleProceedWithBackup() {
        if let index = self.stackViewBackupEntries.arrangedSubviews.firstIndex(where: { (view) -> Bool in
            (view as? DPAGBackupRecoverEntryViewProtocol)?.isSelected ?? false
        }) {
            let backupEntry = self.backupEntries[index - 1]

            if backupEntry.mandantIdent != DPAGMandant.default.ident, backupEntry.appName != DPAGMandant.default.label {
                let vc = DPAGApplicationFacadeUIRegistration.confirmAccountOverridePKVC(backupEntry: backupEntry, delegate: self)
                let navVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)

                self.present(navVC, animated: true, completion: nil)
            } else {
                let vc = DPAGApplicationFacadeUIRegistration.backupRecoverPasswordVC(backup: backupEntry, delegatePassword: self)
                let navVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)

                self.navigationController?.present(navVC, animated: true, completion: nil)
            }
        }
    }

    var testLicenseAvailable: Bool = false
}

extension DPAGBackupRecoverViewController: DPAGBackupRecoverPasswordViewControllerDelegate {
    func handlePasswordEntered(_ backupFile: DPAGBackupFileInfo, password _: String) {
        AppConfig.setIdleTimerDisabled(true)
        // Backup einspielen ...
        self.sharedInstanceProgress = DPAGProgressHUDWithProgress.sharedInstanceProgress.showForBackgroundProcess(true, completion: { [weak self] alertInstance in

            self?.performBlockOnMainThread { [weak self] in
                self?.setNeedsStatusBarAppearanceUpdate()
            }

            var errorText = "backup.recover.importfailed"
            var rc = true
            if let ai = (alertInstance as? DPAGProgressHUDWithProgressDelegate) {
                do {
                    try DPAGApplicationFacade.backupWorker.recoverBackup(backupFileInfo: backupFile, hudWithLabels: ai)
                } catch {
                    rc = false
                    errorText = error.localizedDescription
                }
            }

            self?.performBlockOnMainThread {
                AppConfig.setIdleTimerDisabled(false)
            }

            if rc {
                if DPAGApplicationFacade.preferences.isBaMandant {
                    DPAGProgressHUDWithProgress.sharedInstanceProgress.hide(true) { [weak self] in

                        guard let strongSelf = self else { return }

                        strongSelf.sharedInstanceProgress = nil
                        strongSelf.setNeedsStatusBarAppearanceUpdate()
                        strongSelf.doCheckUsage(syncDirectoriesCompletion: strongSelf.syncDirectories)
                    }
                } else {
                    self?.completionRegistrationCheck?()
                }
            } else {
                DPAGProgressHUDWithProgress.sharedInstanceProgress.hide(true) { [weak self] in
                    self?.sharedInstanceProgress = nil
                    self?.setNeedsStatusBarAppearanceUpdate()
                    self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorText, accessibilityIdentifier: "error_backup_password"))
                }
            }
        }, delegate: self) as? DPAGProgressHUDWithProgressProtocol
    }

    private func syncDirectories(completion: @escaping () -> Void) {
        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
            self?.syncHelper = DPAGSynchronizationHelperAddressbook()
            self?.syncHelper?.syncCompanyAddressbook(completion: { [weak self] in
                // keeping instance alive until work is finished
                self?.syncHelper = nil
                completion()
            })
        }
    }
}

extension DPAGBackupRecoverViewController: DPAGRegistrationCompletedCheck {
    var completionRegistrationCheck: DPAGCompletion? {
        { [weak self] in
            self?.performBlockOnMainThread { [weak self] in
                if let requestAccountViewController = self?.navigationController?.viewControllers.first(where: { (vc) -> Bool in
                    vc is DPAGRequestAccountViewControllerProtocol
                }) as? DPAGRequestAccountViewControllerProtocol {
                    requestAccountViewController.resetPassword()
                }
                NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_COMPLETE_LOGIN, object: nil)
                self?.dismiss(animated: false, completion: nil)
                DPAGProgressHUDWithProgress.sharedInstanceProgress.hide(true, completion: {
                    self?.sharedInstanceProgress = nil
                    self?.setNeedsStatusBarAppearanceUpdate()
                })
            }
        }
    }
}

extension DPAGBackupRecoverViewController: DPAGChatLabelDelegate {
    func didSelectLinkWithURL(_: URL) {
        let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .destructive, handler: { [weak self] _ in
            self?.navigationController?.setViewControllers([DPAGApplicationFacadeUIRegistration.introVC(), DPAGApplicationFacadeUIRegistration.createDeviceWelcomeVC()], animated: true)
        })
        self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "registration.backup_recover.alertCreateDevice.title", messageIdentifier: "registration.backup_recover.alertCreateDevice.message", cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
    }
}

extension DPAGBackupRecoverViewController: DPAGProgressHUDDelegate {
    func setupHUD(_ hud: DPAGProgressHUDProtocol) {
        if let hudWithLabels = hud as? DPAGProgressHUDWithProgressProtocol {
            hudWithLabels.labelTitle.text = DPAGLocalizedString("backup.recover.title")
            hudWithLabels.labelDescription.text = ""
            hudWithLabels.viewProgress.progress = 0
        }
    }
}

extension DPAGBackupRecoverViewController: DPAGBackupRecoverViewControllerPKDelegate {
    func handleProceedWithBackupOverride(backupEntry: DPAGBackupFileInfo) {
        let vc = DPAGApplicationFacadeUIRegistration.backupRecoverPasswordVC(backup: backupEntry, delegatePassword: self)
        let navVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)
        self.navigationController?.present(navVC, animated: true, completion: nil)
    }
}
