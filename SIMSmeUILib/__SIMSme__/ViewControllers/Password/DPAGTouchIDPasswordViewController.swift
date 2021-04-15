//
//  DPAGTouchIDPasswordViewController.swift
//  SIMSme
//
//  Created by RBU on 09/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import LocalAuthentication
import SIMSmeCore
import UIKit

class DPAGTouchIDPasswordViewController: DPAGPasswordViewController, DPAGTouchIDPasswordViewControllerProtocol {
    private var isCancelled = false
    private var authenticationFailed = false

    override func activate() {
        super.activate()

        self.authenticateUser()
    }

    override func reset() {
        super.reset()

        self.isCancelled = true
    }

    private func authenticateUser() {
        self.isCancelled = false

        let context = LAContext()

        var error: NSError?
        let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics

        if context.canEvaluatePolicy(policy, error: &error) {
            context.evaluatePolicy(policy, localizedReason: DPAGLocalizedString("touchID.unlock.message"), reply: { [weak self] success, _ in

                guard let strongSelf = self else { return }

                var isPrivateKeyDecrypted = false

                if strongSelf.isCancelled == false, success {
                    do {
                        try CryptoHelper.sharedInstance?.decryptTouchIDPrivateKey()
                    } catch {
                        DPAGLog(error, message: "DecryptTouchIDPrivateKey failed with exception")
                    }

                    isPrivateKeyDecrypted = CryptoHelper.sharedInstance?.isPrivateKeyDecrypted() ?? false
                }

                if isPrivateKeyDecrypted {
                    strongSelf.handleAuthenticationSucceeded()
                } else {
                    strongSelf.handleAuthenticationFailed()
                }
            })
        } else {
            if let error = error, let laError = LAError.Code(rawValue: error.code) {
                switch laError {
                case .authenticationFailed:
                    break
                case .userCancel:
                    break
                case .userFallback:
                    break
                case .systemCancel:
                    break
                case .passcodeNotSet:
                    break
                case .touchIDNotEnrolled:
                    break
                default:
                    break
                }
            }
            self.handleAuthenticationFailed()
            _ = self.becomeFirstResponder()
        }
    }

    private func handleAuthenticationSucceeded() {
        OperationQueue.main.addOperation { [weak self] in

            guard let strongSelf = self else { return }

            switch strongSelf.state {
            case .login:

                strongSelf.delegate?.passwordDidDecryptPrivateKey()

            case .enterPassword:

                strongSelf.delegate?.passwordIsValid()

            case .registration, .changePassword:
                break

            case .backup:
                break
            }
        }
    }

    private func handleAuthenticationFailed() {
        if self.isCancelled == false {
            self.authenticationFailed = true
        }
    }

    override func becomeFirstResponder() -> Bool {
        if self.authenticationFailed {
            OperationQueue.main.addOperation { [weak self] in

                self?.delegate?.touchIDAuthenticationFailed()
                self?.authenticationFailed = false
            }
        }
        return super.becomeFirstResponder()
    }
}
