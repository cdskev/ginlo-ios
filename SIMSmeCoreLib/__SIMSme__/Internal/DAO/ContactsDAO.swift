//
//  ContactsDAO.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 30.08.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

protocol ContactsDAOProtocol {
  func loadDraft(forStream streamGuid: String) -> String?
  func saveDraft(draft: String, forStream streamGuid: String)
  func resetDraft(forStream streamGuid: String)
  func privatizeContact(_ contact: DPAGContact)
  func updateRecipientsConfidenceState(recipients: [DPAGSendMessageRecipient])
  func undeleteContact(contactGuid: String)
  func saveImageDataString(_ imageDataStr: String, forContactGuid contactGuid: String) -> Bool
  func saveEncryptedImageDataString(_ encryptedImageDataStr: String, forContactGuid contactGuid: String) -> Bool
  func blockContactFromStreamAndRemoveMessages(streamGuid: String)
  func confirmContact(withContactGuid contactGuid: String) -> (streamState: DPAGChatStreamState, confidenceState: DPAGConfidenceState)
  func getContacts(withIds ids: [String]) -> [DPAGContact]
  func setIsBlocked(contactAccountGuid: String, isBlocked: Bool)
  func clearStreamMessagesWithGuid(_ streamGuid: String) -> [String]
  func saveContact(contact: DPAGContactEdit)
  func saveContactsFromServer(responseArray: [[AnyHashable: Any]], searchMode: DPAGContactSearchMode, searchData: String, contactSelf: DPAGContact) -> [String]
  func getContactIndexEntryGuid(forStreamGuid streamGuid: String) -> String?
  
  // Important! This function returns nil when you're deleting a chat. It needs to be fixed. I was doing refactoring here: MELO-799 and kept the same behavior of deletePrivateStream function in DPAGContactsWorker
  func getContactGuid(forStreamGuid streamGuid: String) -> String?
  
  func getStreamGuid(forContactGuid contactGuid: String) -> String?
  func deleteContact(withContactGuid contactGuid: String) -> Bool
  func insertUpdateContact(accountInfoDict: [AnyHashable: Any]) -> String?
  func updateContact(contactGuid: String, accountInfoDict: [AnyHashable: Any]) -> NSNotification.Name?
  func fetchContactsServer(entryType: [DPAGContact.EntryTypeServer], filter: ((DPAGContact) -> Bool)?) -> Set<DPAGContact>
  func setHighConfidence(contactAccountGuid: String) throws
  func fetchAllConfirmedContacts() -> [String: String]
  func isContactValid(phoneNumberNormalized: String) -> Bool
  func hideContact(_ contactGuid: String)
  func findContactStreamGuid(phoneNumber: String) -> String?
  func fetchUnblockedContacts(ownGuid: String?, withReadOnly: Bool) -> Set<DPAGContact>
  func updateBlocked(responseArray: [String])
}

class ContactsDAO: ContactsDAOProtocol {
  func loadDraft(forStream streamGuid: String) -> String? {
    var draft: String?
    
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      
      if let stream = SIMSMessageStream.findFirst(byGuid: streamGuid, in: localContext) {
        if draft != stream.draft {
          draft = stream.draft
        }
      }
    }
    
