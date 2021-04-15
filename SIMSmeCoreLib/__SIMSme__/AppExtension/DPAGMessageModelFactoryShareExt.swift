//
//  DPAGMessageModelFactoryShareExt.swift
//  SIMSmeShareExtensionBase
//
//  Created by RBU on 06.08.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

protocol DPAGMessageModelFactoryShareExtProtocol: AnyObject {
    func message(info: DPAGMessageModelFactoryShareExt.MessageInfo) throws -> String?
    func groupMessage(info: DPAGMessageModelFactoryShareExt.MessageGroupInfo) throws -> String?
}

class DPAGMessageModelFactoryShareExt: NSObject, DPAGMessageModelFactoryShareExtProtocol {
    struct MessageInfo {
        let guid: String?
        let senderId: String
        let text: String
        let desc: String?
        let sendOptions: DPAGSendMessageSendOptions?
        let recipient: DPAGSendMessageRecipient
        let recipientPublicKey: String
        let cachedAesKeys: DPAGContactAesKeys
        let contentType: String
        let attachment: Data?
        let featureSet: String?
        let additionalContentData: [AnyHashable: Any]?
        let accountCrypto: CryptoHelperSimple
    }

    struct MessageGroupInfo {
        let guid: String?
        let senderId: String
        let text: String
        let desc: String?
        let sendOptions: DPAGSendMessageSendOptions?
        let aesKey: String
        let groupGuid: String
        let contentType: String
        let attachment: Data?
        let featureSet: String?
        let additionalContentData: [AnyHashable: Any]?
        let accountCrypto: CryptoHelperSimple
    }

    func message(info: DPAGMessageModelFactoryShareExt.MessageInfo) throws -> String? {
        try self.messageInternal(info: info)
    }

    fileprivate func messageInternal(info: DPAGMessageModelFactoryShareExt.MessageInfo) throws -> String? {
        guard let account = DPAGApplicationFacadeShareExt.cache.account, let contact = DPAGApplicationFacadeShareExt.cache.contact(for: account.guid) else { return nil }
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
        dataDict[DPAGStrings.JSON.Message.AdditionalData.ENCODING_VERSION] = "1"
        guard let jsonString = dataDict.JSONString else { throw DPAGErrorCreateMessage.err465 }
        guard let config = try DPAGEncryptionConfigurationPrivate(forRecipient: info.recipient, cachedAesKeys: info.cachedAesKeys, recipientPublicKey: info.recipientPublicKey, withIV: nil) else { return nil }
        guard let encMessageData = try CryptoHelperEncrypter.encrypt(string: jsonString, withAesKey: config.aesKeyXML) else { return nil }
        var encAttachment: String?
        if let attachment = info.attachment {
            encAttachment = try CryptoHelperEncrypter.encrypt(data: attachment, withAesKey: config.aesKeyXML)
        }
        guard let signatures = try DPAGEncryptionConfiguration.signatures(accountCrypto: info.accountCrypto, config: config, messageDataEncrypted: encMessageData, attachmentEncrypted: encAttachment) else { throw DPAGErrorCreateMessage.err465 }
        let messageType = DPAGStrings.JSON.MessagePrivate.OBJECT_KEY
        var messageDict = config.messageDictionary(info: DPAGEncryptionConfigurationPrivate.MessageDictionaryInfoPrivate(encMessageData: encMessageData, encAttachment: encAttachment, signatures: signatures, messageType: messageType, contentType: info.contentType, sendOptions: info.sendOptions, featureSet: info.featureSet, nickname: profileName, senderId: info.senderId))
        if var dict = messageDict[messageType] as? [AnyHashable: Any] {
            dict[SIMS_GUID] = info.guid
            messageDict[messageType] = dict
        }
        guard let jsonMetadata = messageDict.JSONString else { throw DPAGErrorCreateMessage.err465 }
        guard signatures.signatureDict.JSONString != nil else { throw DPAGErrorCreateMessage.err465 }
        guard signatures.signatureDict256.JSONString != nil else { throw DPAGErrorCreateMessage.err465 }
        return jsonMetadata
    }

    func groupMessage(info: DPAGMessageModelFactoryShareExt.MessageGroupInfo) throws -> String? {
        try self.groupMessageInternal(info: info)
    }

    fileprivate func groupMessageInternal(info: DPAGMessageModelFactoryShareExt.MessageGroupInfo) throws -> String? {
        guard let account = DPAGApplicationFacadeShareExt.cache.account, let contact = DPAGApplicationFacadeShareExt.cache.contact(for: account.guid) else { return nil }
        guard let profileName = contact.nickName, let accountPhone = contact.accountID else { return nil }
        let decAesKey = info.aesKey
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
        dataDict[DPAGStrings.JSON.Message.AdditionalData.ENCODING_VERSION] = "1"
        guard let jsonString = dataDict.JSONString else { throw DPAGErrorCreateMessage.err465 }
        let decAesKeyDict: [AnyHashable: Any]?
        do {
            decAesKeyDict = try XMLReader.dictionary(forXMLString: decAesKey)
        } catch {
            return nil
        }
        guard let aesKey = decAesKeyDict?["key"] as? String else { return nil }
        let ivData = DPAGHelperEx.iv128Bit()
        let iv = ivData.base64EncodedString()
        guard let config = try DPAGEncryptionConfigurationGroup(aesKeyXML: decAesKey, forGroup: info.groupGuid) else { return nil }
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
        guard let signatures = try DPAGEncryptionConfiguration.signatures(accountCrypto: info.accountCrypto, config: config, messageDataEncrypted: base64EncMessageData, attachmentEncrypted: encAttachment) else { throw DPAGErrorCreateMessage.err465 }
        let messageType = DPAGStrings.JSON.MessageGroup.OBJECT_KEY
        var messageDict = config.messageDictionary(info: DPAGEncryptionConfigurationGroup.MessageDictionaryInfoGroup(encMessageData: base64EncMessageData, encAttachment: encAttachment, signatures: signatures, messageType: messageType, contentType: info.contentType, sendOptions: info.sendOptions, featureSet: info.featureSet, nickname: contact.nickName, senderId: info.senderId))
        if var dict = messageDict[messageType] as? [AnyHashable: Any] {
            dict[SIMS_GUID] = info.guid
            messageDict[messageType] = dict
        }
        guard let jsonMetadata = messageDict.JSONString else { throw DPAGErrorCreateMessage.err465 }
        guard signatures.signatureDict.JSONString != nil else { throw DPAGErrorCreateMessage.err465 }
        guard signatures.signatureDict256.JSONString != nil else { throw DPAGErrorCreateMessage.err465 }
        return jsonMetadata
    }
}
