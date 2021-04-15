//
//  DPAGCreateDeviceConfirmCodeViewController.swift
//  SIMSme
//
//  Created by RBU on 24.11.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import SIMSmeCore
import UIKit

class DPAGCreateDeviceConfirmCodeViewController: DPAGViewControllerWithKeyboard {
    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var stackViewAll: UIStackView!

    @IBOutlet private var labelTitle: UILabel! {
        didSet {
            self.labelTitle.text = DPAGLocalizedString("registration.enterActivationCode.title")
            self.labelTitle.font = UIFont.kFontTitle1
            self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
            self.labelTitle.numberOfLines = 0
        }
    }

    @IBOutlet private var labelDescription: UILabel! {
        didSet {
            if DPAGApplicationFacade.preferences.isBaMandant {
            self.labelDescription.text = DPAGLocalizedString("registration.createDeviceConfirm.description")
            } else {
                self.labelDescription.text = DPAGLocalizedString("registration.createDeviceConfirm.description.private")
            }
            self.labelDescription.font = UIFont.kFontSubheadline
            self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDescription.numberOfLines = 0
        }
    }

    @IBOutlet private var buttonScan: UIButton! {
        didSet {
            self.buttonScan.accessibilityIdentifier = "buttonContinue"
            self.buttonScan.configureButton()
            self.buttonScan.setTitle(DPAGLocalizedString("contacts.button.scanContactShort"), for: .normal)
            self.buttonScan.addTarget(self, action: #selector(handleScan), for: .touchUpInside)
            self.buttonScan.isEnabled = UIImagePickerController.isSourceTypeAvailable(.camera)
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.configureTextField(self.textFieldCode0)
                self.configureTextField(self.textFieldCode1)
                self.configureTextField(self.textFieldCode2)
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var textFieldCode0: DPAGTextField! {
        didSet {
            self.textFieldCode0.accessibilityIdentifier = "textFieldCode0"
            self.configureTextField(self.textFieldCode0)
        }
    }

    @IBOutlet private var textFieldCode1: DPAGTextField! {
        didSet {
            self.textFieldCode1.accessibilityIdentifier = "textFieldCode1"
            self.configureTextField(self.textFieldCode1)
        }
    }

    @IBOutlet private var textFieldCode2: DPAGTextField! {
        didSet {
            self.textFieldCode2.accessibilityIdentifier = "textFieldCode2"
            self.configureTextField(self.textFieldCode2)
        }
    }

    @IBOutlet var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.accessibilityIdentifier = "buttonContinue"
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("res.continue"), for: .normal)
            self.viewButtonNext.button.addTarget(self, action: #selector(handleContinue), for: .touchUpInside)
        }
    }

    @IBOutlet var constraintButtonNextBottom: NSLayoutConstraint!

    private let accountGuid: String

    init(accountGuid: String) {
        self.accountGuid = accountGuid

        super.init(nibName: "DPAGCreateDeviceConfirmCodeViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.title = DPAGLocalizedString("registration.createDeviceConfirm.title")

        self.textFieldCode0.configure(textFieldBefore: nil, textFieldAfter: self.textFieldCode1, textFieldMaxLength: 3, didChangeCompletion: self.updateBtnState)
        self.textFieldCode1.configure(textFieldBefore: self.textFieldCode0, textFieldAfter: self.textFieldCode2, textFieldMaxLength: 3, didChangeCompletion: self.updateBtnState)
        self.textFieldCode2.configure(textFieldBefore: self.textFieldCode1, textFieldAfter: nil, textFieldMaxLength: 3, didChangeCompletion: self.updateBtnState)

        self.updateBtnState()
    }

    override func handleKeyboardWillShow(_ aNotification: Notification) {
        super.handleKeyboardWillShow(aNotification, scrollView: self.scrollView, viewVisible: self.textFieldCode0, viewButtonPrimary: self.viewButtonNext)
    }

    override func handleKeyboardWillHide(_ aNotification: Notification) {
        super.handleKeyboardWillHide(aNotification, scrollView: self.scrollView, viewButtonPrimary: self.viewButtonNext)
    }

    private func configureTextField(_ textField: UITextField) {
        textField.configureDefault()
        textField.font = UIFont.kFontCodeInput
        textField.textAlignment = .center
        textField.setPaddingLeftTo(0)
        textField.attributedPlaceholder = NSAttributedString(string: "000", attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        textField.delegate = self
        textField.keyboardType = .asciiCapable
    }

    private func updateBtnState() {
        if let tan0 = self.textFieldCode0.text, let tan1 = self.textFieldCode1.text, let tan2 = self.textFieldCode2.text {
            self.viewButtonNext.isEnabled = (tan0.count + tan1.count + tan2.count == 9)
        } else {
            self.viewButtonNext.isEnabled = false
        }
    }

    @objc
    private func handleScan() {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)

        switch authStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { [weak self] _ in

                DispatchQueue.main.async { [weak self] in
                    self?.handleScan()
                }
            })
        case .authorized:
            let nextVC = DPAGApplicationFacadeUIRegistration.scanCreateDeviceTANVC(blockSuccess: { [weak self] (text: String) in

                guard let strongSelf = self else { return }

                let textFields: [UITextField] = [
                    strongSelf.textFieldCode0,
                    strongSelf.textFieldCode1,
                    strongSelf.textFieldCode2
                ]

                var text1 = text

                if text1.count == 18 {
                    text1 = String(text1.suffix(9))
                }

                let textSplitted = text1.components(withLength: 3)

                for (idx, splitItem) in textSplitted.enumerated() {
                    if idx < textFields.count {
                        textFields[idx].text = splitItem
                    } else {
                        break
                    }
                }
                strongSelf.updateBtnState()
                strongSelf.navigationController?.popToViewController(strongSelf, animated: true)

            }, blockFailed: { [weak self] in

                self?.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "registration.createDeviceConfirm.verifyingQRCodeFailed", okActionHandler: { [weak self] _ in

                    if let strongSelf = self {
                        strongSelf.navigationController?.popToViewController(strongSelf, animated: true)
                    }
                }))

            }, blockCancelled: { [weak self] in

                if let strongSelf = self {
                    strongSelf.navigationController?.popToViewController(strongSelf, animated: true)
                }
            })

            self.navigationController?.pushViewController(nextVC, animated: true)
        default:
            break
        }
    }

    @objc
    private func handleContinue() {
        if let tan0 = self.textFieldCode0.text, let tan1 = self.textFieldCode1.text, let tan2 = self.textFieldCode2.text {
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in

                do {
                    try DPAGApplicationFacade.couplingWorker.requestCoupling(tan: tan0 + tan1 + tan2, reqType: .permanent)

                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                        self?.navigationController?.pushViewController(DPAGApplicationFacadeUIRegistration.createDeviceWaitForConfirmationVC(), animated: true)
                    }
                } catch {
                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                        let errorDesc = error.localizedDescription
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorDesc))
                    }
                }
            }
        }
    }
}

extension DPAGCreateDeviceConfirmCodeViewController: UITextFieldDelegate {
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == self.textFieldCode2 {
            self.perform(#selector(handleContinue), with: nil, afterDelay: 0.1)
        }
        return true
    }
}
