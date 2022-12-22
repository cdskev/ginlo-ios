//
//  DPAGBackupPasswordViewController.swift
// ginlo
//
//  Created by RBU on 23/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

class DPAGBackupPasswordViewController: DPAGPasswordViewControllerBase {
    override var labelHeadline: UILabel? {
        didSet {
            self.labelHeadline?.text = DPAGLocalizedString("settings.backup.password.set.headline")
        }
    }

    override var labelDescription: UILabel? {
        didSet {
            self.labelDescription?.text = DPAGLocalizedString("settings.backup.password.set.description")
        }
    }

    init() {
        super.init(nibName: "DPAGBackupPasswordViewController", bundle: Bundle(for: type(of: self)))

        self.isNewPassword = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func configureView() {
        super.configureView()

        self.title = DPAGLocalizedString("settings.backup.password.set.title")

        self.setupInputTypeComplex(true)
        self.passwordViewController?.state = .backup
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.passwordViewController?.becomeFirstResponder()
    }

    override func handleContinueTapped(_ sender: Any?) {
        self.dismissKeyboard(sender)

        guard let passwordEntered = self.enteredPassword(), passwordEntered.isEmpty == false else {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "registration.validation.passwordCannotBeEmpty"))
            return
        }

        let vc = DPAGApplicationFacadeUISettings.backupPasswordRepeatVC(password: passwordEntered)

        self.navigationController?.pushViewController(vc, animated: true)
    }
}
