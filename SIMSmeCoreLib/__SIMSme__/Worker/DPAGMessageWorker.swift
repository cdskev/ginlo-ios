//
//  DPAGMessageWorker.swift
//  SIMSme
//
//  Created by RBU on 27/01/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

protocol DPAGMessageCryptoWorkerProtocol: AnyObject {
    func decryptAesKey(_ encAesKey: String) throws -> String?

    func decryptAttachment(_ encAttachment: String, encAesKey: String?) -> Data?
    func decryptAttachment(_ encAttachment: String, decAesKey: String?) -> Data?
    func decryptAttachment(_ encAttachment: String, decAesKeyDict: DPAGAesKeyDecrypted?) -> Data?

    func decryptMessageDict(_ encMessageDict: String?, encAesKey: String?, encAesKey2: String?, aesKeyIV iv: String?) -> DPAGMessageDictionary?
    func decryptGroupMessageData(_ messageData: String, decAesKey: String) -> DPAGMessageDictionary?

    func decryptMessageDict(_ message: SIMSPrivateMessage) -> DPAGMessageDictionary?
    func decryptOwnMessageToSendDict(_ message: SIMSMessageToSendPrivate) -> DPAGMessageDictionary?
    func decryptOwnMessageDict(_ message: SIMSPrivateMessage) -> DPAGMessageDictionary?
    func decryptContactMessageDict(_ message: SIMSPrivateMessage) -> DPAGMessageDictionary?
    func decryptGroupMessageDict(_ message: SIMSGroupMessage?, decAesKey: String) -> DPAGMessageDictionary?
    func decryptGroupMessageToSendDict(_ message: SIMSMessageToSend, decAesKey: String) -> DPAGMessageDictionary?
    func decryptChannelMessage(_ message: SIMSChannelMessage, decAesKeyDict: DPAGAesKeyDecrypted) -> DPAGMessageDictionary?

    func decryptPrivateInternalMessage(data: String, encAesKey: String) -> DPAGMessageDictionary?

    func decryptString(_ encString: String?, withKey keyIn: SIMSKey?) -> String?
}

class DPAGMessageCryptoWorker: NSObject, DPAGMessageCryptoWorkerProtocol {
    func signString(_ value: String) throws -> String? {
        try DPAGCryptoHelper.newAccountCrypto()?.signData(data: value)
    }

    func decryptMessageDict(_ encMessageDict: String?, encAesKey: String?, encAesKey2: String?, aesKeyIV iv: String?) -> DPAGMessageDictionary? {
        guard let messageDict = encMessageDict else {
            return nil
        }

        var decryptedMessageDict: DPAGMessageDictionary?

        if let encAesKey2 = encAesKey2, let iv = iv {
            do {
                if let decAesKey = DPAGApplicationFacade.cache.cachedAesKey(key: encAesKey2) {
                    if let decMessage = self.decryptMessageDict(messageDict, decAesKeyDictionary: DPAGAesKeyDecrypted(aesKey: decAesKey, iv: iv)) {
                        decryptedMessageDict = self.decryptedMessageDict(decMessage)
                    }
                } else if let decAesKey = try DPAGCryptoHelper.newAccountCrypto()?.decryptAesKey(encryptedAeskey: encAesKey2) {
                    DPAGApplicationFacade.cache.setCachedAesKey(aesKey: decAesKey, forKey: encAesKey2)

                    if let decMessage = self.decryptMessageDict(messageDict, decAesKeyDictionary: DPAGAesKeyDecrypted(aesKey: decAesKey, iv: iv)) {
                        decryptedMessageDict = self.decryptedMessageDict(decMessage)
                    }
                }
            } catch {
                DPAGLog(error)
            }
        }
        if decryptedMessageDict == nil, let encAesKey = encAesKey {
            do {
                if let decAesKey = try DPAGCryptoHelper.newAccountCrypto()?.decryptAesKey(encryptedAeskey: encAesKey), let decMessage = self.decryptMessageDict(messageDict, decAesKey: decAesKey) {
                    decryptedMessageDict = self.decryptedMessageDict(decMessage)
                }
            } catch {
                DPAGLog(error)
            }
        }
        return decryptedMessageDict
    }

