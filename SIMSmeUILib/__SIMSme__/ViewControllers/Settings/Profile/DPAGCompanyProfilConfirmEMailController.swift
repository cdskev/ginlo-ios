//
//  DPAGCompanyProfilConfirmEMailController.swift
// ginlo
//
//  Created by Yves Hetzer on 26.10.16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGCompanyProfilConfirmEMailControllerProtocol: AnyObject {}

class DPAGCompanyProfilConfirmEMailController: DPAGViewControllerWithKeyboard, DPAGViewControllerWithCompletion, DPAGCompanyProfilConfirmEMailControllerProtocol {
    private weak var textFieldEditing: UITextField?

    @IBOutlet private var scrollView: UIScrollView!

    @IBOutlet private var labelHeader1: UILabel! {
        didSet {
            self.labelHeader1.font = UIFont.kFontHeadline
            self.labelHeader1.textColor = DPAGColorProvider.shared[.labelText]
            self.labelHeader1.numberOfLines = 0
            self.labelHeader1.text = DPAGLocalizedString("settings.companyprofile.code.header.email")
        }
    }

    @IBOutlet private var labelEmailAddress: UILabel! {
        didSet {
            self.labelEmailAddress.font = UIFont.kFontHeadline
            self.labelEmailAddress.textColor = DPAGColorProvider.shared[.labelText]
            self.labelEmailAddress.numberOfLines = 0
        }
    }

    @IBOutlet private var textFieldConfirmCode: UITextField! {
        didSet {
            self.textFieldConfirmCode.configureDefault()
            self.textFieldConfirmCode.delegate = self
            self.textFieldConfirmCode.textAlignment = .center
            self.textFieldConfirmCode.setPaddingLeftTo(0)
            self.textFieldConfirmCode.font = UIFont.kFontCodeInput
        }
    }

    @IBOutlet private var labelHint: UILabel! {
        didSet {
            self.labelHint.text = DPAGLocalizedString("settings.companyprofile.code.email.hint")
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
            self.imageViewAlert?.tintColor = DPAGColorProvider.shared[.alertDestructiveTint]
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
            self.labelAlert?.text = DPAGLocalizedString("settings.companyprofile.code.email.numbertries")
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
                self.labelEmailAddress.textColor = DPAGColorProvider.shared[.labelText]
                self.labelHint.textColor = DPAGColorProvider.shared[.labelText]
                self.imageViewAlert?.tintColor = DPAGColorProvider.shared[.alertDestructiveTint]
                self.viewAlert.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
                self.labelAlert?.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var buttonDelete: UIButton! {
        didSet {
            self.buttonDelete.configureButtonDestructive()
            self.buttonDelete.setTitle(DPAGLocalizedString("settings.companyprofile.email.buttonDelete"), for: .normal)
        }
    }

    var completion: (() -> Void)?

    var syncHelper: DPAGSynchronizationHelperAddressbook?

    init() {
        super.init(nibName: "DPAGCompanyProfilConfirmEMailController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: self.textFieldConfirmCode)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        if let account = DPAGApplicationFacade.cache.account {
            self.configureGui(account)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(handleTextDidChange(_:)), name: UITextField.textDidChangeNotification, object: self.textFieldConfirmCode)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let isInputEmpty = (self.textFieldConfirmCode.text?.isEmpty ?? true)

        if isInputEmpty {
            self.textFieldConfirmCode.becomeFirstResponder()
        }
    }

    @objc
    private func handleTextDidChange(_: Notification?) {
        self.updateBtnState()
    }

    private func updateBtnState() {
        if let text1 = self.textFieldConfirmCode.text, !text1.isEmpty, text1.count == 4 {
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
        self.textFieldConfirmCode?.resignFirstResponder()
    }

    private func configureGui(_ account: DPAGAccount) {
        self.title = DPAGLocalizedString("settings.companyprofile.code.email.title")

        if let contact = DPAGApplicationFacade.cache.contact(for: account.guid) {
            self.labelEmailAddress.text = (DPAGApplicationFacade.preferences.validationEmailAddress ?? contact.eMailAddress)

            if DPAGApplicationFacade.preferences.isCompanyManagedState {
                self.buttonDelete.isHidden = true
            } else {
                self.buttonDelete.isHidden = contact.eMailAddress == nil || contact.phoneNumber == nil
            }
        } else {
            self.buttonDelete.isHidden = true
        }

        self.updateBtnState()

        self.setAlertViewVisible(false)
    }

    private func setAlertViewVisible(_ visible: Bool) {
        if visible {
            let account = DPAGApplicationFacade.cache.account
            let numberOfTries = account?.triesLeftEmail

            if var numberOfTries = numberOfTries {
                numberOfTries -= 1

                let formatString = DPAGLocalizedString("settings.companyprofile.code.email.numbertries")

                let message = String(format: formatString, numberOfTries)

                self.labelAlert?.text = message

                self.saveFailure(triesLeft: numberOfTries)

                if numberOfTries <= 0 {
                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

                        guard let strongSelf = self else { return }

                        strongSelf.dismissKeyboard(nil)

                        let message = "settings.companyprofile.code.email.failure.text"

                        let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in

                            self?.popBackToView()
                        })

                        strongSelf.presentAlert(alertConfig: AlertConfig(titleIdentifier: "settings.companyprofile.code.email.failure.title", messageIdentifier: message, otherButtonActions: [actionOK]))
                    }
                }
            }
            self.viewAlert.isHidden = false
        } else {
            self.viewAlert.isHidden = true
        }
    }

