//
// Created by mg on 09.11.13.
// Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Contacts
import CoreData

public protocol DPAGUpdateKnownContactsWorkerProtocol: AnyObject {
  func handleAccountDict(dictAccountInfo: [AnyHashable: Any], nickNameNew: String?, in localContext: NSManagedObjectContext)
  
  func getAccountInfo(accountGuid guid: String, withProfile profile: Bool, withTempDevice tempDevice: Bool, response: @escaping DPAGServiceResponseBlock)
  
  func getTempDeviceInfo(accountGuid guid: String, withTempDevice device: String, response: @escaping DPAGServiceResponseBlock)
  
  func synchronize(accountGuid guid: String, response: @escaping DPAGServiceResponseBlock)
  func synchronize(accountGuids guids: [String], response: @escaping DPAGServiceResponseBlock)
  
  func synchronizeContacts()
  
  func updateWithAddressbook()
  
  func initMandanten(withResponse responseBlock: @escaping DPAGServiceResponseBlock)
}

class DPAGUpdateKnownContactsWorker: DPAGUpdateKnownContactsWorkerProtocol {
  func initMandanten(withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
    DPAGApplicationFacade.server.getMandanten(withResponse: { responseObject, errorCode, errorMessage in
      guard errorMessage == nil, let responseArray = responseObject as? [[AnyHashable: Any]] else {
        responseBlock(responseObject, errorCode, errorMessage)
        return
      }
      var mandanten: [DPAGMandant] = []
      for responseItemDict in responseArray {
        if let dictMandant = responseItemDict["Mandant"] as? [AnyHashable: Any] {
          if let mandant = DPAGMandant(dict: dictMandant) {
            mandanten.append(mandant)
          }
        }
      }
      DPAGApplicationFacade.preferences.mandanten = mandanten
      DPAGApplicationFacade.updateKnownContactsWorker.updateWithAddressbook()
      responseBlock(responseObject, errorCode, errorMessage)
    })
  }
  
  func handleAccountDict(dictAccountInfo: [AnyHashable: Any], nickNameNew: String?, in localContext: NSManagedObjectContext) {
    _ = self.handleAccountDictInternal(dictAccountInfo: dictAccountInfo, nickNameNew: nickNameNew, in: localContext)
  }
  
  func handleAccountDictInternal(dictAccountInfo: [AnyHashable: Any], nickNameNew: String?, in localContext: NSManagedObjectContext) -> (contact: SIMSContactIndexEntry?, isNew: Bool) {
    guard let accountGuid = dictAccountInfo[SIMS_GUID] as? String else {
      return (nil, false)
    }
    
    let phone = dictAccountInfo[SIMS_PHONE] as? String
    
    if let contact = DPAGApplicationFacade.contactFactory.contact(accountDict: dictAccountInfo, phoneNumber: phone, in: localContext) {
      if contact.guid == accountGuid {
        if let notificationToSend = DPAGApplicationFacade.contactFactory.updateModel(contact: contact, withAccountJson: dictAccountInfo, in: localContext) {
          NotificationCenter.default.post(name: notificationToSend, object: nil, userInfo: [DPAGStrings.Notification.Contact.CHANGED__USERINFO_KEY__CONTACT_GUID: accountGuid])
        }
        
        DPAGApplicationFacade.preferences.setProfileSynchronizationDone(forProfileGuid: accountGuid)
        contact[.UPDATED_AT] = Date()
      } else {
        // found by phone -> contact recreated
        
        let contactOld = contact
        
        if let contactNew = DPAGApplicationFacade.contactFactory.newModel(accountJson: dictAccountInfo, in: localContext) {
          contactNew[.UPDATED_AT] = Date()
          
          if let streamOld = contactOld.stream, contactOld.confidenceState.rawValue >= DPAGConfidenceState.middle.rawValue, (streamOld.messages?.count ?? 0) > 0, contactOld[.MANDANT_IDENT] == contactNew[.MANDANT_IDENT] {
            let content = String(format: DPAGLocalizedString("chat.single.alert.message.contact_recreated"), contactOld.guid ?? "???")
            
            DPAGApplicationFacade.messageFactory.newSystemMessage(content: content, forChat: streamOld, sendDate: Date(), guid: nil, in: localContext)
          }
          if let nickName = nickNameNew {
            contactNew[.NICKNAME] = nickName
          }
          return (contactNew, true)
        }
      }
      if let nickName = nickNameNew {
        contact[.NICKNAME] = nickName
      }
      return (contact, false)
    } else {
      if let contact = DPAGApplicationFacade.contactFactory.newOrUpdateModel(withAccountJson: dictAccountInfo, in: localContext) {
        contact[.UPDATED_AT] = Date()
        
        if let nickName = nickNameNew {
          contact[.NICKNAME] = nickName
        }
        
        return (contact, true)
      }
    }
    
    return (nil, false)
  }
  
