//
//  DPAGCompanyAdressbookWorker.m
// ginlo
//
//  Created by Yves Hetzer on 27.10.16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//
//

import CoreData
import Foundation

public enum DPAGCompanyAdressbookWorkerSyncType: Int {
  case email, company
}

public struct DPAGAddressInformationResponse {
  let responseArray: [Any]?
  let errorCode: String?
  let errorMessage: String?
}

public protocol DPAGCompanyAdressbookWorkerProtocol: AnyObject {
  func setOwnAdressInformation(withResponse responseBlock: @escaping DPAGServiceResponseBlock)
  func syncAdressInformations()
  func loadAdressInformationBatch(guids: [String], type: DPAGCompanyAdressbookWorkerSyncType) -> DPAGAddressInformationResponse
  func confirmConfirmationMail(code: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock)
  func requestConfirmationMail(eMailAddress: String, force: Bool, withResponse responseBlock: @escaping DPAGServiceResponseBlock)
  func validateMailAddress(eMailAddress: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock)
  func confirmConfirmationSMS(code: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock)
  func requestConfirmationSMS(phoneNumber: String, force: Bool, withResponse responseBlock: @escaping DPAGServiceResponseBlock)
  func checkCompanyManagement(withResponse responseBlock: @escaping (_ errorCode: String?, _ errorMessage: String?, _ companyName: String?, _ testLicenseAvailable: Bool, _ accountStateManaged: DPAGAccountCompanyManagedState) -> Void)
  func acceptCompanyManagement(withResponse responseBlock: @escaping DPAGServiceResponseBlock)
  func declineCompanyManagement(withResponse responseBlock: @escaping DPAGServiceResponseBlock)
  func requestCompanyRecoveryKey(withResponse responseBlock: @escaping DPAGServiceResponseBlock)
  func updateCompanyIndexWithServer(cacheVersionCompanyIndexServer: String)
  func updateDomainIndexWithServer()
  func updateFullTextStates()
  func updateFullTextStates(localContext: NSManagedObjectContext)
  func waitForCompanyIndexInfo(timeInterval: TimeInterval) throws
}

