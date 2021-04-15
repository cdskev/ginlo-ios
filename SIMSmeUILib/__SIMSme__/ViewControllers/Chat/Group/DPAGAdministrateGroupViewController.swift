//
//  DPAGAdministrateGroupViewController.swift
//  Ginlo
//
//  Created by iso on 2021-01-19
//  Copyright © 2021 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import MobileCoreServices
import Photos
import SIMSmeCore
import UIKit

class DPAGAdministrateGroupViewController: DPAGGroupViewController {
    private var groupNameOrg: String?
    private var membersOrg: Set<DPAGContact> = Set()
    private var adminsOrg: Set<DPAGContact> = Set()

    private let groupGuidAdmin: String

    private var groupType: DPAGGroupType = .default
    private var groupDeleted: Bool = false

    init(groupGuid: String) {
        self.groupGuidAdmin = groupGuid
        super.init(nibName: "DPAGGroupViewController", bundle: Bundle(for: type(of: self)))
        self.setSilentHelper.chatIdentifier = groupGuid
        self.groupGuid = groupGuid
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureButtons()
        self.configureNavigationBar()
        self.configureTableViews()
        self.configureGroupPhoto()
        self.configureGroupName()
        self.performBlockInBackground {
            self.loadSilentTill()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(handleStreamNeedsUpdate(_:)), name: DPAGStrings.Notification.ChatStream.NEEDS_UPDATE_META, object: nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if (self.navigationController?.viewControllers.contains(self) ?? false) == false {
            NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.ChatStream.NEEDS_UPDATE_META, object: nil)
        }
    }

    @objc
    func handleStreamNeedsUpdate(_ aNotification: Notification) {
        if self.needsUpdateMembers || self.needsGroupNameUpdate || self.needsGroupImageUpdate {
            return
        }
        if ((aNotification.object as? UIViewController) === self) == false, let streamGuid = aNotification.userInfo?[DPAGStrings.Notification.ChatStream.NEEDS_UPDATE__USERINFO_KEY__STREAM_GUID] as? String, streamGuid == self.groupGuid {
            self.performBlockInBackground { [weak self] in
                self?.createModel()
                self?.performBlockOnMainThread { [weak self] in
                    self?.tableViewAdmins.reloadData()
                    if self?.isAdmin ?? false || self?.isOwner ?? false || self?.groupType != .announcement {
                        self?.membersHeaderLabel.isHidden = self?.members.count == 0
                        self?.tableViewMember.reloadData()
                    }
                    self?.configureButtons()
                    self?.configureNavigationBar()
                    self?.configureGroupPhoto()
                    self?.configureGroupName()
                }
            }
        }
    }

    override func createModel() {
        var members: Set<DPAGContact> = Set()
        var admins: Set<DPAGContact> = Set()
        var owners: Set<DPAGContact> = Set()
        var adminsFixed: Set<DPAGContact> = Set()
        if let group = DPAGApplicationFacade.cache.group(for: self.groupGuidAdmin), let account = DPAGApplicationFacade.cache.account {
            let ownGuid = account.guid
            self.accountGuid = ownGuid
            self.groupType = group.groupType
            self.groupDeleted = group.isDeleted
            self.groupName = group.name
            self.ownerGuid = group.guidOwner
            let adminGuids = group.adminGuids
            self.isAdmin = adminGuids.contains(ownGuid)
            self.isOwner = group.guidOwner == ownGuid
            for memberGuid in group.memberGuids {
                guard let contact = DPAGApplicationFacade.cache.contact(for: memberGuid) else {
                    continue
                }
                if ownGuid == memberGuid {
                    if adminGuids.contains(memberGuid) {
                        admins.insert(contact)
                        adminsFixed.insert(contact)
                    } else {
                        members.insert(contact)
                    }
                    if self.isOwner {
                        owners.insert(contact)
                    }
                } else {
                    if adminGuids.contains(memberGuid) {
                        admins.insert(contact)
                        if group.guidOwner == memberGuid {
                            adminsFixed.insert(contact)
                            owners.insert(contact)
                        }
                    } else {
                        members.insert(contact)
                    }
                }
            }
        }
        self.members = members
        self.admins = admins
        self.owners = owners
        self.membersSorted = self.members.sorted { (c1, c2) -> Bool in
            c1.isBeforeInSearch(c2)
        }
        self.adminsSorted = self.admins.sorted { (c1, c2) -> Bool in
            c1.isBeforeInSearch(c2)
        }
        self.adminsFixed = adminsFixed
        self.membersOrg = self.members
        self.adminsOrg = self.admins
    }

    func configureGroupPhoto() {
        self.buttonGroupImage.isHidden = true
        let profileImage = DPAGUIImageHelper.image(forGroupGuid: self.groupGuidAdmin, imageType: .profile)
        self.imageViewGroup.image = profileImage
    }