    func decryptMessageDict(_ encMessageDict: String, decAesKeyDictionary decAesKeyDict: DPAGAesKeyDecrypted) -> String? {
        var decMessage: String?

        do {
            decMessage = try CryptoHelperDecrypter.decryptToString(encryptedString: encMessageDict, withAesKeyDict: decAesKeyDict.dict)
        } catch {
            DPAGLog(error)
        }

        return decMessage
    }

    func decryptMessageDict(_ encMessageDict: String, decAesKey: String) -> String? {
        var decMessage: String?

        do {
            decMessage = try CryptoHelperDecrypter.decryptToString(encryptedString: encMessageDict, withAesKey: decAesKey)
        } catch {
            DPAGLog(error)
        }

        return decMessage
    }

    func decryptAttachment(_ encAttachment: String, encAesKey: String?) -> Data? {
        var decAttachment: Data?

        guard let encAesKey = encAesKey else {
            return decAttachment
        }

        do {
            if let decAesKey = try DPAGCryptoHelper.newAccountCrypto()?.decryptAesKey(encryptedAeskey: encAesKey) {
                decAttachment = try CryptoHelperDecrypter.decrypt(encryptedString: encAttachment, withAesKey: decAesKey)
            }
        } catch {
            DPAGLog(error)
        }
        return (decAttachment?.count ?? 0) > 0 ? decAttachment : nil
    }

    func decryptAttachment(_ encAttachment: String, decAesKey: String?) -> Data? {
        var decAttachment: Data?

        guard let decAesKey = decAesKey else {
            return decAttachment
        }

        do {
            decAttachment = try CryptoHelperDecrypter.decrypt(encryptedString: encAttachment, withAesKey: decAesKey)
        } catch {
            DPAGLog(error)
        }
        return decAttachment
    }

    func decryptAttachment(_ encAttachment: String, decAesKeyDict: DPAGAesKeyDecrypted?) -> Data? {
        var decAttachment: Data?

        guard let decAesKeyDict = decAesKeyDict else {
            return decAttachment
        }

        do {
            decAttachment = try CryptoHelperDecrypter.decrypt(encryptedString: encAttachment, withAesKeyDict: decAesKeyDict.dict)
        } catch {
            DPAGLog(error)
        }
        return decAttachment
    }

    func decryptAesKey(_ encAesKey: String) throws -> String? {
        try DPAGCryptoHelper.newAccountCrypto()?.decryptAesKey(encryptedAeskey: encAesKey)
    }

    func decryptChannelMessage(_ message: SIMSChannelMessage, decAesKeyDict: DPAGAesKeyDecrypted) -> DPAGMessageDictionary? {
        if let data = message.data, let decJsonString = self.decryptMessageDict(data, decAesKeyDictionary: decAesKeyDict) {
            return self.decryptedMessageDict(decJsonString)
        }
        return nil
    }

    func decryptGroupMessageDict(_ message: SIMSGroupMessage?, decAesKey: String) -> DPAGMessageDictionary? {
        if message == nil {
            return nil
        }
        var decryptedMessageDict: DPAGMessageDictionary?
        DPAGLog("decryptGroupMessage")
        guard let messageData = message?.data else {
            return decryptedMessageDict
        }
        decryptedMessageDict = self.decryptGroupMessageData(messageData, decAesKey: decAesKey)
        return decryptedMessageDict
    }

    func decryptGroupMessageData(_ messageData: String, decAesKey: String) -> DPAGMessageDictionary? {
        var decryptedMessageDict: DPAGMessageDictionary?
        if let encMessageData = Data(base64Encoded: messageData) {
            if encMessageData.count >= 16 {
                let iv = encMessageData.subdata(in: 0 ..< 16).base64EncodedString()
                let dataString = encMessageData.subdata(in: 16 ..< encMessageData.count).base64EncodedString()
                do {
                    if let decAesKeyDict = try XMLReader.dictionary(forXMLString: decAesKey), let aesKey = decAesKeyDict["key"] as? String {
                        let aesKeyDict = DPAGAesKeyDecrypted(aesKey: aesKey, iv: iv)
                        if let decJsonString = self.decryptMessageDict(dataString, decAesKeyDictionary: aesKeyDict) {
                            decryptedMessageDict = self.decryptedMessageDict(decJsonString)
                        }
                    }
                } catch let error as NSError {
                    DPAGLog("decryptGroupMessageDict error: %@", error)
                }
            }
        }
        return decryptedMessageDict
    }

