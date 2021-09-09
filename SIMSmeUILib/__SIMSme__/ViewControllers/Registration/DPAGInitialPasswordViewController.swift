//
//  DPAGInitialPasswordViewController.swift
//  SIMSme
//
//  Created by RBU on 22/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public enum GNInitialCreationType {
    case createDevice,
         createAccount,
         scanInvitation,
         executeInvitation
}

public protocol GNInvitationUIViewController {
    var creationJob: GNInitialCreationType { get set }
    var invitationData: [String: Any]? { get set }
}

class DPAGInitialPasswordViewController: DPAGInitialPasswordBaseViewController, DPAGNavigationViewControllerStyler, GNInvitationUIViewController {
    override var labelHeadline: UILabel? {
        didSet {
            self.labelHeadline?.text = DPAGLocalizedString("registration.title.setPassword")
        }
    }

    override var labelDescription: UILabel? {
        didSet {
            self.labelDescription?.text = DPAGLocalizedString("registration.description.initialPassword")
        }
    }

    @IBOutlet private var labelInputTypeDescription: UILabel? {
        didSet {
            self.labelInputTypeDescription?.font = UIFont.kFontFootnote
            self.labelInputTypeDescription?.textColor = DPAGColorProvider.shared[.labelText]
            self.labelInputTypeDescription?.text = DPAGLocalizedString("tutorial.registration.passwordCreate.label.passwordType")
            self.labelInputTypeDescription?.numberOfLines = 0
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelInputTypeDescription?.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    override var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("registration.buttonNextLabel.initialPassword"), for: .normal)
        }
    }

    var creationJob: GNInitialCreationType
    var invitationData: [String: Any]?

    init(initialPasswordJob: GNInitialCreationType) {
        // self.createDevice = createDevice
        self.creationJob = initialPasswordJob
        super.init(nibName: "DPAGInitialPasswordViewController", bundle: Bundle(for: type(of: self)))
        self.isNewPassword = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.performBlockInBackground {
            DPAGApplicationFacade.accountManager.resetAccount()
            if let domainName = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: domainName)
            }
            DPAGApplicationFacade.reset()
        }
        DPAGApplicationFacade.preferences.passwordType = .complex
    }

    override func configureView() {
        super.configureView()
        self.title = DPAGLocalizedString("settings.password")
        self.setupInputTypeAnimated(false, secLevelView: true, withCompletion: nil)
        DPAGApplicationFacade.preferences.passwordType = (self.switchInputType?.isOn ?? false) ? .pin : .complex
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.passwordViewController?.becomeFirstResponder()
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.setNeedsStatusBarAppearanceUpdate()
    }

    override func handleContinueTapped(_ sender: Any?) {
        self.dismissKeyboard(sender)
        guard let passwordEntered = self.enteredPassword(), passwordEntered.isEmpty == false else {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "registration.validation.passwordCannotBeEmpty", okActionHandler: { [weak self] _ in
                self?.passwordViewController?.becomeFirstResponder()
            }))
            return
        }
        if self.switchInputType?.isOn ?? false, passwordEntered.count < 4 {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "registration.validation.pinIsTooShort", okActionHandler: { [weak self] _ in
                self?.passwordViewController?.becomeFirstResponder()
            }))
        } else {
            if (self.switchInputType?.isOn ?? false) == false {
                if let passwordViewControllerComplexTmp = self.passwordViewControllerComplex {
                    // check password
                    let verifyState = passwordViewControllerComplexTmp.verifyPassword(checkSimplePinUsage: false)
                    if !verifyState.contains(.PwdOk) {
                        if let msg = passwordViewControllerComplexTmp.getMessageForPasswordVerifyState(verifyState) {
                            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: msg, accessibilityIdentifier: "registration.validation.pwd_policies_fails", okActionHandler: { [weak self] _ in
                                self?.passwordViewController?.becomeFirstResponder()
                            }))
                        }
                        return
                    }
                }
            }
            var vc = DPAGApplicationFacadeUIRegistration.initialPasswordRepeatVC(password: passwordEntered, initialPasswordJob: self.creationJob)
            vc.invitationData = self.invitationData
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    override func handleInputTypeSwitched(_: Any?) {
        self.setupInputTypeAnimated(true, secLevelView: true, withCompletion: { [weak self] in
            if let strongSelf = self {
                DPAGApplicationFacade.preferences.passwordType = (strongSelf.switchInputType?.isOn ?? false) ? .pin : .complex
                strongSelf.passwordViewController?.becomeFirstResponder()
            }
        })
    }
}