    @IBAction private func handleDelete() {
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let eMailAddress = contact.eMailAddress else {
            return
        }

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
                        self?.popBackToView()
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

    @IBAction private func handleNextButtonTapped() {
        self.textFieldConfirmCode.resignFirstResponder()

        if let code = self.textFieldConfirmCode.text {
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in

                DPAGApplicationFacade.companyAdressbook.confirmConfirmationMail(code: code, withResponse: { [weak self] responseObject, errorCode, errorMessage in

                    guard let strongSelf = self else { return }

                    if let errorMessage = errorMessage {
                        strongSelf.handleServiceError(errorCode, message: errorMessage)
                    } else if responseObject is [String] {
                        strongSelf.performBlockInBackground { [weak self] in
                            self?.handleServiceSuccess()
                        }
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
                    strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: message, accessibilityIdentifier: "error_confirm_email"))
                }
            }
        }
    }

    private func saveSuccess() -> String? {
        DPAGApplicationFacade.profileWorker.emailAddressConfirmed()
    }

    private func saveFailure(triesLeft: Int) {
        DPAGApplicationFacade.profileWorker.saveAvailableEmailAddressConfirmationTries(triesLeft: triesLeft)
    }

    private func popBackToView() {
        if self.completion != nil, self.presentingViewController != nil {
            self.dismiss(animated: true, completion: self.completion)
            return
        }

        if let navVCs = self.navigationController?.viewControllers.reversed().drop(while: { $0 is DPAGCompanyProfilConfirmEMailControllerProtocol || $0 is DPAGCompanyProfilInitEMailControllerProtocol }).reversed() {
            // View aktualisieren starten
            self.navigationController?.setViewControllers(Array(navVCs), animated: true)
            self.completion?()
        }

        NotificationCenter.default.post(name: DPAGStrings.Notification.Application.PERFORM_TASKS_ON_APP_START, object: nil)
    }

    private func domainSyncCompleted(eMailAddress: String?) {
        let message = self.messageSyncCompleted(eMailAddress: eMailAddress ?? "-")

        let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in

            self?.popBackToView()
        })

        self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "settings.companyprofile.code.email.success.title", messageAttributed: message, otherButtonActions: [actionOK]))
    }

    private func messageSyncCompleted(eMailAddress: String) -> NSAttributedString {
        let message = DPAGLocalizedString("settings.companyprofile.code.email.success.text1")

        let messageAttributed = NSMutableAttributedString(string: "\n" + message + "\n\n", attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontFootnote])

        let eMailAddressNonWrapping = eMailAddress.replacingOccurrences(of: ".", with: "\u{2024}")

        messageAttributed.append(NSAttributedString(string: eMailAddressNonWrapping + "\n\n", attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontHeadline]))
        messageAttributed.append(NSAttributedString(string: DPAGLocalizedString("settings.companyprofile.code.email.success.text2"), attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontFootnote]))

        return messageAttributed
    }

    private func handleServiceSuccess() {
        let eMailAddress = self.saveSuccess()

        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

            self?.syncHelper = DPAGSynchronizationHelperAddressbook()

            self?.syncHelper?.syncDomainAndCompanyAddressbook(completion: { [weak self] in

                // keeping instance alive until work is finished
                self?.syncHelper = nil
                self?.domainSyncCompleted(eMailAddress: eMailAddress)

            }, completionOnError: { [weak self] (errorCode: String?, errorMessage: String) in

                self?.syncHelper = nil
                self?.handleServiceError(errorCode, message: errorMessage)
            })
        }
    }
}

extension DPAGCompanyProfilConfirmEMailController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.textFieldEditing = textField
    }

    func textFieldShouldReturn(_: UITextField) -> Bool {
        if self.viewButtonNext.isEnabled {
            self.perform(#selector(handleNextButtonTapped), with: nil, afterDelay: 0.1)
        }
        return true
    }
}
