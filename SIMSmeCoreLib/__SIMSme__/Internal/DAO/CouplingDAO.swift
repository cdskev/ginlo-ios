//
//  CouplingDAO.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 29.08.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

// will change with new server API
struct CouplingDAOPrivateIndexServerEntryDecrypted {
    let accountGuid: String
    let checksum: String?
    let guid: String?
    let dateModified: Date?
    let innerDict: [AnyHashable: Any]
    let jsonDataDict: [AnyHashable: Any]
}

protocol CouplingDAOProtocol {
    func getPendingMessageGuidsForPreview() -> [String]
    func getPendingMessageGuids() throws -> [String]

    @discardableResult
    func savePendingMessages(messages: [[AnyHashable: Any]]) -> [String]

    func removeRemovablePendingMessageGuids(removableGuids: [String])

    func getContactInformationForPrivateIndexSave() -> [String: [String: String]]

    func updateContactChecksums(contactChecksums: [String: String])

    func savePrivateIndexServerEntries(serverContacts: [CouplingDAOPrivateIndexServerEntryDecrypted], forceLoad: Bool) throws -> Set<String>

    func checkForChangesOnContacts(contactPrivateIndexGuidsAndServerChecksums: [String: String]) throws -> (foundAllGuids: Bool, foundLocalChanges: Bool)
}

class CouplingDAO: CouplingDAOProtocol {
    func getPendingMessageGuidsForPreview() -> [String] {
        var pendingGuids: [String] = []

        DPAGApplicationFacade.persistance.loadWithBlock { localContext in

            guard let streams = SIMSMessageStream.mr_findAll(in: localContext) as? [SIMSMessageStream] else {
                return
            }

            pendingGuids = streams.compactMap { $0.messages?.lastObject as? SIMSMessage }.filter { $0.data == nil }.compactMap { $0.guid }
        }

        return pendingGuids
    }

