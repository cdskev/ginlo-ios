//
//  DPAGSendMessageWorkerShareExt.swift
//  SIMSmeShareExtensionBase
//
//  Created by RBU on 06.08.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import ImageIO
import UIKit

public struct DPAGShareExtSendingConfig {
    public let httpUsername: String
    public let httpPassword: String

    public init(httpUsername: String, httpPassword: String) {
        self.httpUsername = httpUsername
        self.httpPassword = httpPassword
    }
}

public protocol DPAGSendMessageOptionsShareExt {}

public struct DPAGSendMessageOptionsShareExtGroup: DPAGSendMessageOptionsShareExt {
    public let accountCrypto: CryptoHelperSimple
    public let aesKey: String

    public init(accountCrypto: CryptoHelperSimple, aesKey: String) {
        self.accountCrypto = accountCrypto
        self.aesKey = aesKey
    }
}

public struct DPAGSendMessageOptionsShareExtSingle: DPAGSendMessageOptionsShareExt {
    public let accountCrypto: CryptoHelperSimple
    public let recipientPublicKey: String
    public let cachedAesKeys: DPAGContactAesKeys

    public init(accountCrypto: CryptoHelperSimple, recipientPublicKey: String, cachedAesKeys: DPAGContactAesKeys) {
        self.accountCrypto = accountCrypto
        self.recipientPublicKey = recipientPublicKey
        self.cachedAesKeys = cachedAesKeys
    }
}

public protocol DPAGSendMessageWorkerShareExtProtocol: AnyObject {
    func sendText(_ text: String, toRecipients recipients: [DPAGSendMessageRecipient], sendMessageOptionsShareExt: DPAGSendMessageOptionsShareExt, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig)
    func sendMedias(_ medias: [DPAGMediaResource], sendMessageOptionsShareExt: DPAGSendMessageOptionsShareExt, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, toRecipients recipients: [DPAGSendMessageRecipient], config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig)
    func sendFiles(_ filesUrls: [URL], sendMessageOptionsShareExt: DPAGSendMessageOptionsShareExt, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, toRecipients recipients: [DPAGSendMessageRecipient], config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig)
}

class DPAGSendMessageWorkerShareExt: NSObject, DPAGSendMessageWorkerShareExtProtocol {
    static let sharedInstance = DPAGSendMessageWorkerShareExt()

