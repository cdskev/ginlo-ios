//
//  DPAGMessageModelFactoryHelper.swift
//  SIMSmeCore
//
//  Created by RBU on 06.02.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import NSHash
import UIKit

struct DPAGEncryptionConfiguration {
    private init() {}

    static func signatures(accountCrypto: CryptoHelperSimple, config: DPAGEncryptionConfigurationPrivate, messageDataEncrypted: String, attachmentEncrypted: String?) throws -> DPAGMessageSignatures? {
        let sha1Attachment = attachmentEncrypted?.sha1()
        let sha256Attachment = attachmentEncrypted?.sha256()

        let hashes = config.hashes(encMessageData: messageDataEncrypted, encAttachment: sha1Attachment)
        let hashes256 = config.hashes256(encMessageData: messageDataEncrypted, encAttachment: sha256Attachment)
        let hashesTemp256 = config.hashesTemp256(encMessageData: messageDataEncrypted, encAttachment: sha256Attachment)

        let hashesValues = config.combineHashes(hashes: hashes)
        let hashesValues256 = config.combineHashes(hashes: hashes256)
        let hashesValuesTemp256 = config.combineHashes(hashes: hashesTemp256)

        let hashesSignature = try accountCrypto.signData(data: hashesValues)
        let hashesSignature256 = try accountCrypto.signData256(data: hashesValues256)
        let hashesSignatureTemp256 = try accountCrypto.signData256(data: hashesValuesTemp256)

        let signatureDict = self.signature(hashes, hashesSignature: hashesSignature)
        let signatureDict256 = self.signature256(hashes256, hashesSignature256: hashesSignature256)
        let signatureDictTemp256 = self.signature256(hashesTemp256, hashesSignature256: hashesSignatureTemp256)

        return DPAGMessageSignatures(signatureDict: signatureDict, signatureDict256: signatureDict256, signatureDictTemp256: signatureDictTemp256)
    }

    static func signatures(accountCrypto: CryptoHelperSimple, config: DPAGEncryptionConfigurationGroup, messageDataEncrypted: String, attachmentEncrypted: String?) throws -> DPAGMessageSignatures? {
        let sha1Attachment = attachmentEncrypted?.sha1()
        let sha256Attachment = attachmentEncrypted?.sha256()

        let hashes = config.hashes(encMessageData: messageDataEncrypted, encAttachment: sha1Attachment)
        let hashes256 = config.hashes256(encMessageData: messageDataEncrypted, encAttachment: sha256Attachment)
        let hashesTemp256 = config.hashesTemp256(encMessageData: messageDataEncrypted, encAttachment: sha256Attachment)

        var hashesValues = messageDataEncrypted.sha1()

        hashesValues += config.senderGuid.sha1()
        hashesValues += config.recipientGuid.sha1()

        if let sha1Attachment = sha1Attachment {
            hashesValues += sha1Attachment
        }

        var hashesValues256 = messageDataEncrypted.sha256()

        hashesValues256 += config.senderGuid.sha256()
        hashesValues256 += config.recipientGuid.sha256()

        if let sha256Attachment = sha256Attachment {
            hashesValues256 += sha256Attachment
        }
        let hashesValuesTemp256 = config.combineHashes(hashes: hashesTemp256)

        let hashesSignature = try accountCrypto.signData(data: hashesValues)
        let hashesSignature256 = try accountCrypto.signData256(data: hashesValues256)
        let hashesSignatureTemp256 = try accountCrypto.signData256(data: hashesValuesTemp256)

        let signatureDict = self.signature(hashes, hashesSignature: hashesSignature)
        let signatureDict256 = self.signature256(hashes256, hashesSignature256: hashesSignature256)
        let signatureDictTemp256 = self.signature256(hashesTemp256, hashesSignature256: hashesSignatureTemp256)

        return DPAGMessageSignatures(signatureDict: signatureDict, signatureDict256: signatureDict256, signatureDictTemp256: signatureDictTemp256)
    }

    static func signatures(accountCrypto: CryptoHelperSimple, config: DPAGEncryptionConfigurationPrivateInternal, messageDataEncrypted: String) throws -> DPAGMessageSignatures? {
        let hashes = config.hashes(encMessageData: messageDataEncrypted)
        let hashes256 = config.hashes256(encMessageData: messageDataEncrypted)
        let hashesTemp256 = config.hashesTemp256(encMessageData: messageDataEncrypted)

        let hashesValues = config.combineHashes(hashes: hashes)
        let hashesValues256 = config.combineHashes(hashes: hashes256)
        let hashesValuesTemp256 = config.combineHashes(hashes: hashesTemp256)

        let hashesSignature = try accountCrypto.signData(data: hashesValues)
        let hashesSignature256 = try accountCrypto.signData256(data: hashesValues256)
        let hashesSignatureTemp256 = try accountCrypto.signData256(data: hashesValuesTemp256)

        let signatureDict = self.signature(hashes, hashesSignature: hashesSignature)
        let signatureDict256 = self.signature(hashes256, hashesSignature: hashesSignature256)
        let signatureDictTemp256 = self.signature256(hashesTemp256, hashesSignature256: hashesSignatureTemp256)

        return DPAGMessageSignatures(signatureDict: signatureDict, signatureDict256: signatureDict256, signatureDictTemp256: signatureDictTemp256)
    }

