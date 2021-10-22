//
//  ReceiveMessageDAO.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 16.08.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

protocol ReceiveMessageDAOProtocol {
    func selectPrivateInternalMessageGuidsToResend(ownAccountGuid: String) -> [String]
    func updateDateDownloaded(forMessageGuids msgGuids: [String], ownAccountGuid: String)
    func messageJSON(forPrivateInternalMessageGuids privateInternalMessageGuids: [String]) -> String?
    func deleteSentPrivateInternalMessages(privateInternalMessageGuids: [String])
    func saveReceivedMessages(_ receivedMessages: [DPAGMessageReceivedCore], ownAccountGuid: String)
    func filterChannelsForUnsubscribe(channelGuids: Set<String>) -> ReceiveMessageDAOChannelUnsubscribeFilterResult
    func filterContactGuidsForUnknown(contactGuids: Set<String>) -> Set<String>
}

struct ReceiveMessageDAOChannelUnsubscribeFilterResult {
    let channelsToUnsubscribe: Set<String>
    let servicesToUnsubscribe: Set<String>
}

class ReceiveMessageDAO: ReceiveMessageDAOProtocol, DPAGClassPerforming {
    struct SaveResult {
        var channelStreamsUpdated: Set<String> = Set()
        var mostRecentDateSendServer: Date?
        var channelUnsubscribedGuids: Set<String> = Set()
        var serviceUnsubscribedGuids: Set<String> = Set()
    }

