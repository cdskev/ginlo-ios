//
//  DPAGServerWorkerShareExt.swift
//  SIMSmeShareExtensionBase
//
//  Created by RBU on 06.08.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import NSHash
import UIKit

private let CMD_SEND_PRIVATE_MESSAGE = "sendPrivateMessage"
private let CMD_SEND_PRIVATE_MESSAGE_WITH_TIME = "sendTimedPrivateMessage"
private let CMD_SEND_GROUP_MESSAGE = "sendGroupMessage"
private let CMD_SEND_GROUP_MESSAGE_WITH_TIME = "sendTimedGroupMessage"

private let CMD_GET_ACCOUNT_INFO = "getAccountInfo"

private let SIMS_COMMAND = "cmd"

private let SIMS_MESSAGE = "message"
private let SIMS_MESSAGE_CHECKSUM = "message-checksum"
private let SIMS_MESSAGE_DATE_TO_SEND = "dateToSend"
private let SIMS_MESSAGE_RETURN_CONFIRM_MESSAGE = "returnConfirmMessage"

private let SIMS_ACCOUNT_GUID = "accountGuid"
private let SIMS_ACCOUNT_PROFILE_INFO = "profileInfo"
private let SIMS_CHECK_READONLY = "checkReadonly"
private let SIMS_ACCOUNT_TEMP_DEVICE = "tempDevice"

public protocol DPAGServerWorkerShareExtProtocol: AnyObject {
    func sendMessage(messageJson: String, backgroundId: String, config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig)
    func sendTimedMessage(messageJson: String, sendTime: Date, backgroundId: String, config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig)
    func sendGroupMessage(messageJson: String, backgroundId: String, config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig)
    func sendTimedGroupMessage(messageJson: String, sendTime: Date, backgroundId: String, config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig)
    func getAccountInfo(guid: String, withProfile profile: Bool, withTempDevice tempDevice: Bool, config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig, withResponse responseBlock: @escaping DPAGServiceResponseBlock)
}

class DPAGServerWorkerShareExt: DPAGServerWorkerShareExtProtocol {
    func sendMessage(messageJson: String, backgroundId: String, config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig) {
        self.sendMessageJson(messageJson: messageJson, command: CMD_SEND_PRIVATE_MESSAGE, backgroundId: backgroundId, config: config, configSending: configSending)
    }

    func sendTimedMessage(messageJson: String, sendTime: Date, backgroundId: String, config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig) {
        self.sendTimedMessageJson(messageJson: messageJson, command: CMD_SEND_PRIVATE_MESSAGE_WITH_TIME, sendTime: sendTime, backgroundId: backgroundId, config: config, configSending: configSending)
    }

    func sendGroupMessage(messageJson: String, backgroundId: String, config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig) {
        self.sendMessageJson(messageJson: messageJson, command: CMD_SEND_GROUP_MESSAGE, backgroundId: backgroundId, config: config, configSending: configSending)
    }

    func sendTimedGroupMessage(messageJson: String, sendTime: Date, backgroundId: String, config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig) {
        self.sendTimedMessageJson(messageJson: messageJson, command: CMD_SEND_GROUP_MESSAGE_WITH_TIME, sendTime: sendTime, backgroundId: backgroundId, config: config, configSending: configSending)
    }

