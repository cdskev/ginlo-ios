//
//  DPAGChatStreamDelegate.swift
// ginlo
//
//  Created by RBU on 09/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import ContactsUI
import CoreData
import CoreLocation
import SIMSmeCore
import UIKit

struct DPAGMessageRecoveryAction: OptionSet {
    let rawValue: Int
    init(rawValue: Int) { self.rawValue = rawValue }

    static let open = DPAGMessageRecoveryAction(rawValue: 1)
    static let resend = DPAGMessageRecoveryAction(rawValue: 2)
}

enum DPAGMessageRecoveryActionSelected: Int {
    case none,
        open,
        resend
}

extension DPAGChatCellBaseViewController: DPAGChatStreamDelegate {
    @discardableResult
    func resignFirstTextResponder() -> Bool {
        self.inputController?.resignFirstResponder() ?? true
    }

    func loadAttachmentWithMessage(_ decryptedMessage: DPAGDecryptedMessage, cell cellWithProgress: DPAGCellWithProgress?, completion: @escaping ((Data?, String?) -> Void)) {
        let savedAttachment = AttachmentHelper.attachmentAlreadySavedForGuid(decryptedMessage.attachmentGuid)
        if savedAttachment == false, decryptedMessage.isOwnMessage, decryptedMessage.dateDownloaded != nil {
            if self.messagesLoading.contains(decryptedMessage.messageGuid) {
                completion(nil, "service.attachement.is-downloading")
            } else {
                completion(nil, "service.ERR-0026")
            }
        } else if savedAttachment {
            if let attachment = decryptedMessage.decryptedAttachment {
                DPAGAttachmentWorker.decryptMessageAttachment(attachment: attachment) { data, errorMessage in
                    if let progressCell = cellWithProgress {
                        progressCell.hideWorkInProgress()

                        if (progressCell is DPAGVoiceMessageCellProtocol) == false {
                            decryptedMessage.markDecryptedMessageAsReadAttachment()
                        }
                        completion(data, errorMessage)
                    } else {
                        decryptedMessage.markDecryptedMessageAsReadAttachment()
                        completion(data, errorMessage)
                    }
                }
            } else {
                completion(nil, "chat.encryption.hashInvalid")
            }
        } else if let cellWithProgressInt = cellWithProgress {
            cellWithProgressInt.showWorkInProgress()
            decryptedMessage.attachmentProgress = 0
            decryptedMessage.cellWithProgress = cellWithProgressInt
            let decryptedMessageMessageGuid = decryptedMessage.messageGuid
            self.messagesLoading.append(decryptedMessageMessageGuid)
            self.performBlockInBackground { [weak cellWithProgressInt, weak self] in
                DPAGAttachmentWorker.loadAttachment(decryptedMessage.attachmentGuid, forMessageGuid: decryptedMessage.messageGuid, progress: decryptedMessage.updateAttachmentProgress, withResponse: { [weak cellWithProgressInt, weak self] responseObject, _, errorMessage in
                    guard let strongSelf = self, cellWithProgressInt != nil else {
                        decryptedMessage.cellWithProgress = nil
                        return
                    }
                    let inCompleteBlock = {
                        DPAGAttachmentWorker.removeEncryptedAttachment(guid: decryptedMessage.attachmentGuid)
                        strongSelf.performBlockOnMainThread { [weak cellWithProgressInt, weak self] in
                            guard let strongSelf = self else { return }
                            if let idx = strongSelf.messagesLoading.firstIndex(of: decryptedMessageMessageGuid) {
                                strongSelf.messagesLoading.remove(at: idx)
                            }
                            cellWithProgressInt?.cancelWorkInProgress()
                            completion(nil, "chat.encryption.hashInvalid")
                        }
                    }
                    if errorMessage != nil {
                        strongSelf.performBlockOnMainThread { [weak cellWithProgressInt, weak self] in
                            guard self != nil, let strongCellWithProgress = cellWithProgressInt else { return }
                            strongCellWithProgress.cancelWorkInProgress()
                            completion(nil, errorMessage)
                        }
                    } else if responseObject as? String != nil, let attachment = decryptedMessage.decryptedAttachment {
                        DPAGAttachmentWorker.decryptMessageAttachment(attachment: attachment) { data, errorMessage in
                            if data != nil {
                                strongSelf.performBlockOnMainThread { [weak self] in
                                    guard let strongSelf = self, strongSelf.navigationController?.presentedViewController == nil, strongSelf.navigationController?.topViewController == strongSelf else { return }
                                    var cell: UITableViewCell?
                                    if let indexPathsForVisibleRows = strongSelf.tableView.indexPathsForVisibleRows {
                                        for idxPath in indexPathsForVisibleRows {
                                            if let msg = strongSelf.decryptedMessageForIndexPath(idxPath, returnUnknownDecMessage: true), msg.messageGuid == decryptedMessageMessageGuid {
                                                cell = strongSelf.tableView.cellForRow(at: idxPath)
                                                break
                                            }
                                        }
                                    }
                                    if let progressCell = cell as? DPAGCellWithProgress {
                                        progressCell.hideWorkInProgressWithCompletion({ [weak progressCell] in
                                            guard let strongSelf = self else { return }
                                            if strongSelf.messagesLoading.contains(decryptedMessageMessageGuid) {
                                                if (progressCell is DPAGVoiceMessageCellProtocol) == false {
                                                    decryptedMessage.markDecryptedMessageAsReadAttachment()
                                                }
                                                completion(data, errorMessage)
                                            }
                                            strongSelf.messagesLoading.removeAll()
                                        })
                                    } else {
                                        if let idx = strongSelf.messagesLoading.firstIndex(of: decryptedMessageMessageGuid) {
                                            strongSelf.messagesLoading.remove(at: idx)
                                        }
                                        completion(data, errorMessage)
                                    }
                                }
                            } else {
                                inCompleteBlock()
                            }
                        }
                    } else {
                        inCompleteBlock()
                    }
                    decryptedMessage.cellWithProgress = nil
                })
            }
        } else {
            self.performBlockInBackground { [weak self] in
                DPAGAttachmentWorker.loadAttachment(decryptedMessage.attachmentGuid, forMessageGuid: decryptedMessage.messageGuid, progress: nil, withResponse: { [weak self] responseObject, _, errorMessage in
                    if let strongSelf = self {
                        if errorMessage != nil {
                            strongSelf.performBlockOnMainThread { [weak self] in
                                if self != nil {
                                    completion(nil, errorMessage)
                                }
                            }
                        } else if responseObject as? String != nil, let attachment = decryptedMessage.decryptedAttachment {
                            DPAGAttachmentWorker.decryptMessageAttachment(attachment: attachment) { data, errorMessage in
                                if data != nil {
                                    strongSelf.performBlockOnMainThread { [weak self] in
                                        if self != nil {
                                            decryptedMessage.markDecryptedMessageAsReadAttachment()

                                            completion(data, errorMessage)
                                        }
                                    }
                                } else {
                                    DPAGAttachmentWorker.removeEncryptedAttachment(guid: decryptedMessage.attachmentGuid)
                                    strongSelf.performBlockOnMainThread { [weak self] in
                                        if self != nil {
                                            completion(data, errorMessage)
                                        }
                                    }
                                }
                            }
                        }
                    }
                })
            }
        }
    }

