//
//  DPAGCompanyProfilConfirmPhoneNumberController.swift
// ginlo
//
//  Created by RBU on 11.01.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGCompanyProfilConfirmPhoneNumberControllerProtocol: AnyObject {}

class DPAGCompanyProfilConfirmPhoneNumberController: DPAGViewControllerWithKeyboard, DPAGViewControllerWithCompletion, DPAGCompanyProfilConfirmPhoneNumberControllerProtocol {
    private weak var textFieldEditing: UITextField?

    @IBOutlet private var scrollView: UIScrollView!

    @IBOutlet private var labelHeader1: UILabel! {
        didSet {
            self.labelHeader1.font = UIFont.kFontHeadline
            self.labelHeader1.textColor = DPAGColorProvider.shared[.labelText]
            self.labelHeader1.numberOfLines = 0
            self.labelHeader1.text = DPAGLocalizedString("settings.companyprofile.code.header.phoneNumber")
        }
    }

    @IBOutlet private var labelPhoneNumber: UILabel! {
        didSet {
            self.labelPhoneNumber.font = UIFont.kFontHeadline
            self.labelPhoneNumber.textColor = DPAGColorProvider.shared[.labelText]
            self.labelPhoneNumber.numberOfLines = 0
            self.labelPhoneNumber.text = DPAGLocalizedString("settings.companyprofile.code.header.phoneNumber")
        }
    }

    @IBOutlet private var textField0: DPAGTextField! {
        didSet {
            self.textField0.accessibilityIdentifier = "textField0"
            self.configureTextField(self.textField0)
        }
    }

    @IBOutlet private var textField1: DPAGTextField! {
        didSet {
            self.textField1.accessibilityIdentifier = "textField1"
            self.configureTextField(self.textField1)
        }
    }

