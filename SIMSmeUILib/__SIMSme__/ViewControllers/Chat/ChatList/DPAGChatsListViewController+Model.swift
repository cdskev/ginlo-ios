//
//  DPAGChatsListViewController+Model.swift
//  SIMSme
//
//  Created by RBU on 07/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

extension DPAGChatsListViewController {
    func showStreamInfoWithGuid(_ streamGuid: String) {
        guard let stream = DPAGApplicationFacade.cache.decryptedStream(streamGuid: streamGuid, in: nil) else { return }
        if let privateStream = stream as? DPAGDecryptedStreamPrivate, let contactGuid = privateStream.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid), contact.isConfirmed {
            let nextVC = DPAGApplicationFacadeUIContacts.contactDetailsVC(contact: contact)
            nextVC.pushedFromChats = true
            DPAGApplicationFacadeUIBase.containerVC.pushSecondaryViewController(nextVC, animated: true)
//            self.navigationController?.pushViewController(nextVC, animated: true)
        } else if stream is DPAGDecryptedStreamGroup, let group = DPAGApplicationFacade.cache.group(for: streamGuid), group.isConfirmed {
            let nextVC = DPAGApplicationFacadeUI.groupEditVC(groupGuid: streamGuid)
            DPAGApplicationFacadeUIBase.containerVC.pushSecondaryViewController(nextVC, animated: true)
//            self.navigationController?.pushViewController(nextVC, animated: true)
        } else if let channelStream = stream as? DPAGDecryptedStreamChannel {
            if channelStream.feedType == .channel {
                if let nextVC = DPAGApplicationFacadeUI.channelDetailsVC(channelGuid: streamGuid, category: nil) {
                    DPAGApplicationFacadeUIBase.containerVC.pushSecondaryViewController(nextVC, animated: true)
//                    self.navigationController?.pushViewController(nextVC, animated: true)
                }
            }
        }
    }

    func scanContactWithStreamGuid(_ streamGuid: String) {
        guard let privateStream = DPAGApplicationFacade.cache.decryptedStream(streamGuid: streamGuid, in: nil) as? DPAGDecryptedStreamPrivate, let contactGuid = privateStream.contactGuid else { return }
        let nextVC = DPAGApplicationFacadeUIContacts.scanProfileVC(contactGuid: contactGuid, blockSuccess: { [weak self] in
            if let strongSelf = self {
                _ = strongSelf.navigationController?.popToViewController(strongSelf, animated: true)
            }
        }, blockFailed: { [weak self] in
            self?.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: "contacts.error.verifyingContactByQRCodeFailed") { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.navigationController?.popToViewController(strongSelf, animated: true)
            })
        }, blockCancelled: {})
        DPAGApplicationFacadeUIBase.containerVC.pushSecondaryViewController(nextVC, animated: true)