    static func signatures(accountCrypto: CryptoHelperSimple, config: DPAGEncryptionConfigurationGroupInvitation, messageDataEncrypted: String) throws -> DPAGMessageSignatures? {
        let hashes = config.hashes(encMessageData: messageDataEncrypted)
        let hashes256 = config.hashes256(encMessageData: messageDataEncrypted)
        let hashesTemp256 = config.hashesTemp256(encMessageData: messageDataEncrypted)

        let hashesValues = config.combineHashes(hashes: hashes)
        let hashesValues256 = config.combineHashes(hashes: hashes256)
        let hashesValuesTemp256 = config.combineHashes(hashes: hashesTemp256)

        let hashesSignature = try accountCrypto.signData(data: hashesValues)
        let hashesSignature256 = try accountCrypto.signData256(data: hashesValues256)
        let hashesSignatureTemp256 = try accountCrypto.signData256(data: hashesValuesTemp256)

        let signatureDict = self.signature(hashes, hashesSignature: hashesSignature)
        let signatureDict256 = self.signature256(hashes256, hashesSignature256: hashesSignature256)
        let signatureDictTemp256 = self.signature256(hashesTemp256, hashesSignature256: hashesSignatureTemp256)

        return DPAGMessageSignatures(signatureDict: signatureDict, signatureDict256: signatureDict256, signatureDictTemp256: signatureDictTemp256)
    }

    private static func signature(_ hashes: [AnyHashable: Any], hashesSignature: String) -> [AnyHashable: Any] {
        let sigDict: [AnyHashable: Any] = [
            SIMS_HASHES: hashes,
            SIMS_SIGNATURE: hashesSignature
        ]
        return sigDict
    }

    private static func signature256(_ hashes256: [AnyHashable: Any], hashesSignature256: String) -> [AnyHashable: Any] {
        let sigDict: [AnyHashable: Any] = [
            SIMS_HASHES: hashes256,
            SIMS_SIGNATURE: hashesSignature256
        ]
        return sigDict
    }
}

class DPAGEncryptionConfigurationBase: NSObject {
    fileprivate struct MessageDictionaryInfo {
        let fromDict: [AnyHashable: Any]
        let toDict: Any
        let encMessageData: String
        let encAttachment: String?
        let signatures: DPAGMessageSignatures
        let messageType: String
        let contentType: String
        let sendOptions: DPAGSendMessageSendOptions?
        let featureSet: String?
        let nickname: String?
        let senderId: String?
        let additionalContentData: [AnyHashable: Any]
    }

    fileprivate func messageDictionary(info: MessageDictionaryInfo) -> [AnyHashable: Any] {
        var contentDict: [AnyHashable: Any] = [
            SIMS_FROM: info.fromDict,
            SIMS_TO: info.toDict,
            SIMS_DATA: info.encMessageData,
            SIMS_SIGNATURE: info.signatures.signatureDict,
            SIMS_SIGNATURE_256: info.signatures.signatureDict256,
            SIMS_SIGNATURE_TEMP_256: info.signatures.signatureDictTemp256
        ]

        if let featureSet = info.featureSet {
            contentDict[SIMS_FEATURES] = featureSet
        }

        if let encAttachment = info.encAttachment {
            contentDict[SIMS_ATTACHMENT] = [encAttachment]
        }

        var contentTypeSend = info.contentType

        if info.sendOptions?.countDownSelfDestruction != nil || info.sendOptions?.dateSelfDestruction != nil {
            contentTypeSend += DPAGStrings.JSON.Message.ContentType.SUFFIX_SELF_DESTRUCTIVE
        }
        if info.sendOptions?.messageGuidCitation != nil {
            contentTypeSend += DPAGStrings.JSON.Message.ContentType.SUFFIX_CITATION
        }
        contentDict[DPAGStrings.JSON.Message.TYPE] = contentTypeSend

        if let senderId = info.senderId {
            contentDict[DPAGStrings.JSON.Message.SENDER_ID] = senderId
        }

        if AppConfig.isShareExtension {
            contentDict[SIMS_DATESEND] = DPAGFormatter.dateServer.string(from: Date())
        }

        if info.sendOptions?.messagePriorityHigh ?? false {
            contentDict[DPAGStrings.JSON.Message.PRIORITY] = "high"
        }

        for (key, value) in info.additionalContentData {
            contentDict[key] = value
        }

        let messageDict = [
            info.messageType: contentDict
        ]
        return messageDict
    }
}

class DPAGEncryptionConfigurationGroup: DPAGEncryptionConfigurationBase {
    var senderGuid: String
    var recipientGuid: String

    var senderEncAesKey: String
    var senderSha1encAesKey: String
    var senderSha256encAesKey: String

    let senderTempDeviceGuid: String?
    let senderTempDeviceEncAesKey: String?
    let senderTempDeviceSha256encAesKey: String?