    func decryptGroupMessageToSendDict(_ message: SIMSMessageToSend, decAesKey: String) -> DPAGMessageDictionary? {
        var decryptedMessageDict: DPAGMessageDictionary?
        DPAGLog("decryptGroupMessageToSend")
        guard let messageData = message.data else {
            return decryptedMessageDict
        }
        if let encMessageData = Data(base64Encoded: messageData) {
            if encMessageData.count >= 16 {
                let iv = encMessageData.subdata(in: 0 ..< 16).base64EncodedString()
                let dataString = encMessageData.subdata(in: 16 ..< encMessageData.count).base64EncodedString()
                do {
                    if let decAesKeyDict = try XMLReader.dictionary(forXMLString: decAesKey), let aesKey = decAesKeyDict["key"] as? String {
                        let aesKeyDict = DPAGAesKeyDecrypted(aesKey: aesKey, iv: iv)
                        if let decJsonString = self.decryptMessageDict(dataString, decAesKeyDictionary: aesKeyDict) {
                            decryptedMessageDict = self.decryptedMessageDict(decJsonString)
                        }
                    }
                } catch let error as NSError {
                    DPAGLog("decryptGroupMessageDict error: %@", error)
                }
            }
        }
        return decryptedMessageDict
    }

    func decryptOwnMessageDict(_ message: SIMSPrivateMessage) -> DPAGMessageDictionary? {
        DPAGLog("decryptOwnMessage")
        return self.decryptMessageDict(message.data, encAesKey: message.fromKey, encAesKey2: message.fromKey2, aesKeyIV: message.aesKey2IV)
    }

    func decryptOwnMessageToSendDict(_ message: SIMSMessageToSendPrivate) -> DPAGMessageDictionary? {
        DPAGLog("decryptOwnMessage")
        return self.decryptMessageDict(message.data, encAesKey: message.fromKey, encAesKey2: message.fromKey2, aesKeyIV: message.aesKey2IV)
    }

    func decryptContactMessageDict(_ message: SIMSPrivateMessage) -> DPAGMessageDictionary? {
        DPAGLog("decryptContactMessage")
        return self.decryptMessageDict(message.data, encAesKey: message.toKey, encAesKey2: message.toKey2, aesKeyIV: message.aesKey2IV)
    }

    func decryptPrivateInternalMessage(data: String, encAesKey: String) -> DPAGMessageDictionary? {
        DPAGLog("decryptInternalMessage")
        return self.decryptMessageDict(data, encAesKey: encAesKey, encAesKey2: nil, aesKeyIV: nil)
    }

    func decryptMessageDict(_ message: SIMSPrivateMessage) -> DPAGMessageDictionary? {
        DPAGLog("decryptMessage")

        if message.isOwnMessage {
            return self.decryptOwnMessageDict(message)
        }
        return self.decryptContactMessageDict(message)
    }

    private func decryptedMessageDict(_ decMessage: String) -> DPAGMessageDictionary? {
        guard let data = decMessage.data(using: .utf8) else {
            return nil
        }

        do {
            if let messageDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                return DPAGMessageDictionary(dict: messageDict)
            }
        } catch let error as NSError {
            DPAGLog(error, message: "error decrypting data")
        }
        return nil
    }

    func decryptString(_ encString: String?, withKey keyIn: SIMSKey?) -> String? {
        guard let key = keyIn, let encryptedString = encString else {
            return nil
        }

        var decryptedString: String?

        do {
            decryptedString = try CryptoHelper.sharedInstance?.decryptToString(encryptedString: encryptedString, with: key)
        } catch {
            DPAGLog(error)
        }

        return decryptedString
    }
}

public protocol DPAGMessageWorkerProtocol: AnyObject {
    func migrateIllegalMessageSendingStates()

    func formatLastMessageDate(_ date: Date?) -> String?
    func markMessageAsReadAttachment(messageGuid: String, chatGuid: String, messageType: DPAGMessageType)

    func deleteTimedMessage(_ messageGuid: String, streamGuid: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock)
    func exportStreamToURLWithStreamGuid(_ streamGuid: String) -> URL?

    func isDestructiveMessageValid(messageGuid: String, sendOptions: DPAGSendMessageItemOptions?) -> Bool

    func createCachedMessages(forStream streamGuid: String)

    func deleteChatStreamMessage(messageGuid: String, streamGuid: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock)

