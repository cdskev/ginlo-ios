//
//  DPAGPasswordViewControllerBase.swift
// ginlo
//
//  Created by RBU on 23/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

open class DPAGPasswordViewControllerBase: DPAGViewControllerWithKeyboard, DPAGPasswordInputDelegate {
    public var isNewPassword = false

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet open var labelHeadline: UILabel? {
        didSet {
            self.labelHeadline?.font = UIFont.kFontTitle1
            self.labelHeadline?.textColor = DPAGColorProvider.shared[.labelText]
            self.labelHeadline?.numberOfLines = 0
        }
    }

    @IBOutlet open var labelDescription: UILabel? {
        didSet {
            self.labelDescription?.font = UIFont.kFontSubheadline
            self.labelDescription?.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDescription?.numberOfLines = 0
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelHeadline?.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDescription?.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet public var viewPasswordInput: UIView!

    @IBOutlet open var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.accessibilityIdentifier = "buttonNext"
            self.viewButtonNext.button.addTarget(self, action: #selector(handleContinueTapped(_:)), for: .touchUpInside)
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("res.continue"), for: .normal)
        }
    }

    @IBOutlet private var constraintPasswordInputHeight: NSLayoutConstraint!

    public var passwordViewControllerPIN: (UIViewController & DPAGPINPasswordViewControllerProtocol)?
    public var passwordViewControllerComplex: (UIViewController & DPAGComplexPasswordViewControllerProtocol)?

    override open func viewDidLoad() {
        super.viewDidLoad()
        self.configureView()
    }

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.passwordViewController?.reset()
        self.viewButtonNext.isEnabled = false
    }

    open func configureView() {}

    @objc
    open func handleContinueTapped(_: Any?) {
        self.doesNotRecognizeSelector(#selector(handleContinueTapped(_:)))
    }

    public var passwordViewController: (UIViewController & DPAGPasswordViewControllerProtocol)? {
        self.passwordViewControllerComplex ?? self.passwordViewControllerPIN
    }

    public func setupInputTypeComplex(_ secLevelView: Bool) {
        self.passwordViewControllerComplex = DPAGApplicationFacadeUIBase.passwordComplexVC(secLevelView: secLevelView, isNewPassword: self.isNewPassword)
        if let vcPasswortNext = self.passwordViewControllerComplex {
            vcPasswortNext.state = .changePassword
            vcPasswortNext.willMove(toParent: self)
            self.addChild(vcPasswortNext)
            self.viewPasswordInput.addSubview(vcPasswortNext.view)
            vcPasswortNext.didMove(toParent: self)
            vcPasswortNext.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate(self.viewPasswordInput.constraintsFill(subview: vcPasswortNext.view))
            self.passwordViewControllerPIN = nil
            vcPasswortNext.delegate = self
            self.viewButtonNext.isEnabled = vcPasswortNext.passwordEnteredCanBeValidated(vcPasswortNext.getEnteredPassword())
        }
    }

    open func enteredPassword() -> String? {
        self.passwordViewController?.getEnteredPassword()
    }

    // MARK: - DPAGPasswordInputDelegate

    open func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let textFieldText = textField.text {
            let text: NSString = textFieldText as NSString
            let resultedString = text.replacingCharacters(in: range, with: string)
            self.viewButtonNext.isEnabled = self.passwordViewController?.passwordEnteredCanBeValidated(resultedString) ?? false
        } else {
            self.viewButtonNext.isEnabled = false
        }

        return true
    }

    public func passwordViewController(_: DPAGPasswordViewControllerProtocol, finishedInputWithPassword _: String?) {
        self.handleContinueTapped(nil)
    }

    // MARK: - Keyboard Handling

    override open func handleViewTapped(_ sender: Any?) {
        self.dismissKeyboard(sender)
    }

    override open func handleKeyboardWillShow(_ aNotification: Notification) {
        super.handleKeyboardWillShow(aNotification, scrollView: self.scrollView, viewVisible: self.viewPasswordInput, viewButtonPrimary: self.viewButtonNext)
    }

    override open func handleKeyboardWillHide(_ aNotification: Notification) {
        super.handleKeyboardWillHide(aNotification, scrollView: self.scrollView, viewButtonPrimary: self.viewButtonNext)
    }

    public func dismissKeyboard(_: Any?) {
        _ = self.passwordViewControllerComplex?.resignFirstResponder()
        _ = self.passwordViewControllerPIN?.resignFirstResponder()
    }
}
