//
//  DPAGStatusBarNotificationDisplay.swift
//  SIMSme
//
//  Created by RBU on 11/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import SIMSmeCore
import UIKit

protocol DPAGStatusBarNotificationDisplayDelegate: AnyObject {
    func notificationIsCompletelyDismissedAndCanShowMore(_ showMore: Bool)
}

protocol DPAGStatusBarNotificationDisplayProtocol: AnyObject {
    var delegate: DPAGStatusBarNotificationDisplayDelegate? { get set }
    func playReceiveSound(_ playSounds: Int)
    func containerVC() -> (UIViewController & DPAGContainerViewControllerProtocol)?
    func showStatusBarNotification(forMessage messageGuid: String)
    func showStatusBarNotification(forInvitationToGroupStream streamGuid: String)
    func showStatusBarNotification(forUnconfirmedChatStream streamGuid: String)
    func showStatusBarNotification(title: String, text: String)
}

class DPAGStatusBarNotificationDisplay: NSObject, DPAGStatusBarNotificationDisplayProtocol {
    weak var delegate: DPAGStatusBarNotificationDisplayDelegate?

    private var soundIdMessageReceived: SystemSoundID?

    override init() {
        super.init()
        if AppConfig.isSimulator == false {
            if let urlSoundMessageReceived = Bundle(for: type(of: self)).url(forResource: "read_sound", withExtension: "mp3", subdirectory: nil) {
                var soundID: SystemSoundID = 0
                if AudioServicesCreateSystemSoundID(urlSoundMessageReceived as CFURL, &soundID) == noErr {
                    self.soundIdMessageReceived = soundID
                    AudioServicesAddSystemSoundCompletion(soundID, nil, nil, { soundID, inClientData in
                        let me = unsafeBitCast(inClientData, to: DPAGStatusBarNotificationDisplay.self)
                        me.audioServicesPlaySystemSoundCompleted(soundID)
                    }, Unmanaged.passRetained(self).toOpaque())
                }
            }
        }
    }

    deinit {
        if let soundIdMessageReceived = self.soundIdMessageReceived {
            AudioServicesRemoveSystemSoundCompletion(soundIdMessageReceived)
            AudioServicesDisposeSystemSoundID(soundIdMessageReceived)
        }
    }

    private func playSounds() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    private var numberReceiveSounds: Int = 0

    func playReceiveSound(_ playSounds: Int) {
        if playSounds == 0 {
            return
        }
        let startLoop = (self.numberReceiveSounds == 0)
        self.numberReceiveSounds = min(DPAGNewMessageNotifier.maximumNumberOfConsecutiveNotifications, self.numberReceiveSounds + playSounds)
        DPAGLog("%@ sounds to play", "\(self.numberReceiveSounds)")
        if startLoop {
            DPAGLog("play %@ sounds", "\(self.numberReceiveSounds)")
            self.performBlockOnMainThread {
                self.playReceiveSounds()
            }
        }
    }

    private func playReceiveSounds() {
        if AppConfig.isSimulator {
            self.numberReceiveSounds = 0
        } else {
            if DPAGApplicationFacade.preferences.skipPlayingReceiveAudio == false, let soundIdMessageReceived = self.soundIdMessageReceived {
                AudioServicesPlaySystemSound(soundIdMessageReceived)
            } else {
                self.numberReceiveSounds = 0
            }
        }
    }

    private func audioServicesPlaySystemSoundCompleted(_: SystemSoundID) {
        self.numberReceiveSounds -= 1
        DPAGLog("%@ sounds still to play", "\(self.numberReceiveSounds)")
        if self.numberReceiveSounds > 0 {
            if DPAGApplicationFacade.preferences.skipPlayingReceiveAudio {
                self.numberReceiveSounds = 0
                DPAGLog("stop playing", "\(self.numberReceiveSounds)")
            } else {
                if let soundIdMessageReceived = self.soundIdMessageReceived {
                    AudioServicesPlaySystemSound(soundIdMessageReceived)
                }
                return
            }
        }
        DPAGLog("finish playing", "\(self.numberReceiveSounds)")
    }

