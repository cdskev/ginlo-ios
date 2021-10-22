//
//  DPAGNewGroupViewController.swift
// ginlo
//
//  Created by RBU on 28/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import MobileCoreServices
import Photos
import SIMSmeCore
import UIKit

class DPAGNewGroupViewController: DPAGGroupViewController {
    weak var delegate: DPAGNewGroupDelegate?

    init(delegate: DPAGNewGroupDelegate?) {
        super.init(nibName: "DPAGGroupViewController", bundle: Bundle(for: type(of: self)))
        self.delegate = delegate
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = DPAGLocalizedString("chat.group.newTitle")
        self.moreButton.isEnabled = false
        self.muteButton.isEnabled = false
    }

    override func configureNavigationBar() {
        self.setRightBarButtonItemWithText(DPAGLocalizedString("navigation.done"), action: #selector(handleCreateGroupTapped(_:)), accessibilityLabelIdentifier: "navigation.done")
        self.navigationItem.rightBarButtonItem?.isEnabled = (self.textFieldGroupName?.text?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) == false
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissViewController))
    }

    @objc
    private func dismissViewController() {
        self.dismiss(animated: true, completion: nil)
    }

    override func getEditOptions() -> [AlertOption] {
        // This purposefully doesn't call the parent
        var alertOptions: [AlertOption] = []

        let manageMemberOption = AlertOption(title: DPAGLocalizedString("chat.group.label.addMember"), style: .default, image: DPAGImageProvider.shared[.kPersonCircleBadgeCheck], textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "chat.group.label.addMember", handler: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.needsUpdateMembers = true
            strongSelf.textFieldGroupName.resignFirstResponder()
            let contactsSelected = DPAGSearchListSelection<DPAGContact>()
            contactsSelected.appendSelectedFixed(contentsOf: strongSelf.members)
            contactsSelected.appendSelectedFixed(contentsOf: strongSelf.admins)
            contactsSelected.appendSelectedFixed(contentsOf: strongSelf.owners)
            if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) {
                contactsSelected.appendSelectedFixed(contentsOf: [contact])
            }
            if let nextVC = DPAGApplicationFacade.preferences.viewControllerContactSelectionForIdent(.dpagSelectGroupChatMembersAddViewController, contactsSelected: contactsSelected), let nextVCConsumer = nextVC as? DPAGContactsSelectionGroupMembersDelegateConsumer {
                nextVCConsumer.memberSelectionDelegate = self

                strongSelf.navigationController?.pushViewController(nextVC, animated: true)
            }
        })
        alertOptions.append(manageMemberOption)
        if self.isAdmin {
            let manageAdminsOption = AlertOption(title: DPAGLocalizedString("chat.group.label.addAdmin"), style: .default, image: DPAGImageProvider.shared[.kPersonCircleBadgeCheckFill], textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "chat.group.label.addAdmin", handler: { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.needsUpdateMembers = true
                strongSelf.textFieldGroupName.resignFirstResponder()
                let nextVC = DPAGApplicationFacadeUIContacts.contactSelectionGroupAdminsVC(members: strongSelf.members.union(strongSelf.admins), admins: strongSelf.admins, adminsFixed: strongSelf.adminsFixed, delegate: strongSelf)
                strongSelf.navigationController?.pushViewController(nextVC, animated: true)
            })
            alertOptions.append(manageAdminsOption)
        }
        return alertOptions
    }

    // INFO: 2021-01-19 - iso
    // If you want to add new group types, please override this method below in a subclass and call handleCreateGroup(ofType:) with the right type
    // (checkout DPAGNewAnnouncementGroupViewController)
    @objc
    func handleCreateGroupTapped(_: Any?) {
        handleCreateGroup(ofType: DPAGStrings.Server.Group.Request.OBJECT_KEY)
    }

    func handleCreateGroup(ofType groupType: String) {
        self.textFieldGroupName?.resignFirstResponder()
        let isNameEmpty = (self.groupName?.count ?? 0 == 0)
        if isNameEmpty {
            self.handleGroupCreationError(DPAGLocalizedString("group.administration.action.no_name"))
            return
        }
        let groupImage = (self.needsGroupImageUpdate ? self.imageViewGroup.image : nil)
        DPAGProgressHUD.sharedInstance.show(true) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.navigationItem.rightBarButtonItem?.isEnabled = false
            strongSelf.performBlockInBackground { [weak self] in
                if let strongSelf = self, let groupNameForNewRoom = strongSelf.groupName, let ownerGuid = DPAGApplicationFacade.cache.account?.guid {
                    let groupGuid = DPAGFunctionsGlobal.uuid(prefix: .streamGroup)
                    var memberGuids = Set(strongSelf.members.compactMap { $0.guid } + strongSelf.admins.compactMap { $0.guid })
                    var adminGuids = Set(strongSelf.admins.compactMap { $0.guid })
                    memberGuids.remove(ownerGuid)
                    adminGuids.remove(ownerGuid)
                    let blockCreate = {
                        do {
                            if groupType == DPAGStrings.Server.Group.Request.OBJECT_KEY_ANNOUNCEMENT {
                                try DPAGApplicationFacade.chatRoomWorker.createAnnouncementGroup(config: DPAGChatRoomCreationConfig(groupGuid: groupGuid, groupName: groupNameForNewRoom, groupImage: groupImage, memberGuids: memberGuids, adminGuids: adminGuids, ownerGuid: ownerGuid)) { [weak self] _, _, errorMessage in
                                    if let errorMessage = errorMessage {
                                        self?.handleGroupCreationError(errorMessage)
                                    } else {
                                        self?.handleGroupCreated(groupGuid)
                                    }
                                }
                            } else {
                                try DPAGApplicationFacade.chatRoomWorker.createGroup(config: DPAGChatRoomCreationConfig(groupGuid: groupGuid, groupName: groupNameForNewRoom, groupImage: groupImage, memberGuids: memberGuids, adminGuids: adminGuids, ownerGuid: ownerGuid)) { [weak self] _, _, errorMessage in
                                    if let errorMessage = errorMessage {
                                        self?.handleGroupCreationError(errorMessage)
                                    } else {
                                        self?.handleGroupCreated(groupGuid)
                                    }
                                }
                            }
                        } catch {
                            DPAGLog(error)
                        }
                    }
                    let filteredMembers = strongSelf.members.filter { (contact) -> Bool in
                        contact.publicKey == nil
                    }
                    let filteredAdmins = strongSelf.admins.filter { (contact) -> Bool in
                        contact.publicKey == nil
                    }
                    let contactsWithMissingPublicKey = filteredMembers.union(filteredAdmins)

                    if contactsWithMissingPublicKey.count > 0 {
                        DPAGApplicationFacade.updateKnownContactsWorker.synchronize(accountGuids: contactsWithMissingPublicKey.compactMap({ $0.guid })) { [weak self] _, _, errorMessage in
                            if let errorMessage = errorMessage {
                                self?.handleGroupCreationError(errorMessage)
                            } else if self != nil {
                                blockCreate()
                            }
                        }
                    } else {
                        blockCreate()
                    }
                }
            }
        }
    }
    
    private func handleGroupCreated(_ streamGuid: String) {
        self.groupGuid = streamGuid
        self.setSilentHelper.chatIdentifier = streamGuid
        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
            self?.dismiss(animated: true) { [weak self] in
                self?.delegate?.handleGroupCreated(streamGuid)
            }
        }
    }

    private func handleGroupCreationError(_ errorMessage: String) {
        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
            self?.navigationItem.rightBarButtonItem?.isEnabled = (self?.textFieldGroupName?.text?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) == false
            self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
        }
    }
}
