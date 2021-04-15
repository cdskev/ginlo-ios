//
//  MessagesDAO.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 07.08.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

struct MessagesDAOAutoDownloadAttachments {
    let attachmentGuidsFoto: [String: String]
    let attachmentGuidsAudio: [String: String]
    let attachmentGuidsVideo: [String: String]
    let attachmentGuidsFile: [String: String]
}

protocol MessagesDAOProtocol {
    func setIsAttachmentAutomaticDownload(messageGuid: String)
    func setIsUnableToLoadAttachment(messageGuid: String)

    func loadAutoDownloadAttachments(contentTypeFilter: @escaping (DPAGMessageContentType) -> Bool) throws -> MessagesDAOAutoDownloadAttachments

    func deleteMessageInstances(msgInstancesGuids: [String])
    func loadMessageStreamInfos(streamGuid: String, ownAccountGuid: String) -> MessageStreamInfos
    func saveMessageAttributes(streamGuid: String, ownAccountGuid: String, dateNow: Date) -> [String]
    func readMessages(guids: [String], date: Date)
    func fetchUnreadMessageServerGuids(streamGuid: String, chatGuid: String?) -> [String]
    func fetchUnreadMessageServerToConfirm(unreadServerMessageGuids: [String], dateNow: Date) -> [String]
    func sendSystemMessage(toStreamGuid streamGuid: String, content: String)
    func fetchStreamsForwarding() -> [DPAGContact]
    func getExistingStreamGuid(withStreamGuid streamGuid: String) -> String?
    func deleteNormalAndTimedMessages(forStreamGuid streamGuid: String)
    func deleteNormalMessages(forStreamGuid streamGuid: String)
    func getTimeMessagesGuids(streamGuid: String) -> [String]
}