    func prepareMessageToResend(messageGuid: String) -> DPAGDecryptedMessage?

    func startSelfDestructionCountDown(messageGuid: String, sendOptions: DPAGSendMessageOptions?)
    func deleteSelfDestructedMessage(messageGuid: String)

    func markStreamMessagesAsRead(streamGuid: String)
}

class DPAGMessageWorker: NSObject, DPAGMessageWorkerProtocol {
    let messagesDAO: MessagesDAOProtocol = MessagesDAO()
    private static var dateFormatter: DateFormatter = {
        let df = DateFormatter()

        df.doesRelativeDateFormatting = true
        df.dateStyle = .short
        df.timeStyle = .none

        return df
    }()

    private static var timeFormatter: DateFormatter {
        let df = DateFormatter()

        df.doesRelativeDateFormatting = true
        df.dateStyle = .none
        df.timeStyle = .short

        return df
    }

    func markStreamMessagesAsRead(streamGuid: String) {
        DispatchQueue(label: "StreamMessageQueue").sync {
            guard let ownAccountGuid = DPAGApplicationFacade.cache.account?.guid else { return }
            let dateNow = Date()
            let messageStreamInfos = messagesDAO.loadMessageStreamInfos(streamGuid: streamGuid, ownAccountGuid: ownAccountGuid)
            if messageStreamInfos.foundUnreadMessage {
                let updatedMessagesGuids = messagesDAO.saveMessageAttributes(streamGuid: streamGuid, ownAccountGuid: ownAccountGuid, dateNow: dateNow)
                updatedMessagesGuids.forEach {
                    NotificationCenter.default.post(name: DPAGStrings.Notification.Message.METADATA_UPDATED, object: nil, userInfo: [DPAGStrings.Notification.Message.METADATA_UPDATED__USERINFO_KEY__MESSAGE_GUID: $0])
                }
            }
            let unreadServerMessageGuids = messagesDAO.fetchUnreadMessageServerGuids(streamGuid: streamGuid, chatGuid: messageStreamInfos.chatGuid)
            guard unreadServerMessageGuids.count > 0 else { return }

            let unreadMessagesServerToConfirm = messagesDAO.fetchUnreadMessageServerToConfirm(unreadServerMessageGuids: unreadServerMessageGuids, dateNow: dateNow)
            guard unreadMessagesServerToConfirm.count > 0 else { return }
            DPAGApplicationFacade.server.confirmDownload(guids: unreadMessagesServerToConfirm) { _, _, errorMessage in
                guard errorMessage == nil else { return }
                DPAGApplicationFacade.server.confirmRead(guids: unreadMessagesServerToConfirm, chatGuid: messageStreamInfos.chatGuid) { [weak self] _, _, errorMessage in
                    guard errorMessage == nil else { return }
                    self?.messagesDAO.readMessages(guids: unreadMessagesServerToConfirm, date: dateNow)
                }
            }
        }
    }