    init?(aesKeyXML: String, forGroup recipientGuid: String) throws {
        if AppConfig.isShareExtension {
            let cache = DPAGApplicationFacadeShareExt.cache

            guard let account = cache.account, let contact = cache.contact(for: account.guid), let accountPublicKey = contact.publicKey else {
                return nil
            }
            self.senderGuid = account.guid
            self.recipientGuid = recipientGuid

            self.senderEncAesKey = try CryptoHelperEncrypter.encrypt(string: aesKeyXML, withPublicKey: accountPublicKey)

            self.senderSha1encAesKey = self.senderEncAesKey.sha1()
            self.senderSha256encAesKey = self.senderEncAesKey.sha256()

            self.senderTempDeviceEncAesKey = nil
            self.senderTempDeviceSha256encAesKey = nil
            self.senderTempDeviceGuid = nil
        } else {
            let cache = DPAGApplicationFacade.cache

            guard let account = cache.account, let contact = cache.contact(for: account.guid), let accountPublicKey = contact.publicKey else {
                return nil
            }
            self.senderGuid = account.guid
            self.recipientGuid = recipientGuid

            self.senderEncAesKey = try CryptoHelperEncrypter.encrypt(string: aesKeyXML, withPublicKey: accountPublicKey)

            self.senderSha1encAesKey = self.senderEncAesKey.sha1()
            self.senderSha256encAesKey = self.senderEncAesKey.sha256()

            // Unterstuetzung TempDevice Empfaenger
            if let tempDevicePublicKey = DPAGApplicationFacade.cache.ownTempDevicePublicKey, let tempDeviceGuid = DPAGApplicationFacade.cache.ownTempDeviceGuid {
                let senderTempDeviceEncAesKey = try CryptoHelperEncrypter.encrypt(string: aesKeyXML, withPublicKey: tempDevicePublicKey)
                self.senderTempDeviceEncAesKey = senderTempDeviceEncAesKey
                self.senderTempDeviceSha256encAesKey = senderTempDeviceEncAesKey.sha256()
                self.senderTempDeviceGuid = tempDeviceGuid
            } else {
                self.senderTempDeviceEncAesKey = nil
                self.senderTempDeviceSha256encAesKey = nil
                self.senderTempDeviceGuid = nil
            }
        }

        super.init()
    }

    func hashes(encMessageData: String, encAttachment sha1Attachment: String?) -> [AnyHashable: Any] {
        var hashes = self.getSignatureHashesSha1()

        hashes[SIMS_DATA] = encMessageData.sha1()

        if let sha1Attachment = sha1Attachment {
            hashes["attachment/0"] = sha1Attachment
        }

        return hashes
    }

    func hashes256(encMessageData: String, encAttachment sha256Attachment: String?) -> [AnyHashable: Any] {
        var hashes = self.getSignatureHashesSha256()

        hashes[SIMS_DATA] = encMessageData.sha256()

        if let sha256Attachment = sha256Attachment {
            hashes["attachment/0"] = sha256Attachment
        }
        return hashes
    }

    func hashesTemp256(encMessageData: String, encAttachment sha256Attachment: String?) -> [AnyHashable: Any] {
        var hashes = self.getSignatureHashesTemp256()

        hashes[SIMS_DATA] = encMessageData.sha256()

        if let sha256Attachment = sha256Attachment {
            hashes["attachment/0"] = sha256Attachment
        }
        return hashes
    }

    func getSignatureHashesSha1() -> [AnyHashable: Any] {
        let hashes = [
            "from/" + self.senderGuid: self.senderGuid.sha1(),
            "to/" + self.recipientGuid: self.recipientGuid.sha1()
        ]
        return hashes
    }

    func getSignatureHashesSha256() -> [AnyHashable: Any] {
        let hashes = [
            "from/" + self.senderGuid: self.senderGuid.sha256(),
            "to/" + self.recipientGuid: self.recipientGuid.sha256()
        ]
        return hashes
    }

    func getSignatureHashesTemp256() -> [AnyHashable: Any] {
        var hashes = self.getSignatureHashesSha256()

        if let senderTempDeviceGuid = self.senderTempDeviceGuid, let senderTempDeviceSha256encAesKey = self.senderTempDeviceSha256encAesKey {
            hashes["to/" + self.recipientGuid + "/tempDevice/guid"] = senderTempDeviceGuid.sha256()
            hashes["to/" + self.recipientGuid + "/tempDevice/key"] = senderTempDeviceSha256encAesKey
        }
        return hashes
    }

    func getSenderDict(nicknameEncoded: String?) -> [AnyHashable: Any] {
        if self.senderTempDeviceGuid != nil {
            if let nickEncoded = nicknameEncoded {
                let rc = [
                    self.senderGuid: [
                        SIMS_KEY: self.senderEncAesKey,
                        SIMS_NICKNAME: nickEncoded,
                        SIMS_TEMP_DEVICE:
                            [
                                SIMS_GUID: self.senderTempDeviceGuid,
                                SIMS_KEY: self.senderTempDeviceEncAesKey
                            ]
                    ]
                ]
                return rc
            } else {
                let rc = [
                    self.senderGuid: [
                        SIMS_KEY: self.senderEncAesKey,
                        SIMS_TEMP_DEVICE:
                            [
                                SIMS_GUID: self.senderTempDeviceGuid,
                                SIMS_KEY: self.senderTempDeviceEncAesKey
                            ]
                    ]
                ]
                return rc
            }
        } else {
            if let nickEncoded = nicknameEncoded {
                let rc = [
                    self.senderGuid: [
                        SIMS_KEY: self.senderEncAesKey,
                        SIMS_NICKNAME: nickEncoded
                    ]
                ]
                return rc
            } else {
                let rc = [
                    self.senderGuid: [
                        SIMS_KEY: self.senderEncAesKey
                    ]
                ]
                return rc
            }
        }
    }

