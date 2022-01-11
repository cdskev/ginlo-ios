//
//  DPAGContactsWorker.swift
// ginlo
//
//  Created by RBU on 06/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Contacts
import CoreData
import JFBCrypt

public enum DPAGContactSearchMode: String {
  case phone,
       mail,
       accountID
}

public protocol DPAGContactsWorkerProtocol: AnyObject {
  func searchContacts(groupId: String, searchText: String, orderByFirstName: Bool) -> [DPAGContact.EntryTypeServer: [DPAGContact]]
  
  func allContactsServer(entryType: DPAGContact.EntryTypeServer, filter: ((DPAGContact) -> Bool)?) -> Set<DPAGContact>
  func allContactsServer(entryType: [DPAGContact.EntryTypeServer], filter: ((DPAGContact) -> Bool)?) -> Set<DPAGContact>
  
  func unblockContact(contactAccountGuid: String, responseBlock: @escaping DPAGServiceResponseBlock)
  func blockContact(contactAccountGuid: String, responseBlock: @escaping DPAGServiceResponseBlock)
  func blockContactStream(streamGuid: String, responseBlock: @escaping DPAGServiceResponseBlock)
  func deletePrivateStream(streamGuid: String, syncWithServer: Bool, responseBlock: @escaping DPAGServiceResponseBlock)
  func getKnownAccounts(hashedPhoneNumbers: [String], response responseBlock: @escaping DPAGServiceResponseBlock)
  
  func unblockedContacts(withReadOnly: Bool) -> Set<DPAGContact>
  func blockedContacts() -> Set<DPAGContact>?
  
  func contact(fromVCard vCard: String) -> CNContact?
  
  func deleteContact(withStreamGuid streamGuid: String)
  func deleteContact(withContactGuid contactGuid: String)
  func unDeleteContact(withContactGuid contactGuid: String)
  func updateRecipientsConfidenceState(recipients: [DPAGSendMessageRecipient])
  func privatizeContact(_ contact: DPAGContact)
  
  func emptyStreamWithGuid(_ streamGuid: String)
  func hideContact(_ contactGuid: String)
  
  func updateBlockedWithServer(cacheVersionGetBlockedServer: String)
  func updatePrivateIndexWithServer(cacheVersionPrivateIndexServer: String) throws
  
  func allAddressBookPersons() -> Set<DPAGPerson>
  
  func saveImage(_ image: UIImage, forContact contactGuid: String) -> String?
  
  func updateOnlineStateKnownContacts(responseBlock: @escaping DPAGServiceResponseBlock)
  
  func contactConfidenceHigh(contactAccountGuid: String)
  
  func openChat(withContactGuid contactGuid: String) -> (streamState: DPAGChatStreamState, confidenceState: DPAGConfidenceState)
  func searchAccount(searchData: String, searchMode: DPAGContactSearchMode, responseBlock: @escaping DPAGServiceResponseBlock)
  
  func saveContact(contact: DPAGContactEdit)
  
  func parseInvitationParams(rawP: String, q: String) -> [String: Any]?
  func parseInvitationQRCode(invitationContent: String) -> [String: Any]?
  func validateScanResult(text: String, publicKey: String) -> Bool
  func validateScanResult(text: String) -> Bool
  func validateSignature(signature: Data, publicKey: String) -> Bool
  func qrCodeContent(account: DPAGAccount, version: DPAGQRCodeVersion) -> String?
  
  func setChatDeleted(streamGuid: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock)
  
  func saveDraft(draft: String, forStream streamGuid: String)
  func loadDraft(forStream streamGuid: String) -> String?
  func resetDraft(forStream streamGuid: String)
  
  func updateContact(contactGuid: String, withAccountJson dictAccountInfo: [AnyHashable: Any]) -> NSNotification.Name?
  
  func insUpdContact(withAccountJson dictAccountInfo: [AnyHashable: Any]) -> String?
  
