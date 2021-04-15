//
//  DPAGCacheShareExt.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 01.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Contacts
import Foundation

public protocol DPAGCacheShareExtProtocol: AnyObject {
    var personDisplayNameOrder: CNContactDisplayNameOrder { get }
    var personSortOrder: CNContactSortOrder { get }

    var account: DPAGAccount? { get }

    func contact(for guid: String) -> DPAGContact?
    func group(for guid: String) -> DPAGGroup?
    func allContactsLocal(entryType: DPAGContact.EntryTypeLocal, filter: ((DPAGContact) -> Bool)?) -> Set<DPAGContact>
    func allContactsServer(entryType: DPAGContact.EntryTypeServer, filter: ((DPAGContact) -> Bool)?) -> Set<DPAGContact>

    func allGroups() -> [DPAGGroup]
    func allChats() -> [DPAGContact]

    func configure(container: DPAGSharedContainerExtensionSending.Container)
}

class DPAGCacheShareExt: DPAGCacheShareExtProtocol {
    var personSortOrder: CNContactSortOrder {
        CNContactsUserDefaults.shared().sortOrder
    }

    var personDisplayNameOrder: CNContactDisplayNameOrder {
        CNContactFormatter.nameOrder(for: CNContact())
    }

    var account: DPAGAccount?

    func contact(for guid: String) -> DPAGContact? {
        self.contacts[guid]
    }

    func group(for guid: String) -> DPAGGroup? {
        self.groups[guid]
    }

    func allContactsLocal(entryType: DPAGContact.EntryTypeLocal, filter: ((DPAGContact) -> Bool)?) -> Set<DPAGContact> {
        let retVal: Set<DPAGContact> = Set(self.contacts.values.filter { (contact) -> Bool in
            self.filterLocalContact(contact, havingEntryType: entryType, filteredBy: filter)
        })

        return retVal
    }

    private func filterLocalContact(_ contact: DPAGContact, havingEntryType entryType: DPAGContact.EntryTypeLocal, filteredBy filter: ((DPAGContact) -> Bool)?) -> Bool {
        let entryTypeFits = contact.entryTypeLocal == entryType
        let isNotDeleted = contact.isDeleted == false
        let isNotOmittedByFiltered = filter?(contact) ?? true

        return entryTypeFits && isNotDeleted && isNotOmittedByFiltered
    }

    func allContactsServer(entryType: DPAGContact.EntryTypeServer, filter: ((DPAGContact) -> Bool)?) -> Set<DPAGContact> {
        let retVal: Set<DPAGContact> = Set(self.contacts.values.filter { (contact) -> Bool in
            self.filterServerContact(contact, havingEntryType: entryType, filteredBy: filter)
        })

        return retVal
    }

    private func filterServerContact(_ contact: DPAGContact, havingEntryType entryType: DPAGContact.EntryTypeServer, filteredBy filter: ((DPAGContact) -> Bool)?) -> Bool {
        let entryTypeFits = contact.entryTypeServer == entryType
        let isNotDeleted = contact.isDeleted == false
        let isNotOmittedByFiltered = filter?(contact) ?? true

        // if it is a private entry and hidden, it is not from the local address book (e.g. unknown group member), so we omit it
        let isPrivateAndNotInAddressBook = contact.entryTypeServer == .privat && contact.entryTypeLocal == .hidden

        return entryTypeFits && isNotDeleted && isNotOmittedByFiltered && !isPrivateAndNotInAddressBook
    }

    func allGroups() -> [DPAGGroup] {
        Array(self.groups.values)
    }

    func allChats() -> [DPAGContact] {
        Array(self.chats.values)
    }

    private var contacts: [String: DPAGContact] = [:]
    private var groups: [String: DPAGGroup] = [:]
    private var chats: [String: DPAGContact] = [:]

    func configure(container: DPAGSharedContainerExtensionSending.Container) {
        self.account = DPAGAccount(account: container.account)

        self.contacts = container.contacts.reduce(into: [:]) { contactsCache, contact in
            contactsCache[contact.guid] = DPAGContact(contact: contact)
        }
        self.groups = container.groups.reduce(into: [:]) { groupsCache, group in
            groupsCache[group.guid] = DPAGGroup(group: group)
        }
        self.chats = container.chats.reduce(into: [:]) { chatsCache, chat in
            chatsCache[chat.guid] = DPAGContact(chat: chat)
        }
    }
}
