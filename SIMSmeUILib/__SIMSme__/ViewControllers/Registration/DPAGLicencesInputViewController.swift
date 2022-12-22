//
//  DPAGLicencesInputViewController.swift
// ginlo
//
//  Created by RBU on 22/06/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGLicencesInputViewController: DPAGViewControllerWithKeyboard, DPAGLicenceViewControllerProtocol {
    @IBOutlet private var labelHeader: UILabel! {
        didSet {
            self.labelHeader.text = DPAGLocalizedString("licenceInput.labelHeader.text")
            self.labelHeader.font = UIFont.kFontTitle1
            self.labelHeader.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelDescription: UILabel! {
        didSet {
            self.labelDescription.text = DPAGLocalizedString("licenceInput.labelDescription.text")
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

    override
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

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.accessibilityIdentifier = "btnActivate"
            self.viewButtonNext.button.addTarget(self, action: #selector(handleActivate), for: .touchUpInside)
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("licenceInput.btnActivate"), for: .normal)
        }
    }

    @IBOutlet private var scrollView: UIScrollView!

    init() {
        super.init(nibName: "DPAGLicencesInputViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

//        self.navigationItem.title = DPAGLocalizedString("licenceInput.title")

        self.textField0.configure(textFieldBefore: nil, textFieldAfter: self.textField1, textFieldMaxLength: 4, didChangeCompletion: self.updateBtnState)
        self.textField1.configure(textFieldBefore: self.textField0, textFieldAfter: self.textField2, textFieldMaxLength: 4, didChangeCompletion: self.updateBtnState)
        self.textField2.configure(textFieldBefore: self.textField1, textFieldAfter: self.textField3, textFieldMaxLength: 4, didChangeCompletion: self.updateBtnState)
        self.textField3.configure(textFieldBefore: self.textField2, textFieldAfter: nil, textFieldMaxLength: 4, didChangeCompletion: self.updateBtnState)
    }

    override func viewFirstAppear(_: Bool) {
        self.textField0.becomeFirstResponder()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.checkCompanyManagement()

        self.performBlockInBackground { [weak self] in
            self?.checkLicence()
        }
    }

    override func appWillEnterForeground() {
        super.appWillEnterForeground()

        self.checkCompanyManagement()

        self.performBlockInBackground { [weak self] in
            self?.checkLicence()
        }
    }

    func showAcceptedRequiredViewController(_ vc: UIViewController) {
        self.navigationController?.pushViewController(vc, animated: true)
        //                                        let nextVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)
        //
        //                                        AppConfig.appWindow()??.rootViewController?.present(nextVC, animated: true, completion: nil)
    }

    func checkedLicenceWithEarlierDate() {}

    func checkedLicenceWithNoDate() {}

    private func configureTextField(_ textField: DPAGTextField) {
        textField.configureDefault()
        textField.setPaddingLeftTo(1)
        textField.setPaddingRightTo(1)

        if (UIScreen.main.bounds.width < 375 && UIScreen.main.bounds.height > UIScreen.main.bounds.width) || (UIScreen.main.bounds.height < 375 && UIScreen.main.bounds.width > UIScreen.main.bounds.height) {
            textField.font = UIFont.kFontHeadline
        } else {
            textField.font = UIFont.kFontTitle3
        }
        textField.delegate = self
        textField.spellCheckingType = .no
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .allCharacters
        textField.keyboardType = .default
        textField.textAlignment = .center
    }

    private func updateBtnState() {
        if let text0 = self.textField0.text, let text1 = self.textField1.text, let text2 = self.textField2.text, let text3 = self.textField3.text, text0.isEmpty == false || text1.isEmpty == false || text2.isEmpty == false || text3.isEmpty == false {
            self.viewButtonNext.isEnabled = true
        } else {
            self.viewButtonNext.isEnabled = false
        }
    }

    @objc
    private func handleActivate() {
        let voucher = String(format: "%@-%@-%@-%@", self.textField0.text ?? "", self.textField1.text ?? "", self.textField2.text ?? "", self.textField3.text ?? "")
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
            DPAGPurchaseWorker.registerVoucher(voucher) { responseObject, _, errorMessage in
                self.performBlockInBackground {
                    NotificationCenter.default.post(name: DPAGStrings.Notification.Licence.LICENCE_UPDATE_TESTLICENCE_DATE, object: nil)
                }
                if let errorMessage = errorMessage {
                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                    }
                } else if let responseArray = responseObject as? [[String: Any]] {
                    if responseArray.count == 0 {
                        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                            if let strongSelf = self {
                                strongSelf.navigationController?.dismiss(animated: true, completion: nil)
                            }
                        }
                    } else if let responseDict = responseArray.first, let ident = responseDict["ident"] as? String, (responseDict["valid"] as? String) != nil, ident == "usage" {
                        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                            self?.navigationController?.dismiss(animated: true, completion: nil)
                        }
                    } else {
                        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                            self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "Invalid response"))
                        }
                    }
                }
            }
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

extension DPAGLicencesInputViewController: UITextFieldDelegate {}