//        self.navigationController?.pushViewController(nextVC, animated: true)
    }

    func clearStreamWithGuid(_ streamGuid: String) {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
            DPAGApplicationFacade.contactsWorker.emptyStreamWithGuid(streamGuid)
            DPAGProgressHUD.sharedInstance.hide(true)
        }
    }
    
    func deleteStreamWithGuid(_ streamGuid: String) {
        if streamGuid.hasPrefix(.streamGroup) {
            if let group = DPAGApplicationFacade.cache.group(for: streamGuid) {
                if group.guidOwner == DPAGApplicationFacade.cache.account?.guid {
                    self.deleteGroupStream(streamGuid)
                } else {
                    self.leaveGroupStream(streamGuid)
                }
            }
        } else if streamGuid.hasPrefix(.streamChannel) {
            self.deleteChannelStream(streamGuid)
        } else if streamGuid.hasPrefix(.streamService) {
            self.deleteChannelStream(streamGuid)
        } else {
            self.deletePrivateStream(streamGuid)
        }
    }

    func deleteGroupStream(_ streamGuid: String) {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            DPAGApplicationFacade.chatRoomWorker.removeRoom(streamGuid) { [weak self] _, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    if let errorMessage = errorMessage {
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                    }
                }
            }
        }
    }

    func leaveGroupStream(_ streamGuid: String) {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
            DPAGApplicationFacade.chatRoomWorker.removeSelfFromGroup(streamGuid) { _, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    if let errorMessage = errorMessage {
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                    }
                }
            }
        }
    }

    func deletePrivateStream(_ streamGuid: String) {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
            DPAGApplicationFacade.contactsWorker.deletePrivateStream(streamGuid: streamGuid, syncWithServer: true) { _, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    if let errorMessage = errorMessage {
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                    }
                }
            }
        }
    }

    func deleteChannelStream(_ streamGuid: String) {
        guard let stream = DPAGApplicationFacade.cache.decryptedStream(streamGuid: streamGuid) as? DPAGDecryptedStreamChannel else { return }
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            DPAGApplicationFacade.feedWorker.unsubscribeFeed(feedGuid: streamGuid, feedType: stream.feedType) { _, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    if let errorMessage = errorMessage {
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                    }
                    NotificationCenter.default.post(name: DPAGStrings.Notification.Menu.MENU_NEW_REINIT, object: nil)
                }
            }
        }
    }

    func exportStreamWithStreamGuid(_ streamGuid: String) {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
            if let fileURLTemp = DPAGApplicationFacade.messageWorker.exportStreamToURLWithStreamGuid(streamGuid) {
                self.fileURLTemp = fileURLTemp
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    if let strongSelf = self {
                        let activityVC = DPAGActivityViewController(activityItems: [fileURLTemp], applicationActivities: nil)
                        activityVC.completionWithItemsHandler = { [weak self] _, _, _, _ in
                            self?.cleanUpExportFiles()
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

    private func cleanUpExportFiles() {
        if let fileURLTemp = self.fileURLTemp {
            do {
                try FileManager.default.removeItem(at: fileURLTemp)
            } catch {
                DPAGLog(error)
            }
            self.fileURLTemp = nil
        }
    }

    func showGroupChat(_ streamGuid: String) {
        if let group = DPAGApplicationFacade.cache.group(for: streamGuid) {
            let streamVC = DPAGApplicationFacadeUI.chatGroupStreamVC(stream: streamGuid, streamState: group.streamState)
            DPAGApplicationFacadeUIBase.containerVC.pushSecondaryViewController(streamVC, animated: true)
//            self.navigationController?.pushViewController(streamVC, animated: true)
        }
    }

    func handleDenyInvitationTapped(_ cell: UITableViewCell & DPAGChatOverviewBaseCellProtocol) {
        guard let indexPath = self.tableView.indexPath(for: cell) else { return }
        guard let stream = self.streamForIndexPath(indexPath) else { return }
        let optionReject = AlertOption(title: DPAGLocalizedString("chat.list.action.confirm.deny.invitation"), style: .destructive, accesibilityIdentifier: "chat.list.action.confirm.deny.invitation") { [weak self] in
            self?.handleDenyInvitationConfirmedWithGuid(stream.guid)
        }
        let optionCancel = AlertOption(title: DPAGLocalizedString("res.cancel"), style: .cancel, textAlignment: nil)
        let alertOptions = [optionReject, optionCancel]
        let alertController = UIAlertController.controller(options: alertOptions, titleKey: "chat.list.title.confirm.deny.invitation", withStyle: .alert)
        self.presentAlertController(alertController)
    }

    func handleBlockContactTapped(_ cell: UITableViewCell & DPAGChatOverviewBaseCellProtocol) {
        guard let indexPath = self.tableView.indexPath(for: cell) else { return }
        guard let stream = self.streamForIndexPath(indexPath) else { return }
        let optionBlock = AlertOption(title: DPAGLocalizedString("chat.list.action.confirm.block.contact"), style: .destructive, accesibilityIdentifier: "chat.list.action.confirm.block.contact") { [weak self] in
            self?.handleBlockContactConfirmedWithGuid(stream.guid)
        }
        let optionCancel = AlertOption(title: DPAGLocalizedString("res.cancel"), style: .cancel, textAlignment: nil)
        let alertOptions = [optionBlock, optionCancel]
        let alertController = UIAlertController.controller(options: alertOptions, titleKey: "chat.list.title.confirm.block.contact", withStyle: .alert)
        self.presentAlertController(alertController)
    }

    func handleDenyInvitationConfirmedWithGuid(_ streamGuid: String) {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
            DPAGApplicationFacade.chatRoomWorker.declineInvitationForRoom(streamGuid) { [weak self] _, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    if let errorMessage = errorMessage {
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                    }
                }
            }
        }
    }

    private func handleConfirmInvitationTapped(_ cell: UITableViewCell & DPAGChatOverviewBaseCellProtocol) {
        guard let indexPath = self.tableView.indexPath(for: cell) else { return }
        guard let stream = self.streamForIndexPath(indexPath) else { return }
        let cell = self.tableView.cellForRow(at: indexPath) as? (UITableViewCell & DPAGChatGroupConfirmInvitationCellProtocol)
        self.startLoadingAnimation(cell, stream: stream)
        let streamGuid = stream.guid
        self.performBlockInBackground { [weak cell, weak self] in
            DPAGApplicationFacade.chatRoomWorker.acceptInvitationForRoom(streamGuid) { [weak self] _, _, errorMessage in
                if let errorMessage = errorMessage {
                    self?.performBlockOnMainThread { [weak self] in
                        self?.stopLoadingAnimation(cell)
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                    }
                } else {
                    var streamFound = false
                    var streamState: DPAGChatStreamState = .readOnly
                    if let group = DPAGApplicationFacade.cache.group(for: streamGuid) {
                        streamFound = true
                        streamState = group.streamState
                    }
                    if streamFound {
                        self?.performBlockOnMainThread { [weak self] in
                            let streamVC = DPAGApplicationFacadeUI.chatGroupStreamVC(stream: streamGuid, streamState: streamState)
                            self?.performBlockInBackground { [weak self] in
                                streamVC.createModel()
                                self?.performBlockOnMainThread { [weak cell, weak self] in
                                    self?.stopLoadingAnimation(cell)
                                    DPAGApplicationFacadeUIBase.containerVC.pushSecondaryViewController(streamVC, animated: true)
//                                    self?.navigationController?.pushViewController(streamVC, animated: true)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func handleBlockContactConfirmedWithGuid(_ streamGuid: String) {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
            DPAGApplicationFacade.contactsWorker.blockContactStream(streamGuid: streamGuid) { [weak self] _, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    if let errorMessage = errorMessage {
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                    }
                }
            }
            DPAGApplicationFacade.contactsWorker.setChatDeleted(streamGuid: streamGuid) { _, _, _ in }
        }
    }

    private func handleConfirmContactTapped(_ cell: UITableViewCell & DPAGChatOverviewBaseCellProtocol) {
        guard let indexPath = self.tableView.indexPath(for: cell) else { return }
        guard let decryptedStream = self.streamForIndexPath(indexPath) as? DPAGDecryptedStreamPrivate, let contactGuid = decryptedStream.contactGuid else { return }
        var streamState: DPAGChatStreamState = .readOnly
        self.startLoadingAnimation(cell, stream: decryptedStream)
        let blockOpenChat = {
            self.performBlockInBackground { [weak cell, weak self] in
                let chatInfo = DPAGApplicationFacade.contactsWorker.openChat(withContactGuid: contactGuid)
                streamState = chatInfo.streamState
                self?.performBlockOnMainThread { [weak self] in
                    let streamVC = DPAGApplicationFacadeUI.chatStreamVC(stream: decryptedStream.guid, streamState: streamState)
                    self?.performBlockInBackground {
                        streamVC.createModel()
                        self?.performBlockOnMainThread { [weak cell, weak self] in
                            self?.stopLoadingAnimation(cell)
                            DPAGApplicationFacadeUIBase.containerVC.pushSecondaryViewController(streamVC, animated: true)
                            // self?.navigationController?.pushViewController(streamVC, animated: true)
                            if self?.tableView.numberOfRows(inSection: indexPath.section) ?? 0 > indexPath.row {
                                self?.tableView.reloadRows(at: [indexPath], with: .automatic)
                            }
                        }
                    }
                }
                DPAGSendInternalMessageWorker.sendProfileToContacts([contactGuid])
            }
        }

        if let contact = DPAGApplicationFacade.cache.contact(for: contactGuid), contact.publicKey?.isEmpty ?? true {
            DPAGApplicationFacade.updateKnownContactsWorker.synchronize(accountGuid: contactGuid) { [weak self] _, _, errorMessage in
                if let errorMessage = errorMessage {
                    if let strongSelf = self {
                        var errorMessageFormated: String?
                        if errorMessage == "service.ERR-0007" {
                            strongSelf.deletePrivateStream(decryptedStream.guid)
                            if let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
                                let content = String(format: DPAGLocalizedString("chat.single.alert.message.contact_deleted"), contact.displayName, DPAGMandant.default.name)
                                errorMessageFormated = content
                            }
                        } else {
                            errorMessageFormated = DPAGLocalizedString(errorMessage)
                        }
                        strongSelf.performBlockOnMainThread { [weak cell, weak self] in
                            self?.stopLoadingAnimation(cell)
                            if let errorMessageFormated = errorMessageFormated {
                                strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessageFormated, accessibilityIdentifier: errorMessage))
                            }
                        }
                    }
                } else {
                    _ = DPAGApplicationFacade.cache.refreshDecryptedStream(streamGuid: decryptedStream.guid)
                    self?.performBlockOnMainThread(blockOpenChat)
                }
            }
            return
        }
        blockOpenChat()
    }

    // MARK: iPad-Support
    
    func openStream(_ tableView: UITableView, stream: DPAGDecryptedStream, indexPath: IndexPath) {
        _ = self.searchController?.searchBar.resignFirstResponder()
        var vcStream: (UIViewController & DPAGChatStreamBaseViewControllerProtocol)?
        if let privateStream = stream as? DPAGDecryptedStreamPrivate {
            if privateStream.isSystemChat {
                vcStream = DPAGApplicationFacadeUI.chatStreamVC(stream: privateStream.guid, streamState: .readOnly)
            } else if let contactGuid = privateStream.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid), contact.isConfirmed {
                if contact.isDeleted {
                    DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
                        DPAGApplicationFacade.updateKnownContactsWorker.getAccountInfo(accountGuid: contactGuid, withProfile: true, withTempDevice: true) { _, _, errorMessage in
                            if errorMessage == nil {
                                contact.setIsDeleted(false)
                                DPAGApplicationFacade.contactsWorker.unDeleteContact(withContactGuid: contactGuid)
                            }
                            self?.performBlockOnMainThread {
                                let vc = DPAGApplicationFacadeUI.chatStreamVC(stream: privateStream.guid, streamState: contact.streamState)
                                DPAGProgressHUD.sharedInstance.hide(true)
                                self?.openStreamViewController(tableView, nextVC: vc, stream: stream, indexPath: indexPath)
                            }
                        }
                    }
                    return
                }
                vcStream = DPAGApplicationFacadeUI.chatStreamVC(stream: privateStream.guid, streamState: contact.streamState)
            }
        } else if let groupStream = stream as? DPAGDecryptedStreamGroup, let group = DPAGApplicationFacade.cache.group(for: groupStream.guid), group.isConfirmed {
            vcStream = DPAGApplicationFacadeUI.chatGroupStreamVC(stream: groupStream.guid, streamState: groupStream.streamState)
        } else if let channelStream = stream as? DPAGDecryptedStreamChannel {
            switch channelStream.feedType {
                case .channel:
                    vcStream = DPAGApplicationFacadeUI.channelStreamVC(stream: channelStream.guid, streamState: .readOnly)
                case .service:
                    vcStream = DPAGApplicationFacadeUI.serviceStreamVC(stream: channelStream.guid, streamState: .readOnly)
            }
        }
        guard let nextVC = vcStream else { return }
        self.openStreamViewController(tableView, nextVC: nextVC, stream: stream, indexPath: indexPath)
    }

    private func openStreamViewController(_ tableView: UITableView, nextVC: UIViewController & DPAGChatStreamBaseViewControllerProtocol, stream: DPAGDecryptedStream, indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) as? (UITableViewCell & DPAGChatOverviewConfirmedBaseCellProtocol) {
            self.startLoadingAnimation(cell, stream: stream)
            self.performBlockInBackground { [weak cell, weak self] in
                nextVC.createModel()
                self?.performBlockOnMainThread { [weak cell, weak self] in
                    self?.stopLoadingAnimation(cell)
                    DPAGApplicationFacadeUIBase.containerVC.pushSecondaryViewController(nextVC, animated: true)
                }
            }
        } else {
            nextVC.createModel()
            DPAGApplicationFacadeUIBase.containerVC.pushSecondaryViewController(nextVC, animated: true)
        }
    }

    private func startLoadingAnimation(_ cell: DPAGChatOverviewBaseCellProtocol?, stream: DPAGDecryptedStream) {
        self.loadingChatGuid = stream.guid
        cell?.setAnimating(true)
        AppConfig.appWindow()??.isUserInteractionEnabled = false
    }

    private func stopLoadingAnimation(_ cell: DPAGChatOverviewBaseCellProtocol?) {
        self.loadingChatGuid = nil
        cell?.setAnimating(false)
        AppConfig.appWindow()??.isUserInteractionEnabled = true
    }
}

extension DPAGChatsListViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerDidDismissOpenInMenu(_: UIDocumentInteractionController) {
        if self.openInControllerOpensApplication == false {
            self.cleanUpExportFiles()
        }
    }

    func documentInteractionController(_: UIDocumentInteractionController, willBeginSendingToApplication _: String?) {
        self.openInControllerOpensApplication = true
    }

    func documentInteractionController(_: UIDocumentInteractionController, didEndSendingToApplication _: String?) {
        self.cleanUpExportFiles()
    }
}

extension DPAGChatsListViewController: DPAGChatCellConfirmDelegate {
    func handleDenyWithCell(_ cell: UITableViewCell & DPAGChatOverviewNotConfirmedBaseCellProtocol) {
        if cell is DPAGChatContactConfirmCellProtocol {
            self.handleBlockContactTapped(cell)
        } else {
            self.handleDenyInvitationTapped(cell)
        }
    }

    func handleConfirmWithCell(_ cell: UITableViewCell & DPAGChatOverviewNotConfirmedBaseCellProtocol) {
        if cell is DPAGChatContactConfirmCellProtocol {
            self.handleConfirmContactTapped(cell)
        } else {
            self.handleConfirmInvitationTapped(cell)
        }
    }
}
