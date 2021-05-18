//
// Created by mg on 14.11.13.
// Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

enum DPAGErrorCreateMessage: Error {
    case err465
    case errNoDeviceCrypto
}

protocol DPAGMessageModelFactoryProtocol {
    func invitationForGroup(groupGuid: String, groupName: String, groupAesKey: String, forRecipients recipients: [SIMSContactIndexEntry], isNewGroup: Bool, groupType: String, in localContext: NSManagedObjectContext) throws -> [[AnyHashable: Any]]?

    func messageToSend(info: DPAGMessageModelFactory.MessageInfo) throws -> String?
    func message(info: DPAGMessageModelFactory.MessageInfo) throws -> String?

    func groupMessage(info: DPAGMessageModelFactory.MessageGroupInfo) throws -> String?
    func groupMessageToSend(info: DPAGMessageModelFactory.MessageGroupInfo) throws -> String?

    func createCitationContentForMessage(messageGuidCitation: String, in localContext: NSManagedObjectContext) -> [AnyHashable: Any]?

    @discardableResult
    func newSystemMessage(content: String, forGroup group: SIMSGroupStream, sendDate: Date, guid: String?, in localContext: NSManagedObjectContext) -> SIMSGroupMessage?
    func newSystemMessage(content: String, forGroupGuid groupGuid: String, sendDate: Date, guid: String?)

    @discardableResult
    func newSystemMessage(content: String, forChat chatStream: SIMSStream, sendDate: Date, guid: String?, in localContext: NSManagedObjectContext) -> SIMSPrivateMessage?
    func newSystemMessage(content: String, forChatGuid chatStreamGuid: String, sendDate: Date, guid: String?)

    @discardableResult
    func newOooStatusMessage(content: String, forChat chatStream: SIMSStream, sendDate: Date, guid: String?, in localContext: NSManagedObjectContext) -> SIMSPrivateMessage?
    @discardableResult
    func newSystemChatMessage(content: String, in localContext: NSManagedObjectContext) -> SIMSPrivateMessage?
    @discardableResult
    func newSystemMessage(content: String, forChannel channel: SIMSChannel, in localContext: NSManagedObjectContext) -> SIMSChannelMessage?
    @discardableResult
    func newSystemMessage(content: String, forChannel channel: SIMSChannel, sendDate: Date, guid: String, in localContext: NSManagedObjectContext) -> SIMSChannelMessage?

    func handle(groupInvitation: DPAGMessageReceivedGroupInvitation, in localContext: NSManagedObjectContext) -> SIMSGroupStream?

    func confirmSend(messageToSend: SIMSMessageToSend, withConfirmation messageConfirmSend: DPAGMessageReceivedConfirmTimedMessageSend, in localContext: NSManagedObjectContext) -> SIMSMessage?

    func privateInternalMessageDictionary(message: SIMSPrivateInternalMessage, forRecipient recipient: SIMSContactIndexEntry, in localContext: NSManagedObjectContext) throws -> [AnyHashable: Any]?
    func internalMessageDictionary(text: String, forRecipient recipient: SIMSContactIndexEntry, writeTo outgoingMessage: SIMSPrivateInternalMessage, in localContext: NSManagedObjectContext) throws -> [AnyHashable: Any]?

    func newGroupMessage(messageDict: DPAGMessageReceivedGroup, groupStream: SIMSGroupStream, in localContext: NSManagedObjectContext) -> SIMSGroupMessage?
    func newChannelMessage(messageDict: DPAGMessageReceivedChannel, in localContext: NSManagedObjectContext) -> SIMSChannelMessage?
    func newPrivateMessage(messageDict: DPAGMessageReceivedPrivate, in localContext: NSManagedObjectContext) -> SIMSPrivateMessage?
}

class DPAGMessageModelFactory: DPAGMessageModelFactoryProtocol {
    struct MessageInfo {
        let text: String
        let desc: String?
        let sendOptions: DPAGSendMessageSendOptions?
        let recipient: DPAGSendMessageRecipient
        let recipientContact: SIMSContactIndexEntry?
        let outgoingMessage: SIMSManagedObjectMessage
        let contentType: String
        let attachment: Data?
        let featureSet: String?
        let additionalContentData: [AnyHashable: Any]?
        let localContext: NSManagedObjectContext
    }

    struct MessageGroupInfo {
        let text: String
        let desc: String?
        let sendOptions: DPAGSendMessageSendOptions?
        let stream: SIMSGroupStream
        let outgoingMessage: SIMSManagedObjectMessage
        let contentType: String
        let attachment: Data?
        let featureSet: String?
        let additionalContentData: [AnyHashable: Any]?
        let localContext: NSManagedObjectContext
    }

    var messageTypes = [
        DPAGStrings.JSON.MessagePrivate.OBJECT_KEY,
        DPAGStrings.JSON.MessagePrivateInternal.OBJECT_KEY,
        DPAGStrings.JSON.MessageInternal.OBJECT_KEY,
        DPAGStrings.JSON.MessageGroup.OBJECT_KEY,
        DPAGStrings.JSON.MessageGroupInvitation.OBJECT_KEY
    ]

    private func configureOutgoingMessage(_ outgoingMessage: SIMSPrivateMessage, recipient: DPAGSendMessageRecipient, config: DPAGEncryptionConfigurationPrivate, encMessageData: String, encAttachment: String?, attachmentIsInternalCopy: Bool, featureSet _: String?, in localContext: NSManagedObjectContext) {
        let message = outgoingMessage
        message.data = encMessageData
        message.dateSendLocal = Date()
        message.fromAccountGuid = config.senderGuid
        message.fromKey = config.senderEncAesKey
        message.fromKey2 = config.senderEncAesKey2
        message.toAccountGuid = config.recipientGuid
        message.toKey = config.recipientEncAesKey
        message.toKey2 = config.recipientEncAesKey2
        message.aesKey2IV = config.aesKeyIV
        if let encAttachment = encAttachment {
            let uuid = DPAGFunctionsGlobal.uuid(prefix: attachmentIsInternalCopy ? .temp : .none)
            DPAGAttachmentWorker.saveEncryptedAttachment(encAttachment, forGuid: uuid)
            message.attachment = uuid
        }
        if let recipient = recipient.contact, let recipientDB = SIMSContactIndexEntry.findFirst(byGuid: recipient.guid, in: localContext) {
            let stream = recipientDB.stream ?? recipientDB.createNewStream(in: localContext)
            recipientDB.confidenceState = .middle
            recipientDB.entryTypeLocal = .privat
            message.messageOrderId = NSNumber(value: ((stream?.messages?.lastObject as? SIMSMessage)?.messageOrderId?.int64Value ?? 0) + 1 as Int64)
            message.stream = stream
        }
    }

    private func configureOutgoingMessageToSend(_ outgoingMessage: SIMSMessageToSendPrivate, recipient: DPAGSendMessageRecipient, config: DPAGEncryptionConfigurationPrivate, encMessageData: String, encAttachment: String?, attachmentIsInternalCopy: Bool, featureSet _: String?, in localContext: NSManagedObjectContext) {
        let message = outgoingMessage
        message.data = encMessageData
        message.fromKey = config.senderEncAesKey
        message.fromKey2 = config.senderEncAesKey2
        message.toAccountGuid = config.recipientGuid
        message.toKey = config.recipientEncAesKey
        message.toKey2 = config.recipientEncAesKey2
        message.aesKey2IV = config.aesKeyIV
        if let recipient = recipient.contact, let recipientDB = SIMSContactIndexEntry.findFirst(byGuid: recipient.guid, in: localContext) {
            message.streamGuid = (recipientDB.stream?.guid ?? recipientDB.createNewStream(in: localContext)?.guid) ?? "unknown"
        }
        if let encAttachment = encAttachment {
            let uuid = DPAGFunctionsGlobal.uuid(prefix: attachmentIsInternalCopy ? .temp : .none)
            DPAGAttachmentWorker.saveEncryptedAttachment(encAttachment, forGuid: uuid)
            message.attachment = uuid
        }
    }