    func selectPrivateInternalMessageGuidsToResend(ownAccountGuid: String) -> [String] {
        var msgGuidsToResend: [String] = []
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            guard let msgsToResend = SIMSPrivateInternalMessage.mr_findAllSorted(by: "dateSend", ascending: true, in: localContext) else { return }
            tryC {
                for msgObj in msgsToResend {
                    if let msg = msgObj as? SIMSPrivateInternalMessage, let msgGuid = msg.guid, msg.toAccountGuid != ownAccountGuid, msg.fromAccountGuid == nil {
                        msgGuidsToResend.append(msgGuid)
                    } else {
                        msgObj.mr_deleteEntity(in: localContext)
                    }
                    if msgGuidsToResend.count > 10 {
                        break
                    }
                }
            }
            .catch { exception in
                // Exception tritt durch paralleles Senden und löschen auf
                DPAGLog("%@", exception)
            }
        }
        return msgGuidsToResend
    }

    func updateDateDownloaded(forMessageGuids msgGuids: [String], ownAccountGuid: String) {
        let dateDownloaded = Date()
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            for messageGuid in msgGuids {
                if let unreadMessage = SIMSMessage.findFirst(byGuid: messageGuid, in: localContext) {
                    if unreadMessage.attributes == nil {
                        unreadMessage.attributes = SIMSMessageAttributes.mr_createEntity(in: localContext)
                    }
                    if unreadMessage.fromAccountGuid == ownAccountGuid {
                        continue
                    }
                    if unreadMessage.attributes?.dateDownloaded == nil {
                        unreadMessage.attributes?.dateDownloaded = dateDownloaded
                    }
                    // update only already cached messages
                    DPAGApplicationFacade.cache.decryptedMessageFast(messageGuid: messageGuid)?.updateDownloaded(withDate: dateDownloaded)
                }
            }
        }
    }

    func messageJSON(forPrivateInternalMessageGuids privateInternalMessageGuids: [String]) -> String? {
        var messageJsonsString: String?
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            var privateInternalMessageDicts: [[AnyHashable: Any]] = []
            for msgGuid in privateInternalMessageGuids {
                guard let msgToResend = SIMSPrivateInternalMessage.findFirst(byGuid: msgGuid, in: localContext) else { continue }
                if let recipient = SIMSContactIndexEntry.findFirst(byGuid: msgToResend.toAccountGuid ?? "noFromAccountGuid", in: localContext), recipient[.IS_DELETED] == false {
                    do {
                        if let messageDict = try DPAGApplicationFacade.messageFactory.privateInternalMessageDictionary(message: msgToResend, forRecipient: recipient, in: localContext) {
                            privateInternalMessageDicts.append(messageDict)
                        }
                    } catch {
                        msgToResend.mr_deleteEntity(in: localContext)
                    }
                } else {
                    msgToResend.mr_deleteEntity(in: localContext)
                }
            }
            messageJsonsString = privateInternalMessageDicts.JSONString
        }
        return messageJsonsString
    }

    func deleteSentPrivateInternalMessages(privateInternalMessageGuids: [String]) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            for msgGuid in privateInternalMessageGuids {
                if let msg = SIMSPrivateInternalMessage.findFirst(byGuid: msgGuid, in: localContext) {
                    msg.mr_deleteEntity(in: localContext)
                }
            }
        }
    }

    func saveReceivedMessages(_ receivedMessages: [DPAGMessageReceivedCore], ownAccountGuid: String) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            do {
                let messagesSaved = try self.saveMessages(receivedMessages, ownAccountGuid: ownAccountGuid, in: localContext)
                self.cleanupChannelMessages(messagesSaved, in: localContext)
            } catch {
                DPAGLog(error)
            }
        }
    }

    private func cleanupChannelMessages(_ messagesSaveResult: SaveResult, in localContext: NSManagedObjectContext) {
        guard messagesSaveResult.channelStreamsUpdated.isEmpty == false else { return }
        var channelMessagesToDelete: [String: SIMSChannelMessage] = [:]
        let maximumNumberOfMessagesInChannel = DPAGApplicationFacade.preferences.maxNumChannelMessagesPerChannel
        let updatedStreams = messagesSaveResult.channelStreamsUpdated
        let predicate = NSPredicate(format: "stream.guid in %@", updatedStreams)
        guard let allChannelMessages = SIMSMessage.mr_findAllSorted(by: "dateSendServer", ascending: false, with: predicate, in: localContext) else { return }
        // Method 1 - fetch all messages then manually group them by channel guid
        var channelMessageCountDictionary: [String: UInt] = [:]
        var updatedChannels: [String: String] = [:]
        for messageObj in allChannelMessages {
            guard let message = messageObj as? SIMSChannelMessage, let messageGuid = message.guid else { continue }
            if let channelGuid = message.stream?.guid {
                let numberOfMessagesInChannel: UInt = channelMessageCountDictionary[channelGuid] ?? 0
                if numberOfMessagesInChannel < maximumNumberOfMessagesInChannel {
                    channelMessageCountDictionary[channelGuid] = numberOfMessagesInChannel + 1
                } else {
                    channelMessagesToDelete[messageGuid] = message
                    updatedChannels[channelGuid] = channelGuid
                }
            } else {
                channelMessagesToDelete[messageGuid] = message
            }
        }
        if let mostRecentDateSendServer = messagesSaveResult.mostRecentDateSendServer {
            self.findChannelsMessagesToDelete(mostRecentDateSendServer: mostRecentDateSendServer, channelMessagesToDelete: &channelMessagesToDelete, updatedChannels: &updatedChannels, in: localContext)
        }
        if channelMessagesToDelete.count > 0 {
            for channelMessage in channelMessagesToDelete.values {
                if let localMessage = channelMessage.mr_(in: localContext) {
                    DPAGApplicationFacade.persistance.deleteMessage(localMessage, in: localContext)
                }
            }
            for channelGuid in updatedChannels.keys {
                DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: channelGuid, stream: nil, in: localContext)
            }
        }
    }

    private func findChannelsMessagesToDelete(mostRecentDateSendServer: Date, channelMessagesToDelete: inout [String: SIMSChannelMessage], updatedChannels: inout [String: String], in localContext: NSManagedObjectContext) {
        let daysToKeepChannelMessages = DPAGApplicationFacade.preferences.maxDaysChannelMessagesValid
        let mostRecentValidDateForChannelMessages = mostRecentDateSendServer.addingTimeInterval(-(60 * 60 * 24 * Double(daysToKeepChannelMessages)))
        guard let oldChannelMessages = SIMSChannelMessage.mr_findAll(with: NSPredicate(format: "dateSendServer < %@", mostRecentValidDateForChannelMessages as NSDate), in: localContext) else { return }
        for channelMessageObj in oldChannelMessages {
            guard let channelMessage = channelMessageObj as? SIMSChannelMessage, let channelMessageGuid = channelMessage.guid, channelMessagesToDelete[channelMessageGuid] == nil else { continue }
            channelMessagesToDelete[channelMessageGuid] = channelMessage
            if let channelGuid = channelMessage.stream?.guid {
                updatedChannels[channelGuid] = channelGuid
            }
        }
    }
    
    private func checkForControlMsgNGPrivate(_ controlMsgNG: DPAGMessageReceivedPrivate) -> Bool {
        if controlMsgNG.contentTyp == DPAGStrings.JSON.Message.ContentType.CONTROL_MSG_NG {
            // IMDAT: WE COULD NOW STOP RINGING IF WE ARE RINGING AN INCOMING CALL (e.g.)
            return true
        }
        return false
    }
    
    private func checkForControlMsgNGGroup(_ controlMsgNG: DPAGMessageReceivedGroup) -> Bool {
        if controlMsgNG.contentTyp == DPAGStrings.JSON.Message.ContentType.CONTROL_MSG_NG {
            // IMDAT: WE COULD NOW STOP RINGING IF WE ARE RINGING AN INCOMING CALL (e.g.)
            return true
        }
        return false
    }
    
    private func saveMessages(_ receivedMessages: [DPAGMessageReceivedCore], ownAccountGuid: String, in localContext: NSManagedObjectContext) throws -> SaveResult {
        var contactsCreated: [String: SIMSContactIndexEntry] = [:]
        var streamNeedsCacheUpdate: [String: SIMSMessageStream] = [:]
        var saveResult = SaveResult()
        for message in receivedMessages {
            var dateSend: Date?
            switch message.messageType {
            case .private:
                guard let messagePrivate = message as? DPAGMessageReceivedPrivate else { break }
                if self.checkForControlMsgNGPrivate(messagePrivate) == false {
                    self.handlePrivateMessage(messagePrivate, ownAccountGuid: ownAccountGuid, contactsCreated: &contactsCreated, streamNeedsCacheUpdate: &streamNeedsCacheUpdate, in: localContext)
                    dateSend = messagePrivate.dateSend
                }
            case .privateInternal:
                guard let messagePrivateInternal = message as? DPAGMessageReceivedPrivateInternal else { break }
                self.handlePrivateInternalMessage(messagePrivateInternal, ownAccountGuid: ownAccountGuid, contactsCreated: &contactsCreated, in: localContext)
                dateSend = messagePrivateInternal.dateSend
            case .internal:
                guard let messageInternal = message as? DPAGMessageReceivedInternal else { break }
                self.handleInternalMessage(messageInternal, ownAccountGuid: ownAccountGuid, streamNeedsCacheUpdate: &streamNeedsCacheUpdate, in: localContext)
                dateSend = messageInternal.dateSend
            case .group:
                guard let messageGroup = message as? DPAGMessageReceivedGroup else { break }
                if  self.checkForControlMsgNGGroup(messageGroup) == false {
                    self.handleGroupMessage(messageGroup, ownAccountGuid: ownAccountGuid, contactsCreated: &contactsCreated, streamNeedsCacheUpdate: &streamNeedsCacheUpdate, in: localContext)
                    dateSend = messageGroup.dateSend
                }
            case .groupInvitation:
                guard let messageGroupInvitation = message as? DPAGMessageReceivedGroupInvitation else { break }
                self.handleGroupInvitationMessage(messageGroupInvitation, ownAccountGuid: ownAccountGuid, contactsCreated: &contactsCreated, in: localContext)
                dateSend = messageGroupInvitation.dateSend
            case .channel:
                guard let messageChannel = message as? DPAGMessageReceivedChannel else { break }
                self.handleChannelMessage(messageChannel, streamNeedsCacheUpdate: &streamNeedsCacheUpdate, saveResult: &saveResult, in: localContext)
                dateSend = messageChannel.dateSend
            case .confirmTimedMessageSent:
                guard let messageConfirmSend = message as? DPAGMessageReceivedConfirmTimedMessageSend else { break }
                self.handleTimedMessageSendConfirmation(messageConfirmSend, streamNeedsCacheUpdate: &streamNeedsCacheUpdate, in: localContext)
                dateSend = messageConfirmSend.dateSend
            case .unknown:
                break
            }
            if let dateSend = dateSend, (saveResult.mostRecentDateSendServer?.compare(dateSend) ?? .orderedAscending) == .orderedAscending {
                saveResult.mostRecentDateSendServer = dateSend
            }
        }
        for stream in streamNeedsCacheUpdate {
            DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: stream.key, stream: stream.value, in: localContext)
        }
        return saveResult
    }

    private func handlePrivateInternalStatusMessage(_ privateInternalMessageDict: DPAGMessageReceivedPrivateInternal, messageDecrypted: DPAGMessageReceivedPrivateInternalDecrypted, in localContext: NSManagedObjectContext) {
        guard let status = messageDecrypted.contentValue as? String, let contact = SIMSContactIndexEntry.findFirst(byGuid: privateInternalMessageDict.fromAccountInfo.accountGuid, in: localContext) else {
            return
        }
        contact[.STATUSMESSAGE] = status
        DPAGLog("status: %@", contact[.STATUSMESSAGE] ?? "status not set")
        if contact[.PROFIL_KEY]?.isEmpty ?? true {
            if let profilKey = messageDecrypted.messageDict.profilKey {
                contact[.PROFIL_KEY] = profilKey
            }
        }
    }

    private func handlePrivateInternalImageMessage(_ privateInternalMessageDict: DPAGMessageReceivedPrivateInternal, messageDecrypted: DPAGMessageReceivedPrivateInternalDecrypted, contactsCreated: inout [String: SIMSContactIndexEntry], in localContext: NSManagedObjectContext) {
        guard let image = messageDecrypted.contentValue as? String else {
            return
        }
        let fromAccountGuid = privateInternalMessageDict.fromAccountInfo.accountGuid
        if let contact = contactsCreated[fromAccountGuid] ?? SIMSContactIndexEntry.findFirst(byGuid: fromAccountGuid, in: localContext) {
            contact[.IMAGE_DATA] = image
        }
    }

    private func handlePrivateInternalGroupImageMessage(_: DPAGMessageReceivedPrivateInternal, messageDecrypted: DPAGMessageReceivedPrivateInternalDecrypted, in localContext: NSManagedObjectContext) {
        guard let image = messageDecrypted.contentValue as? String,
            let groupGuid = messageDecrypted.contentDict?[DPAGStrings.Server.MessageReceivedPrivateInternalDecrypted.Response.GROUP_GUID] as? String,
            SIMSMessageStream.findFirst(byGuid: groupGuid, in: localContext) != nil else {
            return
        }
        DPAGHelperEx.saveBase64Image(encodedImage: image, forGroupGuid: groupGuid)
    }

    private func handlePrivateInternalGroupNameMessage(_: DPAGMessageReceivedPrivateInternal, messageDecrypted: DPAGMessageReceivedPrivateInternalDecrypted, in localContext: NSManagedObjectContext) {
        guard let name = messageDecrypted.contentValue as? String,
            let groupGuid = messageDecrypted.contentDict?[DPAGStrings.Server.MessageReceivedPrivateInternalDecrypted.Response.GROUP_GUID] as? String,
            let group = SIMSMessageStream.findFirst(byGuid: groupGuid, in: localContext) as? SIMSGroupStream else {
            return
        }
        group.group?.groupName = name
    }

    private func handlePrivateInternalNicknameMessage(_ privateInternalMessageDict: DPAGMessageReceivedPrivateInternal, messageDecrypted: DPAGMessageReceivedPrivateInternalDecrypted, contactsCreated: inout [String: SIMSContactIndexEntry], in localContext: NSManagedObjectContext) {
        guard let nickname = messageDecrypted.contentValue as? String else {
            return
        }
        let fromAccountGuid = privateInternalMessageDict.fromAccountInfo.accountGuid
        if let contact = contactsCreated[fromAccountGuid] ?? SIMSContactIndexEntry.findFirst(byGuid: fromAccountGuid, in: localContext) {
            if nickname.isEmpty == false {
                contact[.NICKNAME] = nickname
            }
            if contact[.PROFIL_KEY]?.isEmpty ?? true {
                if let profilKey = messageDecrypted.messageDict.profilKey {
                    contact[.PROFIL_KEY] = profilKey
                }
            }
        } else {
            guard let phone = messageDecrypted.messageDict.phone else { return }
            // create dummy contact and with dummy stream
            let dummyAccountDict: [String: Any] = [SIMS_GUID: fromAccountGuid, SIMS_PHONE: phone, SIMS_PUBLIC_KEY: ""]
            guard let contact = DPAGApplicationFacade.contactFactory.newModel(accountJson: dummyAccountDict, in: localContext), let profilKey = messageDecrypted.messageDict.profilKey else { return }
            if nickname.isEmpty == false {
                contact[.NICKNAME] = nickname
            }
            contact[.PROFIL_KEY] = profilKey
            contactsCreated[fromAccountGuid] = contact
        }
    }

    private func handlePrivateInternalNewGroupMembersMessage(_ privateInternalMessageDict: DPAGMessageReceivedPrivateInternal, messageDecrypted: DPAGMessageReceivedPrivateInternalDecrypted, ownAccountGuid: String, in localContext: NSManagedObjectContext) {
        guard let newGuids = messageDecrypted.contentValue as? [String], let groupGuid = messageDecrypted.contentDict?[DPAGStrings.Server.MessageReceivedPrivateInternalDecrypted.Response.GROUP_GUID] as? String else {
            return
        }
        _ = self.addMembers(newMemberGuids: newGuids, toGroup: groupGuid, senderGuid: nil, senderNick: nil, sendDate: privateInternalMessageDict.dateSend, messageGuid: privateInternalMessageDict.guid, ownAccountGuid: ownAccountGuid, in: localContext)
    }

    private func handlePrivateInternalRemovedGroupMembersMessage(_ privateInternalMessageDict: DPAGMessageReceivedPrivateInternal, messageDecrypted: DPAGMessageReceivedPrivateInternalDecrypted, ownAccountGuid: String, in localContext: NSManagedObjectContext) {
        guard let removedGuids = messageDecrypted.contentValue as? [String], let groupGuid = messageDecrypted.contentDict?[DPAGStrings.Server.MessageReceivedPrivateInternalDecrypted.Response.GROUP_GUID] as? String else {
            return
        }
        _ = self.removeMembers(memberGuidsToRemove: removedGuids, fromGroup: groupGuid, senderGuid: nil, senderNick: nil, sendDate: privateInternalMessageDict.dateSend, messageGuid: privateInternalMessageDict.guid, ownAccountGuid: ownAccountGuid, in: localContext)
    }

    private func handlePrivateInternalMessage(_ privateInternalMessageDict: DPAGMessageReceivedPrivateInternal, ownAccountGuid: String, contactsCreated: inout [String: SIMSContactIndexEntry], in localContext: NSManagedObjectContext) {
        guard let messageDecrypted = privateInternalMessageDict.contentDecrypted else { return }
        switch messageDecrypted.contentType {
            case DPAGStrings.JSON.Message.ContentType.STATUS:
                self.handlePrivateInternalStatusMessage(privateInternalMessageDict, messageDecrypted: messageDecrypted, in: localContext)
            case DPAGStrings.JSON.Message.ContentType.IMAGE:
                self.handlePrivateInternalImageMessage(privateInternalMessageDict, messageDecrypted: messageDecrypted, contactsCreated: &contactsCreated, in: localContext)
            case DPAGStrings.JSON.Message.ContentType.GROUP_IMAGE:
                self.handlePrivateInternalGroupImageMessage(privateInternalMessageDict, messageDecrypted: messageDecrypted, in: localContext)
            case DPAGStrings.JSON.Message.ContentType.GROUP_NAME:
                self.handlePrivateInternalGroupNameMessage(privateInternalMessageDict, messageDecrypted: messageDecrypted, in: localContext)
            case DPAGStrings.JSON.Message.ContentType.NICKNAME:
                self.handlePrivateInternalNicknameMessage(privateInternalMessageDict, messageDecrypted: messageDecrypted, contactsCreated: &contactsCreated, in: localContext)
            case DPAGStrings.JSON.MessageInternal.ObjectKey.NEW_GROUP_MEMBERS:
                self.handlePrivateInternalNewGroupMembersMessage(privateInternalMessageDict, messageDecrypted: messageDecrypted, ownAccountGuid: ownAccountGuid, in: localContext)
            case DPAGStrings.JSON.MessageInternal.ObjectKey.REMOVED_GROUP_MEMBERS:
                self.handlePrivateInternalRemovedGroupMembersMessage(privateInternalMessageDict, messageDecrypted: messageDecrypted, ownAccountGuid: ownAccountGuid, in: localContext)
            default:
                if let contentDict = messageDecrypted.contentDict {
                    DPAGLog("nothing found: \(contentDict)", level: .warning)
                } else {
                    DPAGLog("nothing found: \(messageDecrypted.messageDict)", level: .warning)
                }
        }
    }

    private func handleInternalConfirmDownloadMessage(_ internalMessageDict: DPAGMessageReceivedInternal, data: DPAGMessageReceivedInternal.ConfirmDownload, dateSend: Date, ownAccountGuid: String, streamNeedsCacheUpdate: inout [String: SIMSMessageStream], in localContext: NSManagedObjectContext) {
        data.guids.forEach { guid in
            guard let msg = SIMSMessage.findFirst(byGuid: guid, in: localContext), let decMessage = DPAGApplicationFacade.cache.decryptedMessage(msg, in: localContext), let streamGuid = msg.stream?.guid else { return }
            if internalMessageDict.from == ownAccountGuid {} else {
                if (msg.receiver?.count ?? 0) > 0 {
                    for receiver in msg.receiver ?? Set() where receiver.contactIndexEntry?.guid == internalMessageDict.from {
                        receiver.dateDownloaded = dateSend
                        break
                    }
                    decMessage.updateDownloaded(withDate: dateSend, recipients: msg.receiver ?? Set())
                    if decMessage.isDownloaded, msg.dateDownloaded == nil {
                        msg.dateDownloaded = dateSend
                    }
                } else if msg.dateDownloaded == nil {
                    msg.dateDownloaded = dateSend
                    decMessage.updateDownloaded(withDate: dateSend)
                }
            }
            if msg === msg.stream?.messages?.lastObject as? SIMSMessage, let lastMessageDate = msg.stream?.lastMessageDate {
                // change date to force reload chats list
                msg.stream?.lastMessageDate = Date(timeIntervalSinceReferenceDate: lastMessageDate.timeIntervalSinceReferenceDate + 0.001)
            }
            streamNeedsCacheUpdate[streamGuid] = msg.stream
        }
    }

    private func handleInternalConfirmReadMessage(_ internalMessageDict: DPAGMessageReceivedInternal, data: DPAGMessageReceivedInternal.ConfirmRead, dateSend: Date, ownAccountGuid: String, streamNeedsCacheUpdate: inout [String: SIMSMessageStream], in localContext: NSManagedObjectContext) {
        data.guids.forEach { guid in
            guard let msg = SIMSMessage.findFirst(byGuid: guid, in: localContext), let decMessage = DPAGApplicationFacade.cache.decryptedMessage(msg, in: localContext), let streamGuid = msg.stream?.guid else { return }
            if internalMessageDict.from == ownAccountGuid {
                msg.attributes?.dateReadLocal = dateSend
                decMessage.updateReadLocal(withDate: dateSend)
            } else {
                if (msg.receiver?.count ?? 0) > 0 {
                    for receiver in msg.receiver ?? Set() where receiver.contactIndexEntry?.guid == internalMessageDict.from {
                        receiver.dateRead = dateSend
                        break
                    }
                    decMessage.updateRead(withDate: dateSend, recipients: msg.receiver ?? Set())
                    if decMessage.isReadServer {
                        msg.dateReadServer = dateSend
                    }
                } else {
                    msg.dateReadServer = dateSend
                    decMessage.updateRead(withDate: dateSend)
                }
            }
            if msg === msg.stream?.messages?.lastObject as? SIMSMessage, let lastMessageDate = msg.stream?.lastMessageDate {
                // change date to force reload chats list
                msg.stream?.lastMessageDate = Date(timeIntervalSinceReferenceDate: lastMessageDate.timeIntervalSinceReferenceDate + 0.001)
            }
            streamNeedsCacheUpdate[streamGuid] = msg.stream
        }
    }

    private func handleInternalConfirmDeletedMessage(data: DPAGMessageReceivedInternal.ConfirmDeleted, streamNeedsCacheUpdate: inout [String: SIMSMessageStream], in localContext: NSManagedObjectContext) {
        data.guids.forEach { guid in
            if let msg = SIMSMessage.findFirst(byGuid: guid, in: localContext), DPAGApplicationFacade.cache.decryptedMessage(msg, in: localContext) != nil, let streamGuid = msg.stream?.guid, let stream = msg.stream {
                msg.mr_deleteEntity(in: localContext)
                if msg === msg.stream?.messages?.lastObject as? SIMSMessage, let lastMessageDate = msg.stream?.lastMessageDate {
                    // change date to force reload chats list
                    msg.stream?.lastMessageDate = Date(timeIntervalSinceReferenceDate: lastMessageDate.timeIntervalSinceReferenceDate + 0.001)
                }
                streamNeedsCacheUpdate[streamGuid] = stream
            }
            if let msg = SIMSMessageToSend.findFirst(byGuid: guid, in: localContext), DPAGApplicationFacade.cache.decryptedMessage(msg, in: localContext) != nil, let streamGuid = msg.streamGuid {
                msg.mr_deleteEntity(in: localContext)
                let stream = SIMSStream.findFirst(byGuid: streamGuid, in: localContext)
                streamNeedsCacheUpdate[streamGuid] = stream
            }
        }
    }

    private func handleInternalGroupOwnerChangedMessage(_ internalMessageDict: DPAGMessageReceivedInternal, data: DPAGMessageReceivedInternal.GroupOwnerChanged.GroupOwnerChangedItem, dateSend: Date, streamNeedsCacheUpdate: inout [String: SIMSMessageStream], in localContext: NSManagedObjectContext) {
        guard let groupStream = SIMSMessageStream.findFirst(byGuid: data.roomGuid, in: localContext) as? SIMSGroupStream else { return }
        groupStream.group?.ownerGuid = data.accountGuid
        let content = String(format: DPAGLocalizedString("chat.group.newOwner"), data.accountGuid)
        DPAGApplicationFacade.messageFactory.newSystemMessage(content: content, forGroup: groupStream, sendDate: dateSend, guid: internalMessageDict.guid, in: localContext)
        streamNeedsCacheUpdate[data.roomGuid] = groupStream
    }

    private func handleInternalGroupRemovedMessage(_ internalMessageDict: DPAGMessageReceivedInternal, data: DPAGMessageReceivedInternal.GroupRemoved, dateSend: Date, ownAccountGuid: String, streamNeedsCacheUpdate: inout [String: SIMSMessageStream], in localContext: NSManagedObjectContext) {
        guard let groupStream = SIMSMessageStream.findFirst(byGuid: data.guid, in: localContext) as? SIMSGroupStream, internalMessageDict.from != ownAccountGuid else {
            return
        }
        groupStream.group?.wasDeleted = true
        DPAGApplicationFacade.messageFactory.newSystemMessage(content: DPAGLocalizedString("chat.group.wasDeleted"), forGroup: groupStream, sendDate: dateSend, guid: internalMessageDict.guid, in: localContext)
        streamNeedsCacheUpdate[data.guid] = groupStream
    }

    private func handleInternalChannelRemovedMessage(_ internalMessageDict: DPAGMessageReceivedInternal, data: DPAGMessageReceivedInternal.ChannelRemoved, dateSend: Date, streamNeedsCacheUpdate: inout [String: SIMSMessageStream], in localContext: NSManagedObjectContext) {
        guard let channel = SIMSChannel.findFirst(byGuid: data.guid, in: localContext) else { return }
        channel.stream?.wasDeleted = NSNumber(value: true)
        DPAGApplicationFacade.messageFactory.newSystemMessage(content: DPAGLocalizedString("chat.channel.wasDeleted"), forChannel: channel, sendDate: dateSend, guid: internalMessageDict.guid, in: localContext)
        if let streamGuid = channel.stream?.guid {
            streamNeedsCacheUpdate[streamGuid] = channel.stream
        }
    }

    private func handleInternalGroupNewMembersMessage(_ internalMessageDict: DPAGMessageReceivedInternal, data: DPAGMessageReceivedInternal.GroupMembersNew.GroupMembersNewItem, dateSend: Date, ownAccountGuid: String, streamNeedsCacheUpdate: inout [String: SIMSMessageStream], in localContext: NSManagedObjectContext) {
        let newMemberGuids = data.guids
        let groupGuid = data.roomGuid
        if let stream = self.addMembers(newMemberGuids: newMemberGuids, toGroup: groupGuid, senderGuid: data.senderGuid, senderNick: data.senderNick, sendDate: dateSend, messageGuid: internalMessageDict.guid, ownAccountGuid: ownAccountGuid, in: localContext) {
            streamNeedsCacheUpdate[data.roomGuid] = stream
        }
        if data.guids.contains(ownAccountGuid) {
            if let group = SIMSGroup.findFirst(byGuid: data.roomGuid, in: localContext) {
                group.isConfirmed = true
                group.wasDeleted = false
            }
        }
    }

    private func handleInternalGroupRemovedMembersMessage(data: DPAGMessageReceivedInternal.GroupMembersRemoved.GroupMembersRemovedItem, dateSend: Date, messageGuid: String, ownAccountGuid: String, streamNeedsCacheUpdate: inout [String: SIMSMessageStream], in localContext: NSManagedObjectContext) {
        let memberGuidsToRemove = data.guids
        let groupGuid = data.roomGuid
        if let stream = self.removeMembers(memberGuidsToRemove: memberGuidsToRemove, fromGroup: groupGuid, senderGuid: data.senderGuid, senderNick: data.senderNick, sendDate: dateSend, messageGuid: messageGuid, ownAccountGuid: ownAccountGuid, in: localContext) {
            streamNeedsCacheUpdate[data.roomGuid] = stream
        }
    }

    private func handleInternalGroupInvitedMembersMessage(data: DPAGMessageReceivedInternal.GroupMembersInvited.GroupMembersInvitedItem, dateSend: Date, messageGuid: String, ownAccountGuid: String, streamNeedsCacheUpdate: inout [String: SIMSMessageStream], in localContext: NSManagedObjectContext) {
        let memberGuidsInvited = data.guids
        let groupGuid = data.roomGuid
        guard let groupStream = SIMSMessageStream.findFirst(byGuid: groupGuid, in: localContext) as? SIMSGroupStream, let group = groupStream.group else { return }
        var idx1 = 0
        memberGuidsInvited.forEach { accountGuid in
            if data.senderGuid != ownAccountGuid {
                if let member = SIMSGroupMember.mr_findFirst(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSGroupMember.accountGuid), rightExpression: NSExpression(forConstantValue: accountGuid)), in: localContext) ?? SIMSGroupMember.mr_createEntity(in: localContext) {
                    member.accountGuid = accountGuid
                    member.groups?.insert(group)
                }
            }
            let content = self.systemGroupMessageContentWithFormat("chat.group.invitedMember", formatWithSender: "chat.group.invitedMemberWithSender", accountGuid: accountGuid, senderGuid: data.senderGuid, senderNick: data.senderNick)
            DPAGApplicationFacade.messageFactory.newSystemMessage(content: content, forGroup: groupStream, sendDate: dateSend, guid: messageGuid + "\(idx1)", in: localContext)
            idx1 += 1
        }
        streamNeedsCacheUpdate[data.roomGuid] = groupStream
    }

    private func handleInternalGroupGrantedAdminsMessage(data: DPAGMessageReceivedInternal.GroupMembersAdminGranted.GroupMembersAdminGrantedItem, dateSend: Date, messageGuid: String, ownAccountGuid: String, streamNeedsCacheUpdate: inout [String: SIMSMessageStream], in localContext: NSManagedObjectContext) {
        let adminGrantedGuids = data.guids
        let groupGuid = data.roomGuid
        guard let groupStream = SIMSMessageStream.findFirst(byGuid: groupGuid, in: localContext) as? SIMSGroupStream else { return }
        var idx1 = 0
        adminGrantedGuids.forEach { accountGuid in
            if data.senderGuid != ownAccountGuid {
                groupStream.group?.addAdmin(accountGuid)
            }
            let content = self.systemGroupMessageContentWithFormat("chat.group.grantedAdmin", formatWithSender: "chat.group.grantedAdminWithSender", accountGuid: accountGuid, senderGuid: data.senderGuid, senderNick: data.senderNick)
            DPAGApplicationFacade.messageFactory.newSystemMessage(content: content, forGroup: groupStream, sendDate: dateSend, guid: messageGuid + "\(idx1)", in: localContext)
            idx1 += 1
        }
        streamNeedsCacheUpdate[data.roomGuid] = groupStream
    }

    private func handleInternalGroupRevokedAdminsMessage(data: DPAGMessageReceivedInternal.GroupMembersAdminRevoked.GroupMembersAdminRevokedItem, dateSend: Date, messageGuid: String, ownAccountGuid: String, streamNeedsCacheUpdate: inout [String: SIMSMessageStream], in localContext: NSManagedObjectContext) {
        let adminRevokedGuids = data.guids
        let groupGuid = data.roomGuid
        guard let groupStream = SIMSMessageStream.findFirst(byGuid: groupGuid, in: localContext) as? SIMSGroupStream else { return }
        var idx1 = 0
        adminRevokedGuids.forEach { accountGuid in
            if data.senderGuid != ownAccountGuid {
                groupStream.group?.removeAdmin(accountGuid)
            }
            let content = self.systemGroupMessageContentWithFormat("chat.group.revokedAdmin", formatWithSender: "chat.group.revokedAdminWithSender", accountGuid: accountGuid, senderGuid: data.senderGuid, senderNick: data.senderNick)
            DPAGApplicationFacade.messageFactory.newSystemMessage(content: content, forGroup: groupStream, sendDate: dateSend, guid: messageGuid + "\(idx1)", in: localContext)
            idx1 += 1
        }
        streamNeedsCacheUpdate[data.roomGuid] = groupStream
    }

    private func handleInternalOutOfOfficeMessage(_ internalMessageDict: DPAGMessageReceivedInternal, data: DPAGMessageReceivedInternal.OooMessage.OooMessageItem, dateSend: Date, streamNeedsCacheUpdate: inout [String: SIMSMessageStream], in localContext: NSManagedObjectContext) {
        // Absender + ProfileKey ermitteln
        guard let contact = SIMSContactIndexEntry.findFirst(byGuid: internalMessageDict.from, in: localContext), let streamGuid = contact.stream?.guid, let chatStream = contact.stream else { return }
        if let profileKey = contact[.PROFIL_KEY], let statusText = data.statusText, let statusTextIV = data.statusTextIV {
            do {
                let decryptedData = try CryptoHelperDecrypter.decrypt(encryptedString: statusText, withAesKeyDict: ["key": profileKey, "iv": statusTextIV])
                guard let decryptedString = String(data: decryptedData, encoding: .utf8) else { throw DPAGErrorCrypto.errData }
                DPAGApplicationFacade.messageFactory.newOooStatusMessage(content: decryptedString, forChat: chatStream, sendDate: dateSend, guid: internalMessageDict.guid, in: localContext)
                streamNeedsCacheUpdate[streamGuid] = chatStream
                return
            } catch {
                DPAGLog(error)
            }
        }
        guard let statusValidStr = data.statusValid, let dateFormated = DPAGFormatter.dateServer.date(from: statusValidStr) else { return }
        let message = String(format: DPAGLocalizedString("profile.oooStatus.oldState.oooWithDate"), dateFormated.dateLabel)
        DPAGApplicationFacade.messageFactory.newOooStatusMessage(content: message, forChat: chatStream, sendDate: dateSend, guid: internalMessageDict.guid, in: localContext)
        streamNeedsCacheUpdate[streamGuid] = chatStream
    }

    private func handleInternalMessage(_ internalMessageDict: DPAGMessageReceivedInternal, ownAccountGuid: String, streamNeedsCacheUpdate: inout [String: SIMSMessageStream], in localContext: NSManagedObjectContext) {
        let dateSend = internalMessageDict.dateSend
        if let data = internalMessageDict.confirmDownload {
            self.handleInternalConfirmDownloadMessage(internalMessageDict, data: data, dateSend: dateSend, ownAccountGuid: ownAccountGuid, streamNeedsCacheUpdate: &streamNeedsCacheUpdate, in: localContext)
        }
        if let data = internalMessageDict.confirmRead {
            self.handleInternalConfirmReadMessage(internalMessageDict, data: data, dateSend: dateSend, ownAccountGuid: ownAccountGuid, streamNeedsCacheUpdate: &streamNeedsCacheUpdate, in: localContext)
        }
        if let data = internalMessageDict.confirmDeleted {
            self.handleInternalConfirmDeletedMessage(data: data, streamNeedsCacheUpdate: &streamNeedsCacheUpdate, in: localContext)
        }
        if let data = internalMessageDict.groupOwnerChanged {
            self.handleInternalGroupOwnerChangedMessage(internalMessageDict, data: data, dateSend: dateSend, streamNeedsCacheUpdate: &streamNeedsCacheUpdate, in: localContext)
        }
        if let data = internalMessageDict.groupRemoved {
            self.handleInternalGroupRemovedMessage(internalMessageDict, data: data, dateSend: dateSend, ownAccountGuid: ownAccountGuid, streamNeedsCacheUpdate: &streamNeedsCacheUpdate, in: localContext)
        }
        if let data = internalMessageDict.channelRemoved {
            self.handleInternalChannelRemovedMessage(internalMessageDict, data: data, dateSend: dateSend, streamNeedsCacheUpdate: &streamNeedsCacheUpdate, in: localContext)
        }
        if let data = internalMessageDict.groupMembersNew {
            self.handleInternalGroupNewMembersMessage(internalMessageDict, data: data, dateSend: dateSend, ownAccountGuid: ownAccountGuid, streamNeedsCacheUpdate: &streamNeedsCacheUpdate, in: localContext)
        }
        if let data = internalMessageDict.groupMembersRemoved {
            self.handleInternalGroupRemovedMembersMessage(data: data, dateSend: dateSend, messageGuid: internalMessageDict.guid, ownAccountGuid: ownAccountGuid, streamNeedsCacheUpdate: &streamNeedsCacheUpdate, in: localContext)
        }
        if let data = internalMessageDict.groupMembersInvited {
            self.handleInternalGroupInvitedMembersMessage(data: data, dateSend: dateSend, messageGuid: internalMessageDict.guid, ownAccountGuid: ownAccountGuid, streamNeedsCacheUpdate: &streamNeedsCacheUpdate, in: localContext)
        }
        if let data = internalMessageDict.groupMembersAdminGranted {
            self.handleInternalGroupGrantedAdminsMessage(data: data, dateSend: dateSend, messageGuid: internalMessageDict.guid, ownAccountGuid: ownAccountGuid, streamNeedsCacheUpdate: &streamNeedsCacheUpdate, in: localContext)
        }
        if let data = internalMessageDict.groupMembersAdminRevoked {
            self.handleInternalGroupRevokedAdminsMessage(data: data, dateSend: dateSend, messageGuid: internalMessageDict.guid, ownAccountGuid: ownAccountGuid, streamNeedsCacheUpdate: &streamNeedsCacheUpdate, in: localContext)
        }
        if let data = internalMessageDict.oooMessage {
            self.handleInternalOutOfOfficeMessage(internalMessageDict, data: data, dateSend: dateSend, streamNeedsCacheUpdate: &streamNeedsCacheUpdate, in: localContext)
        }
    }

    private func addMembers(newMemberGuids: [String], toGroup groupGuid: String, senderGuid: String?, senderNick: String?, sendDate: Date, messageGuid: String, ownAccountGuid: String, in localContext: NSManagedObjectContext) -> SIMSGroupStream? {
        guard let groupStream = SIMSMessageStream.findFirst(byGuid: groupGuid, in: localContext) as? SIMSGroupStream, let group = groupStream.group else { return nil }
        var idx1 = 0
        for accountGuid in newMemberGuids {
            if senderGuid != ownAccountGuid {
                if let member = SIMSGroupMember.mr_findFirst(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSGroupMember.accountGuid), rightExpression: NSExpression(forConstantValue: accountGuid)), in: localContext) ?? SIMSGroupMember.mr_createEntity(in: localContext) {
                    member.accountGuid = accountGuid
                    member.groups?.insert(group)
                }
            }
            // since group owner is the admin who sents the invitation, but might not be the real owner, this has to be discussed
            if accountGuid == group.ownerGuid {
                // NOOP
            } else {
                let content = self.systemGroupMessageContentWithFormat("chat.group.newMember", formatWithSender: "chat.group.newMemberWithSender", accountGuid: accountGuid, senderGuid: senderGuid, senderNick: senderNick)
                DPAGApplicationFacade.messageFactory.newSystemMessage(content: content, forGroup: groupStream, sendDate: sendDate, guid: messageGuid + "\(idx1)", in: localContext)
                idx1 += 1
            }
        }
        return groupStream
    }

    private func removeMembers(memberGuidsToRemove: [String], fromGroup groupGuid: String, senderGuid: String?, senderNick: String?, sendDate: Date, messageGuid: String, ownAccountGuid: String, in localContext: NSManagedObjectContext) -> SIMSGroupStream? {
        guard let groupStream = SIMSMessageStream.findFirst(byGuid: groupGuid, in: localContext) as? SIMSGroupStream else { return nil }
        if memberGuidsToRemove.contains(ownAccountGuid) {
            if senderGuid == ownAccountGuid {
                // handled by ReceiveMessagesWorker for internal messages, sender always nil for private internal messages
            } else {
                groupStream.group?.wasDeleted = true
                DPAGApplicationFacade.messageFactory.newSystemMessage(content: DPAGLocalizedString("chat.group.wasDeleted"), forGroup: groupStream, sendDate: sendDate, guid: messageGuid, in: localContext)
            }
        } else {
            var idx1 = 0
            memberGuidsToRemove.forEach { accountGuid in
                if senderGuid != ownAccountGuid {
                    groupStream.group?.removeMember(memberGuid: accountGuid, in: localContext)
                }
                let content: String
                if senderGuid == accountGuid || senderGuid == DPAGConstantsGlobal.kSystemChatAccountGuid {
                    content = self.systemGroupMessageContentWithFormat("chat.group.removedMember", formatWithSender: "chat.group.removedMemberWithSender", accountGuid: accountGuid, senderGuid: nil, senderNick: nil)
                } else {
                    content = self.systemGroupMessageContentWithFormat("chat.group.removedMember", formatWithSender: "chat.group.removedMemberWithSender", accountGuid: accountGuid, senderGuid: senderGuid, senderNick: senderNick)
                }
                DPAGApplicationFacade.messageFactory.newSystemMessage(content: content, forGroup: groupStream, sendDate: sendDate, guid: messageGuid + "\(idx1)", in: localContext)
                idx1 += 1
            }
        }
        return groupStream
    }

    private func systemGroupMessageContentWithFormat(_ format: String, formatWithSender: String, accountGuid: String, senderGuid: String?, senderNick: String?) -> String {
        let content: String
        if let senderGuid = senderGuid {
            let formatContent = DPAGLocalizedString(formatWithSender)
            let senderGuidWithNick: String
            if let senderNick = senderNick {
                senderGuidWithNick = String(format: "%@|%@|", senderGuid, senderNick)
            } else {
                senderGuidWithNick = senderGuid
            }
            content = String(format: formatContent, accountGuid, senderGuidWithNick)
        } else {
            let formatContent = DPAGLocalizedString(format)

            content = String(format: formatContent, accountGuid)
        }
        return content
    }

    private func handleGroupMessage(_ groupMessageDict: DPAGMessageReceivedGroup, ownAccountGuid: String, contactsCreated: inout [String: SIMSContactIndexEntry], streamNeedsCacheUpdate: inout [String: SIMSMessageStream], in localContext: NSManagedObjectContext) {
        guard let groupStream = SIMSMessageStream.findFirst(byGuid: groupMessageDict.toAccountGuid, in: localContext) as? SIMSGroupStream else { return }
        guard let message = self.newGroupMessage(groupMessageDict, groupStream: groupStream, ownAccountGuid: ownAccountGuid, contactsCreated: &contactsCreated, in: localContext) else { return }
        if let streamGuid = message.stream?.guid {
            streamNeedsCacheUpdate[streamGuid] = message.stream
        }
    }

    private func handleGroupInvitationMessage(_ messageGroupInvitation: DPAGMessageReceivedGroupInvitation, ownAccountGuid: String, contactsCreated: inout [String: SIMSContactIndexEntry], in localContext: NSManagedObjectContext) {
        guard let message = DPAGApplicationFacade.messageFactory.newPrivateMessage(messageDict: messageGroupInvitation, in: localContext) else { return }
        if let decryptedDictionary = message.decryptedMessageDictionary(), decryptedDictionary.nick != nil {
            _ = self.checkContact(for: message, ownAccountGuid: ownAccountGuid, contactsCreated: &contactsCreated, in: localContext)
        }
        message.mr_deleteEntity(in: localContext)
        guard let groupStream = DPAGApplicationFacade.messageFactory.handle(groupInvitation: messageGroupInvitation, in: localContext) else { return }
        groupStream.optionsStream = groupStream.optionsStream.union(messageGroupInvitation.messagePriorityHigh ? [.hasUnreadMessages, .hasUnreadHighPriorityMessages] : [.hasUnreadMessages])
        switch groupStream.group?.typeGroup ?? DPAGGroupType.default {
            case .managed, .restricted:
                groupStream.optionsStream = groupStream.optionsStream.subtracting(.hasUnreadMessages)
            default:
                if messageGroupInvitation.fromAccountInfo.accountGuid == ownAccountGuid {
                    groupStream.optionsStream = groupStream.optionsStream.subtracting(.hasUnreadMessages)
                    groupStream.group?.isConfirmed = true
                }
        }
    }

    private func checkContact(for message: SIMSMessage, ownAccountGuid: String, contactsCreated: inout [String: SIMSContactIndexEntry], in localContext: NSManagedObjectContext) -> SIMSContactIndexEntry? {
        var isOwnMessage = false
        var accountGuid = message.fromAccountGuid ?? "???"
        var autoConfidence = false
        if accountGuid == ownAccountGuid {
            if let isPrivateMessage = message as? SIMSPrivateMessage, let toAccountGuid = isPrivateMessage.toAccountGuid {
                accountGuid = toAccountGuid
                // message probably written from a different device or share extension
                autoConfidence = true
            }
            isOwnMessage = true
        }
        var contact: SIMSContactIndexEntry?
        if accountGuid.isSystemChatGuid {
            contact = DPAGSystemChat.systemChat(in: localContext)
        } else {
            contact = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext)
            if contact == nil {
                contact = contactsCreated[accountGuid]
                if contact == nil, let decryptedDictionary = message.decryptedMessageDictionary() {
                    // create dummy contact and with dummy stream
                    var dummyAccountDict: [AnyHashable: Any] = [SIMS_GUID: accountGuid, SIMS_PUBLIC_KEY: ""]
                    if let phone = decryptedDictionary.phone {
                        dummyAccountDict[SIMS_PHONE] = phone
                    }
                    if let contactCreated = DPAGApplicationFacade.contactFactory.newModel(accountJson: dummyAccountDict, in: localContext) {
                        contact = contactCreated
                        if !isOwnMessage {
                            if let nickName = decryptedDictionary.nick, nickName.isEmpty == false {
                                contactCreated[.NICKNAME] = nickName
                            }
                            if let profilKey = decryptedDictionary.profilKey {
                                contactCreated[.PROFIL_KEY] = profilKey
                            }
                        }
                        contactsCreated[accountGuid] = contactCreated
                    }
                }
            } else if let contactDB = contact {
                var decryptedDictionary = message.decryptedMessageDictionary()
                if !isOwnMessage {
                    // received from local addressbook contact
                    if contactDB.entryTypeLocal == .privat {
                        autoConfidence = true
                    }
                    if contactDB[.PHONE_NUMBER]?.isEmpty ?? true {
                        contactDB[.PHONE_NUMBER] = decryptedDictionary?.phone
                    }
                    if contactDB[.PROFIL_KEY]?.isEmpty ?? true, let profilKey = decryptedDictionary?.profilKey {
                        contactDB[.PROFIL_KEY] = profilKey
                    }
                }
                if decryptedDictionary == nil {
                    decryptedDictionary = message.decryptedMessageDictionary()
                }
                if !isOwnMessage, let nickName = decryptedDictionary?.nick, nickName.isEmpty == false, nickName != contactDB[.NICKNAME] {
                    contactDB[.NICKNAME] = nickName
                }
            }
        }
        if let contactDB = contact {
            DPAGApplicationFacade.cache.loadContact(contact: contactDB)
            if autoConfidence {
                contactDB.confirmAndConfide()
            }
        }
        return contact
    }

    private func newGroupMessage(_ messageDict: DPAGMessageReceivedGroup, groupStream: SIMSGroupStream, ownAccountGuid: String, contactsCreated: inout [String: SIMSContactIndexEntry], in localContext: NSManagedObjectContext) -> SIMSGroupMessage? {
        guard let message = DPAGApplicationFacade.messageFactory.newGroupMessage(messageDict: messageDict, groupStream: groupStream, in: localContext) else { return nil }
        _ = self.checkContact(for: message, ownAccountGuid: ownAccountGuid, contactsCreated: &contactsCreated, in: localContext)
        return message
    }

    private func handleChannelMessage(_ channelMessageDict: DPAGMessageReceivedChannel, streamNeedsCacheUpdate: inout [String: SIMSMessageStream], saveResult _: inout SaveResult, in localContext: NSManagedObjectContext) {
        guard let message = self.newChannelMessage(channelMessageDict, in: localContext) else { return }
        if let stream = message.stream as? SIMSChannelStream {
            if let streamGuid = stream.guid {
                streamNeedsCacheUpdate[streamGuid] = stream
            }
            stream.optionsStream = stream.optionsStream.union(.hasUnreadMessages)
        } else {
            message.mr_deleteEntity(in: localContext)
        }
    }

    private func newChannelMessage(_ messageDict: DPAGMessageReceivedChannel, in localContext: NSManagedObjectContext) -> SIMSChannelMessage? {
        DPAGApplicationFacade.messageFactory.newChannelMessage(messageDict: messageDict, in: localContext)
    }

    private func handleTimedMessageSendConfirmation(_ messageConfirmSend: DPAGMessageReceivedConfirmTimedMessageSend, streamNeedsCacheUpdate: inout [String: SIMSMessageStream], in localContext: NSManagedObjectContext) {
        if let messageToSend = SIMSMessageToSend.findFirst(byGuid: messageConfirmSend.sendGuid, in: localContext) {
            if let message = DPAGApplicationFacade.messageFactory.confirmSend(messageToSend: messageToSend, withConfirmation: messageConfirmSend, in: localContext), let stream = message.stream, let streamGuid = stream.guid {
                streamNeedsCacheUpdate[streamGuid] = stream
                stream.optionsStream = stream.optionsStream.union(message.optionsMessage.contains(.priorityHigh) ? [.hasUnreadMessages, .hasUnreadHighPriorityMessages] : [.hasUnreadMessages])
                DPAGApplicationFacade.cache.removeMessage(guid: messageToSend.guid)
            } else {
                messageToSend.mr_deleteEntity(in: localContext)
            }
        }
    }

    private func handlePrivateMessage(_ privateMessageDict: DPAGMessageReceivedPrivate, ownAccountGuid: String, contactsCreated: inout [String: SIMSContactIndexEntry], streamNeedsCacheUpdate: inout [String: SIMSMessageStream], in localContext: NSManagedObjectContext) {
        // no private message (no stream) from own account
        guard let message = self.newPrivateMessage(privateMessageDict, ownAccountGuid: ownAccountGuid, contactsCreated: &contactsCreated, in: localContext) else { return }
        if let streamGuid = message.stream?.guid {
            streamNeedsCacheUpdate[streamGuid] = message.stream
        }
    }

    private func newPrivateMessage(_ messageDict: DPAGMessageReceivedPrivate, ownAccountGuid: String, contactsCreated: inout [String: SIMSContactIndexEntry], in localContext: NSManagedObjectContext) -> SIMSPrivateMessage? {
        guard let message = DPAGApplicationFacade.messageFactory.newPrivateMessage(messageDict: messageDict, in: localContext) else { return nil }
        let contact = self.checkContact(for: message, ownAccountGuid: ownAccountGuid, contactsCreated: &contactsCreated, in: localContext)
        if (message.messageOrderId?.intValue ?? 0) == 0 {
            message.messageOrderId = NSNumber(value: ((contact?.stream?.messages?.lastObject as? SIMSMessage)?.messageOrderId?.int64Value ?? 0) + 1)
            message.stream = contact?.stream
            message.stream?.lastMessageDate = message.dateSendServer
        }
        if messageDict.fromAccountInfo.accountGuid == ownAccountGuid {} else {
            let streamOption = message.stream?.optionsStream ?? []
            message.stream?.optionsStream = streamOption.union(messageDict.messagePriorityHigh ? [.hasUnreadHighPriorityMessages, .hasUnreadMessages] : [.hasUnreadMessages])
        }
        return message
    }

    func filterChannelsForUnsubscribe(channelGuids: Set<String>) -> ReceiveMessageDAOChannelUnsubscribeFilterResult {
        var channelsToUnsubscribe: Set<String> = Set()
        var servicesToUnsubscribe: Set<String> = Set()
        DPAGApplicationFacade.persistance.loadWithBlock { localContext in
            for channelGuid in channelGuids {
                if let channel = SIMSChannel.findFirst(byGuid: channelGuid, in: localContext), channel.stream == nil, (channel.subscribed?.boolValue ?? false) == false {
                    switch channel.validFeedType {
                        case .channel:
                            channelsToUnsubscribe.insert(channelGuid)
                    }
                }
            }
        }
        return ReceiveMessageDAOChannelUnsubscribeFilterResult(channelsToUnsubscribe: channelsToUnsubscribe, servicesToUnsubscribe: servicesToUnsubscribe)
    }

    func filterContactGuidsForUnknown(contactGuids: Set<String>) -> Set<String> {
        var contactGuidsUnknown: Set<String> = contactGuids
        DPAGApplicationFacade.persistance.loadWithBlock { localContext in
            let predicate = NSPredicate(format: "guid in %@", contactGuids)
            guard let contactsKnown = SIMSContactIndexEntry.mr_findAll(with: predicate, in: localContext) else { return }
            let contactGuidsKnown = contactsKnown.compactMap { ($0 as? SIMSContactIndexEntry)?.guid }
            contactGuidsUnknown.subtract(contactGuidsKnown)
        }
        return contactGuidsUnknown
    }
}
