//
//  SendMessageDAO.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 15.08.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

protocol SendMessageDAOProtocol {
    func updateResendMessage(msgGuid: String, withMsgInstance msgInstance: DPAGSendMessageWorkerInstance, forInitialSending: Bool) throws

    func createOutgoingPrivateMessage(msgInstance: DPAGSendMessageWorkerInstance, sendMessageInfo: DPAGSendMessageInfo?) throws
    func createOutgoingGroupMessage(msgInstance: DPAGSendMessageWorkerInstance, sendMessageInfo: DPAGSendMessageInfo?) throws

    func sendingMessageFailed(msgInstance: DPAGSendMessageWorkerInstance)
    func sendingMessageSucceeded(msgInstance: DPAGSendMessageWorkerInstance, messageConfirmSend: DPAGMessageReceivedInternal.ConfirmMessageSend.ConfirmMessageSendItem) -> Date?

    func recipientExists(recipientGuid: String) -> Bool
    func groupExists(groupGuid: String) -> Bool
}

class SendMessageDAO: SendMessageDAOProtocol {
    func recipientExists(recipientGuid: String) -> Bool {
        var recipientFound: Bool = false
        DPAGApplicationFacade.persistance.loadWithBlock { localContext in

            recipientFound = SIMSContactIndexEntry.findFirst(byGuid: recipientGuid, in: localContext) != nil
        }
        return recipientFound
    }

    func groupExists(groupGuid: String) -> Bool {
        var recipientFound: Bool = false
        DPAGApplicationFacade.persistance.loadWithBlock { localContext in

            // faster than searching on SIMSGroupStream, because index is on guid of SIMSMessageStream
            recipientFound = (SIMSMessageStream.findFirst(byGuid: groupGuid, in: localContext) as? SIMSGroupStream) != nil
        }
        return recipientFound
    }

    func updateResendMessage(msgGuid: String, withMsgInstance msgInstance: DPAGSendMessageWorkerInstance, forInitialSending: Bool) throws {
        try DPAGApplicationFacade.persistance.saveWithError { localContext in

            try self.updateResendMessage(msgGuid, withMsgInstance: msgInstance, forInitialSending: forInitialSending, context: localContext)
        }
    }

