//
//  DPAGBackupRecoverPasswordViewController.swift
//  SIMSme
//
//  Created by RBU on 26/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGBackupRecoverPasswordViewController: DPAGPasswordViewControllerBase {
    override var labelHeadline: UILabel? {
        didSet {
            self.labelHeadline?.text = DPAGLocalizedString("registration.backup.recover.password.headline")
        }
    }

    override var labelDescription: UILabel? {
        didSet {
            self.labelDescription?.text = DPAGLocalizedString("registration.backup.recover.password.description")
        }
    }

    @IBOutlet private var labelFooter: UILabel! {
        didSet {
            self.labelFooter.text = DPAGLocalizedString("registration.backup.recover.password.footer")
            self.labelFooter.textColor = DPAGColorProvider.shared[.labelText]
            self.labelFooter.font = UIFont.kFontFootnote
            self.labelFooter.numberOfLines = 0
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelFooter.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    private let backupFile: DPAGBackupFileInfo

    private weak var delegatePassword: DPAGBackupRecoverPasswordViewControllerDelegate?

    init(backup: DPAGBackupFileInfo, delegatePassword: DPAGBackupRecoverPasswordViewControllerDelegate?) {
        self.backupFile = backup
        self.delegatePassword = delegatePassword

        super.init(nibName: "DPAGBackupRecoverPasswordViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func configureView() {
        super.configureView()

        self.title = DPAGLocalizedString("registration.backup.recover.password.title")

        self.setupInputTypeComplex(false)
        self.passwordViewController?.state = .backup

        self.setLeftBarButtonItem(title: "res.cancel", action: #selector(dismissView))
    }

    @objc
    private func dismissView() {
        self.passwordViewController?.resignFirstResponder()
        self.dismiss(animated: true, completion: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.passwordViewController?.becomeFirstResponder()
    }

    override func viewFirstAppear(_ animated: Bool) {
        super.viewFirstAppear(animated)
    }

    override func handleContinueTapped(_ sender: Any?) {
        self.dismissKeyboard(sender)
        guard let passwordEntered = self.enteredPassword(), passwordEntered.isEmpty == false else {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "registration.validation.passwordCannotBeEmpty"))
            return
        }

        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            guard let strongSelf = self else { return }
            do {
                try DPAGApplicationFacade.backupWorker.checkPassword(backupFileInfo: strongSelf.backupFile, withPassword: passwordEntered)
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    self?.dismiss(animated: true) { [weak self] in
                        guard let strongSelf = self else { return }
                        strongSelf.delegatePassword?.handlePasswordEntered(strongSelf.backupFile, password: passwordEntered)
                    }
                }
            } catch {
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "backup.recover.wrongpassword"))
                }
            }
        }
    }
}
