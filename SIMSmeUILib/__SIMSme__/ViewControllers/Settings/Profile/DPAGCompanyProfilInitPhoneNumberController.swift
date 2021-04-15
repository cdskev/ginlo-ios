//
//  DPAGCompanyProfilInitPhoneNumberController.swift
//  SIMSme
//
//  Created by RBU on 11.01.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGCompanyProfilInitPhoneNumberControllerProtocol: AnyObject {}

class DPAGCompanyProfilInitPhoneNumberController: DPAGViewControllerWithKeyboard, DPAGViewControllerWithCompletion, DPAGCompanyProfilConfirmPhoneNumberControllerSkipDelegate, DPAGCompanyProfilInitPhoneNumberControllerProtocol {
    var skipToPhoneNumberValidation = false
    private weak var textFieldEditing: UITextField?
    private var tapGrViewCountry: UITapGestureRecognizer?
    private var preferredCountryIndex = -1
    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var stackViewPhoneNumber: UIStackView!

    @IBOutlet private var labelCountryCode: UILabel! {
        didSet {
            self.labelCountryCode.font = UIFont.kFontCallout
            self.labelCountryCode.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var countryPicker: UIPickerView! {
        didSet {
            self.countryPicker.dataSource = self
            self.countryPicker.delegate = self
            self.countryPicker.accessibilityIdentifier = "countryPicker"
        }
    }

    @IBOutlet private var imageViewDrillDown: UIImageView! {
        didSet {
            self.imageViewDrillDown.image = UIImage.drillDownImage
        }
    }

    @IBOutlet private var labelCountry: UILabel! {
        didSet {
            self.labelCountry.text = DPAGLocalizedString("registration.label.countryLabel")
            self.labelCountry.font = UIFont.kFontFootnote
            self.labelCountry.textColor = DPAGColorProvider.shared[.labelText]
            self.labelCountry.numberOfLines = 0
        }
    }

    @IBOutlet private var buttonCountryChooser: UIButton! {
        didSet {
            self.buttonCountryChooser.accessibilityIdentifier = "buttonCountryChooser"
            self.buttonCountryChooser.layer.cornerRadius = 2.0
            self.buttonCountryChooser.addTargetClosure { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.textFieldPhoneNumber.resignFirstResponder()
                if strongSelf.countryPicker.isHidden == false {
                    strongSelf.removePicker()
                    return
                }
                strongSelf.countryPicker.isHidden = false
                strongSelf.countryPicker.selectRow(strongSelf.preferredCountryIndex, inComponent: 0, animated: false)
                strongSelf.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavCheck], action: #selector(DPAGCompanyProfilInitPhoneNumberController.handleCountryCodeDoneTapped), accessibilityLabelIdentifier: "navigation.done")
                strongSelf.tapGrViewCountry?.isEnabled = true
                UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.countryPicker.superview?.layoutIfNeeded()
                }, completion: { _ in
                })
            }
            self.buttonCountryChooser.titleLabel?.font = UIFont.kFontCallout
            self.buttonCountryChooser.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .normal)
        }
    }

    @IBOutlet private var labelPhoneNumber: UILabel! {
        didSet {
            self.labelPhoneNumber.text = DPAGLocalizedString("contacts.details.labelPhoneNumber")
            self.labelPhoneNumber.font = UIFont.kFontFootnote
            self.labelPhoneNumber.textColor = DPAGColorProvider.shared[.labelText]
            self.labelPhoneNumber.numberOfLines = 0
        }
    }

    @IBOutlet private var textFieldPhoneNumber: UITextField! {
        didSet {
            self.textFieldPhoneNumber.accessibilityIdentifier = "textFieldPhoneNumber"
            self.textFieldPhoneNumber.configureDefault()
            self.textFieldPhoneNumber.delegate = self
            self.textFieldPhoneNumber.returnKeyType = .continue
            self.textFieldPhoneNumber.enablesReturnKeyAutomatically = true
            self.textFieldPhoneNumber.autocapitalizationType = .none
            self.textFieldPhoneNumber.keyboardType = .phonePad
            self.textFieldPhoneNumber.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldPhoneNumber.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        }
    }

    override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.labelCountryCode.textColor = DPAGColorProvider.shared[.labelText]
        self.labelCountry.textColor = DPAGColorProvider.shared[.labelText]
        self.buttonCountryChooser.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .normal)
        self.labelPhoneNumber.textColor = DPAGColorProvider.shared[.labelText]
        self.textFieldPhoneNumber.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldPhoneNumber.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("settings.companyprofile.phoneNumber.button"), for: .normal)
            self.viewButtonNext.button.addTarget(self, action: #selector(handleContinue), for: .touchUpInside)
        }
    }

    @IBOutlet private var buttonDelete: UIButton! {
        didSet {
            self.buttonDelete.configureButtonDestructive()
            self.buttonDelete.setTitle(DPAGLocalizedString("settings.companyprofile.phoneNumber.buttonDelete"), for: .normal)
        }
    }

    var completion: (() -> Void)?

    init() {
        super.init(nibName: "DPAGCompanyProfilInitPhoneNumberController", bundle: Bundle(for: type(of: self)))
        NotificationCenter.default.addObserver(self, selector: #selector(handleConfirmedIdentitiesChanged), name: DPAGStrings.Notification.Account.CONFIRMED_IDENTITIES_CHANGED, object: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: self.textFieldPhoneNumber)
        NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.Account.CONFIRMED_IDENTITIES_CHANGED, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let account = DPAGApplicationFacade.cache.account {
            self.configureGui(account)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(handleTextDidChange(_:)), name: UITextField.textDidChangeNotification, object: self.textFieldPhoneNumber)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.skipToPhoneNumberValidation {
            self.skipToPhoneNumberValidation = false
            self.continueToValidation()
        } else {
            self.textFieldPhoneNumber.becomeFirstResponder()
        }
    }

    @objc
    private func handleTextDidChange(_: Notification?) {
        self.updateBtnState()
    }

    private func updateBtnState() {
        if let text1 = self.textFieldPhoneNumber.text, text1.isEmpty == false {
            self.viewButtonNext.isEnabled = true
        } else {
            self.viewButtonNext.isEnabled = false
        }
    }

    @objc
    private func handleViewCountryTapped(_: UITapGestureRecognizer) {
        self.dismissKeyboard(nil)
        self.removePicker()
    }

    override func handleViewTapped(_ sender: Any?) {
        self.dismissKeyboard(sender)
    }

    override func handleKeyboardWillShow(_ aNotification: Notification) {
        if let textFieldEditing = self.textFieldEditing {
            self.removePicker()
            self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavCheck], action: #selector(handleNumberInputDoneTapped), accessibilityLabelIdentifier: "navigation.done")
            super.handleKeyboardWillShow(aNotification, scrollView: self.scrollView, viewVisible: textFieldEditing, viewButtonPrimary: self.viewButtonNext)
        }
    }

    override func handleKeyboardWillHide(_ aNotification: Notification) {
        self.navigationItem.setRightBarButton(nil, animated: true)
        super.handleKeyboardWillHide(aNotification, scrollView: self.scrollView, viewButtonPrimary: self.viewButtonNext)
    }

    private func dismissKeyboard(_: Any?) {
        self.textFieldPhoneNumber?.resignFirstResponder()
    }

    private func configureGui(_: DPAGAccount) {
        self.title = DPAGLocalizedString("settings.companyprofile.phoneNumber.title")
        self.buttonCountryChooser.addSubview(self.imageViewDrillDown)
        NSLayoutConstraint.activate([
            self.buttonCountryChooser.topAnchor.constraint(equalTo: self.imageViewDrillDown.topAnchor),
            self.buttonCountryChooser.bottomAnchor.constraint(equalTo: self.imageViewDrillDown.bottomAnchor),
            self.buttonCountryChooser.trailingAnchor.constraint(equalTo: self.imageViewDrillDown.trailingAnchor)
        ])
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleViewCountryTapped(_:)))
        tap.numberOfTapsRequired = 1
        tap.cancelsTouchesInView = true
        tap.isEnabled = false
        self.view.addGestureRecognizer(tap)
        self.tapGrViewCountry = tap
        self.countryPicker.isHidden = true
        if AppConfig.buildConfigurationMode == .DEBUG {
            self.updateCountryInfo(0)
        } else {
            self.determineUserPreferredSettings()
        }
        self.configureIdentity()
        self.updateBtnState()
    }

    private func configureIdentity() {
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) else { return }
        if var phoneNumber = DPAGApplicationFacade.preferences.validationPhoneNumber ?? contact.phoneNumber {
            if let countryCode = DPAGCountryCodes.sharedInstance.countryCodeByPhone(phoneNumber), phoneNumber.hasPrefix(countryCode) {
                self.updateCountryInfo(DPAGCountryCodes.sharedInstance.indexForCode(countryCode))
                phoneNumber = String(phoneNumber[phoneNumber.index(phoneNumber.startIndex, offsetBy: countryCode.count)...])
            }
            self.textFieldPhoneNumber.text = phoneNumber
        } else {
            self.textFieldPhoneNumber.text = nil
        }
        if DPAGApplicationFacade.preferences.isCompanyManagedState {
            self.textFieldPhoneNumber.isEnabled = (self.textFieldPhoneNumber.text?.isEmpty ?? true) || (DPAGApplicationFacade.preferences.validationPhoneNumber == nil)
            self.buttonCountryChooser.isEnabled = self.textFieldPhoneNumber.isEnabled
            self.buttonDelete.isHidden = true
        } else {
            self.buttonDelete.isHidden = contact.phoneNumber == nil || contact.eMailAddress == nil
        }
    }

    @objc
    private func handleConfirmedIdentitiesChanged() {
        self.performBlockOnMainThread { [weak self] in
            self?.configureIdentity()
        }
    }

    private func determineUserPreferredSettings() {
        let locale = Locale.current
        let iso = (locale as NSLocale).object(forKey: NSLocale.Key.countryCode) as? String
        self.updateCountryInfo(DPAGCountryCodes.sharedInstance.indexForIso(iso))
    }

    private func updateCountryInfo(_ index: Int) {
        if index >= 0 {
            self.preferredCountryIndex = index
            let country = DPAGCountryCodes.sharedInstance.countries[index]
            self.labelCountryCode.text = country.code
            self.buttonCountryChooser.setTitle(country.name, for: .normal)
        }
    }

    @objc
    private func handleCountryCodeDoneTapped() {
        self.removePicker()
        self.textFieldPhoneNumber.becomeFirstResponder()
    }

    @objc
    private func handleNumberInputDoneTapped() {
        self.textFieldPhoneNumber.resignFirstResponder()
    }

    private func removePicker() {
        if self.countryPicker.isHidden {
            return
        }
        self.countryPicker.isHidden = true
        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: { [weak self] in
            self?.countryPicker.superview?.layoutIfNeeded()
        })
        self.navigationItem.setRightBarButton(nil, animated: true)
        self.tapGrViewCountry?.isEnabled = false
    }

    @IBAction private func handleDelete() {
        self.textFieldPhoneNumber.resignFirstResponder()
        self.removePicker()
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let phoneNumber = contact.phoneNumber else { return }
        let message = self.messageDeleteConfirmation(phoneNumber: phoneNumber)
        let actionContinue = UIAlertAction(titleIdentifier: "res.continue", style: .default, handler: { [weak self] _ in
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
                self?.handleDeleteContinue()
            }
        })
        self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "settings.companyprofile.phoneNumber.confirmDelete.title", messageAttributed: message, cancelButtonAction: .cancelDefault, otherButtonActions: [actionContinue]))
    }

    private func messageDeleteConfirmation(phoneNumber: String) -> NSAttributedString {
        let message = DPAGLocalizedString("settings.companyprofile.phoneNumber.confirmDelete.text1")
        let messageAttributed = NSMutableAttributedString(string: "\n" + message + "\n\n", attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontFootnote])
        messageAttributed.append(NSAttributedString(string: phoneNumber + "\n\n", attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontHeadline]))
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
                        if self?.presentedViewController != nil {
                            self?.dismiss(animated: true, completion: nil)
                        } else {
                            self?.navigationController?.popViewController(animated: true)
                        }
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

    @IBAction private func handleContinue() {
        self.textFieldPhoneNumber.resignFirstResponder()
        self.removePicker()
        guard let phoneNumberEntered = self.textFieldPhoneNumber.text, phoneNumberEntered.isEmpty == false else {
            self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "registration.subline.phone_empty", okActionHandler: { [weak self] _ in
                self?.textFieldPhoneNumber.becomeFirstResponder()
            }))
            return
        }
        let phoneNumber = DPAGCountryCodes.sharedInstance.normalizePhoneNumber(phoneNumberEntered, countryCodeAccount: nil, useCountryCode: self.labelCountryCode.text)
        let countryCodeCount: Int = (self.labelCountryCode.text?.count ?? 0)
        if (phoneNumber.count - countryCodeCount) < 6 {
            self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "registration.subline.phone_empty", okActionHandler: { [weak self] _ in
                self?.textFieldPhoneNumber.becomeFirstResponder()
            }))
            return
        }
        let message = self.messageContinue(phoneNumber: phoneNumber)
        let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in
            self?.handleContinueWithPhone(phoneNumber)
        })
        self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "settings.companyprofile.phoneNumber.confirmsend.title", messageAttributed: message, cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
    }

    private func messageContinue(phoneNumber: String) -> NSAttributedString {
        let message = DPAGLocalizedString("settings.companyprofile.phoneNumber.confirmsend.text1")
        let messageAttributed = NSMutableAttributedString(string: "\n" + message + "\n\n", attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontFootnote])
        messageAttributed.append(NSAttributedString(string: phoneNumber + "\n\n", attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontHeadline]))
        return messageAttributed
    }

    private func handleContinueWithPhone(_ phoneNumber: String) {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            DPAGApplicationFacade.companyAdressbook.requestConfirmationSMS(phoneNumber: phoneNumber, force: false, withResponse: { [weak self] responseObject, errorCode, errorMessage in
                let blockOK: DPAGServiceResponseBlock = { [weak self] responseObject, errorCode, errorMessage in
                    guard let strongSelf = self else { return }
                    if let errorMessage = errorMessage {
                        strongSelf.handleServiceError(errorCode, message: errorMessage)
                    } else if let accountGuid = (responseObject as? [String])?.first, accountGuid == DPAGApplicationFacade.cache.account?.guid {
                        strongSelf.handleServiceSuccess(phoneNumber)
                    } else {
                        strongSelf.handleServiceError("Invalid Response", message: "Invalid Response")
                    }
                }
                // ERR-0077: PHONE_ALREADY_USED
                // ERR-0099: PHONE_ALREADY_USED_PENDING
                if errorCode == "ERR-0077" || errorCode == "ERR-0099" {
                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                        // https://github.com/ginlonet/ginlo-client-ios/issues/36
                        self?.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "requestPhoneNumberConfirmation.alert.phoneNumberAlreadyUsed.message"))
//                        let actionContinue = UIAlertAction(titleIdentifier: "res.continue", style: .destructive, handler: { _ in
//                            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
//                                DPAGApplicationFacade.companyAdressbook.requestConfirmationSMS(phoneNumber: phoneNumber, force: true, withResponse: blockOK)
//                            }
//                        })
//                        self?.presentAlert(alertConfig: AlertConfig(titleIdentifier: "requestPhoneNumberConfirmation.alert.phoneNumberAlreadyUsed.title", messageIdentifier: "requestPhoneNumberConfirmation.alert.phoneNumberAlreadyUsed.message", cancelButtonAction: .cancelDefault, otherButtonActions: [actionContinue]))
                    }
                } else {
                    blockOK(responseObject, errorCode, errorMessage)
                }
            })
        }
    }

    private func handleServiceError(_: String?, message: String) {
        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: message))
        }
    }

    private func savePhoneNumber(_ phoneNumber: String) {
        DPAGApplicationFacade.accountManager.save(phoneNumber: phoneNumber)
    }

    private func handleServiceSuccess(_ phoneNumber: String) {
        self.savePhoneNumber(phoneNumber)
        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
            guard let strongSelf = self else { return }
            let message = strongSelf.messageServiceSuccess(phoneNumber: phoneNumber)
            let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in
                self?.continueToValidation()
            })

            strongSelf.presentAlert(alertConfig: AlertConfig(titleIdentifier: "settings.companyprofile.phoneNumber.send.title", messageAttributed: message, otherButtonActions: [actionOK]))
        }
    }

    private func messageServiceSuccess(phoneNumber: String) -> NSAttributedString {
        let message = DPAGLocalizedString("settings.companyprofile.phoneNumber.send.text1")
        let messageAttributed = NSMutableAttributedString(string: "\n" + message + "\n\n", attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontFootnote])
        messageAttributed.append(NSAttributedString(string: phoneNumber, attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontHeadline]))
        return messageAttributed
    }

    private func continueToValidation() {
        let nextVC = DPAGApplicationFacadeUISettings.companyProfilConfirmPhoneNumberVC()
        (nextVC as? DPAGViewControllerWithCompletion)?.completion = self.completion
        self.navigationController?.pushViewController(nextVC, animated: true)
    }
}