    public func sendText(_ text: String, toRecipients recipients: [DPAGSendMessageRecipient], sendMessageOptionsShareExt: DPAGSendMessageOptionsShareExt, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig) {
        self.sendMessage([text], recipients: recipients, sendMessageOptionsShareExt: sendMessageOptionsShareExt, sendMessageOptions: sendOptions, featureSet: nil, sendMessageInfoBlock: { (contentObject) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) in
            DPAGSendMessageInfo.loadText(contentObject)
        }, config: config, configSending: configSending)
    }

    public func sendMedias(_ medias: [DPAGMediaResource], sendMessageOptionsShareExt: DPAGSendMessageOptionsShareExt, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, toRecipients recipients: [DPAGSendMessageRecipient], config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig) {
        self.sendMessage(medias, recipients: recipients, sendMessageOptionsShareExt: sendMessageOptionsShareExt, sendMessageOptions: sendOptions, featureSet: "\(DPAGMessageFeatureVersion.file.rawValue)", sendMessageInfoBlock: { (contentObject) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) in
            DPAGSendMessageInfo.loadMedia(contentObject)
        }, config: config, configSending: configSending)
    }
    
    func sendFiles(_ filesUrls: [URL], sendMessageOptionsShareExt: DPAGSendMessageOptionsShareExt, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, toRecipients recipients: [DPAGSendMessageRecipient], config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig) {
        self.sendMessage(filesUrls, recipients: recipients, sendMessageOptionsShareExt: sendMessageOptionsShareExt, sendMessageOptions: sendOptions, featureSet: "\(DPAGMessageFeatureVersion.file.rawValue)", sendMessageInfoBlock: { (contentObject) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) in
            DPAGSendMessageInfo.loadFile(contentObject)
        }, config: config, configSending: configSending)
    }

    private func sendMessage(_ contents: [Any], recipients: [DPAGSendMessageRecipient], sendMessageOptionsShareExt: DPAGSendMessageOptionsShareExt, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, featureSet: String?, sendMessageInfoBlock: (_ contentObject: Any) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?), config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig) {
        for contentObject in contents {
            autoreleasepool { [weak self] in
                let sendOptionsRecipients = sendOptions?.copy() as? DPAGSendMessageSendOptions
                let sendMessageInfoResult = sendMessageInfoBlock(contentObject)
                if let errorMessage = sendMessageInfoResult.errorMessage {
                    DPAGLog(errorMessage)
                    return
                }
                for recipient in recipients {
                    autoreleasepool {
                        let isGroup = recipient.isGroup
                        guard let sendMessageInfo = sendMessageInfoResult.sendMessageInfo else { return }
                        let msgInstance = DPAGSendMessageWorkerInstance(receiver: recipient, text: sendMessageInfo.content, contentType: sendMessageInfo.contentType, messageType: isGroup ? .group : .private, streamGuid: isGroup ? recipient.recipientGuid : recipient.contact?.streamGuid)
                        msgInstance.messageDesc = sendMessageInfo.contentDesc
                        msgInstance.sendMessageOptions = sendOptionsRecipients?.copy() as? DPAGSendMessageSendOptions
                        msgInstance.featureSet = featureSet
                        msgInstance.additionalContentData = sendMessageInfo.additionalContentData
                        do {
                            if isGroup, let shareSendOptions = sendMessageOptionsShareExt as? DPAGSendMessageOptionsShareExtGroup {
                                try self?.createOutgoingGroupMessageWithInstance(msgInstance, groupGuid: recipient.recipientGuid, aesKey: shareSendOptions.aesKey, accountCrypto: shareSendOptions.accountCrypto, attachment: sendMessageInfo.attachment)
                            } else if let shareSendOptions = sendMessageOptionsShareExt as? DPAGSendMessageOptionsShareExtSingle {
                                try self?.createOutgoingPrivateMessageWithInstance(msgInstance, recipientPublicKey: shareSendOptions.recipientPublicKey, cachedAesKeys: shareSendOptions.cachedAesKeys, accountCrypto: shareSendOptions.accountCrypto, attachment: sendMessageInfo.attachment)
                            }
                        } catch DPAGErrorCreateMessage.err465 {
                            DPAGLog("internal.error.465")
                            return
                        } catch {
                            DPAGLog(error)
                        }
                        if msgInstance.guidOutgoingMessage == nil {
                            DPAGLog("service.tryAgainLater")
                            return
                        }
                        sendOptionsRecipients?.attachmentIsInternalCopy = true
                        DPAGLog("sending")
                        if msgInstance.messageType == .private {
                            self?.sendPrivateMessage(msgInstance: msgInstance, config: config, configSending: configSending)
                        } else {
                            self?.sendGroupMessage(msgInstance: msgInstance, config: config, configSending: configSending)
                        }
                    }
                }
            }
        }
    }

    private func createOutgoingGroupMessageWithInstance(_ msgInstance: DPAGSendMessageWorkerInstance, groupGuid: String, aesKey: String, accountCrypto: CryptoHelperSimple, attachment: Data?) throws {
        var errorCreate: DPAGErrorCreateMessage?

        let senderId = DPAGFunctionsGlobal.uuid(prefix: .temp)

        do {
            msgInstance.messageJson = try DPAGApplicationFacadeShareExt.messageFactory.groupMessage(info: DPAGMessageModelFactoryShareExt.MessageGroupInfo(guid: nil, senderId: senderId, text: msgInstance.messageText, desc: msgInstance.messageDesc, sendOptions: msgInstance.sendMessageOptions, aesKey: aesKey, groupGuid: groupGuid, contentType: msgInstance.contentType, attachment: attachment, featureSet: msgInstance.featureSet, additionalContentData: msgInstance.additionalContentData, accountCrypto: accountCrypto))
        } catch let err as DPAGErrorCreateMessage {
            errorCreate = err
            return
        } catch { return }

        if msgInstance.messageJson == nil {
            // The message was not properly configured, we risk trying to save an inconsistent context
            msgInstance.guidOutgoingMessage = nil

            return
        }

        msgInstance.sendConcurrent = (attachment?.count ?? 0) > 4_000

        msgInstance.messageType = .group

        if let errorCreate = errorCreate {
            throw errorCreate
        }

        msgInstance.guidOutgoingMessage = DPAGFunctionsGlobal.uuid(prefix: .temp) // Temp GUID
    }

    private func createOutgoingPrivateMessageWithInstance(_ msgInstance: DPAGSendMessageWorkerInstance, recipientPublicKey: String, cachedAesKeys: DPAGContactAesKeys, accountCrypto: CryptoHelperSimple, attachment: Data?) throws {
        var errorCreate: DPAGErrorCreateMessage?

        let senderId = DPAGFunctionsGlobal.uuid(prefix: .temp)

        do {
            msgInstance.messageJson = try DPAGApplicationFacadeShareExt.messageFactory.message(info: DPAGMessageModelFactoryShareExt.MessageInfo(guid: nil, senderId: senderId, text: msgInstance.messageText, desc: msgInstance.messageDesc, sendOptions: msgInstance.sendMessageOptions, recipient: msgInstance.receiver, recipientPublicKey: recipientPublicKey, cachedAesKeys: cachedAesKeys, contentType: msgInstance.contentType, attachment: attachment, featureSet: msgInstance.featureSet, additionalContentData: msgInstance.additionalContentData, accountCrypto: accountCrypto))
        } catch let err as DPAGErrorCreateMessage {
            errorCreate = err
            return
        } catch { return }

        if msgInstance.messageJson == nil {
            // The message was not properly configured, we risk trying to save an inconsistent context
            msgInstance.guidOutgoingMessage = nil

            return
        }

        msgInstance.sendConcurrent = (attachment?.count ?? 0) > 4_000

        msgInstance.messageType = .private

        if let errorCreate = errorCreate {
            throw errorCreate
        }

        msgInstance.guidOutgoingMessage = DPAGFunctionsGlobal.uuid(prefix: .temp) // Temp GUID
    }

    private func sendGroupMessage(msgInstance: DPAGSendMessageWorkerInstance, config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig) {
        guard let messageJson = msgInstance.messageJson, let messageGuid = msgInstance.guidOutgoingMessage else {
            // Something went wrong.. call the handler with an unknown error
            // serviceResponseBlock(nil, nil, nil)
            return
        }

        if let sendDate = msgInstance.sendMessageOptions?.dateToBeSend {
            DPAGApplicationFacadeShareExt.server.sendTimedGroupMessage(messageJson: messageJson, sendTime: sendDate, backgroundId: messageGuid, config: config, configSending: configSending)
        } else {
            DPAGApplicationFacadeShareExt.server.sendGroupMessage(messageJson: messageJson, backgroundId: messageGuid, config: config, configSending: configSending)
        }
    }

    private func sendPrivateMessage(msgInstance: DPAGSendMessageWorkerInstance, config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig) {
        guard let messageJson = msgInstance.messageJson, let messageGuid = msgInstance.guidOutgoingMessage else {
            // Something went wrong.. call the handler with an unknown error
            // serviceResponseBlock(nil, nil, nil)
            return
        }

        if let sendDate = msgInstance.sendMessageOptions?.dateToBeSend {
            DPAGApplicationFacadeShareExt.server.sendTimedMessage(messageJson: messageJson, sendTime: sendDate, backgroundId: messageGuid, config: config, configSending: configSending)
        } else {
            DPAGApplicationFacadeShareExt.server.sendMessage(messageJson: messageJson, backgroundId: messageGuid, config: config, configSending: configSending)
        }
    }
}