class DPAGCompanyAdressbookWorker: NSObject, DPAGCompanyAdressbookWorkerProtocol {
  func setOwnAdressInformation(withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
    guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) else {
      self.performBlockInBackground {
        responseBlock(nil, nil, nil)
      }
      return
    }
    var accountGuidResponse: String?
    var executeResponseBlock = true
    DPAGApplicationFacade.persistance.loadWithBlock { localContext in
      guard let account = SIMSAccount.mr_findFirst(in: localContext) else { return }
      accountGuidResponse = account.guid
      guard account.companyEncryptionEmail?.isEmpty ?? true, account.companyEncryptionPhoneNumber?.isEmpty ?? true else { return }
      var innerData: [AnyHashable: Any] = [:]
      if let lastName = contact.lastName, lastName.isEmpty == false {
        innerData["name"] = lastName
      }
      if let firstName = contact.firstName, firstName.isEmpty == false {
        innerData["firstname"] = firstName
      }
      if let emailAdress = contact.eMailAddress, emailAdress.isEmpty == false {
        innerData["email"] = emailAdress
      }
      if let department = contact.department, department.isEmpty == false {
        innerData["department"] = department
      }
      let dataDict = ["AdressInformation-v1": innerData]
      guard let jsonData = try? JSONSerialization.data(withJSONObject: dataDict, options: []) else { return }
      guard let emailDomain = contact.eMailDomain, let aesKey = try? account.aesKey(emailDomain: emailDomain) else { return }
      guard let jsonDataEncrypted = try? CryptoHelperEncrypter.encryptForJson(data: jsonData, withAesKey: aesKey) else { return }
      var innerDataMutable = jsonDataEncrypted
      innerDataMutable["guid"] = account.guid
      let adressInformation = ["AdressInformation": innerDataMutable]
      guard let data = adressInformation.JSONString else { return }
      executeResponseBlock = false
      DPAGApplicationFacade.server.setAdressInformation(data: data, withResponse: responseBlock)
    }
    if executeResponseBlock {
      responseBlock(accountGuidResponse, nil, nil)
    }
  }
  
  private func loadAdressInformations(type: DPAGCompanyAdressbookWorkerSyncType) -> DPAGAddressInformationResponse {
    var responseArray: [Any]?
    var errorCodeBlock: String?
    var errorMessageBlock: String?
    let semaphore = DispatchSemaphore(value: 0)
    let responseBlock: DPAGServiceResponseBlock = { responseObject, errorCode, errorMessage in
      defer {
        semaphore.signal()
      }
      if let errorMessage = errorMessage {
        DPAGLog(errorMessage)
        errorCodeBlock = errorCode
        errorMessageBlock = errorMessage
      } else if let arr = responseObject as? [Any] {
        responseArray = arr
        DPAGLog("Server response company addresses count: %u, for type %u", responseArray?.count ?? 0, type.rawValue)
      }
    }
    switch type {
      case .email:
        DPAGApplicationFacade.server.getAdressInformations(withResponse: responseBlock)
      case .company:
        let dateSince: Date = DPAGApplicationFacade.preferences.addressInformationsCompanyDate ?? Date(timeIntervalSince1970: TimeInterval(0))
        DPAGApplicationFacade.server.getAdressInformationsCompany(withResponse: responseBlock, since: dateSince)
    }
    _ = semaphore.wait(timeout: .distantFuture)
    return DPAGAddressInformationResponse(responseArray: responseArray, errorCode: errorCodeBlock, errorMessage: errorMessageBlock)
  }
  
  func loadAdressInformationBatch(guids: [String], type: DPAGCompanyAdressbookWorkerSyncType) -> DPAGAddressInformationResponse {
    var responseArray: [Any]?
    var errorCodeBlock: String?
    var errorMessageBlock: String?
    let semaphore = DispatchSemaphore(value: 0)
    let responseBlock: DPAGServiceResponseBlock = { responseObject, errorCode, errorMessage in
      defer {
        semaphore.signal()
      }
      if let errorMessage = errorMessage {
        DPAGLog(errorMessage)
        errorCodeBlock = errorCode
        errorMessageBlock = errorMessage
      } else if let arr = responseObject as? [Any] {
        responseArray = arr
      }
    }
    switch type {
      case .email:
        DPAGApplicationFacade.server.getAdressInformationBatch(guids: guids, withResponse: responseBlock)
      case .company:
        DPAGApplicationFacade.server.getAdressInformationsCompanyBatch(guids: guids, withResponse: responseBlock)
    }
    _ = semaphore.wait(timeout: .distantFuture)
    return DPAGAddressInformationResponse(responseArray: responseArray, errorCode: errorCodeBlock, errorMessage: errorMessageBlock)
  }
  
  private func handleDeletedDomainContact(contactGuid: String, in localContext: NSManagedObjectContext) {
    guard let contactNewPrivate = SIMSContactIndexEntry.findFirst(byGuid: contactGuid, in: localContext) else { return }
    let contactHasConversation = contactNewPrivate.entryTypeLocal == .privat
    let contactIsGroupMember = SIMSGroupMember.mr_findFirst(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSGroupMember.accountGuid), rightExpression: NSExpression(forConstantValue: contactGuid)), in: localContext) != nil
    if contactHasConversation || contactIsGroupMember {
      contactNewPrivate.entryTypeServer = .privat
    } else {
      contactNewPrivate.mr_deleteEntity(in: localContext)
    }
  }
  
  private func handleDeletedCompanyContact(contactGuid: String, in localContext: NSManagedObjectContext) {
    guard let contactNewPrivate = SIMSContactIndexEntry.findFirst(byGuid: contactGuid, in: localContext) else { return }
    let contactHasConversation = contactNewPrivate.entryTypeLocal == .privat
    let contactIsGroupMember = SIMSGroupMember.mr_findFirst(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSGroupMember.accountGuid), rightExpression: NSExpression(forConstantValue: contactGuid)), in: localContext) != nil
    if contactHasConversation || contactIsGroupMember {
      contactNewPrivate.entryTypeServer = .privat
    } else {
      contactNewPrivate.mr_deleteEntity(in: localContext)
    }
  }
  
  private func doSync(ownAccountGuid: String, updateSelf: Bool, type: DPAGCompanyAdressbookWorkerSyncType) -> Bool {
    let stepNum = 1_000
    if type == .company {
      guard let account = DPAGApplicationFacade.cache.account, account.aesKeyCompanyUserData != nil else { return false }
    }
    NotificationCenter.default.post(name: DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfo, object: nil, userInfo: [DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyState: DPAGCompanyAdressbookWorkerSyncInfoState.DownloadServerChecksums])
    let allServerAdressesResponse = self.loadAdressInformations(type: type)
    guard let allServerAdresses = allServerAdressesResponse.responseArray else { return false }
    NotificationCenter.default.post(name: DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfo, object: nil, userInfo: [DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyState: DPAGCompanyAdressbookWorkerSyncInfoState.LoadServerChecksums])
    var mapChecksumServer: [String: String] = [:]
    for o in allServerAdresses {
      guard let kv = o as? [AnyHashable: Any] else { continue }
      guard let accountGuid = kv["guid"] as? String, let checksum = kv["checksum"] as? String else { continue }
      mapChecksumServer[accountGuid] = checksum
    }
    NotificationCenter.default.post(name: DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfo, object: nil, userInfo: [DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyState: DPAGCompanyAdressbookWorkerSyncInfoState.LoadClientChecksums])
    // Nicht mehr existierende Kontakte löschen
    let mapChecksumClient: [String: String] = [:] // self.loadClientChecksums(type: type, mapChecksumServer: mapChecksumServer)
    var mapAccountGuid: [String: String] = [:]
    if type == .email {
      NotificationCenter.default.post(name: DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfo, object: nil, userInfo: [DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyState: DPAGCompanyAdressbookWorkerSyncInfoState.LoadCompanyEntries])
      DPAGApplicationFacade.persistance.saveWithBlock { localContext in
        if let contacts = SIMSCompanyContact.mr_findAll(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSCompanyContact.guid), rightExpression: NSExpression(forConstantValue: DPAGGuidPrefix.companyUser.rawValue), modifier: .direct, type: .beginsWith, options: []), in: localContext), let account = DPAGApplicationFacade.cache.account, let aesKeyCompanyUserData = account.aesKeyCompanyUserData {
          for contactObj in contacts {
            if let contact = contactObj as? SIMSCompanyContact, let contactGuid = contact.guid, let data = contact.data {
              let (_, jsonObj) = SIMSContactIndexEntry.decryptAddressCompanyData(data: data, aesKey: aesKeyCompanyUserData)
              if let jsonObj = jsonObj, let accountGuid = jsonObj["accountGuid"] as? String {
                mapAccountGuid[accountGuid] = contactGuid
              }
            }
          }
        }
      }
    }
    NotificationCenter.default.post(name: DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfo, object: nil, userInfo: [DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyState: DPAGCompanyAdressbookWorkerSyncInfoState.LoadContactsToUpdate])
    var missingAdresses: [String] = []
    mapChecksumServer.forEach { key, value in
      let checkSumClient = mapChecksumClient[key]
      if mapAccountGuid[key] == nil {
        if checkSumClient == nil {
          missingAdresses.append(key)
        } else if checkSumClient != value {
          missingAdresses.append(key)
        }
      }
    }
    if updateSelf {
      missingAdresses.append(ownAccountGuid)
    }
    if missingAdresses.count == 0 {
      return false
    }
    let stepMax = (missingAdresses.count / stepNum) + 1
    // maximal 1000 Stück in ein em Aufruf laden
    while missingAdresses.count > 0 {
      NotificationCenter.default.post(name: DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfo,
                                      object: nil,
                                      userInfo: [DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyState: DPAGCompanyAdressbookWorkerSyncInfoState.DownloadContactsToUpdate,
                                                 DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyProgressStep: stepMax - (missingAdresses.count / stepNum),
                                                 DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyProgressMax: stepMax])
      let currentAdresses = Array(missingAdresses.prefix(stepNum))
      let serverAdressesResponse = self.loadAdressInformationBatch(guids: currentAdresses, type: type)
      NotificationCenter.default.post(name: DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfo,
                                      object: nil,
                                      userInfo: [DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyState: DPAGCompanyAdressbookWorkerSyncInfoState.SaveContactsToUpdate,
                                                 DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyProgressStep: stepMax - (missingAdresses.count / stepNum),
                                                 DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyProgressMax: stepMax])
      missingAdresses = Array(missingAdresses.suffix(from: currentAdresses.count))
      guard let serverAdresses = serverAdressesResponse.responseArray else { return false }
      DPAGApplicationFacade.persistance.saveWithBlock { localContext in
        switch type {
          case .email:
            // Hier bewusst nicht auf das gecachte objekt zugreifen (Race Kondition beim Update)
            guard let account = SIMSAccount.mr_findFirst(in: localContext), let accountGuid = account.guid, let contactSelf = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext), let emailDomain = contactSelf[.EMAIL_DOMAIN], let aesKeyEmailDomain = try? account.aesKey(emailDomain: emailDomain) else { return }
            for serverAdress in serverAdresses {
              self.consumeServerAddress(serverAdress, mapChecksumServer: mapChecksumServer, emailDomain: emailDomain, aesKeyEmailDomain: aesKeyEmailDomain, in: localContext)
            }
          case .company:
            guard let account = SIMSAccount.mr_findFirst(in: localContext), let accountGuid = account.guid, let contactSelf = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) else { return }
            var aeskeyEmailDomain: Data?
            if let selfEmailDomain = contactSelf[.EMAIL_DOMAIN] {
              aeskeyEmailDomain = try? account.aesKey(emailDomain: selfEmailDomain)
            }
            for serverAdress in serverAdresses {
              self.consumeServerCompanyAddress(serverAdress, mapChecksumServer: mapChecksumServer, selfEmailDomain: contactSelf[.EMAIL_DOMAIN], aesKeyEMail: aeskeyEmailDomain, in: localContext)
            }
        }
      }
    }
    if type == .company {
      NotificationCenter.default.post(name: DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfo, object: nil, userInfo: [DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyState: DPAGCompanyAdressbookWorkerSyncInfoState.CheckCompanyContactsToDelete])
      DPAGApplicationFacade.persistance.saveWithBlock { localContext in
        var mapAccountGuid: [String: String] = [:]
        if let contacts = SIMSCompanyContact.mr_findAll(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSCompanyContact.guid), rightExpression: NSExpression(forConstantValue: type == .company ? DPAGGuidPrefix.companyUser.rawValue : DPAGGuidPrefix.account.rawValue), modifier: .direct, type: .beginsWith, options: []), in: localContext), let account = DPAGApplicationFacade.cache.account, let aesKeyCompanyUserData = account.aesKeyCompanyUserData {
          for contactObj in contacts {
            if let contact = contactObj as? SIMSCompanyContact, let contactGuid = contact.guid, let data = contact.data {
              let (_, jsonObj) = SIMSContactIndexEntry.decryptAddressCompanyData(data: data, aesKey: aesKeyCompanyUserData)
              if let jsonObj = jsonObj, let accountGuid = jsonObj["accountGuid"] as? String {
                mapAccountGuid[accountGuid] = contactGuid
              }
            }
          }
        }
        guard let contacts = SIMSContactIndexEntry.mr_findAll(in: localContext) else { return }
        for contactObj in contacts {
          guard let contact = contactObj as? SIMSContactIndexEntry, let contactGuid = contact.guid, mapAccountGuid[contactGuid] == nil, contact.entryTypeServer == .company else { continue }
          //                    NSLog("CONTACT TO DELETE::---------------------------")
          //                    NSLog("       AccountID: %@", contact[.ACCOUNT_ID] ?? "<NONE>")
          //                    NSLog("       Firstname: %@", contact[.FIRST_NAME] ?? "-")
          //                    NSLog("       last name: %@", contact[.LAST_NAME] ?? "-")
          //                    NSLog("       PublicKey: %@", contact[.PUBLIC_KEY] ?? "<NONE>")
          //                    NSLog("       Phone-Nr.: %@", contact[.PHONE_NUMBER] ?? "-")
          self.handleDeletedCompanyContact(contactGuid: contactGuid, in: localContext)
        }
      }
    }
    var guids: [String] = []
    DPAGApplicationFacade.persistance.loadWithBlock { localContext in
      if let contacts = SIMSContactIndexEntry.mr_findAll(in: localContext) {
        for contactObj in contacts {
          if let contact = contactObj as? SIMSContactIndexEntry, let contactGuid = contact.guid {
            if contact.entryTypeServer == .company || contact[.ACCOUNT_ID] == nil {
              guids.append(contactGuid)
            }
          }
        }
      }
    }
    let stepCreateMax = (guids.count / stepNum) + 1
    while guids.count > 0 {
      NotificationCenter.default.post(name: DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfo,
                                      object: nil,
                                      userInfo: [DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyState: DPAGCompanyAdressbookWorkerSyncInfoState.LoadContactsToCreate,
                                                 DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyProgressStep: stepCreateMax - (guids.count / stepNum),
                                                 DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyProgressMax: stepCreateMax])
      let currentGuids = Array(guids.prefix(stepNum))
      guids = Array(guids.suffix(from: currentGuids.count))
      let semaphore = DispatchSemaphore(value: 0)
      DPAGApplicationFacade.updateKnownContactsWorker.synchronize(accountGuids: currentGuids) { _, _, _ in
        semaphore.signal()
      }
      _ = semaphore.wait(timeout: .distantFuture)
    }
    self.performBlockInBackground {
      self.updateFullTextStates()
    }
    return true
  }
  
  private func loadClientChecksums(type: DPAGCompanyAdressbookWorkerSyncType, mapChecksumServer: [String: String]) -> [String: String] {
    var mapChecksumClient: [String: String] = [:]
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      guard let contacts = SIMSCompanyContact.mr_findAll(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSCompanyContact.guid), rightExpression: NSExpression(forConstantValue: type == .company ? DPAGGuidPrefix.companyUser.rawValue : DPAGGuidPrefix.account.rawValue), modifier: .direct, type: .beginsWith, options: []), in: localContext) else {
        return
      }
      for contactObj in contacts {
        guard let contact = contactObj as? SIMSCompanyContact,
              let contactGuid = contact.guid,
              let contactChecksum = contact.checksum else {
          continue
        }
        if type == .email {
          let contactNotFoundOnServer = mapChecksumServer[contactGuid] == nil
          if contactNotFoundOnServer {
            contact.mr_deleteEntity(in: localContext)
            self.handleDeletedDomainContact(contactGuid: contactGuid, in: localContext)
          } else {
            mapChecksumClient[contactGuid] = contactChecksum
          }
        } else if type == .company {
          guard let data = contact.data,
                let account = DPAGApplicationFacade.cache.account,
                let aesKeyCompanyUserData = account.aesKeyCompanyUserData else {
            continue
          }
          let (_, jsonObj) = SIMSContactIndexEntry.decryptAddressCompanyData(data: data, aesKey: aesKeyCompanyUserData)
          if let jsonObj = jsonObj, jsonObj["accountGuid"] as? String != nil {
            mapChecksumClient[contactGuid] = contactChecksum
          } else {
            contact.checksum = ""
          }
        }
      }
    }
    return mapChecksumClient
  }
  
  public func updateFullTextStates() {
    DPAGApplicationFacade.persistance.loadWithBlock { localContext in
      self.updateFullTextStates(localContext: localContext)
    }
  }
  
  public func updateFullTextStates(localContext: NSManagedObjectContext) {
    localContext.perform {
      var contactsPrivateCount = 0
      var contactsCompanyCount = 0
      var contactsDomainCount = 0
      var emailDomain: String?
      if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) {
        emailDomain = contact.eMailDomain
      }
      var contactChecked: Set<String> = Set()
      SIMSContactIndexEntry.mr_findAll(in: localContext)?.forEach { obj in
        if let contact = obj as? SIMSContactIndexEntry, contact[.IS_DELETED] == false, let contactGuid = contact.guid, contactChecked.contains(contactGuid) == false {
          switch contact.entryTypeServer {
            case .privat:
              if contact.entryTypeLocal == .privat, contact.guid != DPAGApplicationFacade.cache.account?.guid {
                contactsPrivateCount += 1
              }
            case .company:
              contactsCompanyCount += 1
              
              if emailDomain != nil, contact[.EMAIL_DOMAIN] == emailDomain {
                contactsDomainCount += 1
              }
            case .email:
              contactsDomainCount += 1
            case .meMyselfAndI:
              break
          }
          contactChecked.insert(contactGuid)
        }
      }
      let changed = (DPAGApplicationFacade.preferences.contactsPrivateCount != contactsPrivateCount) ||
      (DPAGApplicationFacade.preferences.contactsCompanyCount != contactsCompanyCount) ||
      (DPAGApplicationFacade.preferences.contactsDomainCount != contactsDomainCount)
      DPAGApplicationFacade.preferences.contactsPrivateCount = contactsPrivateCount
      DPAGApplicationFacade.preferences.contactsCompanyCount = contactsCompanyCount
      DPAGApplicationFacade.preferences.contactsDomainCount = contactsDomainCount
      if changed {
        NotificationCenter.default.post(name: DPAGStrings.Notification.Contact.CONTACT_COUNT_CHANGED, object: nil)
      }
    }
  }
  
  private func consumeServerAddress(_ o: Any, mapChecksumServer: [String: String], emailDomain: String, aesKeyEmailDomain: Data, in localContext: NSManagedObjectContext) {
    guard let kvPre = o as? [AnyHashable: Any], let kv = kvPre["AdressInformation"] as? [AnyHashable: Any] else { return }
    guard let guid = kv["guid"] as? String, let keyIv = kv["key-iv"] as? String, let data = kv["data"] as? String, let publicKey = kv["publicKey"] as? String, let checkSum = mapChecksumServer[guid] else { return }
    var contact = SIMSContactIndexEntry.findFirst(byGuid: guid, in: localContext)
    var companyContact = SIMSCompanyContact.findFirst(byGuid: guid, in: localContext)
    if companyContact?.checksum == checkSum, (contact?.entryTypeServer ?? .privat) == .privat || (contact?.entryTypeServer ?? .privat) == .meMyselfAndI {
      return
    }
    if companyContact == nil {
      companyContact = SIMSCompanyContact.mr_createEntity(in: localContext)
      companyContact?.data = data
      companyContact?.keyIv = keyIv
      companyContact?.guid = guid
    }
    companyContact?.checksum = checkSum
    if contact == nil {
      contact = SIMSContactIndexEntry.mr_createEntity(in: localContext)
      contact?.keyRelationship = SIMSKey.mr_findFirst(in: localContext)
      contact?.guid = guid
      contact?.entryTypeServer = .email
      contact?[.PUBLIC_KEY] = publicKey
      contact?[.CREATED_AT] = Date()
      contact?[.IS_DELETED] = false
      _ = contact?.createNewStream(in: localContext)
      contact?.confidenceState = .high
    }
    if let contact = contact {
      contact[.EMAIL_DOMAIN] = emailDomain
      contact[.IS_DELETED] = false
      guard let jsonData = try? CryptoHelperDecrypter.decrypt(encryptedData: data, withAesKey: aesKeyEmailDomain, andIv: keyIv) else { return }
      _ = contact.update(withJsonData: jsonData)
    }
    return
  }
  
  private func consumeServerCompanyAddress(_ o: Any, mapChecksumServer: [String: String], selfEmailDomain: String?, aesKeyEMail: Data?, in localContext: NSManagedObjectContext) {
    guard let kvPre = o as? [AnyHashable: Any], let kv = kvPre["CompanyIndexEntry"] as? [AnyHashable: Any] else { return }
    guard let guid = kv["guid"] as? String, kv["dateModified"] as? String != nil, let data = kv["data"] as? String, kv["data-checksum"] as? String != nil, let checkSum = mapChecksumServer[guid] else { return }
    if kv["dateDeleted"] as? String != nil {
      if let companyContact = SIMSCompanyContact.findFirst(byGuid: guid, in: localContext) {
        companyContact.mr_deleteEntity(in: localContext)
      }
      return
    }
    guard let accountGuid = kv["accountGuid"] as? String else {
      if let companyContact = SIMSCompanyContact.findFirst(byGuid: guid, in: localContext) {
        companyContact.mr_deleteEntity(in: localContext)
      }
      return
    }
    
    guard let account = DPAGApplicationFacade.cache.account, let aesKeyCompanyUserData = account.aesKeyCompanyUserData else { return }
    var contact: SIMSContactIndexEntry? = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext)
    var companyContact = SIMSCompanyContact.findFirst(byGuid: guid, in: localContext)
    if companyContact?.checksum == checkSum, (contact?.entryTypeServer ?? .privat) == .privat || (contact?.entryTypeServer ?? .privat) == .meMyselfAndI {
      return
    }
    if companyContact == nil {
      companyContact = SIMSCompanyContact.mr_createEntity(in: localContext)
      companyContact?.data = data
      companyContact?.guid = guid
    }
    companyContact?.checksum = checkSum
    if contact == nil {
      contact = SIMSContactIndexEntry.mr_createEntity(in: localContext)
      contact?.keyRelationship = SIMSKey.mr_findFirst(in: localContext)
      contact?.guid = accountGuid
      contact?.entryTypeLocal = .hidden
      contact?[.CREATED_AT] = Date()
      contact?[.STATUSMESSAGE] = ""
      _ = contact?.createNewStream(in: localContext)
      contact?.confidenceState = .high
    }
    contact?.entryTypeServer = .company
    contact?.confidenceState = .high
    contact?[.IS_DELETED] = false
    if let accountID = kv["accountID"] as? String {
      contact?.setAccountId(accountID)
    }
    let (jsonData, jsonObj) = SIMSContactIndexEntry.decryptAddressCompanyData(data: data, aesKey: aesKeyCompanyUserData)
    guard let jsonData2 = jsonData, var jsonObj2 = jsonObj else { return }
    jsonObj2["accountGuid"] = accountGuid
    _ = contact?.update(withJsonData: jsonData2)
    do {
      let newData = try JSONSerialization.data(withJSONObject: jsonObj2, options: [])
      companyContact?.data = String(data: newData, encoding: .utf8)
      if let selfEmailDomain = selfEmailDomain, let email = contact?[.EMAIL_ADDRESS], email.hasSuffix(selfEmailDomain) {
        var companyContactMail = SIMSCompanyContact.findFirst(byGuid: accountGuid, in: localContext)
        if companyContactMail == nil {
          companyContactMail = SIMSCompanyContact.mr_createEntity(in: localContext)
          let keyIv = try CryptoHelperEncrypter.getNewRawIV()
          guard let aesKeyString = aesKeyEMail?.base64EncodedString() else { return }
          let encryptedData = try CryptoHelperEncrypter.encrypt(data: jsonData2, withAesKeyDict: ["iv": keyIv, "key": aesKeyString])
          companyContactMail?.data = encryptedData
          companyContactMail?.keyIv = keyIv
          companyContactMail?.guid = accountGuid
        }
        contact?[.EMAIL_DOMAIN] = selfEmailDomain
      }
    } catch {
      DPAGLog(error)
    }
  }
  
  func syncAdressInformations() {
    if let account = DPAGApplicationFacade.cache.account {
      if DPAGApplicationFacade.preferences.isCompanyManagedState {
        _ = self.doSync(ownAccountGuid: account.guid, updateSelf: false, type: .company)
      } else {
        if account.isCompanyAccountEmailConfirmed {
          let updateSelf = (account.companyEncryptionEmail?.isEmpty ?? true) && (account.companyEncryptionPhoneNumber?.isEmpty ?? true)
          
          _ = self.doSync(ownAccountGuid: account.guid, updateSelf: updateSelf, type: .email)
        }
      }
    }
  }
  
  func confirmConfirmationMail(code: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
    DPAGApplicationFacade.server.confirmConfirmationMail(code: code, withResponse: responseBlock)
  }
  
  func requestConfirmationMail(eMailAddress: String, force: Bool, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
    DPAGApplicationFacade.server.requestConfirmationMail(eMailAddress: eMailAddress, force: force, withResponse: responseBlock)
  }
  
  func validateMailAddress(eMailAddress: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
    DPAGApplicationFacade.server.validateMailAddress(eMailAddress: eMailAddress, withResponse: responseBlock)
  }
  
  func confirmConfirmationSMS(code: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
    DPAGApplicationFacade.server.confirmConfirmationSMS(code: code, withResponse: responseBlock)
  }
  
  func requestConfirmationSMS(phoneNumber: String, force: Bool, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
    DPAGApplicationFacade.server.requestConfirmationSMS(phoneNumber: phoneNumber, force: force, withResponse: responseBlock)
  }
  
  func checkCompanyManagement(withResponse responseBlock: @escaping (_ errorCode: String?, _ errorMessage: String?, _ companyName: String?, _ testLicenseAvailable: Bool, _ accountStateManaged: DPAGAccountCompanyManagedState) -> Void) {
    DPAGApplicationFacade.server.checkCompanyManagement { responseObject, errorCode, errorMessage in
      if errorMessage != nil || (CryptoHelper.sharedInstance?.isPrivateKeyInMemory() ?? false) == false {
        responseBlock(errorCode, errorMessage, nil, false, .unknown)
      } else {
        var companyName: String?
        var testLicenseAvailable = false
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
          if let account = SIMSAccount.mr_findFirst(in: localContext) {
            if let dictCompany = (responseObject as? [AnyHashable: Any])?[DPAGStrings.JSON.Company.OBJECT_KEY] as? [AnyHashable: Any] {
              account.companyInfo = dictCompany
              testLicenseAvailable = dictCompany["testVoucherAvailable"] as? String ?? "false" == "true"
            } else {
              testLicenseAvailable = (responseObject as? [AnyHashable: Any])?["testVoucherAvailable"] as? String ?? "false" == "true"
            }
            companyName = account.companyName
          }
        }
        var accountStateManaged: DPAGAccountCompanyManagedState = .unknown
        if let accountManagedStateText = ((responseObject as? [AnyHashable: Any])?["state"] as? String) ?? ((responseObject as? [AnyHashable: Any])?[DPAGStrings.JSON.Company.OBJECT_KEY] as? [AnyHashable: Any])?["state"] as? String {
          DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            if let account = SIMSAccount.mr_findFirst(in: localContext) {
              account.updateCompanyManagedState(accountManagedStateText)
              accountStateManaged = account.companyManagedState
            }
          }
        }
        responseBlock(errorCode, errorMessage, companyName, testLicenseAvailable, accountStateManaged)
      }
    }
  }
  
  func acceptCompanyManagement(withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
    DPAGApplicationFacade.server.acceptCompanyManagement { responseObject, errorCode, errorMessage in
      if errorMessage == nil {
        let accountManagedStateText = (responseObject as? [Any])?.first as? String
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
          if let account = SIMSAccount.mr_findFirst(in: localContext) {
            account.updateCompanyManagedState(accountManagedStateText)
          }
        }
      }
      responseBlock(responseObject, errorCode, errorMessage)
    }
  }
  
  func declineCompanyManagement(withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
    DPAGApplicationFacade.server.declineCompanyManagement { responseObject, errorCode, errorMessage in
      if errorMessage == nil {
        let accountManagedStateText = (responseObject as? [Any])?.first as? String
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
          if let account = SIMSAccount.mr_findFirst(in: localContext) {
            account.updateCompanyManagedState(accountManagedStateText)
          }
        }
        DPAGApplicationFacade.preferences.setTestLicenseDaysLeft("0")
      }
      responseBlock(responseObject, errorCode, errorMessage)
    }
  }
  
  func requestCompanyRecoveryKey(withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
    if let recoveryKey = DPAGApplicationFacade.preferences.getCompanyRecoveryKey() {
      DPAGApplicationFacade.server.requestCompanyRecoveryKey(recoveryKey: recoveryKey, withResponse: responseBlock)
    }
  }
  
  func updateCompanyIndexWithServer(cacheVersionCompanyIndexServer: String) {
    guard let account = DPAGApplicationFacade.cache.account else { return }
    if self.doSync(ownAccountGuid: account.guid, updateSelf: false, type: .company) {
      DPAGApplicationFacade.preferences.cacheVersionTaskCompleted(DPAGPreferences.PropString.kCacheVersionCompanyIndex, cacheVersionServer: cacheVersionCompanyIndexServer)
      DPAGApplicationFacade.preferences.addressInformationsCompanyDate = Date().addingDays(-1)
    }
  }
  
  func updateDomainIndexWithServer() {
    guard let account = DPAGApplicationFacade.cache.account else { return }
    if self.doSync(ownAccountGuid: account.guid, updateSelf: false, type: .email) {
      DPAGApplicationFacade.preferences.updateLastDomainIndexSynchronisation()
    }
  }
  
  func waitForCompanyIndexInfo(timeInterval: TimeInterval) throws {
    let semaphore = DispatchSemaphore(value: 0)
    var errorMessageBlock: String?
    let endDate = Date().addingTimeInterval(timeInterval)
    while endDate.isInFuture {
      if let account = DPAGApplicationFacade.cache.account, account.aesKeyCompany != nil, account.aesKeyCompanyUserData != nil {
        break
      }
      DPAGApplicationFacade.server.getCompanyInfo { responseObject, _, errorMessage in
        defer {
          semaphore.signal()
        }
        if let errorMessage = errorMessage {
          errorMessageBlock = errorMessage
        } else if let dictCompany = (responseObject as? [AnyHashable: Any])?[DPAGStrings.JSON.Company.OBJECT_KEY] as? [AnyHashable: Any] {
          DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            if let account = SIMSAccount.mr_findFirst(in: localContext) {
              account.companyInfo = dictCompany
            }
          }
        } else {
          errorMessageBlock = "service.ERR-0001"
        }
      }
      _ = semaphore.wait(wallTimeout: .distantFuture)
      if let errorMessageBlock = errorMessageBlock {
        throw DPAGErrorAutomaticRegistration.error(errorMessageBlock)
      }
      _ = DPAGApplicationFacade.receiveMessagesWorker.getNewMessages(completion: { response in
        defer {
          semaphore.signal()
        }
        
        if let errorMessage = response.errorMessage {
          errorMessageBlock = errorMessage
        }
      }, useLazy: false)
      _ = semaphore.wait(wallTimeout: .distantFuture)
      if let errorMessageBlock = errorMessageBlock {
        throw DPAGErrorAutomaticRegistration.error(errorMessageBlock)
      }
      if let account = DPAGApplicationFacade.cache.account, account.aesKeyCompany != nil, account.aesKeyCompanyUserData != nil {
        break
      }
      Thread.sleep(forTimeInterval: 10.0)
    }
  }
}
