//
//  DPAGCompanyEnterRecoveryKeyViewController.swift
// ginlo
//
//  Created by Yves Hetzer on 09.06.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGCompanyEnterRecoveryKeyViewController: DPAGViewControllerWithKeyboard, UITextFieldDelegate {
    @IBOutlet private var labelHeader: UILabel! {
        didSet {
            self.labelHeader.text = DPAGLocalizedString("recoveryKeyInput.labelHeader.text")
            self.labelHeader.font = UIFont.kFontTitle1
            self.labelHeader.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelDescription: UILabel! {
        didSet {
            self.labelDescription.text = DPAGLocalizedString("recoveryKeyInput.labelDescription.text")
            self.labelDescription.font = UIFont.kFontSubheadline
            self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var textField0: DPAGTextField! {
        didSet {
            self.textField0.accessibilityIdentifier = "textField0"
            self.configureTextField(self.textField0)
            self.textField0.attributedPlaceholder = NSAttributedString(string: "A0A0", attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        }
    }

    @IBOutlet private var textField1: DPAGTextField! {
        didSet {
            self.textField1.accessibilityIdentifier = "textField1"
            self.configureTextField(self.textField1)
            self.textField1.attributedPlaceholder = NSAttributedString(string: "B1B1", attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        }
    }

    @IBOutlet private var textField2: DPAGTextField! {
        didSet {
            self.textField2.accessibilityIdentifier = "textField2"
            self.configureTextField(self.textField2)
            self.textField2.attributedPlaceholder = NSAttributedString(string: "C2C2", attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        }
    }

    @IBOutlet private var textField3: DPAGTextField! {
        didSet {
            self.textField3.accessibilityIdentifier = "textField3"
            self.configureTextField(self.textField3)
            self.textField3.attributedPlaceholder = NSAttributedString(string: "D3D3", attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        }
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.accessibilityIdentifier = "btnActivate"
            self.viewButtonNext.button.addTarget(self, action: #selector(handleActivate), for: .touchUpInside)
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("recoveryKeyInput.btnActivate"), for: .normal)
            self.viewButtonNext.isEnabled = false
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelHeader.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.textField0.attributedPlaceholder = NSAttributedString(string: "A0A0", attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
                self.textField1.attributedPlaceholder = NSAttributedString(string: "B1B1", attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
                self.textField2.attributedPlaceholder = NSAttributedString(string: "C2C2", attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
                self.textField3.attributedPlaceholder = NSAttributedString(string: "D3D3", attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var constraintButtonNextBottom: NSLayoutConstraint!

    @IBOutlet private var scrollView: UIScrollView!

    init() {
        super.init(nibName: "DPAGCompanyEnterRecoveryKeyViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.navigationItem.title = DPAGLocalizedString("recoveryKeyInput.title")

        self.textField0.configure(textFieldBefore: nil, textFieldAfter: self.textField1, textFieldMaxLength: 4, didChangeCompletion: self.updateBtnState)
        self.textField1.configure(textFieldBefore: self.textField0, textFieldAfter: self.textField2, textFieldMaxLength: 4, didChangeCompletion: self.updateBtnState)
        self.textField2.configure(textFieldBefore: self.textField1, textFieldAfter: self.textField3, textFieldMaxLength: 4, didChangeCompletion: self.updateBtnState)
        self.textField3.configure(textFieldBefore: self.textField2, textFieldAfter: nil, textFieldMaxLength: 4, didChangeCompletion: self.updateBtnState)
    }

    override func viewFirstAppear(_: Bool) {
        self.textField0.becomeFirstResponder()
        self.updateBtnState()
    }

    private func configureTextField(_ textField: DPAGTextField) {
        textField.configureDefault()
        textField.setPaddingLeftTo(1)
        textField.setPaddingRightTo(1)
        textField.font = UIFont.kFontCodeInput
        textField.delegate = self
        textField.spellCheckingType = .no
        textField.autocorrectionType = .no
        textField.keyboardType = .default
        textField.textAlignment = .center
    }

    private func updateBtnState() {
        let password = String(format: "%@%@%@%@", self.textField0.text ?? "", self.textField1.text ?? "", self.textField2.text ?? "", self.textField3.text ?? "")

        if password.count >= 16 {
            self.viewButtonNext.isEnabled = true
        } else {
            self.viewButtonNext.isEnabled = false
        }
    }

    @objc
    private func handleActivate() {
        let password = String(format: "%@%@%@%@", self.textField0.text ?? "", self.textField1.text ?? "", self.textField2.text ?? "", self.textField3.text ?? "")

        if (try? DPAGApplicationFacade.accountManager.decryptCompanyRecoveryPasswordFile(password: password)) ?? false {
            if let loginViewController = self.presentingViewController as? DPAGLoginViewControllerProtocol {
                // Push Back to Login Controller
                self.dismiss(animated: true, completion: { [weak loginViewController] in
                    // needChangePasswort auf true6
                    loginViewController?.companyRecoveryPasswordSuccess()
                })
            }
        } else {
            let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: nil)

            self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "business.alert.accountManagement.companyRecoveryKeyWrong.title", messageIdentifier: "business.alert.accountManagement.companyRecoveryKeyWrong.message", otherButtonActions: [actionOK]))
        }
    }

    override func handleViewTapped(_: Any?) {
        self.textField0.resignFirstResponder()
        self.textField1.resignFirstResponder()
        self.textField2.resignFirstResponder()
        self.textField3.resignFirstResponder()
    }

    override func handleKeyboardWillShow(_ aNotification: Notification) {
        super.handleKeyboardWillShow(aNotification, scrollView: self.scrollView, viewVisible: self.textField0, viewButtonPrimary: self.viewButtonNext)
    }

    override func handleKeyboardWillHide(_ aNotification: Notification) {
        super.handleKeyboardWillHide(aNotification, scrollView: self.scrollView, viewButtonPrimary: self.viewButtonNext)
    }
}