  func synchronize(accountGuid guid: String, response: @escaping DPAGServiceResponseBlock) {
    DPAGApplicationFacade.server.getAccountInfo(guid: guid, withProfile: true, withTempDevice: false) { responseObject, errorCode, errorMessage in
      
      if let errorMessage = errorMessage {
        response(nil, errorCode, errorMessage)
      } else if let dict = responseObject as? [AnyHashable: Any], let dictAccountInfo = dict[DPAGStrings.JSON.Account.OBJECT_KEY] as? [AnyHashable: Any] {
        var contactGuidBlock: String?
        
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
          
          if let contact = DPAGApplicationFacade.contactFactory.newOrUpdateModel(withAccountJson: dictAccountInfo, in: localContext), let contactGuid = contact.guid {
            if let groupMember = SIMSGroupMember.mr_findFirst(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSGroupMember.accountGuid), rightExpression: NSExpression(forConstantValue: guid)), in: localContext) {
              groupMember.accountGuid = contactGuid
            }
            
            if contact[.IS_DELETED] { // Fix for the bug of contact being deleted locally but not on server
              contact[.IS_DELETED] = false
            }
            
            contactGuidBlock = contactGuid
          }
        }
        
        response(contactGuidBlock, nil, nil)
        
        if let contactGuid = contactGuidBlock {
          DPAGSendInternalMessageWorker.sendProfileToContacts([contactGuid])
        }
      }
    }
  }
  
  func getAccountInfo(accountGuid guid: String, withProfile profile: Bool, withTempDevice tempDevice: Bool, response: @escaping DPAGServiceResponseBlock) {
    DPAGApplicationFacade.server.getAccountInfo(guid: guid, withProfile: profile, withTempDevice: tempDevice, withResponse: response)
  }
  
  func getTempDeviceInfo(accountGuid guid: String, withTempDevice _: String, response: @escaping DPAGServiceResponseBlock) {
    // TODO: Ergebnis cachen und gecachtes Ergebnis zurückliefern
    DPAGApplicationFacade.server.getTempDeviceInfo(accountGuid: guid, withResponse: response)
  }
  
  func synchronize(accountGuids guids: [String], response: @escaping DPAGServiceResponseBlock) {
    // self.queueGetAccountInfo.addOperation {
    guard guids.isEmpty == false else {
      response([], nil, nil)
      return
    }
    DPAGApplicationFacade.server.getAccountsInfo(guids: guids) { responseObject, errorCode, errorMessage in
      if let errorMessage = errorMessage {
        response(nil, errorCode, errorMessage)
      } else if let dictArr = responseObject as? [[AnyHashable: Any]] {
        var accountGuids: [String] = []
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
          for dict in dictArr {
            if let dictAccountInfo = dict[DPAGStrings.JSON.Account.OBJECT_KEY] as? [AnyHashable: Any] { // , let accountGuid = dictAccountInfo[SIMS_GUID] as? String
              if let contact = DPAGApplicationFacade.contactFactory.newOrUpdateModel(withAccountJson: dictAccountInfo, in: localContext), let contactGuid = contact.guid {
                accountGuids.append(contactGuid)
              }
            }
          }
          for missingAccountId in guids.filter({ (guid) -> Bool in
            accountGuids.contains(guid) == false
          }) {
            if let contact = SIMSContactIndexEntry.findFirst(byGuid: missingAccountId, in: localContext), contact[.IS_DELETED] == false {
              contact[.IS_DELETED] = true
            }
          }
        }
        DPAGSendInternalMessageWorker.sendProfileToContacts(accountGuids)
        response([], nil, nil)
      } else {
        response(nil, nil, nil)
      }
    }
  }
  
  func synchronizeContacts() {
    var contactGuids: [String] = []
    DPAGApplicationFacade.persistance.loadWithBlock { localContext in
      if let allContacts = SIMSContactIndexEntry.mr_findAll(in: localContext) {
        contactGuids = allContacts.compactMap { (obj) -> String? in
          (obj as? SIMSContactIndexEntry)?.guid
        }
      }
    }
    self.synchronize(accountGuids: contactGuids, response: { responseObject, _, _ in
      if responseObject != nil {
        DPAGApplicationFacade.preferences.updateLastContactSynchronization()
      }
      NotificationCenter.default.post(name: DPAGStrings.Notification.ContactsSync.FINISHED, object: self, userInfo: [:])
    })
  }
  
  func updateWithAddressbook() {
    let data = self.allPhoneNumbersAndEmailAddressesWithContactIdentifiers()
    self.updateWithAddressbookPhoneNumbers(phoneNumbersWithContactIdentifiers: data.phoneNumbers, mandanten: data.mandanten)
    self.updateWithAddressbookEmailAddresses(emailAddressesWithContactIdentifiers: data.emailAddresses, mandanten: data.mandanten)
  }
  
  private func updateWithAddressbookPhoneNumbers(phoneNumbersWithContactIdentifiers: [String: String], mandanten: [DPAGMandant]) {
    let stepNum = 500
    var accountsMissing: [String: String] = [:]
    let stepMax = ((phoneNumbersWithContactIdentifiers.count / stepNum) + 1) * mandanten.count
    var step = 1
    //        NSLog("updateWithAddressbookPhoneNumbers")
    for mandant in mandanten {
      var hashedPhoneNumbersToDo = Array(mandant.hashedPhoneNumbers.keys)
      var hashedPhoneNumbersCurrent = hashedPhoneNumbersToDo[0 ..< min(hashedPhoneNumbersToDo.count, stepNum)]
      hashedPhoneNumbersToDo = Array(hashedPhoneNumbersToDo.dropFirst(stepNum))
      while hashedPhoneNumbersCurrent.isEmpty == false {
        NotificationCenter.default.post(name: DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfo, object: nil, userInfo: [DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyState: DPAGUpdateKnownContactsWorkerSyncInfoState.DownloadKnownAccountInfosPhoneNumber, DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyProgressStep: step, DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyProgressMax: stepMax])
        let semaphoreKnown = DispatchSemaphore(value: 0)
        do {
          try DPAGApplicationFacade.server.getKnownAccounts(hashedPhoneNumbers: Array(hashedPhoneNumbersCurrent), mandant: mandant) { responseObject, _, errorMessage in
            defer {
              semaphoreKnown.signal()
            }
            guard errorMessage == nil, let dicts = responseObject as? [[AnyHashable: Any]] else { return }
            NotificationCenter.default.post(name: DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfo, object: nil, userInfo: [DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyState: DPAGUpdateKnownContactsWorkerSyncInfoState.SaveKnownAccountInfosPhoneNumber, DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyProgressStep: step, DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyProgressMax: stepMax])
            DPAGApplicationFacade.persistance.saveWithBlock { localContext in
              for accountDict in dicts {
                guard let hash = accountDict.keys.first as? String, let accountGuid = accountDict.values.first as? String else { continue }
                if let contactDB = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext), contactDB[.PUBLIC_KEY] != nil, contactDB[.ACCOUNT_ID] != nil {
                  //                                    NSLog("IMDAT")
                  //                                    NSLog("ACCOUNT::---------------------------")
                  //                                    NSLog("       AccountID: %@", contactDB[.ACCOUNT_ID] ?? "<NONE>")
                  //                                    NSLog("       Firstname: %@", contactDB[.FIRST_NAME] ?? "-")
                  //                                    NSLog("       last name: %@", contactDB[.LAST_NAME] ?? "-")
                  //                                    NSLog("       PublicKey: %@", contactDB[.PUBLIC_KEY] ?? "<NONE>")
                  //                                    NSLog("       Phone-Nr.: %@", contactDB[.PHONE_NUMBER] ?? "-")
                  if let contactPhone = contactDB[.PHONE_NUMBER], let contactIdentifier = phoneNumbersWithContactIdentifiers[contactPhone] {
                    contactDB[.IS_DELETED] = false
                    contactDB.update(withContactIdentifier: contactIdentifier)
                    contactDB.setConfirmed()
                  } else {
                    accountsMissing[accountGuid] = mandant.hashedPhoneNumbers[hash]
                  }
                } else {
                  accountsMissing[accountGuid] = mandant.hashedPhoneNumbers[hash]
                }
              }
            }
          }
          _ = semaphoreKnown.wait(timeout: .distantFuture)
        } catch {
          DPAGLog(error, message: "error updateWithAddressbookPhone")
          return
        }
        hashedPhoneNumbersCurrent = hashedPhoneNumbersToDo[0 ..< min(hashedPhoneNumbersToDo.count, stepNum)]
        hashedPhoneNumbersToDo = Array(hashedPhoneNumbersToDo.dropFirst(stepNum))
        step += 1
      }
    }
    if accountsMissing.count > 0 {
      let semaphoreMissing = DispatchSemaphore(value: 0)
      let missingGuids: [String] = Array(accountsMissing.keys)
      NotificationCenter.default.post(name: DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfo, object: nil, userInfo: [DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyState: DPAGUpdateKnownContactsWorkerSyncInfoState.DownloadMissingAccountInfosPhoneNumber])
      DPAGApplicationFacade.server.getAccountsInfo(guids: missingGuids) { responseObject, _, errorMessage in
        defer {
          semaphoreMissing.signal()
        }
        guard errorMessage == nil, let dicts = responseObject as? [[AnyHashable: Any]] else { return }
        NotificationCenter.default.post(name: DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfo, object: nil, userInfo: [DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyState: DPAGUpdateKnownContactsWorkerSyncInfoState.SaveMissingAccountInfosPhoneNumber])
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
          for dict in dicts {
            if let dictAccount = dict[DPAGStrings.JSON.Account.OBJECT_KEY] as? [AnyHashable: Any], let accountGuid = dictAccount[DPAGStrings.JSON.Account.GUID] as? String {
              var dictMutable = dictAccount
              if let phoneNumber = accountsMissing[accountGuid] {
                dictMutable[DPAGStrings.JSON.Account.PHONE] = phoneNumber
              }
              let retVal = self.handleAccountDictInternal(dictAccountInfo: dictMutable, nickNameNew: nil, in: localContext)
              if retVal.isNew {
                retVal.contact?.entryTypeLocal = .privat
              }
              if let phoneNumber = accountsMissing[accountGuid], let contactDB = retVal.contact, let contactIdentifier = phoneNumbersWithContactIdentifiers[phoneNumber] {
                contactDB.update(withContactIdentifier: contactIdentifier)
                contactDB.setConfirmed()
              }
            }
          }
        }
        DPAGSendInternalMessageWorker.sendProfileToContacts(missingGuids)
      }
      _ = semaphoreMissing.wait(timeout: .distantFuture)
    }
  }
  
  private func updateWithAddressbookEmailAddresses(emailAddressesWithContactIdentifiers: [String: String], mandanten: [DPAGMandant]) {
    let stepNum = 500
    var accountsMissing: [String: String] = [:]
    let stepMax = ((emailAddressesWithContactIdentifiers.count / stepNum) + 1) * 1 // (ba only)//mandanten.count
    var step = 1
    DPAGLog("updateWithAddressbookEmailAddresses")
    for mandant in mandanten {
      var hashedEmailAddressesToDo: [String] = Array(mandant.hashedEmailAddresses.keys)
      var hashedEmailAdressesCurrent = hashedEmailAddressesToDo[0 ..< min(hashedEmailAddressesToDo.count, stepNum)]
      hashedEmailAddressesToDo = Array(hashedEmailAddressesToDo.dropFirst(stepNum))
      while hashedEmailAdressesCurrent.isEmpty == false {
        NotificationCenter.default.post(name: DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfo, object: nil, userInfo: [DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyState: DPAGUpdateKnownContactsWorkerSyncInfoState.DownloadKnownAccountInfosPhoneNumber, DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyProgressStep: step, DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyProgressMax: stepMax])
        let semaphoreKnown = DispatchSemaphore(value: 0)
        do {
          try DPAGApplicationFacade.server.getKnownAccounts(hashedAccountSearchAttributes: Array(hashedEmailAdressesCurrent), searchMode: DPAGContactSearchMode.mail.rawValue, mandant: mandant) { responseObject, _, errorMessage in
            defer {
              semaphoreKnown.signal()
            }
            guard errorMessage == nil, let dicts = responseObject as? [[AnyHashable: Any]] else { return }
            NotificationCenter.default.post(name: DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfo, object: nil, userInfo: [DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyState: DPAGUpdateKnownContactsWorkerSyncInfoState.SaveKnownAccountInfosPhoneNumber, DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyProgressStep: step, DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyProgressMax: stepMax])
            DPAGApplicationFacade.persistance.saveWithBlock { localContext in
              for accountDict in dicts {
                guard let hash = accountDict.keys.first as? String, let accountGuid = accountDict.values.first as? String else { continue }
                if let contactDB = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext), contactDB[.PUBLIC_KEY] != nil, contactDB[.ACCOUNT_ID] != nil {
                  if let contactEmail = contactDB[.EMAIL_ADDRESS], let contactIdentifier = emailAddressesWithContactIdentifiers[contactEmail] {
                    contactDB.update(withContactIdentifier: contactIdentifier)
                    contactDB.setConfirmed()
                  } else {
                    accountsMissing[accountGuid] = mandant.hashedEmailAddresses[hash]
                  }
                } else {
                  accountsMissing[accountGuid] = mandant.hashedEmailAddresses[hash]
                }
              }
            }
          }
          _ = semaphoreKnown.wait(timeout: .distantFuture)
        } catch {
          DPAGLog(error, message: "error updateWithAddressbookEmail")
          return
        }
        hashedEmailAdressesCurrent = hashedEmailAddressesToDo[0 ..< min(hashedEmailAddressesToDo.count, stepNum)]
        hashedEmailAddressesToDo = Array(hashedEmailAddressesToDo.dropFirst(stepNum))
        step += 1
      }
    }
    if accountsMissing.count > 0 {
      let semaphoreMissing = DispatchSemaphore(value: 0)
      let missingGuids: [String] = Array(accountsMissing.keys)
      NotificationCenter.default.post(name: DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfo, object: nil, userInfo: [DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyState: DPAGUpdateKnownContactsWorkerSyncInfoState.DownloadMissingAccountInfosEmailAddress])
      DPAGApplicationFacade.server.getAccountsInfo(guids: missingGuids) { responseObject, _, errorMessage in
        defer {
          semaphoreMissing.signal()
        }
        guard errorMessage == nil, let dicts = responseObject as? [[AnyHashable: Any]] else { return }
        NotificationCenter.default.post(name: DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfo, object: nil, userInfo: [DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyState: DPAGUpdateKnownContactsWorkerSyncInfoState.SaveMissingKnownAccountInfosEmailAddress])
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
          for dict in dicts {
            if let dictAccount = dict[DPAGStrings.JSON.Account.OBJECT_KEY] as? [AnyHashable: Any], let accountGuid = dictAccount[DPAGStrings.JSON.Account.GUID] as? String {
              var dictMutable = dictAccount
              if let email = accountsMissing[accountGuid] {
                dictMutable[DPAGStrings.JSON.Account.EMAIL] = email
              }
              let retVal = self.handleAccountDictInternal(dictAccountInfo: dictMutable, nickNameNew: nil, in: localContext)
              if retVal.isNew {
                retVal.contact?.entryTypeLocal = .privat
              }
              if let email = accountsMissing[accountGuid], let contactDB = retVal.contact, let contactIdentifier = emailAddressesWithContactIdentifiers[email] {
                contactDB.update(withContactIdentifier: contactIdentifier)
                contactDB.setConfirmed()
              }
            }
          }
        }
        DPAGSendInternalMessageWorker.sendProfileToContacts(missingGuids)
      }
      _ = semaphoreMissing.wait(timeout: .distantFuture)
    }
  }
  
  private struct AddressBookInfo {
    let phoneNumbers: [String: String]
    let emailAddresses: [String: String]
    let mandanten: [DPAGMandant]
  }
  
  private func allPhoneNumbersAndEmailAddressesWithContactIdentifiers() -> AddressBookInfo {
    var retValPhoneNumbers: [String: String] = [:]
    var retValEmailAddresses: [String: String] = [:]
    guard let account = DPAGApplicationFacade.cache.account, let contactCache = DPAGApplicationFacade.cache.contact(for: account.guid) else {
      return AddressBookInfo(phoneNumbers: retValPhoneNumbers, emailAddresses: retValEmailAddresses, mandanten: [])
    }
    NotificationCenter.default.post(name: DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfo, object: nil, userInfo: [DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyState: DPAGUpdateKnownContactsWorkerSyncInfoState.LoadAndHashPhoneNumbersAndEmailAdresses])
    let mandanten = DPAGApplicationFacade.preferences.mandanten
    let fetchRequest = CNContactFetchRequest(keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor, CNContactPhoneNumbersKey as CNKeyDescriptor, CNContactEmailAddressesKey as CNKeyDescriptor])
    var step = 0
    try? CNContactStore().enumerateContacts(with: fetchRequest) { contact, _ in
      step += 1
      if contact.phoneNumbers.count > 0 {
        for phoneNumberValue in contact.phoneNumbers {
          let phoneNumberNormalized = DPAGCountryCodes.sharedInstance.normalizePhoneNumber(phoneNumberValue.value.stringValue, countryCodeAccount: DPAGCountryCodes.sharedInstance.countryCodeByPhone(contactCache.phoneNumber))
          if phoneNumberNormalized.count < 6 {
            continue
          }
          retValPhoneNumbers[phoneNumberNormalized] = contact.identifier
          for mandant in mandanten {
            mandant.addPhoneNumberHash(DPAGApplicationFacade.cache.hash(accountSearchAttribute: phoneNumberNormalized, withSalt: mandant.salt), phoneNumber: phoneNumberNormalized)
          }
        }
      }
      if contact.emailAddresses.count > 0 {
        for emailAddressValue in contact.emailAddresses {
          step += 1
          retValEmailAddresses[emailAddressValue.value as String] = contact.identifier
          for mandant in mandanten where mandant.ident == "ba" {
            mandant.addEmailAddressHash(DPAGApplicationFacade.cache.hash(accountSearchAttribute: emailAddressValue.value as String, withSalt: mandant.salt), emailAddress: emailAddressValue.value as String)
          }
        }
      }
      if (step % 10) == 0 {
        NotificationCenter.default.post(name: DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfo, object: nil, userInfo: [DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyState: DPAGUpdateKnownContactsWorkerSyncInfoState.LoadAndHashPhoneNumbersAndEmailAdresses, DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyProgressStep: step])
      }
    }
    DPAGApplicationFacade.cache.saveHashedAccountSearchAttributes()
    return AddressBookInfo(phoneNumbers: retValPhoneNumbers, emailAddresses: retValEmailAddresses, mandanten: mandanten)
  }
}
