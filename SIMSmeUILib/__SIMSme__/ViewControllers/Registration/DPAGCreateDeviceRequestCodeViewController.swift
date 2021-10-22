//
//  DPAGCreateDeviceRequestCodeViewController.swift
// ginlo
//
//  Created by RBU on 23.11.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGCreateDeviceRequestCodeViewController: DPAGViewControllerWithKeyboard {
    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var stackViewAll: UIStackView!
    @IBOutlet private var labelDescription: UILabel! {
        didSet {
            self.labelDescription.text = DPAGLocalizedString("registration.createDevice.description")
            self.labelDescription.font = UIFont.kFontSubheadline
            self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDescription.numberOfLines = 0
        }
    }

    @IBOutlet private var viewDataSelection: DPAGAccountIDSelectorView! {
        didSet {
            self.viewDataSelection.delegate = self
        }
    }

    @IBOutlet private var labelDeviceName: UILabel! {
        didSet {
            self.labelDeviceName.text = DPAGLocalizedString("registration.createDevice.labelDeviceName")
            self.labelDeviceName.configureLabelForTextField()
        }
    }

    @IBOutlet private var textFieldDeviceName: DPAGTextField! {
        didSet {
            self.textFieldDeviceName.accessibilityIdentifier = "textFieldDeviceName"
            self.textFieldDeviceName.configureDefault()
            self.textFieldDeviceName.delegate = self
            self.textFieldDeviceName.keyboardType = .default
            self.textFieldDeviceName.attributedPlaceholder = NSAttributedString(string: UIDevice.current.name, attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        }
    }
    
    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.textFieldDeviceName.attributedPlaceholder = NSAttributedString(string: UIDevice.current.name, attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.accessibilityIdentifier = "buttonContinue"
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("res.continue"), for: .normal)
            self.viewButtonNext.button.addTarget(self, action: #selector(handleContinueTapped), for: .touchUpInside)
            self.viewButtonNext.isEnabled = false
        }
    }

    private var textFieldActive: UITextField?

    private var tapGrViewDataSelection: UITapGestureRecognizer?
    private var tapGrViewCountry: UITapGestureRecognizer?

    private var accountPhoneString: String?
    private var password: String?
    private var enabledPassword = false

    init(password: String, enabled: Bool) {
        self.password = password
        self.enabledPassword = enabled

        super.init(nibName: "DPAGCreateDeviceRequestCodeViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.navigationItem.title = DPAGLocalizedString("registration.createDevice.title")

        self.addGestureRecognizers()

        self.viewDataSelection.updateDataSelection(index: .emailAddress, withStack: true)
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        DPAGApplicationFacade.accountManager.resetDatabase()
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
        self.textFieldDeviceName.resignFirstResponder()

        self.textFieldActive = nil

        return super.resignFirstResponder()
    }

    @objc
    private func handleContinueTapped() {
        self.resignFirstResponder()

        switch self.viewDataSelection.preferredDataSelectionIndex {
        case .phoneNum:

            guard let accountData = self.viewDataSelection.textFieldPhone.text, accountData.isEmpty == false else {
                self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "registration.subline.phone_empty", okActionHandler: { [weak self] _ in
                    self?.viewDataSelection.textFieldPhone.becomeFirstResponder()
                }))
                return
            }

            let phoneNumber = DPAGCountryCodes.sharedInstance.normalizePhoneNumber(accountData, countryCodeAccount: nil, useCountryCode: self.viewDataSelection.labelCountryCodeValue.text)

            let countryCodeCount: Int = (self.viewDataSelection.labelCountryCodeValue.text?.count ?? 0)

            if (phoneNumber.count - countryCodeCount) < 6 {
                self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "registration.subline.phone_empty", okActionHandler: { [weak self] _ in
                    self?.viewDataSelection.textFieldPhone.becomeFirstResponder()
                }))
                return
            }

            self.createDevice(searchData: phoneNumber, searchMode: .phone)

        case .emailAddress:

            guard let accountData = self.viewDataSelection.textFieldEmail.text?.lowercased(), accountData.isEmpty == false else {
                self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "registration.subline.email_empty", okActionHandler: { [weak self] _ in
                    self?.viewDataSelection.textFieldEmail.becomeFirstResponder()
                }))
                return
            }

            self.createDevice(searchData: accountData, searchMode: .mail)

        case .simsmeID:

            guard let accountData = self.viewDataSelection.textFieldAccountID.text, accountData.isEmpty == false else {
                self.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "registration.subline.accountID_empty", okActionHandler: { [weak self] _ in
                    self?.viewDataSelection.textFieldAccountID.becomeFirstResponder()
                }))
                return
            }

            self.createDevice(searchData: accountData, searchMode: .accountID)
        }
    }

    private func createDevice(searchData: String, searchMode: DPAGCouplingSearchMode) {
        if let password = self.password {
            let deviceNameInput = self.textFieldDeviceName.text ?? ""
            let deviceName = deviceNameInput.isEmpty ? UIDevice.current.name : deviceNameInput

            DPAGApplicationFacade.couplingWorker.setPasswordOptions(password: password, enabled: self.enabledPassword)

            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in

                do {
                    try DPAGApplicationFacade.couplingWorker.selectExistingAccount(data: searchData, searchMode: searchMode)

                    DPAGApplicationFacade.couplingWorker.deviceName = deviceName

                    if let accountGuid = DPAGApplicationFacade.couplingWorker.getCouplingAccountGuid() {
                        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                            self?.navigationController?.pushViewController(DPAGApplicationFacadeUIRegistration.createDeviceConfirmCodeVC(accountGuid: accountGuid), animated: true)
                        }
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

extension DPAGCreateDeviceRequestCodeViewController: DPAGAccountIDSelectorViewDelegate {
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

extension DPAGCreateDeviceRequestCodeViewController: UITextFieldDelegate {
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

    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.textFieldActive = textField
    }

    func textFieldShouldReturn(_: UITextField) -> Bool {
        self.handleContinueTapped()
        return true
    }
}