    private func configureOutgoingGroupMessage(_ outgoingMessage: SIMSGroupMessage, groupStream: SIMSGroupStream, config: DPAGEncryptionConfigurationGroup, encMessageData: String, encAttachment: String?, attachmentIsInternalCopy: Bool, featureSet _: String?) {
        let message = outgoingMessage
        message.data = encMessageData
        message.dateSendLocal = Date()
        message.fromAccountGuid = config.senderGuid
        message.toGroupGuid = config.recipientGuid
        message.messageOrderId = NSNumber(value: ((groupStream.messages?.lastObject as? SIMSMessage)?.messageOrderId?.int64Value ?? 0) + 1)
        message.stream = groupStream
        if let encAttachment = encAttachment {
            let uuid = DPAGFunctionsGlobal.uuid(prefix: attachmentIsInternalCopy ? .temp : .none)
            DPAGAttachmentWorker.saveEncryptedAttachment(encAttachment, forGuid: uuid)
            message.attachment = uuid
        }
    }

    private func configureOutgoingGroupMessageToSend(_ outgoingMessage: SIMSMessageToSendGroup, groupStream: SIMSGroupStream, config: DPAGEncryptionConfigurationGroup, encMessageData: String, encAttachment: String?, attachmentIsInternalCopy: Bool, featureSet _: String?) {
        let message = outgoingMessage
        message.data = encMessageData
        message.dateCreated = Date()
        message.toGroupGuid = config.recipientGuid
        message.streamGuid = groupStream.guid ?? "unknown"
        if let encAttachment = encAttachment {
            let uuid = DPAGFunctionsGlobal.uuid(prefix: attachmentIsInternalCopy ? .temp : .none)
            DPAGAttachmentWorker.saveEncryptedAttachment(encAttachment, forGuid: uuid)
            message.attachment = uuid
        }
    }

    // MARK: - send