  func findContactStream(forPhoneNumbers phoneNumbers: [String]) -> String?
  func loadAccountImage(accountGuid: String)
  
  func fetchChatStreamsForwarding() -> [DPAGContact]
  
  func isChannelFeedbackContactExisting(phoneNumber: String) -> Bool
}

class DPAGContactsWorker: NSObject, DPAGContactsWorkerProtocol {
  var contactDAO: ContactsDAOProtocol = ContactsDAO()
  var messagesDAO: MessagesDAOProtocol = MessagesDAO()
  var systemMessageContentFactory: SystemMessageContentFactoryProtocol = SystemMessageContentFactory()
  
  func searchContacts(groupId: String, searchText: String, orderByFirstName: Bool) -> [DPAGContact.EntryTypeServer: [DPAGContact]] {
    let contactsFound = DPAGDBFullTextHelper.searchContacts(withGroupId: groupId, searchText: searchText, orderByFirstName: orderByFirstName)
    var contactsPrivate: [DPAGContact] = []
    var contactsCompany: [DPAGContact] = []
    var contactsDomain: [DPAGContact] = []
    
    for contactFound in contactsFound {
      guard let contact = DPAGContact(contactSearchFTS: contactFound) else { continue }
      switch contact.entryTypeServer {
        case .privat:
          contactsPrivate.append(contact)
        case .company:
          contactsCompany.append(contact)
        case .email:
          contactsDomain.append(contact)
        case .meMyselfAndI:
          break
      }
    }
    if AppConfig.isShareExtension {
      let cache = DPAGApplicationFacadeShareExt.cache
      if cache.account?.isCompanyUserRestricted ?? false {
        return [.privat: [], .company: contactsCompany, .email: []]
      }
    } else {
      let cache = DPAGApplicationFacade.cache
      if cache.account?.isCompanyUserRestricted ?? false {
        return [.privat: [], .company: contactsCompany, .email: []]
      }
    }
    return [.privat: contactsPrivate, .company: contactsCompany, .email: contactsDomain]
  }
  
  func allContactsServer(entryType: DPAGContact.EntryTypeServer, filter: ((DPAGContact) -> Bool)?) -> Set<DPAGContact> {
    self.allContactsServer(entryType: [entryType], filter: filter)
  }
  
  func allContactsServer(entryType: [DPAGContact.EntryTypeServer], filter: ((DPAGContact) -> Bool)?) -> Set<DPAGContact> {
    if AppConfig.isShareExtension {
      var retVal = Set<DPAGContact>()
      for entryTypeItem in entryType {
        retVal.formUnion(DPAGApplicationFacadeShareExt.cache.allContactsServer(entryType: entryTypeItem, filter: nil))
      }
      return retVal
    } else {
      return contactDAO.fetchContactsServer(entryType: entryType, filter: filter)
    }
  }
  
