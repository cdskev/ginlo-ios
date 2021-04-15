//
//  DPAGProfileViewController.swift
//  SIMSme
//
//  Created by RBU on 28/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import MobileCoreServices
import Photos
import SIMSmeCore
import UIKit
import ZXingObjC

class DPAGProfileViewController: DPAGViewControllerWithKeyboard, DPAGProfileViewControllerProtocol {
    private static let MAXLENGTH_NICK_NAME = 30
    private static let MAXLENGTH_STATUS = 140

    private let mandantId = DPAGApplicationFacade.preferences.mandantIdent ?? DPAGMandant.IDENT_DEFAULT

    private weak var textFieldEditing: UITextField?

    var skipToEmailValidationInit = false
    var skipToPhoneNumberValidationInit = false
    var skipToEmailValidation = false
    var skipToPhoneNumberValidation = false

    @IBOutlet private var scrollView: UIScrollView!

    private var profileImageChanged = false
    private var contactEdit: DPAGContactEdit?

    @IBOutlet private var topView: UIView! {
        didSet {
            self.topView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }
    
    @IBOutlet private var viewAlertValidation: UIView! {
        didSet {
            self.viewAlertValidation.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
        }
    }

    @IBOutlet private var labelAlertValidation: UILabel! {
        didSet {
            self.labelAlertValidation.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
            self.labelAlertValidation.font = UIFont.kFontSubheadline
            self.labelAlertValidation.numberOfLines = 0
        }
    }

    @IBOutlet private var buttonAlertValidation: UIButton! {
        didSet {}
    }

    @IBOutlet private var buttonSelectImage: UIButton! {
        didSet {
            self.buttonSelectImage.layer.cornerRadius = self.buttonSelectImage.frame.size.width / 2
            self.buttonSelectImage.layer.masksToBounds = true
            self.buttonSelectImage.accessibilityIdentifier = "buttonSelectImage"
            self.buttonSelectImage.backgroundColor = DPAGColorProvider.shared[.imageSelectorBackground]
            self.buttonSelectImage.setImage(DPAGImageProvider.shared[.kImageAddPhoto], for: .normal)
            self.buttonSelectImage.tintColor = DPAGColorProvider.shared[.imageSelectorTint]
        }
    }

    @IBOutlet private var imageViewProfile: UIImageView! {
        didSet {
            let imageLayer = self.imageViewProfile.layer

            imageLayer.cornerRadius = self.imageViewProfile.frame.size.width / 2
            imageLayer.masksToBounds = true

            self.imageViewProfile.accessibilityIdentifier = "imageViewProfile"
        }
    }

    @IBOutlet private var textFieldNick: UITextField! {
        didSet {
            self.textFieldNick.configureAsTitle()
            self.textFieldNick.delegate = self
            self.textFieldNick.returnKeyType = .done
            self.textFieldNick.enablesReturnKeyAutomatically = true
            self.textFieldNick.autocapitalizationType = .sentences
            self.textFieldNick.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("settings.profile.nickNameLabel"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            self.textFieldNick.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    @IBOutlet private var textFieldStatus: UITextField! {
        didSet {
            self.textFieldStatus.configureDefault()
            self.textFieldStatus.delegate = self
            self.textFieldStatus.returnKeyType = .done
            self.textFieldStatus.enablesReturnKeyAutomatically = true
            self.textFieldStatus.setPaddingRightTo(20)
            self.textFieldStatus.isEnabled = false
            self.textFieldStatus.textAlignment = .center
            self.textFieldStatus.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    @IBOutlet private var imageViewStatusAccessory: UIImageView! {
        didSet {
            self.imageViewStatusAccessory.image = UIImage.drillDownImage
        }
    }

    @IBOutlet private var buttonStatus: UIButton! {
        didSet {}
    }

    @IBOutlet private var stackViewNames: UIStackView! {
        didSet {
            self.stackViewNames.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }
    
    @IBOutlet private var labelFirstName: UILabel! {
        didSet {
            self.labelFirstName.text = DPAGLocalizedString("contacts.details.labelFirstName").uppercased()
            self.labelFirstName.configureLabelForTextField()
            self.labelFirstName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }

    @IBOutlet private var textFieldFirstName: DPAGTextField! {
        didSet {
            self.textFieldFirstName.accessibilityIdentifier = "textFieldFirstName"
            self.textFieldFirstName.configureDefault()
            self.textFieldFirstName.delegate = self
            self.textFieldFirstName.returnKeyType = .done
            self.textFieldFirstName.enablesReturnKeyAutomatically = true
            self.textFieldFirstName.autocapitalizationType = .sentences
            self.textFieldFirstName.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldFirstName.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            self.textFieldFirstName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    @IBOutlet private var imageViewFirstNameLocked: UIImageView! {
        didSet {
            self.imageViewFirstNameLocked.image = DPAGImageProvider.shared[.kImageLockedSmall]
            self.imageViewFirstNameLocked.tintColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelLastName: UILabel! {
        didSet {
            self.labelLastName.text = DPAGLocalizedString("contacts.details.labelLastName").uppercased()
            self.labelLastName.configureLabelForTextField()
            self.labelLastName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }

    @IBOutlet private var textFieldLastName: DPAGTextField! {
        didSet {
            self.textFieldLastName.accessibilityIdentifier = "textFieldLastName"
            self.textFieldLastName.configureDefault()
            self.textFieldLastName.delegate = self
            self.textFieldLastName.returnKeyType = .done
            self.textFieldLastName.enablesReturnKeyAutomatically = true
            self.textFieldLastName.autocapitalizationType = .sentences
            self.textFieldLastName.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldLastName.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            self.textFieldLastName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    @IBOutlet private var imageViewLastNameLocked: UIImageView! {
        didSet {
            self.imageViewLastNameLocked.image = DPAGImageProvider.shared[.kImageLockedSmall]
            self.imageViewLastNameLocked.tintColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var stackViewDepartment: UIStackView! {
        didSet {
            if DPAGApplicationFacade.preferences.isWhiteLabelBuild == false {
                self.stackViewDepartment.isHidden = true
                self.stackViewDepartment.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            }
        }
    }

    @IBOutlet private var labelDepartment: UILabel! {
        didSet {
            self.labelDepartment.text = DPAGLocalizedString("contacts.details.labelDepartment").uppercased()
            self.labelDepartment.configureLabelForTextField()
            self.labelDepartment.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }

    @IBOutlet private var textFieldDepartment: DPAGTextField! {
        didSet {
            self.textFieldDepartment.accessibilityIdentifier = "textFieldDepartment"
            self.textFieldDepartment.configureDefault()
            self.textFieldDepartment.delegate = self
            self.textFieldDepartment.returnKeyType = .done
            self.textFieldDepartment.enablesReturnKeyAutomatically = true
            self.textFieldDepartment.autocapitalizationType = .sentences
            self.textFieldDepartment.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldDepartment.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            self.textFieldDepartment.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    @IBOutlet private var imageViewDepartmentLocked: UIImageView! {
        didSet {
            self.imageViewDepartmentLocked.image = DPAGImageProvider.shared[.kImageLockedSmall]
            self.imageViewDepartmentLocked.tintColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var stackViewPhone: UIStackView! {
        didSet {
            self.stackViewPhone.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }
    
    @IBOutlet private var labelPhoneNumber: UILabel! {
        didSet {
            self.labelPhoneNumber.text = DPAGLocalizedString("contacts.details.labelPhoneNumber").uppercased()
            self.labelPhoneNumber.configureLabelForTextField()
            self.labelPhoneNumber.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }

    @IBOutlet private var labelPhoneNumberValidation: UILabel! {
        didSet {
            self.labelPhoneNumberValidation.textColor = DPAGColorProvider.shared[.labelText]
            self.labelPhoneNumberValidation.font = UIFont.kFontFootnoteBold
            self.labelPhoneNumberValidation.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }

    @IBOutlet private var textFieldPhoneNumber: UITextField! {
        didSet {
            self.textFieldPhoneNumber.accessibilityIdentifier = "textFieldPhoneNumber"
            self.textFieldPhoneNumber.configureDefault()
            self.textFieldPhoneNumber.isEnabled = false
            self.textFieldPhoneNumber.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldPhoneNumber.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            self.textFieldPhoneNumber.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    @IBOutlet private var buttonPhoneNumber: UIButton! {
        didSet {}
    }

    @IBOutlet private var imageViewPhoneNumberLocked: UIImageView! {
        didSet {
            self.imageViewPhoneNumberLocked.image = DPAGImageProvider.shared[.kImageLockedSmall]
            self.imageViewPhoneNumberLocked.tintColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var imageViewPhoneNumberAccessory: UIImageView! {
        didSet {
            self.imageViewPhoneNumberAccessory.image = UIImage.drillDownImage
        }
    }

    @IBOutlet private var stackViewEmail: UIStackView! {
        didSet {
            self.stackViewEmail.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            // MARK: Email-Registration
            self.stackViewEmail.isHidden = DPAGApplicationFacade.preferences.isBaMandant == false
        }
    }

    @IBOutlet private var labelEmail: UILabel! {
        didSet {
            self.labelEmail.text = DPAGLocalizedString("contacts.details.labelEMail").uppercased()
            self.labelEmail.configureLabelForTextField()
            self.labelEmail.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }

    @IBOutlet private var labelEmailValidation: UILabel! {
        didSet {
            self.labelEmailValidation.textColor = DPAGColorProvider.shared[.labelText]
            self.labelEmailValidation.font = UIFont.kFontFootnoteBold
            self.labelEmailValidation.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }

    @IBOutlet private var textFieldEmail: UITextField! {
        didSet {
            self.textFieldEmail.accessibilityIdentifier = "textFieldEMail"
            self.textFieldEmail.configureDefault()
            self.textFieldEmail.isEnabled = false
            self.textFieldEmail.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldEMail.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            self.textFieldEmail.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    @IBOutlet private var buttonEmail: UIButton! {
        didSet {}
    }

    @IBOutlet private var imageViewEmailLocked: UIImageView! {
        didSet {
            self.imageViewEmailLocked.image = DPAGImageProvider.shared[.kImageLockedSmall]
            self.imageViewEmailLocked.tintColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var imageViewEmailAccessory: UIImageView! {
        didSet {
            self.imageViewEmailAccessory.image = UIImage.drillDownImage
        }
    }

    @IBOutlet private var stackViewAccountID: UIStackView! {
        didSet {
            self.stackViewAccountID.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }
    @IBOutlet private var labelAccountIDLabel: UILabel! {
        didSet {
            self.labelAccountIDLabel.text = DPAGLocalizedString("contacts.details.labelAccountID")
            self.labelAccountIDLabel.configureLabelForTextField()
            self.labelAccountIDLabel.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }

    @IBOutlet private var labelAccountID: UILabel! {
        didSet {
            self.labelAccountID.font = UIFont.kFontCalloutBold
            self.labelAccountID.textColor = DPAGColorProvider.shared[.labelLink]
        }
    }

    @IBOutlet private var labelAccountIDDesc: UILabel! {
        didSet {
            self.labelAccountIDDesc.font = UIFont.kFontBadge
            self.labelAccountIDDesc.textColor = DPAGColorProvider.shared.kColorAccentMandant[mandantId]
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

    @IBOutlet private var stackViewQRCode: UIStackView! {
        didSet {
            self.stackViewQRCode.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }
    @IBOutlet private var labelQRDesc: UILabel! {
        didSet {
            self.labelQRDesc.text = DPAGLocalizedString("settings.profile.qr_code_desc")
            self.labelQRDesc.font = UIFont.kFontBody
            self.labelQRDesc.textColor = DPAGColorProvider.shared[.labelText]
            self.labelQRDesc.numberOfLines = 0
        }
    }

    @IBOutlet private var imageViewQRCode: UIImageView! {
        didSet {
            self.imageViewQRCode.backgroundColor = UIColor.clear
        }
    }

    @IBOutlet private var buttonDeleteAccount: UIButton! {
        didSet {
            self.buttonDeleteAccount.accessibilityIdentifier = "deleteAccountButton"
            self.buttonDeleteAccount.setTitle(DPAGLocalizedString("settings.profile.button.deleteAccount"), for: .normal)
            self.buttonDeleteAccount.configureButtonDestructive()
        }
    }

    @IBOutlet private var buttonSave: UIButton! {
        didSet {
            self.buttonSave.configureButton()
            self.buttonSave.setTitle(DPAGLocalizedString("settings.profile.button.saveChanges"), for: .normal)
        }
    }

    @IBOutlet private var viewOooStatusBorder: UIView! {
        didSet {
            if DPAGApplicationFacade.preferences.isBaMandant {
                self.viewOooStatusBorder.layer.cornerRadius = self.viewOooStatusBorder.frame.size.height / 2.0
            } else {
                self.viewOooStatusBorder.isHidden = true
            }
        }
    }

    @IBOutlet private var viewOooStatus: UIView! {
        didSet {
            if DPAGApplicationFacade.preferences.isBaMandant {
                self.viewOooStatus.layer.cornerRadius = self.viewOooStatus.frame.size.height / 2.0
            } else {
                self.viewOooStatus.isHidden = true
            }
        }
    }

    init() {
        super.init(nibName: "DPAGProfileViewController", bundle: Bundle(for: type(of: self)))
        NotificationCenter.default.addObserver(self, selector: #selector(handleConfirmedIdentitiesChanged), name: DPAGStrings.Notification.Account.CONFIRMED_IDENTITIES_CHANGED, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleContactChanged), name: DPAGStrings.Notification.Contact.CHANGED, object: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.Account.CONFIRMED_IDENTITIES_CHANGED, object: nil)
        NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.Contact.CHANGED, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let account = DPAGApplicationFacade.cache.account {
            self.createQrCode(account)
        }
        self.title = DPAGLocalizedString("settings.profile")
        self.navigationItem.rightBarButtonItem = self.editButtonItem
        self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.configureGui()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.skipToEmailValidationInit {
            self.skipToEmailValidationInit = false
            self.handleEmailButton(nil)
        } else if self.skipToPhoneNumberValidationInit {
            self.skipToPhoneNumberValidationInit = false
            self.handlePhoneNumberButton(nil)
        } else if self.skipToEmailValidation {
            self.skipToEmailValidation = false
            self.handleEmailButton(nil)
        } else if self.skipToPhoneNumberValidation {
            self.skipToPhoneNumberValidation = false
            self.handlePhoneNumberButton(nil)
        }
    }

    @IBAction private func handleDeleteAccount(_: Any?) {
        let block = { [weak self] (success: Bool) in
            if success {
                self?.navigationController?.pushViewController(DPAGApplicationFacadeUISettings.deleteProfileVC(showAccountID: true), animated: true)
            }
        }
        DPAGApplicationFacadeUIBase.loginVC.requestPassword(withTouchID: false, completion: block)
    }

    @objc
    private func handleContactChanged(aNotification: Notification) {
        if let contactGuid = aNotification.userInfo?[DPAGStrings.Notification.Contact.CHANGED__USERINFO_KEY__CONTACT_GUID] as? String, contactGuid == DPAGApplicationFacade.cache.account?.guid, self.isEditing == false {
            self.configureGui()
        }
    }

    private func configureGui() {
        guard let contact = self.getContact() else { return }
        self.textFieldNick.text = contact.nickName
        if self.profileImageChanged == false {
            self.imageViewProfile.image = contact.image(for: .profile)
        }
        if contact.hasImage {
            self.buttonSelectImage.accessibilityIdentifier = "settings.profile.title.labelImageOverlay.changeImage"
            self.buttonSelectImage.accessibilityLabel = DPAGLocalizedString("settings.profile.title.labelImageOverlay.changeImage")
        } else {
            self.buttonSelectImage.accessibilityIdentifier = "settings.profile.title.labelImageOverlay.selectImage"
            self.buttonSelectImage.accessibilityLabel = DPAGLocalizedString("settings.profile.title.labelImageOverlay.selectImage")
        }
        self.textFieldStatus.text = DPAGApplicationFacade.statusWorker.latestStatus()
        self.labelAccountID.text = contact.accountID
        self.labelAccountIDDesc.text = DPAGMandant.default.label
        self.configureIdentitiy()
        self.configureEditMode()
        if DPAGApplicationFacade.preferences.isBaMandant {
            if contact.oooStatusState == "ooo" {
                self.viewOooStatus.isHidden = false
                self.viewOooStatusBorder.isHidden = false
                self.viewOooStatus.backgroundColor = DPAGColorProvider.shared[.oooStatusInactive] // INSECURE
            } else {
                self.viewOooStatus.backgroundColor = DPAGColorProvider.shared[.oooStatusActive] // SECURE
                self.viewOooStatus.isHidden = false
                self.viewOooStatusBorder.isHidden = false
            }
        }
    }

    private func configureIdentitiy() {
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) else { return }
        self.textFieldFirstName.text = contact.firstName
        self.textFieldLastName.text = contact.lastName
        self.textFieldDepartment.text = contact.department
        self.viewAlertValidation.isHidden = true
        let companyPhoneNumberStatus = account.companyPhoneNumberStatus
        switch companyPhoneNumberStatus {
            case .none:
                self.labelPhoneNumberValidation.text = nil
                self.textFieldPhoneNumber.text = DPAGApplicationFacade.preferences.validationPhoneNumber ?? contact.phoneNumber
                if DPAGApplicationFacade.preferences.isCompanyManagedState, DPAGApplicationFacade.preferences.validationPhoneNumber != nil {
                    self.viewAlertValidation.isHidden = false
                    self.labelAlertValidation.text = DPAGLocalizedString("settings.profile.phoneNumber_warn_status10.alertMessage")
                    self.labelPhoneNumberValidation.textColor = DPAGColorProvider.shared[.labelValidationUnconfirmed]
                    self.labelPhoneNumberValidation.text = DPAGLocalizedString("settings.profile.phoneNumber_warn_status10")
                }
            case .confirm_FAILED:
                self.labelPhoneNumberValidation.textColor = DPAGColorProvider.shared[.labelText]
                self.labelPhoneNumberValidation.text = DPAGLocalizedString("settings.profile.phoneNumber_warn_status0")
                self.textFieldPhoneNumber.text = DPAGApplicationFacade.preferences.validationPhoneNumber ?? contact.phoneNumber
                if DPAGApplicationFacade.preferences.isCompanyManagedState, DPAGApplicationFacade.preferences.validationPhoneNumber != nil {
                    self.viewAlertValidation.isHidden = false
                    self.labelAlertValidation.text = DPAGLocalizedString("settings.profile.phoneNumber_warn_status10.alertMessage")
                }
            case .wait_CONFIRM:
                self.labelPhoneNumberValidation.textColor = DPAGColorProvider.shared[.labelValidationUnconfirmed]
                self.labelPhoneNumberValidation.text = DPAGLocalizedString("settings.profile.phoneNumber_warn_status10")
                self.textFieldPhoneNumber.text = DPAGApplicationFacade.preferences.validationPhoneNumber ?? contact.phoneNumber
                self.viewAlertValidation.isHidden = false
                self.labelAlertValidation.text = DPAGLocalizedString("settings.profile.phoneNumber_warn_status10.alertMessage")

            case .confirmed:
                self.labelPhoneNumberValidation.textColor = DPAGColorProvider.shared[.labelValidationConfirmed]
                self.labelPhoneNumberValidation.text = DPAGLocalizedString("settings.profile.phoneNumber_warn_status30")
                self.textFieldPhoneNumber.text = contact.phoneNumber
                if DPAGApplicationFacade.preferences.isCompanyManagedState, DPAGApplicationFacade.preferences.validationPhoneNumber != nil {
                    self.viewAlertValidation.isHidden = false
                    self.labelAlertValidation.text = DPAGLocalizedString("settings.profile.phoneNumber_warn_status10.alertMessage")
                }
        }
        if DPAGApplicationFacade.preferences.isCompanyAdressBookEnabled {
            let companyEMailStatus = account.companyEMailAddressStatus
            switch companyEMailStatus {
                case .none:
                    self.labelEmailValidation.text = nil
                    self.textFieldEmail.text = DPAGApplicationFacade.preferences.validationEmailAddress ?? contact.eMailAddress
                    if DPAGApplicationFacade.preferences.isCompanyManagedState, DPAGApplicationFacade.preferences.validationEmailAddress != nil {
                        if self.viewAlertValidation.isHidden {
                            self.viewAlertValidation.isHidden = false
                            self.labelAlertValidation.text = DPAGLocalizedString("settings.profile.email_warn_status10.alertMessage")
                        }
                        self.labelEmailValidation.textColor = DPAGColorProvider.shared[.labelValidationUnconfirmed]
                        self.labelEmailValidation.text = DPAGLocalizedString("settings.profile.email_warn_status10")
                    }
                case .confirm_FAILED:
                    self.labelEmailValidation.textColor = DPAGColorProvider.shared[.labelText]
                    self.labelEmailValidation.text = DPAGLocalizedString("settings.profile.email_warn_status0")
                    self.textFieldEmail.text = DPAGApplicationFacade.preferences.validationEmailAddress ?? contact.eMailAddress
                    if DPAGApplicationFacade.preferences.isCompanyManagedState, DPAGApplicationFacade.preferences.validationEmailAddress != nil, self.viewAlertValidation.isHidden {
                        self.viewAlertValidation.isHidden = false
                        self.labelAlertValidation.text = DPAGLocalizedString("settings.profile.email_warn_status10.alertMessage")
                    }
                case .wait_CONFIRM:
                    self.labelEmailValidation.textColor = DPAGColorProvider.shared[.labelValidationUnconfirmed]
                    self.labelEmailValidation.text = DPAGLocalizedString("settings.profile.email_warn_status10")
                    self.textFieldEmail.text = DPAGApplicationFacade.preferences.validationEmailAddress ?? contact.eMailAddress
                    if self.viewAlertValidation.isHidden {
                        self.viewAlertValidation.isHidden = false
                        self.labelAlertValidation.text = DPAGLocalizedString("settings.profile.email_warn_status10.alertMessage")
                    }
                case .confirmed:
                    self.labelEmailValidation.textColor = DPAGColorProvider.shared[.labelValidationConfirmed]
                    self.labelEmailValidation.text = DPAGLocalizedString("settings.profile.email_warn_status30")
                    self.textFieldEmail.text = contact.eMailAddress
                    if DPAGApplicationFacade.preferences.isCompanyManagedState, DPAGApplicationFacade.preferences.validationEmailAddress != nil {
                        if self.viewAlertValidation.isHidden {
                            self.viewAlertValidation.isHidden = false
                            self.labelAlertValidation.text = DPAGLocalizedString("settings.profile.email_warn_status10.alertMessage")
                        }
                    }
            }
        }
        if DPAGApplicationFacade.preferences.isCompanyManagedState {
            if DPAGApplicationFacade.preferences.validationPhoneNumber == nil {
                self.buttonPhoneNumber.isEnabled = false
                self.imageViewPhoneNumberLocked.isHidden = false
                self.imageViewPhoneNumberAccessory.isHidden = true
            } else {
                self.buttonPhoneNumber.isEnabled = true
                self.imageViewPhoneNumberLocked.isHidden = true
                self.imageViewPhoneNumberAccessory.isHidden = false
            }
            if DPAGApplicationFacade.preferences.validationEmailAddress == nil {
                self.buttonEmail.isEnabled = false
                self.imageViewEmailLocked.isHidden = false
                self.imageViewEmailAccessory.isHidden = true
            } else {
                self.buttonEmail.isEnabled = true
                self.imageViewEmailLocked.isHidden = true
                self.imageViewEmailAccessory.isHidden = false
            }
            self.imageViewFirstNameLocked.isHidden = false
            self.imageViewLastNameLocked.isHidden = false
            self.imageViewDepartmentLocked.isHidden = false
        } else {
            self.imageViewFirstNameLocked.isHidden = true
            self.imageViewLastNameLocked.isHidden = true
            self.imageViewDepartmentLocked.isHidden = true

            self.imageViewEmailLocked.isHidden = true
            self.imageViewPhoneNumberLocked.isHidden = true
        }
    }

    @objc
    private func handleConfirmedIdentitiesChanged() {
        self.performBlockOnMainThread { [weak self] in
            self?.configureIdentitiy()
            self?.configureEditMode()
        }
    }

    private var saveAfterEditing = true

    @objc
    private func cancelEditing() {
        self.saveAfterEditing = false
        self.profileImageChanged = false
        self.setEditing(false, animated: true)
        self.saveAfterEditing = true
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if editing {
            if let account = DPAGApplicationFacade.cache.account {
                self.contactEdit = DPAGContactEdit(guid: account.guid)
            }
            self.configureEditMode()
        } else {
            self.dismissKeyboard(nil)
            if self.saveAfterEditing {
                self.handleSave()
            }
            self.contactEdit = nil
            self.configureGui()
        }
    }

    private func configureEditMode() {
        if self.isEditing {
            self.textFieldNick.isEnabled = true
            self.textFieldNick.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
            if DPAGApplicationFacade.preferences.isCompanyManagedState {
                self.textFieldFirstName.isEnabled = false
                self.textFieldLastName.isEnabled = false
                self.textFieldDepartment.isEnabled = false
            } else {
                self.textFieldFirstName.isEnabled = true
                self.textFieldLastName.isEnabled = true
                self.textFieldDepartment.isEnabled = true
                self.textFieldFirstName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
                self.textFieldLastName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
                self.textFieldDepartment.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
            }
            self.textFieldPhoneNumber.isEnabled = false
            self.textFieldEmail.isEnabled = false
            self.imageViewEmailAccessory.isHidden = self.imageViewEmailLocked.isHidden == false
            self.imageViewPhoneNumberAccessory.isHidden = self.imageViewPhoneNumberLocked.isHidden == false
            self.buttonSelectImage.isHidden = false
            self.buttonSave.isHidden = false
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelEditing))
            
        } else {
            self.textFieldNick.isEnabled = false
            self.textFieldNick.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            self.textFieldFirstName.isEnabled = false
            self.textFieldLastName.isEnabled = false
            self.textFieldDepartment.isEnabled = false
            self.textFieldPhoneNumber.isEnabled = false
            self.textFieldEmail.isEnabled = false
            self.textFieldFirstName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            self.textFieldLastName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            self.textFieldDepartment.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            self.stackViewPhone.isHidden = false
            self.stackViewAccountID.isHidden = false
            self.stackViewQRCode.isHidden = false
            self.imageViewEmailAccessory.isHidden = self.buttonEmail.isEnabled == false
            self.imageViewPhoneNumberAccessory.isHidden = self.buttonPhoneNumber.isEnabled == false
            self.buttonSelectImage.isHidden = true
            self.buttonDeleteAccount.isHidden = false
            self.buttonSave.isHidden = true
            self.navigationItem.leftBarButtonItem = nil
            if DPAGApplicationFacade.preferences.isCompanyAdressBookEnabled {
                self.stackViewEmail.isHidden = false
            } else {
                self.stackViewEmail.isHidden = true
            }
        }
        if DPAGApplicationFacade.preferences.isWhiteLabelBuild == false {
            self.stackViewNames.isHidden = true
            self.stackViewDepartment.isHidden = true
            self.stackViewEmail.isHidden = true
        }
    }

    @IBAction private func handleEmailButton(_: Any?) {
        let companyEMailStatus = DPAGApplicationFacade.cache.account?.companyEMailAddressStatus ?? .none
        switch companyEMailStatus {
            case .none, .confirm_FAILED:
                if let nextVC = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitEMailController) {
                    self.navigationController?.pushViewController(nextVC, animated: true)
                }
            case .wait_CONFIRM:
                if let nextVC = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitEMailController) {
                    (nextVC as? DPAGCompanyProfilConfirmEMailControllerSkipDelegate)?.skipToEmailValidation = DPAGApplicationFacade.preferences.validationEmailAddress != nil

                    self.navigationController?.pushViewController(nextVC, animated: true)
                }
            case .confirmed:
                if let nextVC = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitEMailController) {
                    self.navigationController?.pushViewController(nextVC, animated: true)
                }
        }
    }

    @IBAction private func handlePhoneNumberButton(_: Any?) {
        let companyPhoneNumberStatus = DPAGApplicationFacade.cache.account?.companyPhoneNumberStatus ?? .none
        switch companyPhoneNumberStatus {
            case .none, .confirm_FAILED:
                if let nextVC = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitPhoneNumberController) {
                    self.navigationController?.pushViewController(nextVC, animated: true)
                }
            case .wait_CONFIRM:
                if let nextVC = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitPhoneNumberController) {
                    (nextVC as? DPAGCompanyProfilConfirmPhoneNumberControllerSkipDelegate)?.skipToPhoneNumberValidation = DPAGApplicationFacade.preferences.validationPhoneNumber != nil

                    self.navigationController?.pushViewController(nextVC, animated: true)
                }
            case .confirmed:
                if let nextVC = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitPhoneNumberController) {
                    self.navigationController?.pushViewController(nextVC, animated: true)
                }
        }
    }

    @IBAction private func handleValidateButton(_: Any?) {
        if DPAGApplicationFacade.preferences.validationPhoneNumber != nil {
            self.handlePhoneNumberButton(nil)
        } else if DPAGApplicationFacade.preferences.validationEmailAddress != nil {
            self.handleEmailButton(nil)
        }
    }

    @IBAction private func buttonAccountIdPressed(_: Any?) {
        guard let contact = self.getContact(), let accountId = contact.accountID else { return }
        let sharingHelper = SharingHelper()
        sharingHelper.showSharing(fromViewController: self, items: [accountId], sourceView: labelAccountID)
    }

    override func handleViewTapped(_ sender: Any?) {
        self.dismissKeyboard(sender)
    }

    override func handleKeyboardWillShow(_ notification: Notification) {
        if let textFieldEditing = self.textFieldEditing {
            super.handleKeyboardWillShow(notification, scrollView: self.scrollView, viewVisible: textFieldEditing)
        }
    }

    override func handleKeyboardWillHide(_ notification: Notification) {
        super.handleKeyboardWillHide(notification, scrollView: self.scrollView)
    }

    private func dismissKeyboard(_: Any?) {
        self.textFieldNick.resignFirstResponder()
        self.textFieldFirstName.resignFirstResponder()
        self.textFieldLastName.resignFirstResponder()
        self.textFieldPhoneNumber.resignFirstResponder()
        self.textFieldEmail.resignFirstResponder()
        self.textFieldDepartment.resignFirstResponder()
    }

    private func createQrCode(_ simsaccount: DPAGAccount) {
        do {
            self.imageViewQRCode.image = try self.createQrCode(simsaccount, size: self.imageViewQRCode.frame.size, qrCodeVersion: .v2)
        } catch {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: error.localizedDescription, accessibilityIdentifier: "error_create_qrcode"))
        }
    }

    private func createQrCode(_ account: DPAGAccount, size: CGSize, qrCodeVersion: DPAGQRCodeVersion) throws -> UIImage? {
        if let qrContent = DPAGApplicationFacade.contactsWorker.qrCodeContent(account: account, version: qrCodeVersion) {
            let writer: ZXMultiFormatWriter = ZXMultiFormatWriter()
            let result: ZXBitMatrix = try writer.encode(qrContent, format: kBarcodeFormatQRCode, width: Int32(size.width), height: Int32(size.height))
            if let image = ZXImage(matrix: result).cgimage {
                let retValImage = UIImage(cgImage: image)
                return retValImage
            }
        }
        return nil
    }

    @IBAction private func handleButtonSave() {
        self.setEditing(false, animated: true)
    }

    private func handleSave() {
        self.saveUserNickName()
        self.saveImage()
        self.saveExtended()
    }

    private func saveExtended() {
        if let contactEdit = self.contactEdit {
            DPAGApplicationFacade.contactsWorker.saveContact(contact: contactEdit)
        }
    }

    private func saveUserNickName() {
        guard let compactProfileName = self.textFieldNick.text?.trimmingCharacters(in: .whitespaces), compactProfileName.isEmpty == false else {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "registration.validation.profileNameIsNotValid"))
            return
        }
        guard let contact = self.getContact(), compactProfileName != contact.nickName else { return }
        DPAGApplicationFacade.accountManager.save(nickName: compactProfileName)
        self.performBlockInBackground {
            DPAGSendInternalMessageWorker.broadcastNicknameUpdate(compactProfileName)
        }
        if self.profileImageChanged == false {
            self.imageViewProfile.image = contact.image(for: .profile)
        }
    }

    private func saveImage() {
        guard self.profileImageChanged else { return }
        if let image = self.imageViewProfile.image, let accountGuid = DPAGApplicationFacade.cache.account?.guid, let encoded = DPAGApplicationFacade.contactsWorker.saveImage(image, forContact: accountGuid) {
            DPAGSendInternalMessageWorker.broadcastProfileImage(encoded)
            NotificationCenter.default.post(name: DPAGStrings.Notification.Account.IMAGE_CHANGED, object: nil)
        }
        self.profileImageChanged = false
    }

    private func getContact() -> DPAGContact? {
        DPAGApplicationFacade.cache.ownContact()
    }

    // MARK: - pick picture

    @IBAction private func handlePickPictureButtonTapped(_: Any?) {
        PictureButtonHandler.handlePickPictureButtonTapped(viewControllerWithImagePicker: self)
    }

    @IBAction private func handleStatusDrillDownTapped(_: Any?) {
        if DPAGApplicationFacade.preferences.isBaMandant {
            let nextVC = DPAGApplicationFacadeUISettings.outOfOfficeStatusVC()
            nextVC.delegate = self
            self.present(DPAGApplicationFacadeUIBase.navVC(rootViewController: nextVC), animated: true, completion: nil)
        } else {
            let nextVC = DPAGApplicationFacadeUISettings.statusMessageVC()
            nextVC.delegate = self
            self.present(DPAGApplicationFacadeUIBase.navVC(rootViewController: nextVC), animated: true, completion: nil)
        }
    }
    
    @IBOutlet var labelPhoneNumberView: UIView! {
        didSet {
            self.labelPhoneNumberView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }
    
    @IBOutlet var labelEmailView: UIView! {
        didSet {
            self.labelEmailView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }
    
    @IBOutlet var labelFirstNameView: UIView! {
        didSet {
            self.labelFirstNameView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }
    
    @IBOutlet var labelLastNameView: UIView! {
        didSet {
            self.labelLastNameView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }
    
    @IBOutlet var labelDepartmentView: UIView! {
        didSet {
            self.labelDepartmentView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }
    
    @IBOutlet var labelAccountIDLabelView: UIView! {
        didSet {
            self.labelAccountIDLabelView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }
    
    override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()

        self.labelPhoneNumberView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.labelEmailView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.labelFirstNameView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.labelLastNameView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.labelDepartmentView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.labelAccountIDLabelView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]

        self.labelPhoneNumberValidation.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.labelEmailValidation.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]

        self.labelFirstName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.labelLastName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.labelDepartment.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.labelPhoneNumber.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.labelEmail.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.labelAccountIDLabel.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]

        self.viewAlertValidation.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
        self.buttonSelectImage.backgroundColor = DPAGColorProvider.shared[.imageSelectorBackground]

        self.labelAlertValidation.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
        
        self.buttonSelectImage.tintColor = DPAGColorProvider.shared[.imageSelectorTint]
        self.textFieldNick.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("settings.profile.nickNameLabel"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        self.textFieldFirstName.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldFirstName.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        self.imageViewFirstNameLocked.tintColor = DPAGColorProvider.shared[.labelText]
        self.textFieldLastName.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldLastName.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        self.imageViewLastNameLocked.tintColor = DPAGColorProvider.shared[.labelText]
        self.textFieldDepartment.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldDepartment.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        self.imageViewDepartmentLocked.tintColor = DPAGColorProvider.shared[.labelText]
        self.labelPhoneNumberValidation.textColor = DPAGColorProvider.shared[.labelText]
        self.textFieldPhoneNumber.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldPhoneNumber.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        self.imageViewPhoneNumberLocked.tintColor = DPAGColorProvider.shared[.labelText]
        self.labelEmailValidation.textColor = DPAGColorProvider.shared[.labelText]
        self.textFieldEmail.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldEMail.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
        self.imageViewEmailLocked.tintColor = DPAGColorProvider.shared[.labelText]
        self.labelAccountID.textColor = DPAGColorProvider.shared[.labelLink]
        self.labelAccountIDDesc.textColor = DPAGColorProvider.shared.kColorAccentMandant[mandantId]
        self.viewAccountIDDesc.backgroundColor = DPAGColorProvider.shared.kColorAccentMandantContrast[mandantId]
        self.imageViewAccountID.tintColor = DPAGColorProvider.shared[.accountID]
        self.labelQRDesc.textColor = DPAGColorProvider.shared[.labelText]
        
        self.topView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.stackViewNames.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.stackViewDepartment.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.stackViewPhone.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.stackViewEmail.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.stackViewAccountID.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.stackViewQRCode.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        
        self.labelPhoneNumberValidation.textColor = DPAGColorProvider.shared[.labelText]
        self.labelEmailValidation.textColor = DPAGColorProvider.shared[.labelText]
        self.labelFirstName.textColor = DPAGColorProvider.shared[.labelText]
        self.labelLastName.textColor = DPAGColorProvider.shared[.labelText]
        self.labelDepartment.textColor = DPAGColorProvider.shared[.labelText]
        self.labelPhoneNumber.textColor = DPAGColorProvider.shared[.labelText]
        self.labelEmail.textColor = DPAGColorProvider.shared[.labelText]
        self.labelAccountIDLabel.textColor = DPAGColorProvider.shared[.labelText]

        self.textFieldStatus.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.textFieldPhoneNumber.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.textFieldEmail.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        
        if self.isEditing {
            self.textFieldNick.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
            if !DPAGApplicationFacade.preferences.isCompanyManagedState {
                self.textFieldFirstName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
                self.textFieldLastName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
                self.textFieldDepartment.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
            }
        } else {
            self.textFieldNick.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            self.textFieldFirstName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            self.textFieldLastName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            self.textFieldDepartment.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }

        self.textFieldNick.textColor = DPAGColorProvider.shared[.backgroundInputText]
        self.textFieldStatus.textColor = DPAGColorProvider.shared[.backgroundInputText]
        self.textFieldFirstName.textColor = DPAGColorProvider.shared[.backgroundInputText]
        self.textFieldLastName.textColor = DPAGColorProvider.shared[.backgroundInputText]
        self.textFieldDepartment.textColor = DPAGColorProvider.shared[.backgroundInputText]
        self.textFieldPhoneNumber.textColor = DPAGColorProvider.shared[.backgroundInputText]
        self.textFieldEmail.textColor = DPAGColorProvider.shared[.backgroundInputText]

        self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]

        configureGui()
    }
}

extension DPAGProfileViewController: DPAGStatusPickerTableViewControllerDelegate {
    func updateStatusMessage(_ statusMessage: String) {
        self.textFieldStatus.text = statusMessage
    }
}

extension DPAGProfileViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.textFieldEditing = textField
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == self.textFieldNick {
            self.textFieldStatus.becomeFirstResponder()
        } else if textField == self.textFieldStatus {
            self.textFieldFirstName.becomeFirstResponder()
        } else if textField == self.textFieldFirstName {
            self.textFieldLastName.becomeFirstResponder()
        } else if textField == self.textFieldLastName {
            self.textFieldDepartment.becomeFirstResponder()
        } else if textField == self.textFieldDepartment {
            self.textFieldDepartment.resignFirstResponder()
        }

        return false
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == self.textFieldFirstName {
            self.contactEdit?.firstName = textField.text
        } else if textField == self.textFieldLastName {
            self.contactEdit?.lastName = textField.text
        } else if textField == self.textFieldDepartment {
            self.contactEdit?.department = textField.text
        }
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let currentText = (textField.text as NSString?) else { return true }
        var retVal = true
        let resultedString = currentText.replacingCharacters(in: range, with: string)
        if textField == self.textFieldNick, resultedString.count >= DPAGProfileViewController.MAXLENGTH_NICK_NAME {
            let resultedStringNew = String(resultedString[..<resultedString.index(resultedString.startIndex, offsetBy: DPAGProfileViewController.MAXLENGTH_NICK_NAME)])
            textField.text = String(resultedStringNew)
            retVal = false
        } else if textField == self.textFieldStatus, resultedString.count >= DPAGProfileViewController.MAXLENGTH_STATUS {
            let resultedStringNew = String(resultedString[..<resultedString.index(resultedString.startIndex, offsetBy: DPAGProfileViewController.MAXLENGTH_STATUS)])
            textField.text = String(resultedStringNew)
            retVal = false
        }
        return retVal
    }
}

extension DPAGProfileViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let profileImage = UIImagePickerController.profileImage(withPickerInfo: info) {
            self.buttonSelectImage.accessibilityIdentifier = "settings.profile.title.labelImageOverlay.updatedImage"
            self.buttonSelectImage.accessibilityLabel = DPAGLocalizedString("settings.profile.title.labelImageOverlay.changeImage")
            self.imageViewProfile.image = profileImage
            self.profileImageChanged = true
        }
        picker.dismiss(animated: true, completion: nil)
    }
}
