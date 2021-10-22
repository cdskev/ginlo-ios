//
//  DPAGContactDetailsViewControllerBase.swift
// ginlo
//
//  Created by RBU on 19/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVKit
import MobileCoreServices
import Photos
import SIMSmeCore
import UIKit

class DPAGContactDetailsViewControllerBase: DPAGViewControllerWithKeyboard {
    private static let SilentCellIdentifier = "SilentCellIdentifier"

    weak var delegate: DPAGContactDetailDelegate?

    private weak var textFieldActive: UITextField?
    var setSilentHelper = SetSilentHelper(chatType: .single)
    var silentStateObservation: NSKeyValueObservation?
    private let sendEmailHelper = SendEmailHelper()

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var viewConfidence: UIView?

    @IBOutlet var topView: UIView! {
        didSet {
            self.topView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }
    
    @IBOutlet var imageViewContact: UIImageView! {
        didSet {
            let imageLayer = self.imageViewContact.layer
            imageLayer.cornerRadius = self.imageViewContact.frame.size.width / 2
            imageLayer.masksToBounds = true
        }
    }

    @IBOutlet var imageViewContactChanged: UIImageView! {
        didSet {
            let imageLayer = self.imageViewContactChanged.layer
            imageLayer.cornerRadius = self.imageViewContactChanged.frame.size.width / 2
            imageLayer.masksToBounds = true
        }
    }

    @IBOutlet var buttonContactImage: UIButton! {
        didSet {
            let imageLayer = self.buttonContactImage.layer
            imageLayer.cornerRadius = self.buttonContactImage.frame.size.width / 2
            imageLayer.masksToBounds = true
            self.buttonContactImage.backgroundColor = DPAGColorProvider.shared[.imageSelectorBackground]
            self.buttonContactImage.setImage(DPAGImageProvider.shared[.kImageAddPhoto], for: .normal)
            self.buttonContactImage.tintColor = DPAGColorProvider.shared[.imageSelectorTint]
        }
    }

    @IBOutlet var stackViewNickname: DPAGStackView! {
        didSet {
            self.stackViewNickname.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }
    
    @IBOutlet var textFieldNickname: DPAGTextField! {
        didSet {
            self.textFieldNickname.accessibilityIdentifier = "textFieldNickname"
            self.textFieldNickname.configureAsTitle()
            self.textFieldNickname.font = UIFont.kFontTitle2
            self.textFieldNickname.textAlignment = .center
            self.textFieldNickname.delegate = self
            self.textFieldNickname.keyboardType = .alphabet
            self.textFieldNickname.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldNickname.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            self.textFieldNickname.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    @IBOutlet var textFieldStatus: DPAGTextField! {
        didSet {
            self.textFieldStatus.accessibilityIdentifier = "textFieldStatus"
            self.textFieldStatus.configureDefault()
            self.textFieldStatus.font = UIFont.kFontFootnote
            self.textFieldStatus.textAlignment = .center
            self.textFieldStatus.delegate = self
            self.textFieldStatus.keyboardType = .alphabet
            self.textFieldStatus.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldStatus.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            self.textFieldStatus.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    @IBOutlet var chatButtonView: UIView! {
        didSet {
            self.chatButtonView.layer.cornerRadius = self.chatButtonView.frame.size.width / 2
            self.chatButtonView.layer.masksToBounds = true
            self.chatButtonView.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
        }
    }

    @IBOutlet var chatButton: UIButton! {
        didSet {
            self.chatButton.accessibilityIdentifier = "buttonChat"
            self.chatButton.addTarget(self, action: #selector(handleChat(_:)), for: .touchUpInside)
            self.chatButton.setImage(DPAGImageProvider.shared[.kBubbleRightFill]?.imageWithTintColor(DPAGColorProvider.shared[.buttonTint]), for: .normal)
            self.chatButton.tintColor = DPAGColorProvider.shared[.buttonTint]
        }
    }
    
    @IBOutlet var muteButtonView: UIView! {
        didSet {
            self.muteButtonView.layer.cornerRadius = self.muteButtonView.frame.size.width / 2
            self.muteButtonView.layer.masksToBounds = true
            self.muteButtonView.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
        }
    }

    @IBOutlet var muteButton: UIButton! {
        didSet {
            self.muteButton.accessibilityIdentifier = "chats.group.selectImage"
            switch self.setSilentHelper.currentSilentState {
                case .none:
                    self.muteButton.setImage(DPAGImageProvider.shared[.kBell]?.imageWithTintColor(DPAGColorProvider.shared[.buttonTint]), for: .normal)
                default:
                    self.muteButton.setImage(DPAGImageProvider.shared[.kBellSlash]?.imageWithTintColor(DPAGColorProvider.shared[.buttonTint]), for: .normal)
            }
            self.muteButton.tintColor = DPAGColorProvider.shared[.buttonTint]
            self.muteButton.addTarget(self, action: #selector(handleSilent(_:)), for: .touchUpInside)
        }
    }
    
    func getContactOptions() -> [AlertOption] {
        []
    }
    
    @objc
    private func showContactOptions(_: Any?) {
        var alertOptions: [AlertOption] = getContactOptions()
        alertOptions.append(AlertOption(title: DPAGLocalizedString("res.cancel"), style: .cancel, textAlignment: CATextLayerAlignmentMode.center))
        let alertController = UIAlertController.controller(options: alertOptions.compactMap { $0 }, sourceView: contactsButtonView)
        self.presentAlertController(alertController)
    }

    @IBOutlet var contactsButtonView: UIView! {
        didSet {
            self.contactsButtonView.layer.cornerRadius = self.contactsButtonView.frame.size.width / 2
            self.contactsButtonView.layer.masksToBounds = true
            self.contactsButtonView.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
        }
    }
    @IBOutlet var contactsButton: UIButton! {
        didSet {
            self.contactsButton.addTarget(self, action: #selector(showContactOptions(_:)), for: .touchUpInside)
            self.contactsButton.accessibilityIdentifier = "chat.group.button.edit"
            self.contactsButton.setImage(DPAGImageProvider.shared[.kPersonFill]?.imageWithTintColor(DPAGColorProvider.shared[.buttonTint]), for: .normal)
            self.contactsButton.tintColor = DPAGColorProvider.shared[.buttonTint]
        }
    }
    
    func getExportChatOption() -> AlertOption? {
        if DPAGApplicationFacade.preferences.isChatExportAllowed {
            return AlertOption(title: DPAGLocalizedString("chat.list.action.export.single"), style: .default, image: DPAGImageProvider.shared[.kShare], textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "buttonExportChat", handler: { [weak self] in
                let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .destructive, handler: { [weak self] _ in
                    self?.handleExportChat(nil)
                })
                self?.presentAlert(alertConfig: AlertConfig(titleIdentifier: "chat.message.exportChat.warning.title", messageIdentifier: "chat.message.exportChat.warning.message", cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
            })
        }
        return nil
    }
    
    func getEmptyChatOption() -> AlertOption {
        AlertOption(title: DPAGLocalizedString("chat.list.action.removeMessages.single"), style: .default, image: DPAGImageProvider.shared[.kClear], textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "buttonDeleteChatContent", handler: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.handleEmptyChat(nil)
        })
    }
    
    func getMoreOptions() -> [AlertOption] {
        var options: [AlertOption] = []
        if let exportOption = getExportChatOption() {
            options.append(exportOption)
        }
        options.append(getEmptyChatOption())
        return options
    }
    
    @objc
    private func showMoreOptions(_: Any?) {
        var alertOptions: [AlertOption] = self.getMoreOptions()

        alertOptions.append(AlertOption(title: DPAGLocalizedString("res.cancel"), style: .cancel, textAlignment: CATextLayerAlignmentMode.center))
        let alertController = UIAlertController.controller(options: alertOptions.compactMap { $0 }, sourceView: moreButtonView)
        self.presentAlertController(alertController)
    }
    
    @IBOutlet var moreButtonView: UIView! {
        didSet {
            self.moreButtonView.layer.cornerRadius = self.moreButtonView.frame.size.width / 2
            self.moreButtonView.layer.masksToBounds = true
            self.moreButtonView.backgroundColor = DPAGColorProvider.shared[.buttonBackground]

        }
    }

    @IBOutlet var moreButton: UIButton! {
        didSet {
            self.moreButton.addTarget(self, action: #selector(showMoreOptions(_:)), for: .touchUpInside)
            self.moreButton.accessibilityIdentifier = "chats.group.selectImage"
            self.moreButton.setImage(DPAGImageProvider.shared[.kEllipsis]?.imageWithTintColor(DPAGColorProvider.shared[.buttonTint]), for: .normal)
            self.moreButton.tintColor = DPAGColorProvider.shared[.buttonTint]
        }
    }
    
    @IBOutlet var stackViewFirstName: DPAGStackView! {
        didSet {
            self.stackViewFirstName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }
    
    @IBOutlet var labelFirstNameView: UIView! {
        didSet {
            self.labelFirstNameView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }
    
    @IBOutlet private var labelFirstName: UILabel! {
        didSet {
            self.labelFirstName.text = DPAGLocalizedString("contacts.details.labelFirstName").uppercased()
            self.labelFirstName.configureLabelForTextField()
        }
    }

    @IBOutlet var textFieldFirstName: DPAGTextField! {
        didSet {
            self.textFieldFirstName.accessibilityIdentifier = "textFieldFirstName"
            self.textFieldFirstName.configureDefault()
            self.textFieldFirstName.font = UIFont.kFontCallout
            self.textFieldFirstName.delegate = self
            self.textFieldFirstName.keyboardType = .alphabet
            self.textFieldFirstName.autocorrectionType = .no
            self.textFieldFirstName.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldFirstName.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            self.textFieldFirstName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    @IBOutlet var imageViewFirstNameLocked: UIImageView! {
        didSet {
            self.imageViewFirstNameLocked.image = DPAGImageProvider.shared[.kImageLockedSmall]
            self.imageViewFirstNameLocked.tintColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet var stackViewLastName: DPAGStackView! {
        didSet {
            self.stackViewLastName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }
    
    @IBOutlet var labelLastNameView: UIView! {
        didSet {
            self.labelLastNameView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }
    
    @IBOutlet private var labelLastName: UILabel! {
        didSet {
            self.labelLastName.text = DPAGLocalizedString("contacts.details.labelLastName").uppercased()
            self.labelLastName.configureLabelForTextField()
        }
    }

    @IBOutlet var textFieldLastName: DPAGTextField! {
        didSet {
            self.textFieldLastName.accessibilityIdentifier = "textFieldLastName"
            self.textFieldLastName.configureDefault()
            self.textFieldLastName.font = UIFont.kFontCallout
            self.textFieldLastName.delegate = self
            self.textFieldLastName.keyboardType = .alphabet
            self.textFieldLastName.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldLastName.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            self.textFieldLastName.autocorrectionType = .no
            self.textFieldLastName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    @IBOutlet var imageViewLastNameLocked: UIImageView! {
        didSet {
            self.imageViewLastNameLocked.image = DPAGImageProvider.shared[.kImageLockedSmall]
            self.imageViewLastNameLocked.tintColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet var stackViewPhoneNumber: DPAGStackView! {
        didSet {
            self.stackViewPhoneNumber.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }
    
    @IBOutlet var labelPhoneNumberView: UIView! {
        didSet {
            self.labelPhoneNumberView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }
    
    @IBOutlet private var labelPhoneNumber: UILabel! {
        didSet {
            self.labelPhoneNumber.text = DPAGLocalizedString("contacts.details.labelPhoneNumber").uppercased()
            self.labelPhoneNumber.configureLabelForTextField()
        }
    }

    @IBOutlet var textFieldPhoneNumber: DPAGTextField! {
        didSet {
            self.textFieldPhoneNumber.accessibilityIdentifier = "textFieldPhoneNumber"
            self.textFieldPhoneNumber.configureDefault()
            self.textFieldPhoneNumber.font = UIFont.kFontCallout
            self.textFieldPhoneNumber.delegate = self
            self.textFieldPhoneNumber.keyboardType = .phonePad
            self.textFieldPhoneNumber.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldPhoneNumber.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            self.textFieldPhoneNumber.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    @IBOutlet var imageViewPhoneNumberLocked: UIImageView! {
        didSet {
            self.imageViewPhoneNumberLocked.image = DPAGImageProvider.shared[.kImageLockedSmall]
            self.imageViewPhoneNumberLocked.tintColor = DPAGColorProvider.shared[.labelText]
        }
    }
    
    @IBOutlet var stackViewEmailAddress: DPAGStackView! {
        didSet {
            self.stackViewEmailAddress.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }
    
    @IBOutlet var labelEmailAddressView: UIView! {
        didSet {
            self.labelEmailAddressView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }
    
    @IBOutlet private var labelEmailAddress: UILabel! {
        didSet {
            self.labelEmailAddress.text = DPAGLocalizedString("contacts.details.labelEMail").uppercased()
            self.labelEmailAddress.configureLabelForTextField()
        }
    }

    @IBOutlet var textFieldEmailAddress: DPAGTextField! {
        didSet {
            self.textFieldEmailAddress.accessibilityIdentifier = "textFieldEmail"
            self.textFieldEmailAddress.configureDefault()
            self.textFieldEmailAddress.font = UIFont.kFontCallout
            self.textFieldEmailAddress.delegate = self
            self.textFieldEmailAddress.keyboardType = .emailAddress
            self.textFieldEmailAddress.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldEMail.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            self.textFieldEmailAddress.autocorrectionType = .no
            self.textFieldEmailAddress.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    @IBOutlet var imageViewEmailAddressLocked: UIImageView! {
        didSet {
            self.imageViewEmailAddressLocked.image = DPAGImageProvider.shared[.kImageLockedSmall]
            self.imageViewEmailAddressLocked.tintColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet var stackViewDepartment: DPAGStackView! {
        didSet {
            self.stackViewDepartment.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }
    
    @IBOutlet var labelDepartmentView: UIView! {
        didSet {
            self.labelDepartmentView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }
    
    @IBOutlet private var labelDepartment: UILabel! {
        didSet {
            self.labelDepartment.text = DPAGLocalizedString("contacts.details.labelDepartment").uppercased()
            self.labelDepartment.configureLabelForTextField()
        }
    }

    @IBOutlet var textFieldDepartment: DPAGTextField! {
        didSet {
            self.textFieldDepartment.accessibilityIdentifier = "textFieldDepartment"
            self.textFieldDepartment.configureDefault()
            self.textFieldDepartment.font = UIFont.kFontCallout
            self.textFieldDepartment.delegate = self
            self.textFieldDepartment.keyboardType = .alphabet
            self.textFieldDepartment.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("contacts.details.textFieldDepartment.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            self.textFieldDepartment.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    @IBOutlet var imageViewDepartmentLocked: UIImageView! {
        didSet {
            self.imageViewDepartmentLocked.image = DPAGImageProvider.shared[.kImageLockedSmall]
            self.imageViewDepartmentLocked.tintColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var stackViewAccountID: DPAGStackView! {
        didSet {
            self.stackViewAccountID.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }
    
    @IBOutlet private var labelAccountIDView: UIView! {
        didSet {
            self.labelAccountIDView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        }
    }
    @IBOutlet private var labelAccountID: UILabel! {
        didSet {
            self.labelAccountID.text = DPAGLocalizedString("contacts.details.labelAccountID")
            self.labelAccountID.configureLabelForTextField()
        }
    }

    @IBOutlet private var imageViewAccountID: UIImageView! {
        didSet {
            self.imageViewAccountID.image = DPAGImageProvider.shared[.kImageFingerprintSmall]
            self.imageViewAccountID.tintColor = DPAGColorProvider.shared[.accountID]
        }
    }

    @IBOutlet private var labelAccountIDValue: UILabel! {
        didSet {
            self.labelAccountIDValue.font = UIFont.kFontCalloutBold
            self.labelAccountIDValue.textColor = DPAGColorProvider.shared[.labelLink]
        }
    }

    @IBOutlet private var viewMandant: UIView! {
        didSet {
            self.viewMandant.backgroundColor = DPAGColorProvider.shared[.mandantBackground]
            self.viewMandant.layer.cornerRadius = 9
            self.viewMandant.layer.masksToBounds = true
        }
    }

    @IBOutlet private var labelMandant: UILabel! {
        didSet {
            self.labelMandant.font = UIFont.kFontBadge
            self.labelMandant.textColor = DPAGColorProvider.shared[.mandantText]
            self.labelMandant.text = nil
        }
    }
    
    @IBOutlet var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.accessibilityIdentifier = "buttonSave"
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("contacts.details.buttonSave"), for: .normal)
            self.viewButtonNext.button.addTarget(self, action: #selector(handleSave(_:)), for: .touchUpInside)
        }
    }

    let contact: DPAGContact
    let contactEdit: DPAGContactEdit

    private let mandanten = DPAGApplicationFacade.preferences.mandantenDict

    init(contact: DPAGContact, contactEdit: DPAGContactEdit? = nil) {
        self.contact = contact
        self.contactEdit = contactEdit ?? DPAGContactEdit(guid: contact.guid)
        super.init(nibName: "DPAGContactDetailsViewControllerBase", bundle: Bundle(for: type(of: self)))
        self.setSilentHelper.chatIdentifier = self.contact.guid
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.configureTitle()
        self.configureGui()
        self.configureNavigationBar()
        self.configureSetSilentHelper()
    }

    deinit {
        self.silentStateObservation?.invalidate()
    }

    override func handleViewTapped(_ sender: Any?) {
        super.handleViewTapped(sender)

        _ = self.resignFirstResponder()
    }

    private func configureSetSilentHelper() {
        self.silentStateObservation = self.setSilentHelper.observe(\.silentStateChange, options: [.new]) { [weak self] _, _ in
            self?.performBlockOnMainThread { [weak self] in
                if let strongSelf = self {
                    switch strongSelf.setSilentHelper.currentSilentState {
                        case .none:
                            strongSelf.muteButton.setImage(DPAGImageProvider.shared[.kBell]?.imageWithTintColor(DPAGColorProvider.shared[.buttonTint]), for: .normal)
                        default:
                            strongSelf.muteButton.setImage(DPAGImageProvider.shared[.kBellSlash]?.imageWithTintColor(DPAGColorProvider.shared[.buttonTint]), for: .normal)
                    }
                }
            }
        }
    }

    func configureTitle() {}

    func configureNavigationBar() {
        let dummyBarButton = UIView(frame: CGRect(origin: .zero, size: DPAGImageProvider.kSizeBarButton))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: dummyBarButton)
    }

    func configureGui() {
        self.textFieldNickname.text = self.contact.nickName?.isEmpty ?? true ? self.contact.firstName : self.contact.nickName
        self.textFieldStatus.text = self.contact.statusMessage?.isEmpty ?? true ? DPAGLocalizedString("contacts.details.unknown.status") : self.contact.statusMessage
        self.textFieldFirstName.text = self.contactEdit.firstName ?? self.contact.firstName
        self.textFieldLastName.text = self.contactEdit.lastName ?? self.contact.lastName
        self.textFieldPhoneNumber.text = self.contactEdit.phoneNumber ?? self.contact.phoneNumber
        self.textFieldEmailAddress.text = self.contactEdit.eMailAddress ?? self.contact.eMailAddress
        self.textFieldDepartment.text = self.contactEdit.department ?? self.contact.department
        self.imageViewContact.image = self.imageViewContactChanged.image ?? self.contact.image(for: .profile)?.circleImageUsingConfidenceColor(UIColor.confidenceStatusToColor(self.contact.confidence, isActive: true), thickness: 8)
        self.labelAccountIDValue.text = self.contact.accountID
        self.labelMandant.text = self.mandanten[self.contact.mandantIdent]?.label ?? self.contact.mandantIdent
        self.viewConfidence?.backgroundColor = UIColor.confidenceStatusToColor(self.contact.confidence, isActive: true)
        self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.buttonContactImage.isEnabled = true
    }

    override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.viewConfidence?.backgroundColor = UIColor.confidenceStatusToColor(self.contact.confidence, isActive: true)
        self.topView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.buttonContactImage.backgroundColor = DPAGColorProvider.shared[.imageSelectorBackground]
        self.buttonContactImage.tintColor = DPAGColorProvider.shared[.imageSelectorTint]

        self.stackViewNickname.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.textFieldNickname.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.textFieldNickname.textColor = DPAGColorProvider.shared[.textFieldText]
        self.textFieldStatus.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.textFieldStatus.textColor = DPAGColorProvider.shared[.textFieldText]

        self.chatButtonView.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
        self.chatButton.tintColor = DPAGColorProvider.shared[.buttonTint]

        self.muteButtonView.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
        switch self.setSilentHelper.currentSilentState {
            case .none:
                self.muteButton.setImage(DPAGImageProvider.shared[.kBell]?.imageWithTintColor(DPAGColorProvider.shared[.buttonTint]), for: .normal)
            default:
                self.muteButton.setImage(DPAGImageProvider.shared[.kBellSlash]?.imageWithTintColor(DPAGColorProvider.shared[.buttonTint]), for: .normal)
        }
        self.muteButton.tintColor = DPAGColorProvider.shared[.buttonTint]
        self.contactsButtonView.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
        self.contactsButton.setImage(DPAGImageProvider.shared[.kPersonFill]?.imageWithTintColor(DPAGColorProvider.shared[.buttonTint]), for: .normal)
        self.contactsButton.tintColor = DPAGColorProvider.shared[.buttonTint]

        self.moreButton.setImage(DPAGImageProvider.shared[.kEllipsis]?.imageWithTintColor(DPAGColorProvider.shared[.buttonTint]), for: .normal)
        self.moreButton.tintColor = DPAGColorProvider.shared[.buttonTint]

        self.stackViewFirstName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.labelFirstNameView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.labelFirstName.textColor = DPAGColorProvider.shared[.labelText]
        self.labelFirstName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.textFieldFirstName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.textFieldFirstName.textColor = self.imageViewFirstNameLocked.isHidden ? DPAGColorProvider.shared[.textFieldText] : DPAGColorProvider.shared[.textFieldTextDisabled]
        self.imageViewFirstNameLocked.tintColor = DPAGColorProvider.shared[.labelText]

        self.stackViewLastName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.labelLastNameView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.labelLastName.textColor = DPAGColorProvider.shared[.labelText]
        self.labelLastName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.textFieldLastName.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.textFieldLastName.textColor = self.imageViewLastNameLocked.isHidden ? DPAGColorProvider.shared[.textFieldText] : DPAGColorProvider.shared[.textFieldTextDisabled]
        self.imageViewLastNameLocked.tintColor = DPAGColorProvider.shared[.labelText]

        self.stackViewPhoneNumber.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.labelPhoneNumberView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.labelPhoneNumber.textColor = DPAGColorProvider.shared[.labelText]
        self.labelPhoneNumber.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.textFieldPhoneNumber.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.textFieldPhoneNumber.textColor = DPAGColorProvider.shared[.textFieldText]
        self.imageViewPhoneNumberLocked.tintColor = DPAGColorProvider.shared[.labelText]

        self.stackViewEmailAddress.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.labelEmailAddressView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.labelEmailAddress.textColor = DPAGColorProvider.shared[.labelText]
        self.labelEmailAddress.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.textFieldEmailAddress.textColor = DPAGColorProvider.shared[.textFieldText]
        self.textFieldEmailAddress.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.imageViewEmailAddressLocked.tintColor = DPAGColorProvider.shared[.labelText]

        self.stackViewDepartment.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.labelDepartmentView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.labelDepartment.textColor = DPAGColorProvider.shared[.labelText]
        self.labelDepartment.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.textFieldDepartment.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.textFieldDepartment.textColor = self.imageViewDepartmentLocked.isHidden ? DPAGColorProvider.shared[.textFieldText] : DPAGColorProvider.shared[.textFieldTextDisabled]
        self.imageViewDepartmentLocked.tintColor = DPAGColorProvider.shared[.labelText]

        self.labelAccountIDView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
        self.labelAccountIDValue.textColor = DPAGColorProvider.shared[.labelLink]
        self.viewMandant.backgroundColor = DPAGColorProvider.shared.kColorAccentMandantContrast[self.contact.mandantIdent] ?? DPAGColorProvider.shared[.mandantBackground]
        self.labelMandant.textColor = DPAGColorProvider.shared.kColorAccentMandant[self.contact.mandantIdent] ?? DPAGColorProvider.shared[.mandantText]
        self.stackViewAccountID.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.imageViewAccountID.tintColor = DPAGColorProvider.shared[.accountID]
    }

    override func handleKeyboardWillShow(_ aNotification: Notification) {
        if let textFieldActive = self.textFieldActive {
            super.handleKeyboardWillShow(aNotification, scrollView: self.scrollView, viewVisible: textFieldActive, viewButtonPrimary: self.viewButtonNext)
        }
    }

    override func handleKeyboardWillHide(_ aNotification: Notification) {
        super.handleKeyboardWillHide(aNotification, scrollView: self.scrollView, viewButtonPrimary: self.viewButtonNext)
    }

    // swiftlint:disable private_action
    @IBAction func handleEmptyChat(_: Any?) {}

    @IBAction func handleExportChat(_: Any?) {}

    @IBAction func handleRemove(_: Any?) {}

    @IBAction func handleSave(_: Any?) {}

    @IBAction func handleScan(_: Any?) {}

    @IBAction func handleBlock(_: Any?) {}

    @IBAction func handleChat(_: Any?) {}

    @IBAction func handleSilent(_: Any?) {}

    @IBAction func handleContactImage(_: Any?) {
        PictureButtonHandler.handlePickPictureButtonTapped(viewControllerWithImagePicker: self)
    }

    @IBAction func buttonAccountIdValuePressed(_: Any?) {
        guard let contactId = self.contact.accountID else { return }
        let sharingHelper = SharingHelper()
        sharingHelper.showSharing(fromViewController: self, items: [contactId], sourceView: labelAccountIDValue)
    }

    // swiftlint:enable private_action

    override func resignFirstResponder() -> Bool {
        self.textFieldStatus.resignFirstResponder()
        self.textFieldNickname.resignFirstResponder()
        self.textFieldDepartment.resignFirstResponder()
        self.textFieldEmailAddress.resignFirstResponder()
        self.textFieldLastName.resignFirstResponder()
        self.textFieldFirstName.resignFirstResponder()
        self.textFieldPhoneNumber.resignFirstResponder()

        return super.resignFirstResponder()
    }

    private func showSendingEmail(toAddress address: String?) {
        guard let address = address else {
            return
        }
        self.sendEmailHelper.showSendingEmail(fromViewController: self.navigationController, recepients: [address])
    }
}

extension DPAGContactDetailsViewControllerBase: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let profileImage = UIImagePickerController.profileImage(withPickerInfo: info) {
            self.imageViewContactChanged.image = profileImage
        }
        picker.dismiss(animated: true, completion: nil)
    }
}

extension DPAGContactDetailsViewControllerBase: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.textFieldActive = textField
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField == self.textFieldPhoneNumber, self.isEditing == false, let phoneNumber = textField.text {
            let phoneNumberStripped = phoneNumber.stripUnrecognizedPhoneNumberCharacters()
            let phoneURL = URL(string: "tel://\(phoneNumberStripped)")

            AppConfig.openURL(phoneURL)

            return false
        }

        if textField == self.textFieldEmailAddress, self.isEditing == false {
            self.showSendingEmail(toAddress: textFieldEmailAddress.text)
            return false
        }

        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == self.textFieldNickname {
            self.textFieldStatus.becomeFirstResponder()
        } else if textField == self.textFieldStatus {
            self.textFieldFirstName.becomeFirstResponder()
        } else if textField == self.textFieldFirstName {
            self.textFieldLastName.becomeFirstResponder()
        } else if textField == self.textFieldLastName {
            self.textFieldPhoneNumber.becomeFirstResponder()
        } else if textField == self.textFieldPhoneNumber {
            self.textFieldEmailAddress.becomeFirstResponder()
        } else if textField == self.textFieldEmailAddress {
            self.textFieldDepartment.becomeFirstResponder()
        }

        return false
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == self.textFieldNickname {
            self.contactEdit.nickname = textField.text
        } else if textField == self.textFieldStatus {
            self.contactEdit.status = textField.text
        } else if textField == self.textFieldFirstName {
            self.contactEdit.firstName = textField.text
        } else if textField == self.textFieldLastName {
            self.contactEdit.lastName = textField.text
        } else if textField == self.textFieldPhoneNumber {
            self.contactEdit.phoneNumber = textField.text
        } else if textField == self.textFieldEmailAddress {
            self.contactEdit.eMailAddress = textField.text
        } else if textField == self.textFieldDepartment {
            self.contactEdit.department = textField.text
        }
    }
}
