//
//  DPAGChangePasswordBaseViewController.swift
// ginlo
//
//  Created by RBU on 08/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGChangePasswordBaseViewController: DPAGViewControllerWithKeyboard, DPAGPasswordInputDelegate {
    public var forceBackToRoot = true
    public var isNewPassword = false

    @IBOutlet var scrollView: UIScrollView!

    @IBOutlet var switchInputType: UISwitch! {
        didSet {
            self.switchInputType.accessibilityIdentifier = "switchInputType"
            self.switchInputType.addTarget(self, action: #selector(handleInputTypeSwitched(_:)), for: .valueChanged)
            self.switchInputType.isOn = DPAGApplicationFacade.preferences.canUseSimplePin && (self.passwordType == .pin)
            self.switchInputType.isEnabled = DPAGApplicationFacade.preferences.canUseSimplePin
            self.switchInputType.isHidden = !DPAGApplicationFacade.preferences.canUseSimplePin
        }
    }

    @IBOutlet var labelInputType: UILabel! {
        didSet {
            self.labelInputType.text = DPAGLocalizedString("registration.inputType.initialPassword")
            self.labelInputType.font = UIFont.kFontHeadline
            self.labelInputType.textColor = DPAGColorProvider.shared[.labelText]
            self.labelInputType.numberOfLines = 0
            self.labelInputType.isHidden = !DPAGApplicationFacade.preferences.canUseSimplePin
        }
    }

    @IBOutlet var passwordInputContainer: UIView!
    @IBOutlet var labelHeadline: UILabel! {
        didSet {
            self.labelHeadline.numberOfLines = 0
            self.labelHeadline.font = UIFont.kFontTitle1
            self.labelHeadline.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet var labelHeadlineDescription: UILabel! {
        didSet {
            self.labelHeadlineDescription.numberOfLines = 0
            self.labelHeadlineDescription.font = UIFont.kFontFootnote
            self.labelHeadlineDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.labelHeadlineDescription.isHidden = true
        }
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelInputType.textColor = DPAGColorProvider.shared[.labelText]
                self.labelHeadline.textColor = DPAGColorProvider.shared[.labelText]
                self.labelHeadlineDescription.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet var btnSkipSetPassword: UIButton! {
        didSet {
            self.btnSkipSetPassword.configureButton()
            self.btnSkipSetPassword.isHidden = true
        }
    }

    @IBOutlet var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.accessibilityIdentifier = "buttonNext"
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("res.continue"), for: .normal)
            self.viewButtonNext.button.isEnabled = false
            self.viewButtonNext.button.addTarget(self, action: #selector(handleContinueTapped(_:)), for: .touchUpInside)
        }
    }

    @IBOutlet private var constraintButtonNextBottom: NSLayoutConstraint!

    var passwordViewControllerPIN: (UIViewController & DPAGPINPasswordViewControllerProtocol)?
    var passwordViewControllerComplex: (UIViewController & DPAGComplexPasswordViewControllerProtocol)?
    var passwordType: DPAGPasswordType = DPAGPasswordType.complex

    @IBOutlet var constraintPasswordInputHeight: NSLayoutConstraint!

    var passwordViewController: (UIViewController & DPAGPasswordViewControllerProtocol)? {
        self.passwordViewControllerComplex ?? self.passwordViewControllerPIN
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.passwordViewController?.reset()

        self.setupInputType(completion: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.passwordViewController?.becomeFirstResponder()
    }

    override func handleKeyboardWillShow(_ aNotification: Notification) {
        super.handleKeyboardWillShow(aNotification, scrollView: self.scrollView, viewVisible: self.passwordInputContainer, viewButtonPrimary: self.viewButtonNext)
    }

    override func handleKeyboardWillHide(_ aNotification: Notification) {
        super.handleKeyboardWillHide(aNotification, scrollView: self.scrollView, viewButtonPrimary: self.viewButtonNext)
    }

    override func handleViewTapped(_: Any?) {
        self.passwordViewController?.resignFirstResponder()
    }

    @objc
    func handleContinueTapped(_: Any?) {
        self.passwordViewController?.authenticate()
        // self.proceedWithPassword(self.passwordViewController?.getEnteredPassword())
    }

    func setupInputType(completion: DPAGCompletion?) {
        if self.switchInputType.isOn, self.passwordViewControllerPIN == nil {
            self.passwordViewController?.resignFirstResponder()

            self.passwordType = .pin

            let passwordViewControllerPIN = DPAGApplicationFacadeUIBase.passwordPINVC(secLevelView: true)

            passwordViewControllerPIN.delegate = self
            passwordViewControllerPIN.state = .changePassword

            passwordViewControllerPIN.view.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]

            passwordViewControllerPIN.view.layoutIfNeeded()

            self.constraintPasswordInputHeight.constant = passwordViewControllerPIN.view.frame.size.height

            passwordViewControllerPIN.view.frame = CGRect(x: 0, y: 0, width: self.passwordInputContainer.frame.size.width, height: self.constraintPasswordInputHeight.constant)

            passwordViewControllerPIN.view.layoutIfNeeded()

            self.passwordViewControllerComplex?.willMove(toParent: nil)
            self.passwordViewControllerComplex?.view.removeFromSuperview()
            self.passwordViewControllerComplex?.removeFromParent()

            passwordViewControllerPIN.willMove(toParent: self)
            self.addChild(passwordViewControllerPIN)
            self.passwordInputContainer.addSubview(passwordViewControllerPIN.view)

            self.passwordViewControllerPIN = passwordViewControllerPIN

            self.view.setNeedsUpdateConstraints()

            if let completion = completion {
                UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: { [weak self] in

                    self?.view.layoutIfNeeded()
                }, completion: { [weak self] _ in

                    passwordViewControllerPIN.didMove(toParent: self)
                    self?.passwordViewControllerComplex?.didMove(toParent: nil)
                    self?.passwordViewControllerComplex = nil
                    self?.viewButtonNext.isEnabled = self?.passwordViewController?.passwordEnteredCanBeValidated(self?.passwordViewController?.getEnteredPassword()) ?? false
                    completion()
                })
            } else {
                self.view.layoutIfNeeded()
                passwordViewControllerPIN.didMove(toParent: self)
                self.passwordViewControllerComplex?.didMove(toParent: nil)
                self.passwordViewControllerComplex = nil
                self.viewButtonNext.isEnabled = self.passwordViewController?.passwordEnteredCanBeValidated(self.passwordViewController?.getEnteredPassword()) ?? false
            }
        } else if !self.switchInputType.isOn, self.passwordViewControllerComplex == nil {
            self.passwordViewController?.resignFirstResponder()

            self.passwordType = .complex

            let passwordViewControllerComplex = DPAGApplicationFacadeUIBase.passwordComplexVC(secLevelView: true, isNewPassword: self.isNewPassword)

            passwordViewControllerComplex.delegate = self
            passwordViewControllerComplex.state = .changePassword

            self.passwordViewControllerPIN?.willMove(toParent: nil)
            self.passwordViewControllerPIN?.view.removeFromSuperview()
            self.passwordViewControllerPIN?.removeFromParent()

            passwordViewControllerComplex.willMove(toParent: self)
            self.addChild(passwordViewControllerComplex)
            self.passwordInputContainer.addSubview(passwordViewControllerComplex.view)

            passwordViewControllerComplex.view.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate(self.passwordInputContainer.constraintsFill(subview: passwordViewControllerComplex.view))

            self.passwordViewControllerComplex = passwordViewControllerComplex

            self.view.setNeedsUpdateConstraints()

            if let completion = completion {
                UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: { [weak self] in

                    self?.view.layoutIfNeeded()
                }, completion: { [weak self] _ in

                    passwordViewControllerComplex.didMove(toParent: self)
                    self?.passwordViewControllerPIN?.didMove(toParent: nil)
                    self?.passwordViewControllerPIN = nil

                    self?.viewButtonNext.isEnabled = self?.passwordViewController?.passwordEnteredCanBeValidated(self?.passwordViewController?.getEnteredPassword()) ?? false
                    completion()
                })
            } else {
                self.view.layoutIfNeeded()
                passwordViewControllerComplex.didMove(toParent: self)
                self.passwordViewControllerPIN?.didMove(toParent: nil)
                self.passwordViewControllerPIN = nil

                self.viewButtonNext.isEnabled = self.passwordViewController?.passwordEnteredCanBeValidated(self.passwordViewController?.getEnteredPassword()) ?? false
            }
        } else {
            completion?()
        }
    }

    @objc
    func handleInputTypeSwitched(_: Any?) {
        self.setupInputType { [weak self] in
            self?.passwordViewController?.becomeFirstResponder()
        }
    }

    @objc
    func proceedWithPassword(_: String?) {
        self.doesNotRecognizeSelector(#selector(proceedWithPassword(_:)))
    }

    @IBAction private func btnSkipPasswordPressed(_: Any) {
        if self.forceBackToRoot {
            self.navigationController?.popToRootViewController(animated: true)
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }

    // MARK: - @protocol DPAGPasswordInputDelegate

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let textFieldText = textField.text {
            let text: NSString = textFieldText as NSString
            let resultedString = text.replacingCharacters(in: range, with: string)

            self.viewButtonNext.isEnabled = self.passwordViewController?.passwordEnteredCanBeValidated(resultedString) ?? false
        }
        return true
    }

    func passwordViewController(_: DPAGPasswordViewControllerProtocol, finishedInputWithPassword password: String?) {
        self.proceedWithPassword(password)
    }
}