    func combineHashes(hashes: [AnyHashable: Any]) -> String {
        var hashesValues = ""

        let keys = ["data", "from/" + self.senderGuid, "from/" + self.senderGuid + "/key", "to/" + self.recipientGuid, "to/" + self.recipientGuid + "/key", "attachment/0", "to/" + self.recipientGuid + "/tempDevice/guid", "to/" + self.recipientGuid + "/tempDevice/key"]

        for key in keys {
            if let value = hashes[key] as? String {
                hashesValues += value
            }
        }
        return hashesValues
    }

    struct MessageDictionaryInfoGroup {
        let encMessageData: String
        let encAttachment: String?
        let signatures: DPAGMessageSignatures
        let messageType: String
        let contentType: String
        let sendOptions: DPAGSendMessageSendOptions?
        let featureSet: String?
        let nickname: String?
        let senderId: String?
    }

    func messageDictionary(info: MessageDictionaryInfoGroup) -> [AnyHashable: Any] {
        var nickEncoded: String?

        if AppConfig.isShareExtension {
            let preferences = DPAGApplicationFacadeShareExt.preferences

            if preferences.sendNickname, info.nickname != nil {
                nickEncoded = info.nickname?.data(using: .utf8)?.base64EncodedString(options: .lineLength76Characters)
            }
        } else {
            let preferences = DPAGApplicationFacade.preferences

            if preferences.sendNickname, info.nickname != nil {
                nickEncoded = info.nickname?.data(using: .utf8)?.base64EncodedString(options: .lineLength76Characters)
            }
        }

        let fromDict = self.getSenderDict(nicknameEncoded: nickEncoded)

        let toDict = self.recipientGuid

        return self.messageDictionary(info: MessageDictionaryInfo(fromDict: fromDict, toDict: toDict, encMessageData: info.encMessageData, encAttachment: info.encAttachment, signatures: info.signatures, messageType: info.messageType, contentType: info.contentType, sendOptions: info.sendOptions, featureSet: info.featureSet, nickname: info.nickname, senderId: info.senderId, additionalContentData: [:]))
    }
}

class DPAGEncryptionConfigurationPrivate: DPAGEncryptionConfigurationBase {
    let senderGuid: String
    let recipientGuid: String

    let recipientEncAesKey: String
    let recipientEncAesKey2: String
    let recipientSha1encAesKey: String
    let recipientSha256encAesKey: String

    let senderEncAesKey: String
    let senderEncAesKey2: String
    let senderSha1encAesKey: String
    let senderSha256encAesKey: String

    let aesKey: String
    let aesKeyIV: String
    let aesKeyXML: String

    let recipientTempDeviceGuid: String?
    let recipientTempDeviceEncAesKey: String?
    let recipientTempDeviceEncAesKey2: String?
    let recipientTempDeviceSha256encAesKey: String?

    let senderTempDeviceGuid: String?
    let senderTempDeviceEncAesKey: String?
    let senderTempDeviceEncAesKey2: String?
    let senderTempDeviceSha256encAesKey: String?

