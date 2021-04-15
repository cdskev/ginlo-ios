//
//  AppExtensionDAO.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 28.08.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

protocol AppExtensionDAOProtocol {
    func getContactsAndContactStreamsForShareExtension(account accountCache: DPAGAccount, contacts: inout [DPAGSharedContainerExtensionSending.Contact], contactStreams: inout [DPAGSharedContainerExtensionSending.ContactStream]) throws

    func getConversationsForShareExtension() throws -> [DPAGSharedContainerExtensionSending.Chat]

    func getContactsForNotificationExtension(account accountCache: DPAGAccount) throws -> [String: DPAGSharedContainerExtension.Contact]
}

class AppExtensionDAO: AppExtensionDAOProtocol {
    func getContactsAndContactStreamsForShareExtension(account accountCache: DPAGAccount, contacts: inout [DPAGSharedContainerExtensionSending.Contact], contactStreams: inout [DPAGSharedContainerExtensionSending.ContactStream]) throws {
        var contactsLocal: [DPAGSharedContainerExtensionSending.Contact] = []
        var contactStreamsLocal: [DPAGSharedContainerExtensionSending.ContactStream] = []

        try DPAGApplicationFacade.persistance.loadWithError { localContext in

            let contactsDB = try SIMSContactIndexEntry.findAll(in: localContext)

            for contact in contactsDB {
                guard let contactGuid = contact.guid else {
                    return
                }

                guard accountCache.guid == contactGuid ||
                    (
                        contact[.IS_BLOCKED] == false
                            && contactGuid.isSystemChatGuid == false
                            && contact.isReadOnly == false
                            && contact[.IS_DELETED] == false
                    ),
                    let contactCache = DPAGApplicationFacade.cache.contact(for: contactGuid, contactDB: contact) else {
                    continue
                }

                var cachedContact = DPAGSharedContainerExtensionSending.Contact(contact: contactCache)

                if accountCache.guid == contactGuid {
                    if let myPublicKey = try? DPAGCryptoHelper.newAccountCrypto()?.getPublicKeyFromPrivateKey() {
                        cachedContact.publicKey = myPublicKey
                    }
                }
                contactsLocal.append(cachedContact)

                if let streamGuid = contact.stream?.guid { contactStreamsLocal.append(DPAGSharedContainerExtensionSending.ContactStream(guid: streamGuid, contactGuid: contactGuid))
                }
            }
        }

        contacts.append(contentsOf: contactsLocal)
        contactStreams.append(contentsOf: contactStreamsLocal)
    }

    func getConversationsForShareExtension() throws -> [DPAGSharedContainerExtensionSending.Chat] {
        var chats: [DPAGSharedContainerExtensionSending.Chat] = []

        try DPAGApplicationFacade.persistance.loadWithError { localContext in

            let predicate = NSCompoundPredicate(orPredicateWithSubpredicates:
                [
                    NSCompoundPredicate(andPredicateWithSubpredicates:
                        [
                            NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageStream.streamType), rightExpression: NSExpression(forConstantValue: DPAGStreamType.single.rawValue)),
                            NSCompoundPredicate(orPredicateWithSubpredicates:
                                [
                                    NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageStream.wasDeleted), rightExpression: NSExpression(forConstantValue: nil)),
                                    NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageStream.wasDeleted), rightExpression: NSExpression(forConstantValue: false))
                                ]),
                            NSPredicate(format: "(options & \(DPAGStreamOption.blocked.rawValue)) <> \(DPAGStreamOption.blocked.rawValue)"),
                            NSPredicate(format: "(options & \(DPAGStreamOption.isReadOnly.rawValue)) <> \(DPAGStreamOption.isReadOnly.rawValue)"),
                            NSCompoundPredicate(orPredicateWithSubpredicates:
                                [
                                    NSPredicate(format: "messages.@count > 0"),
                                    NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageStream.lastMessageDate), rightNotExpression: NSExpression(forConstantValue: nil))
                                ])
                        ])
                ])

            let allChats = try SIMSStream.findAll(in: localContext, with: predicate)

            for streamPrivate in allChats {
                if DPAGSystemChat.isSystemChat(streamPrivate) {
                    continue
                }

                if let contactDB = streamPrivate.contactIndexEntry, let contactGuid = contactDB.guid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid), contact.isReadOnly == false, contact.isDeleted == false, contact.isConfirmed == true {
                    chats.append(DPAGSharedContainerExtensionSending.Chat(contact: contact))
                }
            }
        }

        return chats
    }

    func getContactsForNotificationExtension(account accountCache: DPAGAccount) throws -> [String: DPAGSharedContainerExtension.Contact] {
        var contacts: [String: DPAGSharedContainerExtension.Contact] = [:]

        try DPAGApplicationFacade.persistance.loadWithError { localContext in

            let contactsDB = try SIMSContactIndexEntry.findAll(in: localContext)

            for contact in contactsDB {
                guard let contactGuid = contact.guid else {
                    return
                }

                guard accountCache.guid == contactGuid ||
                    (
                        contact[.IS_BLOCKED] == false
                            && contact[.IS_DELETED] == false
                    ),
                    let contactCache = DPAGApplicationFacade.cache.contact(for: contactGuid, contactDB: contact) else {
                    continue
                }

                let name = contactCache.displayName
                let guid = contactCache.guid
                let sCContact = DPAGSharedContainerExtension.Contact(guid: guid, name: name, confidenceState: contactCache.confidence.rawValue)

                contacts[sCContact.guid] = sCContact
            }
        }

        return contacts
    }
}
