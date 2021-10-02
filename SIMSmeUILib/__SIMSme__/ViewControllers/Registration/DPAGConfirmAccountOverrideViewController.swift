//
//  DPAGConfirmAccountOverrideViewController.swift
//  SIMSme
//
//  Created by RBU on 26/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGConfirmAccountOverrideViewController: DPAGViewControllerBackground {
    @IBOutlet private var scrollView: UIScrollView!

    @IBOutlet private var imageViewInfo: UIImageView! {
        didSet {
            self.imageViewInfo.image = DPAGImageProvider.shared[.kImageAlertLarge]
        }
    }

    @IBOutlet private var labelDescription: UILabel! {
        didSet {
            self.labelDescription.text = DPAGLocalizedString("registration.confirm_override.description")
            self.labelDescription.font = UIFont.kFontSubheadline
            self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDescription.numberOfLines = 0
        }
    }

    @IBOutlet private var labelConfirmation: UILabel! {
        didSet {
            self.labelConfirmation.text = DPAGLocalizedString("registration.confirm_override.confirmation")
            self.labelConfirmation.font = UIFont.kFontTitle1
            self.labelConfirmation.textColor = DPAGColorProvider.shared[.labelText]
            self.labelConfirmation.numberOfLines = 0
        }
    }

    @IBOutlet private var btnConfirmOverride: UIButton! {
        didSet {
            self.btnConfirmOverride.accessibilityIdentifier = "btnConfirmOverride"
            self.btnConfirmOverride.configureButtonDestructive()
            self.btnConfirmOverride.addTarget(self, action: #selector(handleOverride), for: .touchUpInside)
            self.btnConfirmOverride.setTitle(DPAGLocalizedString("registration.confirm_override.btnConfirmOverride"), for: .normal)
        }
    }

    @IBOutlet private var viewBtnCancel: UIView! {
        didSet {
            self.viewBtnCancel.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.labelConfirmation.textColor = DPAGColorProvider.shared[.labelText]
                self.viewBtnCancel.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var btnCancel: UIButton! {
        didSet {
            self.btnCancel.accessibilityIdentifier = "btnCancel"
            self.btnCancel.configurePrimaryButton()
            self.btnCancel.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
            self.btnCancel.setTitle(DPAGLocalizedString("res.cancel"), for: .normal)
        }
    }

    private let oldAccountID: String?

    init(oldAccountID: String?) {
        self.oldAccountID = oldAccountID

        super.init(nibName: "DPAGConfirmAccountOverrideViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.navigationItem.title = DPAGLocalizedString("registration.confirm_override.title")
    }

    @objc
    private func handleCancel() {
        _ = self.navigationController?.popViewController(animated: true)
    }

    @objc
    private func handleOverride() {
        if let code = DPAGApplicationFacade.preferences.bootstrappingConfirmationCode {
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                DPAGApplicationFacade.accountManager.confirmAccount(code: code, responseBlock: { [weak self] _, _, errorMessage in
                    if let errorMessage = errorMessage {
                        if errorMessage == "service.error499" {
                            self?.handleServiceError("service.error499.createAccount")
                        } else {
                            self?.handleServiceError(errorMessage)
                        }
                    } else {
                        self?.handleServiceSuccessNoBackup()
                    }
                })
            }
        }
    }

    private func handleServiceError(_ message: String) {
        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
            guard let strongSelf = self else { return }
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
            guard let strongSelf = self, let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let accountID = contact.accountID else { return }
            if let oldAccountId = self?.oldAccountID {
                do {
                    try DPAGApplicationFacade.backupWorker.deleteBackups(accountID: oldAccountId)
                } catch {
                    DPAGLog(error)
                }
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