    func sendingMessageSucceeded(msgInstance: DPAGSendMessageWorkerInstance, messageConfirmSend: DPAGMessageReceivedInternal.ConfirmMessageSend.ConfirmMessageSendItem) -> Date? {
        var lastMessageDate: Date?
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            guard let messageGuidBefore = msgInstance.guidOutgoingMessage, let lastMessageDateDict = DPAGFormatter.date.date(from: messageConfirmSend.dateSent) else {
                // The message was probably deleted and this worker was not properly stopped!
                return
            }
            let guidOutgoingMessageNew = messageConfirmSend.guid
            lastMessageDate = lastMessageDateDict
            if let message = self.loadOutgoingMessageWithInstance(msgInstance, in: localContext) {
                message.guid = guidOutgoingMessageNew
                message.sendingState = NSNumber(value: DPAGMessageState.sentSucceeded.rawValue)
                message.dateSendServer = lastMessageDateDict
                message.stream?.lastMessageDate = lastMessageDateDict
                if let attachmentGuid = message.attachment, let attachmentGuidNew = messageConfirmSend.attachmentGuids?.first {
                    DPAGAttachmentWorker.moveEncryptedAttachment(guidOld: attachmentGuid, guidNew: attachmentGuidNew)
                    message.attachment = attachmentGuidNew
                }
                if let recipients = messageConfirmSend.recipients, recipients.isEmpty == false {
                    for receiver in recipients {
                        if receiver.contactGuid != message.fromAccountGuid, let contact = SIMSContactIndexEntry.findFirst(byGuid: receiver.contactGuid, in: localContext) {
                            if let receiverEntity = SIMSMessageReceiver.mr_createEntity(in: localContext) {
                                receiverEntity.contactIndexEntry = contact
                                receiverEntity.sendsReadConfirmation = NSNumber(value: receiver.sendsReadConfirmation == "1")
                                receiverEntity.message = message
                                message.receiver?.insert(receiverEntity)
                            }
                        }
                    }
                    if let decMessage = DPAGApplicationFacade.cache.decryptedMessage(message, in: localContext) {
                        decMessage.update(withRecipients: message.receiver ?? Set())
                    }
                }
                if let streamGuid = message.stream?.guid {
                    DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: streamGuid, stream: message.stream, in: localContext)
                }
                let decMessage = DPAGApplicationFacade.cache.decryptedMessage(message, in: localContext)
                decMessage?.sendingState = .sentSucceeded
            } else if let message = self.loadOutgoingMessageToSendWithInstance(msgInstance, in: localContext) {
                message.guid = guidOutgoingMessageNew
                message.sendingState = NSNumber(value: DPAGMessageState.sentSucceeded.rawValue)
                if let attachmentGuid = message.attachment, let attachmentGuidNew = messageConfirmSend.attachmentGuids?.first {
                    DPAGAttachmentWorker.moveEncryptedAttachment(guidOld: attachmentGuid, guidNew: attachmentGuidNew)
                    message.attachment = attachmentGuidNew
                }
                if let stream = SIMSMessageStream.findFirst(byGuid: message.streamGuid, in: localContext) {
                    stream.lastMessageDate = message.dateCreated
                    DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: message.streamGuid, stream: stream, in: localContext)
                }
                // message.dateSendServer = lastMessageDateDict
                let decMessage = DPAGApplicationFacade.cache.decryptedMessage(message, in: localContext)
                decMessage?.sendingState = .sentSucceeded
            }
            DPAGApplicationFacade.cache.removeMessage(guid: messageGuidBefore)
        }
        return lastMessageDate
    }

    func sendingMessageFailed(msgInstance: DPAGSendMessageWorkerInstance) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            if let message = self.loadOutgoingMessageWithInstance(msgInstance, in: localContext) {
                message.sendingState = NSNumber(value: DPAGMessageState.sentFailed.rawValue)
                DPAGApplicationFacade.cache.removeMessage(guid: message.guid)
                DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: message.stream?.guid, stream: message.stream, in: localContext)
            } else if let message = self.loadOutgoingMessageToSendWithInstance(msgInstance, in: localContext) {
                message.sendingState = NSNumber(value: DPAGMessageState.sentFailed.rawValue)
                DPAGApplicationFacade.cache.removeMessage(guid: message.guid)
                DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: message.streamGuid, stream: nil, in: localContext)
            }
        }
    }

    private func updateResendMessage(_ messageToResend: String, withMsgInstance msgInstance: DPAGSendMessageWorkerInstance, forInitialSending: Bool, context localContext: NSManagedObjectContext) throws {
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let accountPublicKey = contact.publicKey else {
            return
        }
        if let message = SIMSMessageToSend.findFirst(byGuid: messageToResend, in: localContext), let decryptedMessage = DPAGApplicationFacade.cache.decryptedMessage(message, in: localContext) {
            // reorder message
            if decryptedMessage.contentType == .voiceRec {
                msgInstance.featureSet = "\(DPAGMessageFeatureVersion.voiceRec.rawValue)"
            } else if decryptedMessage.contentType == .file {
                msgInstance.featureSet = "\(DPAGMessageFeatureVersion.file.rawValue)"
            }
            msgInstance.guidOutgoingMessage = message.guid
            msgInstance.guidStream = message.streamGuid
            msgInstance.messageType = decryptedMessage.messageType
            if let sendOptions = decryptedMessage.sendOptions {
                msgInstance.sendMessageOptions = DPAGSendMessageSendOptions(countDownSelfDestruction: sendOptions.countDownSelfDestruction, dateSelfDestruction: sendOptions.dateSelfDestruction, dateToBeSend: sendOptions.dateToBeSend, messagePriorityHigh: message.optionsMessage.contains(.priorityHigh))
            }
            msgInstance.messageText = decryptedMessage.content ?? ""
            msgInstance.contentType = decryptedMessage.contentType.stringRepresentation
            // msgInstance.attachment = nil
            var messageDict: [AnyHashable: Any]?
            var signatures: DPAGMessageSignatures?
            var attachmentSize: Int = 0
            if let messagePrivate = message as? SIMSMessageToSendPrivate, let messageData = messagePrivate.data, let toAccountGuid = messagePrivate.toAccountGuid, let recipient = SIMSContactIndexEntry.findFirst(byGuid: toAccountGuid, in: localContext), let fromKey = messagePrivate.fromKey {
                try autoreleasepool {
                    var encodedAttachment: String? = DPAGAttachmentWorker.encryptedAttachment(guid: message.attachment)
                    msgInstance.receiver = DPAGSendMessageRecipient(recipientGuid: toAccountGuid)
                    guard let accountCrypto = DPAGCryptoHelper.newAccountCrypto() else {
                        throw DPAGErrorSendMessage.err463
                    }
                    guard let decAesKey = try accountCrypto.decryptAesKey(encryptedAeskey: fromKey) else {
                        throw DPAGErrorSendMessage.err463
                    }
                    let decAesKeyDict: [AnyHashable: Any]?
                    do { decAesKeyDict = try XMLReader.dictionary(forXMLString: decAesKey) } catch { return }
                    guard let iv = decAesKeyDict?["iv"] as? String else {
                        throw DPAGErrorSendMessage.err463
                    }
                    guard let cachedAesKeys = try recipient.aesKey(accountPublicKey: accountPublicKey, createNew: true), let recipientPublicKey = msgInstance.receiver.contact?.publicKey, let config = try DPAGEncryptionConfigurationPrivate(forRecipient: msgInstance.receiver, cachedAesKeys: cachedAesKeys, recipientPublicKey: recipientPublicKey, withIV: iv) else {
                        throw DPAGErrorSendMessage.err463
                    }
                    guard let signaturesMsg = try DPAGEncryptionConfiguration.signatures(accountCrypto: accountCrypto, config: config, messageDataEncrypted: messageData, attachmentEncrypted: encodedAttachment) else {
                        throw DPAGErrorSendMessage.err463
                    }
                    signatures = signaturesMsg
                    attachmentSize = encodedAttachment?.count ?? 0
                    messageDict = config.messageDictionary(info: DPAGEncryptionConfigurationPrivate.MessageDictionaryInfoPrivate(encMessageData: messageData, encAttachment: encodedAttachment, signatures: signaturesMsg, messageType: DPAGStrings.JSON.MessagePrivate.OBJECT_KEY, contentType: msgInstance.contentType, sendOptions: msgInstance.sendMessageOptions, featureSet: msgInstance.featureSet, nickname: contact.nickName ?? "", senderId: msgInstance.guidOutgoingMessage))
                    encodedAttachment = nil
                }
            } else if let messageGroup = message as? SIMSMessageToSendGroup, let recipient = messageGroup.streamToSend(in: localContext), let messageData = messageGroup.data, let groupGuid = recipient.guid {
                try autoreleasepool {
                    var encodedAttachment: String? = DPAGAttachmentWorker.encryptedAttachment(guid: message.attachment)
                    msgInstance.receiver = DPAGSendMessageRecipient(recipientGuid: groupGuid)
                    guard let decAesKey = recipient.groupAesKey, let config = try DPAGEncryptionConfigurationGroup(aesKeyXML: decAesKey, forGroup: groupGuid) else {
                        throw DPAGErrorSendMessage.err463
                    }
                    guard let accountCrypto = DPAGCryptoHelper.newAccountCrypto(), let signaturesMsg = try DPAGEncryptionConfiguration.signatures(accountCrypto: accountCrypto, config: config, messageDataEncrypted: messageData, attachmentEncrypted: encodedAttachment) else {
                        throw DPAGErrorSendMessage.err463
                    }
                    signatures = signaturesMsg
                    attachmentSize = encodedAttachment?.count ?? 0
                    messageDict = config.messageDictionary(info: DPAGEncryptionConfigurationGroup.MessageDictionaryInfoGroup(encMessageData: messageData, encAttachment: encodedAttachment, signatures: signaturesMsg, messageType: DPAGStrings.JSON.MessageGroup.OBJECT_KEY, contentType: msgInstance.contentType, sendOptions: msgInstance.sendMessageOptions, featureSet: msgInstance.featureSet, nickname: contact.nickName ?? "", senderId: msgInstance.guidOutgoingMessage))
                    encodedAttachment = nil
                }
            } else {
                return
            }
            var messageJson: String?
            try autoreleasepool {
                if let messageDict = messageDict {
                    NSLog("SendMessageDAO -> attachmentSize = \(attachmentSize)")
                    if DPAGHelper.canPerformRAMBasedJSON(ofSize: UInt(attachmentSize)) {
                        // use RAM-based conversion
                        messageJson = messageDict.JSONString
                    } else {
                        // use Disk-based conversion
                        messageJson = try GNJSONSerialization.string(withJSONObject: messageDict)
                    }
                } else {
                    messageDict = nil
                    throw DPAGErrorSendMessage.err463
                }
                messageDict = nil
            }
            // Signature sichern
            guard let rawSignature = signatures?.signatureDict.JSONString else {
                throw DPAGErrorSendMessage.err463
                // return nil
            }
            message.rawSignature = rawSignature
            guard let rawSignature256 = signatures?.signatureDict256.JSONString else {
                throw DPAGErrorSendMessage.err463
                // return nil
            }
            message.rawSignature256 = rawSignature256
            msgInstance.messageJson = messageJson
        }
        if let message = SIMSMessage.findFirst(byGuid: messageToResend, in: localContext), let stream = message.stream, let decryptedMessage = DPAGApplicationFacade.cache.decryptedMessage(message, in: localContext) {
            // reorder message
            if !forInitialSending {
                message.stream = nil
                if let lastMessage = stream.messages?.lastObject as? SIMSMessage {
                    message.messageOrderId = NSNumber(value: (lastMessage.messageOrderId?.int64Value ?? 0) + 1)
                } else {
                    message.messageOrderId = NSNumber(value: 1)
                }
                message.stream = stream
                let dateNow = Date()
                message.dateSendLocal = dateNow
                message.dateSendServer = dateNow
            }
            if decryptedMessage.contentType == .voiceRec {
                msgInstance.featureSet = "\(DPAGMessageFeatureVersion.voiceRec.rawValue)"
            } else if decryptedMessage.contentType == .file {
                msgInstance.featureSet = "\(DPAGMessageFeatureVersion.file.rawValue)"
            }
            msgInstance.guidOutgoingMessage = message.guid
            msgInstance.guidStream = message.stream?.guid
            msgInstance.messageType = decryptedMessage.messageType
            if let sendOptions = decryptedMessage.sendOptions {
                msgInstance.sendMessageOptions = DPAGSendMessageSendOptions(countDownSelfDestruction: sendOptions.countDownSelfDestruction, dateSelfDestruction: sendOptions.dateSelfDestruction, dateToBeSend: sendOptions.dateToBeSend, messagePriorityHigh: message.optionsMessage.contains(.priorityHigh))
            }
            msgInstance.messageText = decryptedMessage.content ?? ""
            msgInstance.contentType = decryptedMessage.contentType.stringRepresentation
            // msgInstance.attachment = nil
            var messageDict: [AnyHashable: Any]?
            var signatures: DPAGMessageSignatures?
            var attachmentSize: Int = 0
            if let messagePrivate = message as? SIMSPrivateMessage, let recipient = SIMSContactIndexEntry.findFirst(byGuid: messagePrivate.toAccountGuid, in: localContext), let messageData = messagePrivate.data, let receiverGuid = recipient.guid, let fromKey = messagePrivate.fromKey {
                try autoreleasepool {
                    var encodedAttachment: String? = DPAGAttachmentWorker.encryptedAttachment(guid: message.attachment)
                    msgInstance.receiver = DPAGSendMessageRecipient(recipientGuid: receiverGuid)
                    guard let accountCrypto = DPAGCryptoHelper.newAccountCrypto() else {
                        throw DPAGErrorSendMessage.err463
                    }
                    guard let decAesKey = try accountCrypto.decryptAesKey(encryptedAeskey: fromKey) else {
                        throw DPAGErrorSendMessage.err463
                    }
                    let decAesKeyDict: [AnyHashable: Any]?
                    do { decAesKeyDict = try XMLReader.dictionary(forXMLString: decAesKey) } catch { return }
                    guard let iv = decAesKeyDict?["iv"] as? String else {
                        throw DPAGErrorSendMessage.err463
                    }
                    guard let cachedAesKeys = try recipient.aesKey(accountPublicKey: accountPublicKey, createNew: true), let recipientPublicKey = msgInstance.receiver.contact?.publicKey, let config = try DPAGEncryptionConfigurationPrivate(forRecipient: msgInstance.receiver, cachedAesKeys: cachedAesKeys, recipientPublicKey: recipientPublicKey, withIV: iv) else {
                        throw DPAGErrorSendMessage.err463
                    }
                    guard let signaturesMsg = try DPAGEncryptionConfiguration.signatures(accountCrypto: accountCrypto, config: config, messageDataEncrypted: messageData, attachmentEncrypted: encodedAttachment) else {
                        throw DPAGErrorSendMessage.err463
                    }
                    signatures = signaturesMsg
                    attachmentSize = encodedAttachment?.count ?? 0
                    messageDict = config.messageDictionary(info: DPAGEncryptionConfigurationPrivate.MessageDictionaryInfoPrivate(encMessageData: messageData, encAttachment: encodedAttachment, signatures: signaturesMsg, messageType: DPAGStrings.JSON.MessagePrivate.OBJECT_KEY, contentType: msgInstance.contentType, sendOptions: msgInstance.sendMessageOptions, featureSet: msgInstance.featureSet, nickname: contact.nickName ?? "", senderId: msgInstance.guidOutgoingMessage))
                    encodedAttachment = nil
                }
            } else if let messageGroup = message as? SIMSGroupMessage, let recipient = messageGroup.stream as? SIMSGroupStream, let messageData = messageGroup.data, let receiverGuid = recipient.guid {
                try autoreleasepool {
                    var encodedAttachment: String? = DPAGAttachmentWorker.encryptedAttachment(guid: message.attachment)
                    msgInstance.receiver = DPAGSendMessageRecipient(recipientGuid: receiverGuid)
                    guard let decAesKey = recipient.groupAesKey, let config = try DPAGEncryptionConfigurationGroup(aesKeyXML: decAesKey, forGroup: receiverGuid) else {
                        throw DPAGErrorSendMessage.err463
                    }
                    guard let accountCrypto = DPAGCryptoHelper.newAccountCrypto(), let signaturesMsg = try DPAGEncryptionConfiguration.signatures(accountCrypto: accountCrypto, config: config, messageDataEncrypted: messageData, attachmentEncrypted: encodedAttachment) else {
                        throw DPAGErrorSendMessage.err463
                    }
                    signatures = signaturesMsg
                    attachmentSize = encodedAttachment?.count ?? 0
                    messageDict = config.messageDictionary(info: DPAGEncryptionConfigurationGroup.MessageDictionaryInfoGroup(encMessageData: messageData, encAttachment: encodedAttachment, signatures: signaturesMsg, messageType: DPAGStrings.JSON.MessageGroup.OBJECT_KEY, contentType: msgInstance.contentType, sendOptions: msgInstance.sendMessageOptions, featureSet: msgInstance.featureSet, nickname: contact.nickName ?? "", senderId: msgInstance.guidOutgoingMessage))
                    encodedAttachment = nil
                }
            } else {
                return
            }
            
            var messageJson: String?
            try autoreleasepool {
                if let messageDict = messageDict {
                    NSLog("SendMessageDAO -> attachmentSize = \(attachmentSize)")
                    if DPAGHelper.canPerformRAMBasedJSON(ofSize: UInt(attachmentSize)) {
                        // use RAM-based conversion
                        messageJson = messageDict.JSONString
                    } else {
                        // use Disk-based conversion
                        messageJson = try GNJSONSerialization.string(withJSONObject: messageDict)
                    }
                } else {
                    messageDict = nil
                    throw DPAGErrorSendMessage.err463
                }
                messageDict = nil
            }
            // Signature sichern
            guard let rawSignature = signatures?.signatureDict.JSONString else {
                throw DPAGErrorSendMessage.err463
                // return nil
            }
            message.rawSignature = rawSignature
            guard let rawSignature256 = signatures?.signatureDict256.JSONString else {
                throw DPAGErrorSendMessage.err463
                // return nil
            }
            message.rawSignature256 = rawSignature256
            if !forInitialSending {
                message.stream?.lastMessageDate = message.dateSendServer
                message.refreshSectionTitle()
            }
            msgInstance.messageJson = messageJson
        }
    }

    func createOutgoingPrivateMessage(msgInstance: DPAGSendMessageWorkerInstance, sendMessageInfo: DPAGSendMessageInfo?) throws {
        try DPAGApplicationFacade.persistance.saveWithError { localContext in
            let guidRecipient = msgInstance.receiver.recipientGuid
            guard let recipient = SIMSContactIndexEntry.findFirst(byGuid: guidRecipient, in: localContext), let contact = DPAGApplicationFacade.cache.contact(for: guidRecipient) else {
                DPAGLog("Cannot create outgoing private message because recipient is null.")
                return
            }
            let hasEmptyPublicKey = (recipient[.PUBLIC_KEY]?.isEmpty ?? true)
            if hasEmptyPublicKey {
                DPAGApplicationFacade.updateKnownContactsWorker.synchronize(accountGuid: guidRecipient) { [weak self] _, _, errorMessage in
                    if errorMessage != nil {
                        DPAGLog("Cannot create outgoing private message because recipient is null.")
                        return
                    } else {
                        do {
                            try self?.createOutgoingPrivateMessage(msgInstance: msgInstance, sendMessageInfo: sendMessageInfo)
                        } catch {}
                    }
                }
                return
            }
            msgInstance.receiver.contact = contact
            if let dateToSend = msgInstance.sendMessageOptions?.dateToBeSend {
                // Before we save the context, we need a valid Core Data entity (non null not-optional fields)
                guard let privateMessage = SIMSMessageToSendPrivate.mr_createEntity(in: localContext) else {
                    DPAGLog("Error creating outgoing private message.")
                    return
                }
                privateMessage.sendingState = NSNumber(value: DPAGMessageState.sending.rawValue)
                privateMessage.guid = DPAGFunctionsGlobal.uuid(prefix: .temp)
                let dateNow = Date()
                privateMessage.dateCreated = dateNow
                privateMessage.dateToSend = dateToSend
                privateMessage.optionsMessage = (msgInstance.sendMessageOptions?.messagePriorityHigh ?? false) ? [.priorityHigh] : []
                let attachmentCount = sendMessageInfo?.attachment?.count ?? 0
                let messageInfo = DPAGMessageModelFactory.MessageInfo(text: msgInstance.messageText, desc: msgInstance.messageDesc, sendOptions: msgInstance.sendMessageOptions, recipient: msgInstance.receiver, recipientContact: recipient, outgoingMessage: privateMessage, contentType: msgInstance.contentType, attachment: sendMessageInfo?.attachment, featureSet: msgInstance.featureSet, additionalContentData: msgInstance.additionalContentData, localContext: localContext)
                sendMessageInfo?.attachment = nil
                msgInstance.messageJson = try DPAGApplicationFacade.messageFactory.messageToSend(info: messageInfo)
                if msgInstance.messageJson == nil {
                    // The message was not properly configured, we risk trying to save an inconsistent context
                    msgInstance.guidOutgoingMessage = nil
                    privateMessage.mr_deleteEntity(in: localContext)
                    return
                }
                privateMessage.streamToSend(in: localContext)?.lastMessageDate = privateMessage.dateCreated
                msgInstance.sendConcurrent = attachmentCount > 4_000
                msgInstance.messageType = .private
                msgInstance.guidOutgoingMessage = privateMessage.guid
                // MessageType vor dem decrypten (cache !!) setzen
                privateMessage.typeMessage = .private
                DPAGApplicationFacade.cache.decryptedMessage(privateMessage, in: localContext)
            } else {
                // Before we save the context, we need a valid Core Data entity (non null not-optional fields)
                guard let privateMessage = SIMSPrivateMessage.mr_createEntity(in: localContext) else {
                    DPAGLog("Error creating outgoing private message.")
                    return
                }
                privateMessage.sendingState = NSNumber(value: DPAGMessageState.sending.rawValue)
                privateMessage.guid = DPAGFunctionsGlobal.uuid(prefix: .temp)
                let dateNow = Date()
                privateMessage.dateSendLocal = dateNow
                privateMessage.dateSendServer = dateNow
                privateMessage.attributes = SIMSMessageAttributes.mr_createEntity(in: localContext)
                privateMessage.optionsMessage = (msgInstance.sendMessageOptions?.messagePriorityHigh ?? false) ? [.priorityHigh] : []
                let attachmentCount = sendMessageInfo?.attachment?.count ?? 0
                let messageInfo = DPAGMessageModelFactory.MessageInfo(text: msgInstance.messageText, desc: msgInstance.messageDesc, sendOptions: msgInstance.sendMessageOptions, recipient: msgInstance.receiver, recipientContact: recipient, outgoingMessage: privateMessage, contentType: msgInstance.contentType, attachment: sendMessageInfo?.attachment, featureSet: msgInstance.featureSet, additionalContentData: msgInstance.additionalContentData, localContext: localContext)
                sendMessageInfo?.attachment = nil
                msgInstance.messageJson = try DPAGApplicationFacade.messageFactory.message(info: messageInfo)
                if msgInstance.messageJson == nil {
                    // The message was not properly configured, we risk trying to save an inconsistent context
                    msgInstance.guidOutgoingMessage = nil
                    privateMessage.mr_deleteEntity(in: localContext)
                    return
                }
                privateMessage.stream?.lastMessageDate = privateMessage.dateSendServer
                msgInstance.sendConcurrent = attachmentCount > 4_000
                msgInstance.messageType = .private
                msgInstance.guidOutgoingMessage = privateMessage.guid
                // MessageType vor dem decrypten (cache !!) setzen
                privateMessage.typeMessage = .private
                DPAGApplicationFacade.cache.decryptedMessage(privateMessage, in: localContext)
            }
            msgInstance.receiver.contact = nil
        }
    }

    func createOutgoingGroupMessage(msgInstance: DPAGSendMessageWorkerInstance, sendMessageInfo: DPAGSendMessageInfo?) throws {
        try DPAGApplicationFacade.persistance.saveWithError { localContext in
            let guidGroupStream = msgInstance.receiver.recipientGuid
            guard let groupStream = SIMSMessageStream.findFirst(byGuid: guidGroupStream, in: localContext) as? SIMSGroupStream else {
                DPAGLog("Cannot create outgoing group message because group stream is null.")
                return
            }
            if let dateToSend = msgInstance.sendMessageOptions?.dateToBeSend {
                guard let groupMessage = SIMSMessageToSendGroup.mr_createEntity(in: localContext) else {
                    DPAGLog("Error creating outgoing group message.")
                    return
                }
                groupMessage.sendingState = NSNumber(value: DPAGMessageState.sending.rawValue)
                groupMessage.guid = DPAGFunctionsGlobal.uuid(prefix: .temp) // Temp GUID
                let dateNow = Date()
                groupMessage.dateCreated = dateNow
                groupMessage.dateToSend = dateToSend
                groupMessage.optionsMessage = (msgInstance.sendMessageOptions?.messagePriorityHigh ?? false) ? [.priorityHigh] : []
                let attachmentCount = sendMessageInfo?.attachment?.count ?? 0
                let messageInfo = DPAGMessageModelFactory.MessageGroupInfo(text: msgInstance.messageText, desc: msgInstance.messageDesc, sendOptions: msgInstance.sendMessageOptions, stream: groupStream, outgoingMessage: groupMessage, contentType: msgInstance.contentType, attachment: sendMessageInfo?.attachment, featureSet: msgInstance.featureSet, additionalContentData: msgInstance.additionalContentData, localContext: localContext)
                sendMessageInfo?.attachment = nil
                msgInstance.messageJson = try DPAGApplicationFacade.messageFactory.groupMessageToSend(info: messageInfo)
                if msgInstance.messageJson == nil {
                    msgInstance.guidOutgoingMessage = nil
                    groupMessage.mr_deleteEntity(in: localContext)
                    return
                }
                groupMessage.streamToSend(in: localContext)?.lastMessageDate = groupMessage.dateCreated
                msgInstance.sendConcurrent = attachmentCount > 4_000
                msgInstance.messageType = .group
                msgInstance.guidOutgoingMessage = groupMessage.guid
                groupMessage.typeMessage = .group
                DPAGApplicationFacade.cache.decryptedMessage(groupMessage, in: localContext)
            } else {
                guard let groupMessage = SIMSGroupMessage.mr_createEntity(in: localContext) else {
                    DPAGLog("Error creating outgoing group message.")
                    return
                }
                groupMessage.sendingState = NSNumber(value: DPAGMessageState.sending.rawValue)
                groupMessage.guid = DPAGFunctionsGlobal.uuid(prefix: .temp) // Temp GUID
                let dateNow = Date()
                groupMessage.dateSendLocal = dateNow
                groupMessage.dateSendServer = dateNow
                groupMessage.attributes = SIMSMessageAttributes.mr_createEntity(in: localContext)
                groupMessage.optionsMessage = (msgInstance.sendMessageOptions?.messagePriorityHigh ?? false) ? [.priorityHigh] : []
                let attachmentCount = sendMessageInfo?.attachment?.count ?? 0
                let messageInfo = DPAGMessageModelFactory.MessageGroupInfo(text: msgInstance.messageText, desc: msgInstance.messageDesc, sendOptions: msgInstance.sendMessageOptions, stream: groupStream, outgoingMessage: groupMessage, contentType: msgInstance.contentType, attachment: sendMessageInfo?.attachment, featureSet: msgInstance.featureSet, additionalContentData: msgInstance.additionalContentData, localContext: localContext)
                sendMessageInfo?.attachment = nil
                msgInstance.messageJson = try DPAGApplicationFacade.messageFactory.groupMessage(info: messageInfo)
                if msgInstance.messageJson == nil {
                    msgInstance.guidOutgoingMessage = nil
                    groupMessage.mr_deleteEntity(in: localContext)
                    return
                }
                groupMessage.stream?.lastMessageDate = groupMessage.dateSendServer
                msgInstance.sendConcurrent = attachmentCount > 4_000
                msgInstance.messageType = .group
                msgInstance.guidOutgoingMessage = groupMessage.guid
                groupMessage.typeMessage = .group
                DPAGApplicationFacade.cache.decryptedMessage(groupMessage, in: localContext)
            }
        }
    }

    private func loadOutgoingMessageWithInstance(_ msgInstance: DPAGSendMessageWorkerInstance, in localContext: NSManagedObjectContext) -> SIMSMessage? {
        if let guidOutgoingMessage = msgInstance.guidOutgoingMessage {
            return SIMSMessage.findFirst(byGuid: guidOutgoingMessage, in: localContext)
        }
        return nil
    }

    private func loadOutgoingMessageToSendWithInstance(_ msgInstance: DPAGSendMessageWorkerInstance, in localContext: NSManagedObjectContext) -> SIMSMessageToSend? {
        if let guidOutgoingMessage = msgInstance.guidOutgoingMessage {
            return SIMSMessageToSend.findFirst(byGuid: guidOutgoingMessage, in: localContext)
        }
        return nil
    }
}
