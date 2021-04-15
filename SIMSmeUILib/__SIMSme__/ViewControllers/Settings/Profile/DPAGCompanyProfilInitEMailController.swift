//
//  DPAGCompanyProfilInitEMailController.swift
//  SIMSme
//
//  Created by Yves Hetzer on 25.10.16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGCompanyProfilInitEMailControllerProtocol: AnyObject {}

class DPAGCompanyProfilInitEMailController: DPAGViewControllerWithKeyboard, DPAGViewControllerWithCompletion, DPAGCompanyProfilConfirmEMailControllerSkipDelegate, DPAGCompanyProfilInitEMailControllerProtocol {
    var skipToEmailValidation = false

    private weak var textFieldEditing: UITextField?
    @IBOutlet private var scrollView: UIScrollView!

    @IBOutlet private var stackViewEmail: UIStackView!
    @IBOutlet private var labelEmail: UILabel! {
        didSet {
            self.labelEmail.text = DPAGLocalizedString("contacts.details.labelEMail")
            self.labelEmail.font = UIFont.kFontFootnote
            self.labelEmail.textColor = DPAGColorProvider.shared[.labelText]
            self.labelEmail.numberOfLines = 0
        }
    }

    @IBOutlet private var textFieldEmail: UITextField! {
        didSet {
            self.textFieldEmail.accessibilityIdentifier = "textFieldEMail"
            self.textFieldEmail.configureDefault()
            self.textFieldEmail.delegate = self
            self.textFieldEmail.returnKeyType = .continue
            self.textFieldEmail.enablesReturnKeyAutomatically = true
            self.textFieldEmail.autocapitalizationType = .none
            self.textFieldEmail.keyboardType = .emailAddress
            self.textFieldEmail.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldEMail.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        }
    }

    @IBOutlet private var stackViewFirstName: UIStackView!
    @IBOutlet private var labelFirstName: UILabel! {
        didSet {
            self.labelFirstName.text = DPAGLocalizedString("contacts.details.labelFirstName")
            self.labelFirstName.textColor = DPAGColorProvider.shared[.labelText]
            self.labelFirstName.font = UIFont.kFontFootnote
            self.labelFirstName.numberOfLines = 0
        }
    }

    @IBOutlet private var textFieldFirstName: DPAGTextField! {
        didSet {
            self.textFieldFirstName.accessibilityIdentifier = "textFieldFirstName"
            self.textFieldFirstName.configureDefault()
            self.textFieldFirstName.delegate = self
            self.textFieldFirstName.returnKeyType = .continue
            self.textFieldFirstName.enablesReturnKeyAutomatically = true
            self.textFieldFirstName.autocapitalizationType = .sentences
            self.textFieldFirstName.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldFirstName.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        }
    }

    @IBOutlet private var stackViewLastName: UIStackView!
    @IBOutlet private var labelLastName: UILabel! {
        didSet {
            self.labelLastName.text = DPAGLocalizedString("contacts.details.labelLastName")
            self.labelLastName.textColor = DPAGColorProvider.shared[.labelText]
            self.labelLastName.font = UIFont.kFontFootnote
            self.labelLastName.numberOfLines = 0
        }
    }

