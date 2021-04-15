//
//  DPAGChatHelper.swift
//  SIMSme
//
//  Created by RBU on 07/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

struct DPAGChatHelper {
    private init() {}

    static func openChatStreamView(_ streamGuid: String, navigationController: UINavigationController?, completion: @escaping ((UIViewController & DPAGChatStreamBaseViewControllerProtocol)?) -> Void) {
        self.openChatStreamView(streamGuid, navigationController: navigationController, startChatWithUnconfirmedContact: false, showMessage: nil, draftText: nil, completion: completion)
    }

    static func openChatStreamView(_ streamGuid: String, navigationController: UINavigationController?, showMessage messageGuid: String, completion: @escaping ((UIViewController & DPAGChatStreamBaseViewControllerProtocol)?) -> Void) {
        self.openChatStreamView(streamGuid, navigationController: navigationController, startChatWithUnconfirmedContact: false, showMessage: messageGuid, draftText: nil, completion: completion)
    }

    static func openChatStreamView(_ streamGuid: String, navigationController: UINavigationController?, startChatWithUnconfirmedContact isNewChatStreamWithUnconfirmedContact: Bool, completion: @escaping ((UIViewController & DPAGChatStreamBaseViewControllerProtocol)?) -> Void) {
        self.openChatStreamView(streamGuid, navigationController: navigationController, startChatWithUnconfirmedContact: isNewChatStreamWithUnconfirmedContact, showMessage: nil, draftText: nil, completion: completion)
    }

    static func openChatStreamView(_ streamGuid: String, navigationController: UINavigationController?, startChatWithUnconfirmedContact isNewChatStreamWithUnconfirmedContact: Bool, showMessage messageGuid: String?, draftText text: String?, completion: @escaping ((UIViewController & DPAGChatStreamBaseViewControllerProtocol)?) -> Void) {
        guard let chatStreamViewController = self.chatStreamViewControllerForStream(streamGuid, navigationController: navigationController, chatWithUnconfirmedContact: isNewChatStreamWithUnconfirmedContact) else {
            completion(nil)
            return
        }
        chatStreamViewController.draftTextMessage = text
        chatStreamViewController.showMessageGuid = messageGuid
        let block = {
            DPAGApplicationFacadeUIBase.containerVC.showSecondaryViewController(DPAGSimsMeController.sharedInstance.chatsListViewController, addViewController: chatStreamViewController, completion: { [weak chatStreamViewController] in
                completion(chatStreamViewController)
            })
        }
        if Thread.isMainThread == false {
            chatStreamViewController.createModel()
            OperationQueue.main.addOperation(block)
        } else {
            chatStreamViewController.createModel()
            block()
        }
    }

