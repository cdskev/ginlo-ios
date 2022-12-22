//
//  DPAGChangePasswordRepeatViewController.swift
// ginlo
//
//  Created by RBU on 08/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGChangePasswordRepeatViewControllerProtocol {}

class DPAGChangePasswordRepeatViewController: DPAGChangePasswordBaseViewController, DPAGChangePasswordRepeatViewControllerProtocol {
    private var firstPasswordInput: String

    init(password: String, passwordType: DPAGPasswordType) {
        self.firstPasswordInput = password

        super.init(nibName: "DPAGChangePasswordRepeatViewController", bundle: Bundle(for: type(of: self)))

        self.passwordType = passwordType
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = DPAGLocalizedString("settings.password.changePassword")

        self.labelHeadline.text = DPAGLocalizedString("registration.headline.enterPasswordAgain")

        self.switchInputType.isEnabled = false

        // input type always hidden
        self.switchInputType.isHidden = true
        self.labelInputType.isHidden = true

        if DPAGApplicationFacade.preferences.hasSystemGeneratedPassword {
            self.navigationItem.title = DPAGLocalizedString("registration.headline.initialPassword2.title")

            self.viewButtonNext.button.setTitle(DPAGLocalizedString("registration.headline.initialPassword2.next"), for: .normal)
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("registration.headline.initialPassword2.next"), for: .selected)
        }
    }

    override func proceedWithPassword(_ password: String?) {
        if password == self.firstPasswordInput {
            self.passwordViewController?.resignFirstResponder()

            do {
                try DPAGApplicationFacade.preferences.storePasswordType(self.passwordType, password: self.firstPasswordInput)
            } catch {
                self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: error.localizedDescription))
                return
            }

            let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in

                guard let strongSelf = self else { return }

                if let vc = strongSelf.navigationController?.viewControllers.reversed().first(where: { ($0 is DPAGChangePasswordRepeatViewControllerProtocol) == false && ($0 is DPAGChangePasswordViewControllerProtocol) == false }) {
                    strongSelf.navigationController?.popToViewController(vc, animated: true)
                } else if DPAGApplicationFacadeUIBase.loginVC.mustChangePassword {
                    DPAGApplicationFacadeUIBase.loginVC.mustChangePassword = false
                    NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_COMPLETE_LOGIN, object: nil)
                } else {
                    strongSelf.navigationController?.popToRootViewController(animated: true)
                }
            })

            self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "settings.password.changePassword.complete", otherButtonActions: [actionOK]))
        } else {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "registration.validation.passwordDoesNotMatch"))
        }
    }
}
