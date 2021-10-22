//
//  DPAGPasswordViewController.swift
// ginlo
//
//  Created by RBU on 09/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGPasswordViewController: UIViewController, DPAGPasswordViewControllerProtocol {
    weak var delegate: DPAGPasswordInputDelegate?

    var state: DPAGPasswordViewControllerState = .login

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.view.accessibilityIdentifier = "\(type(of: self))".components(separatedBy: ".").last
    }

    func activate() {}

    func reset() {}

    func authenticate() {}

    func verifyPassword(checkSimplePinUsage: Bool) -> DPAGPasswordViewControllerVerifyState {
        DPAGApplicationFacade.preferences.verifyPassword(self.getEnteredPassword(), checkSimplePinUsage: checkSimplePinUsage)
    }

    func checkPasswordDuration() -> Bool {
        if !DPAGApplicationFacade.preferences.isBaMandant {
            return true
        }
        if let maxPwdDuration = DPAGApplicationFacade.preferences.passwordMaxDuration {
            if maxPwdDuration > 0 {
                if let pwdSetDate = DPAGApplicationFacade.preferences.passwordSetAt {
                    let pwdExpireDate = pwdSetDate.addingDays(maxPwdDuration)
                    if pwdExpireDate.isInFuture {
                        return true
                    }
                }
                return false
            }
        }
        return true
    }

    func checkPasswordReusability() -> Bool {
        if !DPAGApplicationFacade.preferences.isBaMandant {
            return true
        }
        guard DPAGApplicationFacade.preferences.getUsedPasswordEntriesCount() != nil else { return true }
        guard let password = self.getEnteredPassword() else { return true }
        let chelper = CryptoHelper.sharedInstance
        guard let usedPwds = DPAGApplicationFacade.preferences.getUsedHashedPasswords() else { return true }
        for hashedPwd: String in usedPwds {
            do {
                if try chelper?.checkPassword(password: password, withHash: hashedPwd) ?? false {
                    return false
                }
            } catch {
                DPAGLog(error)
            }
        }
        return true
    }

    func passwordEnteredCanBeValidated(_ enteredPassword: String?) -> Bool {
        (enteredPassword?.isEmpty ?? true) == false
    }

    func getEnteredPassword() -> String? {
        nil
    }

    func checkPasswordAndProceed(_ password: String?) -> Bool {
        guard let password = password else {
            self.delegate?.passwordIsInvalid()
            return false
        }
        var retVal = false
        var retry = 3
        while retry > 0, !retVal {
            do {
                try CryptoHelper.sharedInstance?.decryptPrivateKey(password: password, saveDecryptedPK: false)
                retVal = true
            } catch {
                retry -= 1
                if retry == 0 {
                    self.delegate?.passwordIsInvalid()
                    retVal = false
                }
            }
        }
        if retVal {
            self.delegate?.passwordIsValid()
        }
        return retVal
    }

    func tryToDecryptPrivateKey(_ enteredPassword: String?) -> Bool {
        guard let enteredPassword = enteredPassword else {
            self.delegate?.passwordDidNotDecryptPrivateKey()
            return false
        }
        var retVal = false
        var retry = 3
        while retry > 0, !retVal {
            do {
                try CryptoHelper.sharedInstance?.decryptPrivateKey(password: enteredPassword, saveDecryptedPK: false)
                retVal = true
            } catch {
                retry -= 1
                if retry == 0 {
                    self.delegate?.passwordDidNotDecryptPrivateKey()
                    retVal = false
                }
            }
        }
        if retVal {
            if !self.verifyPassword(checkSimplePinUsage: true).contains(.PwdOk) {
                self.delegate?.passwordCorrespondsNotToThePasswordPolicies()
            } else if !self.checkPasswordDuration() {
                self.delegate?.passwordIsExpired()
            } else {
                self.delegate?.passwordDidDecryptPrivateKey()
            }
        }
        return retVal
    }
}
