//
//  DPAGRequestAccountViewController.swift
// ginlo
//
//  Created by RBU on 23/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGRequestAccountViewControllerProtocol: AnyObject {
  func resetPassword()
}

class DPAGRequestAccountViewController: DPAGViewControllerWithKeyboard, DPAGRequestAccountViewControllerProtocol {
  private static let kPickerHeight: CGFloat = 162
  private static let DPAGAccountManagerAccountExistsErrorCode = "service.ERR-0077"
  private static let DPAGAccountManagerAccountIsBlockedErrorCode = "service.ERR-0099"
  
  @IBOutlet private var scrollView: UIScrollView!
  @IBOutlet private var labelHeadline: UILabel! {
    didSet {
      self.labelHeadline.text = DPAGLocalizedString("registration.headline.phoneAndCountryCode")
      self.labelHeadline.font = UIFont.kFontTitle1
      self.labelHeadline.textColor = DPAGColorProvider.shared[.labelText]
      self.labelHeadline.numberOfLines = 0
    }
  }
  
  @IBOutlet private var viewDataSelection: DPAGAccountIDSelectorView! {
    didSet {
      self.viewDataSelection.delegate = self
    }
  }
  
  @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
    didSet {
      self.viewButtonNext.button.accessibilityIdentifier = "buttonNext"
      self.viewButtonNext.button.setTitle(DPAGLocalizedString("registration.buttonNextLabel.createAccount"), for: .normal)
      self.viewButtonNext.button.addTarget(self, action: #selector(handleSendTapped), for: .touchUpInside)
      self.viewButtonNext.isEnabled = false
    }
  }
  
  @IBOutlet private var stackViewAll: UIStackView!
  
  @IBOutlet private var labelTerms: DPAGChatLabel! {
    didSet {
      self.labelTerms.font = UIFont.kFontSubheadline
      self.labelTerms.textColor = DPAGColorProvider.shared[.labelText]
      self.labelTerms.numberOfLines = 0
      let btnTitle = DPAGLocalizedString("registration.buttonNextLabel.createAccount")
      let textAGBPre = String(format: DPAGLocalizedString("registration.agb.pre"), btnTitle)
      let termsText = NSMutableAttributedString(string: textAGBPre, attributes: [.font: UIFont.kFontSubheadline, .foregroundColor: DPAGColorProvider.shared[.labelText]])
      let termsLink = NSAttributedString(string: DPAGLocalizedString("registration.agb.AGB"), attributes: [.font: UIFont.kFontSubheadline, .foregroundColor: DPAGColorProvider.shared[.labelLink]])
      let termsTextLength = (termsText.string as NSString).length
      let termsLinkLength = (termsLink.string as NSString).length
      termsText.append(termsLink)
      self.labelTerms.attributedText = termsText
      self.labelTerms.linkAttributeDefault = [.foregroundColor: DPAGColorProvider.shared[.labelLink], .underlineStyle: NSUnderlineStyle.single.rawValue]
      self.labelTerms.linkAttributeHighlight = [.foregroundColor: DPAGColorProvider.shared[.labelLink], .underlineStyle: NSUnderlineStyle.single.rawValue]
      if let url = URL(string: DPAGLocalizedString("settings.termsandcondition.url")) {
        self.labelTerms.setLink(url: url, for: NSRange(location: termsTextLength, length: termsLinkLength))
      }
      self.labelTerms.accessibilityIdentifier = "registration.agb.pre"
      self.labelTerms.delegate = self
    }
  }
  