    func deleteSelfDestructedMessage(messageGuid: String) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            if let message = SIMSMessage.findFirst(byGuid: messageGuid, in: localContext) {
                DPAGApplicationFacade.persistance.deleteMessage(message, in: localContext)

                if DPAGApplicationFacade.preferences.supportMultiDevice {
                    if let messageGuid = message.guid {
                        self.performBlockInBackground {
                            DPAGApplicationFacade.server.confirmDeleted(guids: [messageGuid], withResponse: nil)
                        }
                    }
                }
            }
        }
    }

    func startSelfDestructionCountDown(messageGuid: String, sendOptions: DPAGSendMessageOptions?) {
        if let sendOptions = sendOptions {
            DPAGApplicationFacade.persistance.saveWithBlock { localContext in

                if let sdm = SIMSSelfDestructMessage.mr_createEntity(in: localContext) {
                    sendOptions.dateSelfDestruction = sendOptions.destructionDateForCountdown(messageGuid: messageGuid)
                    sendOptions.countDownSelfDestruction = nil

                    sdm.dateDestruction = sendOptions.dateSelfDestruction
                    sdm.messageGuid = messageGuid
                }
            }
        }
    }

    func prepareMessageToResend(messageGuid: String) -> DPAGDecryptedMessage? {
        var decMessage: DPAGDecryptedMessage?

        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            if let messageToResend = SIMSMessage.findFirst(byGuid: messageGuid, in: localContext) {
                messageToResend.sendingState = NSNumber(value: DPAGMessageState.sending.rawValue)

                decMessage = DPAGApplicationFacade.cache.decryptedMessage(messageToResend, in: localContext)

                decMessage?.isSent = false
                decMessage?.sendingState = .sending
            } else if let messageToResend = SIMSMessageToSend.findFirst(byGuid: messageGuid, in: localContext) {
                messageToResend.sendingState = NSNumber(value: DPAGMessageState.sending.rawValue)

                decMessage = DPAGApplicationFacade.cache.decryptedMessage(messageToResend, in: localContext)

                decMessage?.isSent = false
                decMessage?.sendingState = .sending
            }
        }

        return decMessage
    }

    func deleteChatStreamMessage(messageGuid: String, streamGuid: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            if let message = SIMSMessage.findFirst(byGuid: messageGuid, in: localContext) {
                DPAGApplicationFacade.persistance.deleteMessage(message, in: localContext)
                DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: streamGuid, stream: nil, in: localContext)

                if DPAGApplicationFacade.preferences.supportMultiDevice {
                    self.performBlockInBackground {
                        DPAGApplicationFacade.server.confirmDeleted(guids: [messageGuid], withResponse: nil)
                    }
                }

                responseBlock(nil, nil, nil)
            } else if SIMSMessageToSend.findFirst(byGuid: messageGuid, in: localContext) != nil {
                DPAGApplicationFacade.messageWorker.deleteTimedMessage(messageGuid, streamGuid: streamGuid, withResponse: responseBlock)
            }
        }
    }

    func createCachedMessages(forStream streamGuid: String) {
        tryC {
            DPAGApplicationFacade.persistance.loadWithBlock { localContext in

                if let messages = SIMSMessageStream.findFirst(byGuid: streamGuid, in: localContext)?.messages {
                    var cc = 0
                    // Restliche Nachrichten prefetchen
                    for msg in messages.reverseObjectEnumerator() {
                        if let message = msg as? SIMSMessage, let messageGuid = message.guid, DPAGApplicationFacade.cache.decryptedMessageFast(messageGuid: messageGuid) == nil {
                            /* DPAGDecryptedMessage *decMessage = */ DPAGApplicationFacade.cache.decryptedMessage(message, in: localContext)
                            cc += 1
                            if cc > 50 {
                                break
                            }
                        }
                    }
                }
            }
        }
        .catch { _ in
        }
    }

    func formatLastMessageDate(_ date: Date?) -> String? {
        guard let messageDate = date else {
            return nil
        }

        let sinceNow = messageDate.timeIntervalSinceNow

        if sinceNow > -86_400 {
            let dcNow = (Calendar.current as NSCalendar).components(.day, from: Date())
            let dcDate = (Calendar.current as NSCalendar).components(.day, from: messageDate)

            if dcNow.day == dcDate.day {
                return DPAGMessageWorker.timeFormatter.string(from: messageDate)
            }
        }

        return DPAGMessageWorker.dateFormatter.string(from: messageDate)
    }

    func isDestructiveMessageValid(messageGuid: String, sendOptions: DPAGSendMessageItemOptions?) -> Bool {
        if let destructionConfiguration = sendOptions {
            if destructionConfiguration.countDownSelfDestruction != nil, destructionConfiguration.dateSelfDestruction?.isInPast ?? false {
                DPAGApplicationFacade.persistance.deleteMessageForStream(messageGuid)
                return false
            }
        }

        var isValid = true
        DPAGApplicationFacade.persistance.loadWithBlock { localContext in

            if let sdm = SIMSSelfDestructMessage.mr_findFirst(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSSelfDestructMessage.messageGuid), rightExpression: NSExpression(forConstantValue: messageGuid)), in: localContext), let dateDestruction = sdm.dateDestruction {
                if dateDestruction.isInPast {
                    DPAGApplicationFacade.persistance.deleteMessageForStream(messageGuid)
                    isValid = false
                }
            }
        }

        return isValid
    }

    // - Beim Appstart alle Nachrichten mit sendingState DPAGMessageStateSending auf DPAGMessageStateSentFailed setzen.
    func migrateIllegalMessageSendingStates() {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            let privateMessages = SIMSPrivateMessage.mr_findAll(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSPrivateMessage.sendingState), rightExpression: NSExpression(forConstantValue: DPAGMessageState.sending.rawValue)), in: localContext)
            let groupMessages = SIMSGroupMessage.mr_findAll(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSGroupMessage.sendingState), rightExpression: NSExpression(forConstantValue: DPAGMessageState.sending.rawValue)), in: localContext)
            let privateInternalMessages = SIMSPrivateInternalMessage.mr_findAll(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSPrivateInternalMessage.fromAccountGuid), rightExpression: NSExpression(forConstantValue: "")), in: localContext)
            let messagesToSend = SIMSMessageToSend.mr_findAll(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageToSend.sendingState), rightExpression: NSExpression(forConstantValue: DPAGMessageState.sending.rawValue)), in: localContext)

            let predEmptyStream =
                NSCompoundPredicate(andPredicateWithSubpredicates:
                    [
                        NSPredicate(format: "(options & %d) == %d", DPAGStreamOption.hasUnreadMessages.rawValue, DPAGStreamOption.hasUnreadMessages.rawValue),
                        NSPredicate(format: "messages.@count == 0")
                    ])

            let streamsEmpty = SIMSMessageStream.mr_findAll(with: predEmptyStream, in: localContext)

            privateMessages?.forEach({ messageObj in
                if let message = messageObj as? SIMSMessage {
                    message.sendingState = NSNumber(value: DPAGMessageState.sentFailed.rawValue)
                }
            })

            groupMessages?.forEach { messageObj in
                if let message = messageObj as? SIMSMessage {
                    message.sendingState = NSNumber(value: DPAGMessageState.sentFailed.rawValue)
                }
            }

            privateInternalMessages?.forEach { messageObj in
                if let message = messageObj as? SIMSPrivateInternalMessage {
                    message.fromAccountGuid = nil
                }
            }

            messagesToSend?.forEach { messageObj in
                if let message = messageObj as? SIMSMessageToSend {
                    message.sendingState = NSNumber(value: DPAGMessageState.sentFailed.rawValue)
                }
            }

            streamsEmpty?.forEach { streamObj in
                if let stream = streamObj as? SIMSMessageStream {
                    stream.optionsStream = stream.optionsStream.subtracting(.hasUnreadMessages)
                }
            }

            if let defectOPrivateStream = SIMSStream.mr_findAll(with: NSCompoundPredicate(andPredicateWithSubpredicates: [NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSStream.contact?.guid), rightExpression: NSExpression(forConstantValue: nil)), NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSStream.contactIndexEntry?.guid), rightExpression: NSExpression(forConstantValue: nil))]), in: localContext) {
                defectOPrivateStream.forEach { stream in
                    stream.mr_deleteEntity(in: localContext)
                }
            }
        }
    }

    public func deleteTimedMessage(_ messageGuid: String, streamGuid: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.deleteTimedMessage(messageGuid: messageGuid) { responseObject, errorCode, errorMessage in

            if let errorMessage = errorMessage {
                responseBlock(responseObject, errorCode, errorMessage)
            } else {
                DPAGApplicationFacade.persistance.saveWithBlock { localContext in

                    if let message = SIMSMessageToSend.findFirst(byGuid: messageGuid, in: localContext) {
                        DPAGApplicationFacade.persistance.deleteMessage(message, in: localContext)
                        DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: streamGuid, stream: nil, in: localContext)
                    }
                }

                responseBlock(responseObject, errorCode, errorMessage)
            }
        }
    }

    func markMessageAsReadAttachment(messageGuid: String, chatGuid: String, messageType _: DPAGMessageType) {
        DPAGApplicationFacade.server.confirmRead(guids: [messageGuid], chatGuid: chatGuid) { _, _, _ in
            // TODO: error check
            DPAGApplicationFacade.persistance.saveWithBlock { localContext in

                if let unreadMessage = SIMSMessage.findFirst(byGuid: messageGuid, in: localContext) {
                    if unreadMessage.attributes == nil {
                        unreadMessage.attributes = SIMSMessageAttributes.mr_createEntity(in: localContext)
                    }
                    unreadMessage.attributes?.dateReadServer = Date()

                    DPAGApplicationFacade.cache.decryptedMessage(unreadMessage, in: localContext)?.isReadServerAttachment = true
                }
            }
        }
    }

    func exportStreamToURLWithStreamGuid(_ streamGuid: String) -> URL? {
        var retVal: URL?

        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            guard let stream = SIMSMessageStream.findFirst(byGuid: streamGuid, in: localContext) else {
                return
            }

            var fileURLTemp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

            var streamName = "???"

            if let contactDB = (stream as? SIMSStream)?.contactIndexEntry, let contactGuid = contactDB.guid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
                streamName = contact.displayName
            } else if let streamGroup = stream as? SIMSGroupStream, let group = streamGroup.group, let groupName = group.groupName {
                streamName = groupName
            } else if let streamChannel = stream as? SIMSChannelStream, let channel = streamChannel.channel, let channelName = channel.name_short {
                streamName = channelName
            }
            let fileName = DPAGMandant.default.name + "_" + streamName.replacingOccurrences(of: " ", with: "_")
            fileURLTemp = fileURLTemp.appendingPathComponent(fileName).appendingPathExtension("txt")
            retVal = fileURLTemp
            let fileURLPath = fileURLTemp.path
            if FileManager.default.fileExists(atPath: fileURLPath) {
                do {
                    try FileManager.default.removeItem(atPath: fileURLPath)
                } catch {
                    DPAGLog(error)
                }
            }
            let ownAccountGuid = DPAGApplicationFacade.cache.account?.guid
            let contact = DPAGApplicationFacade.cache.contact(for: ownAccountGuid ?? "???")
            let ownAccountNick = contact?.nickName ?? "<--"
            var contacts: [String: DPAGContact] = [:]
            // init file
            try? Data().write(to: fileURLTemp, options: [.atomic])
            guard let messages = stream.messages?.array as? [SIMSMessage] else {
                return
            }
            if let fileHandle = try? FileHandle(forWritingTo: fileURLTemp) {
                defer {
                    fileHandle.closeFile()
                }
                fileHandle.seekToEndOfFile()
                for message in messages {
                    var messageText = ""
                    messageText += DPAGFormatter.date.string(from: message.dateSendServer ?? Date())
                    if message.fromAccountGuid == ownAccountGuid {
                        messageText += ": \(ownAccountNick)"
                    } else if let contact = contacts[message.fromAccountGuid ?? "???"] {
                        messageText += ": \(contact.displayName)"
                    } else if let contact = DPAGApplicationFacade.cache.contact(for: message.fromAccountGuid ?? "") {
                        contacts[message.fromAccountGuid ?? "???"] = contact
                        messageText += ": \(contact.displayName)"
                    } else {
                        messageText += ": ???"
                    }
                    if let decMessage = DPAGApplicationFacade.cache.decryptedMessage(message, in: localContext) {
                        messageText += ": "
                        if decMessage.isSelfDestructive {
                            messageText += DPAGLocalizedString("chat.export.messageType.selfDestruct")
                        } else if decMessage.errorType != DPAGMessageSecurityError.none, decMessage.errorType != DPAGMessageSecurityError.notChecked {
                            messageText += DPAGLocalizedString("chat.export.messageType.error")
                        } else if let decMessageContent = decMessage.content {
                            switch decMessage.contentType {
                            case .controlMsgNG:
                                messageText += ""
                            case .voiceRec:
                                messageText += DPAGLocalizedString("chat.export.messageType.voiceRec")
                            case .avCallInvitation:
                                messageText += DPAGLocalizedString("chat.export.messageType.avCall")
                            case .plain, .oooStatusMessage, .textRSS:
                                if decMessage.isSystemGenerated {
                                    messageText += DPAGApplicationFacade.cache.parseSystemMessageContent(decMessageContent, in: localContext)
                                } else {
                                    messageText += decMessageContent
                                }
                            case .image:
                                messageText += DPAGLocalizedString("chat.export.messageType.image")
                            case .video:
                                messageText += DPAGLocalizedString("chat.export.messageType.video")
                            case .location:
                                messageText += DPAGLocalizedString("chat.export.messageType.location")
                            case .contact:
                                messageText += DPAGLocalizedString("chat.export.messageType.contact")
                            case .file:
                                messageText += DPAGLocalizedString("chat.export.messageType.file")
                            }
                        }
                        messageText += "\n"
                    }
                    if let data = messageText.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                }
                // compress_path(fileURLTemp!.path!, fileURLZipTemp!.path!, 9)
            }
        }
        return retVal
    }
}