    func showStatusBarNotification(forMessage messageGuid: String) {
        guard DPAGSimsMeController.sharedInstance.canShowStatusBarNotification() else {
            self.delegate?.notificationIsCompletelyDismissedAndCanShowMore(true)
            return
        }
        var imageProfile: UIImage?
        var roundedImageProfile = true
        var streamNameOrNil: String?
        var preview: String?
        var streamGuidOrNil: String?
        if let message = DPAGApplicationFacade.cache.decryptedMessage(messageGuid: messageGuid) {
            streamGuidOrNil = message.streamGuid
            if let decMessagePrivate = message as? DPAGDecryptedMessagePrivate, let contactGuid = decMessagePrivate.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
                streamNameOrNil = contact.displayName
                if decMessagePrivate.isSystemChat {
                    imageProfile = DPAGImageProvider.shared[.kImageChatSystemLogo]
                    roundedImageProfile = false
                } else {
                    imageProfile = contact.image(for: .chat)
                }
            } else if let messageGroup = message as? DPAGDecryptedMessageGroup, let streamGuid = messageGroup.streamGuid, let group = DPAGApplicationFacade.cache.group(for: streamGuid) {
                if message.contentType != .textRSS, let contact = DPAGApplicationFacade.cache.contact(for: message.fromAccountGuid) {
                    streamNameOrNil = String(format: "%@@%@", contact.displayName, streamNameOrNil ?? "")
                } else {
                    streamNameOrNil = group.name
                }
                imageProfile = DPAGUIImageHelper.image(forGroupGuid: streamGuid, imageType: .chat)
            } else if let messageChannel = message as? DPAGDecryptedMessageChannel, let channel = DPAGApplicationFacade.cache.channel(for: messageChannel.channelGuid) {
                streamNameOrNil = channel.name_short
                imageProfile = self.profileImage(forChannel: channel)
                roundedImageProfile = false
            }
            preview = self.getPreviewText(forMessage: message)
        }
        guard let streamName = streamNameOrNil, let streamGuid = streamGuidOrNil else {
            self.delegate?.notificationIsCompletelyDismissedAndCanShowMore(true)
            return
        }
        self.performBlockOnMainThread {
            DPAGLocalNotificationViewController.show(config: DPAGLocalNotificationViewController.LocalNotificationConfig(title: streamName, message: preview, image: nil, imageProfile: imageProfile, roundedImageProfile: roundedImageProfile, duration: DPAGLocalNotificationViewController.NOTIFICATION_DISPLAY_DURATION, isExpanded: false, completionOnShow: { [weak self] isShown in
                if isShown {
                    self?.playSounds()
                }
                }, completionOnHide: { [weak self] isDismissedWithTapGesture, isDismissedWithSwipeUpGesture in
                    if isDismissedWithTapGesture {
                        self?.displayChatStream(streamGuid, withMessage: messageGuid)
                    }
                    self?.delegate?.notificationIsCompletelyDismissedAndCanShowMore(isDismissedWithSwipeUpGesture == false)
            }))
        }
    }

    func showAVCallInvitation(forMessage messageGuid: String) { }

    func showStatusBarNotification(forInvitationToGroupStream streamGuid: String) {
        guard DPAGSimsMeController.sharedInstance.canShowStatusBarNotification() else {
            self.delegate?.notificationIsCompletelyDismissedAndCanShowMore(true)
            return
        }
        guard let group = DPAGApplicationFacade.cache.group(for: streamGuid) else {
            self.delegate?.notificationIsCompletelyDismissedAndCanShowMore(true)
            return
        }
        let imageProfile = DPAGUIImageHelper.image(forGroupGuid: streamGuid, imageType: .chat)
        let groupName = group.name
        let groupType = group.groupType
        let groupMessage: String
        switch groupType {
            case .restricted:
                groupMessage = "notification.restrictedRoomInvitation.message"
            case .managed:
                groupMessage = "notification.managedRoomInvitation.message"
            default:
                groupMessage = "notification.groupInvitation.message"
        }
        self.performBlockOnMainThread {
            DPAGLocalNotificationViewController.show(config: DPAGLocalNotificationViewController.LocalNotificationConfig(title: groupName, message: DPAGLocalizedString(groupMessage), image: nil, imageProfile: imageProfile, roundedImageProfile: true, duration: DPAGLocalNotificationViewController.NOTIFICATION_DISPLAY_DURATION, isExpanded: true, completionOnShow: { [weak self] isShown in
                if isShown {
                    self?.playSounds()
                }
                }, completionOnHide: { [weak self] isDismissedWithTapGesture, isDismissedWithSwipeUpGesture in
                    if isDismissedWithTapGesture {
                        self?.displayChatList(focusedStreamGuid: streamGuid)
                    }
                    self?.delegate?.notificationIsCompletelyDismissedAndCanShowMore(isDismissedWithSwipeUpGesture == false)
            }))
        }
    }

    func showStatusBarNotification(forUnconfirmedChatStream streamGuid: String) {
        guard DPAGSimsMeController.sharedInstance.canShowStatusBarNotification() else {
            self.delegate?.notificationIsCompletelyDismissedAndCanShowMore(true)
            return
        }
        var imageProfile: UIImage?
        var roundedImageProfile = true
        var streamName: String?
        if let stream = DPAGApplicationFacade.cache.decryptedStream(streamGuid: streamGuid, in: nil) {
            if let streamPrivate = stream as? DPAGDecryptedStreamPrivate, let contactGuid = streamPrivate.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
                streamName = contact.displayName
                imageProfile = contact.image(for: .chat)
            } else if let streamGroup = stream as? DPAGDecryptedStreamGroup {
                imageProfile = DPAGUIImageHelper.image(forGroupGuid: streamGuid, imageType: .chat)
                streamName = streamGroup.streamName
            } else if stream is DPAGDecryptedStreamChannel, let channel = DPAGApplicationFacade.cache.channel(for: streamGuid) {
                streamName = channel.name_short
                imageProfile = self.profileImage(forChannel: channel)
                roundedImageProfile = false
            }
        }
        if streamName == nil {
            self.delegate?.notificationIsCompletelyDismissedAndCanShowMore(true)
            return
        }
        self.performBlockOnMainThread {
            DPAGLocalNotificationViewController.show(config: DPAGLocalNotificationViewController.LocalNotificationConfig(title: streamName, message: DPAGLocalizedString("notification.unconfirmedChatStream.message"), image: nil, imageProfile: imageProfile, roundedImageProfile: roundedImageProfile, duration: DPAGLocalNotificationViewController.NOTIFICATION_DISPLAY_DURATION, isExpanded: true, completionOnShow: { [weak self] isShown in
                if isShown {
                    self?.playSounds()
                }
                }, completionOnHide: { [weak self] isDismissedWithTapGesture, isDismissedWithSwipeUpGesture in
                    if isDismissedWithTapGesture {
                        self?.displayChatList(focusedStreamGuid: streamGuid)
                    }
                    self?.delegate?.notificationIsCompletelyDismissedAndCanShowMore(isDismissedWithSwipeUpGesture == false)
            }))
        }
    }

    // MARK: - content view

    private func getPreviewText(forMessage message: DPAGDecryptedMessage) -> String? {
        var contentType: DPAGMessageContentType = message.contentType
        if message.errorType != .none, message.errorType != .notChecked {
            contentType = .plain
        }
        let isOwnMessage = message.isOwnMessage
        var previewText: String?
        if message.isSelfDestructive {
            previewText = DPAGLocalizedString("chat.selfdestruction.preview")
        } else {
            switch contentType {
                case .avCallInvitation:
                    previewText = "📞"
                case .controlMsgNG:
                    previewText = ""
                case .plain, .oooStatusMessage, .textRSS:
                    if let decryptedMessageChannel = message as? DPAGDecryptedMessageChannel, let content = decryptedMessageChannel.content {
                        switch decryptedMessageChannel.feedType {
                            case .channel:
                                previewText = (DPAGApplicationFacade.feedWorker as? DPAGFeedWorkerProtocolSwift)?.replaceChannelLink(content, contentLinkReplacer: decryptedMessageChannel.contentLinkReplacer).content
                        }
                    } else {
                        previewText = message.content
                    }
                case .image:
                    previewText = isOwnMessage ? DPAGLocalizedString("chat.overview.preview.imageSent") : DPAGLocalizedString("chat.overview.preview.imageReceived")
                case .video:
                    previewText = isOwnMessage ? DPAGLocalizedString("chat.overview.preview.videoSent") : DPAGLocalizedString("chat.overview.preview.videoReceived")
                case .location:
                    previewText = isOwnMessage ? DPAGLocalizedString("chat.overview.preview.locationSent") : DPAGLocalizedString("chat.overview.preview.locationReceived")
                case .contact:
                    previewText = isOwnMessage ? DPAGLocalizedString("chat.overview.preview.contactSent") : DPAGLocalizedString("chat.overview.preview.contactReceived")
                case .voiceRec:
                    previewText = isOwnMessage ? DPAGLocalizedString("chat.overview.preview.VoiceSent") : DPAGLocalizedString("chat.overview.preview.VoiceReceived")
                case .file:
                    previewText = isOwnMessage ? DPAGLocalizedString("chat.overview.preview.FileSent") : DPAGLocalizedString("chat.overview.preview.FileReceived")
            }
            if message.isHighPriorityMessage {
                previewText = DPAGLocalizedString("chat.overview.preview.HighPriorityPre") + (previewText ?? "")
            }
        }

        return previewText
    }

    private func profileImage(forChannel channel: DPAGChannel) -> UIImage? {
        let assetsList = DPAGApplicationFacade.feedWorker.assetsChat(feedGuid: channel.guid)
        if let profileImage = assetsList[.profile] as? UIImage {
            return profileImage
        } else {
            DPAGApplicationFacade.feedWorker.updateAssets(feedGuids: [channel.guid], feedType: channel.feedType) {}
        }
        return nil
    }

    private func displayChatStream(_ streamGuid: String, withMessage messageGuid: String) {
        guard let window = AppConfig.appWindow(), let viewControllerRoot = window?.rootViewController as? (UIViewController & DPAGRootContainerViewControllerProtocol) else { return }
        guard viewControllerRoot.children.first as? (UIViewController & DPAGContainerViewControllerProtocol) != nil else { return }
        if DPAGSimsMeController.sharedInstance.isWaitingForLogin == false {
            DPAGProgressHUD.sharedInstance.show(true) { _ in
                DPAGSimsMeController.sharedInstance.dismissAllPresentedNavigationControllers(true, completionInBackground: false) {
                    DPAGChatHelper.openChatStreamView(streamGuid, navigationController: DPAGApplicationFacadeUIBase.containerVC.secondaryNavigationController, showMessage: messageGuid) { _ in
                        DPAGProgressHUD.sharedInstance.hide(true)
                    }
                }
            }
        }
    }

    func showStatusBarNotification(title: String, text: String) {
        DPAGLocalNotificationViewController.show(
            config: DPAGLocalNotificationViewController.LocalNotificationConfig(
                title: title,
                message: text,
                image: nil,
                imageProfile: DPAGImageProvider.shared[.kImageChatSystemLogo],
                roundedImageProfile: false,
                duration: DPAGLocalNotificationViewController.NOTIFICATION_DISPLAY_DURATION,
                isExpanded: true,
                completionOnShow: { [weak self] isShown in
                    if isShown {
                        self?.playSounds()
                    }
                },
                completionOnHide: { [weak self] isDismissedWithTapGesture, _ in
                    if isDismissedWithTapGesture {
                        self?.displayChatList(focusedStreamGuid: nil)
                    }
                }
            )
        )
    }

    func containerVC() -> (UIViewController & DPAGContainerViewControllerProtocol)? {
        guard let window = AppConfig.appWindow(), let viewControllerRoot = window?.rootViewController as? (UIViewController & DPAGRootContainerViewControllerProtocol) else { return nil }
        guard let viewController = viewControllerRoot.children.first as? (UIViewController & DPAGContainerViewControllerProtocol) else { return nil }
        return viewController
    }

    private func displayChatList(focusedStreamGuid streamGuid: String?) {
        guard let containerVC = self.containerVC() else { return }
        self.closeCurrentView(containerVC.mainNavigationController)
        if let streamGuid = streamGuid {
            DPAGSimsMeController.sharedInstance.chatsListViewController.scrollToStream(streamGuid)
        }
    }

    private func closeCurrentView(_ navigationController: UINavigationController) {
        let activeViewControllers = navigationController.viewControllers
        var chatVC: (UIViewController & DPAGChatsListViewControllerProtocol)?
        for vc in activeViewControllers where vc is (UIViewController & DPAGChatsListViewControllerProtocol) {
            chatVC = vc as? (UIViewController & DPAGChatsListViewControllerProtocol)
            break
        }
        if let chatVC = chatVC {
            if navigationController.presentedViewController != nil {
                navigationController.dismiss(animated: true) {
                    navigationController.popToViewController(chatVC, animated: true)
                }
            } else {
                navigationController.popToViewController(chatVC, animated: true)
            }
        } else {
            DPAGApplicationFacadeUIBase.containerVC.showTopMainViewController(DPAGSimsMeController.sharedInstance.chatsListViewController, completion: nil)
        }
    }
}