    init?(forRecipient recipient: DPAGSendMessageRecipient, cachedAesKeys: DPAGContactAesKeys, recipientPublicKey: String, withIV iv: String?) throws {
        let recipientGuid = recipient.recipientGuid

        if AppConfig.isShareExtension {
            let cache = DPAGApplicationFacadeShareExt.cache

            guard let account = cache.account, let contact = cache.contact(for: account.guid), let accountPublicKey = contact.publicKey else {
                return nil
            }

            let ivNew = iv ?? DPAGHelperEx.iv128Bit().base64EncodedString()

            self.aesKeyIV = ivNew
            self.aesKey = cachedAesKeys.aesKey

            self.senderGuid = account.guid
            self.recipientGuid = recipientGuid

            let aesKeyDict = ["key": cachedAesKeys.aesKey, "iv": ivNew, "timestamp": CryptoHelper.newDateInDLFormat()]
            let aesKeyXML = XMLWriter.xmlString(from: aesKeyDict)

            self.aesKeyXML = aesKeyXML

            self.recipientEncAesKey = try CryptoHelperEncrypter.encrypt(string: aesKeyXML, withPublicKey: recipientPublicKey)
            self.recipientEncAesKey2 = cachedAesKeys.recipientEncAesKey

            self.senderEncAesKey = try CryptoHelperEncrypter.encrypt(string: aesKeyXML, withPublicKey: accountPublicKey)
            self.senderEncAesKey2 = cachedAesKeys.senderEncAesKey

            self.senderTempDeviceEncAesKey = nil
            self.senderTempDeviceEncAesKey2 = nil
            self.senderTempDeviceSha256encAesKey = nil
            self.senderTempDeviceGuid = nil
        } else {
            let cache = DPAGApplicationFacade.cache

            guard let account = cache.account, let contact = cache.contact(for: account.guid), let accountPublicKey = contact.publicKey else {
                return nil
            }

            let ivNew = iv ?? DPAGHelperEx.iv128Bit().base64EncodedString()

            self.aesKeyIV = ivNew
            self.aesKey = cachedAesKeys.aesKey

            self.senderGuid = account.guid
            self.recipientGuid = recipientGuid

            let aesKeyDict = ["key": cachedAesKeys.aesKey, "iv": ivNew, "timestamp": CryptoHelper.newDateInDLFormat()]
            let aesKeyXML = XMLWriter.xmlString(from: aesKeyDict)

            self.aesKeyXML = aesKeyXML

            self.recipientEncAesKey = try CryptoHelperEncrypter.encrypt(string: aesKeyXML, withPublicKey: recipientPublicKey)
            self.recipientEncAesKey2 = cachedAesKeys.recipientEncAesKey

            self.senderEncAesKey = try CryptoHelperEncrypter.encrypt(string: aesKeyXML, withPublicKey: accountPublicKey)
            self.senderEncAesKey2 = cachedAesKeys.senderEncAesKey

            // TODO: Unterstützung tempdevice sender
            // Unterstuetzung TempDevice Empfaenger
            if let tempDevicePublicKey = DPAGApplicationFacade.cache.ownTempDevicePublicKey, let tempDeviceGuid = DPAGApplicationFacade.cache.ownTempDeviceGuid {
                let senderTempDeviceEncAesKey = try CryptoHelperEncrypter.encrypt(string: aesKeyXML, withPublicKey: tempDevicePublicKey)

                self.senderTempDeviceEncAesKey = senderTempDeviceEncAesKey
                self.senderTempDeviceEncAesKey2 = try CryptoHelperEncrypter.encrypt(string: self.aesKey, withPublicKey: tempDevicePublicKey)
                self.senderTempDeviceSha256encAesKey = senderTempDeviceEncAesKey.sha256()
                self.senderTempDeviceGuid = tempDeviceGuid
            } else {
                self.senderTempDeviceEncAesKey = nil
                self.senderTempDeviceEncAesKey2 = nil
                self.senderTempDeviceSha256encAesKey = nil
                self.senderTempDeviceGuid = nil
            }
        }

        self.senderSha1encAesKey = self.senderEncAesKey.sha1()
        self.senderSha256encAesKey = self.senderEncAesKey.sha256()

        self.recipientSha1encAesKey = self.recipientEncAesKey.sha1()
        self.recipientSha256encAesKey = self.recipientEncAesKey.sha256()

        // Unterstuetzung TempDevice Empfaenger
        if let tempDevicePublicKey = recipient.tempDevicePublicKey {
            let recipientTempDeviceEncAesKey = try CryptoHelperEncrypter.encrypt(string: aesKeyXML, withPublicKey: tempDevicePublicKey)

            self.recipientTempDeviceEncAesKey = recipientTempDeviceEncAesKey
            self.recipientTempDeviceEncAesKey2 = try CryptoHelperEncrypter.encrypt(string: self.aesKey, withPublicKey: tempDevicePublicKey)
            self.recipientTempDeviceSha256encAesKey = recipientTempDeviceEncAesKey.sha256()
            self.recipientTempDeviceGuid = recipient.tempDeviceGuid
        } else {
            self.recipientTempDeviceEncAesKey = nil
            self.recipientTempDeviceEncAesKey2 = nil
            self.recipientTempDeviceSha256encAesKey = nil
            self.recipientTempDeviceGuid = nil
        }

        super.init()
    }

    func hashes(encMessageData: String, encAttachment sha1Attachment: String?) -> [AnyHashable: Any] {
        var hashes = self.getSignatureHashesSha1()

        hashes[SIMS_DATA] = encMessageData.sha1()

        if let sha1Attachment = sha1Attachment {
            hashes["attachment/0"] = sha1Attachment
        }

        return hashes
    }

    func hashes256(encMessageData: String, encAttachment sha256Attachment: String?) -> [AnyHashable: Any] {
        var hashes = self.getSignatureHashesSha256()

        hashes[SIMS_DATA] = encMessageData.sha256()

        if let sha256Attachment = sha256Attachment {
            hashes["attachment/0"] = sha256Attachment
        }
        return hashes
    }

    func hashesTemp256(encMessageData: String, encAttachment sha256Attachment: String?) -> [AnyHashable: Any] {
        var hashes = self.getSignatureHashesTemp256()

        hashes[SIMS_DATA] = encMessageData.sha256()

        if let sha256Attachment = sha256Attachment {
            hashes["attachment/0"] = sha256Attachment
        }
        return hashes
    }

    func getRecipientDict() -> [AnyHashable: Any] {
        if self.recipientTempDeviceGuid != nil {
            return [
                self.recipientGuid: [
                    SIMS_KEY: self.recipientEncAesKey,
                    SIMS_KEY_2: self.recipientEncAesKey2,
                    SIMS_TEMP_DEVICE: [
                        SIMS_GUID: self.recipientTempDeviceGuid,
                        SIMS_KEY: self.recipientTempDeviceEncAesKey,
                        SIMS_KEY_2: self.recipientTempDeviceEncAesKey2
                    ]
                ]
            ]
        } else {
            return [
                self.recipientGuid: [
                    SIMS_KEY: self.recipientEncAesKey,
                    SIMS_KEY_2: self.recipientEncAesKey2
                ]
            ]
        }
    }

