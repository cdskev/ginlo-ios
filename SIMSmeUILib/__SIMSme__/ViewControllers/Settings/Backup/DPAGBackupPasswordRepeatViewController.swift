//
//  DPAGBackupPasswordRepeatViewController.swift
//  SIMSme
//
//  Created by RBU on 23/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGBackupPasswordRepeatViewController: DPAGPasswordViewControllerBase {
    private let passwordEntered: String

    init(password: String) {
        self.passwordEntered = password

        super.init(nibName: "DPAGBackupPasswordRepeatViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func configureView() {
        super.configureView()

        self.title = DPAGLocalizedString("settings.backup.password.repeat.title")

        self.labelHeadline?.text = DPAGLocalizedString("settings.backup.password.repeat.headline")

        self.setupInputTypeComplex(false)
        self.passwordViewController?.state = .backup
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.passwordViewController?.becomeFirstResponder()
    }

    override func handleContinueTapped(_ sender: Any?) {
        self.dismissKeyboard(sender)

        guard let passwordCurrent = self.enteredPassword(), passwordCurrent.isEmpty == false else {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "registration.validation.passwordCannotBeEmpty"))
            return
        }

        if self.passwordViewControllerPIN != nil, passwordCurrent.count < 4 {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "registration.validation.pinIsTooShort"))
        } else if self.passwordEntered != passwordCurrent {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "registration.validation.passwordDoesNotMatch"))
        } else {
            // BackupPasswort setzen
            let hasPassword = DPAGApplicationFacade.backupWorker.loadKeyConfig()

            do {
                try DPAGApplicationFacade.backupWorker.createKey(pwd: passwordCurrent)
            } catch {
                self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: error.localizedDescription))
                return
            }

            // Automatisches Backup starten
            if let vcBackupNext = self.navigationController?.viewControllers.first(where: { $0 is DPAGBackupViewControllerProtocol }) as? (UIViewController & DPAGBackupViewControllerProtocol) {
                // Automatisches Backup nur starten, wenn vorher noch kein Passwort gesetzt war...
                vcBackupNext.automaticStartBackup = !hasPassword

                _ = self.navigationController?.popToViewController(vcBackupNext, animated: true)

                if hasPassword {
                    vcBackupNext.presentErrorAlert(alertConfig: AlertConfigError(titleIdentifier: "registration.dontAskForPassword.alertTitle", messageIdentifier: "settings.backup.password.passwordchanged"))
                }
            }
        }
    }
}
