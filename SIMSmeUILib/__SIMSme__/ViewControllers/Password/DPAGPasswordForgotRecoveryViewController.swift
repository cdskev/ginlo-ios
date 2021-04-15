//
//  DPAGPasswordForgotRecoveryViewController.swift
//  SIMSme
//
//  Created by RBU on 16.01.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGPasswordForgotRecoveryViewController: DPAGViewControllerWithKeyboard {
    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var stackViewContent: UIStackView!
    @IBOutlet private var viewAlert: UIView! {
        didSet {
            self.viewAlert.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
        }
    }

    @IBOutlet private var labelAlert: UILabel! {
        didSet {
            self.labelAlert.text = DPAGLocalizedString("forgotPasswordRecovery.labelAlert")
            self.labelAlert.numberOfLines = 0
            self.labelAlert.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
            self.labelAlert.font = UIFont.kFontHeadline
            self.labelAlert.textAlignment = .center
        }
    }

    @IBOutlet private var viewTitle: UIView!
    @IBOutlet private var labelTitle: UILabel! {
        didSet {
            self.labelTitle.text = DPAGLocalizedString("forgotPasswordRecovery.labelTitle")
            self.labelTitle.numberOfLines = 0
            self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
            self.labelTitle.font = UIFont.kFontTitle1
        }
    }

    @IBOutlet private var labelDescription: UILabel! {
        didSet {
            self.labelDescription.text = DPAGLocalizedString("forgotPasswordRecovery.labelDescription")
            self.labelDescription.numberOfLines = 0
            self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDescription.font = UIFont.kFontSubheadline
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.viewAlert.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
                self.labelAlert.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
                self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var textField0: DPAGTextField! {
        didSet {
            self.configure(textField: self.textField0)
        }
    }

    @IBOutlet private var textField1: DPAGTextField! {
        didSet {
            self.configure(textField: self.textField1)
        }
    }

    @IBOutlet private var textField2: DPAGTextField! {
        didSet {
            self.configure(textField: self.textField2)
        }
    }

    @IBOutlet private var textField3: DPAGTextField! {
        didSet {
            self.configure(textField: self.textField3)
        }
    }

    @IBOutlet private var textField4: DPAGTextField! {
        didSet {
            self.configure(textField: self.textField4)
        }
    }

    @IBOutlet private var textField5: DPAGTextField! {
        didSet {
            self.configure(textField: self.textField5)
        }
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("forgotPasswordRecover.buttonRecover"), for: .normal)
            self.viewButtonNext.button.addTarget(self, action: #selector(handleRecover), for: .touchUpInside)
        }
    }

    init() {
        super.init(nibName: "DPAGPasswordForgotRecoveryViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = DPAGLocalizedString("forgotPasswordRecovery.title")

        self.viewAlert.isHidden = true

        self.textField0.configure(textFieldBefore: nil, textFieldAfter: self.textField1, textFieldMaxLength: 4, didChangeCompletion: self.updateBtnState)
        self.textField1.configure(textFieldBefore: self.textField0, textFieldAfter: self.textField2, textFieldMaxLength: 4, didChangeCompletion: self.updateBtnState)
        self.textField2.configure(textFieldBefore: self.textField1, textFieldAfter: self.textField3, textFieldMaxLength: 4, didChangeCompletion: self.updateBtnState)
        self.textField3.configure(textFieldBefore: self.textField2, textFieldAfter: self.textField4, textFieldMaxLength: 4, didChangeCompletion: self.updateBtnState)
        self.textField4.configure(textFieldBefore: self.textField3, textFieldAfter: self.textField5, textFieldMaxLength: 4, didChangeCompletion: self.updateBtnState)
        self.textField5.configure(textFieldBefore: self.textField4, textFieldAfter: nil, textFieldMaxLength: 4, didChangeCompletion: self.updateBtnState)

        self.viewButtonNext.isEnabled = false
    }

    private func configure(textField: DPAGTextField) {
        textField.configureDefault()
        textField.setPaddingLeftTo(1)
        textField.setPaddingRightTo(1)

        textField.attributedPlaceholder = NSAttributedString(string: "0000", attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])

        textField.font = UIFont.kFontCodeInput
        textField.delegate = self
        textField.spellCheckingType = .no
        textField.autocorrectionType = .no
        //textField.autocapitalizationType = .allCharacters
        textField.keyboardType = .default
        textField.textAlignment = .center
    }

    private func updateBtnState() {
        if let tan0 = self.textField0.text, let tan1 = self.textField1.text, let tan2 = self.textField2.text, let tan3 = self.textField3.text, let tan4 = self.textField4.text, let tan5 = self.textField5.text {
            self.viewButtonNext.isEnabled = (tan0.count + tan1.count + tan2.count + tan3.count + tan4.count + tan5.count == 24)
        } else {
            self.viewButtonNext.isEnabled = false
        }
    }

    @objc
    private func dismissKeyboard() {
        self.textField0.resignFirstResponder()
        self.textField1.resignFirstResponder()
        self.textField2.resignFirstResponder()
        self.textField3.resignFirstResponder()
        self.textField4.resignFirstResponder()
        self.textField5.resignFirstResponder()
    }

    override func handleViewTapped(_: Any?) {
        self.dismissKeyboard()
    }

    override func handleKeyboardWillShow(_ aNotification: Notification) {
        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavCheck], action: #selector(dismissKeyboard), accessibilityLabelIdentifier: "navigation.done")

        super.handleKeyboardWillShow(aNotification, scrollView: self.scrollView, viewVisible: self.textField3, viewButtonPrimary: self.viewButtonNext)
    }

    override func handleKeyboardWillHide(_ aNotification: Notification) {
        self.navigationItem.setRightBarButton(nil, animated: true)

        super.handleKeyboardWillHide(aNotification, scrollView: self.scrollView, viewButtonPrimary: self.viewButtonNext)
    }

    @objc
    private func handleRecover() {
        let block = { [weak self] (_: Bool) in

            guard let strongSelf = self else {
                return
            }

            if let tan0 = strongSelf.textField0.text, let tan1 = strongSelf.textField1.text, let tan2 = strongSelf.textField2.text, let tan3 = strongSelf.textField3.text, let tan4 = strongSelf.textField4.text, let tan5 = strongSelf.textField5.text {
                let recoveryCode = (tan0 + "-" + tan1 + "-" + tan2 + "-" + tan3 + "-" + tan4 + "-" + tan5)

                if let deviceCrypto = CryptoHelper.sharedInstance, (try? deviceCrypto.decryptBackupPrivateKey(password: recoveryCode, backupMode: .miniBackup)) ?? false {
                    if let loginViewController = self?.presentingViewController as? DPAGLoginViewControllerProtocol {
                        // Push Back to Login Controller
                        self?.dismiss(animated: true, completion: { [weak loginViewController] in
                            // needChangePasswort auf true6
                            loginViewController?.companyRecoveryPasswordSuccess()
                        })
                    }
                } else {
                    UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: { [weak self] in

                        guard let strongSelf = self else {
                            return
                        }

                        strongSelf.viewAlert.isHidden = false
                        strongSelf.viewTitle.isHidden = true
                        strongSelf.stackViewContent.layoutIfNeeded()
                    })
                }
            }
        }

        if self.viewAlert.isHidden == false {
            UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: {
                self.viewAlert.isHidden = true
                self.viewTitle.isHidden = false
                self.stackViewContent.layoutIfNeeded()
            }, completion: block)
        } else {
            block(true)
        }
    }
}

extension DPAGPasswordForgotRecoveryViewController: UITextFieldDelegate {}