    func invitationForGroup(groupGuid: String, groupName: String, groupAesKey: String, forRecipients recipients: [SIMSContactIndexEntry], isNewGroup: Bool, groupType: String, in _: NSManagedObjectContext) throws -> [[AnyHashable: Any]]? {
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) else { return nil }
        guard let profileName = contact.nickName, let accountPhone = contact.accountID else { return nil }
        var dataDict = [
            DPAGStrings.JSON.MessageGroupInvitation.GROUP_GUID: groupGuid,
            DPAGStrings.JSON.MessageGroupInvitation.GROUP_NAME: groupName,
            DPAGStrings.JSON.Group.ROOM_TYPE: groupType,
            DPAGStrings.JSON.Group.GROUP_TYPE: groupType,
            DPAGStrings.JSON.Message.NICKNAME: profileName,
            DPAGStrings.JSON.Message.PHONE: accountPhone,
            DPAGStrings.JSON.Message.CONTENT_TYPE: DPAGStrings.JSON.Message.ContentType.INVITATION
        ]
        if let accountProfilKey = contact.profilKey {
            dataDict[DPAGStrings.JSON.Message.ACCOUNT_PROFIL_KEY] = accountProfilKey
        }
        guard let jsonString = dataDict.JSONString else { return nil }
        guard let encMessageData = try CryptoHelperEncrypter.encrypt(string: jsonString, withAesKey: groupAesKey) else { return nil }
        var messages: [[AnyHashable: Any]] = []
        for recipient in recipients {
            guard let recipientPublicKey = recipient.publicKey, let config = try DPAGEncryptionConfigurationGroupInvitation(aesKeyXML: groupAesKey, forRecipient: recipient.guid ?? "??", recipientPublicKey: recipientPublicKey) else { continue }
            if let accountCrypto = DPAGCryptoHelper.newAccountCrypto(), let signatures = try DPAGEncryptionConfiguration.signatures(accountCrypto: accountCrypto, config: config, messageDataEncrypted: encMessageData) {
                let messageDict = config.messageDictionary(info: DPAGEncryptionConfigurationGroupInvitation.MessageDictionaryInfoInternal(encMessageData: encMessageData, signatures: signatures, messageType: DPAGStrings.JSON.MessageGroupInvitation.OBJECT_KEY, contentType: DPAGStrings.JSON.Message.ContentType.INTERNAL, nickname: profileName, senderId: nil))
                messages.append(messageDict)
            }
        }
        if DPAGApplicationFacade.preferences.supportMultiDevice, isNewGroup {
            if let config = try DPAGEncryptionConfigurationGroupInvitation(aesKeyXML: groupAesKey) {
                if let accountCrypto = DPAGCryptoHelper.newAccountCrypto(), let signatures = try DPAGEncryptionConfiguration.signatures(accountCrypto: accountCrypto, config: config, messageDataEncrypted: encMessageData) {
                    let messageDict = config.messageDictionary(info: DPAGEncryptionConfigurationGroupInvitation.MessageDictionaryInfoInternal(encMessageData: encMessageData, signatures: signatures, messageType: DPAGStrings.JSON.MessageGroupInvitation.OBJECT_KEY, contentType: DPAGStrings.JSON.Message.ContentType.INTERNAL, nickname: profileName, senderId: nil))
                    messages.append(messageDict)
                }
            }
        }
        return messages
    }

    func messageToSend(info: DPAGMessageModelFactory.MessageInfo) throws -> String? {
        try self.messageInternal(info: info)
    }

    func message(info: DPAGMessageModelFactory.MessageInfo) throws -> String? {
        try self.messageInternal(info: info)
    }

    private func messageInternal(info: DPAGMessageModelFactory.MessageInfo) throws -> String? {
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let accountPublicKey = contact.publicKey else { return nil }
        guard let profileName = contact.nickName, let accountPhone = contact.accountID else { return nil }
        var dataDict: [AnyHashable: Any] = [
            DPAGStrings.JSON.Message.CONTENT: info.text,
            DPAGStrings.JSON.Message.CONTENT_DESCRIPTION: info.desc ?? "",
            DPAGStrings.JSON.Message.NICKNAME: profileName,
            DPAGStrings.JSON.Message.PHONE: accountPhone,
            DPAGStrings.JSON.Message.CONTENT_TYPE: info.contentType
        ]
        if let accountProfilKey = contact.profilKey {
            dataDict[DPAGStrings.JSON.Message.ACCOUNT_PROFIL_KEY] = accountProfilKey
        }
        if let sendOptions = info.sendOptions {
            if let countDownSelfDestruction = sendOptions.countDownSelfDestruction {
                dataDict[DPAGStrings.JSON.Message.DESTRUCTION_COUNTDOWN] = NSNumber(value: countDownSelfDestruction)
            } else if let destructionDate = sendOptions.dateSelfDestruction {
                dataDict[DPAGStrings.JSON.Message.DESTRUCTION_DATE] = DPAGFormatter.date.string(from: destructionDate)
            }
        }
        if let additionalContentData = info.additionalContentData {
            additionalContentData.forEach { key, value in
                dataDict[key] = value
            }
        }
        if let messageGuidCitation = info.sendOptions?.messageGuidCitation, let citationContent = self.createCitationContentForMessage(messageGuidCitation: messageGuidCitation, in: info.localContext) {
            dataDict["citation"] = citationContent
        }
        dataDict[DPAGStrings.JSON.Message.AdditionalData.ENCODING_VERSION] = "1"
        guard let jsonString = dataDict.JSONString else {
            throw DPAGErrorCreateMessage.err465
        }
        guard let cachedAesKeys = try info.recipientContact?.aesKey(accountPublicKey: accountPublicKey, createNew: true), let recipientPublicKey = info.recipient.contact?.publicKey, let config = try DPAGEncryptionConfigurationPrivate(forRecipient: info.recipient, cachedAesKeys: cachedAesKeys, recipientPublicKey: recipientPublicKey, withIV: nil) else { return nil }
        guard let encMessageData = try CryptoHelperEncrypter.encrypt(string: jsonString, withAesKey: config.aesKeyXML) else { return nil }
        var encAttachment: String?
        if let attachment = info.attachment {
            NSLog("IMDAT::Working on Encryption")
            encAttachment = try CryptoHelperEncrypter.encrypt(data: attachment, withAesKey: config.aesKeyXML)
            NSLog("IMDAT::Working on Encryption::CONTINUING")
        }
        if let outgoingMessageToSend = info.outgoingMessage as? SIMSMessageToSendPrivate {
            self.configureOutgoingMessageToSend(outgoingMessageToSend, recipient: info.recipient, config: config, encMessageData: encMessageData, encAttachment: encAttachment, attachmentIsInternalCopy: info.sendOptions?.attachmentIsInternalCopy ?? false, featureSet: info.featureSet, in: info.localContext)
        } else if let outgoingMessagePrivate = info.outgoingMessage as? SIMSPrivateMessage {
            self.configureOutgoingMessage(outgoingMessagePrivate, recipient: info.recipient, config: config, encMessageData: encMessageData, encAttachment: encAttachment, attachmentIsInternalCopy: info.sendOptions?.attachmentIsInternalCopy ?? false, featureSet: info.featureSet, in: info.localContext)
        }
        guard let accountCrypto = DPAGCryptoHelper.newAccountCrypto(), let signatures = try DPAGEncryptionConfiguration.signatures(accountCrypto: accountCrypto, config: config, messageDataEncrypted: encMessageData, attachmentEncrypted: encAttachment) else {
            throw DPAGErrorCreateMessage.err465
        }
        let messageDict = config.messageDictionary(info: DPAGEncryptionConfigurationPrivate.MessageDictionaryInfoPrivate(encMessageData: encMessageData, encAttachment: encAttachment, signatures: signatures, messageType: DPAGStrings.JSON.MessagePrivate.OBJECT_KEY, contentType: info.contentType, sendOptions: info.sendOptions, featureSet: info.featureSet, nickname: profileName, senderId: info.outgoingMessage.guid))

        guard let jsonMetadata = messageDict.JSONString else {
            throw DPAGErrorCreateMessage.err465
        }
        guard let rawSignature = signatures.signatureDict.JSONString else {
            throw DPAGErrorCreateMessage.err465
        }
        info.outgoingMessage.rawSignature = rawSignature
        guard let rawSignature256 = signatures.signatureDict256.JSONString else {
            throw DPAGErrorCreateMessage.err465
        }
        info.outgoingMessage.rawSignature256 = rawSignature256
        return jsonMetadata
    }

    func groupMessage(info: DPAGMessageModelFactory.MessageGroupInfo) throws -> String? {
        try self.groupMessageInternal(info: info)
    }

    func groupMessageToSend(info: DPAGMessageModelFactory.MessageGroupInfo) throws -> String? {
        try self.groupMessageInternal(info: info)
    }

    private func groupMessageInternal(info: DPAGMessageModelFactory.MessageGroupInfo) throws -> String? {
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) else { return nil }
        guard let profileName = contact.nickName, let accountPhone = contact.accountID, let decAesKey = info.stream.group?.aesKey else { return nil }
        var dataDict: [AnyHashable: Any] = [
            DPAGStrings.JSON.Message.CONTENT: info.text,
            DPAGStrings.JSON.Message.CONTENT_DESCRIPTION: info.desc ?? "",
            DPAGStrings.JSON.Message.NICKNAME: profileName,
            DPAGStrings.JSON.Message.PHONE: accountPhone,
            DPAGStrings.JSON.Message.CONTENT_TYPE: info.contentType
        ]
        let outgoingMessageGuid = info.outgoingMessage.guid
        if let accountProfilKey = contact.profilKey {
            dataDict[DPAGStrings.JSON.Message.ACCOUNT_PROFIL_KEY] = accountProfilKey
        }
        if let sendOptions = info.sendOptions {
            if let countDownSelfDestruction = sendOptions.countDownSelfDestruction {
                dataDict[DPAGStrings.JSON.Message.DESTRUCTION_COUNTDOWN] = NSNumber(value: countDownSelfDestruction as Double)
            } else if let destructionDate = sendOptions.dateSelfDestruction {
                dataDict[DPAGStrings.JSON.Message.DESTRUCTION_DATE] = DPAGFormatter.date.string(from: destructionDate)
            }
        }
        if let additionalContentData = info.additionalContentData {
            additionalContentData.forEach { key, value in
                dataDict[key] = value
            }
        }
        if let messageGuidCitation = info.sendOptions?.messageGuidCitation, let citationContent = self.createCitationContentForMessage(messageGuidCitation: messageGuidCitation, in: info.localContext) {
            dataDict["citation"] = citationContent
        }
        dataDict[DPAGStrings.JSON.Message.AdditionalData.ENCODING_VERSION] = "1"
        guard let jsonString = dataDict.JSONString else {
            throw DPAGErrorCreateMessage.err465
        }
        let decAesKeyDict: [AnyHashable: Any]?
        do {
            decAesKeyDict = try XMLReader.dictionary(forXMLString: decAesKey)
            
        } catch {
            return nil
        }
        guard let aesKey = decAesKeyDict?["key"] as? String else { return nil }
        let ivData = DPAGHelperEx.iv128Bit()
        let iv = ivData.base64EncodedString()
        guard let groupGuid = info.stream.group?.guid, let config = try DPAGEncryptionConfigurationGroup(aesKeyXML: decAesKey, forGroup: groupGuid) else { return nil }
        let aesKeyDict = [
            "key": aesKey,
            "iv": iv
        ]
        guard let messageDataEncrypted = Data(base64Encoded: try CryptoHelperEncrypter.encrypt(string: jsonString, withAesKeyDict: aesKeyDict)) else { return nil }
        var encMessageData = ivData
        encMessageData.append(messageDataEncrypted)
        let base64EncMessageData = encMessageData.base64EncodedString()
        var encAttachment: String?
        if let attachment = info.attachment {
            let attachmentIvData = DPAGHelperEx.iv128Bit()
            let attachmentDecAesKeyDict = [
                "key": aesKey,
                "iv": attachmentIvData.base64EncodedString()
            ]
            let encAttachmentString = try CryptoHelperEncrypter.encrypt(data: attachment, withAesKeyDict: attachmentDecAesKeyDict)
            var encAttachmentData = attachmentIvData
            guard let encAttachmentDataBase64 = Data(base64Encoded: encAttachmentString) else { return nil }
            encAttachmentData.append(encAttachmentDataBase64)
            encAttachment = encAttachmentData.base64EncodedString()
        }
        if let outgoingMessageToSend = info.outgoingMessage as? SIMSMessageToSendGroup {
            self.configureOutgoingGroupMessageToSend(outgoingMessageToSend, groupStream: info.stream, config: config, encMessageData: base64EncMessageData, encAttachment: encAttachment, attachmentIsInternalCopy: info.sendOptions?.attachmentIsInternalCopy ?? false, featureSet: info.featureSet)
        } else if let outgoingMessageGroup = info.outgoingMessage as? SIMSGroupMessage {
            self.configureOutgoingGroupMessage(outgoingMessageGroup, groupStream: info.stream, config: config, encMessageData: base64EncMessageData, encAttachment: encAttachment, attachmentIsInternalCopy: info.sendOptions?.attachmentIsInternalCopy ?? false, featureSet: info.featureSet)
        }
        guard let accountCrypto = DPAGCryptoHelper.newAccountCrypto(), let signatures = try DPAGEncryptionConfiguration.signatures(accountCrypto: accountCrypto, config: config, messageDataEncrypted: base64EncMessageData, attachmentEncrypted: encAttachment) else {
            throw DPAGErrorCreateMessage.err465
        }

        let messageDict = config.messageDictionary(info: DPAGEncryptionConfigurationGroup.MessageDictionaryInfoGroup(encMessageData: base64EncMessageData, encAttachment: encAttachment, signatures: signatures, messageType: DPAGStrings.JSON.MessageGroup.OBJECT_KEY, contentType: info.contentType, sendOptions: info.sendOptions, featureSet: info.featureSet, nickname: contact.nickName, senderId: outgoingMessageGuid))
        guard let jsonMetadata = messageDict.JSONString else {
            throw DPAGErrorCreateMessage.err465
        }
        guard let rawSignature = signatures.signatureDict.JSONString else {
            throw DPAGErrorCreateMessage.err465
        }
        info.outgoingMessage.rawSignature = rawSignature
        guard let rawSignature256 = signatures.signatureDict256.JSONString else {
            throw DPAGErrorCreateMessage.err465
        }
        info.outgoingMessage.rawSignature256 = rawSignature256
        return jsonMetadata
    }

    func createCitationContentForMessage(messageGuidCitation: String, in localContext: NSManagedObjectContext) -> [AnyHashable: Any]? {
        if let message = SIMSMessage.findFirst(byGuid: messageGuidCitation, in: localContext), let decMessage = DPAGApplicationFacade.cache.decryptedMessage(messageGuid: messageGuidCitation, in: localContext) {
            var citation: [AnyHashable: Any] = [:]
            citation[DPAGStrings.JSON.MessageCitation.FROM_GUID] = message.fromAccountGuid
            citation[DPAGStrings.JSON.MessageCitation.MSG_GUID] = messageGuidCitation
            if let contact = SIMSContactIndexEntry.findFirst(byGuid: message.fromAccountGuid, in: localContext) {
                citation[DPAGStrings.JSON.MessageCitation.NICKNAME] = contact[.NICKNAME]
            }
            citation[SIMS_DATESEND] = DPAGFormatter.dateServer.string(from: message.dateSendServer ?? Date())
            citation[DPAGStrings.JSON.MessageCitation.CONTENT_TYPE] = decMessage.contentType.stringRepresentation
            if decMessage.contentType == .file {
                citation[DPAGStrings.JSON.MessageCitation.CONTENT] = decMessage.additionalData?.fileName ?? "File"
            } else {
                citation[DPAGStrings.JSON.MessageCitation.CONTENT] = decMessage.content
            }
            if decMessage.contentDesc != nil {
                citation[DPAGStrings.JSON.MessageCitation.CONTENT_DESCRIPTION] = decMessage.contentDesc
            }
            if let messageGroup = message as? SIMSGroupMessage {
                citation[DPAGStrings.JSON.MessageCitation.TO_GUID] = messageGroup.toGroupGuid
            } else if let messagePrivate = message as? SIMSPrivateMessage {
                citation[DPAGStrings.JSON.MessageCitation.TO_GUID] = messagePrivate.toAccountGuid
            }
            return citation
        }
        return nil
    }

    func internalMessage(text: String, forRecipient recipient: SIMSContactIndexEntry, writeTo outgoingMessage: SIMSPrivateInternalMessage, in localContext: NSManagedObjectContext) throws -> String? {
        guard let messageDict = try self.internalMessageDictionary(text: text, forRecipient: recipient, writeTo: outgoingMessage, in: localContext) else { return nil }
        guard let jsonMetadata = messageDict.JSONString else { return nil }
        return jsonMetadata
    }

    func internalMessageDictionary(text: String, forRecipient recipient: SIMSContactIndexEntry, writeTo outgoingMessage: SIMSPrivateInternalMessage, in localContext: NSManagedObjectContext) throws -> [AnyHashable: Any]? {
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) else { return nil }
        guard let key = SIMSKey.mr_findFirst(in: localContext), let profileName = contact.nickName, let accountPhone = contact.accountID else { return nil }
        var dataDict: [AnyHashable: Any] = [
            DPAGStrings.JSON.Message.CONTENT: text,
            DPAGStrings.JSON.Message.NICKNAME: profileName,
            DPAGStrings.JSON.Message.PHONE: accountPhone,
            DPAGStrings.JSON.Message.CONTENT_TYPE: DPAGStrings.JSON.Message.ContentType.PLAIN
        ]
        if let accountProfilKey = contact.profilKey {
            dataDict[DPAGStrings.JSON.Message.ACCOUNT_PROFIL_KEY] = accountProfilKey
        }
        guard let jsonString = dataDict.JSONString, let aesKey = key.aes_key else { return nil }
        guard let deviceCrypto = CryptoHelper.sharedInstance else { return nil }
        guard let decAesKey = try deviceCrypto.decryptAesKey(encryptedAeskey: aesKey) else { return nil }
        guard let recipientGuid = recipient.guid, let recipientPublicKey = recipient.publicKey, let config = try DPAGEncryptionConfigurationPrivateInternal(aesKeyXML: decAesKey, forRecipient: recipientGuid, recipientPublicKey: recipientPublicKey) else { return nil }
        guard let encMessageData = try CryptoHelperEncrypter.encrypt(string: jsonString, withAesKey: decAesKey) else { return nil }
        outgoingMessage.toAccountGuid = recipient.guid
        outgoingMessage.guid = DPAGFunctionsGlobal.uuid(prefix: .temp)
        outgoingMessage.data = encMessageData
        outgoingMessage.fromAccountGuid = ""
        if let accountCrypto = DPAGCryptoHelper.newAccountCrypto(), let signatures = try DPAGEncryptionConfiguration.signatures(accountCrypto: accountCrypto, config: config, messageDataEncrypted: encMessageData) {
            let messageDict = config.messageDictionary(info: DPAGEncryptionConfigurationPrivateInternal.MessageDictionaryInfoInternal(encMessageData: encMessageData, signatures: signatures, messageType: DPAGStrings.JSON.MessagePrivateInternal.OBJECT_KEY, contentType: DPAGStrings.JSON.Message.ContentType.INTERNAL, nickname: profileName, senderId: outgoingMessage.guid))
            return messageDict
        }
        return nil
    }

    func privateInternalMessageDictionary(message: SIMSPrivateInternalMessage, forRecipient recipient: SIMSContactIndexEntry, in localContext: NSManagedObjectContext) throws -> [AnyHashable: Any]? {
        guard let key = SIMSKey.mr_findFirst(in: localContext), let encMessageData = message.data, let aesKey = key.aes_key else { return nil }
        guard let deviceCrypto = CryptoHelper.sharedInstance else { return nil }
        guard let decAesKey = try deviceCrypto.decryptAesKey(encryptedAeskey: aesKey) else { return nil }
        guard let recipientGuid = recipient.guid, let recipientPublicKey = recipient.publicKey, let config = try DPAGEncryptionConfigurationPrivateInternal(aesKeyXML: decAesKey, forRecipient: recipientGuid, recipientPublicKey: recipientPublicKey) else { return nil }
        if let accountCrypto = DPAGCryptoHelper.newAccountCrypto(), let signatures = try DPAGEncryptionConfiguration.signatures(accountCrypto: accountCrypto, config: config, messageDataEncrypted: encMessageData) {
            let messageDict = config.messageDictionary(info: DPAGEncryptionConfigurationPrivateInternal.MessageDictionaryInfoInternal(encMessageData: encMessageData, signatures: signatures, messageType: DPAGStrings.JSON.MessagePrivateInternal.OBJECT_KEY, contentType: DPAGStrings.JSON.Message.ContentType.INTERNAL, nickname: nil, senderId: message.guid))
            return messageDict
        }
        return nil
    }

    // MARK: - system

    func newSystemMessage(content: String, forGroupGuid groupGuid: String, sendDate: Date, guid: String?) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            guard let groupStream = SIMSGroupStream.findFirst(byGuid: groupGuid, in: localContext) else { return }
            self.newSystemMessage(content: content, forGroup: groupStream, sendDate: sendDate, guid: guid, in: localContext)
        }
    }

    @discardableResult
    func newSystemMessage(content: String, forGroup group: SIMSGroupStream, sendDate: Date, guid: String?, in localContext: NSManagedObjectContext) -> SIMSGroupMessage? {
        if let messageGuid = guid, let messageExisting = SIMSMessage.findFirst(byGuid: messageGuid, in: localContext) as? SIMSGroupMessage {
            return messageExisting
        }
        let ivData = DPAGHelperEx.iv128Bit()
        let iv = ivData.base64EncodedString()
        let dataDict = [
            DPAGStrings.JSON.Message.CONTENT: content,
            DPAGStrings.JSON.Message.CONTENT_TYPE: DPAGStrings.JSON.Message.ContentType.PLAIN
        ]
        guard let jsonString = dataDict.JSONString, let decAesKey = group.group?.aesKey else { return nil }
        let decAesKeyDict: [AnyHashable: Any]?
        do {
            decAesKeyDict = try XMLReader.dictionary(forXMLString: decAesKey)
        } catch {
            return nil
        }
        guard let aesKey = decAesKeyDict?["key"] as? String else { return nil }
        let aesKeyDict = [
            "key": aesKey,
            "iv": iv
        ]
        if let lastMessage = group.messages?.lastObject as? SIMSGroupMessage {
            if let decLastMessageDictionary = DPAGApplicationFacade.messageCryptoWorker.decryptGroupMessageDict(lastMessage, decAesKey: decAesKey), content == decLastMessageDictionary.content {
                return nil
            }
        }
        guard let encMessageDataString = try? CryptoHelperEncrypter.encrypt(string: jsonString, withAesKeyDict: aesKeyDict) else { return nil }
        guard let message = SIMSGroupMessage.mr_createEntity(in: localContext) else { return nil }
        message.dateSendLocal = sendDate
        message.dateSendServer = sendDate
        message.attributes = SIMSMessageAttributes.mr_createEntity(in: localContext)
        var encMessageData = ivData
        guard let encMessageDataBase64 = Data(base64Encoded: encMessageDataString) else { return nil }
        encMessageData.append(encMessageDataBase64)
        message.data = encMessageData.base64EncodedString()
        let messageGuid = guid ?? DPAGFunctionsGlobal.uuid(prefix: .messageGroup)
        message.guid = messageGuid
        message.fromAccountGuid = DPAGConstantsGlobal.kSystemChatAccountGuid
        message.toGroupGuid = group.guid ?? "unknown"
        message.messageOrderId = NSNumber(value: ((group.messages?.lastObject as? SIMSMessage)?.messageOrderId?.int64Value ?? 0) + 1 as Int64)
        message.stream = group
        message.typeMessage = .group
        return message
    }

    func newSystemMessage(content: String, forChatGuid chatStreamGuid: String, sendDate: Date, guid: String?) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            guard let chatStream = SIMSStream.findFirst(byGuid: chatStreamGuid, in: localContext) else { return }
            self.newSystemMessage(content: content, forChat: chatStream, sendDate: sendDate, guid: guid, in: localContext)
        }
    }

    @discardableResult
    func newSystemMessage(content: String, forChat chatStream: SIMSStream, sendDate: Date, guid: String?, in localContext: NSManagedObjectContext) -> SIMSPrivateMessage? {
        guard let message = self.newSystemChatMessage(content: content, in: localContext) else { return nil }
        if let guid = guid {
            message.guid = guid
        }
        message.dateSendLocal = sendDate
        message.dateSendServer = sendDate
        message.messageOrderId = NSNumber(value: ((chatStream.messages?.lastObject as? SIMSMessage)?.messageOrderId?.int64Value ?? 0) + 1 as Int64)
        message.stream = chatStream
        return message
    }

    func newOooStatusMessage(content: String, forChat chatStream: SIMSStream, sendDate: Date, guid: String?, in localContext: NSManagedObjectContext) -> SIMSPrivateMessage? {
        guard let message = self.newSystemChatMessage(content: content, contentType: DPAGStrings.JSON.Message.ContentType.OOO_STATUS_MESSAGE, in: localContext) else { return nil }
        if let guid = guid {
            message.guid = guid
        }
        message.dateSendLocal = sendDate
        message.dateSendServer = sendDate
        message.messageOrderId = NSNumber(value: ((chatStream.messages?.lastObject as? SIMSMessage)?.messageOrderId?.int64Value ?? 0) + 1 as Int64)
        message.stream = chatStream
        return message
    }

    func newSystemChatMessage(content: String, in localContext: NSManagedObjectContext) -> SIMSPrivateMessage? {
        self.newSystemChatMessage(content: content, contentType: DPAGStrings.JSON.Message.ContentType.PLAIN, in: localContext)
    }

    func newSystemChatMessage(content: String, contentType: String, in localContext: NSManagedObjectContext) -> SIMSPrivateMessage? {
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let accountPublicKey = contact.publicKey else { return nil }
        guard let decAesKey = try? CryptoHelperEncrypter.getNewAesKey() else { return nil }
        let dataDict: [AnyHashable: Any] = [
            DPAGStrings.JSON.Message.CONTENT: content,
            DPAGStrings.JSON.Message.CONTENT_TYPE: contentType
        ]
        guard let jsonString = dataDict.JSONString else { return nil }
        guard let encMessageData = try? CryptoHelperEncrypter.encrypt(string: jsonString, withAesKey: decAesKey) else { return nil }
        guard let message = SIMSPrivateMessage.mr_createEntity(in: localContext) else { return nil }
        guard let toKey = try? CryptoHelperEncrypter.encrypt(string: decAesKey, withPublicKey: accountPublicKey) else { return nil }
        message.toKey = toKey
        message.data = encMessageData
        message.dateSendLocal = Date()
        message.dateSendServer = message.dateSendLocal
        message.attributes = SIMSMessageAttributes.mr_createEntity(in: localContext)
        message.guid = DPAGFunctionsGlobal.uuid(prefix: .messageChat)
        message.fromAccountGuid = DPAGConstantsGlobal.kSystemChatAccountGuid
        message.fromKey = ""
        message.toAccountGuid = account.guid
        message.typeMessage = .private
        return message
    }

    func newSystemMessage(content: String, forChannel channel: SIMSChannel, in localContext: NSManagedObjectContext) -> SIMSChannelMessage? {
        guard let iv = channel.iv, let decAesKey = channel.aes_key else { return nil }
        let dataDict = [
            DPAGStrings.JSON.Message.CONTENT: content,
            DPAGStrings.JSON.Message.CONTENT_TYPE: DPAGStrings.JSON.Message.ContentType.PLAIN
        ]
        guard let jsonString = dataDict.JSONString else { return nil }
        let aesKeyDict = DPAGAesKeyDecrypted(aesKey: decAesKey, iv: iv)
        if let lastMessage = channel.stream?.messages?.lastObject as? SIMSChannelMessage {
            if let decLastMessageDictionary = DPAGApplicationFacade.messageCryptoWorker.decryptChannelMessage(lastMessage, decAesKeyDict: aesKeyDict), content == decLastMessageDictionary.content {
                return nil
            }
        }
        guard let encMessageDataString = try? CryptoHelperEncrypter.encrypt(string: jsonString, withAesKeyDict: aesKeyDict.dict) else { return nil }
        guard let message = SIMSChannelMessage.mr_createEntity(in: localContext) else { return nil }
        message.dateSendLocal = Date()
        message.dateSendServer = message.dateSendLocal
        message.attributes = SIMSMessageAttributes.mr_createEntity(in: localContext)
        message.fromAccountGuid = DPAGConstantsGlobal.kSystemChatAccountGuid
        message.fromKey = channel.aes_key ?? ""
        message.data = encMessageDataString
        message.guid = DPAGFunctionsGlobal.uuid(prefix: .messageChannel)
        message.toAccountGuid = DPAGApplicationFacade.cache.account?.guid ?? "unknown"
        message.toKey = ""
        message.messageOrderId = NSNumber(value: ((channel.stream?.messages?.lastObject as? SIMSMessage)?.messageOrderId?.int64Value ?? 0) + 1 as Int64)
        message.stream = channel.stream
        message.typeMessage = .channel
        message.stream?.lastMessageDate = message.dateSendLocal
        if DPAGApplicationFacade.cache.decrypteStream(stream: message.stream) != nil {
            DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: message.stream?.guid, stream: message.stream, in: localContext)
        }
        return message
    }

    func newSystemMessage(content: String, forChannel channel: SIMSChannel, sendDate: Date, guid: String, in localContext: NSManagedObjectContext) -> SIMSChannelMessage? {
        guard let iv = channel.iv, let decAesKey = channel.aes_key else { return nil }
        let dataDict = [
            DPAGStrings.JSON.Message.CONTENT: content,
            DPAGStrings.JSON.Message.CONTENT_TYPE: DPAGStrings.JSON.Message.ContentType.PLAIN
        ]
        guard let jsonString = dataDict.JSONString else { return nil }
        let aesKeyDict = DPAGAesKeyDecrypted(aesKey: decAesKey, iv: iv)
        if let lastMessage = channel.stream?.messages?.lastObject as? SIMSChannelMessage {
            if let decLastMessageDictionary = DPAGApplicationFacade.messageCryptoWorker.decryptChannelMessage(lastMessage, decAesKeyDict: aesKeyDict), content == decLastMessageDictionary.content {
                return nil
            }
        }
        guard let encMessageDataString = try? CryptoHelperEncrypter.encrypt(string: jsonString, withAesKeyDict: aesKeyDict.dict) else { return nil }
        guard let message = SIMSChannelMessage.mr_createEntity(in: localContext) else { return nil }
        message.dateSendLocal = sendDate
        message.dateSendServer = sendDate
        message.attributes = SIMSMessageAttributes.mr_createEntity(in: localContext)
        message.fromAccountGuid = DPAGConstantsGlobal.kSystemChatAccountGuid
        message.fromKey = channel.aes_key ?? ""
        message.data = encMessageDataString
        message.guid = guid
        message.toAccountGuid = DPAGApplicationFacade.cache.account?.guid ?? "unknown"
        message.toKey = ""
        message.messageOrderId = NSNumber(value: ((channel.stream?.messages?.lastObject as? SIMSMessage)?.messageOrderId?.int64Value ?? 0) + 1 as Int64)
        message.stream = channel.stream
        message.typeMessage = .channel
        message.stream?.lastMessageDate = message.dateSendLocal
        return message
    }

    // MARK: - receive

    func handle(groupInvitation: DPAGMessageReceivedGroupInvitation, in localContext: NSManagedObjectContext) -> SIMSGroupStream? {
        do {
            var stream: SIMSGroupStream?
            let contentDecrypted = try groupInvitation.contentDecrypted()
            if let existingGroup = SIMSMessageStream.findFirst(byGuid: contentDecrypted.groupGuid, in: localContext) as? SIMSGroupStream {
                if groupInvitation.fromAccountInfo.accountGuid == DPAGApplicationFacade.cache.account?.guid {
                    existingGroup.group?.isConfirmed = true
                    existingGroup.group?.wasDeleted = false
                    stream = existingGroup
                    DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: contentDecrypted.groupGuid, stream: existingGroup, in: localContext)
                } else {
                    if (existingGroup.group?.wasDeleted ?? false) == false {
                        return nil
                    }
                    existingGroup.group?.isConfirmed = false
                    existingGroup.group?.wasDeleted = false
                    stream = existingGroup
                    DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: contentDecrypted.groupGuid, stream: existingGroup, in: localContext)
                }
            } else if let streamNew = SIMSGroupStream.mr_createEntity(in: localContext) {
                streamNew.guid = contentDecrypted.groupGuid
                streamNew.typeStream = .group
                streamNew.optionsStream = DPAGApplicationFacade.preferences.streamVisibilityGroup ? [] : .filtered
                if let group = SIMSGroup.findFirst(byGuid: contentDecrypted.groupGuid, in: localContext) ?? SIMSGroup.mr_createEntity(in: localContext) {
                    group.guid = contentDecrypted.groupGuid
                    streamNew.group = group
                    if let toAccountDecAesKey = contentDecrypted.groupAesKey {
                        group.aesKey = toAccountDecAesKey
                    }
                    group.keyRelationship = SIMSKey.mr_findFirst(in: localContext)
                    group.type = NSNumber(value: contentDecrypted.groupType.rawValue)
                }
                stream = streamNew
            }
            stream?.group?.invitedAt = groupInvitation.dateSend
            stream?.lastMessageDate = stream?.group?.invitedAt
            stream?.group?.groupName = contentDecrypted.groupName
            // OWNER is SENDER!!! Not relevant now, but maybe in the future
            stream?.group?.ownerGuid = groupInvitation.fromAccountInfo.accountGuid
            DPAGHelperEx.saveBase64Image(encodedImage: contentDecrypted.groupImageEncoded, forGroupGuid: contentDecrypted.groupGuid)
            return stream
        } catch {
            DPAGLog(error)
        }
        return nil
    }

    func newGroupMessage(messageDict: DPAGMessageReceivedGroup, groupStream: SIMSGroupStream, in localContext: NSManagedObjectContext) -> SIMSGroupMessage? {
        var messageDB = SIMSMessage.findFirst(byGuid: messageDict.guid, in: localContext) as? SIMSGroupMessage
        if messageDB == nil {
            if let senderGuid = messageDict.senderId { // message from share extension
                messageDB = SIMSMessage.findFirst(byGuid: senderGuid, in: localContext) as? SIMSGroupMessage
            }
        }
        if messageDB == nil {
            messageDB = SIMSGroupMessage.mr_createEntity(in: localContext)
            messageDB?.attributes = SIMSMessageAttributes.mr_createEntity(in: localContext)
        } else if let recipients = messageDB?.receiver {
            for recipient in recipients {
                recipient.mr_deleteEntity(in: localContext)
            }
        }
        guard let message = messageDB else { return nil }
        message.dateSendServer = messageDict.dateSend
        message.dateSendLocal = Date()
        if let dateDownloaded = messageDict.dateDownloaded, message.attributes?.dateDownloaded == nil {
            if message.attributes == nil {
                message.attributes = SIMSMessageAttributes.mr_createEntity(in: localContext)
            }
            message.attributes?.dateDownloaded = DPAGFormatter.date.date(from: dateDownloaded)
        }
        message.data = messageDict.data
        message.guid = messageDict.guid
        if let attachmentGuid = message.attachment, let attachmentGuidNew = messageDict.attachments?.first {
            DPAGAttachmentWorker.moveEncryptedAttachment(guidOld: attachmentGuid, guidNew: attachmentGuidNew)
        }
        message.attachment = messageDict.attachments?.first
        message.fromAccountGuid = messageDict.fromAccountInfo.accountGuid
        if message.fromAccountGuid == DPAGApplicationFacade.cache.account?.guid {
            message.sendingState = NSNumber(value: DPAGMessageState.sentSucceeded.rawValue)
            message.dateSendLocal = message.dateSendServer
        }
        message.toGroupGuid = messageDict.toAccountGuid
        message.errorType = NSNumber(value: messageDict.contentTyp == DPAGMessageContentType.textRSS.stringRepresentation ? DPAGMessageSecurityError.none.rawValue : DPAGMessageSecurityError.notChecked.rawValue)
        if let dataSignature = messageDict.dataSignature?.JSONString {
            message.dataSignature = dataSignature
        }
        if let dataSignature = messageDict.dataSignature256?.JSONString {
            message.dataSignature256 = dataSignature
            message.setAdditionalData(key: "dataSignature256", value: dataSignature)
        }
        if messageDict.fromAccountInfo.tempDevice?.guid != nil {
            message.setAdditionalData(key: "fromAccountTempDeviceGuid", value: messageDict.fromAccountInfo.tempDevice?.guid)
            message.setAdditionalData(key: "fromAccountTempDeviceAesKey", value: messageDict.fromAccountInfo.tempDevice?.key)
        }
        message.rawSignature = message.dataSignature
        message.rawSignature256 = message.dataSignature256
        if let dataSignatureTemp256 = messageDict.dataSignatureTemp256?.JSONString {
            message.setAdditionalData(key: "dataSignatureTemp256", value: dataSignatureTemp256)
        }
        message.optionsMessage = messageDict.messagePriorityHigh ? .priorityHigh : []
        if (message.messageOrderId?.intValue ?? 0) == 0 {
            message.messageOrderId = NSNumber(value: ((groupStream.messages?.lastObject as? SIMSMessage)?.messageOrderId?.int64Value ?? 0) + 1 as Int64)
            message.stream = groupStream
            message.stream?.lastMessageDate = message.dateSendServer
        }
        if message.fromAccountGuid != DPAGApplicationFacade.cache.account?.guid {
            message.stream?.optionsStream = groupStream.optionsStream.union(messageDict.messagePriorityHigh ? [.hasUnreadMessages, .hasUnreadHighPriorityMessages] : [.hasUnreadMessages])
        }
        message.typeMessage = .group
        if let recipients = messageDict.recipients, recipients.isEmpty == false {
            for recipient in recipients {
                if recipient.contactGuid != message.fromAccountGuid, let contact = SIMSContactIndexEntry.findFirst(byGuid: recipient.contactGuid, in: localContext) {
                    if let recipientEntity = SIMSMessageReceiver.mr_createEntity(in: localContext) {
                        recipientEntity.contactIndexEntry = contact
                        recipientEntity.sendsReadConfirmation = NSNumber(value: recipient.sendsReadConfirmation == "1")
                        recipientEntity.message = message
                        message.receiver?.insert(recipientEntity)
                    }
                }
            }
        }
        if let contentType = messageDict.contentTyp {
            message.setAdditionalData(key: "contentType", value: contentType)
        }
        return message
    }

    func newChannelMessage(messageDict: DPAGMessageReceivedChannel, in localContext: NSManagedObjectContext) -> SIMSChannelMessage? {
        guard let channel = SIMSChannel.findFirst(byGuid: messageDict.toAccountGuid, in: localContext) else { return nil }
        var messageDB = SIMSMessage.findFirst(byGuid: messageDict.guid, in: localContext) as? SIMSChannelMessage
        if messageDB == nil {
            messageDB = SIMSChannelMessage.mr_createEntity(in: localContext)
            messageDB?.attributes = SIMSMessageAttributes.mr_createEntity(in: localContext)
        }
        guard let message = messageDB else { return nil }
        message.dateSendServer = messageDict.dateSend
        message.dateSendLocal = Date()
        if let dateDownloaded = messageDict.dateDownloaded, message.attributes?.dateDownloaded == nil {
            if message.attributes == nil {
                message.attributes = SIMSMessageAttributes.mr_createEntity(in: localContext)
            }
            message.dateDownloaded = DPAGFormatter.date.date(from: dateDownloaded)
        }
        message.fromAccountGuid = messageDict.toAccountGuid
        message.fromKey = channel.aes_key ?? ""
        message.data = messageDict.data
        message.attachment = messageDict.attachments?.first
        message.guid = messageDict.guid
        message.toAccountGuid = DPAGApplicationFacade.cache.account?.guid ?? "unknown"
        message.toKey = ""
        message.messageOrderId = NSNumber(value: ((channel.stream?.messages?.lastObject as? SIMSMessage)?.messageOrderId?.int64Value ?? 0) + 1 as Int64)
        message.stream = channel.stream
        message.stream?.optionsStream = channel.stream?.optionsStream.union(.hasUnreadMessages) ?? []
        message.typeMessage = .channel
        message.stream?.lastMessageDate = message.dateSendServer
        return message
    }

    func newPrivateMessage(messageDict: DPAGMessageReceivedPrivate, in localContext: NSManagedObjectContext) -> SIMSPrivateMessage? {
        var messageDB = SIMSMessage.findFirst(byGuid: messageDict.guid, in: localContext) as? SIMSPrivateMessage
        if messageDB == nil {
            if let senderGuid = messageDict.senderId { // message from share extension
                messageDB = SIMSMessage.findFirst(byGuid: senderGuid, in: localContext) as? SIMSPrivateMessage
            }
        }
        if messageDB == nil {
            messageDB = SIMSPrivateMessage.mr_createEntity(in: localContext)
            messageDB?.attributes = SIMSMessageAttributes.mr_createEntity(in: localContext)
        }
        guard let message = messageDB else { return nil }
        message.dateSendServer = messageDict.dateSend
        message.dateSendLocal = Date()
        if let dateDownloaded = messageDict.dateDownloaded, message.attributes?.dateDownloaded == nil {
            if message.attributes == nil {
                message.attributes = SIMSMessageAttributes.mr_createEntity(in: localContext)
            }
            message.dateDownloaded = DPAGFormatter.date.date(from: dateDownloaded)
        }
        message.data = messageDict.data
        message.guid = messageDict.guid
        if let attachmentGuid = message.attachment, let attachmentGuidNew = messageDict.attachments?.first, attachmentGuid != attachmentGuidNew {
            DPAGAttachmentWorker.moveEncryptedAttachment(guidOld: attachmentGuid, guidNew: attachmentGuidNew)
        }
        message.attachment = messageDict.attachments?.first
        message.fromAccountGuid = messageDict.fromAccountInfo.accountGuid
        if message.fromAccountGuid == DPAGApplicationFacade.cache.account?.guid {
            message.sendingState = NSNumber(value: DPAGMessageState.sentSucceeded.rawValue as UInt)
            message.dateSendLocal = message.dateSendServer
        }
        message.fromKey = messageDict.fromAccountInfo.encAesKey
        message.fromKey2 = messageDict.fromAccountInfo.encAesKey2
        message.toAccountGuid = messageDict.toAccountInfo.accountGuid
        message.toKey = messageDict.toAccountInfo.encAesKey
        message.toKey2 = messageDict.toAccountInfo.encAesKey2
        message.aesKey2IV = messageDict.aesKey2IV
        message.errorType = NSNumber(value: messageDict.contentTyp == DPAGMessageContentType.textRSS.stringRepresentation ? DPAGMessageSecurityError.none.rawValue : DPAGMessageSecurityError.notChecked.rawValue)
        if let dataSignature = messageDict.dataSignature?.JSONString {
            message.dataSignature = dataSignature
        }
        if let dataSignature = messageDict.dataSignature256?.JSONString {
            message.dataSignature256 = dataSignature
            message.setAdditionalData(key: "dataSignature256", value: dataSignature)
        }
        if let dataSignatureTemp256 = messageDict.dataSignatureTemp256?.JSONString {
            message.setAdditionalData(key: "dataSignatureTemp256", value: dataSignatureTemp256)
        }
        message.rawSignature = message.dataSignature
        message.rawSignature256 = message.dataSignature256
        message.optionsMessage = messageDict.messagePriorityHigh ? .priorityHigh : []
        message.typeMessage = .private
        if messageDict.fromAccountInfo.tempDevice?.guid != nil {
            message.setAdditionalData(key: "fromAccountTempDeviceGuid", value: messageDict.fromAccountInfo.tempDevice?.guid)
            message.setAdditionalData(key: "fromAccountTempDeviceAesKey", value: messageDict.fromAccountInfo.tempDevice?.key)
            message.setAdditionalData(key: "fromAccountTempDeviceAesKey2", value: messageDict.fromAccountInfo.tempDevice?.key2)
        }
        if messageDict.toAccountInfo.tempDevice?.guid != nil {
            message.setAdditionalData(key: "toAccountTempDeviceGuid", value: messageDict.toAccountInfo.tempDevice?.guid)
            message.setAdditionalData(key: "toAccountTempDeviceAesKey", value: messageDict.toAccountInfo.tempDevice?.key)
            message.setAdditionalData(key: "toAccountTempDeviceAesKey2", value: messageDict.toAccountInfo.tempDevice?.key2)
        }
        if let contentType = messageDict.contentTyp {
            message.setAdditionalData(key: "contentType", value: contentType)
        }
        return message
    }

    func confirmSend(messageToSend: SIMSMessageToSend, withConfirmation messageConfirmSend: DPAGMessageReceivedConfirmTimedMessageSend, in localContext: NSManagedObjectContext) -> SIMSMessage? {
        if let messageToSendPrivate = messageToSend as? SIMSMessageToSendPrivate, let messageStreamPrivate = messageToSendPrivate.streamToSend(in: localContext) {
            guard let message = SIMSPrivateMessage.mr_createEntity(in: localContext) else { return nil }
            message.dateSendServer = messageConfirmSend.dateSend
            message.dateSendLocal = messageConfirmSend.dateSend
            message.attributes = SIMSMessageAttributes.mr_createEntity(in: localContext)
            message.data = messageToSend.data
            message.guid = messageToSend.guid
            if let attachmentGuid = message.attachment, let attachmentGuidNew = messageToSend.attachment {
                DPAGAttachmentWorker.moveEncryptedAttachment(guidOld: attachmentGuid, guidNew: attachmentGuidNew)
            }
            message.attachment = messageToSend.attachment
            message.attachmentHash = messageToSend.attachmentHash
            message.fromAccountGuid = (DPAGApplicationFacade.cache.account?.guid ?? messageConfirmSend.fromGuid)
            message.fromKey = messageToSendPrivate.fromKey
            message.toAccountGuid = messageToSendPrivate.toAccountGuid
            message.toKey = messageToSendPrivate.toKey
            message.errorType = NSNumber(value: DPAGMessageSecurityError.none.rawValue as Int)
            message.dataSignature = messageToSend.dataSignature
            message.dataSignature256 = messageToSend.dataSignature256
            message.rawSignature = messageToSend.rawSignature
            message.rawSignature256 = messageToSend.rawSignature256
            let orderIdLast = ((messageStreamPrivate.messages?.lastObject as? SIMSMessage)?.messageOrderId?.int64Value ?? 0)
            message.messageOrderId = NSNumber(value: orderIdLast + 1)
            message.stream = messageStreamPrivate
            message.stream?.optionsStream = messageStreamPrivate.optionsStream.union(.hasUnreadMessages)
            message.typeMessage = .private
            message.stream?.lastMessageDate = message.dateSendServer
            message.sendingState = NSNumber(value: DPAGMessageState.sentSucceeded.rawValue)
            message.optionsMessage = messageToSend.optionsMessage
            messageToSendPrivate.mr_deleteEntity(in: localContext)
            return message
        } else if let messageToSendGroup = messageToSend as? SIMSMessageToSendGroup, let messageStreamGroup = messageToSendGroup.streamToSend(in: localContext) {
            guard let message = SIMSGroupMessage.mr_createEntity(in: localContext) else { return nil }
            message.dateSendServer = messageConfirmSend.dateSend
            message.dateSendLocal = messageConfirmSend.dateSend
            message.attributes = SIMSMessageAttributes.mr_createEntity(in: localContext)
            message.data = messageToSend.data
            message.guid = messageToSend.guid
            if let attachmentGuid = message.attachment, let attachmentGuidNew = messageToSend.attachment {
                DPAGAttachmentWorker.moveEncryptedAttachment(guidOld: attachmentGuid, guidNew: attachmentGuidNew)
            }
            message.attachment = messageToSend.attachment
            message.attachmentHash = messageToSend.attachmentHash
            message.fromAccountGuid = (DPAGApplicationFacade.cache.account?.guid ?? messageConfirmSend.fromGuid)
            message.toGroupGuid = messageToSendGroup.toGroupGuid
            message.errorType = NSNumber(value: DPAGMessageSecurityError.none.rawValue)
            message.dataSignature = messageToSend.dataSignature
            message.dataSignature256 = messageToSend.dataSignature256
            message.rawSignature = messageToSend.rawSignature
            message.rawSignature256 = messageToSend.rawSignature256
            let orderIdLast = ((messageStreamGroup.messages?.lastObject as? SIMSMessage)?.messageOrderId?.int64Value ?? 0)
            message.messageOrderId = NSNumber(value: orderIdLast + 1)
            message.stream = messageStreamGroup
            message.stream?.lastMessageDate = message.dateSendServer
            message.stream?.optionsStream = messageStreamGroup.optionsStream.union(.hasUnreadMessages)
            message.typeMessage = .group
            message.sendingState = NSNumber(value: DPAGMessageState.sentSucceeded.rawValue)
            message.optionsMessage = messageToSend.optionsMessage
            if let recipients = messageConfirmSend.recipients, recipients.isEmpty == false {
                for recipient in recipients {
                    if recipient.contactGuid != message.fromAccountGuid, let contact = SIMSContactIndexEntry.findFirst(byGuid: recipient.contactGuid, in: localContext) {
                        if let recipientEntity = SIMSMessageReceiver.mr_createEntity(in: localContext) {
                            recipientEntity.contactIndexEntry = contact
                            recipientEntity.sendsReadConfirmation = NSNumber(value: recipient.sendsReadConfirmation == "1")
                            recipientEntity.message = message
                            message.receiver?.insert(recipientEntity)
                        }
                    }
                }
            }
            messageToSendGroup.mr_deleteEntity(in: localContext)
            return message
        }
        return nil
    }
}