  @IBOutlet private var skipEnterPhonenEmailButton: UIButton! {
    didSet {
      if DPAGApplicationFacade.preferences.isBaMandant {
        self.skipEnterPhonenEmailButton.isHidden = true
      } else {
        self.skipEnterPhonenEmailButton.accessibilityIdentifier = "buttonNext"
        self.skipEnterPhonenEmailButton.setTitle(DPAGLocalizedString("registration.buttonNextLabel.skipContactInfo"), for: .normal)
        self.skipEnterPhonenEmailButton.setTitleColor(DPAGColorProvider.shared[.labelLink], for: .normal)
        self.skipEnterPhonenEmailButton.addTargetClosure { _ in
          let title = "registration.request_account.create_confirm.title"
          let messageAttributed = NSMutableAttributedString(string: DPAGLocalizedString("registration.request_account.create_confirm.message_no_contact"), attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontSubheadline])
          let proceedButtonTitle = "registration.request_account.create_confirm.continue_without_contact"
          let actionContinue = UIAlertAction(titleIdentifier: proceedButtonTitle, style: .default, handler: { [weak self] _ in
            self?.createAnonymousAccount()
          })
          let actionCancel = UIAlertAction(titleIdentifier: "registration.request_account.create_confirm.back", style: .cancel, handler: nil)
          self.presentAlert(alertConfig: AlertConfig(titleIdentifier: title, messageAttributed: messageAttributed, cancelButtonAction: actionCancel, otherButtonActions: [actionContinue]))
        }
      }
    }
  }
  
  private func createAnonymousAccount() {
    guard self.password != nil else { return }
    DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true, completion: { [weak self] _ in
      guard let strongSelf = self, let password = strongSelf.password else { return }
      do {
        _ = try DPAGApplicationFacade.backupWorker.isICloudEnabled()
      } catch {
        DPAGLog(error)
      }
      strongSelf.accountGuid = DPAGApplicationFacade.accountManager.createAccount(password: password, phoneNumber: nil, emailAddress: nil, emailDomain: nil, endpoint: strongSelf.endpoint) { [weak self] responseObject, _, errorMessage in
        if let errorMessage = errorMessage {
          self?.handleAnonymousServiceError(errorMessage)
        } else if let responseArr = responseObject as? [Any] {
          self?.handleAnonymousServiceSuccess(responseArr)
        } else {
          self?.handleAnonymousServiceError("service.ERR-0001")
        }
      }
    })
  }
  
  private func handleAnonymousServiceSuccess(_ responseArr: [Any]) {
    DPAGApplicationFacade.preferences.isInAppNotificationEnabled = false
    // This part cannot happen if the account is created anonymously, but we need to
    // know whether the user would like to restore a backup...
    // ANONYMOUS:
    if responseArr.count > 1 {
      DPAGApplicationFacade.preferences.setBootstrappingCheckbackup(true)
      DPAGApplicationFacade.preferences.bootstrappingOverrideAccount = true
      var skipOverwriteWarning = true
      var availableAccountID: [String] = []
      responseArr.forEach { accountObj in
        if let account = accountObj as? [String: Any], let accountDict = account["Account"] as? [String: String] {
          let guid = accountDict["guid"]
          let mandant = accountDict["mandant"]
          let accountID = accountDict["accountID"]
          if guid != self.accountGuid, let accountID = accountID {
            availableAccountID.append(accountID)
            if mandant == DPAGApplicationFacade.preferences.mandantIdent {
              skipOverwriteWarning = false
              DPAGApplicationFacade.preferences.bootstrappingOldAccountID = accountID
            }
          }
        }
      }
      DPAGApplicationFacade.preferences.bootstrappingAvailableAccountID = availableAccountID
      DPAGApplicationFacade.preferences.bootstrappingSkipWarningOverrideAccount = skipOverwriteWarning
    }
    // END
    if let dictionary = responseArr[0] as? [AnyHashable: Any], let dictAccount = dictionary[DPAGStrings.JSON.Account.OBJECT_KEY] as? [AnyHashable: Any], let accountID = dictAccount[DPAGStrings.JSON.Account.ACCOUNT_ID] as? String {
      DPAGApplicationFacade.accountManager.autoConfirmAccount(accountID: accountID)
      DPAGApplicationFacade.model.update(with: nil)
      DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
        if let strongSelf = self {
          if strongSelf.enabledPassword == false {
            DPAGApplicationFacade.preferences.passwordOnStartEnabled = false
          }
          guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let accountID = contact.accountID else { return }
          let vc = DPAGApplicationFacadeUIRegistration.welcomeVC(account: account.guid, accountID: accountID, phoneNumber: contact.phoneNumber, emailAddress: contact.eMailAddress, emailDomain: contact.eMailDomain, checkUsage: false)
          strongSelf.navigationController?.pushViewController(vc, animated: true)
        }
      }
    }
  }
  
  private func handleAnonymousServiceError(_ message: String) {
    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
      if let strongSelf = self {
        strongSelf.handleAnonymousAccountCreationFailedWithMessage(message)
      }
    }
  }
  
  private func handleAnonymousAccountCreationFailedWithMessage(_ message: String) {
    DPAGApplicationFacade.accountManager.resetDatabase()
    self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: message))
  }
  
  override
  func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if #available(iOS 13.0, *) {
      if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
        DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
        self.labelHeadline.textColor = DPAGColorProvider.shared[.labelText]
        self.labelTerms.textColor = DPAGColorProvider.shared[.labelText]
        self.labelTerms.linkAttributeDefault = [.foregroundColor: DPAGColorProvider.shared[.labelLink], .underlineStyle: NSUnderlineStyle.single.rawValue]
        self.labelTerms.linkAttributeHighlight = [.foregroundColor: DPAGColorProvider.shared[.labelLink], .underlineStyle: NSUnderlineStyle.single.rawValue]
        self.skipEnterPhonenEmailButton.setTitleColor(DPAGColorProvider.shared[.labelLink], for: .normal)
      }
    } else {
      DPAGColorProvider.shared.darkMode = false
    }
  }
  
  private var textFieldActive: UITextField?
  private var tapGrViewDataSelection: UITapGestureRecognizer?
  private var tapGrViewCountry: UITapGestureRecognizer?
  private var accountGuid: String?
  private var password: String?
  private var enabledPassword = false
  private var endpoint: String?
  
  init(password: String, enabled: Bool, endpoint: String?) {
    self.password = password
    self.enabledPassword = enabled
    self.endpoint = endpoint
    super.init(nibName: "DPAGRequestAccountViewController", bundle: Bundle(for: type(of: self)))
  }
  
  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.navigationItem.title = DPAGLocalizedString("registration.title.createAccount")
    self.addGestureRecognizers()
    if DPAGApplicationFacade.preferences.isBaMandant == false {
      self.viewDataSelection.enabledPhoneOnly()
    } else {
      self.viewDataSelection.updateDataSelection(index: .emailAddress, withStack: true)
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    DPAGApplicationFacade.accountManager.resetDatabase()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if DPAGApplicationFacade.preferences.isBaMandant == false {
      self.viewDataSelection.textFieldPhone.becomeFirstResponder()
    } else {
      self.viewDataSelection.textFieldEmail.becomeFirstResponder()
    }
  }
  
  private func addGestureRecognizers() {
    let tapData = UITapGestureRecognizer(target: self, action: #selector(handleViewDataTapped(_:)))
    tapData.numberOfTapsRequired = 1
    tapData.cancelsTouchesInView = true
    tapData.isEnabled = false
    self.view.addGestureRecognizer(tapData)
    self.tapGrViewDataSelection = tapData
    let tapCountry = UITapGestureRecognizer(target: self, action: #selector(handleViewCountryTapped(_:)))
    tapCountry.numberOfTapsRequired = 1
    tapCountry.cancelsTouchesInView = true
    tapCountry.isEnabled = false
    self.view.addGestureRecognizer(tapCountry)
    self.tapGrViewCountry = tapCountry
  }
  
  override func handleViewTapped(_: Any?) {
    self.resignFirstResponder()
    self.viewDataSelection.removeDataPicker { [weak self] in
      self?.viewDataSelection.removeCountryPicker(completion: nil)
    }
  }
  
  @objc
  private func handleViewDataTapped(_: Any?) {
    self.resignFirstResponder()
    self.viewDataSelection.removeDataPicker(completion: nil)
  }
  
  @objc
  private func handleViewCountryTapped(_: Any?) {
    self.resignFirstResponder()
    self.viewDataSelection.removeCountryPicker(completion: nil)
  }
  
  @objc
  private func handleSendTapped() {
    self.resignFirstResponder()
    switch self.viewDataSelection.preferredDataSelectionIndex {
      case .phoneNum:
        guard let phoneNumberEntered = self.viewDataSelection.textFieldPhone.text, phoneNumberEntered.isEmpty == false else {
          self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "registration.subline.phone_empty", okActionHandler: { [weak self] _ in
            self?.viewDataSelection.textFieldPhone.becomeFirstResponder()
          }))
          return
        }
        let phoneNumber = DPAGCountryCodes.sharedInstance.normalizePhoneNumber(phoneNumberEntered, countryCodeAccount: nil, useCountryCode: self.viewDataSelection.labelCountryCodeValue.text)
        let countryCodeCount = (self.viewDataSelection.labelCountryCodeValue.text?.count ?? 0)
        if (phoneNumber.count - countryCodeCount) < 6 {
          self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "registration.subline.phone_empty", okActionHandler: { [weak self] _ in
            self?.viewDataSelection.textFieldPhone.becomeFirstResponder()
          }))
          return
        }
        self.createAccount(searchData: phoneNumber, searchMode: .phone)
      case .emailAddress:
        guard let accountData = self.viewDataSelection.textFieldEmail.text?.lowercased().trimmingCharacters(in: .whitespaces), accountData.isEmpty == false else {
          self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "registration.subline.email_empty", okActionHandler: { [weak self] _ in
            self?.viewDataSelection.textFieldEmail.becomeFirstResponder()
          }))
          return
        }
        self.createAccount(searchData: accountData, searchMode: .mail)
      case .simsmeID:
        break
    }
  }
  
  private func createAccount(searchData: String, searchMode _: DPAGCouplingSearchMode) {
    switch self.viewDataSelection.preferredDataSelectionIndex {
      case .phoneNum:
        let message = DPAGLocalizedString("registration.request_account.create_confirm.message") + "\n"
        self.prepareAlertAccountCreate(message: message, searchData: searchData, handler: { [weak self] _ in
          self?.create(phoneNumber: searchData, emailAddress: nil)
        })
      case .emailAddress:
        let message = DPAGLocalizedString("registration.request_account.create_confirm.message_emailaddress") + "\n"
        self.prepareAlertAccountCreate(message: message, searchData: searchData, handler: { [weak self] _ in
          self?.create(phoneNumber: nil, emailAddress: searchData)
        })
      case .simsmeID:
        break
    }
  }
  
  private func prepareAlertAccountCreate(message: String, searchData: String, handler: ((UIAlertAction) -> Void)?) {
    let title = "registration.request_account.create_confirm.title"
    let messageAttributed = NSMutableAttributedString(string: message, attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontSubheadline])
    messageAttributed.append(NSAttributedString(string: searchData, attributes: [.foregroundColor: DPAGColorProvider.shared[.alertTint], .font: UIFont.kFontHeadline]))
    let proceedButtonTitle = "registration.request_account.create_confirm.continue"
    let actionContinue = UIAlertAction(titleIdentifier: proceedButtonTitle, style: .default, handler: handler)
    let actionCancel = UIAlertAction(titleIdentifier: "registration.request_account.create_confirm.back", style: .cancel, handler: nil)
    self.presentAlert(alertConfig: AlertConfig(titleIdentifier: title, messageAttributed: messageAttributed, cancelButtonAction: actionCancel, otherButtonActions: [actionContinue]))
  }
  
  func resetPassword() {
    self.password = nil
  }
  
  override func handleKeyboardWillShow(_ aNotification: Notification) {
    self.viewDataSelection.removeDataPicker { [weak self] in
      self?.viewDataSelection.removeCountryPicker { [weak self] in
        guard let strongSelf = self else { return }
        strongSelf.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavCheck], action: #selector(strongSelf.handleInputDoneTapped), accessibilityLabelIdentifier: "navigation.done")
        if let textFieldActive = (strongSelf.textFieldActive ?? strongSelf.viewDataSelection.textFieldActive) {
          strongSelf.handleKeyboardWillShow(aNotification, scrollView: strongSelf.scrollView, viewVisible: textFieldActive, viewButtonPrimary: strongSelf.viewButtonNext)
        }
      }
    }
  }
  
  override func handleKeyboardWillHide(_ aNotification: Notification) {
    self.navigationItem.setRightBarButton(nil, animated: true)
    super.handleKeyboardWillHide(aNotification, scrollView: self.scrollView, viewButtonPrimary: self.viewButtonNext)
  }
  
  @objc
  private func handleDataSelectionDoneTapped() {
    self.viewDataSelection.removeDataPicker(completion: nil)
    // self.textFieldPhone.becomeFirstResponder()
  }
  
  @objc
  private func handleCountrySelectionDoneTapped() {
    self.viewDataSelection.removeCountryPicker(completion: nil)
    self.viewDataSelection.textFieldPhone.becomeFirstResponder()
  }
  
  @objc
  private func handleInputDoneTapped() {
    self.resignFirstResponder()
  }
  
  @discardableResult
  override func resignFirstResponder() -> Bool {
    self.viewDataSelection.resignFirstResponder()
    self.textFieldActive = nil
    return super.resignFirstResponder()
  }
  
  private func create(phoneNumber: String?, emailAddress: String?) {
    let block = { [weak self] (emailDomain: String?) in
      guard let strongSelf = self, let password = strongSelf.password else { return }
      do {
        _ = try DPAGApplicationFacade.backupWorker.isICloudEnabled()
      } catch {
        DPAGLog(error)
      }
      strongSelf.accountGuid = DPAGApplicationFacade.accountManager.createAccount(password: password, phoneNumber: phoneNumber, emailAddress: emailAddress, emailDomain: emailDomain, endpoint: strongSelf.endpoint) { [weak self] responseObject, _, errorMessage in
        if let errorMessage = errorMessage {
          self?.handleServiceError(errorMessage)
        } else if let responseArr = responseObject as? [Any] {
          self?.handleServiceSuccess(responseArr)
        } else {
          self?.handleServiceError("service.ERR-0001")
        }
      }
    }
    if self.password != nil {
      DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true, completion: { [weak self] _ in
        if let eMailAddress = emailAddress {
          DPAGApplicationFacade.requestWorker.checkEmailAddress(eMailAddress: eMailAddress) { responseObject, errorCode, errorMessage in
            if let errorMessage = errorMessage {
              if errorCode == "ERR-0124" { // BLACKLISTED_EMAIL_DOMAIN
                block(nil)
              } else {
                self?.handleServiceError(errorMessage)
              }
            } else if let domain = (responseObject as? [String])?.first {
              block(domain)
            } else {
              self?.handleServiceError("service.ERR-0001")
            }
          }
        } else {
          block(nil)
        }
      })
    }
  }
  
  private func handleServiceSuccess(_ responseArr: [Any]) {
    DPAGApplicationFacade.preferences.isInAppNotificationEnabled = false
    if responseArr.count > 1 {
      DPAGApplicationFacade.preferences.setBootstrappingCheckbackup(true)
      DPAGApplicationFacade.preferences.bootstrappingOverrideAccount = true
      var skipOverwriteWarning = true
      var availableAccountID: [String] = []
      responseArr.forEach { accountObj in
        if let account = accountObj as? [String: Any], let accountDict = account["Account"] as? [String: String] {
          let guid = accountDict["guid"]
          let mandant = accountDict["mandant"]
          let accountID = accountDict["accountID"]
          if guid != self.accountGuid, let accountID = accountID {
            availableAccountID.append(accountID)
            if mandant == DPAGApplicationFacade.preferences.mandantIdent {
              skipOverwriteWarning = false
              DPAGApplicationFacade.preferences.bootstrappingOldAccountID = accountID
            }
          }
        }
      }
      DPAGApplicationFacade.preferences.bootstrappingAvailableAccountID = availableAccountID
      DPAGApplicationFacade.preferences.bootstrappingSkipWarningOverrideAccount = skipOverwriteWarning
    }
    
    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
      if let strongSelf = self {
        if strongSelf.enabledPassword == false {
          DPAGApplicationFacade.preferences.passwordOnStartEnabled = false
        }
        strongSelf.title = ""
        strongSelf.navigationController?.pushViewController(DPAGApplicationFacadeUIRegistration.confirmAccountVC(confirmationCode: nil), animated: true)
      }
    }
  }
  
  private func handleServiceError(_ message: String) {
    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
      if let strongSelf = self {
        strongSelf.handleAccountCreationFailedWithMessage(message)
      }
    }
  }
  
  private func handleAccountCreationFailedWithMessage(_ message: String) {
    DPAGApplicationFacade.accountManager.resetDatabase()
    self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: message))
  }
}

