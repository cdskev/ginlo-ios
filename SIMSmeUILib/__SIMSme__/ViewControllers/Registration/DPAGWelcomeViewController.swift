//
//  DPAGWelcomeViewController.swift
//  SIMSme
//
//  Created by RBU on 23/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import Contacts
import MobileCoreServices
import Photos
import SIMSmeCore
import UIKit

struct RequestAccountManagementCompletions {
    let completionAccepted: () -> Void
    let completionRequired: () -> Void
    let completionDeclined: () -> Void
    let completionError: () -> Void
}

class DPAGWelcomeViewController: DPAGViewControllerWithKeyboard, DPAGWelcomeViewControllerProtocol {
    typealias Names = (firstName: String?, lastName: String?)

    private static let MAXLENGTH_NICK_NAME = 30

    private let mandantId = DPAGApplicationFacade.preferences.mandantIdent ?? DPAGMandant.IDENT_DEFAULT

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var headlineLabel: UILabel? {
        didSet {
            self.headlineLabel?.font = UIFont.kFontHeadline
            self.headlineLabel?.textColor = DPAGColorProvider.shared[.labelText]
            self.headlineLabel?.numberOfLines = 0
            self.headlineLabel?.text = DPAGLocalizedString("registration.headline.completeYourProfile")
        }
    }

    @IBOutlet private var profilePictureView: UIImageView! {
        didSet {
            self.profilePictureView.accessibilityIdentifier = "profilePictureView"
            self.profilePictureView.image = DPAGImageProvider.shared[.kImagePlaceholderSingle]
            self.profilePictureView.layer.cornerRadius = self.profilePictureView.frame.size.width / 2
            self.profilePictureView.layer.masksToBounds = true
        }
    }

    @IBOutlet private var profileInputLabel: UILabel! {
        didSet {
            self.profileInputLabel.configureLabelForTextField()
            self.profileInputLabel.text = DPAGLocalizedString("registration.label.profileInput")
        }
    }

    @IBOutlet private var textFieldProfilName: UITextField! {
        didSet {
            self.textFieldProfilName.accessibilityIdentifier = "textFieldProfilName"
            self.textFieldProfilName.configureDefault()

            self.textFieldProfilName.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("registration.input.profileNamePlaceHolder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            self.textFieldProfilName.delegate = self
            self.textFieldProfilName.autocapitalizationType = UITextAutocapitalizationType.sentences
            self.textFieldProfilName.accessibilityLabel = DPAGLocalizedString("registration.label.profileInput")
            self.textFieldProfilName.enablesReturnKeyAutomatically = true
        }
    }

    @IBOutlet private var stackViewPhoneNumber: UIStackView!
    @IBOutlet private var phoneNumberLabel: UILabel! {
        didSet {
            self.phoneNumberLabel.configureLabelForTextField()
            self.phoneNumberLabel.text = DPAGLocalizedString("registration.label.phoneInput")
        }
    }

    @IBOutlet private var phoneNumberValue: UILabel! {
        didSet {
            self.phoneNumberValue.font = UIFont.kFontCallout
            self.phoneNumberValue.textColor = DPAGColorProvider.shared[.labelText]
            self.phoneNumberValue.text = self.phoneNumber
        }
    }

    @IBOutlet private var stackViewEMailAddress: UIStackView!
    @IBOutlet private var eMailAddressLabel: UILabel! {
        didSet {
            self.eMailAddressLabel.configureLabelForTextField()
            self.eMailAddressLabel.text = DPAGLocalizedString("registration.label.emailAddressInput")
        }
    }

    @IBOutlet private var eMailAddressValue: UILabel! {
        didSet {
            self.eMailAddressValue.font = UIFont.kFontCallout
            self.eMailAddressValue.textColor = DPAGColorProvider.shared[.labelText]
            self.eMailAddressValue.text = self.eMailAddress
        }
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.accessibilityIdentifier = "buttonNext"
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("res.continue"), for: .normal)
            self.viewButtonNext.button.addTarget(self, action: #selector(handleContinueTapped), for: .touchUpInside)
            self.viewButtonNext.isEnabled = false
        }
    }

