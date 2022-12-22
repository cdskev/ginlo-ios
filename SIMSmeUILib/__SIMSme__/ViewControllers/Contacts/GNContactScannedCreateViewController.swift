//
//  GNContactScannedCreateViewController.swift
//  SIMSmeUILib
//
//  Created by Imdat Solak on 09.09.21.
//  Copyright © 2021 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class GNContactScannedCreateViewController: DPAGContactDetailsViewControllerBase, GNContactScannedCreateViewControllerProtocol {
    var confirmConfidence = false
    var createNewChat = false
    var isLogin = false

    override func configureTitle() {
        self.title = DPAGLocalizedString("contacts.createScanned.title")
    }

    override func configureGui() {
        super.configureGui()
        let isWhiteLabel = DPAGApplicationFacade.preferences.isWhiteLabelBuild
        self.stackViewNickname.isHidden = true
        self.stackViewFirstName.isHidden = false
        self.stackViewLastName.isHidden = false
        self.stackViewDepartment.isHidden = isWhiteLabel == false
        self.stackViewPhoneNumber.isHidden = false
        self.stackViewEmailAddress.isHidden = false
        self.imageViewFirstNameLocked.isHidden = true
        self.imageViewLastNameLocked.isHidden = true
        self.imageViewPhoneNumberLocked.isHidden = true
        self.imageViewEmailAddressLocked.isHidden = true
        self.imageViewDepartmentLocked.isHidden = true
        self.isEditing = true
    }

    override
    func configureNavigationBar() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: DPAGLocalizedString("contacts.details.buttonSave"), style: .plain, target: self, action: #selector(handleSave(_:)))
        self.navigationItem.rightBarButtonItem?.accessibilityIdentifier = "buttonSave"
        self.viewButtonNext.isHidden = true
    }

    override func handleSave(_: Any?) {
        _ = self.resignFirstResponder()
        let image = self.imageViewContactChanged.image
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            if let strongSelf = self {
                let contactEdit = strongSelf.contactEdit
                let contactAccountGuid = strongSelf.contactEdit.guid
                DPAGApplicationFacade.contactsWorker.saveContact(contact: contactEdit)
                if strongSelf.confirmConfidence {
                    DPAGApplicationFacade.contactsWorker.contactConfidenceHigh(contactAccountGuid: contactAccountGuid)
                    DPAGApplicationFacade.contactsWorker.saveContact(contact: contactEdit)
                }
                if let imageChanged = image {
                    _ = DPAGApplicationFacade.contactsWorker.saveImage(imageChanged, forContact: contactEdit.guid)
                }
                if let contact = DPAGApplicationFacade.cache.contact(for: contactAccountGuid), let streamGuid = contact.streamGuid {
                    _ = DPAGApplicationFacade.cache.decryptedStream(streamGuid: streamGuid, in: nil)
                }
            }
            DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                guard let strongSelf = self else { return }
                if strongSelf.isLogin {
                    if !strongSelf.createNewChat {
                        if let presentedViewController = self?.presentedViewController {
                            presentedViewController.dismiss(animated: true) {
                                NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_COMPLETE_LOGIN, object: nil)
                            }
                        } else {
                            NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_COMPLETE_LOGIN, object: nil)
                        }
                    } else {
                        let contactGuid = self?.contactEdit.guid ?? "???"
                        if let presentedViewController = self?.presentedViewController {
                            presentedViewController.dismiss(animated: true) {
                                NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_COMPLETE_LOGIN, object: nil)
                                NotificationCenter.default.post(name: DPAGStrings.Notification.Menu.MENU_SHOW_CHATS, object: nil, userInfo: [DPAGStrings.Notification.Menu.MENU_SHOW_CHATS__USERINFO_KEY__CONTACT_GUID: contactGuid])
                            }
                        } else {
                            NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_COMPLETE_LOGIN, object: nil)
                            NotificationCenter.default.post(name: DPAGStrings.Notification.Menu.MENU_SHOW_CHATS, object: nil, userInfo: [DPAGStrings.Notification.Menu.MENU_SHOW_CHATS__USERINFO_KEY__CONTACT_GUID: contactGuid])
                        }
                    }
                } else {
                    if strongSelf.createNewChat {
                        let contactGuid = self?.contactEdit.guid ?? "???"
                        if let presentedViewController = self?.presentedViewController {
                            presentedViewController.dismiss(animated: true) {
                                NotificationCenter.default.post(name: DPAGStrings.Notification.Menu.MENU_SHOW_CHATS, object: nil, userInfo: [DPAGStrings.Notification.Menu.MENU_SHOW_CHATS__USERINFO_KEY__CONTACT_GUID: contactGuid])
                            }
                        } else {
                            NotificationCenter.default.post(name: DPAGStrings.Notification.Menu.MENU_SHOW_CHATS, object: nil, userInfo: [DPAGStrings.Notification.Menu.MENU_SHOW_CHATS__USERINFO_KEY__CONTACT_GUID: contactGuid])
                        }
                    } else {
                        if let presentedViewController = self?.presentedViewController {
                            presentedViewController.dismiss(animated: true) {
                                NotificationCenter.default.post(name: DPAGStrings.Notification.Menu.MENU_SHOW_CHATS, object: nil, userInfo: nil)
                            }
                        } else {
                            NotificationCenter.default.post(name: DPAGStrings.Notification.Menu.MENU_SHOW_CHATS, object: nil, userInfo: nil)
                        }
                    }
                }
            }
        }
    }

    func saveContactToContactEdit() {
        self.contactEdit.firstName = self.contact.firstName
        self.contactEdit.lastName = self.contact.lastName
        self.contactEdit.phoneNumber = self.contact.phoneNumber
        self.contactEdit.eMailAddress = self.contact.eMailAddress
        self.contactEdit.department = self.contact.department
    }
}