    return draft
  }
  
  func saveDraft(draft: String, forStream streamGuid: String) {
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      
      if let stream = SIMSMessageStream.findFirst(byGuid: streamGuid, in: localContext) {
        if (stream.draft ?? "") != draft {
          stream.draft = draft
        }
      }
    }
  }
  
  func resetDraft(forStream streamGuid: String) {
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      
      if let stream = SIMSMessageStream.findFirst(byGuid: streamGuid, in: localContext) {
        stream.draft = nil
      }
    }
  }
  
  func privatizeContact(_ contact: DPAGContact) {
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      
      if let contact = SIMSContactIndexEntry.findFirst(byGuid: contact.guid, in: localContext) {
        contact.entryTypeLocal = .privat
      }
    }
  }
  
  func updateRecipientsConfidenceState(recipients: [DPAGSendMessageRecipient]) {
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      for recipient in recipients {
        if let contact = SIMSContactIndexEntry.findFirst(byGuid: recipient.recipientGuid, in: localContext) {
          contact.confirmAndConfide()
        }
      }
    }
  }
  
  func undeleteContact(contactGuid: String) {
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      if let contact = SIMSContactIndexEntry.findFirst(byGuid: contactGuid, in: localContext) {
        contact[.IS_DELETED] = false
      }
    }
  }
  
  func saveImageDataString(_ imageDataStr: String, forContactGuid contactGuid: String) -> Bool {
    var success = false
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      if let contact = SIMSContactIndexEntry.findFirst(byGuid: contactGuid, in: localContext) {
        contact[.IMAGE_DATA] = imageDataStr
        success = true
      }
    }
    return success
  }
  
  func saveEncryptedImageDataString(_ encryptedImageDataStr: String, forContactGuid contactGuid: String) -> Bool {
    var success = false
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      guard let contact = SIMSContactIndexEntry.findFirst(byGuid: contactGuid, in: localContext) else { return }
      do {
        try contact.setImageEncrypted(encryptedImageDataStr)
        
        DPAGApplicationFacade.cache.contact(for: contactGuid, contactDB: contact)?.removeCachedImages()
        success = true
        
      } catch {
        DPAGLog(error)
      }
    }
    return success
  }
  
  func blockContactFromStreamAndRemoveMessages(streamGuid: String) {
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      if let stream = SIMSMessageStream.findFirst(byGuid: streamGuid, in: localContext) as? SIMSStream, let contact = stream.contactIndexEntry {
        contact[.IS_BLOCKED] = true
        contact.removeAllMessages()
      }
    }
  }
  
  func confirmContact(withContactGuid contactGuid: String) -> (streamState: DPAGChatStreamState, confidenceState: DPAGConfidenceState) {
    var streamState: DPAGChatStreamState = .readOnly
    var confidenceState: DPAGConfidenceState = .none
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      if let contact = SIMSContactIndexEntry.findFirst(byGuid: contactGuid, in: localContext) {
        contact.confidenceState = .middle
        contact.entryTypeLocal = .privat
        contact.setConfirmed()
        streamState = contact.streamState
        confidenceState = contact.confidenceState
        
        contact.updateStatusForAllGroups(in: localContext)
      }
    }
    return (streamState, confidenceState)
  }
  
  func getContacts(withIds ids: [String]) -> [DPAGContact] {
    var result: [DPAGContact]!
    DPAGApplicationFacade.persistance.loadWithBlock { localContext in
      result = ids.compactMap {
        self.getContact(forId: $0, context: localContext)
      }
    }
    return result
  }
  
  func setIsBlocked(contactAccountGuid: String, isBlocked: Bool) {
    DPAGApplicationFacade.persistance.saveWithBlock({ localContext in
      SIMSContactIndexEntry.findFirst(byGuid: contactAccountGuid, in: localContext)?[.IS_BLOCKED] = isBlocked
    })
  }
  
  func clearStreamMessagesWithGuid(_ streamGuid: String) -> [String] {
    var result = [String]()
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      guard let messageStream = SIMSMessageStream.findFirst(byGuid: streamGuid, in: localContext) else { return }
      let streamPrivate = self.getPrivateStreamForClearing(from: messageStream)
      let streamGroup = self.getGroupStreamForClearing(from: messageStream)
      let streamChannel = self.getChannelStreamForClearing(from: messageStream)
      let streamForClearingFound = streamPrivate != nil || streamGroup != nil || streamChannel != nil
      if streamForClearingFound == true {
        result.append(contentsOf: self.deleteMessages(messageStream.messages, in: localContext))
        self.clearDecryptedStream(fromStreamGuid: streamGuid, messageStream: messageStream, context: localContext)
      }
    }
    return result
  }
  
  func getContactIndexEntryGuid(forStreamGuid streamGuid: String) -> String? {
    var result: String?
    DPAGApplicationFacade.persistance.loadWithBlock { localContext in
      let stream = SIMSMessageStream.findFirst(byGuid: streamGuid, in: localContext) as? SIMSStream
      let contact = stream?.contactIndexEntry
      result = contact?.guid
    }
    return result
  }
  
  func getContactGuid(forStreamGuid streamGuid: String) -> String? {
    var result: String?
    DPAGApplicationFacade.persistance.loadWithBlock { localContext in
      let stream = SIMSStream.findFirst(byGuid: streamGuid, in: localContext)
      result = stream?.contact?.guid
    }
    return result
  }
  
  func getStreamGuid(forContactGuid contactGuid: String) -> String? {
    var result: String?
    DPAGApplicationFacade.persistance.loadWithBlock { localContext in
      let contact = SIMSContactIndexEntry.findFirst(byGuid: contactGuid, in: localContext)
      let stream = contact?.stream
      result = stream?.guid
    }
    return result
  }
  
  func deleteContact(withContactGuid contactGuid: String) -> Bool {
    var result: Bool = false
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      guard let contact = SIMSContactIndexEntry.findFirst(byGuid: contactGuid, in: localContext) else { return }
      result = contact.mr_deleteEntity(in: localContext)
    }
    return result
  }
  
  func insertUpdateContact(accountInfoDict: [AnyHashable: Any]) -> String? {
    var accountGuid: String?
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      if let contact = DPAGApplicationFacade.contactFactory.newOrUpdateModel(withAccountJson: accountInfoDict, in: localContext) {
        accountGuid = contact.guid
      }
    }
    return accountGuid
  }
  
  func updateContact(contactGuid: String, accountInfoDict: [AnyHashable: Any]) -> NSNotification.Name? {
    var notificationToSend: NSNotification.Name?
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      if let contact = SIMSContactIndexEntry.findFirst(byGuid: contactGuid, in: localContext) {
        notificationToSend = DPAGApplicationFacade.contactFactory.updateModel(contact: contact, withAccountJson: accountInfoDict, in: localContext)
      }
    }
    return notificationToSend
  }
  
  func hideContact(_ contactGuid: String) {
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      if let contactEntry = self.getContactEntry(forId: contactGuid, context: localContext) {
        if contactEntry.entryTypeLocal == .privat, contactEntry.entryTypeServer == .privat {
          contactEntry.entryTypeLocal = .hidden
        }
      }
    }
  }
  
  // MARK: - Private
  
  private func clearDecryptedStream(fromStreamGuid streamGuid: String, messageStream: SIMSMessageStream, context: NSManagedObjectContext) {
    guard let decryptedStream = DPAGApplicationFacade.cache.decryptedStream(stream: messageStream, in: context) else { return }
    decryptedStream.newMessagesCount = 0
    decryptedStream.previewText = []
    DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: streamGuid, stream: messageStream, in: context)
  }
  
  private func getPrivateStreamForClearing(from messageStream: SIMSMessageStream) -> SIMSStream? {
    guard let privateStream = messageStream as? SIMSStream, let contactDB = privateStream.contactIndexEntry, let contactGuid = contactDB.guid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid), contact.isConfirmed else { return nil }
    return privateStream
  }
  
  private func getGroupStreamForClearing(from messageStream: SIMSMessageStream) -> SIMSGroupStream? {
    guard let groupStream = messageStream as? SIMSGroupStream, groupStream.isConfirmed?.boolValue ?? false else { return nil }
    return groupStream
  }
  
  private func getChannelStreamForClearing(from messageStream: SIMSMessageStream) -> SIMSChannelStream? {
    messageStream as? SIMSChannelStream
  }
  
  private func getContact(forId id: String, context: NSManagedObjectContext) -> DPAGContact? {
    guard let contactEntry = self.getContactEntry(forId: id, context: context) else { return nil }
    return DPAGApplicationFacade.cache.contact(for: id, contactDB: contactEntry)
  }
  
  private func getContactEntry(forId id: String, context: NSManagedObjectContext) -> SIMSContactIndexEntry? {
    SIMSContactIndexEntry.findFirst(byGuid: id, in: context)
  }
  
  private func deleteMessages(_ messages: NSOrderedSet?, in context: NSManagedObjectContext) -> [String] {
    var messageGuids: [String] = []
    guard let msgs = messages else { return messageGuids }
    for msg in Array(msgs) {
      if let message = msg as? SIMSMessage {
        DPAGApplicationFacade.persistance.deleteMessage(message, in: context)
        if let guid = message.guid {
          messageGuids.append(guid)
        }
      }
    }
    return messageGuids
  }
  
  func saveContact(contact: DPAGContactEdit) {
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      if let contactDB = SIMSContactIndexEntry.findFirst(byGuid: contact.guid, in: localContext) {
        if contact.firstName != nil {
          contactDB[.FIRST_NAME] = contact.firstName
        }
        if contact.lastName != nil {
          contactDB[.LAST_NAME] = contact.lastName
        }
        if contact.phoneNumber != nil {
          contactDB[.PHONE_NUMBER] = contact.phoneNumber
        }
        if contact.eMailAddress != nil {
          contactDB[.EMAIL_ADDRESS] = contact.eMailAddress
        }
        if contact.department != nil {
          contactDB[.DEPARTMENT] = contact.department
        }
        if let image = contact.image {
          contactDB[.IMAGE_DATA] = image.contactImageDataEncoded()
        }
        contactDB.entryTypeLocal = .privat
        contactDB[.UPDATED_AT] = Date()
        DPAGApplicationFacade.cache.contact(for: contact.guid)?.removeCachedImages()
      }
    }
  }
  
  private func deleteDuplicates(contact: DPAGContactEdit, context: NSManagedObjectContext) {
    let dbContacts = SIMSContactIndexEntry.mr_findAll(in: context) as? [SIMSContactIndexEntry]
    let cachedContact = DPAGApplicationFacade.cache.contact(for: contact.guid)
    if let contacts = dbContacts, let cachedContact = cachedContact {
      let listToDelete = contacts.filter { $0[.PHONE_NUMBER] == cachedContact.phoneNumber && $0[.MANDANT_IDENT] == cachedContact.mandantIdent && $0.guid != nil && $0.guid != contact.guid }
      for contactToDelete in listToDelete where contactToDelete[.IS_DELETED] == false {
        contactToDelete[.IS_DELETED] = true
      }
    }
  }
  
  func saveContactsFromServer(responseArray: [[AnyHashable: Any]], searchMode: DPAGContactSearchMode, searchData: String, contactSelf: DPAGContact) -> [String] {
    var contacts: [String] = []
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      for responseDict in responseArray {
        guard let accountDict = responseDict[DPAGStrings.JSON.Account.OBJECT_KEY] as? [AnyHashable: Any],
              let accountID = accountDict[DPAGStrings.JSON.Account.ACCOUNT_ID] as? String,
              let guid = accountDict[DPAGStrings.JSON.Account.GUID] as? String,
              let publicKey = accountDict[DPAGStrings.JSON.Account.PUBLIC_KEY] as? String else { continue }
        var contactDBToAdd: SIMSContactIndexEntry?
        if let contact = DPAGApplicationFacade.cache.contact(for: guid) {
          switch contact.entryTypeServer {
            case .company:
              if contacts.contains(guid) == false {
                contacts.append(guid)
              }
              continue
            case .email:
              if contact.eMailDomain == contactSelf.eMailDomain {
                if contacts.contains(guid) == false {
                  contacts.append(guid)
                }
                continue
              }
            case .meMyselfAndI:
              continue
            case .privat:
              break
          }
          contactDBToAdd = SIMSContactIndexEntry.findFirst(byGuid: guid, in: localContext)
        } else {
          contactDBToAdd = SIMSContactIndexEntry.findFirst(byGuid: guid, in: localContext) ?? SIMSContactIndexEntry.mr_createEntity(in: localContext)
        }
        guard let contactDB = contactDBToAdd else { continue }
        contactDB.guid = guid
        if contactDB.keyRelationship == nil {
          contactDB.keyRelationship = SIMSKey.mr_findFirst(in: localContext)
        }
        if contactDB.stream == nil {
          contactDB.createNewStream(in: localContext)
          contactDB[.CREATED_AT] = Date()
        }
        contactDB[.ACCOUNT_ID] = accountID
        contactDB[.PUBLIC_KEY] = publicKey
        NSLog("•••• nickname  = \(contactDB[.NICKNAME])")
        NSLog("•••• publicKey  = \(contactDB[.PUBLIC_KEY])")
        NSLog("•••• is_deleted = \(contactDB[.IS_DELETED])")
        contactDB[.IS_DELETED] = false
        if let encryptedStatus = accountDict[DPAGStrings.JSON.Account.STATUS] as? String {
          contactDB[.STATUS_ENCRYPTED] = encryptedStatus
        }
        if let encryptedNickname = accountDict[DPAGStrings.JSON.Account.NICKNAME] as? String {
          contactDB[.NICKNAME_ENCRYPTED] = encryptedNickname
        }
        switch searchMode {
          case .phone:
            if contactDB[.PHONE_NUMBER] == nil {
              contactDB[.PHONE_NUMBER] = searchData
            }
          case .mail:
            if contactDB[.EMAIL_ADDRESS] == nil {
              contactDB[.EMAIL_ADDRESS] = searchData
            }
          case .accountID:
            break
        }
        contactDB[.MANDANT_IDENT] = accountDict[DPAGStrings.WHITELABEL_MANDANT] as? String
        if contacts.contains(guid) == false {
          contacts.append(guid)
        }
      }
    }
    return contacts
  }
  
  func fetchContactsServer(entryType: [DPAGContact.EntryTypeServer], filter: ((DPAGContact) -> Bool)?) -> Set<DPAGContact> {
    var retVal: Set<DPAGContact> = Set()
    DPAGApplicationFacade.persistance.loadWithBlock { localContext in
      if let contactsDB = SIMSContactIndexEntry.mr_findAll(in: localContext) as? [SIMSContactIndexEntry] {
        let filteredContactsDB = contactsDB.filter { entryType.contains($0.entryTypeServer) && ($0.entryTypeServer != .privat || $0.entryTypeLocal != .hidden) }
        //                DPAGLog("Contacts fetched from DB: %u", filteredContactsDB.count)
        for contact in filteredContactsDB {
          if let contactGuid = contact.guid {
            //                        NSLog("New Contact:")
            //                        NSLog("    AccountID      = \(contact[SIMSContactIndexEntry.AttrString.ACCOUNT_ID] ?? "---")")
            //                        NSLog("    Firstname      = \(contact[SIMSContactIndexEntry.AttrString.FIRST_NAME] ?? "NONE")")
            //                        NSLog("    Lastname       = \(contact[SIMSContactIndexEntry.AttrString.LAST_NAME] ?? "NONE")")
            //                        NSLog("    Nickname       = \(contact[SIMSContactIndexEntry.AttrString.NICKNAME] ?? "NONE")")
            //                        NSLog("    IsBlocked      = \(contact[SIMSContactIndexEntry.AttrBool.IS_BLOCKED])")
            //                        NSLog("    IsDeleted      = \(contact[SIMSContactIndexEntry.AttrBool.IS_DELETED])")
            //                        NSLog("    EntryTypeLocal = \(contact.entryTypeLocal)")
            if let contactCache = DPAGApplicationFacade.cache.contact(for: contactGuid, contactDB: contact), filter?(contactCache) ?? true {
              //                            NSLog("    Contact Cache Names:")
              //                            NSLog("       Firstname = \(contactCache.firstName ?? "NONE")")
              //                            NSLog("       Lastname  = \(contactCache.lastName ?? "NONE")")
              //                            NSLog("       Nickname  = \(contactCache.nickName ?? "NONE")")
              retVal.insert(contactCache)
            }
            //                        NSLog("---------------------------------------------------------------")
          }
        }
      }
    }
    return retVal
  }
  
  func setHighConfidence(contactAccountGuid: String) throws {
    try DPAGApplicationFacade.persistance.saveWithError { localContext in
      guard let contact = SIMSContactIndexEntry.findFirst(byGuid: contactAccountGuid, in: localContext) else { return }
      contact.confidenceState = .high
      let allMembers = try SIMSGroupMember.findAll(in: localContext, with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSGroupMember.accountGuid), rightExpression: NSExpression(forConstantValue: contactAccountGuid)))
      for member in allMembers {
        for group in member.groups ?? Set() {
          group.updateStatus(in: localContext)
        }
      }
      DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: nil, stream: contact.stream, in: localContext)
    }
  }
  
  func fetchAllConfirmedContacts() -> [String: String] {
    var contactsUpdate: [String: String] = [:]
    DPAGApplicationFacade.persistance.loadWithBlock { localContext in
      if let contacts = SIMSContactIndexEntry.mr_findAll(in: localContext) as? [SIMSContactIndexEntry] {
        for contact in contacts {
          if let contactGuid = contact.guid, contact[.IS_DELETED] == false, contact.isConfirmed, contact.stream?.lastMessageDate != nil {
            contactsUpdate[contactGuid] = contact.stream?.guid
          }
        }
        DPAGLog("updateSet contacts: %@", Array(contactsUpdate.keys))
      }
    }
    return contactsUpdate
  }
  
  func isContactValid(phoneNumberNormalized: String) -> Bool {
    var retVal = false
    DPAGApplicationFacade.persistance.loadWithBlock { localContext in
      if let contacts = SIMSContactIndexEntry.mr_findAll(in: localContext) as? [SIMSContactIndexEntry] {
        for contact in contacts where contact.phoneNumber == phoneNumberNormalized && contact[.IS_DELETED] == false && (contact.publicKey?.isEmpty ?? true) == false {
          retVal = true
          break
        }
      }
    }
    return retVal
  }
  
  func findContactStreamGuid(phoneNumber: String) -> String? {
    var streamGuid: String?
    DPAGApplicationFacade.persistance.loadWithBlock { localContext in
      streamGuid = (SIMSContactIndexEntry.mr_findAll(in: localContext) as? [SIMSContactIndexEntry])?.filter({ (contact) -> Bool in
        contact[.IS_DELETED] == false && contact.phoneNumber == phoneNumber
      }).max(by: { (contact1, contact2) -> Bool in
        if let date1 = contact1[.CREATED_AT] {
          if let date2 = contact2[.CREATED_AT] {
            return date1.compare(date2) == .orderedAscending
          }
          return true
        }
        return contact2[.CREATED_AT] == nil
      })?.stream?.guid
    }
    return streamGuid
  }
  
  func fetchUnblockedContacts(ownGuid: String?, withReadOnly: Bool) -> Set<DPAGContact> {
    var contacts: Set<DPAGContact> = Set()
    DPAGApplicationFacade.persistance.loadWithBlock { localContext in
      guard let contactsDB = SIMSContactIndexEntry.mr_findAll(in: localContext) as? [SIMSContactIndexEntry] else { return }
      for contact in contactsDB {
        guard let contactGuid = contact.guid else { return }
        if ownGuid != contactGuid || (contact[.IS_BLOCKED] == false && contactGuid.isSystemChatGuid == false && contact[.IS_DELETED] == false),
           let contactCache = DPAGApplicationFacade.cache.contact(for: contactGuid, contactDB: contact), withReadOnly || contactCache.isReadOnly == false {
          contacts.insert(contactCache)
        }
      }
    }
    return contacts
  }
  
  func updateBlocked(responseArray: [String]) {
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      var blockedAccounts: [String: String] = [:]
      responseArray.forEach { accountGuid in
        blockedAccounts[accountGuid] = accountGuid
        SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext)?[.IS_BLOCKED] = true
      }
      SIMSContactIndexEntry.mr_findAll(in: localContext)?.forEach { contact in
        guard let contact = contact as? SIMSContactIndexEntry, let contactGuid = contact.guid else { return }
        if contact[.IS_BLOCKED] {
          if blockedAccounts[contactGuid] == nil {
            contact[.IS_BLOCKED] = false
          }
        } else {
          if blockedAccounts[contactGuid] != nil {
            contact[.IS_BLOCKED] = true
          }
        }
      }
    }
  }
}