  func isChannelFeedbackContactExisting(phoneNumber: String) -> Bool {
    var phoneNumberNormalized = ""
    if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) {
      phoneNumberNormalized = DPAGCountryCodes.sharedInstance.normalizePhoneNumber(phoneNumber, countryCodeAccount: DPAGCountryCodes.sharedInstance.countryCodeByPhone(contact.phoneNumber))
    }
    return contactDAO.isContactValid(phoneNumberNormalized: phoneNumberNormalized)
  }
  
  func fetchChatStreamsForwarding() -> [DPAGContact] {
    messagesDAO.fetchStreamsForwarding()
  }
  
  func loadAccountImage(accountGuid: String) {
    if Thread.isMainThread {
      self.performBlockInBackground { [weak self] in
        self?.loadAccountImageInBackground(accountGuid: accountGuid)
      }
    } else {
      self.loadAccountImageInBackground(accountGuid: accountGuid)
    }
  }
  
  private func loadAccountImageInBackground(accountGuid: String) {
    DPAGApplicationFacade.server.getAccountImage(guid: accountGuid) { responseObject, _, errorMessage in
      if errorMessage == nil, let responseArray = responseObject as? [String], let imageEncrypted = responseArray.first {
        _ = self.contactDAO.saveEncryptedImageDataString(imageEncrypted, forContactGuid: accountGuid)
        NotificationCenter.default.post(name: DPAGStrings.Notification.Contact.CHANGED, object: nil, userInfo: [DPAGStrings.Notification.Contact.CHANGED__USERINFO_KEY__CONTACT_GUID: accountGuid])
      }
    }
  }
  
  func findContactStream(forPhoneNumbers phoneNumbers: [String]) -> String? {
    guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) else { return nil }
    
    let countryCodeAccount = DPAGCountryCodes.sharedInstance.countryCodeByPhone(contact.phoneNumber)
    for phoneNum in phoneNumbers {
      let phoneNumber = DPAGCountryCodes.sharedInstance.normalizePhoneNumber(phoneNum, countryCodeAccount: countryCodeAccount, useCountryCode: nil)
      if let streamGuid = contactDAO.findContactStreamGuid(phoneNumber: phoneNumber) {
        return streamGuid
      }
    }
    return nil
  }
  
  func insUpdContact(withAccountJson dictAccountInfo: [AnyHashable: Any]) -> String? {
    contactDAO.insertUpdateContact(accountInfoDict: dictAccountInfo)
  }
  
  func updateContact(contactGuid: String, withAccountJson dictAccountInfo: [AnyHashable: Any]) -> NSNotification.Name? {
    contactDAO.updateContact(contactGuid: contactGuid, accountInfoDict: dictAccountInfo)
  }
  
  func resetDraft(forStream streamGuid: String) {
    self.contactDAO.resetDraft(forStream: streamGuid)
  }
  
  func loadDraft(forStream streamGuid: String) -> String? {
    self.contactDAO.loadDraft(forStream: streamGuid)
  }
  
  func saveDraft(draft: String, forStream streamGuid: String) {
    self.contactDAO.saveDraft(draft: draft, forStream: streamGuid)
  }
  
  func setChatDeleted(streamGuid: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
    guard let existingStreamGuid = self.messagesDAO.getExistingStreamGuid(withStreamGuid: streamGuid) else { return }
    DPAGApplicationFacade.server.setChatDeleted(streamGuid: existingStreamGuid, withResponse: responseBlock)
  }
  
  func qrCodeContent(account: DPAGAccount, version: DPAGQRCodeVersion) -> String? {
    guard account.privateKey != nil, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let accountPublicKey = contact.publicKey else { return nil }
    
    if version == .v2, let accountID = contact.accountID, accountID.isEmpty == false {
      return "V2\r" + accountID + "\r" + accountPublicKey.sha256Data().base64EncodedString()
    } else if let accountID = contact.accountID, accountID.isEmpty == false {
      let pkSig = accountPublicKey.sha256Data().base64EncodedString()
      let params = "p=1&c=0&i=\(accountID)&s=\(pkSig)"
      let p = params.data(using: .utf8)?.base64EncodedString()
      if let p = p {
        let q = (params + AppConfig.qrCodeSalt).sha1()
        return "https://" + AppConfig.ginloNowInvitationUrl + "?p=\(p)&q=\(q)"
      }
      return nil
    }
    return nil
  }
  
  private func splitInvitationPParam(_ param: String) -> [String: Any]? {
    let components = param.components(separatedBy: "&")
    var retval: [String: Any] = [:]
    
    DPAGLog("splitInvitationPParam:: param = \(param)")
    NSLog("splitInvitationPParam:: param = \(param)")
    for s in components {
      let kv = s.components(separatedBy: "=")
      if kv.count >= 2 {
        let key = kv[0]
        var value = kv[1]
        if s.hasSuffix("=") {
          if s.hasSuffix("==") {
            value += "=="
          } else {
            value += "="
          }
        }
        if key == "s" {
          DPAGLog("splitInvigationPParam:: key= \(key), value = \(value)")
          NSLog("splitInvigationPParam:: key= \(key), value = \(value)")
          if let publicKeyData = value.data(using: .utf8), let publicKeyDataDecoded = Data(base64Encoded: publicKeyData, options: .ignoreUnknownCharacters) {
            //                    if let data = Data(base64Encoded: value, options: .ignoreUnknownCharacters) {
            retval[key] = publicKeyDataDecoded
          } else {
            retval[key] = "ERROR"
          }
        } else {
          retval[key] = value
        }
      }
    }
    if retval.count > 0 {
      NSLog("Returning retval = \(retval)")
      return retval
    }
    return nil
  }
  
  private func pParamFromInvitationComponent(param: String, fingerprint: String) -> String? {
    DPAGLog("pParamFromInvitationComponent: param = \(param), fingerprint = \(fingerprint)")
    NSLog("pParamFromInvitationComponent: param = \(param), fingerprint = \(fingerprint)")
    if let data = Data(base64Encoded: param), let pParams = String(data: data, encoding: .utf8) {
      let sha1 = (pParams + AppConfig.qrCodeSalt).sha1()
      NSLog("sha1 = \(sha1), fingerprint = \(fingerprint)")
      if sha1 == fingerprint {
        NSLog("Returning \(pParams)")
        return pParams
      }
    }
    return nil
  }
  
  func parseInvitationParams(rawP: String, q: String) -> [String: Any]? {
    if let p = pParamFromInvitationComponent(param: rawP, fingerprint: q) {
      return splitInvitationPParam(p)
    }
    return nil
  }
  
  func parseInvitationQRCode(invitationContent: String) -> [String: Any]? {
    guard invitationContent.starts(with: "https://" + AppConfig.ginloNowInvitationUrl),
          let incomingURL = URL(string: invitationContent),
          let components = NSURLComponents(url: incomingURL, resolvingAgainstBaseURL: true),
          let params = components.queryItems,
          params.count == 2 else { return nil }
    let rawP: String?
    let q: String?
    switch params[0].name {
      case "p":
        rawP = params[0].value
        q = params[1].value
      default:
        rawP = params[1].value
        q = params[0].value
    }
    if let rp = rawP, let qq = q {
      return parseInvitationParams(rawP: rp, q: qq)
    }
    return nil
  }
  
  func validateInvitationQRCode(text: String) -> Bool {
    parseInvitationQRCode(invitationContent: text) != nil
  }
  
  private func validateOldQRCode(text: String, publicKey: String) -> Bool {
    if text.hasPrefix("V2") {
      let components = text.components(separatedBy: .newlines)
      if components.count == 3 {
        if let publicKeyData = components[2].data(using: .utf8), let publicKeyDataDecoded = Data(base64Encoded: publicKeyData, options: .ignoreUnknownCharacters) {
          let sha256 = publicKey.sha256Data()
          return (sha256 == publicKeyDataDecoded)
        }
      }
    }
    return false
  }
  
  func validateScanResult(text: String, publicKey: String) -> Bool {
    NSLog("validateScanResult:: text = \(text), publicKey = \(publicKey)")
    if validateOldQRCode(text: text, publicKey: publicKey) {
      return true
    } else if let invitationData = parseInvitationQRCode(invitationContent: text), let signature = invitationData["s"], let sigData = signature as? Data {
      return validateSignature(signature: sigData, publicKey: publicKey)
    }
    return false
  }
  
  func validateScanResult(text: String) -> Bool {
    validateInvitationQRCode(text: text)
  }
  
  func validateSignature(signature: Data, publicKey: String) -> Bool {
    let pks = publicKey.sha256Data()
    let x = signature.base64EncodedString()
    let y = pks.base64EncodedString()
    NSLog("validateSignature:: signature = \(x), publicKey = \(publicKey), publicKey.sha256 = \(y)")
    DPAGLog("validateSignature:: signature = \(x), publicKey = \(publicKey), publicKey.sha256 = \(y)")
    return signature == pks
  }
  
  func allAddressBookPersons() -> Set<DPAGPerson> {
    var persons: Set<DPAGPerson> = Set()
    let fetchRequest = CNContactFetchRequest(keysToFetch: [CNContactGivenNameKey as CNKeyDescriptor, CNContactFamilyNameKey as CNKeyDescriptor, CNContactPhoneNumbersKey as CNKeyDescriptor, CNContactEmailAddressesKey as CNKeyDescriptor, CNContactImageDataKey as CNKeyDescriptor, CNContactImageDataAvailableKey as CNKeyDescriptor])
    
    try? CNContactStore().enumerateContacts(with: fetchRequest) { contact, _ in
      if let person = DPAGPerson(contact: contact) {
        persons.insert(person)
      }
    }
    return persons
  }
  
  func contact(fromVCard vCard: String) -> CNContact? {
    if let vCardData = vCard.data(using: .utf8) {
      if let contacts = try? CNContactVCardSerialization.contacts(with: vCardData) {
        return contacts.first
      }
    }
    return nil
  }
  
  func unblockedContacts(withReadOnly: Bool) -> Set<DPAGContact> {
    let ownGuid = DPAGApplicationFacade.cache.account?.guid
    return contactDAO.fetchUnblockedContacts(ownGuid: ownGuid, withReadOnly: withReadOnly)
  }
  
  func blockedContacts() -> Set<DPAGContact>? {
    do {
      let contacts = try DPAGApplicationFacade.backupWorker.loadBlockedContacts()
      let blocked = Set(self.contactDAO.getContacts(withIds: contacts))
      DPAGLog("blocked contacts: %@", blocked)
      return blocked
    } catch {
      return nil
    }
  }
  
  func unblockContact(contactAccountGuid: String, responseBlock: @escaping DPAGServiceResponseBlock) {
    self.setBlockedContactState(blocked: false, contactAccountGuid: contactAccountGuid, responseBlock: responseBlock)
  }
  
  func blockContact(contactAccountGuid: String, responseBlock: @escaping DPAGServiceResponseBlock) {
    self.setBlockedContactState(blocked: true, contactAccountGuid: contactAccountGuid, responseBlock: responseBlock)
  }
  
  private func setBlockedContactState(blocked: Bool, contactAccountGuid: String, responseBlock: @escaping DPAGServiceResponseBlock) {
    DPAGApplicationFacade.server.setContact(contactAccountGuid: contactAccountGuid, blocked: blocked) { responseObject, errorCode, errorMessage in
      if errorMessage != nil {
        responseBlock(nil, errorCode, errorMessage)
      } else if let guid = (responseObject as? [AnyObject])?.first as? String {
        if contactAccountGuid == guid {
          self.contactDAO.setIsBlocked(contactAccountGuid: contactAccountGuid, isBlocked: blocked)
          responseBlock(responseObject, errorCode, errorMessage)
        } else {
          responseBlock(nil, "service.tryAgainLater", "service.tryAgainLater")
        }
      } else {
        responseBlock(nil, "service.tryAgainLater", "service.tryAgainLater")
      }
    }
  }
  
  func blockContactStream(streamGuid: String, responseBlock: @escaping DPAGServiceResponseBlock) {
    let contactAccountGuidBlock = self.contactDAO.getContactIndexEntryGuid(forStreamGuid: streamGuid)
    guard let contactAccountGuid = contactAccountGuidBlock else {
      responseBlock(nil, "ERR-0057", "service.ERR-0057")
      return
    }
    DPAGApplicationFacade.server.setContact(contactAccountGuid: contactAccountGuid, blocked: true) { responseObject, errorCode, errorMessage in
      if errorMessage != nil {
        if errorMessage == "service.ERR-0007" {
          self.removeStreamForBlockedContact(contactAccountGuid: contactAccountGuid, stream: streamGuid)
          responseBlock(nil, nil, nil)
        } else {
          responseBlock(nil, errorCode, errorMessage)
        }
      } else if let guid = (responseObject as? [AnyObject])?.first as? String {
        if contactAccountGuid == guid {
          self.removeStreamForBlockedContact(contactAccountGuid: contactAccountGuid, stream: streamGuid)
          responseBlock(responseObject, nil, nil)
        } else {
          responseBlock(nil, "service.tryAgainLater", "service.tryAgainLater")
        }
      }
    }
  }
  
  func removeStreamForBlockedContact(contactAccountGuid _: String, stream streamGuid: String) {
    self.contactDAO.blockContactFromStreamAndRemoveMessages(streamGuid: streamGuid)
  }
  
  func deletePrivateStream(streamGuid: String, syncWithServer: Bool, responseBlock: @escaping DPAGServiceResponseBlock) {
    if syncWithServer == false {
      self.messagesDAO.deleteNormalAndTimedMessages(forStreamGuid: streamGuid)
      responseBlock(nil, nil, nil)
      return
    }
    if let contactGuid = self.contactDAO.getContactGuid(forStreamGuid: streamGuid) {
      DPAGApplicationFacade.server.setChatDeleted(streamGuid: contactGuid) { _, _, _ in }
    }
    let timedMessageGuids = self.messagesDAO.getTimeMessagesGuids(streamGuid: streamGuid)
    if timedMessageGuids.count == 0 {
      self.messagesDAO.deleteNormalMessages(forStreamGuid: streamGuid)
      responseBlock(nil, nil, nil)
      return
    }
    DPAGApplicationFacade.server.deleteTimedMessages(messageGuids: timedMessageGuids) { responseObject, errorCode, errorMessage in
      if errorMessage == nil {
        self.messagesDAO.deleteNormalAndTimedMessages(forStreamGuid: streamGuid)
      }
      responseBlock(responseObject, errorCode, errorMessage)
    }
  }
  
  func getKnownAccounts(hashedPhoneNumbers: [String], response responseBlock: @escaping DPAGServiceResponseBlock) {
    DPAGApplicationFacade.server.getKnownAccounts(hashedPhoneNumbers: hashedPhoneNumbers, withResponse: responseBlock)
  }
  
  func deleteContact(withStreamGuid streamGuid: String) {
    guard let contactGuid = self.contactDAO.getContactIndexEntryGuid(forStreamGuid: streamGuid) else { return }
    self.deleteContact(withContactGuid: contactGuid, andStreamGuid: streamGuid)
  }
  
  func deleteContact(withContactGuid contactGuid: String) {
    guard let streamGuid = self.contactDAO.getStreamGuid(forContactGuid: contactGuid) else { return }
    self.deleteContact(withContactGuid: contactGuid, andStreamGuid: streamGuid)
  }
  
  private func deleteContact(withContactGuid contactGuid: String, andStreamGuid streamGuid: String) {
    let content = self.systemMessageContentFactory.createMessageContactDeleted(contactGuid: contactGuid)
    if self.contactDAO.deleteContact(withContactGuid: contactGuid) == true {
      self.messagesDAO.sendSystemMessage(toStreamGuid: streamGuid, content: content)
      do {
        _ = try self.deletePrivateIndexEntries(guids: [contactGuid])
      } catch {
      }
    }
  }
  
  func deletePrivateIndexEntries(guids: [String]) throws -> [Any]? {
    DPAGLog("DeletePrivateIndexEntries PrivateIndex :%@", guids)
    var retVal: [Any]?
    var errorCodeBlock: String?
    var errorMessageBlock: String?
    let semaphore = DispatchSemaphore(value: 0)
    let responseBlock: DPAGServiceResponseBlock = { responseObject, errorCode, errorMessage in
      defer {
        semaphore.signal()
      }
      if let errorMessage = errorMessage {
        DPAGLog(errorMessage)
        errorMessageBlock = errorMessage
        errorCodeBlock = errorCode
      } else if let rc = responseObject as? [Any] {
        retVal = rc
      }
    }
    DPAGApplicationFacade.server.deletePrivateIndexEntries(guids: guids.joined(separator: ","), withResponse: responseBlock)
    _ = semaphore.wait(timeout: .distantFuture)
    if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
      throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
    }
    return retVal
  }
  
  func unDeleteContact(withContactGuid contactGuid: String) {
    self.contactDAO.undeleteContact(contactGuid: contactGuid)
  }
  
  func privatizeContact(_ contact: DPAGContact) {
    self.contactDAO.privatizeContact(contact)
  }
  
  func updateRecipientsConfidenceState(recipients: [DPAGSendMessageRecipient]) {
    self.contactDAO.updateRecipientsConfidenceState(recipients: recipients)
  }
  
  func updateBlockedWithServer(cacheVersionGetBlockedServer: String) {
    DPAGApplicationFacade.server.getBlocked { [weak self] responseObject, _, errorMessage in
      if errorMessage == nil, let responseArray = responseObject as? [String] {
        self?.contactDAO.updateBlocked(responseArray: responseArray)
        DPAGApplicationFacade.preferences.cacheVersionTaskCompleted(DPAGPreferences.PropString.kCacheVersionGetBlocked, cacheVersionServer: cacheVersionGetBlockedServer)
      }
    }
  }
  
  func updatePrivateIndexWithServer(cacheVersionPrivateIndexServer: String) throws {
    let lastSuccessFullSync = DPAGApplicationFacade.preferences.lastSuccessFullSyncPrivateIndex
    let now = DPAGFormatter.date.string(from: Date())
    try DPAGApplicationFacade.couplingWorker.loadPrivateIndexFromServer(ifModifiedSince: lastSuccessFullSync, forceLoad: false)
    DPAGApplicationFacade.preferences[.kCacheVersionPrivateIndex] = cacheVersionPrivateIndexServer
    DPAGApplicationFacade.preferences.lastSuccessFullSyncPrivateIndex = now
  }
  
  func saveImage(_ image: UIImage, forContact contactGuid: String) -> String? {
    guard let imageDataStr = image.pngData()?.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters) else { return nil }
    let success = self.contactDAO.saveImageDataString(imageDataStr, forContactGuid: contactGuid)
    DPAGApplicationFacade.cache.contact(for: contactGuid)?.removeCachedImages()
    return success ? imageDataStr : nil
  }
  
  func updateOnlineStateKnownContacts(responseBlock: @escaping DPAGServiceResponseBlock) {
    let contactsUpdate = contactDAO.fetchAllConfirmedContacts()
    DPAGApplicationFacade.server.getOnlineStateBatch(guids: Array(contactsUpdate.keys)) { responseObject, errorCode, errorMessage in
      if errorMessage != nil {
        responseBlock(nil, errorCode, errorMessage)
      } else if let result = (responseObject as? [AnyObject]) {
        var hasUpdate = false
        result.forEach({ state in
          guard let stateObject = state as? [String: Any?], let guid = stateObject["accountGuid"] as? String else { return }
          let lastOnline = stateObject["lastOnline"] as? String
          let oooState = (stateObject["oooStatus"] as? [String: Any])?["statusState"] as? String
          if let streamGuid = contactsUpdate[guid], let decStream = DPAGApplicationFacade.cache.decryptedStream(streamGuid: streamGuid) as? DPAGDecryptedStreamPrivate {
            if let lastOnline = lastOnline {
              decStream.lastOnlineDate = DPAGFormatter.dateServer.date(from: lastOnline)
              hasUpdate = true
            } else {
              if decStream.lastOnlineDate != nil {
                hasUpdate = true
                decStream.lastOnlineDate = nil
              }
            }
            if let oooState = oooState, oooState == "ooo" {
              if !decStream.oooState {
                hasUpdate = true
              }
              decStream.oooState = true
            } else {
              if decStream.oooState {
                hasUpdate = true
              }
              decStream.oooState = false
            }
          }
          
        })
        if hasUpdate {
          NotificationCenter.default.post(name: DPAGStrings.Notification.ChatList.NEEDS_UPDATE, object: nil, userInfo: nil)
        }
        responseBlock(responseObject, errorCode, errorMessage)
      } else {
        responseBlock(nil, "service.tryAgainLater", "service.tryAgainLater")
      }
    }
  }
  
  func contactConfidenceHigh(contactAccountGuid: String) {
    do {
      try contactDAO.setHighConfidence(contactAccountGuid: contactAccountGuid)
    } catch {
      DPAGLog(error)
    }
  }
  
  func openChat(withContactGuid contactGuid: String) -> (streamState: DPAGChatStreamState, confidenceState: DPAGConfidenceState) {
    self.contactDAO.confirmContact(withContactGuid: contactGuid)
  }
  
  func searchAccount(searchData: String, searchMode: DPAGContactSearchMode, responseBlock: @escaping DPAGServiceResponseBlock) {
    var contacts: [String] = []
    var searchDataServer: [String] = []
    
    switch searchMode {
      case .phone:
        let phoneNumberNormalized: String
        if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) {
          phoneNumberNormalized = DPAGCountryCodes.sharedInstance.normalizePhoneNumber(searchData, countryCodeAccount: DPAGCountryCodes.sharedInstance.countryCodeByPhone(contact.phoneNumber))
        } else {
          phoneNumberNormalized = DPAGCountryCodes.sharedInstance.normalizePhoneNumber(searchData, countryCodeAccount: nil, useCountryCode: nil)
        }
        for mandant in DPAGApplicationFacade.preferences.mandanten {
          searchDataServer.append(DPAGApplicationFacade.cache.hash(accountSearchAttribute: phoneNumberNormalized, withSalt: mandant.salt))
        }
      case .mail:
        for mandant in DPAGApplicationFacade.preferences.mandanten where mandant.ident == "ba" {
          searchDataServer.append(JFBCrypt.hashPassword(searchData.lowercased(), withSalt: mandant.salt))
          break
        }
      case .accountID:
        searchDataServer.append(searchData)
    }
    DPAGApplicationFacade.server.getKnownAccounts(hashedAccountSearchAttributes: searchDataServer, searchMode: searchMode.rawValue) { [weak self] responseObject, errorCode, errorMessage in
      if errorMessage != nil {
        responseBlock(contacts, errorCode, errorMessage)
        return
      } else if let responseArray = responseObject as? [[AnyHashable: Any]], responseArray.count > 0, let account = DPAGApplicationFacade.cache.account, let contactSelf = DPAGApplicationFacade.cache.contact(for: account.guid) {
        contacts = self?.contactDAO.saveContactsFromServer(responseArray: responseArray, searchMode: searchMode, searchData: searchData, contactSelf: contactSelf) ?? contacts
        responseBlock(contacts, errorCode, errorMessage)
        return
      }
      responseBlock(contacts, errorCode, errorMessage)
    }
  }
  
  func saveContact(contact: DPAGContactEdit) {
    contactDAO.saveContact(contact: contact)
  }
  
  func emptyStreamWithGuid(_ streamGuid: String) {
    let messageGuids = self.contactDAO.clearStreamMessagesWithGuid(streamGuid)
    if DPAGApplicationFacade.preferences.supportMultiDevice, messageGuids.count > 0 {
      DPAGApplicationFacade.server.confirmDeleted(guids: messageGuids, withResponse: nil)
    }
  }
  
  func hideContact(_ contactGuid: String) {
    self.contactDAO.hideContact(contactGuid)
  }
}
