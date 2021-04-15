//
//  DPAGGroupChatStreamViewController.swift
//  SIMSme
//
//  Created by RBU on 10/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import SIMSmeCore
import UIKit

class DPAGGroupChatStreamViewController: DPAGChatStreamBaseViewController, DPAGSendingDelegate, UITableViewDataSource, UITableViewDelegate, DPAGNavigationViewControllerStyler {
    init(stream streamGuid: String, streamState: DPAGChatStreamState) {
        super.init(streamGuid: streamGuid, streamState: streamState)
        self.showsInputController = (streamState == .write)
        self.sendingDelegate = self
    }
    
    private var navBarImage: UIImage?
    
    override func viewDidLoad() {
        var colorConfidence: UIColor?
        if let ownAccountGuid = DPAGApplicationFacade.cache.account?.guid, let group = DPAGApplicationFacade.cache.group(for: self.streamGuid) {
            if group.groupType == .restricted {
                if group.isReadOnly {
                    self.showsInputController = false
                }
            }
            if group.groupType == .announcement && !group.adminGuids.contains(ownAccountGuid) {
                self.showsInputController = false
            }
            let navbarImage = DPAGImageProvider.shared[.kImageBarButtonNavGroup]
            if group.groupType != .restricted, group.isDeleted == false {
                if group.adminGuids.contains(ownAccountGuid) {
                    self.rightBarButtonItem = UIBarButtonItem(image: navbarImage, style: .plain, target: self, action: #selector(DPAGGroupChatStreamViewController.handleAdministrateChatRoomTapped))
                    self.rightBarButtonItem?.accessibilityLabel = DPAGLocalizedString("chat.group.administration.title")
                    self.rightBarButtonItem?.accessibilityIdentifier = "chat.group.administration.title"
                } else {
                    self.rightBarButtonItem = UIBarButtonItem(image: navbarImage, style: .plain, target: self, action: #selector(DPAGGroupChatStreamViewController.handleAboutChatRoomTapped))
                    self.rightBarButtonItem?.accessibilityLabel = DPAGLocalizedString("chat.list.action.showInfo.group")
                    self.rightBarButtonItem?.accessibilityIdentifier = "chat.list.action.showInfo.group"
                }
            } else if group.groupType == .restricted, group.isDeleted == false {
                self.rightBarButtonItem = UIBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavGroupSetSilent], style: .plain, target: self, action: #selector(DPAGGroupChatStreamViewController.handlePushSilentChatRoomTapped))
                self.rightBarButtonItem?.accessibilityLabel = DPAGLocalizedString("chat.info.labelSilent")
                self.rightBarButtonItem?.accessibilityIdentifier = "chat.info.labelSilent"
            } else {
                self.rightBarButtonItem = nil
                self.wasDeleted = group.isDeleted
            }
            if group.confidenceState != .none {
                colorConfidence = UIColor.confidenceStatusToColor(group.confidenceState)
            }
        }
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(groupConfidenceStateChanged(_:)), name: DPAGStrings.Notification.Group.CONFIDENCE_UPDATED, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(contactChanged(_:)), name: DPAGStrings.Notification.Contact.CHANGED, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(groupWasDeleted(_:)), name: DPAGStrings.Notification.Group.WAS_DELETED, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleStreamNeedsUpdate(_:)), name: DPAGStrings.Notification.ChatStream.NEEDS_UPDATE, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(groupChanged(_:)), name: DPAGStrings.Notification.Group.CHANGED, object: nil)
        self.setup()
        if let colorConfidence = colorConfidence, colorConfidence != UIColor.clear {
            self.addConfidenceView()
        }
        DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation = nil
        let groupGuid = self.streamGuid
        self.performBlockInBackground {
            DPAGApplicationFacade.chatRoomWorker.checkGroupSynchronization(forGroup: groupGuid, force: true, notify: true)
        }
    }
    
    // NUMVOIP
    override func shouldAddVoipButtons() -> Bool {
        if AppConfig.isVoipActive && AppConfig.isVoipGroupCallAllowed, self.showsInputController, let group = DPAGApplicationFacade.cache.group(for: self.streamGuid) {
            return AppConfig.voipMaxGroupMembers >= (group.memberGuids.count + group.adminGuids.count)
        }
        return false
    }

    @objc
    func handleStreamNeedsUpdate(_ aNotification: Notification) {
        if ((aNotification.object as? UIViewController) === self) == false, let streamGuid = aNotification.userInfo?[DPAGStrings.Notification.ChatStream.NEEDS_UPDATE__USERINFO_KEY__STREAM_GUID] as? String, streamGuid == self.streamGuid {
            self.performBlockOnMainThread { [weak self] in
                guard let strongSelf = self else { return }
                let oldInputState = strongSelf.showsInputController
                strongSelf.updateInputStateAnimated(false)
                var colorConfidence: UIColor = .clear
                if let ownAccountGuid = DPAGApplicationFacade.cache.account?.guid, let group = DPAGApplicationFacade.cache.group(for: strongSelf.streamGuid) {
                    let navbarImage = DPAGImageProvider.shared[.kImageBarButtonNavGroup]
                    if group.groupType != .restricted, group.isDeleted == false {
                        if group.adminGuids.contains(ownAccountGuid) {
                            strongSelf.rightBarButtonItem = UIBarButtonItem(image: navbarImage, style: .plain, target: strongSelf, action: #selector(DPAGGroupChatStreamViewController.handleAdministrateChatRoomTapped))
                            strongSelf.rightBarButtonItem?.accessibilityLabel = DPAGLocalizedString("chat.group.administration.title")
                            strongSelf.rightBarButtonItem?.accessibilityIdentifier = "chat.group.administration.title"
                        } else {
                            strongSelf.rightBarButtonItem = UIBarButtonItem(image: navbarImage, style: .plain, target: strongSelf, action: #selector(DPAGGroupChatStreamViewController.handleAboutChatRoomTapped))
                            strongSelf.rightBarButtonItem?.accessibilityLabel = DPAGLocalizedString("chat.list.action.showInfo.group")
                            strongSelf.rightBarButtonItem?.accessibilityIdentifier = "chat.list.action.showInfo.group"
                        }
                    } else if group.groupType == .restricted, group.isDeleted == false {
                        strongSelf.rightBarButtonItem = UIBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavGroupSetSilent], style: .plain, target: self, action: #selector(DPAGGroupChatStreamViewController.handlePushSilentChatRoomTapped))
                        strongSelf.rightBarButtonItem?.accessibilityLabel = DPAGLocalizedString("chat.info.labelSilent")
                        strongSelf.rightBarButtonItem?.accessibilityIdentifier = "chat.info.labelSilent"
                    } else {
                        strongSelf.rightBarButtonItem = nil
                    }
                    strongSelf.updateRightBarButtonItems(timedMessagesCount: strongSelf.timedMessagesCount)
                    if group.confidenceState != .none {
                        strongSelf.title = group.name
                        colorConfidence = UIColor.confidenceStatusToColor(group.confidenceState)
                    }
                }
                strongSelf.navigationSeparator?.backgroundColor = colorConfidence
                let silentTillString = aNotification.userInfo?[DPAGStrings.Notification.ChatStream.NEEDS_UPDATE__USERINFO_KEY__PUSH_SILENT_TILL] as? String ?? ""
                let silentTillDate = DPAGFormatter.dateServer.date(from: silentTillString)
                self?.silentHelper.currentSilentState = SetSilentHelper.silentStateFor(silentDate: silentTillDate)
                if oldInputState != strongSelf.showsInputController {
                    strongSelf.shouldUsePreferredSizes = false
                    strongSelf.tableView.reloadData()
                    strongSelf.shouldUsePreferredSizes = true
                }
            }
        }
    }

    override func onSilentStateChanged() {
        self.updateRightBarButton()
    }

    func updateRightBarButton() {
        guard case SilentState.none = self.silentHelper.currentSilentState else {
            self.rightBarButtonItem?.image = DPAGImageProvider.shared[.kImageBarButtonNavContactSilent]
            self.rightBarButtonItem?.tintColor = DPAGColorProvider.shared[.muteActive]
            return
        }
        if let group = DPAGApplicationFacade.cache.group(for: self.streamGuid), group.groupType == .restricted {
            self.rightBarButtonItem?.image = DPAGImageProvider.shared[.kImageBarButtonNavGroupSetSilent]
        } else {
            self.rightBarButtonItem?.image = DPAGImageProvider.shared[.kImageBarButtonNavGroup]
            self.rightBarButtonItem?.tintColor = DPAGColorProvider.shared[.navigationBarTint]
        }
    }
    
    override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        if let rightBarButtonItems = self.navigationItem.rightBarButtonItems {
            for item in rightBarButtonItems {
                item.tintColor = DPAGColorProvider.shared[.navigationBarTint]
            }
        }
        switch self.silentHelper.currentSilentState {
            case .date, .permanent:
                self.rightBarButtonItem?.tintColor = DPAGColorProvider.shared[.muteActive]
            default:
                self.rightBarButtonItem?.tintColor = DPAGColorProvider.shared[.navigationBarTint]
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.state != .write || self.cameFromChatList {
            self.updateInputStateAnimated(false)
        }
        var colorConfidence = UIColor.clear
        if let group = DPAGApplicationFacade.cache.group(for: self.streamGuid) {
            self.title = group.name
            if group.confidenceState != .none {
                colorConfidence = UIColor.confidenceStatusToColor(group.confidenceState)
            }
        }
        self.transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
            if let strongSelf = self, let navigationController = strongSelf.navigationController as? (UINavigationController & DPAGNavigationControllerProtocol) {
                strongSelf.navigationSeparator?.backgroundColor = colorConfidence
                strongSelf.navigationProcessActivityIndicator?.color = navigationController.navigationBar.tintColor
                strongSelf.navigationProcessDescription?.textColor = navigationController.navigationBar.tintColor
                strongSelf.navigationTitle?.textColor = navigationController.navigationBar.tintColor
            }
        }, completion: { [weak self] context in
            guard let strongSelf = self else { return }
            if context.isCancelled == false {
                strongSelf.updateInputStateIfInputDisabledAndForceDisabled(false, forceEnabledIfNotConfirmed: false)
            }
        })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let doUpdateInput = self.inputController?.inputDisabled ?? true
        if doUpdateInput {
            self.updateInputStateAnimated(false)
        }
        var colorConfidence = UIColor.clear
        if let group = DPAGApplicationFacade.cache.group(for: self.streamGuid), group.confidenceState != .none {
            colorConfidence = UIColor.confidenceStatusToColor(group.confidenceState)
        }
        if let navigationController = self.navigationController as? (UINavigationController & DPAGNavigationControllerProtocol) {
            self.navigationSeparator?.backgroundColor = colorConfidence
            self.navigationProcessActivityIndicator?.color = navigationController.navigationBar.tintColor
            self.navigationProcessDescription?.textColor = navigationController.navigationBar.tintColor
            self.navigationTitle?.textColor = navigationController.navigationBar.tintColor
        }
        let groupGuid = self.streamGuid
        self.performBlockInBackground {
            DPAGApplicationFacade.chatRoomWorker.checkGroupSynchronization(forGroup: groupGuid, force: true, notify: true)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    @objc
    func groupConfidenceStateChanged(_ aNotification: Notification) {
        if let newStatus = aNotification.userInfo?[DPAGStrings.Notification.Group.CONFIDENCE_UPDATED__USERINFO_KEY__NEW_STATE] as? NSNumber, let groupGuid = aNotification.userInfo?[DPAGStrings.Notification.Group.CONFIDENCE_UPDATED__USERINFO_KEY__GROUP_GUID] as? String {
            if groupGuid == self.streamGuid, let confidenceState = DPAGConfidenceState(rawValue: newStatus.uintValue) {
                self.performBlockOnMainThread { [weak self] in
                    let colorConfidence = UIColor.confidenceStatusToColor(confidenceState)
                    UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: { [weak self] in
                        self?.navigationSeparator?.backgroundColor = colorConfidence
                    })
                    self?.tableView.reloadData()
                }
            }
        }
    }

    @objc
    func contactChanged(_ aNotification: Notification) {
        if let contactGuid = aNotification.userInfo?[DPAGStrings.Notification.Contact.CHANGED__USERINFO_KEY__CONTACT_GUID] as? String {
            if let group = DPAGApplicationFacade.cache.group(for: self.streamGuid) {
                if group.memberGuids.contains(contactGuid) {
                    self.imgCache.removeValue(forKey: contactGuid)
                    self.performBlockOnMainThread { [weak self] in
                        self?.tableView.reloadData()
                    }
                }
            }
        }
    }

    @objc
    func groupWasDeleted(_ aNotification: Notification) {
        if let groupGuid = aNotification.userInfo?[DPAGStrings.Notification.Group.WAS_DELETED__USERINFO_KEY__GROUP_GUID] as? String, self.streamGuid == groupGuid {
            self.performBlockOnMainThread { [weak self] in
                self?.updateInputStateAnimated(false, forceDisabled: true)
            }
        }
    }

    @objc
    func groupChanged(_ aNotification: Notification) {
        if let groupGuid = aNotification.userInfo?[DPAGStrings.Notification.Group.CHANGED__USERINFO_KEY__GROUP_GUID] as? String, self.streamGuid == groupGuid {
            self.performBlockOnMainThread { [weak self] in
                self?.tableView.reloadData()
            }
        }
    }

    @objc
    func handlePushSilentChatRoomTapped() {
        let nextVC = DPAGApplicationFacadeUIContacts.setSilentVC(setSilentHelper: self.silentHelper)
        self.navigationController?.pushViewController(nextVC, animated: true)
    }

    @objc
    func handleAboutChatRoomTapped() {
        let nextVC = DPAGApplicationFacadeUI.groupEditVC(groupGuid: self.streamGuid)
        self.navigationController?.pushViewController(nextVC, animated: true)
    }

    @objc
    func handleAdministrateChatRoomTapped() {
        let nextVC = DPAGApplicationFacadeUI.groupEditVC(groupGuid: self.streamGuid)
        self.navigationController?.pushViewController(nextVC, animated: true)
    }

    override func handleMessageSendFailed(_ errorMessage: String?) {
        super.handleMessageSendFailed(errorMessage)
        if errorMessage == DPAGStrings.ErrorCode.GROUP_DELETED {
            DPAGApplicationFacade.chatRoomWorker.setGroupRemotelyDeleted(groupGuid: self.streamGuid)
            self.performBlockOnMainThread { [weak self] in
                self?.updateInputStateAnimated(false, forceDisabled: true)
            }
        }
    }

    override func updateNewMessagesCountAndBadge() {
        self.updateNewMessagesCountAndBadge(-1)
    }

    func getRecipients() -> [DPAGSendMessageRecipient] {
        [DPAGSendMessageRecipient(recipientGuid: self.streamGuid)]
    }

    override func openInfoForMessage(_ message: DPAGDecryptedMessage) {
        let nextVC = DPAGApplicationFacadeUI.messageReceiverInfoGroupVC(decMessage: message, streamGuid: self.streamGuid, streamState: self.state)
        nextVC.sendingDelegate = self
        self.reloadOnAppear = true
        self.navigationController?.pushViewController(nextVC, animated: true)
    }

    func isEditingEnabled() -> Bool { DPAGApplicationFacade.chatRoomWorker.isEditingEnabled(groupGuid: self.streamGuid) }

    func loadSilentTill() {
        let groupGuid = self.streamGuid
        DPAGApplicationFacade.chatRoomWorker.readGroupSilentTill(groupGuid: groupGuid) { responseObject, _, errorMessage in
            if errorMessage == nil {
                self.silentHelper.currentSilentState = SetSilentHelper.silentStateFor(silentDate: responseObject as? Date)
            }
        }
    }
}