extension DPAGRequestAccountViewController: DPAGChatLabelDelegate {
  func didSelectLinkWithURL(_ url: URL) {
    AppConfig.openURL(url)
  }
}

extension DPAGRequestAccountViewController: DPAGAccountIDSelectorViewDelegate {
  var labelPhoneNumberSelection: String {
    DPAGLocalizedString("registration.createDevice.inputDataLabelPhoneNumber.label")
  }
  
  var labelEMailAddressSelection: String {
    DPAGLocalizedString("registration.createDevice.inputDataLabelEmail.label")
  }
  
  var labelSIMSmeIDSelection: String {
    DPAGLocalizedString("registration.createDevice.inputDataLabelAccountID.label")
  }
  
  var labelPhoneNumberPicker: String {
    DPAGLocalizedString("registration.createDevice.inputDataLabelPhoneNumber")
  }
  
  var labelEMailAddressPicker: String {
    DPAGLocalizedString("registration.createDevice.inputDataLabelEmail")
  }
  
  var labelSIMSmeIDPicker: String {
    DPAGLocalizedString("registration.createDevice.inputDataLabelAccountID")
  }
  
  func accountIDSelectorViewWillShowDataSelection() {
    self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavCheck], action: #selector(handleDataSelectionDoneTapped), accessibilityLabelIdentifier: "navigation.done")
    self.tapGrViewDataSelection?.isEnabled = true
  }
  
  func accountIDSelectorViewWillHideDataSelection() {
    self.navigationItem.setRightBarButton(nil, animated: true)
    self.tapGrViewDataSelection?.isEnabled = false
  }
  
  func accountIDSelectorViewWillShowCountryCodeSelection() {
    self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavCheck], action: #selector(handleCountrySelectionDoneTapped), accessibilityLabelIdentifier: "navigation.done")
    
    self.tapGrViewCountry?.isEnabled = true
  }
  
  func accountIDSelectorViewWillHideCountryCodeSelection() {
    self.navigationItem.setRightBarButton(nil, animated: true)
    self.tapGrViewCountry?.isEnabled = false
  }
  
  func accountIDSelectorViewDidSelect() {
    switch self.viewDataSelection.preferredDataSelectionIndex {
      case .phoneNum:
        self.viewButtonNext.isEnabled = (self.viewDataSelection.textFieldPhone.text?.isEmpty ?? true) == false
      case .emailAddress:
        self.viewButtonNext.isEnabled = (self.viewDataSelection.textFieldEmail.text?.isEmpty ?? true) == false
      case .simsmeID:
        self.viewButtonNext.isEnabled = (self.viewDataSelection.textFieldAccountID.text?.isEmpty ?? true) == false
    }
  }
}

extension DPAGRequestAccountViewController: UITextFieldDelegate {
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    if let textFieldText = textField.text {
      let text: NSString = textFieldText as NSString
      let resultedString = text.replacingCharacters(in: range, with: string)
      self.viewButtonNext.isEnabled = resultedString.isEmpty == false
    } else {
      self.viewButtonNext.isEnabled = false
    }
    return true
  }
  
  func textFieldShouldReturn(_: UITextField) -> Bool {
    self.perform(#selector(handleSendTapped), with: nil, afterDelay: 0.1)
    return true
  }
  
  func textFieldDidBeginEditing(_ textField: UITextField) {
    self.textFieldActive = textField
  }
}