    override func configureNavigationBar() {
        if self.isAdmin || self.isOwner {
            self.setRightBarButtonItemWithText(DPAGLocalizedString("navigation.done"), action: #selector(handleUpdateGroupTapped(_:)), accessibilityLabelIdentifier: "navigation.done")
            self.navigationItem.rightBarButtonItem?.isEnabled = false
            if self.groupType == .announcement {
                self.title = DPAGLocalizedString("chat.group.announcementRoom.administration.title")
            } else {
                self.title = DPAGLocalizedString("chat.group.administration.title")
            }
        } else {
            if self.groupType == .announcement {
                self.title = DPAGLocalizedString("chat.group.announcementRoom.infoView.title")
            } else {
                self.title = DPAGLocalizedString("chat.group.infoView.title")
            }
        }
    }

    override func configureTableViews() {
        super.configureTableViews()
        if self.isAdmin || self.isOwner {
            return
        }
        if groupType == .announcement {
            self.tableViewMember.isHidden = true
            self.membersHeaderLabel.isHidden = true
            self.membersHeaderLabel.removeFromSuperview()
            self.tableViewMember.removeFromSuperview()
        }
    }

    private func configureGroupName() {
        self.textFieldGroupName.text = self.groupName
        self.textFieldGroupName.isEnabled = false
    }

    private func configureButtons() {
        if self.isAdmin {
            self.editGroupButtonView.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
            self.editGroupButton.isEnabled = true
        } else {
            self.editGroupButtonView.backgroundColor = DPAGColorProvider.shared[.buttonBackgroundDisabled]
            self.editGroupButton.isEnabled = false
        }
    }
    
    override func getEditOptions() -> [AlertOption] {
        var options = super.getEditOptions()
        
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
        options.append(manageMemberOption)
        if self.isAdmin {
            let manageAdminsOption = AlertOption(title: DPAGLocalizedString("chat.group.label.addAdmin"), style: .default, image: DPAGImageProvider.shared[.kPersonCircleBadgeCheckFill], textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "chat.group.label.addAdmin", handler: { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.needsUpdateMembers = true
                strongSelf.textFieldGroupName.resignFirstResponder()
                let nextVC = DPAGApplicationFacadeUIContacts.contactSelectionGroupAdminsVC(members: strongSelf.members.union(strongSelf.admins), admins: strongSelf.admins, adminsFixed: strongSelf.adminsFixed, delegate: strongSelf)
                strongSelf.navigationController?.pushViewController(nextVC, animated: true)
            })
            options.append(manageAdminsOption)
        }
        return options
    }
    
    override func getMoreOptions() -> [AlertOption] {
        var options: [AlertOption] = []
        
        if let exportOption = getExportOption() {
            options.append(exportOption)
        }
        options.append(clearContentOption())
        if self.isOwner && self.groupType != .managed && self.groupType != .restricted {
            let deleteChatOption = AlertOption(title: DPAGLocalizedString("chat.group.button.delete"), style: .destructive, image: DPAGImageProvider.shared[.kDeleteLeft], textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "buttonDeleteChatContent", handler: { [weak self] in
                self?.handleDeletionButtonTapped(self)
            })
            options.append(deleteChatOption)
        } else {
            let leaveChatOption = AlertOption(title: DPAGLocalizedString("chat.group.button.leave"), style: .destructive, image: DPAGImageProvider.shared[.kArrowSquareUp], textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "buttonDeleteChatContent", handler: { [weak self] in
                self?.handleLeaveButtonTapped(self)
            })
            options.append(leaveChatOption)
        }
        return options
    }
    
    @objc
    private func handleLeaveButtonTapped(_: Any?) {
        let leaveGroup = AlertOption(title: DPAGLocalizedString("chat.list.action.confirm.leave.groupchat"),
                                     style: .destructive,
                                     accesibilityIdentifier: "chat.list.action.confirm.leave.groupchat",
                                     handler: { [weak self] in
                                         self?.handleLeaveConfirmed()
        })
        let cancel = AlertOption.cancelOption()
        let alertController = UIAlertController.controller(options: [leaveGroup, cancel], titleKey: "chat.list.title.confirm.leave.groupchat", withStyle: .alert)
        self.presentAlertController(alertController)
    }

    @objc
    private func handleDeletionButtonTapped(_: Any?) {
        let deleteGroup = AlertOption(title: DPAGLocalizedString("chat.list.action.confirm.delete.groupchat"),
                                      style: .destructive,
                                      accesibilityIdentifier: "chat.list.action.confirm.delete.groupchat",
                                      handler: { [weak self] in
                                          self?.handleDeletionConfirmed()
        })
        let cancel = AlertOption.cancelOption()
        let alertController = UIAlertController.controller(options: [deleteGroup, cancel], titleKey: "chat.list.title.confirm.delete.groupchat", withStyle: .alert)
        self.presentAlertController(alertController)
    }

    @objc
    private func handleLeaveConfirmed() {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            if let strongSelf = self {
                DPAGApplicationFacade.chatRoomWorker.removeSelfFromGroup(strongSelf.groupGuidAdmin) { _, _, errorMessage in
                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                        if let errorMessage = errorMessage {
                            self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                        } else {
                            _ = self?.navigationController?.popToRootViewController(animated: true)
                        }
                    }
                }
            }
        }
    }

    @objc
    private func handleDeletionConfirmed() {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            if let strongSelf = self {
                DPAGApplicationFacade.chatRoomWorker.removeRoom(strongSelf.groupGuidAdmin) { _, _, errorMessage in
                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                        if let strongSelf = self {
                            if errorMessage != nil {
                                strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "chat.group.alert.deletionFailed"))
                            } else {
                                strongSelf.navigationController?.popToRootViewController(animated: true)
                            }
                        }
                    }
                }
            }
        }
    }

    @objc
    func handleUpdateGroupTapped(_: Any?) {
        if self.needsUpdateMembers || self.needsGroupNameUpdate || self.needsGroupImageUpdate {
            let image: UIImage? =  self.needsGroupImageUpdate ? ( self.needsGroupImageUpdate ? imageViewGroup.image : DPAGHelperEx.image(forGroupGuid: groupGuidAdmin)) : nil
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self, image] _ in
                guard let strongSelf = self else {
                    DPAGProgressHUD.sharedInstance.hide(true)
                    return
                }
                let localImage = image
                let needsGroupDataUpdate = (strongSelf.needsGroupNameUpdate || strongSelf.needsGroupImageUpdate)
                if needsGroupDataUpdate || strongSelf.needsUpdateMembers {
                    let name = strongSelf.groupName ?? "Groupname"
                    let image = localImage
                    let memberGuids = strongSelf.members.compactMap { $0.guid } + strongSelf.admins.compactMap { $0.guid }
                    let adminGuids = strongSelf.admins.compactMap { $0.guid }
                    let memberGuidsOrg = strongSelf.membersOrg.compactMap { $0.guid } + strongSelf.adminsOrg.compactMap { $0.guid }
                    let adminGuidsOrg = strongSelf.adminsOrg.compactMap { $0.guid }
                    let newMembers = Set(strongSelf.findNewGuids(memberGuids, inCurrentGuids: memberGuidsOrg))
                    let removedMembers = Set(strongSelf.findRemovedGuids(memberGuids, inCurrentGuids: memberGuidsOrg))
                    let newAdmins = Set(strongSelf.findNewGuids(adminGuids, inCurrentGuids: adminGuidsOrg))
                    let removedAdmins = Set(strongSelf.findRemovedGuids(adminGuids, inCurrentGuids: adminGuidsOrg))
                    do {
                        try DPAGApplicationFacade.chatRoomWorker.updateGroup(config: DPAGChatRoomUpdateConfig(groupGuid: strongSelf.groupGuidAdmin, groupName: name, groupImage: image, newMembers: newMembers, removedMembers: removedMembers, newAdmins: newAdmins, removedAdmins: removedAdmins, updateGroupData: needsGroupDataUpdate, type: strongSelf.groupType)) { [weak self] _, _, errorMessage in
                            if errorMessage != nil {
                                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                                    self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "chat.group.alert.couldNotSaveChanges"))
                                }
                            } else if let groupGuidAdmin = self?.groupGuidAdmin {
                                self?.performBlockOnMainThread({ [weak self] in
                                    self?.navigationController?.popViewController(animated: true)
                                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                                        NotificationCenter.default.post(name: DPAGStrings.Notification.ChatStream.NEEDS_UPDATE, object: self, userInfo: [DPAGStrings.Notification.ChatStream.NEEDS_UPDATE__USERINFO_KEY__STREAM_GUID: groupGuidAdmin])
                                    }
                                })
                            } else {
                                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                                    self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "Invalid response"))
                                }
                            }
                        }
                    } catch {
                        DPAGLog(error)
                    }
                }
            }
        } else {
            _ = self.navigationController?.popViewController(animated: true)
        }
    }

    override func textFieldDidEndEditing(_ textField: UITextField) {
        super.textFieldDidEndEditing(textField)
        if (self.groupName?.isEmpty ?? true) == false {
            self.needsGroupNameUpdate = (self.groupNameOrg != self.groupName)
        }
    }

    override func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let retVal = super.textField(textField, shouldChangeCharactersIn: range, replacementString: string)
        if (self.groupName?.isEmpty ?? true) == false {
            self.needsGroupNameUpdate = (self.groupNameOrg != self.groupName)
        }
        return retVal
    }

    private func findRemovedGuids(_ updatedGuids: [String], inCurrentGuids currentGuids: [String]) -> [String] { currentGuids.filter { updatedGuids.contains($0) == false } }
    private func findNewGuids(_ updatedGuids: [String], inCurrentGuids currentGuids: [String]) -> [String] { updatedGuids.filter { currentGuids.contains($0) == false } }
}