    @IBOutlet private var textFieldLastName: DPAGTextField! {
        didSet {
            self.textFieldLastName.accessibilityIdentifier = "textFieldLastName"
            self.textFieldLastName.configureDefault()
            self.textFieldLastName.delegate = self
            self.textFieldLastName.returnKeyType = .continue
            self.textFieldLastName.enablesReturnKeyAutomatically = true
            self.textFieldLastName.autocapitalizationType = .sentences
            self.textFieldLastName.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldLastName.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        }
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("settings.companyprofile.email.button"), for: .normal)
            self.viewButtonNext.button.addTarget(self, action: #selector(handleContinue), for: .touchUpInside)
        }
    }

    @IBOutlet private var labelHint: UILabel! {
        didSet {
            self.labelHint.text = DPAGLocalizedString("settings.profile.email_hint")
            self.labelHint.font = UIFont.kFontFootnote
            self.labelHint.textColor = DPAGColorProvider.shared[.labelText]
            self.labelHint.numberOfLines = 0
        }
    }

    override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.labelEmail.textColor = DPAGColorProvider.shared[.labelText]
        self.textFieldEmail.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldEMail.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        self.labelFirstName.textColor = DPAGColorProvider.shared[.labelText]
        self.textFieldFirstName.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldFirstName.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        self.labelLastName.textColor = DPAGColorProvider.shared[.labelText]
        self.textFieldLastName.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldLastName.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        self.labelHint.textColor = DPAGColorProvider.shared[.labelText]
    }

    @IBOutlet private var buttonDelete: UIButton! {
        didSet {
            self.buttonDelete.configureButtonDestructive()
            self.buttonDelete.setTitle(DPAGLocalizedString("settings.companyprofile.email.buttonDelete"), for: .normal)
        }
    }

    var completion: (() -> Void)?

    init() {
        super.init(nibName: "DPAGCompanyProfilInitEMailController", bundle: Bundle(for: type(of: self)))
        NotificationCenter.default.addObserver(self, selector: #selector(handleConfirmedIdentitiesChanged), name: DPAGStrings.Notification.Account.CONFIRMED_IDENTITIES_CHANGED, object: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: self.textFieldEmail)
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: self.textFieldFirstName)
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: self.textFieldLastName)
        NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.Account.CONFIRMED_IDENTITIES_CHANGED, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let account = DPAGApplicationFacade.cache.account {
            self.configureGui(account)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(handleTextDidChange(_:)), name: UITextField.textDidChangeNotification, object: self.textFieldEmail)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTextDidChange(_:)), name: UITextField.textDidChangeNotification, object: self.textFieldFirstName)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTextDidChange(_:)), name: UITextField.textDidChangeNotification, object: self.textFieldLastName)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.skipToEmailValidation {
            self.skipToEmailValidation = false
            self.continueToValidation()
        } else {
            if self.stackViewEmail.isHidden == false, self.textFieldEmail.text?.isEmpty ?? true {
                self.textFieldEmail.becomeFirstResponder()
            } else if self.stackViewFirstName.isHidden == false, self.textFieldFirstName.text?.isEmpty ?? true {
                self.textFieldFirstName.becomeFirstResponder()
            } else if self.stackViewLastName.isHidden == false, self.textFieldLastName.text?.isEmpty ?? true {
                self.textFieldLastName.becomeFirstResponder()
            }
        }
    }

    @objc
    private func handleTextDidChange(_: Notification?) {
        self.updateBtnState()
    }

    private func updateBtnState() {
        if let text1 = self.textFieldEmail.text, text1.isEmpty == false, self.stackViewFirstName.isHidden || ((self.textFieldFirstName.text?.isEmpty ?? true) == false), self.stackViewLastName.isHidden || ((self.textFieldLastName.text?.isEmpty ?? true) == false) {
            self.viewButtonNext.isEnabled = true
        } else {
            self.viewButtonNext.isEnabled = false
        }
    }

    override func handleViewTapped(_ sender: Any?) {
        self.dismissKeyboard(sender)
    }

    override func handleKeyboardWillShow(_ aNotification: Notification) {
        if let textFieldEditing = self.textFieldEditing {
            super.handleKeyboardWillShow(aNotification, scrollView: self.scrollView, viewVisible: textFieldEditing, viewButtonPrimary: self.viewButtonNext)
        }
    }

    override func handleKeyboardWillHide(_ aNotification: Notification) {
        super.handleKeyboardWillHide(aNotification, scrollView: self.scrollView, viewButtonPrimary: self.viewButtonNext)
    }

    private func dismissKeyboard(_: Any?) {
        self.textFieldEmail?.resignFirstResponder()
        self.textFieldFirstName?.resignFirstResponder()
        self.textFieldLastName?.resignFirstResponder()
    }

    private func configureGui(_: DPAGAccount) {
        self.title = DPAGLocalizedString("settings.companyprofile.email.title")
        self.configureIdentity()
        self.updateBtnState()
    }

    private func configureIdentity() {
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) else { return }
        self.textFieldFirstName.text = contact.firstName
        self.textFieldLastName.text = contact.lastName
        self.textFieldEmail.text = DPAGApplicationFacade.preferences.validationEmailAddress ?? contact.eMailAddress
        if DPAGApplicationFacade.preferences.isCompanyManagedState {
            self.textFieldEmail.isEnabled = (self.textFieldEmail.text?.isEmpty ?? true) || (DPAGApplicationFacade.preferences.validationEmailAddress == nil)
            self.buttonDelete.isHidden = true
            self.stackViewFirstName.isHidden = true
            self.stackViewLastName.isHidden = true
        } else {
            self.buttonDelete.isHidden = contact.eMailAddress == nil || contact.phoneNumber == nil
            self.stackViewFirstName.isHidden = (self.textFieldFirstName.text?.isEmpty ?? true) == false
            self.stackViewLastName.isHidden = (self.textFieldLastName.text?.isEmpty ?? true) == false
        }
    }

    @objc
    private func handleConfirmedIdentitiesChanged() {
        self.performBlockOnMainThread { [weak self] in
            self?.configureIdentity()
        }
    }

    @IBAction private func handleDelete() {
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let eMailAddress = contact.eMailAddress else { return }
        let message = self.messageDeleteConfirmation(eMailAddress: eMailAddress)
        let actionOK = UIAlertAction(titleIdentifier: "res.continue", style: .default, handler: { [weak self] _ in
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
                self?.handleDeleteContinue()
            }
        })
        self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "settings.companyprofile.email.confirmDelete.title", messageAttributed: message, cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
    }

    private func messageDeleteConfirmation(eMailAddress: String) -> NSAttributedString {
        let message = DPAGLocalizedString("settings.companyprofile.email.confirmDelete.text1")
        let messageAttributed = NSMutableAttributedString(string: "\n" + message + "\n\n", attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontFootnote])
        let eMailAddressNonWrapping = eMailAddress.replacingOccurrences(of: ".", with: "\u{2024}")
        messageAttributed.append(NSAttributedString(string: eMailAddressNonWrapping + "\n\n", attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontHeadline]))
        messageAttributed.append(NSAttributedString(string: DPAGLocalizedString("settings.companyprofile.email.confirmDelete.text2"), attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontFootnote]))
        return messageAttributed
    }

    private func handleDeleteContinue() {
        DPAGApplicationFacade.accountManager.removeConfirmedEmailAddress { [weak self] responseObject, _, errorMessage in
            if let errorMessage = errorMessage {
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                }
            } else if let accountGuid = (responseObject as? [String])?.first, accountGuid == DPAGApplicationFacade.cache.account?.guid {
                do {
                    try DPAGApplicationFacade.accountManager.removeConfirmedEmailAddressDB()
                } catch {
                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                        self?.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: error.localizedDescription))
                    }
                    return
                }
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in
                        if self?.presentedViewController != nil {
                            self?.dismiss(animated: true, completion: nil)
                        } else {
                            self?.navigationController?.popViewController(animated: true)
                        }
                    })
                    self?.presentAlert(alertConfig: AlertConfig(messageIdentifier: "settings.companyprofile.email.confirmDelete.success", otherButtonActions: [actionOK]))
                }
            } else {
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "Invalid response"))
                }
            }
        }
    }

    @IBAction private func handleContinue() {
        if let firstName = self.textFieldFirstName.text, let lastName = textFieldLastName.text {
            DPAGApplicationFacade.accountManager.save(firstName: firstName, lastName: lastName)
        }
        guard let eMailAddress = self.textFieldEmail.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), DPAGHelperEx.isEmailValid(eMailAddress) else {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "settings.companyprofile.email.invalid"))
            return
        }
        let message = self.messageContinue(eMailAddress: eMailAddress)
        let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in
            self?.handleContinueWithEmailAddress(eMailAddress)
        })
        self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "settings.companyprofile.email.confirmsend.title", messageAttributed: message, cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
    }

    private func messageContinue(eMailAddress: String) -> NSAttributedString {
        let message = DPAGLocalizedString("settings.companyprofile.email.confirmsend.text1")
        let messageAttributed = NSMutableAttributedString(string: "\n" + message + "\n\n", attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontFootnote])
        let eMailAddressNonWrapping = eMailAddress.replacingOccurrences(of: ".", with: "\u{2024}")
        messageAttributed.append(NSAttributedString(string: eMailAddressNonWrapping + "\n\n", attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontHeadline]))
        messageAttributed.append(NSAttributedString(string: DPAGLocalizedString("settings.companyprofile.email.confirmsend.text2"), attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontFootnote]))
        return messageAttributed
    }

    private func handleContinueWithEmailAddress(_ eMailAddress: String) {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            let blockMail = { [weak self] in
                DPAGApplicationFacade.companyAdressbook.requestConfirmationMail(eMailAddress: eMailAddress, force: false, withResponse: { responseObject, errorCode, errorMessage in
                    let blockOK: DPAGServiceResponseBlock = { [weak self] responseObject, errorCode, errorMessage in
                        guard let strongSelf = self else { return }
                        if let errorMessage = errorMessage {
                            strongSelf.handleServiceError(errorCode, message: errorMessage)
                        } else if let responseArray = responseObject as? [Any] {
                            if let eMailDomain = responseArray.first as? String, eMailAddress.contains(eMailDomain) {
                                strongSelf.handleServiceSuccess(eMailAddress: eMailAddress, eMailDomain: eMailDomain)
                            } else {
                                strongSelf.handleServiceSuccess(eMailAddress: eMailAddress, eMailDomain: nil)
                            }
                        } else {
                            strongSelf.handleServiceError("Invalid Response", message: "Invalid Response")
                        }
                    }
                    if errorCode == "ERR-0128" { // DUPLICATE_ENTRY_FOR_EMAIL_HASH
                        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                            // https://github.com/ginlonet/ginlo-client-ios/issues/36
                            self?.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "requestEmailConfirmation.alert.mailAlreadyUsed.message"))
//                            let actionOK = UIAlertAction(titleIdentifier: "res.continue", style: .destructive, handler: { _ in
//                                DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
//                                    DPAGApplicationFacade.companyAdressbook.requestConfirmationMail(eMailAddress: eMailAddress, force: true, withResponse: blockOK)
//                                }
//                            })
//                            self?.presentAlert(alertConfig: AlertConfig(titleIdentifier: "requestEmailConfirmation.alert.mailAlreadyUsed.title", messageIdentifier: "requestEmailConfirmation.alert.mailAlreadyUsed.message", cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
                        }
                    } else {
                        blockOK(responseObject, errorCode, errorMessage)
                    }
                })
            }
            if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), contact.eMailDomain != nil {
                DPAGApplicationFacade.companyAdressbook.validateMailAddress(eMailAddress: eMailAddress) { _, errorCode, _ in
                    if errorCode == "ERR-0124" { // BLACKLISTED_EMAIL_DOMAIN
                        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                            let actionOK = UIAlertAction(titleIdentifier: "res.continue", style: .destructive, handler: { _ in
                                DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                                    blockMail()
                                }
                            })
                            self?.presentAlert(alertConfig: AlertConfig(titleIdentifier: "requestEmailConfirmation.alert.freemailer.title", messageIdentifier: "requestEmailConfirmation.alert.freemailer.message", cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
                        }
                    } else {
                        blockMail()
                    }
                }
            } else {
                blockMail()
            }
        }
    }

    private func handleServiceError(_ errorCode: String?, message: String) {
        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
            guard let strongSelf = self else { return }
            if errorCode == "ERR-0124" {
                strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "settings.companyprofile.email.freemailer"))
            } else {
                strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: message))
            }
        }
    }

    private func save(eMailAddress: String, eMailDomain: String?) {
        DPAGApplicationFacade.accountManager.save(eMailAddress: eMailAddress, eMailDomain: eMailDomain)
    }

    private func handleServiceSuccess(eMailAddress: String, eMailDomain: String?) {
        self.save(eMailAddress: eMailAddress, eMailDomain: eMailDomain)
        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
            guard let strongSelf = self else { return }
            let message = strongSelf.messageServiceSuccess(eMailAddress: eMailAddress)
            let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in
                self?.continueToValidation()
            })
            strongSelf.presentAlert(alertConfig: AlertConfig(titleIdentifier: "settings.companyprofile.email.send.title", messageAttributed: message, otherButtonActions: [actionOK]))
        }
    }

    private func messageServiceSuccess(eMailAddress: String) -> NSAttributedString {
        let message = DPAGLocalizedString("settings.companyprofile.email.send.text1")
        let eMailAddressNonWrapping = eMailAddress.replacingOccurrences(of: ".", with: "\u{2024}")
        let messageAttributed = NSMutableAttributedString(string: "\n\n" + message + "\n\n", attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontFootnote])
        messageAttributed.append(NSAttributedString(string: eMailAddressNonWrapping + "\n\n", attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontHeadline]))
        messageAttributed.append(NSAttributedString(string: DPAGLocalizedString("settings.companyprofile.email.send.text2"), attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontFootnote]))
        return messageAttributed
    }

    private func continueToValidation() {
        let nextVC = DPAGApplicationFacadeUISettings.companyProfilConfirmEMailVC()
        (nextVC as? DPAGViewControllerWithCompletion)?.completion = self.completion
        self.navigationController?.pushViewController(nextVC, animated: true)
    }
}