    @IBOutlet private var profilePictureButton: UIButton! {
        didSet {
            self.profilePictureButton.accessibilityIdentifier = "profilePictureButton"
            self.profilePictureButton.addTarget(self, action: #selector(handlePickPictureButtonTapped), for: .touchUpInside)
            self.profilePictureButton.layer.cornerRadius = self.profilePictureButton.frame.size.width / 2
            self.profilePictureButton.layer.masksToBounds = true
            self.profilePictureButton.backgroundColor = DPAGColorProvider.shared[.imageSelectorBackground]
            self.profilePictureButton.setImage(DPAGImageProvider.shared[.kImageAddPhoto], for: .normal)
            self.profilePictureButton.tintColor = DPAGColorProvider.shared[.imageSelectorTint]
        }
    }

    @IBOutlet private var stackViewAccountID: UIStackView!
    @IBOutlet private var labelAccountIDLabel: UILabel! {
        didSet {
            self.labelAccountIDLabel.text = DPAGLocalizedString("contacts.details.labelAccountID")
            self.labelAccountIDLabel.configureLabelForTextField()
        }
    }

    @IBOutlet private var labelAccountID: UILabel! {
        didSet {
            self.labelAccountID.textColor = DPAGColorProvider.shared[.accountID]
            self.labelAccountID.font = UIFont.kFontCalloutBold
            self.labelAccountID.text = self.accountID
        }
    }

    @IBOutlet private var labelAccountIDDesc: UILabel! {
        didSet {
            self.labelAccountIDDesc.font = UIFont.kFontBadge
            self.labelAccountIDDesc.textColor = DPAGColorProvider.shared.kColorAccentMandant[mandantId]
            self.labelAccountIDDesc.text = DPAGMandant.default.label
        }
    }

    @IBOutlet private var viewAccountIDDesc: UIView! {
        didSet {
            self.viewAccountIDDesc.backgroundColor = DPAGColorProvider.shared.kColorAccentMandantContrast[mandantId]
            self.viewAccountIDDesc.layer.cornerRadius = 9
            self.viewAccountIDDesc.layer.masksToBounds = true
        }
    }

    @IBOutlet private var imageViewAccountID: UIImageView! {
        didSet {
            self.imageViewAccountID.image = DPAGImageProvider.shared[.kImageFingerprintSmall]
            self.imageViewAccountID.tintColor = DPAGColorProvider.shared[.accountID]
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

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.headlineLabel?.textColor = DPAGColorProvider.shared[.labelText]
                self.textFieldProfilName.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("registration.input.profileNamePlaceHolder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
                self.phoneNumberValue.textColor = DPAGColorProvider.shared[.labelText]
                self.eMailAddressValue.textColor = DPAGColorProvider.shared[.labelText]
                self.profilePictureButton.backgroundColor = DPAGColorProvider.shared[.imageSelectorBackground]
                self.profilePictureButton.tintColor = DPAGColorProvider.shared[.imageSelectorTint]
                self.labelAccountID.textColor = DPAGColorProvider.shared[.accountID]
                self.labelAccountIDDesc.textColor = DPAGColorProvider.shared.kColorAccentMandant[mandantId]
                self.viewAccountIDDesc.backgroundColor = DPAGColorProvider.shared.kColorAccentMandantContrast[mandantId]
                self.imageViewAccountID.tintColor = DPAGColorProvider.shared[.accountID]
                self.labelFirstName.textColor = DPAGColorProvider.shared[.labelText]
                self.textFieldFirstName.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldFirstName.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
                self.labelLastName.textColor = DPAGColorProvider.shared[.labelText]
                self.textFieldLastName.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldLastName.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    private var profileImage: UIImage?

    var accountGuid: String
    private var accountID: String
    private var phoneNumber: String?
    private var eMailAddress: String?
    private var eMailDomain: String?
    private var accountImage: String?
    private var checkUsage = false
    var testLicenseAvailable: Bool = false

    private var syncHelper: DPAGSynchronizationHelperAddressbook?

    init(account accountGuid: String, accountID: String, phoneNumber: String?, emailAddress: String?, emailDomain: String?, checkUsage: Bool) {
        self.accountGuid = accountGuid
        self.accountID = accountID
        self.phoneNumber = phoneNumber
        self.eMailAddress = emailAddress
        self.eMailDomain = emailDomain
        self.checkUsage = checkUsage

        super.init(nibName: "DPAGWelcomeViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureGui()
    }

    private func configureGui() {
        self.navigationItem.hidesBackButton = true

        self.title = DPAGLocalizedString("registration.profile.title")

        self.stackViewPhoneNumber.isHidden = self.phoneNumber == nil
        self.stackViewEMailAddress.isHidden = self.eMailAddress == nil
        self.stackViewFirstName.isHidden = self.eMailDomain == nil || DPAGApplicationFacade.preferences.isCompanyManagedState
        self.stackViewLastName.isHidden = self.eMailDomain == nil || DPAGApplicationFacade.preferences.isCompanyManagedState
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if DPAGApplicationFacade.preferences.didShowProfileInfo == false {
            self.present(DPAGApplicationFacadeUIBase.navVC(rootViewController: DPAGApplicationFacadeUIRegistration.showIdentityVC(accountID: self.accountID)), animated: false, completion: nil)

            return
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        (self.navigationController?.viewControllers.first(where: { $0 is DPAGRequestAccountViewControllerProtocol }) as? DPAGRequestAccountViewControllerProtocol)?.resetPassword()
        if self.presentedViewController == nil, self.checkUsage, DPAGApplicationFacade.preferences.isBaMandant {
            self.checkUsage = false
            self.doCheckUsage(syncDirectoriesCompletion: self.syncDirectories)
        } else {
            self.textFieldProfilName.becomeFirstResponder()
        }
    }

    private func getNames() -> Names {
        var firstName = self.textFieldFirstName.text
        var lastName = self.textFieldLastName.text
        if DPAGApplicationFacade.preferences.isCompanyManagedState {
            let contact = DPAGApplicationFacade.cache.ownContact()
            firstName = contact?.firstName
            lastName = contact?.lastName
        }
        return (firstName, lastName)
    }

    @objc
    private func handleContinueTapped() {
        self.resignFirstResponder()
        guard let compactProfileName = self.textFieldProfilName.text?.replacingOccurrences(of: " ", with: "") else {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "registration.validation.profileNameIsNotValid"))
            return
        }
        if compactProfileName.isEmpty {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "registration.validation.profileNameIsNotValid"))
            return
        }
        guard let profileName = self.textFieldProfilName.text else { return }
        let names = self.getNames()
        DPAGApplicationFacade.accountManager.initiate(nickName: profileName, firstName: names.firstName, lastName: names.lastName)
        let status = DPAGApplicationFacade.statusWorker.latestStatus()
        let accountImage = self.accountImage
        self.performBlockInBackground {
            DPAGApplicationFacade.preferences.didAskForPushPreview = true
            DPAGNotificationWorker.setBackgroundPushNotificationEnabled(true) { _, _, errorMessage in
                if errorMessage == nil {
                    DPAGApplicationFacade.preferences.backgroundAccessTokenSyncEnabled = true
                    DPAGNotificationWorker.setPreviewPushNotificationEnabled(true) { _, _, errorMessage in
                        if errorMessage == nil {
                            DPAGApplicationFacade.preferences.previewPushNotification = true
                        }
                    }
                }
            }
            DPAGApplicationFacade.profileWorker.setPublicOnlineState(enabled: true, withResponse: nil)
            DPAGSendInternalMessageWorker.broadcastProfilUpdate(nickname: profileName, status: status, image: accountImage, oooState: nil, oooStatusText: nil, oooStatusValid: nil, completion: nil)
            try? DPAGApplicationFacade.devicesWorker.createShareExtensionDevice(withResponse: nil)
        }
        let block = { [weak self] in
            if AppConfig.buildConfigurationMode == .TEST {
                DPAGApplicationFacade.preferences.isInAppNotificationEnabled = false
            } else {
                DPAGApplicationFacade.preferences.isInAppNotificationEnabled = true
            }
            let blockCompleted = { [weak self] in
                NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_COMPLETE_LOGIN, object: nil)
                self?.dismiss(animated: true, completion: nil)
            }
            if self?.eMailAddress != nil {
                self?.syncHelper = DPAGSynchronizationHelperAddressbook()
                self?.syncHelper?.syncDomainAddressbook(completion: { [weak self] in
                    // keeping instance alive until work is finished
                    self?.syncHelper = nil
                    blockCompleted()
                })
            } else {
                blockCompleted()
            }
        }
        let companyManagedState = DPAGApplicationFacade.cache.account?.companyManagedState ?? .unknown
        switch companyManagedState {
            case .accepted, .acceptedEmailRequired, .acceptedPhoneRequired, .acceptedEmailFailed, .acceptedPhoneFailed, .acceptedPendingValidation:
                if DPAGApplicationFacade.cache.account?.isCompanyUserRestricted ?? false {
                    block()
                    return
                }
            case .accountDeleted, .declined, .requested, .unknown:
                break
        }

        let blockUpdate = {
            DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                self?.syncHelper = DPAGSynchronizationHelperAddressbook()
                self?.syncHelper?.syncPrivateAddressbook(completion: { [weak self] in
                    self?.syncHelper = nil
                    block()
                })
            }
        }
        let actionCancel = UIAlertAction(titleIdentifier: "alert.welcome.updateLocalContacts.buttonCancel", style: .cancel, handler: { _ in
            block()
        })
        let actionOK = UIAlertAction(titleIdentifier: "alert.welcome.updateLocalContacts.buttonOK", style: .default, handler: { _ in
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
                switch CNContactStore.authorizationStatus(for: .contacts) {
                    case .authorized:
                        blockUpdate()
                    case .denied, .restricted:
                        break
                    case .notDetermined:
                        self?.performBlockOnMainThread {
                            CNContactStore().requestAccess(for: .contacts, completionHandler: { granted, error in
                                if granted, error == nil {
                                    blockUpdate()
                                } else {
                                    DPAGProgressHUD.sharedInstance.hide(true) {
                                        block()
                                    }
                                }
                            })
                        }
                    @unknown default:
                        DPAGLog("Switch with unknown value: \(CNContactStore.authorizationStatus(for: .contacts).rawValue)", level: .warning)
                }
            }
        })
        self.presentAlert(alertConfig: AlertConfig(messageIdentifier: "alert.welcome.updateLocalContacts.message", cancelButtonAction: actionCancel, otherButtonActions: [actionOK]))
    }

    @objc
    private func handlePickPictureButtonTapped() {
        PictureButtonHandler.handlePickPictureButtonTapped(viewControllerWithImagePicker: self)
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        self.textFieldProfilName.resignFirstResponder()
        self.textFieldFirstName.resignFirstResponder()
        self.textFieldLastName.resignFirstResponder()

        return super.resignFirstResponder()
    }

    @objc
    private func handleProfileInputDoneTapped() {
        self.resignFirstResponder()
    }

    // MARK: - UIKeyboard handling

    override func handleViewTapped(_: Any?) {
        self.resignFirstResponder()
    }

    override func handleKeyboardWillShow(_ aNotification: Notification) {
        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavCheck], action: #selector(handleProfileInputDoneTapped), accessibilityLabelIdentifier: "navigation.done")

        super.handleKeyboardWillShow(aNotification, scrollView: self.scrollView, viewVisible: self.textFieldProfilName, viewButtonPrimary: self.viewButtonNext)
    }

    override func handleKeyboardWillHide(_ aNotification: Notification) {
        self.navigationItem.setRightBarButton(nil, animated: true)

        super.handleKeyboardWillHide(aNotification, scrollView: self.scrollView, viewButtonPrimary: self.viewButtonNext)
    }
}