    static func openChatStreamView(_ streamGuid: String, navigationController: UINavigationController?, startChatWithUnconfirmedContact isNewChatStreamWithUnconfirmedContact: Bool, draftMediaResource media: DPAGMediaResource, completion: @escaping (UIViewController?) -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                DPAGChatHelper.openChatStreamView(streamGuid, navigationController: navigationController, startChatWithUnconfirmedContact: isNewChatStreamWithUnconfirmedContact, draftMediaResource: media, completion: completion)
            }
            return
        }
        guard let chatStreamViewController = self.chatStreamViewControllerForStream(streamGuid, navigationController: navigationController, chatWithUnconfirmedContact: isNewChatStreamWithUnconfirmedContact) else {
            completion(nil)
            return
        }
        var enableUserInteraction = false
        let type = media.mediaType
        var viewControllers: [UIViewController] = []
        var vcCompletion: UIViewController?
        if type == .image || type == .video {
            let sendImageOrVideoViewController = DPAGApplicationFacadeUI.imageOrVideoSendVC(mediaSourceType: .none, mediaResources: [media], sendDelegate: chatStreamViewController, enableMultiSelection: false)
            enableUserInteraction = true
            sendImageOrVideoViewController.title = chatStreamViewController.title
            viewControllers = [chatStreamViewController, sendImageOrVideoViewController]
            vcCompletion = sendImageOrVideoViewController
        } else if type == .file {
            chatStreamViewController.mediaToSend = media
            viewControllers = [chatStreamViewController]
            vcCompletion = chatStreamViewController
        }
        if viewControllers.count > 0 {
            let block = {
                if enableUserInteraction {
                    chatStreamViewController.view.isUserInteractionEnabled = true
                }
                DPAGApplicationFacadeUIBase.containerVC.showSecondaryViewController(DPAGSimsMeController.sharedInstance.chatsListViewController, addViewControllers: viewControllers, animated: true, completion: { [weak vcCompletion] in
                    completion(vcCompletion)
                })
            }
            if Thread.isMainThread == false {
                chatStreamViewController.createModel()
                OperationQueue.main.addOperation(block)
            } else {
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    chatStreamViewController.createModel()
                    DispatchQueue.main.async(execute: block)
                }
            }
        }
    }

    private static func chatStreamViewControllerForStream(_ streamGuid: String, navigationController: UINavigationController?, chatWithUnconfirmedContact isNewChatStreamWithUnconfirmedContact: Bool) -> (UIViewController & DPAGChatStreamBaseViewControllerProtocol)? {
        var vcc: UIViewController?
        if Thread.current == Thread.main {
            vcc = navigationController?.visibleViewController
        } else {
            DispatchQueue.main.sync {
                vcc = navigationController?.visibleViewController
            }
        }
        if let vcCurrent = vcc as? (UIViewController & DPAGChatStreamBaseViewControllerProtocol) {
            if vcCurrent.streamGuid == streamGuid {
                return nil
            }
        }
        var chatStreamViewController: (UIViewController & DPAGChatStreamBaseViewControllerProtocol)?
        if let messageStream = DPAGApplicationFacade.cache.decryptedStream(streamGuid: streamGuid, in: nil) {
            if let groupStream = messageStream as? DPAGDecryptedStreamGroup {
                chatStreamViewController = DPAGApplicationFacadeUI.chatGroupStreamVC(stream: streamGuid, streamState: groupStream.streamState)
                chatStreamViewController?.title = groupStream.streamName
            } else if let privateStream = messageStream as? DPAGDecryptedStreamPrivate, let contactGuid = privateStream.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
                let streamState = contact.streamState
                chatStreamViewController = DPAGApplicationFacadeUI.chatStreamVC(stream: streamGuid, streamState: streamState, startChatWithUnconfirmedContact: isNewChatStreamWithUnconfirmedContact)
            } else if let channelStream = messageStream as? DPAGDecryptedStreamChannel {
                let streamState: DPAGChatStreamState = .readOnly // channelStream.streamState
                let feedType = channelStream.feedType
                switch feedType {
                    case .channel:
                        chatStreamViewController = DPAGApplicationFacadeUI.channelStreamVC(stream: streamGuid, streamState: streamState)
                    case .service:
                        chatStreamViewController = DPAGApplicationFacadeUI.serviceStreamVC(stream: streamGuid, streamState: streamState)
                }
            }
        }
        return chatStreamViewController
    }

    private static func prepareSendingWithSendingDelegate(_ sendingDelegate: DPAGSendingDelegate, completion: @escaping DPAGCompletion) {
        guard sendingDelegate is UIViewController, let sendingViewController = sendingDelegate as? UIViewController else { return }
        if sendingDelegate.navigationController?.presentedViewController != nil {
            sendingDelegate.navigationController?.dismiss(animated: true, completion: { [weak sendingDelegate] in
                guard let sendingDelegate = sendingDelegate, let sendingViewController = sendingDelegate as? UIViewController else { return }
                CATransaction.begin()
                CATransaction.setCompletionBlock(completion)
                _ = sendingDelegate.navigationController?.popToViewController(sendingViewController, animated: true)
                CATransaction.commit()
            })
        } else {
            CATransaction.begin()
            CATransaction.setCompletionBlock(completion)
            _ = sendingDelegate.navigationController?.popToViewController(sendingViewController, animated: true)
            CATransaction.commit()
        }
    }

    static func sendMessageWithDelegate(_ sendingDelegate: DPAGSendingDelegate?, sendingBlock: @escaping ([DPAGSendMessageRecipient]) -> Void) {
        guard let sendingDelegate = sendingDelegate else { return }
        let block = {
            if AppConfig.isShareExtension {
                sendingDelegate.updateViewBeforeMessageWillSend()
                sendingDelegate.performBlockInBackground {
                    let recipients = sendingDelegate.getRecipients()
                    sendingBlock(recipients)
                    sendingDelegate.updateRecipientsConfidenceState()
                }
                sendingDelegate.updateViewAfterMessageWasSent()
            } else {
                CATransaction.begin()
                CATransaction.setCompletionBlock {
                    sendingDelegate.performBlockInBackground {
                        let recipients = sendingDelegate.getRecipients()
                        sendingBlock(recipients)
                        sendingDelegate.updateRecipientsConfidenceState()
                    }
                    sendingDelegate.updateViewAfterMessageWasSent()
                }
                sendingDelegate.updateViewBeforeMessageWillSend()
                CATransaction.commit()
            }
        }
        sendingDelegate.performBlockOnMainThread {
            DPAGChatHelper.prepareSendingWithSendingDelegate(sendingDelegate, completion: block)
        }
    }
}