    func getSenderDict(nicknameEncoded: String?) -> [AnyHashable: Any] {
        if self.senderTempDeviceGuid != nil {
            if let nickEncoded = nicknameEncoded {
                return [
                    self.senderGuid: [
                        SIMS_KEY: self.senderEncAesKey,
                        SIMS_KEY_2: self.senderEncAesKey2,
                        SIMS_NICKNAME: nickEncoded,
                        SIMS_TEMP_DEVICE: [
                            SIMS_GUID: self.senderTempDeviceGuid,
                            SIMS_KEY: self.senderTempDeviceEncAesKey,
                            SIMS_KEY_2: self.senderTempDeviceEncAesKey2
                        ]
                    ]
                ]
            } else {
                return [
                    self.senderGuid: [
                        SIMS_KEY: self.senderEncAesKey,
                        SIMS_KEY_2: self.senderEncAesKey2,
                        SIMS_TEMP_DEVICE: [
                            SIMS_GUID: self.senderTempDeviceGuid,
                            SIMS_KEY: self.senderTempDeviceEncAesKey,
                            SIMS_KEY_2: self.senderTempDeviceEncAesKey2
                        ]
                    ]
                ]
            }
        } else {
            if let nickEncoded = nicknameEncoded {
                return [
                    self.senderGuid: [
                        SIMS_KEY: self.senderEncAesKey,
                        SIMS_KEY_2: self.senderEncAesKey2,
                        SIMS_NICKNAME: nickEncoded
                    ]
                ]
            } else {
                return [
                    self.senderGuid: [
                        SIMS_KEY: self.senderEncAesKey,
                        SIMS_KEY_2: self.senderEncAesKey2
                    ]
                ]
            }
        }
    }

    func getSignatureHashesSha1() -> [AnyHashable: Any] {
        let hashes = [
            "from/" + self.senderGuid: self.senderGuid.sha1(),
            "from/" + self.senderGuid + "/key": self.senderSha1encAesKey,
            "to/" + self.recipientGuid: self.recipientGuid.sha1(),
            "to/" + self.recipientGuid + "/key": self.recipientSha1encAesKey
        ]
        return hashes
    }

    func getSignatureHashesSha256() -> [AnyHashable: Any] {
        let hashes = [
            "from/" + self.senderGuid: self.senderGuid.sha256(),
            "from/" + self.senderGuid + "/key": self.senderSha256encAesKey,
            "to/" + self.recipientGuid: self.recipientGuid.sha256(),
            "to/" + self.recipientGuid + "/key": self.recipientSha256encAesKey
        ]
        return hashes
    }

    func getSignatureHashesTemp256() -> [AnyHashable: Any] {
        var hashes = self.getSignatureHashesSha256()

        // Unterstützung tempdevice recipient
        if let recipientTempDeviceGuid = self.recipientTempDeviceGuid, let recipientTempDeviceSha256encAesKey = self.recipientTempDeviceSha256encAesKey {
            hashes["to/" + self.recipientGuid + "/tempDevice/guid"] = recipientTempDeviceGuid.sha256()
            hashes["to/" + self.recipientGuid + "/tempDevice/key"] = recipientTempDeviceSha256encAesKey
        }
        // TUnterstützung tempdevice sender
        if let senderTempDeviceGuid = self.senderTempDeviceGuid, let senderTempDeviceSha256encAesKey = self.senderTempDeviceSha256encAesKey {
            hashes["from/" + self.senderGuid + "/tempDevice/guid"] = senderTempDeviceGuid.sha256()
            hashes["from/" + self.senderGuid + "/tempDevice/key"] = senderTempDeviceSha256encAesKey
        }
        return hashes
    }

    func combineHashes(hashes: [AnyHashable: Any]) -> String {
        var hashesValues = ""

        let keys = ["data", "from/" + self.senderGuid, "from/" + self.senderGuid + "/key", "from/" + self.senderGuid + "/tempDevice/guid", "from/" + self.senderGuid + "/tempDevice/key", "to/" + self.recipientGuid, "to/" + self.recipientGuid + "/key", "to/" + self.recipientGuid + "/tempDevice/guid", "to/" + self.recipientGuid + "/tempDevice/key", "attachment/0"]

        for key in keys {
            if let value = hashes[key] as? String {
                hashesValues += value
            }
        }
        return hashesValues
    }

    struct MessageDictionaryInfoPrivate {
        let encMessageData: String
        let encAttachment: String?
        let signatures: DPAGMessageSignatures
        let messageType: String
        let contentType: String
        let sendOptions: DPAGSendMessageSendOptions?
        let featureSet: String?
        let nickname: String?
        let senderId: String?
    }

