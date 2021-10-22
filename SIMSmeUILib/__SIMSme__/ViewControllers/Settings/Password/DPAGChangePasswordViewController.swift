//
//  DPAGChangePasswordViewController.swift
// ginlo
//
//  Created by RBU on 08/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGChangePasswordViewControllerProtocol {}

class DPAGChangePasswordViewController: DPAGChangePasswordBaseViewController, DPAGChangePasswordViewControllerProtocol {
    init() {
        super.init(nibName: "DPAGChangePasswordViewController", bundle: Bundle(for: type(of: self)))

        self.passwordType = DPAGApplicationFacade.preferences.passwordType
        self.isNewPassword = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = DPAGLocalizedString("settings.password.changePassword")

        self.labelHeadline.text = DPAGLocalizedString("registration.headline.initialPassword")

        if DPAGApplicationFacade.preferences.hasSystemGeneratedPassword {
            self.navigationItem.title = DPAGLocalizedString("registration.headline.initialPassword2.title")

            self.labelHeadline.text = DPAGLocalizedString("registration.headline.initialPassword2")
            self.labelHeadlineDescription.text = DPAGLocalizedString("registration.headline.initialPassword2.desc")
            self.labelHeadlineDescription.isHidden = false

            self.btnSkipSetPassword.isHidden = false
            self.btnSkipSetPassword.setTitle(DPAGLocalizedString("registration.changePassword.skipSetPassword"), for: .normal)

            self.btnSkipSetPassword.setTitle(DPAGLocalizedString("registration.changePassword.skipSetPassword"), for: .selected)

            self.viewButtonNext.button.setTitle(DPAGLocalizedString("registration.headline.initialPassword2.next"), for: .normal)
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("registration.headline.initialPassword2.next"), for: .selected)
        }
    }

    override func proceedWithPassword(_ password: String?) {
        if let pwd = password, pwd.isEmpty == false {
            /* if let passwordViewControllerComplex = self.passwordViewController as? DPAGComplexPasswordViewControllerProtocol
             {
                 let verifyState = passwordViewControllerComplex.verifyPassword()

                 if (!verifyState.contains(DPAGPasswordVerifyState.PwdOk))
                 {
                     self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "registration.validation.pwd_verifcation_fails")
                     return
                 }
             } */

            let vc = DPAGApplicationFacadeUISettings.changePasswordRepeatVC(password: pwd, passwordType: self.passwordType)

            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}