extension DPAGCompanyProfilInitEMailController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.textFieldEditing = textField
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == self.textFieldEmail {
            if self.stackViewFirstName.isHidden == false {
                self.textFieldFirstName.becomeFirstResponder()
            } else if self.stackViewLastName.isHidden == false {
                self.textFieldLastName.becomeFirstResponder()
            } else if self.viewButtonNext.isEnabled {
                self.perform(#selector(handleContinue), with: nil, afterDelay: 0.1)
            } else {
                textField.resignFirstResponder()
            }
        } else if textField == self.textFieldFirstName {
            if self.stackViewLastName.isHidden == false {
                self.textFieldLastName.becomeFirstResponder()
            } else if self.viewButtonNext.isEnabled {
                self.perform(#selector(handleContinue), with: nil, afterDelay: 0.1)
            } else if self.stackViewEmail.isHidden == false {
                self.textFieldEmail.becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
            }
        } else if textField == self.textFieldLastName {
            if self.viewButtonNext.isEnabled {
                self.perform(#selector(handleContinue), with: nil, afterDelay: 0.1)
            } else if self.stackViewEmail.isHidden == false {
                self.textFieldEmail.becomeFirstResponder()
            } else if self.stackViewFirstName.isHidden == false {
                self.textFieldFirstName.becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
            }
        }
        return true
    }
}