// MARK: - UIImagePickerController delegate protocol

extension DPAGWelcomeViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let profileImage = UIImagePickerController.profileImage(withPickerInfo: info) {
            self.profileImage = profileImage
            self.profilePictureView.image = profileImage

            self.performBlockInBackground { [weak self] in

                if let strongSelf = self, let profileImage = strongSelf.profileImage {
                    strongSelf.accountImage = DPAGApplicationFacade.contactsWorker.saveImage(profileImage, forContact: strongSelf.accountGuid)
                }
            }
        }

        picker.dismiss(animated: true, completion: { [weak self] in

            if let strongSelf = self {
                strongSelf.view.bringSubviewToFront(strongSelf.profilePictureButton)
            }
        })
    }
}

// MARK: - UITextFieldDelegate

extension DPAGWelcomeViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == self.textFieldProfilName {
            if self.stackViewFirstName.isHidden == false {
                self.textFieldFirstName.becomeFirstResponder()
            } else if self.stackViewLastName.isHidden == false {
                self.textFieldLastName.becomeFirstResponder()
            } else if self.viewButtonNext.isEnabled {
                self.perform(#selector(handleProfileInputDoneTapped), with: nil, afterDelay: 0.1)
            } else {
                textField.resignFirstResponder()
            }
        } else if textField == self.textFieldFirstName {
            if self.stackViewLastName.isHidden == false {
                self.textFieldLastName.becomeFirstResponder()
            } else if self.viewButtonNext.isEnabled {
                self.perform(#selector(handleProfileInputDoneTapped), with: nil, afterDelay: 0.1)
            } else {
                self.textFieldProfilName.becomeFirstResponder()
            }
        } else if textField == self.textFieldLastName {
            if self.viewButtonNext.isEnabled {
                self.perform(#selector(handleProfileInputDoneTapped), with: nil, afterDelay: 0.1)
            } else {
                self.textFieldProfilName.becomeFirstResponder()
            }
        }
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let currentText = (textField.text as NSString?) else { return true }
        var retVal = true
        let resultedString = currentText.replacingCharacters(in: range, with: string)
        var resultedStringNew: String
        if textField == self.textFieldProfilName, resultedString.count >= DPAGWelcomeViewController.MAXLENGTH_NICK_NAME {
            resultedStringNew = String(resultedString[..<resultedString.index(resultedString.startIndex, offsetBy: DPAGWelcomeViewController.MAXLENGTH_NICK_NAME)])
            textField.text = resultedStringNew
            retVal = false
        }
        resultedStringNew = resultedString.trimmingCharacters(in: .whitespaces)
        var enabled = resultedStringNew.isEmpty == false
        if textField == self.textFieldProfilName {
            if self.stackViewFirstName.isHidden == false && enabled {
                enabled = (self.textFieldFirstName.text?.isEmpty ?? true) == false
            }
            if self.stackViewFirstName.isHidden == false, enabled {
                enabled = (self.textFieldLastName.text?.isEmpty ?? true) == false
            }
        } else if textField == self.textFieldFirstName && enabled{
             enabled = (self.textFieldProfilName.text?.isEmpty ?? true) == false
            if enabled {
                enabled = (self.textFieldLastName.text?.isEmpty ?? true) == false
            }
        } else if textField == self.textFieldLastName && enabled {
            enabled = (self.textFieldProfilName.text?.isEmpty ?? true) == false
            if enabled {
                enabled = (self.textFieldFirstName.text?.isEmpty ?? true) == false
            }
        }
        self.viewButtonNext.isEnabled = enabled
        if textField == self.textFieldProfilName, resultedStringNew.isEmpty == false, self.profileImage == nil {
            let letters = DPAGUIImageHelper.lettersForPlaceholder(name: resultedStringNew)
            let color = DPAGHelperEx.color(forPlaceholderLetters: letters)
            if let image = DPAGUIImageHelper.imageForPlaceholder(color: color, letters: letters, imageType: .profile) {
                self.profilePictureView.image = image
            }
        }
        return retVal
    }
}

extension DPAGWelcomeViewController: DPAGRegistrationCompletedCheck {
    var completionRegistrationCheck: DPAGCompletion? {
        { [weak self] in

            guard let strongSelf = self else {
                return
            }

            strongSelf.textFieldProfilName.becomeFirstResponder()

            strongSelf.stackViewFirstName.isHidden = strongSelf.stackViewFirstName.isHidden || DPAGApplicationFacade.preferences.isCompanyManagedState
            strongSelf.stackViewLastName.isHidden = strongSelf.stackViewLastName.isHidden || DPAGApplicationFacade.preferences.isCompanyManagedState
        }
    }