    func messageDictionary(info: MessageDictionaryInfoPrivate) -> [AnyHashable: Any] {
        var nickEncoded: String?

        if AppConfig.isShareExtension {
            let preferences = DPAGApplicationFacadeShareExt.preferences

            if preferences.sendNickname, info.nickname != nil {
                nickEncoded = info.nickname?.data(using: .utf8)?.base64EncodedString(options: .lineLength76Characters)
            }
        } else {
            let preferences = DPAGApplicationFacade.preferences

            if preferences.sendNickname, info.nickname != nil {
                nickEncoded = info.nickname?.data(using: .utf8)?.base64EncodedString(options: .lineLength76Characters)
            }
        }

        let fromDict = self.getSenderDict(nicknameEncoded: nickEncoded)

        let toDict = [
            self.getRecipientDict()
        ]

        return self.messageDictionary(info: MessageDictionaryInfo(fromDict: fromDict, toDict: toDict, encMessageData: info.encMessageData, encAttachment: info.encAttachment, signatures: info.signatures, messageType: info.messageType, contentType: info.contentType, sendOptions: info.sendOptions, featureSet: info.featureSet, nickname: info.nickname, senderId: info.senderId, additionalContentData: [SIMS_KEY_2_IV: self.aesKeyIV]))
    }
}

class DPAGEncryptionConfigurationInternal: DPAGEncryptionConfigurationBase {
    let senderGuid: String
    let recipientGuid: String

    let recipientEncAesKey: String
    let recipientSha1encAesKey: String
    let recipientSha256encAesKey: String

    let senderEncAesKey: String
    let senderSha1encAesKey: String
    let senderSha256encAesKey: String

    let aesKeyXML: String

    let senderTempDeviceGuid: String?
    let senderTempDeviceEncAesKey: String?
    let senderTempDeviceSha256encAesKey: String?

    init?(aesKeyXML: String, forRecipient recipientGuid: String, recipientPublicKey: String) throws {
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let accountPublicKey = contact.publicKey else {
            return nil
        }

        self.senderGuid = account.guid
        self.recipientGuid = recipientGuid

        self.aesKeyXML = aesKeyXML

        self.recipientEncAesKey = try CryptoHelperEncrypter.encrypt(string: aesKeyXML, withPublicKey: recipientPublicKey)

        self.senderEncAesKey = try CryptoHelperEncrypter.encrypt(string: aesKeyXML, withPublicKey: accountPublicKey)

        self.senderSha1encAesKey = self.senderEncAesKey.sha1()
        self.senderSha256encAesKey = self.senderEncAesKey.sha256()

        self.recipientSha1encAesKey = self.recipientEncAesKey.sha1()
        self.recipientSha256encAesKey = self.recipientEncAesKey.sha256()

        self.senderTempDeviceEncAesKey = nil
        self.senderTempDeviceSha256encAesKey = nil
        self.senderTempDeviceGuid = nil

        super.init()
    }

    init?(aesKeyXML: String) throws {
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let accountPublicKey = contact.publicKey else {
            return nil
        }

        let recipientGuid = account.guid
        let recipientPublicKey = accountPublicKey

        self.senderGuid = account.guid
        self.recipientGuid = recipientGuid

        self.aesKeyXML = aesKeyXML

        self.recipientEncAesKey = try CryptoHelperEncrypter.encrypt(string: aesKeyXML, withPublicKey: recipientPublicKey)

        self.senderEncAesKey = try CryptoHelperEncrypter.encrypt(string: aesKeyXML, withPublicKey: accountPublicKey)

        self.senderSha1encAesKey = self.senderEncAesKey.sha1()
        self.senderSha256encAesKey = self.senderEncAesKey.sha256()

        self.recipientSha1encAesKey = self.recipientEncAesKey.sha1()
        self.recipientSha256encAesKey = self.recipientEncAesKey.sha256()

        if AppConfig.isShareExtension {
            self.senderTempDeviceEncAesKey = nil
            self.senderTempDeviceSha256encAesKey = nil
            self.senderTempDeviceGuid = nil
        } else {
            if let tempDevicePublicKey = DPAGApplicationFacade.cache.ownTempDevicePublicKey, let tempDeviceGuid = DPAGApplicationFacade.cache.ownTempDeviceGuid {
                let senderTempDeviceEncAesKey = try CryptoHelperEncrypter.encrypt(string: aesKeyXML, withPublicKey: tempDevicePublicKey)

                self.senderTempDeviceEncAesKey = senderTempDeviceEncAesKey
                self.senderTempDeviceSha256encAesKey = senderTempDeviceEncAesKey.sha256()
                self.senderTempDeviceGuid = tempDeviceGuid
            } else {
                self.senderTempDeviceEncAesKey = nil
                self.senderTempDeviceSha256encAesKey = nil
                self.senderTempDeviceGuid = nil
            }
        }

        super.init()
    }

    func combineHashes(hashes: [AnyHashable: Any]) -> String {
        var hashesValues = ""

        let keys = ["data", "from/" + self.senderGuid, "from/" + self.senderGuid + "/key", "from/" + self.senderGuid + "/tempDevice/guid", "from/" + self.senderGuid + "/tempDevice/key", "to/" + self.recipientGuid, "to/" + self.recipientGuid + "/key", "to/" + self.recipientGuid + "/tempDevice/guid", "to/" + self.recipientGuid + "/tempDevice/key"]

        for key in keys {
            if let value = hashes[key] as? String {
                hashesValues += value
            }
        }
        return hashesValues
    }