    @IBOutlet private var labelHint: UILabel! {
        didSet {
            self.labelHint.text = DPAGLocalizedString("settings.companyprofile.code.phoneNumber.hint")
            self.labelHint.font = UIFont.kFontFootnote
            self.labelHint.textColor = DPAGColorProvider.shared[.labelText]
            self.labelHint.numberOfLines = 0
        }
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("settings.companyprofile.code.activate"), for: .normal)
            self.viewButtonNext.button.addTarget(self, action: #selector(handleNextButtonTapped), for: .touchUpInside)
        }
    }

    @IBOutlet private var imageViewAlert: UIImageView! {
        didSet {
            self.imageViewAlert?.image = DPAGImageProvider.shared[.kImageButtonAlert]
        }
    }

    @IBOutlet private var viewAlert: UIView! {
        didSet {
            self.viewAlert.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
        }
    }

    @IBOutlet private var labelAlert: UILabel! {
        didSet {
            self.labelAlert?.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
            self.labelAlert?.text = DPAGLocalizedString("settings.companyprofile.code.phoneNumber..numbertries")
            self.labelAlert?.font = UIFont.kFontSubheadline
        }
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelHeader1.textColor = DPAGColorProvider.shared[.labelText]
                self.labelPhoneNumber.textColor = DPAGColorProvider.shared[.labelText]
                self.labelHint.textColor = DPAGColorProvider.shared[.labelText]
                self.viewAlert.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
                self.labelAlert?.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
                self.configureTextField(self.textField0)
                self.configureTextField(self.textField1)
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet fileprivate var buttonDelete: UIButton! {
        didSet {
            self.buttonDelete.configureButtonDestructive()
            self.buttonDelete.setTitle(DPAGLocalizedString("settings.companyprofile.phoneNumber.buttonDelete"), for: .normal)
        }
    }

    var completion: (() -> Void)?

    var syncHelper: DPAGSynchronizationHelperAddressbook?

    init() {
        super.init(nibName: "DPAGCompanyProfilConfirmPhoneNumberController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        if let account = DPAGApplicationFacade.cache.account {
            self.configureGui(account)
        }
    }

    private func configureTextField(_ textField: UITextField) {
        textField.configureDefault()
        textField.attributedPlaceholder = NSAttributedString(string: "000", attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        textField.delegate = self
        textField.textAlignment = .center
        textField.setPaddingLeftTo(0)
        textField.font = UIFont.kFontCodeInput
        textField.keyboardType = .numberPad
    }

    private func updateBtnState() {
        if let text0 = self.textField0.text, let text1 = self.textField1.text, text0.count + text1.count == 6 {
            self.viewButtonNext.isEnabled = true
        } else {
            self.viewButtonNext.isEnabled = false
        }
    }

    override func handleViewTapped(_ sender: Any?) {
        self.dismissKeyboard(sender)
    }

    override func handleKeyboardWillShow(_ notification: Notification) {
        if let textFieldEditing = self.textFieldEditing {
            super.handleKeyboardWillShow(notification, scrollView: self.scrollView, viewVisible: textFieldEditing, viewButtonPrimary: self.viewButtonNext)
        }
    }

    override func handleKeyboardWillHide(_ notification: Notification) {
        super.handleKeyboardWillHide(notification, scrollView: self.scrollView, viewButtonPrimary: self.viewButtonNext)
    }

    private func dismissKeyboard(_: Any?) {
        self.textField0.resignFirstResponder()
        self.textField1.resignFirstResponder()
    }

    private func configureGui(_ account: DPAGAccount) {
        self.title = DPAGLocalizedString("settings.companyprofile.code.phoneNumber.title")

        if let contact = DPAGApplicationFacade.cache.contact(for: account.guid) {
            self.labelPhoneNumber.text = (DPAGApplicationFacade.preferences.validationPhoneNumber ?? contact.phoneNumber) ?? "-"

            if DPAGApplicationFacade.preferences.isCompanyManagedState || DPAGApplicationFacade.preferences.isBaMandant == false {
                self.buttonDelete.isHidden = true
            } else {
                self.buttonDelete.isHidden = contact.phoneNumber == nil || contact.eMailAddress == nil
            }
        } else {
            self.buttonDelete.isHidden = true
        }

        self.textField0.configure(textFieldBefore: nil, textFieldAfter: self.textField1, textFieldMaxLength: 3, didChangeCompletion: self.updateBtnState)
        self.textField1.configure(textFieldBefore: self.textField0, textFieldAfter: nil, textFieldMaxLength: 3, didChangeCompletion: self.updateBtnState)

        self.updateBtnState()

        self.setAlertViewVisible(false)
    }

    private func setAlertViewVisible(_ visible: Bool) {
        if visible {
            let account = DPAGApplicationFacade.cache.account
            let numberOfTries = account?.triesLeftPhoneNumber

            if var numberOfTries = numberOfTries {
                numberOfTries -= 1

                let formatString = DPAGLocalizedString("settings.companyprofile.code.phoneNumber.numbertries")

                let message = String(format: formatString, numberOfTries)

                self.labelAlert?.text = message

                self.saveFailure(triesLeft: numberOfTries)

                if numberOfTries <= 0 {
                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

                        guard let strongSelf = self else { return }

                        strongSelf.dismissKeyboard(nil)

                        let message = "settings.companyprofile.code.phoneNumber.failure.text"
                        let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in

                            self?.popBackToView()
                        })

                        strongSelf.presentAlert(alertConfig: AlertConfig(titleIdentifier: "settings.companyprofile.code.phoneNumber.failure.title", messageIdentifier: message, otherButtonActions: [actionOK]))
                    }
                }
            }
            self.viewAlert.isHidden = false
        } else {
            self.viewAlert.isHidden = true
        }
    }

    @IBAction private func handleDelete() {
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let phoneNumber = contact.phoneNumber else {
            return
        }

        let message = self.messageDeleteConfirmation(phoneNumber: phoneNumber)

        let actionOK = UIAlertAction(titleIdentifier: "res.continue", style: .default, handler: { [weak self] _ in

            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in

                self?.handleDeleteContinue()
            }
        })

        self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "settings.companyprofile.phoneNumber.confirmDelete.title", messageAttributed: message, cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
    }

    private func messageDeleteConfirmation(phoneNumber: String) -> NSAttributedString {
        let message = DPAGLocalizedString("settings.companyprofile.phoneNumber.confirmDelete.text1")

        let messageAttributed = NSMutableAttributedString(string: "\n" + message + "\n\n", attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontFootnote])

        messageAttributed.append(NSAttributedString(string: phoneNumber, attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontHeadline]))
        messageAttributed.append(NSAttributedString(string: DPAGLocalizedString("settings.companyprofile.phoneNumber.confirmDelete.text2"), attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontFootnote]))

        return messageAttributed
    }

    private func handleDeleteContinue() {
        DPAGApplicationFacade.accountManager.removeConfirmedPhoneNumber { [weak self] responseObject, _, errorMessage in

            if let errorMessage = errorMessage {
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                }
            } else if let accountGuid = (responseObject as? [String])?.first, accountGuid == DPAGApplicationFacade.cache.account?.guid {
                do {
                    try DPAGApplicationFacade.accountManager.removeConfirmedPhoneNumberDB()
                } catch {
                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

                        self?.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: error.localizedDescription))
                    }
                    return
                }

                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

                    let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in
                        self?.popBackToView()
                    })

                    self?.presentAlert(alertConfig: AlertConfig(messageIdentifier: "settings.companyprofile.phoneNumber.confirmDelete.success", otherButtonActions: [actionOK]))
                }
            } else {
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "Invalid response"))
                }
            }
        }
    }

    @IBAction private func handleNextButtonTapped() {
        self.textField0.resignFirstResponder()
        self.textField1.resignFirstResponder()

        if let code = self.textField0.text, let code2 = self.textField1.text {
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in

                DPAGApplicationFacade.companyAdressbook.confirmConfirmationSMS(code: code + code2, withResponse: { [weak self] (responseObject: Any?, errorCode: String?, errorMessage: String?) in

                    guard let strongSelf = self else { return }

                    if let errorMessage = errorMessage {
                        strongSelf.handleServiceError(errorCode, message: errorMessage)
                    } else if responseObject is [String] {
                        strongSelf.handleServiceSuccess()
                    } else {
                        strongSelf.handleServiceError("Invalid Response", message: "Invalid Response")
                    }
                })
            }
        }
    }

    private func handleServiceError(_ errorCode: String?, message: String) {
        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

            if let strongSelf = self {
                if errorCode == "ERR-0126" {
                    strongSelf.setAlertViewVisible(true)
                } else {
                    strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: message, accessibilityIdentifier: "error_confirm_phoneNumber"))
                }
            }
        }
    }

    private func saveSuccess() -> String? {
        DPAGApplicationFacade.profileWorker.phoneNumberConfirmed()
    }

    private func saveFailure(triesLeft: Int) {
        DPAGApplicationFacade.profileWorker.saveAvailablePhoneNumberConfirmationTries(triesLeft: triesLeft)
    }

    private func popBackToView() {
        if self.completion != nil, self.presentingViewController != nil {
            self.dismiss(animated: true, completion: self.completion)
            return
        }

        if let navVCs = self.navigationController?.viewControllers.reversed().drop(while: { $0 is DPAGCompanyProfilConfirmPhoneNumberControllerProtocol || $0 is DPAGCompanyProfilInitPhoneNumberControllerProtocol }).reversed() {
            // View aktualisieren starten
            self.navigationController?.setViewControllers(Array(navVCs), animated: true)
            self.completion?()
        }

        NotificationCenter.default.post(name: DPAGStrings.Notification.Application.PERFORM_TASKS_ON_APP_START, object: nil)
    }

    private func domainSyncCompleted(phoneNumber: String?) {
        let message = self.messageSyncCompletion(phoneNumber: phoneNumber ?? "-")

        let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in

            self?.popBackToView()
        })

        self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "settings.companyprofile.code.phoneNumber.success.title", messageAttributed: message, otherButtonActions: [actionOK]))
    }

    private func messageSyncCompletion(phoneNumber: String) -> NSAttributedString {
        let message = DPAGLocalizedString("settings.companyprofile.code.phoneNumber.success.text1")

        let messageAttributed = NSMutableAttributedString(string: "\n" + message + "\n\n", attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontFootnote])

        messageAttributed.append(NSAttributedString(string: phoneNumber + "\n\n", attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontHeadline]))

        if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let accountID = contact.accountID, let lastBackup = DPAGApplicationFacade.preferences.backupLastFile {
            if !lastBackup.contains(accountID) {
                messageAttributed.append(NSAttributedString(string: DPAGLocalizedString("settings.companyprofile.code.phoneNumber.success.backupHint"), attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontHeadline]))
            }
        }

        return messageAttributed
    }

    private func handleServiceSuccess() {
        let phoneNumber = self.saveSuccess()

        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

            self?.syncHelper = DPAGSynchronizationHelperAddressbook()

            self?.syncHelper?.syncDomainAndCompanyAddressbook(completion: { [weak self] in

                // keeping instance alive until work is finished
                self?.syncHelper = nil
                self?.domainSyncCompleted(phoneNumber: phoneNumber)

            }, completionOnError: { [weak self] (errorCode: String?, errorMessage: String) in

                self?.syncHelper = nil
                self?.handleServiceError(errorCode, message: errorMessage)
            })
        }
    }
}

extension DPAGCompanyProfilConfirmPhoneNumberController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.textFieldEditing = textField
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == self.textField0 {
            self.textField1.becomeFirstResponder()
        } else if self.viewButtonNext.isEnabled {
            self.perform(#selector(handleNextButtonTapped), with: nil, afterDelay: 0.1)
        } else {
            self.textField0.becomeFirstResponder()
        }
        return true
    }
}
