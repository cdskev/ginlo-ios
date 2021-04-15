//
//  DPAGContactDetailsViewController.swift
//  SIMSme
//
//  Created by RBU on 15/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import SIMSmeCore
import UIKit

class DPAGContactDetailsViewController: DPAGContactDetailsViewControllerBase, DPAGContactDetailsViewControllerProtocol {
    private enum Sections: Int {
        case contactInfos = 0,
            lastMessageDate,
            count
    }

    var pushedFromChats = false
    var enableRemove = false
    var enableEdit = false
    let conversationActionHelper = ConversationActionHelper()

    override var textFieldNickname: DPAGTextField! {
        didSet {
            self.textFieldNickname.textColor = DPAGColorProvider.shared[.textFieldText]
        }
    }

    override var textFieldStatus: DPAGTextField! {
        didSet {
            self.textFieldStatus.textColor = DPAGColorProvider.shared[.textFieldText]
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.isEditing = false
        self.performBlockInBackground { [weak self] in
            guard let strongSelf = self else { return }
            DPAGApplicationFacade.preferences.addLastRecentlyUsed(contacts: [strongSelf.contact])
            strongSelf.loadSilentTill()
        }
    }

    override func configureTitle() {
        self.title = self.contact.displayName
    }

    override func configureNavigationBar() {
        if enableEdit {
            self.navigationItem.rightBarButtonItem = self.editButtonItem
        }
    }

    private var saveAfterEditing = false

    @objc
    private func cancelEditing() {
        self.saveAfterEditing = false
        self.setEditing(false, animated: true)
        self.saveAfterEditing = true
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if editing == false {
            _ = self.resignFirstResponder()
            if self.saveAfterEditing {
                self.handleSave(self.viewButtonNext.button)
            } else {
                self.imageViewContactChanged.image = nil
            }
        } else {
            self.saveAfterEditing = true
        }
        self.configureGui()
    }

    override func configureGui() {
        super.configureGui()
        guard let account = DPAGApplicationFacade.cache.account, let contactSelf = DPAGApplicationFacade.cache.contact(for: account.guid) else { return }
        enableEdit = contact.entryTypeServer == .privat
        self.textFieldNickname.isEnabled = false
        self.textFieldStatus.isEnabled = false
        self.imageViewFirstNameLocked.isHidden = self.contact.entryTypeServer == .privat || (self.contact.entryTypeServer == .email && contactSelf.eMailDomain != self.contact.eMailDomain)
        self.imageViewLastNameLocked.isHidden = self.imageViewFirstNameLocked.isHidden
        self.imageViewPhoneNumberLocked.isHidden = self.contact.entryTypeServer != .company
        self.imageViewEmailAddressLocked.isHidden = self.contact.entryTypeServer == .privat
        self.imageViewDepartmentLocked.isHidden = self.contact.entryTypeServer != .company
        self.textFieldFirstName.textColor = self.imageViewFirstNameLocked.isHidden ? DPAGColorProvider.shared[.textFieldText] : DPAGColorProvider.shared[.textFieldTextDisabled]
        self.textFieldLastName.textColor = self.imageViewLastNameLocked.isHidden ? DPAGColorProvider.shared[.textFieldText] : DPAGColorProvider.shared[.textFieldTextDisabled]
        self.textFieldDepartment.textColor = self.imageViewDepartmentLocked.isHidden ? DPAGColorProvider.shared[.textFieldText] : DPAGColorProvider.shared[.textFieldTextDisabled]
        self.imageViewContact.image = self.contact.image(for: .profile)
        let isWhiteLabel = DPAGApplicationFacade.preferences.isWhiteLabelBuild
        if self.isEditing {
            self.stackViewFirstName.isHidden = false
            self.stackViewLastName.isHidden = false
            self.stackViewDepartment.isHidden = isWhiteLabel == false
            self.stackViewPhoneNumber.isHidden = false
            self.stackViewEmailAddress.isHidden = false
            self.textFieldFirstName.isEnabled = self.contact.entryTypeServer == .privat || (self.contact.entryTypeServer == .email && contactSelf.eMailDomain != self.contact.eMailDomain)
            self.textFieldLastName.isEnabled = self.textFieldFirstName.isEnabled
            self.textFieldPhoneNumber.isEnabled = self.contact.entryTypeServer != .company
            self.textFieldEmailAddress.isEnabled = self.contact.entryTypeServer == .privat
            self.textFieldDepartment.isEnabled = self.contact.entryTypeServer != .company
            self.viewButtonNext.isHidden = false
            self.chatButton.isEnabled = false
            self.buttonContactImage.isHidden = false
            self.textFieldEmailAddress.textColor = DPAGColorProvider.shared[.textFieldText]
            self.textFieldPhoneNumber.textColor = DPAGColorProvider.shared[.textFieldText]
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelEditing))
        } else {
            self.stackViewFirstName.isHidden = (self.contact.firstName?.isEmpty ?? true)
            self.stackViewLastName.isHidden = (self.contact.lastName?.isEmpty ?? true)
            self.stackViewDepartment.isHidden = isWhiteLabel == false || (self.contact.department?.isEmpty ?? true)
            self.stackViewPhoneNumber.isHidden = (self.contact.phoneNumber?.isEmpty ?? true)
            self.stackViewEmailAddress.isHidden = (self.contact.eMailAddress?.isEmpty ?? true)
            self.textFieldFirstName.isEnabled = false
            self.textFieldLastName.isEnabled = false
            self.textFieldEmailAddress.isEnabled = true
            self.textFieldPhoneNumber.isEnabled = true
            self.textFieldDepartment.isEnabled = false
            self.viewButtonNext.isHidden = true
            self.buttonContactImage.isHidden = true
            self.textFieldEmailAddress.textColor = DPAGColorProvider.shared[.labelLink]
            self.textFieldPhoneNumber.textColor = DPAGColorProvider.shared[.labelLink]
            if self.contact.guid == DPAGApplicationFacade.cache.account?.guid {
                self.moreButton.isEnabled = false
                self.chatButton.isEnabled = false
                self.contactsButton.isEnabled = false
            } else {
                self.moreButton.isEnabled = self.pushedFromChats && self.contact.streamGuid != nil
                if self.pushedFromChats {
                    self.chatButton.isEnabled = false
                } else {
                    self.chatButton.isEnabled = !self.contact.isReadOnly
                }
            }
            self.navigationItem.leftBarButtonItem = nil
        }
    }
    
    override
    func getContactOptions() -> [AlertOption] {
        var alertOptions = super.getContactOptions()
        if self.contact.guid != DPAGApplicationFacade.cache.account?.guid {
            var contactOption: AlertOption
            if self.contact.isBlocked {
                contactOption = AlertOption(title: DPAGLocalizedString("contacts.details.buttonUnblock"), style: .default, image: DPAGImageProvider.shared[.kMinusCircle], textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "contacts.details.buttonUnblock", handler: {
                    self.handleBlock(self)
                })
            } else {
                contactOption = AlertOption(title: DPAGLocalizedString("contacts.details.buttonBlock"), style: .default, image: DPAGImageProvider.shared[.kMinusCircle], textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "contacts.details.buttonBlock", handler: {
                    self.handleBlock(self)
                })
            }
            alertOptions.append(contactOption)
            if !self.pushedFromChats && (self.contact.entryTypeServer == .privat || self.contact.entryTypeLocal == .privat) {
                alertOptions.append(AlertOption(title: DPAGLocalizedString("contacts.details.buttonRemove"), style: .default, image: DPAGImageProvider.shared[.kDeleteLeft], textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "contacts.details.buttonRemove", handler: {
                    self.handleRemove(self)
                }))
            }
            var shouldAddScanOption = false
            if self.contact.confidence != .high, UIImagePickerController.isSourceTypeAvailable(.camera) {
                let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
                switch authorizationStatus {
                    case .authorized, .notDetermined:
                        shouldAddScanOption = true
                    case .denied, .restricted:
                        shouldAddScanOption = false
                    @unknown default:
                        DPAGLog("Switch with unknown value: \(authorizationStatus.rawValue)", level: .warning)
                }
            } else {
                shouldAddScanOption = false
            }
            if shouldAddScanOption {
                alertOptions.append(AlertOption(title: DPAGLocalizedString("contacts.details.buttonScan"), style: .default, image: DPAGImageProvider.shared[.kScan], textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "contacts.details.buttonScan", handler: {
                    self.handleScan(self)
                }))
            }
        }
        return alertOptions
    }

    override func handleEmptyChat(_: Any?) {
        conversationActionHelper.showClearChatPopup(viewController: self, streamGuid: self.contact.streamGuid)
    }

    override func handleExportChat(_: Any?) {
        guard let streamGuid = self.contact.streamGuid else { return }
        let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .destructive, handler: { [weak self] _ in
            self?.exportStreamWithStreamGuid(streamGuid)
        })
        self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "chat.message.exportChat.warning.title", messageIdentifier: "chat.message.exportChat.warning.message", cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
    }

    private func exportStreamWithStreamGuid(_ streamGuid: String) {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
            if let fileURLTemp = DPAGApplicationFacade.messageWorker.exportStreamToURLWithStreamGuid(streamGuid) {
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    if let strongSelf = self {
                        let activityVC = DPAGActivityViewController(activityItems: [fileURLTemp], applicationActivities: nil)
                        activityVC.completionWithItemsHandler = { _, _, _, _ in
                            do {
                                try FileManager.default.removeItem(at: fileURLTemp)
                            } catch {
                                DPAGLog(error)
                            }
                        }
                        strongSelf.present(activityVC, animated: true) {
                            UINavigationBar.appearance().barTintColor = .white
                            UINavigationBar.appearance().tintColor = .black
                            UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.black]
                        }
                    }
                }
            } else {
                DPAGProgressHUD.sharedInstance.hide(true)
            }
        }
    }

    override func handleScan(_: Any?) {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authorizationStatus {
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video, completionHandler: { [weak self] _ in
                    DispatchQueue.main.async { [weak self] in
                        self?.handleScan(nil)
                    }
                })
                return
            case .authorized:
                let nextVC = DPAGApplicationFacadeUIContacts.scanProfileVC(contactGuid: self.contact.guid, blockSuccess: { [weak self] in
                    guard let strongSelf = self, let contact = self?.contact else { return }
                    strongSelf.configureGui()
                    strongSelf.navigationController?.popToViewController(strongSelf, animated: true)
                    self?.delegate?.contactDidUpdate(contact)
                }, blockFailed: { [weak self] in
                    self?.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "contacts.error.verifyingContactByQRCodeFailed", okActionHandler: { [weak self] _ in
                        if let strongSelf = self {
                            _ = strongSelf.navigationController?.popToViewController(strongSelf, animated: true)
                        }
                    }))
                }, blockCancelled: {})
                self.navigationController?.pushViewController(nextVC, animated: true)
            case .denied, .restricted:
                break
            @unknown default:
                DPAGLog("Switch with unknown value: \(authorizationStatus.rawValue)", level: .warning)
        }
    }

    override func handleChat(_: Any?) {
        if let streamGuid = self.contact.streamGuid {
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
                guard let contact = self?.contact else {
                    DPAGProgressHUD.sharedInstance.hide(true)
                    return
                }
                // init cache
                _ = DPAGApplicationFacade.cache.decryptedStream(streamGuid: streamGuid, in: nil)
                if contact.entryTypeLocal == .hidden {
                    DPAGApplicationFacade.contactsWorker.privatizeContact(contact)
                }
                let block = {
                    NotificationCenter.default.post(name: DPAGStrings.Notification.Menu.MENU_SHOW_CHATSTREAM, object: nil, userInfo: [DPAGStrings.Notification.Menu.MENU_SHOW_CHATSTREAM__USERINFO_KEY__STREAM_GUID: streamGuid, DPAGStrings.Notification.Menu.MENU_SHOW_CHATSTREAM__USERINFO_KEY__WITH_UNCONFIRMED_CONTACT: true])
                }
                if contact.publicKey == nil {
                    DPAGApplicationFacade.updateKnownContactsWorker.synchronize(accountGuid: contact.guid) { _, _, errorMessage in
                        if let errorMessage = errorMessage {
                            DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                                self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                            }
                        } else {
                            block()
                        }
                    }
                } else {
                    block()
                }
            }
        }
    }

    override func handleBlock(_: Any?) {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
            let responseBlock: DPAGServiceResponseBlock = { _, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    if let errorMessage = errorMessage {
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                    } else {
                        self?.configureGui()
                    }
                }
            }
            if self.contact.isBlocked {
                DPAGApplicationFacade.contactsWorker.unblockContact(contactAccountGuid: self.contact.guid, responseBlock: responseBlock)
            } else {
                DPAGApplicationFacade.contactsWorker.blockContact(contactAccountGuid: self.contact.guid, responseBlock: responseBlock)
            }
        }
    }

    override func handleSilent(_: Any?) {
        let nextVC = DPAGApplicationFacadeUIContacts.setSilentVC(setSilentHelper: self.setSilentHelper)
        self.navigationController?.pushViewController(nextVC, animated: true)
    }

    override func handleRemove(_: Any?) {
        let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .destructive, handler: { [weak self] _ in
            self?.removeContact()
        })
        self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "chat.message.removeContact.warning.title", messageIdentifier: "chat.message.removeContact.warning.message", cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
    }

    // MARK: IMDAT-CONTACT
    private func removeContact() {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            guard let contact = self?.contact else { return }
            DPAGApplicationFacade.contactsWorker.deleteContact(withContactGuid: contact.guid)
            DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                if let vcs = self?.navigationController?.viewControllers {
                    for vc in vcs where vc is DPAGViewControllerWithReloadProtocol {
                        (vc as? DPAGViewControllerWithReloadProtocol)?.reloadOnAppear = true
                    }
                }
                self?.navigationController?.popViewController(animated: true)
            }
        }
    }

    override func handleSave(_: Any?) {
        _ = self.resignFirstResponder()
        if self.isEditing {
            self.setEditing(false, animated: false)
            return
        }
        let imageChanged = self.imageViewContactChanged.image
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            if let contactEdit = self?.contactEdit {
                DPAGApplicationFacade.contactsWorker.saveContact(contact: contactEdit)
                if let imageChanged = imageChanged {
                    _ = DPAGApplicationFacade.contactsWorker.saveImage(imageChanged, forContact: contactEdit.guid)
                }
            }
            DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                self?.imageViewContactChanged.image = nil
                self?.configureTitle()
                self?.configureGui()
                if let contact = self?.contact {
                    self?.delegate?.contactDidUpdate(contact)
                }
            }
        }
    }

    private func loadSilentTill() {
        let responseBlock: DPAGServiceResponseBlock = { [weak self] responseObject, _, errorMessage in
            if errorMessage != nil {} else if let dictResponse = responseObject as? [AnyHashable: Any], let dictAccountInfo = dictResponse[DPAGStrings.JSON.Account.OBJECT_KEY] as? [AnyHashable: Any], dictAccountInfo[DPAGStrings.JSON.Account.GUID] as? String != nil {
                let silentTillString: String = dictAccountInfo[DPAGStrings.JSON.Account.PUSH_SILENT_TILL] as? String ?? ""
                let silentTillDate = DPAGFormatter.dateServer.date(from: silentTillString)
                self?.setSilentHelper.currentSilentState = SetSilentHelper.silentStateFor(silentDate: silentTillDate)
            }
        }
        DPAGApplicationFacade.updateKnownContactsWorker.getAccountInfo(accountGuid: self.contact.guid, withProfile: false, withTempDevice: false, response: responseBlock)
    }
}