    func hashes(encMessageData: String) -> [AnyHashable: Any] {
        let hashes = [
            SIMS_DATA: encMessageData.sha1(),
            "from/" + self.senderGuid: self.senderGuid.sha1(),
            "from/" + self.senderGuid + "/key": self.senderSha1encAesKey,
            "to/" + self.recipientGuid: self.recipientGuid.sha1(),
            "to/" + self.recipientGuid + "/key": self.recipientSha1encAesKey
        ]

        return hashes
    }

    func hashes256(encMessageData: String) -> [AnyHashable: Any] {
        let hashes = [
            SIMS_DATA: encMessageData.sha256(),
            "from/" + self.senderGuid: self.senderGuid.sha256(),
            "from/" + self.senderGuid + "/key": self.senderSha256encAesKey,
            "to/" + self.recipientGuid: self.recipientGuid.sha256(),
            "to/" + self.recipientGuid + "/key": self.recipientSha256encAesKey
        ]

        return hashes
    }

    func hashesTemp256(encMessageData: String) -> [AnyHashable: Any] {
        var hashes = self.hashes256(encMessageData: encMessageData)

        // Unterstützung tempdevice sender
        if let senderTempDeviceGuid = self.senderTempDeviceGuid, let senderTempDeviceSha256encAesKey = self.senderTempDeviceSha256encAesKey {
            hashes["from/" + self.senderGuid + "/tempDevice/guid"] = senderTempDeviceGuid.sha256()
            hashes["from/" + self.senderGuid + "/tempDevice/key"] = senderTempDeviceSha256encAesKey
        }

        return hashes
    }

    struct MessageDictionaryInfoInternal {
        let encMessageData: String
        let signatures: DPAGMessageSignatures
        let messageType: String
        let contentType: String
        let nickname: String?
        let senderId: String?
    }

    fileprivate func internalMessageDictionary(info: MessageDictionaryInfoInternal) -> [AnyHashable: Any] {
        var fromDict: [AnyHashable: Any] = [
            self.senderGuid: [
                SIMS_KEY: self.senderEncAesKey
            ]
        ]

        if DPAGApplicationFacade.preferences.sendNickname, info.nickname != nil, let nickEncoded = info.nickname?.data(using: .utf8)?.base64EncodedString(options: .lineLength76Characters) {
            fromDict = [
                self.senderGuid: [
                    SIMS_KEY: self.senderEncAesKey,
                    SIMS_NICKNAME: nickEncoded
                ]
            ]
        }

        let toDict: [[AnyHashable: Any]]

        if let senderTempDeviceGuid = self.senderTempDeviceGuid, let senderTempDeviceEncAesKey = self.senderTempDeviceEncAesKey {
            toDict = [
                [
                    self.recipientGuid: [
                        SIMS_KEY: self.recipientEncAesKey,
                        SIMS_TEMP_DEVICE: [
                            SIMS_GUID: senderTempDeviceGuid,
                            SIMS_KEY: senderTempDeviceEncAesKey
                        ]
                    ]
                ]
            ]
        } else {
            toDict = [
                [
                    self.recipientGuid: [
                        SIMS_KEY: self.recipientEncAesKey
                    ]
                ]
            ]
        }

        return self.messageDictionary(info: MessageDictionaryInfo(fromDict: fromDict, toDict: toDict, encMessageData: info.encMessageData, encAttachment: nil, signatures: info.signatures, messageType: info.messageType, contentType: info.contentType, sendOptions: nil, featureSet: nil, nickname: info.nickname, senderId: info.senderId, additionalContentData: [:]))
    }
}

class DPAGEncryptionConfigurationPrivateInternal: DPAGEncryptionConfigurationInternal {
    func messageDictionary(info: MessageDictionaryInfoInternal) -> [AnyHashable: Any] {
        self.internalMessageDictionary(info: info)
    }
}

class DPAGEncryptionConfigurationGroupInvitation: DPAGEncryptionConfigurationInternal {
    func messageDictionary(info: MessageDictionaryInfoInternal) -> [AnyHashable: Any] {
        self.internalMessageDictionary(info: info)
    }
}

public class DPAGMessageRecipient {
    public let contactGuid: String
    public var sendsReadConfirmation: Bool
    public var dateRead: Date?
    public var dateDownloaded: Date?

    public var contact: DPAGContact?

    init(contactGuid: String, sendsReadConfirmation: Bool, dateRead: Date?, dateDownloaded: Date?) {
        self.contactGuid = contactGuid
        self.sendsReadConfirmation = sendsReadConfirmation

        self.dateRead = dateRead
        self.dateDownloaded = dateDownloaded
    }
}

struct DPAGMessageSignatures {
    let signatureDict: [AnyHashable: Any]
    let signatureDict256: [AnyHashable: Any]
    let signatureDictTemp256: [AnyHashable: Any]

    init(signatureDict: [AnyHashable: Any], signatureDict256: [AnyHashable: Any], signatureDictTemp256: [AnyHashable: Any]) {
        self.signatureDict = signatureDict
        self.signatureDict256 = signatureDict256
        self.signatureDictTemp256 = signatureDictTemp256
    }
}
