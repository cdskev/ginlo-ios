//
//  DPAGNewMessageNotifier.swift
//  SIMSme
//
//  Created by RBU on 09/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGNewMessageNotifierProtocol: AnyObject {
    var isReceivingInitialMessagesProcessRunning: Bool { get }

    func initialReceivingCheckForNewMessages()
    func stopRequesting()
}

class DPAGNewMessageNotifier: NSObject, DPAGNewMessageNotifierProtocol {
    static let sharedInstance: DPAGNewMessageNotifierProtocol = DPAGNewMessageNotifier()

    private var statusBarNotificationDisplay = DPAGApplicationFacadeUI.statusBarNotificationDisplay()
    private var notifiableNewMessages: [Any] = []

    private var isNotificationProcessRunning: Bool = false
    var isReceivingInitialMessagesProcessRunning: Bool = false
    private var isInBackground: Bool = false
    private var displayedNotificationCount: Int = 0
    private var timeToShowNextStatusBarNotification: TimeInterval = TimeInterval(0)
    private var preventLazy: Bool = true

    private var forceStop: Bool = false

    private let queueSyncVars = DispatchQueue(label: "de.dpag.simsme.DPAGNewMessageNotifier.queueSyncVars", qos: .background, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    private var lastRunInternal: Date = Date()

    private var lastRun: Date {
        get {
            var rc: Date?
            self.queueSyncVars.sync(flags: DispatchWorkItemFlags.barrier) {
                rc = self.lastRunInternal
            }

            return rc ?? Date()
        }
        set {
            self.queueSyncVars.sync(flags: DispatchWorkItemFlags.barrier) {
                self.lastRunInternal = newValue
            }
        }
    }

    private var queueGetNewMessages = OperationQueue()

    private weak var requestGetNewMessages: URLSessionTask?

    private var observerBackground: NSObjectProtocol?
    private var observerPrivateKey: NSObjectProtocol?

    override init() {
        super.init()

        self.statusBarNotificationDisplay.delegate = self

        self.queueGetNewMessages.maxConcurrentOperationCount = 1

        self.queueGetNewMessages.qualityOfService = QualityOfService.userInitiated

        self.isReceivingInitialMessagesProcessRunning = true

        // Watchdog, der überwacht, das immer ein Task in der Queue ist
        _ = Timer.scheduledTimer(timeInterval: 0.4, target: self, selector: #selector(DPAGNewMessageNotifier.checkQueue), userInfo: nil, repeats: true)

        // Warm Up
        DPAGCryptoHelper.initAccount()

        self.observerBackground = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil, queue: .main) { [weak self] _ in

            self?.isInBackground = true
            self?.requestGetNewMessages?.cancel()
        }

        self.observerPrivateKey = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Application.UI_IS_READY_WITH_PRIVATE_KEY, object: nil, queue: .main) { [weak self] _ in

            self?.isInBackground = false
            self?.isReceivingInitialMessagesProcessRunning = true
            self?.lastRun = Date()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)

        if let observerBackground = self.observerBackground {
            NotificationCenter.default.removeObserver(observerBackground)
        }
        if let observerPrivateKey = self.observerPrivateKey {
            NotificationCenter.default.removeObserver(observerPrivateKey)
        }
    }

    @objc
    private func checkQueue() {
        if self.isInBackground || self.queueGetNewMessages.operationCount > 0 {
            return
        }
        if self.lastRun.timeIntervalSinceNow < -1 {
            if self.forceStop {
                // dissmiss Background Thread
                DPAGLog("Skipping Queue")
                return
            }

            DPAGLog("Restarting Queue")
            self.checkForNewMessages()
        }
    }

    func stopRequesting() {
        self.forceStop = true
    }

    func initialReceivingCheckForNewMessages() {
        self.lastRun = Date()
        self.isInBackground = false
        self.isReceivingInitialMessagesProcessRunning = true
        self.checkForNewMessages()
    }