    @discardableResult
    func savePendingMessages(messages: [[AnyHashable: Any]]) -> [String] {
        var foundGuids: [String] = []

        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            // Nachrichten verarbeiten

            var dictStreams: [String: SIMSMessageStream] = [:]

            for dictMessage in messages {
                if let dictMessagePrivate = dictMessage[DPAGStrings.JSON.MessagePrivate.OBJECT_KEY] as? [AnyHashable: Any] {
                    if let messagePrivateReceived = try? DictionaryDecoder().decode(DPAGMessageReceivedPrivate.self, from: dictMessagePrivate),
                        let messagePrivate = DPAGApplicationFacade.messageFactory.newPrivateMessage(messageDict: messagePrivateReceived, in: localContext),
                        let messagePrivateGuid = messagePrivate.guid {
                        foundGuids.append(messagePrivateGuid)

                        // a pending message always already existed in database, so we don't need to set the stream after the factory call
                        if let streamGuid = messagePrivate.stream?.guid {
                            dictStreams[streamGuid] = messagePrivate.stream
                        }
                    }
                }

                if let dictMessageGroup = dictMessage[DPAGStrings.JSON.MessageGroup.OBJECT_KEY] as? [AnyHashable: Any] {
                    if let messageGroup = try? DictionaryDecoder().decode(DPAGMessageReceivedGroup.self, from: dictMessageGroup),
                        let group = SIMSGroup.findFirst(byGuid: messageGroup.toAccountGuid, in: localContext),
                        let stream = group.stream,
                        let groupMessage = DPAGApplicationFacade.messageFactory.newGroupMessage(messageDict: messageGroup, groupStream: stream, in: localContext),
                        let groupMessageGuid = groupMessage.guid {
                        foundGuids.append(groupMessageGuid)

                        if let streamGuid = stream.guid {
                            dictStreams[streamGuid] = stream
                        }
                    }
                }
            }

            for stream in dictStreams.values {
                let hasNewMessages = stream.countNewMessages() > 0

                if hasNewMessages {
                    stream.optionsStream = stream.optionsStream.union(.hasUnreadMessages)
                } else {
                    stream.optionsStream = stream.optionsStream.subtracting(.hasUnreadMessages)
                }

                DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: stream.guid, stream: stream, in: localContext)
            }
        }

        return foundGuids
    }

    func getPendingMessageGuids() throws -> [String] {
        var pendingMessageGuids: [String] = []
        let FETCH_LIMIT = 30

        try DPAGApplicationFacade.persistance.loadWithError { localContext in

            let pendingMessageGuidsPrivate = try self.fetchPendingMessageGuidsPrivate(limit: FETCH_LIMIT, in: localContext)

            guard pendingMessageGuidsPrivate.isEmpty else {
                pendingMessageGuids = pendingMessageGuidsPrivate
                return
            }

            let pendingMessageGuidsGroup = try self.fetchPendingMessageGuidsGroup(limit: FETCH_LIMIT, in: localContext)

            pendingMessageGuids = pendingMessageGuidsGroup
        }

        return pendingMessageGuids
    }

    private func fetchPendingMessageGuidsPrivate(limit: Int, in localContext: NSManagedObjectContext) throws -> [String] {
        let predicate = NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSPrivateMessage.data), rightExpression: NSExpression(forConstantValue: nil))

        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: SIMSPrivateMessage.mr_entityName())

        fetchRequest.predicate = predicate
        fetchRequest.fetchLimit = limit
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = [SIMS_GUID]

        let pendingPrivateMessages = try localContext.fetch(fetchRequest)

        let pendingMessageGuids = pendingPrivateMessages.compactMap({ $0[SIMS_GUID] as? String })

        return pendingMessageGuids
    }

    private func fetchPendingMessageGuidsGroup(limit: Int, in localContext: NSManagedObjectContext) throws -> [String] {
        let predicateGroup = NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSGroupMessage.data), rightExpression: NSExpression(forConstantValue: nil))

        let fetchRequestGroup = NSFetchRequest<NSDictionary>(entityName: SIMSGroupMessage.mr_entityName())

        fetchRequestGroup.predicate = predicateGroup
        fetchRequestGroup.fetchLimit = limit
        fetchRequestGroup.resultType = .dictionaryResultType
        fetchRequestGroup.propertiesToFetch = [SIMS_GUID]

        let pendingGroupMessages = try localContext.fetch(fetchRequestGroup)

        let pendingMessageGuids: [String] = pendingGroupMessages.compactMap {
            guard let messageGuid = $0[SIMS_GUID] as? String, messageGuid.hasSuffix("}") else {
                return nil
            }
            return messageGuid
        }

        return pendingMessageGuids
    }

    func removeRemovablePendingMessageGuids(removableGuids: [String]) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            for messageGuid in removableGuids {
                guard let msg = SIMSMessage.findFirst(byGuid: messageGuid, in: localContext) else {
                    continue
                }

                msg.mr_deleteEntity(in: localContext)
            }
        }
    }

    func getContactInformationForPrivateIndexSave() -> [String: [String: String]] {
        var contactDicts: [String: [String: String]] = [:]

        do {
            try DPAGApplicationFacade.persistance.saveWithError { localContext in

                let allContacts = try SIMSContactIndexEntry.findAll(in: localContext)

                for contact in allContacts {
                    guard contact.entryTypeServer == .privat || contact.entryTypeServer == .meMyselfAndI,
                        let contactGuid = contact.guid,
                        contactGuid.isSystemChatGuid == false,
                        contact.shouldSaveServer,
                        contact.serverChecksum?.isEmpty ?? false else {
                        continue
                    }

                    do {
                        guard let dict = try contact.exportServer() else {
                            continue
                        }

                        contactDicts[contactGuid] = dict
                    } catch {
                        DPAGLog(error)
                    }
                }
            }
        } catch {
            DPAGLog(error)
        }

        return contactDicts
    }

    func updateContactChecksums(contactChecksums: [String: String]) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            contactChecksums.forEach { key, value in

                guard let contact = SIMSContactIndexEntry.findFirst(byGuid: key, in: localContext) else {
                    return
                }

                contact.serverChecksum = value
            }
        }
    }

    func savePrivateIndexServerEntries(serverContacts: [CouplingDAOPrivateIndexServerEntryDecrypted], forceLoad: Bool) throws -> Set<String> {
        var privateIndexGuidsToDelete: Set<String> = Set()

        try DPAGApplicationFacade.persistance.saveWithError { localContext in

            for entry in serverContacts {
                if let existingEntry = SIMSContactIndexEntry.findFirst(byGuid: entry.accountGuid, in: localContext) {
                    let serverChecksum = existingEntry.serverChecksum
                    // Wenn bisher nicht zum Server gespeichert, dann immer übernehmen, sonst prüfen ob es änderungen gibt
                    if existingEntry.shouldSaveServer,
                        (serverChecksum?.isEmpty ?? true) || serverChecksum == entry.checksum,
                        forceLoad == false {
                        continue
                    }

                    if let privateIndexGuid = existingEntry.privateIndexGuid, entry.guid != privateIndexGuid {
                        privateIndexGuidsToDelete.insert(privateIndexGuid)
                    }

                    existingEntry.importServer(innerContactInfo: entry.jsonDataDict, indexEntry: entry.innerDict, in: localContext)
                } else if let newEntry = DPAGApplicationFacade.contactFactory.newModel(accountGuid: entry.accountGuid, publicKey: nil, in: localContext) {
                    newEntry.importServer(innerContactInfo: entry.jsonDataDict, indexEntry: entry.innerDict, in: localContext)
                }
            }
        }

        return privateIndexGuidsToDelete
    }

    func checkForChangesOnContacts(contactPrivateIndexGuidsAndServerChecksums: [String: String]) throws -> (foundAllGuids: Bool, foundLocalChanges: Bool) {
        var bFoundAll = true
        var bHasLocalChanges = false

        try DPAGApplicationFacade.persistance.loadWithError { localContext in

            let allContacts = try SIMSContactIndexEntry.findAll(in: localContext)
            let contactGuids = contactPrivateIndexGuidsAndServerChecksums.keys

            for guid in contactGuids {
                var bFound = false

                for entry in allContacts {
                    guard let privateIndexGuid = entry.privateIndexGuid, privateIndexGuid == guid else {
                        continue
                    }

                    let serverChecksum = entry.serverChecksum

                    if (serverChecksum?.isEmpty ?? true) || serverChecksum == contactPrivateIndexGuidsAndServerChecksums[guid] {
                        bFound = true
                    }

                    if serverChecksum?.isEmpty ?? true {
                        bHasLocalChanges = true

                        if bFoundAll == false {
                            break
                        }
                    }
                }

                if bFound == false {
                    bFoundAll = false
                }

                if bHasLocalChanges, bFoundAll == false {
                    break
                }
            }
        }

        return (bFoundAll, bHasLocalChanges)
    }
}