class MessagesDAO: MessagesDAOProtocol {
    func setIsAttachmentAutomaticDownload(messageGuid: String) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            if let msgs = SIMSMessage.findFirst(byGuid: messageGuid, in: localContext) {
                msgs.setAdditionalData(key: "isAttachmentAutomaticDownload", value: "true")
            }
        }
    }

    func setIsUnableToLoadAttachment(messageGuid: String) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            if let msgs = SIMSMessage.findFirst(byGuid: messageGuid, in: localContext) {
                msgs.setAdditionalData(key: "unable_to_load_attachment", value: "true")
            }
        }
    }

    func loadAutoDownloadAttachments(contentTypeFilter: @escaping (DPAGMessageContentType) -> Bool) throws -> MessagesDAOAutoDownloadAttachments {
        var attachmentGuidsFoto: [String: String] = [:]
        var attachmentGuidsAudio: [String: String] = [:]
        var attachmentGuidsVideo: [String: String] = [:]
        var attachmentGuidsFile: [String: String] = [:]

        try DPAGApplicationFacade.persistance.loadWithError { localContext in

            let pred = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.attachment), rightNotExpression: NSExpression(forConstantValue: nil)),
                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.dateReadServer), rightExpression: NSExpression(forConstantValue: nil)),
                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.attributes?.dateReadServer), rightExpression: NSExpression(forConstantValue: nil))
            ])

            let fetchRequest = NSFetchRequest<SIMSMessage>(entityName: SIMSMessage.mr_entityName())

            fetchRequest.predicate = pred
            fetchRequest.propertiesToFetch = [SIMS_ATTACHMENT, SIMS_GUID, "additionalData"]

            let msgs = try localContext.fetch(fetchRequest)

            for msg in msgs {
                if let msgGuid = msg.guid, let attachmentGuid = msg.attachment, AttachmentHelper.attachmentAlreadySavedForGuid(attachmentGuid) == false,
                    let additionalContentTypeData = msg.getAdditionalData(key: "contentType"), msg.getAdditionalData(key: "unable_to_load_attachment") == nil {
                    let contentType = DPAGMessageContentType.contentType(for: additionalContentTypeData)

                    guard contentTypeFilter(contentType) else {
                        continue
                    }

                    switch contentType {
                    case .image:
                        attachmentGuidsFoto[msgGuid] = attachmentGuid
                    case .voiceRec:
                        attachmentGuidsAudio[msgGuid] = attachmentGuid
                    case .video:
                        attachmentGuidsVideo[msgGuid] = attachmentGuid
                    case .file:
                        attachmentGuidsFile[msgGuid] = attachmentGuid
                    default:
                        break
                    }
                }
            }
        }

        return MessagesDAOAutoDownloadAttachments(attachmentGuidsFoto: attachmentGuidsFoto, attachmentGuidsAudio: attachmentGuidsAudio, attachmentGuidsVideo: attachmentGuidsVideo, attachmentGuidsFile: attachmentGuidsFile)
    }

    func loadMessageStreamInfos(streamGuid: String, ownAccountGuid: String) -> MessageStreamInfos {
        var messageStreamInfos = MessageStreamInfos(chatGuid: streamGuid, foundUnreadMessage: false)

        DPAGApplicationFacade.persistance.loadWithBlock { localContext in
            guard let stream = SIMSMessageStream.findFirst(byGuid: streamGuid, in: localContext) else { return }
            messageStreamInfos.chatGuid = self.fetchChatGuid(stream: stream)
            messageStreamInfos.foundUnreadMessage = self.foundUnreadMessage(stream: stream, ownAccountGuid: ownAccountGuid)
        }

        return messageStreamInfos
    }

    private func fetchChatGuid(stream: SIMSMessageStream) -> String? {
        var chatGuid: String?
        if let streamPrivate = stream as? SIMSStream {
            chatGuid = streamPrivate.contactIndexEntry?.guid
        } else if let streamGroup = stream as? SIMSGroupStream {
            chatGuid = streamGroup.group?.guid
        }
        return chatGuid
    }

    private func foundUnreadMessage(stream: SIMSMessageStream, ownAccountGuid: String) -> Bool {
        var foundUnreadMessage = stream.optionsStream.contains(.hasUnreadMessages)

        if foundUnreadMessage == false,
            let messages = stream.messages {
            for msgObj in messages {
                if let msg = msgObj as? SIMSMessage, ownAccountGuid != msg.fromAccountGuid, msg.attributes?.dateReadLocal == nil {
                    foundUnreadMessage = true
                    break
                }
            }
        }
        return foundUnreadMessage
    }

    func deleteMessageInstances(msgInstancesGuids: [String]) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            for guidOutgoingMessage in msgInstancesGuids {
                if let msg = SIMSMessage.findFirst(byGuid: guidOutgoingMessage, in: localContext) {
                    msg.mr_deleteEntity(in: localContext)
                } else if let msg = SIMSMessageToSend.findFirst(byGuid: guidOutgoingMessage, in: localContext) {
                    msg.mr_deleteEntity(in: localContext)
                }
            }
        }
    }

    func saveMessageAttributes(streamGuid: String, ownAccountGuid: String, dateNow: Date) -> [String] {
        var result = [String]()
        DPAGApplicationFacade.persistance.saveWithBlock { localContextSave in

            guard let streamSave = SIMSMessageStream.findFirst(byGuid: streamGuid, in: localContextSave) else { return }

            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.fromAccountGuid), rightNotExpression: NSExpression(forConstantValue: ownAccountGuid)),
                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.attributes?.dateReadLocal), rightExpression: NSExpression(forConstantValue: nil))
            ])

            streamSave.options = NSNumber(value: streamSave.optionsStream.subtracting([.hasUnreadMessages, .hasUnreadHighPriorityMessages]).rawValue)

            let messagesDict = streamSave.messages?.filtered(using: predicate)
                .compactMap { $0 as? SIMSMessage }
                .reduce(into: [String: SIMSMessage](), {
                    if let guid = $1.guid {
                        $0[guid] = $1
                    }
                })

            if let messagesDict = messagesDict {
                messagesDict.forEach {
                    self.saveSingleMessageAttributes(message: $0.value, context: localContextSave, dateNow: dateNow)
                    result.append($0.key)
                }
            }

            let decStream = DPAGApplicationFacade.cache.decryptedStream(stream: streamSave, in: localContextSave)

            decStream?.newMessagesCount = 0
            decStream?.hasUnreadHighPriorityMessages = false
        }
        return result
    }

    private func saveSingleMessageAttributes(message: SIMSMessage, context: NSManagedObjectContext, dateNow: Date) {
        if message.attributes == nil {
            message.attributes = SIMSMessageAttributes.mr_createEntity(in: context)
        }

        message.attributes?.dateReadLocal = dateNow

        DPAGApplicationFacade.cache.decryptedMessage(message, in: context)?.updateReadLocal(withDate: dateNow)
    }

    func readMessages(guids: [String], date: Date) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            for messageGuid in guids {
                self.readMessage(messageGuid: messageGuid, localContextSave: localContext, dateNow: date)
            }
        }
    }

    private func readMessage(messageGuid: String, localContextSave: NSManagedObjectContext, dateNow: Date) {
        guard let unreadMessage = SIMSMessage.findFirst(byGuid: messageGuid, in: localContextSave), unreadMessage.attachment == nil else { return }

        if unreadMessage.attributes == nil {
            unreadMessage.attributes = SIMSMessageAttributes.mr_createEntity(in: localContextSave)
        }

        if unreadMessage.attributes?.dateDownloaded != nil {
            unreadMessage.attributes?.dateReadServer = dateNow

            DPAGApplicationFacade.cache.decryptedMessageFast(messageGuid: messageGuid)?.updateRead(withDate: dateNow)
        } else {
            unreadMessage.attributes?.dateDownloaded = dateNow
            unreadMessage.attributes?.dateReadServer = dateNow

            if let decMessage = DPAGApplicationFacade.cache.decryptedMessageFast(messageGuid: messageGuid) {
                decMessage.updateRead(withDate: dateNow)
                decMessage.updateDownloaded(withDate: dateNow)
            }
        }
    }

    func fetchUnreadMessageServerGuids(streamGuid: String, chatGuid: String?) -> [String] {
        var unreadServerMessageGuids: [String] = []

        DPAGApplicationFacade.persistance.loadWithBlock { localContext in
            if let unreadMessagesServer = self.fetchUnreadServerMessageGuids(streamGuid: streamGuid, chatGuid: chatGuid, in: localContext) {
                unreadServerMessageGuids = unreadMessagesServer
            }
        }

        return unreadServerMessageGuids
    }

    private func fetchUnreadServerMessageGuids(streamGuid: String, chatGuid: String?, in localContext: NSManagedObjectContext) -> [String]? {
        guard let ownAccountGuid = DPAGApplicationFacade.cache.account?.guid else { return nil }

        let predicate: NSCompoundPredicate

        if let chatGuid = chatGuid, chatGuid.isSystemChatGuid {
            predicate = prepareSystemChatMessagePredicate(streamGuid: streamGuid)
        } else {
            predicate = prepareNormalChatMesagePredicate(streamGuid: streamGuid, ownAccountGuid: ownAccountGuid)
        }

        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: SIMSMessage.mr_entityName())

        fetchRequest.predicate = predicate
        fetchRequest.propertiesToFetch = [SIMS_GUID]
        fetchRequest.resultType = .dictionaryResultType

        do {
            return try localContext.fetch(fetchRequest).compactMap { $0[SIMS_GUID] as? String }
        } catch {
            DPAGLog(error)
            return []
        }
    }

    private func prepareSystemChatMessagePredicate(streamGuid: String) -> NSCompoundPredicate {
        NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.stream?.guid), rightExpression: NSExpression(forConstantValue: streamGuid)),
            NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.dateReadServer), rightExpression: NSExpression(forConstantValue: nil)),
            NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.attributes?.dateReadServer), rightExpression: NSExpression(forConstantValue: nil)),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.errorType), rightExpression: NSExpression(forConstantValue: DPAGMessageSecurityError.none.rawValue)),
                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.errorType), rightExpression: NSExpression(forConstantValue: DPAGMessageSecurityError.notChecked.rawValue))
            ])
        ])
    }

    private func prepareNormalChatMesagePredicate(streamGuid: String, ownAccountGuid: String) -> NSCompoundPredicate {
        NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.stream?.guid), rightExpression: NSExpression(forConstantValue: streamGuid)),
            NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.fromAccountGuid), rightNotExpression: NSExpression(forConstantValue: DPAGConstantsGlobal.kSystemChatAccountGuid)),
            NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.fromAccountGuid), rightNotExpression: NSExpression(forConstantValue: ownAccountGuid)),
            NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.dateReadServer), rightExpression: NSExpression(forConstantValue: nil)),
            NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.attributes?.dateReadServer), rightExpression: NSExpression(forConstantValue: nil)),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.errorType), rightExpression: NSExpression(forConstantValue: DPAGMessageSecurityError.none.rawValue)),
                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.errorType), rightExpression: NSExpression(forConstantValue: DPAGMessageSecurityError.notChecked.rawValue))
            ])
        ])
    }

    func fetchUnreadMessageServerToConfirm(unreadServerMessageGuids: [String], dateNow: Date) -> [String] {
        var unreadMessagesServerConfirm: [String] = []

        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            for messageGuid in unreadServerMessageGuids {
                if messageGuid.hasPrefix(.messageChannel) || messageGuid.hasPrefix(.messageService) {
                    self.readMessage(messageGuid: messageGuid, localContextSave: localContext, dateNow: dateNow)
                } else {
                    unreadMessagesServerConfirm.append(messageGuid)
                }
            }
        }
        return unreadMessagesServerConfirm
    }

    func sendSystemMessage(toStreamGuid streamGuid: String, content: String) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            guard let stream = SIMSMessageStream.findFirst(byGuid: streamGuid, in: localContext) as? SIMSStream else {
                return
            }

            DPAGApplicationFacade.messageFactory.newSystemMessage(content: content, forChat: stream, sendDate: Date(), guid: nil, in: localContext)
        }
    }

    func fetchStreamsForwarding() -> [DPAGContact] {
        let fetchRequest = prepareFetchRequestStreamsForwarding()
        let fetchContext = NSManagedObjectContext.mr_backgroundFetch()
        var streamsForward: [DPAGContact] = []

        fetchContext.performAndWait {
            do {
                let chatStreams = try fetchContext.fetch(fetchRequest)

                for stream in chatStreams {
                    guard let streamPrivate = stream as? SIMSStream else { continue }
                    if DPAGSystemChat.isSystemChat(streamPrivate) {
                        continue
                    }

                    if let contactDB = streamPrivate.contactIndexEntry, let contactGuid = contactDB.guid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid, contactDB: contactDB), contact.isDeleted == false, contact.isReadOnly == false, contact.isConfirmed == true {
                        streamsForward.append(contact)
                    }
                }
            } catch let error as NSError {
                DPAGLog(error, message: "fetching chats error")
            }
        }

        return streamsForward
    }

    private func prepareFetchRequestStreamsForwarding() -> NSFetchRequest<SIMSMessageStream> {
        let fetchRequest = NSFetchRequest<SIMSMessageStream>(entityName: SIMSMessageStream.entityName())

        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SIMSMessageStream.lastMessageDate, ascending: false)]

        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageStream.streamType), rightExpression: NSExpression(forConstantValue: DPAGStreamType.single.rawValue)),
                // NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageStream.isConfirmed), rightExpression: NSExpression(forConstantValue: true)),
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageStream.wasDeleted), rightExpression: NSExpression(forConstantValue: nil)),
                    NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageStream.wasDeleted), rightExpression: NSExpression(forConstantValue: false))
                ]),
                NSPredicate(format: "(options & \(DPAGStreamOption.blocked.rawValue)) <> \(DPAGStreamOption.blocked.rawValue)"),
                NSPredicate(format: "(options & \(DPAGStreamOption.isReadOnly.rawValue)) <> \(DPAGStreamOption.isReadOnly.rawValue)"),
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "messages.@count > 0"),
                    NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageStream.lastMessageDate), rightNotExpression: NSExpression(forConstantValue: nil))
                ])
            ])
        ])

        return fetchRequest
    }

    func getExistingStreamGuid(withStreamGuid streamGuid: String) -> String? {
        var result: String?
        DPAGApplicationFacade.persistance.loadWithBlock { localContext in
            result = SIMSStream.findFirst(byGuid: streamGuid, in: localContext)?.guid
        }
        return result
    }

    func deleteNormalAndTimedMessages(forStreamGuid streamGuid: String) {
        self.deleteTimedMessages(forStreamGuid: streamGuid)
        self.deleteNormalMessages(forStreamGuid: streamGuid)
    }

    private func getStreamTimedMessagesPredicate(streamGuid: String) -> NSComparisonPredicate {
        NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageToSend.streamGuid), rightExpression: NSExpression(forConstantValue: streamGuid))
    }

    private func deleteTimedMessages(forStreamGuid streamGuid: String) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            let streamTimedMessagesPredicate = self.getStreamTimedMessagesPredicate(streamGuid: streamGuid)
            guard let timedMessages = SIMSMessageToSend.mr_findAll(with: streamTimedMessagesPredicate, in: localContext) as? [SIMSMessageToSend] else {
                return
            }

            timedMessages.forEach {
                DPAGApplicationFacade.persistance.deleteMessage($0, in: localContext)
            }
        }
    }

    func getTimeMessagesGuids(streamGuid: String) -> [String] {
        var timedMessageGuids: [String] = []
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            let streamTimedMessagesPredicate = self.getStreamTimedMessagesPredicate(streamGuid: streamGuid)
            let messagesRequest = SIMSMessageToSend.mr_requestAll(with: streamTimedMessagesPredicate, in: localContext)

            messagesRequest.propertiesToFetch = ["guid"]
            messagesRequest.resultType = .dictionaryResultType

            do {
                guard let timedMessages = try localContext.fetch(messagesRequest) as? [[String: String]] else {
                    return
                }

                timedMessages.forEach {
                    timedMessageGuids.append(contentsOf: $0.values)
                }
            } catch {
                DPAGLog(error)
            }
        }
        return timedMessageGuids
    }

    func deleteNormalMessages(forStreamGuid streamGuid: String) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            guard let stream = SIMSMessageStream.findFirst(byGuid: streamGuid, in: localContext) else {
                return
            }

            self.deleteNormalMessages(forStream: stream, context: localContext)
            DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: streamGuid, stream: stream, in: localContext)
        }
    }

    private func deleteNormalMessages(forStream stream: SIMSMessageStream, context: NSManagedObjectContext) {
        if let messages = stream.messages {
            for message in Array(messages) {
                if let msg = message as? SIMSMessage {
                    DPAGApplicationFacade.persistance.deleteMessage(msg, in: context)
                }
            }
        }

        stream.messages = NSOrderedSet()
        stream.lastMessageDate = nil
    }
}

struct MessageStreamInfos {
    var chatGuid: String?
    var foundUnreadMessage: Bool
}
