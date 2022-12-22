//
//  DPAGContactNewSearchViewController.swift
// ginlo
//
//  Created by RBU on 18.12.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGContactNewSearchViewController: DPAGViewControllerWithKeyboard, DPAGContactNewSearchViewControllerProtocol {
  private enum DataSelectionType: Int, CaseCountable {
    case phoneNum,
         emailAddress,
         simsmeID
  }
  
  @IBOutlet private var scrollView: UIScrollView!
  @IBOutlet private var labelHeader: UILabel! {
    didSet {
      self.labelHeader.text = DPAGLocalizedString("contacts.search.header")
      self.labelHeader.font = UIFont.kFontTitle1
      self.labelHeader.textColor = DPAGColorProvider.shared[.labelText]
      self.labelHeader.numberOfLines = 0
    }
  }
  
  @IBOutlet private var labelDescription: UILabel! {
    didSet {
      self.labelDescription.text = String(format: DPAGLocalizedString("contacts.search.description"), DPAGMandant.default.name)
      self.labelDescription.font = UIFont.kFontSubheadline
      self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
      self.labelDescription.numberOfLines = 0
    }
  }
  
  @IBOutlet private var labelAccountData: UILabel! {
    didSet {
      self.labelAccountData.text = DPAGLocalizedString("contacts.search.labelAccountData")
      self.labelAccountData.font = UIFont.kFontFootnote
      self.labelAccountData.textColor = DPAGColorProvider.shared[.labelText]
      self.labelAccountData.numberOfLines = 0
    }
  }
  
  @IBOutlet private var viewDataSelection: DPAGAccountIDSelectorView! {
    didSet {
      self.viewDataSelection.delegate = self
      self.viewDataSelection.labelCountryCode.text = DPAGLocalizedString("contacts.search.labelCountryCode")
      self.viewDataSelection.labelPhone.text = DPAGLocalizedString("contacts.search.labelPhone")
    }
  }
  
  @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
    didSet {
      self.viewButtonNext.button.accessibilityIdentifier = "buttonContinue"
      self.viewButtonNext.button.setTitle(DPAGLocalizedString("contacts.search.buttonContinue"), for: .normal)
      self.viewButtonNext.button.addTarget(self, action: #selector(handleContinueTapped), for: .touchUpInside)
    }
  }
  
  override
  func handleDesignColorsUpdated() {
    super.handleDesignColorsUpdated()
    self.labelHeader.textColor = DPAGColorProvider.shared[.labelText]
    self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
    self.labelAccountData.textColor = DPAGColorProvider.shared[.labelText]
  }
  
  private var textFieldActive: UITextField?
  private var tapGrViewDataSelection: UITapGestureRecognizer?
  private var tapGrViewCountry: UITapGestureRecognizer?
  
  var phoneNumInit: String?
  var countryCodeInit: String?
  var emailAddressInit: String?
  var ginloIDInit: String?
  
  init() {
    super.init(nibName: "DPAGContactNewSearchViewController", bundle: Bundle(for: type(of: self)))
  }
  
  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.title = DPAGLocalizedString("contacts.options.addContact")
    self.addGestureRecognizers()
    if self.countryCodeInit != nil {
      self.viewDataSelection.updateCountryInfo(index: DPAGCountryCodes.sharedInstance.indexForCode(self.countryCodeInit))
    }
    if self.ginloIDInit != nil {
      self.viewDataSelection.textFieldAccountID.text = self.ginloIDInit
      self.viewDataSelection.updateDataSelection(index: .simsmeID, withStack: true)
    } else if self.phoneNumInit != nil {
      self.viewDataSelection.textFieldPhone.text = self.phoneNumInit
      self.viewDataSelection.updateDataSelection(index: .phoneNum, withStack: true)
    } else if self.emailAddressInit != nil {
      self.viewDataSelection.textFieldEmail.text = self.emailAddressInit
      self.viewDataSelection.updateDataSelection(index: .emailAddress, withStack: true)
    } else {
      self.viewDataSelection.updateDataSelection(index: .phoneNum, withStack: true)
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
  
  @objc
  private func handleContinueTapped() {
    self.resignFirstResponder()
    switch self.viewDataSelection.preferredDataSelectionIndex {
      case .phoneNum:
        let accountData = self.viewDataSelection.textFieldPhone.text ?? ""
        if accountData.isEmpty {
          self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "registration.subline.phone_empty", okActionHandler: { [weak self] _ in
            self?.viewDataSelection.textFieldPhone.becomeFirstResponder()
          }))
          return
        }
        let phoneNumber = DPAGCountryCodes.sharedInstance.normalizePhoneNumber(accountData, countryCodeAccount: nil, useCountryCode: self.viewDataSelection.labelCountryCodeValue.text)
        let countryCodeCount = (self.viewDataSelection.labelCountryCodeValue.text?.count ?? 0)
        if (phoneNumber.count - countryCodeCount) < 6 {
          self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "registration.subline.phone_empty", okActionHandler: { [weak self] _ in
            self?.viewDataSelection.textFieldPhone.becomeFirstResponder()
          }))
          return
        }
        self.searchAccount(searchData: phoneNumber, searchMode: .phone)
      case .emailAddress:
        let accountData = self.viewDataSelection.textFieldEmail.text?.lowercased() ?? ""
        if accountData.isEmpty {
          self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "registration.subline.email_empty", okActionHandler: { [weak self] _ in
            self?.viewDataSelection.textFieldEmail.becomeFirstResponder()
          }))
          return
        }
        self.searchAccount(searchData: accountData, searchMode: .mail)
      case .simsmeID:
        let accountData = self.viewDataSelection.textFieldAccountID.text ?? ""
        if accountData.isEmpty {
          self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "registration.subline.accountID_empty", okActionHandler: { [weak self] _ in
            self?.viewDataSelection.textFieldAccountID.becomeFirstResponder()
          }))
          return
        }
        self.searchAccount(searchData: accountData, searchMode: .accountID)
    }
  }
  
  private func searchAccount(searchData: String, searchMode: DPAGContactSearchMode) {
    DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
      DPAGApplicationFacade.contactsWorker.searchAccount(searchData: searchData, searchMode: searchMode) { responseObject, _, errorMessage in
        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
          if let errorMessage = errorMessage {
            self?.presentErrorAlert(alertConfig: AlertConfigError(titleIdentifier: "attention", messageIdentifier: errorMessage))
          } else if let guids = responseObject as? [String] {
            if let account = DPAGApplicationFacade.cache.account, let contactSelf = DPAGApplicationFacade.cache.contact(for: account.guid) {
              if guids.count > 1 {
                let nextVC = DPAGApplicationFacadeUIContacts.contactNewSelectVC(contactGuids: guids)
                self?.navigationController?.pushViewController(nextVC, animated: true)
              } else if let guid = guids.first, let contactCache = DPAGApplicationFacade.cache.contact(for: guid) {
                switch contactCache.entryTypeServer {
                  case .company:
                    let nextVC = DPAGApplicationFacadeUIContacts.contactDetailsVC(contact: contactCache)
                    self?.navigationController?.pushViewController(nextVC, animated: true)
                  case .email:
                    if contactCache.eMailDomain == contactSelf.eMailDomain {
                      let nextVC = DPAGApplicationFacadeUIContacts.contactDetailsVC(contact: contactCache)
                      self?.navigationController?.pushViewController(nextVC, animated: true)
                    } else {
                      let nextVC = DPAGApplicationFacadeUIContacts.contactNewCreateVC(contact: contactCache)
                      self?.navigationController?.pushViewController(nextVC, animated: true)
                    }
                  case .meMyselfAndI:
                    break
                  case .privat:
                    let nextVC = DPAGApplicationFacadeUIContacts.contactNewCreateVC(contact: contactCache)
                    self?.navigationController?.pushViewController(nextVC, animated: true)
                }
              } else {
                let nextVC = DPAGApplicationFacadeUIContacts.contactNotFoundVC(searchData: searchData, searchMode: searchMode)
                self?.navigationController?.pushViewController(nextVC, animated: true)
              }
            } else {
              let nextVC = DPAGApplicationFacadeUIContacts.contactNotFoundVC(searchData: searchData, searchMode: searchMode)
              self?.navigationController?.pushViewController(nextVC, animated: true)
            }
          }
        }
      }
    }
  }
}

extension DPAGContactNewSearchViewController: DPAGAccountIDSelectorViewDelegate {
  var labelPhoneNumberSelection: String {
    DPAGLocalizedString("registration.createDevice.inputDataLabelPhoneNumber")
  }
  
  var labelEMailAddressSelection: String {
    DPAGLocalizedString("registration.createDevice.inputDataLabelEmail")
  }
  
  var labelSIMSmeIDSelection: String {
    DPAGLocalizedString("registration.createDevice.inputDataLabelAccountID")
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

extension DPAGContactNewSearchViewController: UITextFieldDelegate {
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    guard let currentText = (textField.text as NSString?) else {
      self.viewButtonNext.isEnabled = false
      return true
    }
    let resultedString = currentText.replacingCharacters(in: range, with: string)
    self.viewButtonNext.isEnabled = resultedString.isEmpty == false
    return true
  }
  
  func textFieldShouldReturn(_: UITextField) -> Bool {
    self.perform(#selector(handleContinueTapped), with: nil, afterDelay: 0.1)
    return true
  }
  
  func textFieldDidBeginEditing(_ textField: UITextField) {
    self.textFieldActive = textField
  }
}