extension DPAGCompanyProfilInitPhoneNumberController: UIPickerViewDataSource {
    func numberOfComponents(in _: UIPickerView) -> Int {
        1
    }

    func pickerView(_: UIPickerView, numberOfRowsInComponent _: Int) -> Int {
        let count = DPAGCountryCodes.sharedInstance.countries.count
        DPAGLog("number fo countries \(count)")
        return count
    }
}

extension DPAGCompanyProfilInitPhoneNumberController: UIPickerViewDelegate {
    func pickerView(_: UIPickerView, attributedTitleForRow row: Int, forComponent _: Int) -> NSAttributedString? {
        let name = DPAGCountryCodes.sharedInstance.countries[row].name
        return NSAttributedString(string: name ?? "?", attributes: [.foregroundColor: DPAGColorProvider.shared[.datePickerText]])
    }

    func pickerView(_: UIPickerView, didSelectRow row: Int, inComponent _: Int) {
        self.updateCountryInfo(row)
    }
}

extension DPAGCompanyProfilInitPhoneNumberController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.textFieldEditing = textField
    }

    func textFieldShouldReturn(_: UITextField) -> Bool {
        if self.viewButtonNext.isEnabled {
            self.perform(#selector(handleContinue), with: nil, afterDelay: 0.1)
        }
        return true
    }
}