    private func sendMessageJson(messageJson: String, command: String, backgroundId _: String, config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig) {
        let checksum = messageJson.md5()
        let semaphore = DispatchSemaphore(value: 0)
        let responseBlock: DPAGServiceResponseBlock = { responseObject, _, _ in
            defer {
                semaphore.signal()
            }
            if let response = responseObject as? [Any], let firstResponse = response.first as? [String: Any], let responseDict = firstResponse["ConfirmMessageSend"] as? [String: Any], let messageGuid = responseDict["guid"] as? String, let urlMetadataRoot = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: config.groupID) {
                let urlMetadata = urlMetadataRoot.appendingPathComponent("msg_" + messageGuid).appendingPathExtension("mmd")
                do {
                    // MessageGuid einfuegen
                    guard let data = messageJson.data(using: .utf8), var json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                        // appropriate error handling
                        return
                    }
                    let key = (command == CMD_SEND_GROUP_MESSAGE) ? "GroupMessage" : "PrivateMessage"
                    if var innerDict = json[key] as? [String: Any] {
                        innerDict["guid"] = messageGuid
                        if let dateSendNew = responseDict["datesend"] {
                            innerDict["datesend"] = dateSendNew
                        }
                        if let attachments = responseDict["attachments"] {
                            innerDict["attachmentGuids"] = attachments
                        }
                        json[key] = innerDict
                    }
                    let parameterData = try JSONSerialization.data(withJSONObject: json, options: [])

                    try parameterData.write(to: urlMetadata)
                } catch {
                    DPAGLog(error, message: "error writing metadata")
                }
            }
        }
        let parameters: [AnyHashable: Any] = [
            SIMS_COMMAND: command,
            SIMS_MESSAGE: messageJson,
            SIMS_MESSAGE_CHECKSUM: checksum,
            SIMS_MESSAGE_RETURN_CONFIRM_MESSAGE: NSNumber(value: 1)
        ]
        DPAGApplicationFacadeShareExt.service.perform(request: {
            let request = DPAGHttpServiceRequestShareExt()
            request.parameters = parameters
            request.urlHttpService = config.urlHttpService
            request.httpUsername = configSending.httpUsername
            request.httpPassword = configSending.httpPassword
            request.appGroupId = config.groupID
            request.responseBlock = responseBlock
            // request.backgroundId = backgroundId
            return request
        }())
        _ = semaphore.wait(timeout: .distantFuture)
    }

    private func sendTimedMessageJson(messageJson: String, command: String, sendTime: Date, backgroundId: String, config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig) {
        let checksum = messageJson.md5()
        let parameters: [AnyHashable: Any] = [
            SIMS_COMMAND: command,
            SIMS_MESSAGE: messageJson,
            SIMS_MESSAGE_CHECKSUM: checksum,
            SIMS_MESSAGE_DATE_TO_SEND: sendTime
        ]
        DPAGApplicationFacadeShareExt.service.perform(request: {
            let request = DPAGHttpServiceRequestShareExt()
            request.parameters = parameters
            request.urlHttpService = config.urlHttpService
            request.httpUsername = configSending.httpUsername
            request.httpPassword = configSending.httpPassword
            request.appGroupId = config.groupID
            request.backgroundId = backgroundId
            return request
        }())
    }

    func getAccountInfo(guid: String, withProfile profile: Bool, withTempDevice tempDevice: Bool, config: DPAGSharedContainerConfig, configSending: DPAGShareExtSendingConfig, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        let parameters: [AnyHashable: Any] = [
            SIMS_COMMAND: CMD_GET_ACCOUNT_INFO,
            SIMS_ACCOUNT_GUID: guid,
            SIMS_ACCOUNT_PROFILE_INFO: profile ? "1" : "0",
            DPAGStrings.WHITELABEL_MANDANT: "1",
            SIMS_CHECK_READONLY: (DPAGApplicationFacadeShareExt.cache.account?.isCompanyUserRestricted ?? false) ? "1" : "0",
            SIMS_ACCOUNT_TEMP_DEVICE: tempDevice ? "1" : "0"
        ]
        DPAGApplicationFacadeShareExt.service.perform(request: {
            let request = DPAGHttpServiceRequestShareExt()
            request.parameters = parameters
            request.urlHttpService = config.urlHttpService
            request.httpUsername = configSending.httpUsername
            request.httpPassword = configSending.httpPassword
            request.appGroupId = config.groupID
            request.responseBlock = responseBlock
            return request
        }())
    }
}