    private func checkForNewMessages() {
        self.forceStop = false
        self.lastRun = Date()
        self.checkForNewMessagesInternalDoNotNotifyUser()
    }

    @objc
    private func checkForNewMessagesInternal() {
        self.lastRun = Date()
        self.checkForNewMessagesInternalWithNotifications(true)
    }

    @objc
    private func checkForNewMessagesInternalDoNotNotifyUser() {
        self.lastRun = Date()
        self.checkForNewMessagesInternalWithNotifications(false)
    }

    private func checkForNewMessagesInternalWithNotifications(_ showNotifications: Bool) {
        if self.queueGetNewMessages.operationCount > 2 {
            return
        }
        if self.isInBackground {
            return
        }
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let strongOperation = operation, let strongSelf = self else { return }
            if strongOperation.isCancelled {
                return
            }
            let isActive = AppConfig.applicationState() != .background
            if isActive, CryptoHelper.sharedInstance?.isPrivateKeyDecrypted() ?? false {
                if strongSelf.isReceivingInitialMessagesProcessRunning {
                    NotificationCenter.default.post(name: DPAGStrings.Notification.ReceivingNewMessages.STARTED, object: nil)
                }
                let dateStart = Date()
                let sema = DispatchSemaphore(value: 0)
                let completion: (ReceivedMessagesResponse) -> Void = { response in
                    guard let strongOperation = operation, let strongSelf = self else { return }
                    if strongOperation.isCancelled {
                        return
                    }
                    strongSelf.lastRun = Date()
                    if Thread.isMainThread {
                        assert(false, "Should not run on Mainthread")
                        DPAGLog("RunOnMain")
                    }
                    if strongSelf.isInBackground {
                        sema.signal()
                        NotificationCenter.default.post(name: DPAGStrings.Notification.ReceivingNewMessages.FINISHED, object: nil)
                        return
                    }
                    DPAGLog("Release Lock")
                    sema.signal()
                    if response.errorMessage != nil {
                        strongSelf.isReceivingInitialMessagesProcessRunning = false
                        if CryptoHelper.sharedInstance?.isPrivateKeyInMemory() ?? false, strongSelf.requestGetNewMessages == nil || (strongSelf.requestGetNewMessages?.state ?? .running) != .canceling {
                            let dateEnd = Date()
                            var delay = TimeInterval(1)
                            if dateEnd.timeIntervalSince(dateStart) < TimeInterval(30) {
                                delay = TimeInterval(DPAGApplicationFacade.preferences.listRefreshRate)
                            }
                            if showNotifications == false {
                                strongSelf.performBlockOnMainThread {
                                    self?.perform(#selector(DPAGNewMessageNotifier.checkForNewMessagesInternalDoNotNotifyUser), with: nil, afterDelay: delay)
                                }
                            } else {
                                strongSelf.performBlockOnMainThread {
                                    self?.perform(#selector(DPAGNewMessageNotifier.checkForNewMessagesInternal), with: nil, afterDelay: delay)
                                }
                            }
                        }
                        if response.errorMessage == "service.ERR-0119" {
                            DPAGSimsMeController.sharedInstance.showPurchaseIfPossible()
                        }
                        NotificationCenter.default.post(name: DPAGStrings.Notification.ReceivingNewMessages.FAILED, object: nil)
                    } else {
                        let messages = response.messagesWithNotification
                        if let messages = messages, messages.isEmpty == false {
                            if CryptoHelper.sharedInstance?.isPrivateKeyInMemory() ?? false {
                                strongSelf.performBlockInBackground {
                                    self?.maybeShowNotificationForNewMessages(showNotifications, messages)
                                }
                            }
                        }
                        if strongSelf.isReceivingInitialMessagesProcessRunning {
                            // Wenn keine Nachrichten mehr kommen, dann ist der Initiale Prozess fertig
                            if messages?.isEmpty ?? true {
                                strongSelf.isReceivingInitialMessagesProcessRunning = false
                            } else {
                                // neue Nachrichten Empfangen --> Eventuell gibts da noch mehr ....
                                strongSelf.performBlockOnMainThread {
                                    self?.perform(#selector(DPAGNewMessageNotifier.checkForNewMessagesInternalDoNotNotifyUser), with: nil, afterDelay: TimeInterval(0.01))
                                }
                                return
                            }
                        }
                        if let messages = messages, messages.isEmpty == false {
                            if CryptoHelper.sharedInstance?.isPrivateKeyInMemory() ?? false {
                                strongSelf.performBlockInBackground {
                                    self?.preparePlaySounds(messages)
                                }
                            }
                        }
                        strongSelf.performBlockOnMainThread {
                            self?.perform(#selector(DPAGNewMessageNotifier.checkForNewMessagesInternal), with: nil, afterDelay: DPAGApplicationFacade.preferences.lazyMsgServiceEnabled ? TimeInterval(0.01) : TimeInterval(DPAGApplicationFacade.preferences.listRefreshRate))
                        }
                        NotificationCenter.default.post(name: DPAGStrings.Notification.ReceivingNewMessages.FINISHED, object: nil)
                    }
                }
                strongSelf.requestGetNewMessages?.cancel()
                strongSelf.requestGetNewMessages = DPAGApplicationFacade.receiveMessagesWorker.getNewMessages(completion: completion, useLazy: !strongSelf.isReceivingInitialMessagesProcessRunning && showNotifications && !strongSelf.preventLazy && DPAGApplicationFacade.preferences.lazyMsgServiceEnabled)
                strongSelf.preventLazy = false
                let requestGetNewMessages = strongSelf.requestGetNewMessages
                if Thread.isMainThread {
                    assert(false, "Should not run on Mainthread")
                    DPAGLog("RunOnMain")
                }
                let timeUpStart = DispatchTime.now()
                let timeUp = DispatchTime.now() + Double(Int64(61 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)
                var bSuccess = false
                for index: UInt64 in stride(from: 0, to: 60, by: 1) {
                    let nextTime = timeUpStart + Double(Int64(index * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)
                    if sema.wait(timeout: nextTime) == DispatchTimeoutResult.success {
                        bSuccess = true
                        break
                    }
                    if strongOperation.isCancelled {
                        requestGetNewMessages?.cancel()
                        DPAGLog("DPAGNewMessages Operation was Cancelled before (lock data)")
                        return
                    }
                }
                if !bSuccess, sema.wait(timeout: timeUp) != DispatchTimeoutResult.success {
                    requestGetNewMessages?.cancel()
                    strongSelf.checkForNewMessages()
                }
            } else {
                DPAGLog("Application not active or no decrypted key present")
            }
        }

        if self.queueGetNewMessages.operationCount > 0 {
            self.requestGetNewMessages?.cancel()
            self.requestGetNewMessages = nil
            self.queueGetNewMessages.cancelAllOperations()
        }
        operation.queuePriority = Operation.QueuePriority.high
        self.queueGetNewMessages.addOperation(operation)
        DPAGLog("DPAGNewMessages Queue checkForNewMessagesInternalWithNotifications \(self.queueGetNewMessages.operationCount) \(self.queueGetNewMessages.isSuspended) ")
    }

    private func preparePlaySounds(_ messages: ReceivedMessagesWithNotification) {
        var messagesToPlay = 0
        // Settings auswerten ...
        if DPAGApplicationFacade.preferences.isChatNotificationSoundEnabled(chatType: .single) {
            messagesToPlay += messages.messagesPrivate.count
        }
        if DPAGApplicationFacade.preferences.isChatNotificationSoundEnabled(chatType: .group) {
            messagesToPlay += messages.messagesGroup.count
        }
        if DPAGApplicationFacade.preferences.isChatNotificationSoundEnabled(chatType: .channel) {
            for channelMessageGuid in messages.messagesChannel {
                if let channelMsg = DPAGApplicationFacade.cache.decryptedMessage(messageGuid: channelMessageGuid) as? DPAGDecryptedMessageChannel, let channel = DPAGApplicationFacade.cache.channel(for: channelMsg.channelGuid) {
                    if DPAGApplicationFacade.preferences.isChatNotificationEnabled(feedType: channel.feedType, feedGuid: channel.guid) {
                        messagesToPlay += 1
                    }
                }
            }
        }
        if messagesToPlay > 0 {
            statusBarNotificationDisplay.playReceiveSound(messagesToPlay)
        }
    }

    // Another SHIT here...
    private func maybeShowNotificationForNewMessages(_ showNotifications: Bool, _ messages: ReceivedMessagesWithNotification) {
        if showNotifications {
            showNotificationForNewMessages(messages)
        } else if messages.isEmpty == false {
            var relevantMessages: [Any] = []
            relevantMessages.append(contentsOf: messages.messagesPrivate)
            relevantMessages.append(contentsOf: messages.messagesGroup)
            for messageGuid in relevantMessages.reversed() {
                if let messageGuidAsString = messageGuid as? String, let message = DPAGApplicationFacade.cache.decryptedMessage(messageGuid: messageGuidAsString), message.contentType == .avCallInvitation, Date(timeIntervalSinceNow: -30).compare(message.messageDate ?? Date()) == .orderedAscending  {
                    showStatusBarNotificationForMessageWithContent(messageGuidAsString)
                    break
                }
            }
        }
    }
    
    private func showNotificationForNewMessages(_ messages: ReceivedMessagesWithNotification) {
        if DPAGApplicationFacade.preferences.isInAppNotificationEnabled == false {
            return
        }
        self.performBlockOnMainThread { [weak self] in
            if DPAGProgressHUD.sharedInstance.isHUDVisible() {
                return
            }
            guard let strongSelf = self else { return }
            let relevantNewMessages = strongSelf.filterRelevantNewMessages(messages)
            if relevantNewMessages.count > 0 {
                if Date.timeIntervalSinceReferenceDate > strongSelf.timeToShowNextStatusBarNotification {
                    DPAGFunctionsGlobal.synchronized(strongSelf) {
                        strongSelf.notifiableNewMessages.insert(contentsOf: relevantNewMessages, at: 0)
                    }
                } else {
                    DPAGLog("Not showing status bar notification for \(relevantNewMessages.count) messages because they were received during the cooldown time")
                }
            }
            if !strongSelf.isNotificationProcessRunning {
                strongSelf.showNextNotificationForNewMessages()
            }
        }
    }

    private func filterRelevantNewMessages(_ messages: ReceivedMessagesWithNotification) -> [Any] {
        var relevantMessages: [Any] = []
        self.addReceivedMessagesToRelevantMessagesIfNeeded(relevantMessages: &relevantMessages, notificationChatType: .group, receivedMessages: messages.messagesGroupInvitation)
        self.addReceivedMessagesToRelevantMessagesIfNeeded(relevantMessages: &relevantMessages, notificationChatType: .single, receivedMessages: messages.messagesPrivate)
        self.addReceivedMessagesToRelevantMessagesIfNeeded(relevantMessages: &relevantMessages, notificationChatType: .group, receivedMessages: messages.messagesGroup)
        self.addReceivedMessagesToRelevantMessagesIfNeeded(relevantMessages: &relevantMessages, notificationChatType: .channel, receivedMessages: messages.messagesChannel)
        return relevantMessages
    }

    private func addReceivedMessagesToRelevantMessagesIfNeeded(relevantMessages: inout [Any], notificationChatType: DPAGNotificationChatType, receivedMessages: [Any]) {
        var addMessages = false
        if AppConfig.isSimulator {
            addMessages = true
        } else {
            addMessages = DPAGApplicationFacade.preferences.isChatNotificationEnabled(chatType: notificationChatType) && (relevantMessages.count < DPAGNewMessageNotifier.maximumNumberOfConsecutiveNotifications)
        }
        if addMessages {
            relevantMessages.append(contentsOf: receivedMessages.prefix(DPAGNewMessageNotifier.maximumNumberOfConsecutiveNotifications - relevantMessages.count))
        }
    }

    // MARK: - show notifications

    private func showNextNotificationForNewMessages() {
        if self.notifiableNewMessages.count > 0, CryptoHelper.sharedInstance?.isPrivateKeyInMemory() ?? false {
            self.isNotificationProcessRunning = true
            var message: Any?
            DPAGFunctionsGlobal.synchronized(self) {
                message = self.notifiableNewMessages.removeFirst()
            }
            self.showStatusBarNotificationForMessage(message)
        } else {
            self.isNotificationProcessRunning = false
        }
    }

    private func showStatusBarNotificationForMessage(_ message: Any?) {
        if let invitation = message as? SIMSGroupInvitation {
            self.showStatusBarNotificationForInvitation(invitation)
        } else if let messageGuid = message as? String {
            self.showStatusBarNotificationForMessageWithContent(messageGuid)
        }
    }

    private func showStatusBarNotificationForInvitation(_ message: SIMSGroupInvitation) {
        self.statusBarNotificationDisplay.showStatusBarNotification(forInvitationToGroupStream: message.groupGuid)
    }

    private func showStatusBarNotificationForMessageWithContent(_ messageGuid: String) {
        var isConfirmed = false
        var isAVCallInvitation = false
        var streamGuidDB: String?
        var showMessage = true
        if let message = DPAGApplicationFacade.cache.decryptedMessage(messageGuid: messageGuid), let streamGuid = message.streamGuid, let stream = DPAGApplicationFacade.cache.decryptedStream(streamGuid: streamGuid, in: nil) {
            streamGuidDB = streamGuid
            if let streamPrivate = stream as? DPAGDecryptedStreamPrivate, let contactGuid = streamPrivate.contactGuid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
                isConfirmed = contact.isConfirmed
            } else if stream is DPAGDecryptedStreamGroup, let group = DPAGApplicationFacade.cache.group(for: streamGuid) {
                isConfirmed = group.isConfirmed
            } else if stream is DPAGDecryptedStreamChannel {
                isConfirmed = true
            }
            if AppConfig.isSimulator == false {
                isAVCallInvitation = message.contentType == .avCallInvitation
                if isAVCallInvitation {
                    showMessage = true
                } else if let channelStream = stream as? DPAGDecryptedStreamChannel {
                    let feedType = channelStream.feedType
                    switch feedType {
                        case .channel:
                            showMessage = DPAGApplicationFacade.preferences.isChatNotificationEnabled(chatType: .channel) && DPAGApplicationFacade.preferences.isChatNotificationEnabled(feedType: .channel, feedGuid: streamGuid)
                        case .service:
                            showMessage = DPAGApplicationFacade.preferences.isChatNotificationEnabled(chatType: .service) && DPAGApplicationFacade.preferences.isChatNotificationEnabled(feedType: .service, feedGuid: streamGuid)
                    }
                } else if stream is DPAGDecryptedStreamGroup {
                    showMessage = DPAGApplicationFacade.preferences.isChatNotificationEnabled(chatType: .group)
                } else if stream is DPAGDecryptedStreamPrivate {
                    showMessage = DPAGApplicationFacade.preferences.isChatNotificationEnabled(chatType: .single)
                }
            }
        }
        guard showMessage, let streamGuid = streamGuidDB else {
            self.showNextNotificationForNewMessages()
            return
        }
        if isConfirmed == false && isAVCallInvitation == false {
            self.statusBarNotificationDisplay.showStatusBarNotification(forUnconfirmedChatStream: streamGuid)
        } else if isAVCallInvitation == true {
            if let message = DPAGApplicationFacade.cache.decryptedMessage(messageGuid: messageGuid), message.contentType == .avCallInvitation, Date(timeIntervalSinceNow: -30).compare(message.dateSendServer ?? Date()) == .orderedAscending  {
                self.showInvitationForAVCall(message: messageGuid)
            }
        } else {
            self.showStatusBarNotificationForConfirmedChatStream(streamGuid, message: messageGuid)
        }
    }

    private func showInvitationForAVCall(message messageGuid: String) {
        DPAGSimsMeController.sharedInstance.chatsListViewController.showAVCallInvitation(forMessage: messageGuid)
        notificationIsCompletelyDismissedAndCanShowMore(true)
    }
    
    private func showStatusBarNotificationForConfirmedChatStream(_ streamGuid: String, message messageGuid: String) {
        if self.shouldDisplayMessageNotificationForVisibleViewController(streamGuid) == false {
            self.showNextNotificationForNewMessages()
            return
        }
        self.statusBarNotificationDisplay.showStatusBarNotification(forMessage: messageGuid)
    }

    private func shouldDisplayMessageNotificationForVisibleViewController(_ streamGuid: String) -> Bool {
        guard let containerVC = self.statusBarNotificationDisplay.containerVC() else { return false }
        if let visibleViewController = containerVC.mainNavigationController.visibleViewController, visibleViewController.navigationController != visibleViewController {
            if visibleViewController is DPAGModalViewControllerProtocol || visibleViewController is UIAlertController {
                return false
            }
            if let viewControllers = visibleViewController.navigationController?.viewControllers {
                for vc in viewControllers {
                    if let streamVC = vc as? DPAGChatStreamBaseViewControllerProtocol, streamVC.streamGuid == streamGuid {
                        return false
                    }
                }
            }
        }
        for vc in containerVC.mainNavigationController.viewControllers {
            if let streamVC = vc as? DPAGChatStreamBaseViewControllerProtocol, streamVC.streamGuid == streamGuid {
                return false
            }
        }
        return true
    }
}

// MARK: - DPAGStatusBarNotificationDisplayDelegate

extension DPAGNewMessageNotifier: DPAGStatusBarNotificationDisplayDelegate {
    static let maximumNumberOfConsecutiveNotifications = 3
    func notificationIsCompletelyDismissedAndCanShowMore(_ showMore: Bool) {
        let numberOfSecondsToCooldown = TimeInterval(60)
        // The user manually dismissed the notification
        if showMore == false {
            self.notifiableNewMessages.removeAll()
        }
        // Increase the counter of shown and dismissed notifications
        self.displayedNotificationCount += 1
        if self.displayedNotificationCount >= DPAGNewMessageNotifier.maximumNumberOfConsecutiveNotifications {
            // Show notification that there are more messages in the queue
            if self.notifiableNewMessages.isEmpty == false {
                DPAGLog("Not showing status bar notification for \(self.notifiableNewMessages.count) more messages because we've already shown self.displayedNotificationCount consecutive notifications")
                self.statusBarNotificationDisplay.showStatusBarNotification(title: String(format: DPAGLocalizedString("chat.system.nickname"), DPAGMandant.default.name), text: DPAGLocalizedString("notification.too_many_notifications_message"))
            }
            self.notifiableNewMessages.removeAll()
            // Cooldown
            self.timeToShowNextStatusBarNotification = Date.timeIntervalSinceReferenceDate + numberOfSecondsToCooldown
            DPAGLog("Setting cooldown time for status bar notification to \(Date(timeIntervalSinceReferenceDate: self.timeToShowNextStatusBarNotification))")
        }
        self.showNextNotificationForNewMessages()
        // More notifications in the queue?
        if self.notifiableNewMessages.isEmpty {
            self.displayedNotificationCount = 0
        }
    }
}