    private func syncDirectories(completion: @escaping () -> Void) {
        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

            self?.syncHelper = DPAGSynchronizationHelperAddressbook()

            self?.syncHelper?.syncCompanyAddressbook(completion: { [weak self] in

                // keeping instance alive until work is finished
                self?.syncHelper = nil
                completion()
            })
        }
    }
}

protocol DPAGRegistrationCompletedCheck: AnyObject {
    var testLicenseAvailable: Bool { get set }

    var completionRegistrationCheck: DPAGCompletion? { get }

    func doCheckUsage(syncDirectoriesCompletion: @escaping (@escaping () -> Void) -> Void)

    func showErrorAlertCheck(alertConfig: UIViewController.AlertConfigError)

    @discardableResult
    func presentAlert(alertConfig: UIViewController.AlertConfig) -> UIAlertController

    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Swift.Void)?)
}

extension DPAGRegistrationCompletedCheck {
    func doCheckUsage(syncDirectoriesCompletion: @escaping (@escaping () -> Void) -> Void) {
        let blockPurchase = {
            _ = DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                DPAGPurchaseWorker.getPurchasedProductsWithResponse { [weak self] responseObject, _, errorMessage in

                    if self != nil {
                        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

                            if let strongSelf = self {
                                if let errorMessage = errorMessage {
                                    strongSelf.showErrorAlertCheck(alertConfig: UIViewController.AlertConfigError(messageIdentifier: errorMessage))
                                } else if let responseArray = responseObject as? [[String: Any]] {
                                    if responseArray.count == 0 {
                                        if let vc = strongSelf.testLicenseAvailable ? DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagTestLicenseViewController) : DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagLicenseInitViewController) {
                                            let nvc = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)

                                            strongSelf.present(nvc, animated: true, completion: nil)
                                        }
                                    } else if let responseDict = responseArray.first, let ident = responseDict["ident"] as? String, ident == "usage" {
                                        if let valid = responseDict["valid"] as? String, let dateValid = DPAGFormatter.date.date(from: valid), dateValid.isEarlierThan(Date()) {
                                            if let vc: UIViewController = strongSelf.testLicenseAvailable ? DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagTestLicenseViewController) : DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagLicenseInitViewController) {
                                                let nvc = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)

                                                strongSelf.present(nvc, animated: true, completion: nil)
                                            }
                                        } else {
                                            strongSelf.completionRegistrationCheck?()
                                        }
                                    } else {
                                        strongSelf.showErrorAlertCheck(alertConfig: UIViewController.AlertConfigError(messageIdentifier: "Invalid response"))
                                    }
                                } else {
                                    strongSelf.showErrorAlertCheck(alertConfig: UIViewController.AlertConfigError(messageIdentifier: "Invalid response"))
                                }
                            }
                        }
                    }
                }
            }
        }

        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in

            let responseBlock: (String?, String?, String?, Bool, DPAGAccountCompanyManagedState) -> Void = { [weak self] _, errorMessage, companyName, testLicenseAvailable, accountStateManaged in

                if errorMessage != nil {
                    DPAGProgressHUD.sharedInstance.hide(false, completion: blockPurchase)
                } else {
                    self?.testLicenseAvailable = testLicenseAvailable

                    switch accountStateManaged {
                    case .requested:

                        DispatchQueue.main.async { [weak self] in

                            self?.requestAccountManagement(forCompany: companyName, completions: RequestAccountManagementCompletions(completionAccepted: {
                                do {
                                    try DPAGApplicationFacade.accountManager.ensureCompanyRecoveryPassword()
                                } catch {
                                    DPAGLog(error)
                                }
                                syncDirectoriesCompletion(blockPurchase)
                                }, completionRequired: {
                                    do {
                                        try DPAGApplicationFacade.accountManager.ensureCompanyRecoveryPassword()
                                    } catch {
                                        DPAGLog(error)
                                    }
                                    blockPurchase()
                            }, completionDeclined: blockPurchase, completionError: blockPurchase))
                        }

                    case .accepted:
                        do {
                            try DPAGApplicationFacade.accountManager.ensureCompanyRecoveryPassword()
                        } catch {
                            DPAGLog(error)
                        }
                        DPAGApplicationFacade.preferences.isCompanyManagedState = true
                        DPAGProgressHUD.sharedInstance.hide(false) {
                            syncDirectoriesCompletion(blockPurchase)
                        }

                    case .acceptedEmailRequired:

                        DPAGApplicationFacade.preferences.isCompanyManagedState = true
                        DPAGProgressHUD.sharedInstance.hide(false, completion: {
                            if let vc = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitEMailController) {
                                (vc as? DPAGViewControllerWithCompletion)?.completion = {
                                    do {
                                        try DPAGApplicationFacade.accountManager.ensureCompanyRecoveryPassword()
                                    } catch {
                                        DPAGLog(error)
                                    }
                                    blockPurchase()
                                }

                                let nextVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)

                                AppConfig.appWindow()??.rootViewController?.present(nextVC, animated: true, completion: nil)
                            }
                        })

                    case .acceptedEmailFailed:

                        DPAGApplicationFacade.preferences.isCompanyManagedState = true
                        DPAGProgressHUD.sharedInstance.hide(false, completion: {
                            if let vc = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitEMailController) {
                                (vc as? DPAGCompanyProfilConfirmEMailControllerSkipDelegate)?.skipToEmailValidation = true

                                (vc as? DPAGViewControllerWithCompletion)?.completion = {
                                    do {
                                        try DPAGApplicationFacade.accountManager.ensureCompanyRecoveryPassword()
                                    } catch {
                                        DPAGLog(error)
                                    }
                                    blockPurchase()
                                }

                                let nextVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)

                                AppConfig.appWindow()??.rootViewController?.present(nextVC, animated: true, completion: nil)
                            }
                        })

                    case .acceptedPhoneRequired:

                        DPAGApplicationFacade.preferences.isCompanyManagedState = true
                        DPAGProgressHUD.sharedInstance.hide(false, completion: {
                            if let vc = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitPhoneNumberController) {
                                (vc as? DPAGViewControllerWithCompletion)?.completion = {
                                    do {
                                        try DPAGApplicationFacade.accountManager.ensureCompanyRecoveryPassword()
                                    } catch {
                                        DPAGLog(error)
                                    }
                                    blockPurchase()
                                }

                                let nextVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)

                                AppConfig.appWindow()??.rootViewController?.present(nextVC, animated: true, completion: nil)
                            }
                        })

                    case .acceptedPhoneFailed:

                        DPAGApplicationFacade.preferences.isCompanyManagedState = true
                        DPAGProgressHUD.sharedInstance.hide(false, completion: {
                            if let vc = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitPhoneNumberController) {
                                (vc as? DPAGCompanyProfilConfirmPhoneNumberControllerSkipDelegate)?.skipToPhoneNumberValidation = true

                                (vc as? DPAGViewControllerWithCompletion)?.completion = {
                                    do {
                                        try DPAGApplicationFacade.accountManager.ensureCompanyRecoveryPassword()
                                    } catch {
                                        DPAGLog(error)
                                    }
                                    blockPurchase()
                                }

                                let nextVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)

                                AppConfig.appWindow()??.rootViewController?.present(nextVC, animated: true, completion: nil)
                            }
                        })

                    case .declined, .acceptedPendingValidation, .accountDeleted, .unknown:
                        DPAGProgressHUD.sharedInstance.hide(false, completion: blockPurchase)
                    }
                }
            }

            DPAGApplicationFacade.companyAdressbook.checkCompanyManagement(withResponse: responseBlock)
        }
    }

    private func requestAccountManagement(forCompany companyName: String?, completions: RequestAccountManagementCompletions) {
        if AppConfig.appWindow()??.rootViewController?.presentedViewController == nil {
            DPAGProgressHUD.sharedInstance.hide(false, completion: { [weak self] in

                let message = DPAGLocalizedString("business.alert.accountManagementRequested.message")

                let actionDecline = UIAlertAction(titleIdentifier: "business.alert.accountManagementRequested.btnDecline.title", style: .cancel, handler: { _ in

                    DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in

                        let responseBlock: DPAGServiceResponseBlock = { [weak self] _, _, errorMessage in

                            DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

                                guard self != nil else { return }

                                if let errorMessage = errorMessage {
                                    self?.showErrorAlertCheck(alertConfig: UIViewController.AlertConfigError(messageIdentifier: errorMessage))
                                }
                                completions.completionDeclined()
                            }
                        }

                        DPAGApplicationFacade.companyAdressbook.declineCompanyManagement(withResponse: responseBlock)
                    }
                })

                let actionAccept = UIAlertAction(titleIdentifier: "business.alert.accountManagementRequested.btnAccept.title", style: .default, handler: { _ in

                    DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in

                        let responseBlock: DPAGServiceResponseBlock = { [weak self] _, _, errorMessage in

                            if let errorMessage = errorMessage {
                                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

                                    guard self != nil else { return }
                                    self?.showErrorAlertCheck(alertConfig: UIViewController.AlertConfigError(messageIdentifier: errorMessage))
                                    completions.completionError()
                                }
                                return
                            }

                            guard self != nil else { return }

                            let accountStateManaged: DPAGAccountCompanyManagedState = DPAGApplicationFacade.cache.account?.companyManagedState ?? .unknown

                            switch accountStateManaged {
                            case .accepted, .acceptedEmailFailed, .acceptedPhoneFailed, .acceptedEmailRequired, .acceptedPhoneRequired, .acceptedPendingValidation:
                                DPAGApplicationFacade.preferences.isCompanyManagedState = true

                                DPAGApplicationFacade.profileWorker.getCompanyInfo(withResponse: nil)

                            case .accountDeleted, .declined, .requested, .unknown:
                                break
                            }

                            DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

                                guard self != nil else { return }

                                switch accountStateManaged {
                                case .accepted:
                                    completions.completionAccepted()

                                case .acceptedEmailRequired:
                                    if let vc = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitEMailController) {
                                        (vc as? DPAGViewControllerWithCompletion)?.completion = completions.completionRequired

                                        let nextVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)

                                        AppConfig.appWindow()??.rootViewController?.present(nextVC, animated: true, completion: nil)
                                    }

                                case .acceptedPhoneRequired:

                                    if let vc = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitPhoneNumberController) {
                                        (vc as? DPAGViewControllerWithCompletion)?.completion = completions.completionRequired

                                        let nextVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)

                                        AppConfig.appWindow()??.rootViewController?.present(nextVC, animated: true, completion: nil)
                                    }
                                default:
                                    completions.completionError()
                                }
                            }
                        }

                        DPAGApplicationFacade.companyAdressbook.acceptCompanyManagement(withResponse: responseBlock)
                    }
                })

                self?.presentAlert(alertConfig: UIViewController.AlertConfig(titleIdentifier: "business.alert.accountManagementRequested.title", messageIdentifier: String(format: message, companyName ?? "??"), otherButtonActions: [actionDecline, actionAccept]))
            })
        } else {
            DPAGProgressHUD.sharedInstance.hide(false, completion: completions.completionError)
        }
    }
}