    func navigationControllerForMediaPresentation(withRootViewController rootViewController: UIViewController) -> (UINavigationController & DPAGNavigationControllerProtocol) {
        let navVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: rootViewController)
        navVC.modalPresentationStyle = .custom
        navVC.transitioningDelegateZooming = DPAGApplicationFacadeUIBase.defaultAnimatedTransitioningDelegate()
        navVC.transitioningDelegate = navVC.transitioningDelegateZooming
        navVC.copyNavigationBarStyle(navVCSrc: self.navigationController)
        return navVC
    }

    private static let mediaResourceForwarding: DPAGMediaResourceForwarding = { mediaResource in
        let navigationController = DPAGApplicationFacadeUIBase.containerVC.secondaryNavigationController
        let activeChatsVC = DPAGApplicationFacadeUIContacts.activeChatsVC()
        activeChatsVC.completionOnSelectReceiver = { receiver in
            let streamGuidReceiver = (receiver as? DPAGContact)?.streamGuid ?? (receiver as? DPAGGroup)?.guid
            let streamNameReceiver = (receiver as? DPAGContact)?.displayName ?? (receiver as? DPAGGroup)?.name
            guard let streamGuid = streamGuidReceiver, let streamName = streamNameReceiver else { return }
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                DPAGChatHelper.openChatStreamView(streamGuid, navigationController: navigationController, startChatWithUnconfirmedContact: true, draftMediaResource: mediaResource) { streamVC in
                    streamVC?.title = streamName
                    DPAGProgressHUD.sharedInstance.hide(true)
                }
            }
        }
        if let presentedViewController = navigationController.presentedViewController {
            presentedViewController.dismiss(animated: true) {
                navigationController.pushViewController(activeChatsVC, animated: true)
            }
        } else {
            navigationController.pushViewController(activeChatsVC, animated: true)
        }
    }

    func setUpImageViewWithData(_ data: Data, messageGuid: String, decMessage: DPAGDecryptedMessage, stream streamGuid: String) {
        if (self.isMovingFromParent || self.isBeingDismissed) == false, self.parent != nil, self.presentingViewController == nil {
            self.inputController?.textView?.resignFirstResponder()
            let mediaResource = DPAGMediaResource(type: .image)
            mediaResource.mediaContent = data
            mediaResource.attachment = decMessage.decryptedAttachment
            mediaResource.text = decMessage.contentDesc
            if decMessage.isSelfDestructive, !decMessage.isOwnMessage {
                let vc = DPAGApplicationFacadeUI.imageShowVC(messageGuid: messageGuid, decMessage: decMessage, fromStream: streamGuid, mediaResource: mediaResource)
                self.navigationController?.pushViewController(vc, animated: true)
            } else {
                let vc = DPAGApplicationFacadeUIMedia.mediaDetailVC(mediaResources: [mediaResource], index: 0, contentViewDelegate: self, mediaResourceForwarding: DPAGChatCellBaseViewController.mediaResourceForwarding)
                vc.titleShow = self.title
                let navVC = self.navigationControllerForMediaPresentation(withRootViewController: vc)
                self.present(navVC, animated: true, completion: nil)
            }
        }
    }

    func setUpVideoViewWithData(_ data: Data, messageGuid: String, decMessage: DPAGDecryptedMessage, stream streamGuid: String) {
        if (self.isMovingFromParent || self.isBeingDismissed) == false, self.parent != nil, self.presentingViewController == nil {
            self.inputController?.textView?.resignFirstResponder()
            if let imagePreview = decMessage.content, let imageData = Data(base64Encoded: imagePreview, options: .ignoreUnknownCharacters), let image = UIImage(data: imageData) {
                let mediaResource = DPAGMediaResource(type: .video)
                mediaResource.mediaContent = data
                mediaResource.preview = image
                mediaResource.attachment = decMessage.decryptedAttachment
                mediaResource.text = decMessage.contentDesc
                if decMessage.isSelfDestructive, !decMessage.isOwnMessage {
                    let vc = DPAGApplicationFacadeUI.videoShowVC(messageGuid: messageGuid, decMessage: decMessage, fromStream: streamGuid, mediaResource: mediaResource)
                    self.navigationController?.pushViewController(vc, animated: true)
                } else {
                    let vc = DPAGApplicationFacadeUIMedia.mediaDetailVC(mediaResources: [mediaResource], index: 0, contentViewDelegate: self, mediaResourceForwarding: DPAGChatCellBaseViewController.mediaResourceForwarding)
                    vc.titleShow = self.title
                    let navVC = self.navigationControllerForMediaPresentation(withRootViewController: vc)
                    self.present(navVC, animated: true, completion: nil)
                }
            }
        }
    }

    func setUpVoiceRecViewWithData(_: Data, messageGuid: String, decMessage: DPAGDecryptedMessage, stream streamGuid: String) {
        if (self.isMovingFromParent || self.isBeingDismissed) == false, self.parent != nil, self.presentingViewController == nil {
            self.inputController?.textView?.resignFirstResponder()
            let vc = DPAGApplicationFacadeUI.voiceRecShowVC(messageGuid: messageGuid, decMessage: decMessage, fromStream: streamGuid)
            if decMessage.isSelfDestructive {
                self.navigationController?.pushViewController(vc, animated: true)
            } else {
                let navVC = self.navigationControllerForMediaPresentation(withRootViewController: vc)
                self.present(navVC, animated: true, completion: nil)
            }
        }
    }

    func showErrorAlertForCellWithMessage(alertConfig: AlertConfigError) {
        self.presentErrorAlert(alertConfig: alertConfig)
    }

    func deleteChatStreamMessage(_ messageGuid: String) {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(false) { _ in
            DPAGApplicationFacade.messageWorker.deleteChatStreamMessage(messageGuid: messageGuid, streamGuid: self.streamGuid) { _, _, errorMessage in
                if let errorMessage = errorMessage {
                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                    }
                } else {
                    DPAGProgressHUD.sharedInstance.hide(true)
                }
            }
        }
        _ = self.navigationController?.popToViewController(self.sendingDelegate as? UIViewController ?? self, animated: true)
    }

    func commentChatStreamMessage(_ message: DPAGDecryptedMessage) {
        self.inputController?.handleCommentMessage(for: message)
        self.inputSendOptionsView?.reset()
    }

    @objc
    func scrollViewDidEndScrollingAnimation(_: UIScrollView) {
        self.scrollingAnimationCompletion?()
        self.scrollingAnimationCompletion = nil
    }

    func selectCitationForMessage(_ message: DPAGDecryptedMessage) {
        if let msgGuid = message.citationContent?.msgGuid {
            if let indexPath = self.indexPathForMessage(msgGuid) {
                if self.tableView.cellForRow(at: indexPath) != nil {
                    self.scrollingAnimationCompletionBlock(for: indexPath)()
                } else {
                    self.scrollingAnimationCompletion = self.scrollingAnimationCompletionBlock(for: indexPath)
                }
                self.tableView.scrollToRow(at: indexPath, at: .none, animated: true)
            } else if let decMessage = DPAGApplicationFacade.cache.decryptedMessage(messageGuid: msgGuid), let streamGuid = decMessage.streamGuid, streamGuid != self.streamGuid {
                DPAGChatHelper.openChatStreamView(streamGuid, navigationController: self.navigationController, showMessage: msgGuid) { _ in }
            }
        }
    }

    func didSelectMessageCell(_: DPAGMessageCellProtocol) {
//        self.inputController?.textView?.resignFirstResponder()
    }

    func showProfile() {
        let nextVC = DPAGApplicationFacadeUISettings.profileVC()
        self.navigationController?.pushViewController(nextVC, animated: true)
    }

    func showOptionsForFailedMessage(_ message: String?, openAction blockOpen: DPAGCompletion?) {
        guard let messageGuid = message else { return }
        if ((self.inputController?.inputDisabled ?? true) == true && DPAGApplicationFacade.cache.decryptedMessage(messageGuid: messageGuid)?.sendOptions?.dateToBeSend == nil) || (DPAGHelperEx.isNetworkReachable() == false && blockOpen == nil) {
            return
        }
        let options: DPAGMessageRecoveryAction
        if DPAGHelperEx.isNetworkReachable() {
            options = blockOpen != nil ? [.resend, .open] : .resend
        } else if blockOpen != nil {
            options = .open
        } else {
            return
        }
        let isTextViewFirstResponder = self.inputController?.textView?.isFirstResponder() ?? false
        let block = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.showRecoveryOptions(options, forMessage: messageGuid, view: strongSelf.view) { [weak self] _, recoveryAction in
                guard let strongSelf = self else { return }
                switch recoveryAction {
                    case .resend:
                        strongSelf.performBlockInBackground { [weak self] in
                            if let strongSelf = self, let decMessage = DPAGApplicationFacade.messageWorker.prepareMessageToResend(messageGuid: messageGuid) {
                                decMessage.resetPreferredCellHeights()
                                strongSelf.resendMessage(msgGuid: messageGuid)
                            }
                        }
                    case .open:
                        blockOpen?()
                    case .none:
                        if isTextViewFirstResponder {
                            strongSelf.performBlockOnMainThread { [weak self] in
                                self?.inputController?.textView?.becomeFirstResponder()
                            }
                        }
                }
            }
        }
        if isTextViewFirstResponder {
            self.inputController?.keyboardDidHideCompletion = block
            self.performBlockOnMainThread { [weak self] in
                self?.inputController?.textView?.resignFirstResponder()
            }
        } else {
            self.performBlockOnMainThread { [weak self] in
                self?.inputController?.dismissSendOptionsView(animated: true, completion: block)
            }
        }
    }

    func showRecoveryOptions(_ supportedRecoveryOptions: DPAGMessageRecoveryAction, forMessage message: String, view _: UIView, completionHandler: @escaping (String, DPAGMessageRecoveryActionSelected) -> Void) {
        self.resignFirstResponder()
        let completionHandler = completionHandler
        let message = message
        let title = "chat.message-failed.recovery.title"
        let cancelButtonTitle = "chat.message-failed.recovery.cancel"
        let openButtonTitle = "chat.message-failed.recovery.open"
        let retryButtonTitle = "chat.message-failed.recovery.retry"
        var options = [AlertOption]()
        if supportedRecoveryOptions.contains(.open) {
            let optionOpen = AlertOption(titleKey: openButtonTitle, style: .default) {
                completionHandler(message, .open)
            }
            options.append(optionOpen)
        }
        if supportedRecoveryOptions.contains(.resend) {
            let optionResend = AlertOption(titleKey: retryButtonTitle, style: .default) {
                completionHandler(message, .resend)
            }
            options.append(optionResend)
        }
        let optionCancel = AlertOption(titleKey: cancelButtonTitle, style: .cancel) {
            completionHandler(message, .none)
        }
        options.append(optionCancel)
        let alertController = UIAlertController.controller(options: options, titleKey: title, withStyle: .alert)
        self.presentAlertController(alertController)
    }

    func askToForwardURL(_ url: URL) {
        self.onUrlMessageClicked(url: url, logDetail: nil)
    }

    func askToForwardURL(_ url: URL, message: DPAGDecryptedMessage) {
        var logDetail: String?
        if let groupMessage = message as? DPAGDecryptedMessageGroup {
            if groupMessage.groupType == .restricted {
                logDetail = groupMessage.messageGuid
            }
        }

        self.onUrlMessageClicked(url: url, logDetail: logDetail)
    }

    private func onUrlMessageClicked(url: URL, logDetail _: String?) {
        self.resignFirstResponder()

        let urlString = url.absoluteString
        let optionOpenUrl = AlertOption(title: DPAGLocalizedString("chat.link.actionSheet.openInSafari"), style: .default, accesibilityIdentifier: "chat.link.actionSheet.openInSafari") {
            AppConfig.openURL(URL(string: urlString))
        }

        let optionCopyUrl = AlertOption(title: DPAGLocalizedString("chat.link.actionSheet.copy"), style: .default, accesibilityIdentifier: "chat.link.actionSheet.copy") {
            UIPasteboard.general.string = urlString
        }

        let optionCancel = AlertOption.cancelOption()
        let alertController = UIAlertController.controller(options: [optionOpenUrl, optionCopyUrl, optionCancel], titleString: urlString, withStyle: .alert, accessibilityIdentifier: "action_forward_url")
        self.presentAlertController(alertController)
    }

    func openLink(for label: DPAGChatLabel) {
        self.resignFirstResponder()
        if label.links.count == 1 {
            if let url = label.links.first?.1 {
                AppConfig.openURL(url as URL)
            }
        } else {
            var options: [AlertOption] = label.links.map {
                let urlString = $0.1.absoluteString
                return AlertOption(title: urlString, style: .default, handler: {
                    AppConfig.openURL(URL(string: urlString))
                })
            }
            options.append(AlertOption.cancelOption())
            let alertController = UIAlertController.controller(options: options, withStyle: .alert, accessibilityIdentifier: "action_open_link")
            self.presentAlertController(alertController)
        }
    }

    func copyLink(for label: DPAGChatLabel) {
        self.resignFirstResponder()
        if label.links.count == 1 {
            if let url = label.links.first?.1 {
                UIPasteboard.general.url = url as URL
            }
        } else {
            var options: [AlertOption] = label.links.map {
                let url = $0.1
                let urlString = url.absoluteString
                return AlertOption(title: urlString, style: .default, handler: {
                    UIPasteboard.general.url = url
                })
            }
            options.append(AlertOption.cancelOption())
            let alertController = UIAlertController.controller(options: options, withStyle: .alert, accessibilityIdentifier: "action_copy_link")
            self.presentAlertController(alertController)
        }
    }

    func forwardText(_ forwardingText: String, message: DPAGDecryptedMessage) {
        let navigationController = DPAGApplicationFacadeUIBase.containerVC.secondaryNavigationController
        let nextVC = DPAGApplicationFacadeUIContacts.activeChatsVC()
        nextVC.completionOnSelectReceiver = { [weak self] receiver in
            let streamGuidReceiver = (receiver as? DPAGContact)?.streamGuid ?? (receiver as? DPAGGroup)?.guid
            let streamNameReceiver = (receiver as? DPAGContact)?.displayName ?? (receiver as? DPAGGroup)?.name
            guard let streamGuid = streamGuidReceiver, let streamName = streamNameReceiver else { return }
            guard self != nil else { return }
            if let messageCitationGuid = message.citationContent?.msgGuid {
                let messageIdentifier = String(format: DPAGLocalizedString("chat.message.forwardComment.willSendTo.message"), streamName)
                let actionCancel = UIAlertAction(titleIdentifier: "res.cancel", style: .cancel, handler: { _ in
                    DPAGProgressHUD.sharedInstance.show(true) { _ in
                        DPAGChatHelper.openChatStreamView(streamGuid, navigationController: navigationController, startChatWithUnconfirmedContact: true, showMessage: nil, draftText: forwardingText) { _ in
                            DPAGProgressHUD.sharedInstance.hide(true)
                        }
                    }
                })
                let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in
                    guard self != nil else { return }
                    DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                        DPAGChatHelper.openChatStreamView(streamGuid, navigationController: navigationController, startChatWithUnconfirmedContact: true, showMessage: nil, draftText: nil) { streamVC in
                            DPAGProgressHUD.sharedInstance.hide(true) {
                                guard let streamVC = streamVC else { return }
                                DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation = messageCitationGuid
                                streamVC.sendTextWithWorker(forwardingText, sendMessageOptions: streamVC.inputController?.getSendOptions())
                            }
                        }
                    }
                })
                nextVC.presentAlert(alertConfig: AlertConfig(titleIdentifier: "chat.message.forwardComment.willSendTo.title", messageIdentifier: messageIdentifier, cancelButtonAction: actionCancel, otherButtonActions: [actionOK]))
            } else {
                DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                    DPAGChatHelper.openChatStreamView(streamGuid, navigationController: navigationController, startChatWithUnconfirmedContact: true, showMessage: nil, draftText: forwardingText) { _ in
                        DPAGProgressHUD.sharedInstance.hide(true)
                    }
                }
            }
        }
        navigationController.pushViewController(nextVC, animated: true)
    }

    func requestRejoinAVCall(_ message: DPAGDecryptedMessage) {
        if message.contentType == .avCallInvitation {
            DPAGSimsMeController.sharedInstance.chatsListViewController.showAVCallInvitation(forMessage: message.messageGuid)
        }
    }
    
    func loadAttachmentFileWithMessage(_ decryptedMessage: DPAGDecryptedMessage, cell cellWithProgress: DPAGCellWithProgress?) {
        let messageGuidCitation = decryptedMessage.citationContent?.msgGuid
        self.loadAttachmentWithMessage(decryptedMessage, cell: cellWithProgress) { [weak self] data, errorString in
            guard let strongSelf = self else { return }
            if let fileData = data {
                let navigationController = strongSelf.navigationController
                let nextVC = DPAGApplicationFacadeUIContacts.activeChatsVC()
                nextVC.completionOnSelectReceiver = { receiver in
                    let streamGuidReceiver = (receiver as? DPAGContact)?.streamGuid ?? (receiver as? DPAGGroup)?.guid
                    let streamNameReceiver = (receiver as? DPAGContact)?.displayName ?? (receiver as? DPAGGroup)?.name
                    guard let streamGuid = streamGuidReceiver, let streamName = streamNameReceiver else { return }
                    guard self != nil else { return }
                    let mediaResource = DPAGMediaResource(type: .file)
                    mediaResource.mediaContent = fileData
                    mediaResource.additionalData = decryptedMessage.additionalData
                    if messageGuidCitation != nil {
                        let messageIdentifier = String(format: DPAGLocalizedString("chat.message.forwardComment.willSendTo.message"), streamName)
                        let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in
                            guard self != nil else { return }
                            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                                DPAGChatHelper.openChatStreamView(streamGuid, navigationController: navigationController, startChatWithUnconfirmedContact: true, showMessage: nil, draftText: nil) { streamVC in
                                    DPAGProgressHUD.sharedInstance.hide(true) {
                                        guard let streamVC = streamVC else { return }
                                        DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation = messageGuidCitation
                                        streamVC.sendMediaWithWorker(mediaResource, sendMessageOptions: streamVC.inputController?.getSendOptions())
                                    }
                                }
                            }
                        })
                        nextVC.presentAlert(alertConfig: AlertConfig(titleIdentifier: "chat.message.forwardComment.willSendTo.title", messageIdentifier: messageIdentifier, cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
                    } else {
                        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                            DPAGChatHelper.openChatStreamView(streamGuid, navigationController: navigationController, startChatWithUnconfirmedContact: true, draftMediaResource: mediaResource) { streamVC in
                                streamVC?.title = streamName
                                DPAGProgressHUD.sharedInstance.hide(true)
                            }
                        }
                    }
                }
                navigationController?.pushViewController(nextVC, animated: true)
            } else if let errorString = errorString {
                strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorString))
            }
        }
    }

    func loadAttachmentVideoWithMessage(_ decryptedMessage: DPAGDecryptedMessage, cell cellWithProgress: DPAGCellWithProgress?, previewImage: UIImage?) {
        let messageGuidCitation = decryptedMessage.citationContent?.msgGuid
        self.loadAttachmentWithMessage(decryptedMessage, cell: cellWithProgress) { [weak self] data, errorString in
            guard let strongSelf = self else { return }
            if let videoData = data {
                let navigationController = strongSelf.navigationController
                let nextVC = DPAGApplicationFacadeUIContacts.activeChatsVC()
                nextVC.completionOnSelectReceiver = { receiver in
                    let streamGuidReceiver = (receiver as? DPAGContact)?.streamGuid ?? (receiver as? DPAGGroup)?.guid
                    let streamNameReceiver = (receiver as? DPAGContact)?.displayName ?? (receiver as? DPAGGroup)?.name
                    guard let streamGuid = streamGuidReceiver, let streamName = streamNameReceiver else { return }
                    guard self != nil else { return }
                    let mediaResource = DPAGMediaResource(type: .video)
                    mediaResource.mediaContent = videoData
                    mediaResource.preview = previewImage
                    mediaResource.text = decryptedMessage.contentDesc
                    mediaResource.attachment = decryptedMessage.decryptedAttachment
                    if messageGuidCitation != nil {
                        let messageIdentifier = String(format: DPAGLocalizedString("chat.message.forwardComment.willSendTo.message"), streamName)
                        let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in
                            guard self != nil else { return }
                            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                                DPAGChatHelper.openChatStreamView(streamGuid, navigationController: navigationController, startChatWithUnconfirmedContact: true, showMessage: nil, draftText: nil) { streamVC in
                                    DPAGProgressHUD.sharedInstance.hide(true) {
                                        guard let streamVC = streamVC else { return }
                                        DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation = messageGuidCitation
                                        streamVC.sendMediaWithWorker(mediaResource, sendMessageOptions: streamVC.inputController?.getSendOptions())
                                    }
                                }
                            }
                        })
                        nextVC.presentAlert(alertConfig: AlertConfig(titleIdentifier: "chat.message.forwardComment.willSendTo.title", messageIdentifier: messageIdentifier, cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
                    } else {
                        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                            DPAGChatHelper.openChatStreamView(streamGuid, navigationController: navigationController, startChatWithUnconfirmedContact: true, draftMediaResource: mediaResource) { streamVC in
                                streamVC?.title = streamName
                                DPAGProgressHUD.sharedInstance.hide(true)
                            }
                        }
                    }
                }
                navigationController?.pushViewController(nextVC, animated: true)
            } else if let errorString = errorString {
                strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorString))
            }
        }
    }

    func loadAttachmentImageWithMessage(_ decryptedMessage: DPAGDecryptedMessage, cell cellWithProgress: DPAGCellWithProgress?, previewImage: UIImage?) {
        let messageGuidCitation = decryptedMessage.citationContent?.msgGuid
        self.loadAttachmentWithMessage(decryptedMessage, cell: cellWithProgress) { [weak self] data, errorString in
            guard let strongSelf = self else { return }
            if let imageData = data {
                let navigationController = strongSelf.navigationController
                let nextVC = DPAGApplicationFacadeUIContacts.activeChatsVC()
                nextVC.completionOnSelectReceiver = { receiver in
                    let streamGuidReceiver = (receiver as? DPAGContact)?.streamGuid ?? (receiver as? DPAGGroup)?.guid
                    let streamNameReceiver = (receiver as? DPAGContact)?.displayName ?? (receiver as? DPAGGroup)?.name
                    guard let streamGuid = streamGuidReceiver, let streamName = streamNameReceiver else { return }
                    guard self != nil else { return }
                    let mediaResource = DPAGMediaResource(type: .image)
                    mediaResource.mediaContent = imageData
                    mediaResource.preview = previewImage
                    mediaResource.text = decryptedMessage.contentDesc
                    mediaResource.attachment = decryptedMessage.decryptedAttachment
                    if messageGuidCitation != nil {
                        let messageIdentifier = String(format: DPAGLocalizedString("chat.message.forwardComment.willSendTo.message"), streamName)
                        let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in
                            guard self != nil else { return }
                            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                                DPAGChatHelper.openChatStreamView(streamGuid, navigationController: navigationController, startChatWithUnconfirmedContact: true, showMessage: nil, draftText: nil) { streamVC in
                                    DPAGProgressHUD.sharedInstance.hide(true) {
                                        guard let streamVC = streamVC else { return }
                                        DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation = messageGuidCitation
                                        streamVC.sendMediaWithWorker(mediaResource, sendMessageOptions: streamVC.inputController?.getSendOptions())
                                    }
                                }
                            }

                        })
                        nextVC.presentAlert(alertConfig: AlertConfig(titleIdentifier: "chat.message.forwardComment.willSendTo.title", messageIdentifier: messageIdentifier, cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
                    } else {
                        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                            DPAGChatHelper.openChatStreamView(streamGuid, navigationController: navigationController, startChatWithUnconfirmedContact: true, draftMediaResource: mediaResource) { streamVC in
                                streamVC?.title = streamName
                                DPAGProgressHUD.sharedInstance.hide(true)
                            }
                        }
                    }
                }
                navigationController?.pushViewController(nextVC, animated: true)
            } else if let errorString = errorString {
                strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorString))
            }
        }
    }

    func loadAttachmentImageWithMessage(_ decryptedMessage: DPAGDecryptedMessage, cell cellWithProgress: DPAGCellWithProgress?) {
        let messageGuidCitation = decryptedMessage.citationContent?.msgGuid
        self.loadAttachmentWithMessage(decryptedMessage, cell: cellWithProgress) { [weak self] data, errorString in
            guard let strongSelf = self else { return }
            if let imageData = data {
                let navigationController = strongSelf.navigationController
                let nextVC = DPAGApplicationFacadeUIContacts.activeChatsVC()
                nextVC.completionOnSelectReceiver = { receiver in
                    let streamGuidReceiver = (receiver as? DPAGContact)?.streamGuid ?? (receiver as? DPAGGroup)?.guid
                    let streamNameReceiver = (receiver as? DPAGContact)?.displayName ?? (receiver as? DPAGGroup)?.name
                    guard let streamGuid = streamGuidReceiver, let streamName = streamNameReceiver else { return }
                    guard self != nil else { return }
                    let mediaResource = DPAGMediaResource(type: .image)
                    mediaResource.mediaContent = imageData
                    mediaResource.text = decryptedMessage.contentDesc
                    mediaResource.attachment = decryptedMessage.decryptedAttachment
                    if messageGuidCitation != nil {
                        let messageIdentifier = String(format: DPAGLocalizedString("chat.message.forwardComment.willSendTo.message"), streamName)
                        let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in
                            guard self != nil else { return }
                            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                                DPAGChatHelper.openChatStreamView(streamGuid, navigationController: navigationController, startChatWithUnconfirmedContact: true, showMessage: nil, draftText: nil) { streamVC in
                                    DPAGProgressHUD.sharedInstance.hide(true) {
                                        guard let streamVC = streamVC else { return }
                                        DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation = messageGuidCitation
                                        streamVC.sendMediaWithWorker(mediaResource, sendMessageOptions: streamVC.inputController?.getSendOptions())
                                    }
                                }
                            }
                        })
                        nextVC.presentAlert(alertConfig: AlertConfig(titleIdentifier: "chat.message.forwardComment.willSendTo.title", messageIdentifier: messageIdentifier, cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
                    } else {
                        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                            DPAGChatHelper.openChatStreamView(streamGuid, navigationController: navigationController, startChatWithUnconfirmedContact: true, draftMediaResource: mediaResource) { streamVC in
                                streamVC?.title = streamName
                                DPAGProgressHUD.sharedInstance.hide(true)
                            }
                        }
                    }
                }
                navigationController?.pushViewController(nextVC, animated: true)
            } else if let errorString = errorString {
                strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorString))
            }
        }
    }

    private func locationWithLocationJSON(_ locationJSON: String) -> CLLocation? {
        guard let data = locationJSON.data(using: .utf8) else { return nil }
        do {
            if let locationDict = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as? [AnyHashable: Any], let latitudeNum = locationDict[DPAGStrings.JSON.Location.LATITUDE] as? NSNumber, let longitudeNum = locationDict[DPAGStrings.JSON.Location.LONGITUDE] as? NSNumber {
                let latitude: CLLocationDegrees = latitudeNum.doubleValue
                let longitude: CLLocationDegrees = longitudeNum.doubleValue

                return CLLocation(latitude: latitude, longitude: longitude)
            }
        } catch {
            DPAGLog(error)
        }

        return nil
    }

    func dismissInputController(completion: DPAGCompletion?) {
        if self.inputController?.textView?.isFirstResponder() ?? false {
            self.inputController?.keyboardDidHideCompletion = completion
            self.performBlockOnMainThread { [weak self] in
                self?.inputController?.textView?.resignFirstResponder()
            }
        } else {
            self.performBlockOnMainThread { [weak self] in
                if let inputController = self?.inputController {
                    inputController.dismissSendOptionsView(animated: true, completion: completion ?? {})
                } else {
                    completion?()
                }
            }
        }
    }

    func didSelectValidLocation(_ message: DPAGDecryptedMessage) {
        let block = { [weak self] in
            guard let strongSelf = self else { return }
            if let locationJson = message.content {
                let locationViewController = DPAGApplicationFacadeUI.locationShowVC()
                let pinLocation = strongSelf.locationWithLocationJSON(locationJson)
                locationViewController.pinLocation = pinLocation
                locationViewController.automaticallyZoom = true
                strongSelf.navigationController?.pushViewController(locationViewController, animated: true)
            }
        }

        self.dismissInputController(completion: block)
    }

    func didSelectValidText(_ message: DPAGDecryptedMessage) {
        let block = { [weak self] in
            guard let strongSelf = self else { return }
            if message.isSelfDestructive, message.isOwnMessage == false, let streamGuid = message.streamGuid {
                let nextVC = DPAGApplicationFacadeUI.textDestructionShowVC(messageGuid: message.messageGuid, decMessage: message, fromStream: streamGuid)
                strongSelf.navigationController?.pushViewController(nextVC, animated: true)
            }
        }

        self.dismissInputController(completion: block)
    }

    func didSelectValidImage(_ message: DPAGDecryptedMessage, cell: DPAGMessageCellProtocol) {
        let block = { [weak self, weak cell] in
            guard let strongSelf = self, let cell = cell else { return }
            if cell.isLoadingAttachment == false, let streamGuid = message.streamGuid {
                cell.isLoadingAttachment = true
                strongSelf.loadAttachmentWithMessage(message, cell: cell as? DPAGCellWithProgress) { [weak self, weak cell] data, errorString in
                    guard let strongSelf = self else { return }
                    cell?.isLoadingAttachment = false
                    if let imageData = data {
                        strongSelf.performBlockOnMainThread { [weak self, weak cell] in
                            if let strongSelf = self, let cell = cell, cell.isHidden == false {
                                strongSelf.setUpImageViewWithData(imageData, messageGuid: message.messageGuid, decMessage: message, stream: streamGuid)
                            }
                        }
                    } else if let errorString = errorString {
                        strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorString))
                    }
                }
            }
        }
        self.dismissInputController(completion: block)
    }

    func didSelectValidFile(_ message: DPAGDecryptedMessage, cell: DPAGMessageCellProtocol) {
        let block = { [weak self, weak cell] in
            guard let strongSelf = self, let cell = cell else { return }
            if cell.isLoadingAttachment == false, let streamGuid = message.streamGuid {
                cell.isLoadingAttachment = true
                strongSelf.loadAttachmentWithMessage(message, cell: cell as? DPAGCellWithProgress) { [weak self, weak cell] data, errorString in
                    guard let strongSelf = self else { return }
                    cell?.isLoadingAttachment = false
                    if let fileData = data {
                        strongSelf.performBlockOnMainThread { [weak self, weak cell] in
                            if let strongSelf = self, let cell = cell, cell.isHidden == false, let cellView = cell as? UIView {
                                var rect = cellView.frame
                                rect.origin.x = 0
                                rect.origin.y = 0
                                strongSelf.setUpFileViewWithData(fileData, messageGuid: message.messageGuid, decMessage: message, stream: streamGuid, inRect: rect, inView: cellView)
                            }
                        }
                    } else if let errorString = errorString {
                        strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorString))
                    }
                }
            }
        }
        self.dismissInputController(completion: block)
    }

    func didSelectValidVoiceRec(_ message: DPAGDecryptedMessage, cell: DPAGMessageCellProtocol) {
        let block = { [weak self, weak cell] in
            guard let strongSelf = self, let cell = cell else { return }
            if DPAGApplicationFacadeUIBase.audioHelper.audioPlayer?.isPlaying ?? false, DPAGApplicationFacadeUIBase.audioHelper.delegatePlay === cell {
                DPAGApplicationFacadeUIBase.audioHelper.stopPlaying()
            } else if cell.isLoadingAttachment == false {
                cell.isLoadingAttachment = true
                strongSelf.loadAttachmentWithMessage(message, cell: cell as? DPAGCellWithProgress) { [weak self, weak cell] data, errorString in
                    guard let strongSelf = self else { return }
                    cell?.isLoadingAttachment = false
                    if let voiceData = data {
                        strongSelf.performBlockOnMainThread { [weak self, weak cell] in
                            if self != nil {
                                (cell as? DPAGVoiceMessageCellProtocol)?.playAudioWithData(voiceData)
                            }
                        }
                    } else if let errorString = errorString {
                        strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorString))
                    }
                }
            }
        }
        self.dismissInputController(completion: block)
    }

    func didSelectValidVideo(_ message: DPAGDecryptedMessage, cell: DPAGMessageCellProtocol) {
        let block = { [weak self, weak cell] in
            guard let strongSelf = self, let cell = cell else { return }
            if cell.isLoadingAttachment == false, let streamGuid = message.streamGuid {
                cell.isLoadingAttachment = true
                strongSelf.loadAttachmentWithMessage(message, cell: cell as? DPAGCellWithProgress) { [weak self, weak cell] data, errorString in
                    guard let strongSelf = self else { return }
                    cell?.isLoadingAttachment = false
                    if let videoData = data {
                        strongSelf.performBlockOnMainThread { [weak self, weak cell] in
                            if let strongSelf = self, let cell = cell, cell.isHidden == false {
                                strongSelf.setUpVideoViewWithData(videoData, messageGuid: message.messageGuid, decMessage: message, stream: streamGuid)
                            }
                        }
                    } else if let errorString = errorString {
                        strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorString))
                    }
                }
            }
        }
        self.dismissInputController(completion: block)
    }

    func didSelectValidSystemMessage(_: DPAGDecryptedMessage) {
        self.dismissInputController(completion: nil)
    }

    func didSelectValidContact(_ message: DPAGDecryptedMessage) {
        let block = { [weak self] in
            guard let strongSelf = self else { return }
            if let vcardAccoundID = message.vcardAccountID, let vcardAccountGuid = message.vcardAccountGuid, let contactToSave = message.content {
                strongSelf.showContactAddToPrivateVCard(vcardAccoundID: vcardAccoundID, vcardAccountGuid: vcardAccountGuid, contactToSave: contactToSave)
            } else if let contactToSave = message.content {
                strongSelf.showContactAddForVCard(contactToSave)
            } else {
                strongSelf.showErrorAlertForCellWithMessage(alertConfig: AlertConfigError(messageIdentifier: "chats.sendContact.notFeasible"))
            }
        }
        self.dismissInputController(completion: block)
    }

    func openSingleChat(_ message: DPAGDecryptedMessage) {
        if let contact = DPAGApplicationFacade.cache.contact(for: message.fromAccountGuid), let streamGuid = contact.streamGuid {
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
                DPAGChatHelper.openChatStreamView(streamGuid, navigationController: self?.navigationController, startChatWithUnconfirmedContact: true) { _ in
                    DPAGProgressHUD.sharedInstance.hide(true)
                }
            }
        }
    }

    func showDetailsForContact(_ contactGuid: String) {
        if let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
            let nextVC = DPAGApplicationFacadeUIContacts.contactDetailsVC(contact: contact)
            nextVC.pushedFromChats = (self is DPAGChatStreamViewControllerProtocol)
            self.navigationController?.pushViewController(nextVC, animated: true)
        }
    }

    func showDetailsForChannel(_ channelGuid: String) {
        if let nextVC = DPAGApplicationFacadeUI.channelDetailsVC(channelGuid: channelGuid, category: nil) {
            self.navigationController?.pushViewController(nextVC, animated: true)
        }
    }

    func showContactAddForVCard(_ contactToSave: String) {
        if DPAGApplicationFacade.preferences.sendVCardDisabled {
            return
        }
        let actionCancel = UIAlertAction(titleIdentifier: "chats.sendContact.askForSaveContact.no", style: .cancel, handler: nil)
        let actionOK = UIAlertAction(titleIdentifier: "chats.sendContact.askForSaveContact.yes", style: .default, handler: { [weak self] _ in
            if let strongSelf = self {
                if var contact = DPAGApplicationFacade.contactsWorker.contact(fromVCard: contactToSave) {
                    if contact.note.isEmpty {
                        if let note = contactToSave.components(separatedBy: .newlines).first(where: { $0.hasPrefix("NOTE:SIMSme-ID\\:") }), let contactNew = contact.mutableCopy() as? CNMutableContact {
                            contactNew.note = String(note[note.index(note.startIndex, offsetBy: 5)...])
                            contact = contactNew
                        }
                    }
                    let newPersonViewController = DPAGContactViewController(forNewContact: contact)
                    newPersonViewController.delegate = self
                    strongSelf.present(DPAGApplicationFacadeUIBase.navVC(rootViewController: newPersonViewController), animated: true, completion: nil)
                }
            }
        })
        self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "chats.sendContact.askForSaveContact.title", messageIdentifier: "chats.sendContact.askForSaveContact.message", cancelButtonAction: actionCancel, otherButtonActions: [actionOK]))
    }

    func showContactAddToPrivateVCard(vcardAccoundID: String, vcardAccountGuid: String, contactToSave: String) {
        if DPAGApplicationFacade.preferences.sendVCardDisabled {
            return
        }
        let actionCancel = UIAlertAction(titleIdentifier: "chats.sendContact.askForSaveContact.no", style: .cancel, handler: nil)
        let actionOK = UIAlertAction(titleIdentifier: "chats.sendContact.askForSaveContact.yes", style: .default, handler: { [weak self] _ in
            if let contact = DPAGApplicationFacade.cache.contact(for: vcardAccoundID) {
                if contact.entryTypeServer != .meMyselfAndI {
                    self?.startShowAddVCard(contactToSave: contactToSave, guid: vcardAccountGuid, isNew: false)
                }
            } else {
                DPAGApplicationFacade.updateKnownContactsWorker.getAccountInfo(accountGuid: vcardAccountGuid, withProfile: true, withTempDevice: true) { [weak self, contactToSave] responseObject, _, errorMessage in
                    guard let strongSelf = self else { return }
                    if errorMessage != nil, errorMessage == "service.ERR-0007" {
                        let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: nil)
                        strongSelf.presentAlert(alertConfig: AlertConfig(messageIdentifier: "chats.sendContact.NoContactDisplayName", otherButtonActions: [actionOK]))
                    } else if let dictResponse = responseObject as? [String: Any], let dictAccountInfo = dictResponse[DPAGStrings.JSON.Account.OBJECT_KEY] as? [String: Any], dictAccountInfo[DPAGStrings.JSON.Account.GUID] as? String != nil {
                        if let accountGuid = DPAGApplicationFacade.contactsWorker.insUpdContact(withAccountJson: dictAccountInfo), DPAGApplicationFacade.cache.contact(for: accountGuid) != nil {
                            strongSelf.startShowAddVCard(contactToSave: contactToSave, guid: accountGuid, isNew: true)
                        }
                    }
                }
            }
        })
        self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "chats.sendContact.askForSaveContact.title", messageIdentifier: "chats.sendContact.askForSaveContactInPrivate.message", cancelButtonAction: actionCancel, otherButtonActions: [actionOK]))
    }

    func startShowAddVCard(contactToSave: String, guid: String, isNew: Bool) {
        let vCardValues = DPAGApplicationFacade.contactsWorker.contact(fromVCard: contactToSave)
        let firstName: String? = vCardValues?.givenName
        let lastName: String? = vCardValues?.familyName
        let department: String? = vCardValues?.departmentName
        let phoneNumbers = vCardValues?.phoneNumbers
        let firstPhone = phoneNumbers?.first
        let number = firstPhone?.value
        let phoneNumber: String? = number?.stringValue
        var eMailAddress: String?
        let emailAddresses = vCardValues?.emailAddresses
        let firsteMail = emailAddresses?.first
        if let eMail = firsteMail?.value {
            eMailAddress = eMail as String?
        }

        if let contactCache = DPAGApplicationFacade.cache.contact(for: guid) {
            let contactEdit = DPAGContactEdit(guid: guid)
            contactEdit.firstName = firstName ?? contactCache.firstName
            contactEdit.lastName = lastName ?? contactCache.lastName
            contactEdit.phoneNumber = phoneNumber ?? contactCache.phoneNumber
            contactEdit.department = department ?? contactCache.department
            contactEdit.eMailAddress = eMailAddress ?? contactCache.eMailAddress
            self.performBlockOnMainThread({ [weak self] in
                if isNew {
                    let nextVC = DPAGApplicationFacadeUIContacts.contactNewCreateVC(contact: contactCache, contactEdit: contactEdit)
                    self?.navigationController?.pushViewController(nextVC, animated: true)
                } else {
                    let nextVC = DPAGApplicationFacadeUIContacts.contactDetailsVC(contact: contactCache, contactEdit: contactEdit)
                    self?.navigationController?.pushViewController(nextVC, animated: true)
                }
            })
        }
    }

    func setUpFileViewWithData(_ data: Data, messageGuid _: String, decMessage: DPAGDecryptedMessage, stream _: String, inRect: CGRect, inView: UIView) {
        if let fileName = decMessage.additionalData?.fileName {
            self.openFileData(data, fileName: fileName, inRect: inRect, inView: inView)
        }
    }

    func longPress(_ recognizer: UILongPressGestureRecognizer, withCell cell: UITableViewCell & DPAGMessageCellProtocol) {
        if recognizer.state == .began {
            self.inputController?.textView?.resignFirstResponder()
            self.longPressCell = cell
        }
    }

    func canSelectContact() -> Bool {
        self.tableView.isEditing == false
    }

    func canSelectContent() -> Bool {
        self.tableView.isEditing == false
    }
}

extension DPAGChatCellBaseViewController: CNContactViewControllerDelegate {
    func contactViewController(_ viewController: CNContactViewController, didCompleteWith _: CNContact?) {
        viewController.dismiss(animated: true, completion: nil)
    }
}
