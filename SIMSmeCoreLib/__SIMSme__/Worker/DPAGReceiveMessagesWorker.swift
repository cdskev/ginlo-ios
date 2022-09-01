//
// Created by mg on 25.11.13.
// Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

public struct ReceivedMessagesWithNotification {
  public var messagesPrivate: [String] = []
  public var messagesGroup: [String] = []
  public var messagesGroupInvitation: [SIMSGroupInvitation] = []
  public var messagesChannel: [String] = []
  
  public var isEmpty: Bool {
    self.messagesPrivate.isEmpty && self.messagesGroup.isEmpty && self.messagesChannel.isEmpty && self.messagesGroupInvitation.isEmpty
  }
}

public struct ReceivedMessagesResponse {
  public let messagesWithNotification: ReceivedMessagesWithNotification?
  public let errorCode: String?
  public let errorMessage: String?
}

public protocol DPAGReceiveMessagesWorkerProtocol: AnyObject {
  func getNewMessages(completion block: @escaping (ReceivedMessagesResponse) -> Void, useLazy: Bool) -> URLSessionTask?
}

class DPAGReceiveMessagesWorker: NSObject, DPAGReceiveMessagesWorkerProtocol {
  private let receiveMessageDAO: ReceiveMessageDAOProtocol = ReceiveMessageDAO()
  
  private struct InternalMessageInfo {
    var loadTimedMessages = false
    var fetchOwnTempDevice = false
    var privateIndexUpdateGuids: [String: String] = [:]
    var removeConfirmedEmailAddressDB = false
    var removeConfirmedPhoneNumberDB = false
    var updateAccountId = false
    var profilInfoChangedGuids: Set<String> = Set()
    var unknownContactGuids: Set<String> = Set()
    var channelsToCheck: Set<String> = Set()
    var messageGuidsWithNotification = ReceivedMessagesWithNotification()
    var groupAutoAcceptedGuids: Set<String> = Set()
    var groupAutoUpdateGuids: Set<String> = Set()
    var groupInvitations: [SIMSGroupInvitation] = []
    var groupDeletedGuids: Set<String> = Set()
    var contactsUpdated: Set<String> = Set()
    var streamsUpdatedMeta: Set<String> = Set()
    var needsPrivateIndexUpdate = false
  }
  
  private struct GroupAddInfo {
    let groupGuid: String
    let messageGuid: String
    let messageGuidIndex: Int
    var contactGuids: Set<String>
    let sendDate: Date
    let senderGuid: String?
    let senderNick: String?
  }
  
  func getNewMessages(completion block: @escaping (ReceivedMessagesResponse) -> Void, useLazy: Bool) -> URLSessionTask? {
    let serviceResponseBlock: DPAGServiceResponseBlock = { [weak self] responseObject, errorCode, errorMessage in
      if let errorMessage = errorMessage {
        // Wenn Netzwerk nicht erreichbar (Flugmodus), dann nicht sofort zurückkehren, sondern für eine halbe sekunde pausieren
        if errorCode == "service.tryAgainLater" {
          Thread.sleep(forTimeInterval: 0.5)
        } else if errorCode == "backendservice.internet.connectionFailed" {
          Thread.sleep(forTimeInterval: 10)
        } else if errorCode == "service.error-999" {
          DPAGApplicationFacade.service.checkAutoDownloads()
        }
        block(ReceivedMessagesResponse(messagesWithNotification: nil, errorCode: errorCode, errorMessage: errorMessage))
      } else if let receivedMessages = responseObject as? [[AnyHashable: Any]] {
        let isActive = AppConfig.applicationState() == .active
        if CryptoHelper.sharedInstance?.isPrivateKeyDecrypted() ?? false, isActive {
          self?.handleNewMessages(receivedMessages, withResponseBlock: block)
        } else {
          block(ReceivedMessagesResponse(messagesWithNotification: nil, errorCode: errorCode, errorMessage: "Private key is not yet decrypted"))
        }
      } else {
        block(ReceivedMessagesResponse(messagesWithNotification: nil, errorCode: errorCode, errorMessage: "Invalid response"))
      }
    }
    return DPAGApplicationFacade.server.getNewMessages(withResponse: serviceResponseBlock, useLazy: useLazy)
  }
  
  private func handleNewMessages(_ receivedMessages: [[AnyHashable: Any]], withResponseBlock block: @escaping (ReceivedMessagesResponse) -> Void) {
    DPAGLog("messages received: %i", receivedMessages.count)
    guard let ownAccountGuid = DPAGApplicationFacade.cache.account?.guid, receivedMessages.count != 0 else {
      DPAGApplicationFacade.service.checkAutoDownloads()
      block(ReceivedMessagesResponse(messagesWithNotification: nil, errorCode: nil, errorMessage: nil))
      return
    }
    // TODO: ISO
    let sema = DispatchSemaphore(value: 1)
    let timeUp = DispatchTime.now() + Double(60 * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC)
    DPAGLog("Start handleNewMessages Lock")
    if sema.wait(timeout: timeUp) != .success {
      DPAGLog("Timed Out handleNewMessages Lock")
    }
    // dispatch_release(sema)
    DPAGLog("Finish  handleNewMessages Lock")
    do {
      try DPAGFunctionsGlobal.synchronizedWithError(self) {
        let decodedMessages = self.decodeMessages(receivedMessages)
        let messageGuidsWithNotification = try self.handleMessages(decodedMessages, ownAccountGuid: ownAccountGuid)
        DPAGApplicationFacade.service.checkAutoDownloads()
        DPAGApplicationFacade.cache.checkNotCheckedMessages()
        let blockResendPrivateInternal = { [weak self] in
          guard let ownAccountGuid = DPAGApplicationFacade.cache.account?.guid, let msgGuidsToResend = self?.receiveMessageDAO.selectPrivateInternalMessageGuidsToResend(ownAccountGuid: ownAccountGuid) else {
            return
          }
          do {
            try self?.resendPrivateInternalMessages(msgGuidsToResend)
          } catch {
            DPAGLog(error, message: "error resendPRivateInternal")
          }
        }
        let receivedMsgGuids = decodedMessages.compactMap { $0.guid }
        if receivedMsgGuids.count > 0 {
          DPAGLog("Start confirming download new messages")
          DPAGApplicationFacade.server.confirmDownload(guids: receivedMsgGuids) { _, _, errorMessage in
            DPAGLog("Finished confirming download new messages")
            if errorMessage == nil {
              guard let ownAccountGuid = DPAGApplicationFacade.cache.account?.guid else {
                return
              }
              self.receiveMessageDAO.updateDateDownloaded(forMessageGuids: receivedMsgGuids, ownAccountGuid: ownAccountGuid)
            }
            self.performBlockInBackground(blockResendPrivateInternal)
            block(ReceivedMessagesResponse(messagesWithNotification: messageGuidsWithNotification, errorCode: nil, errorMessage: nil))
          }
        } else {
          self.performBlockInBackground(blockResendPrivateInternal)
          block(ReceivedMessagesResponse(messagesWithNotification: messageGuidsWithNotification, errorCode: nil, errorMessage: nil))
        }
      }
    } catch {
      DPAGLog(error)
    }
    DPAGLog("Release handleNewMessages Lock")
    sema.signal()
  }
  
  private func handleMessagesAfterSave(_ messages: [DPAGMessageReceivedCore], ownAccountGuid: String) throws -> InternalMessageInfo {
    var messageInfo = InternalMessageInfo()
    var contactToCheck: DPAGContact?
    var isOwnMessage = false
    for message in messages {
      switch message.messageType {
        case .private:
          guard let messagePrivate = message as? DPAGMessageReceivedPrivate else { break }
          if messagePrivate.fromAccountInfo.accountGuid != ownAccountGuid, messagePrivate.pushInfo != "nopush" {
            messageInfo.messageGuidsWithNotification.messagesPrivate.append(messagePrivate.guid)
          }
          if messagePrivate.fromAccountInfo.accountGuid == ownAccountGuid {
            isOwnMessage = true
            contactToCheck = DPAGApplicationFacade.cache.contact(for: messagePrivate.toAccountInfo.accountGuid)
          } else {
            contactToCheck = DPAGApplicationFacade.cache.contact(for: messagePrivate.fromAccountInfo.accountGuid)
          }
        case .privateInternal:
          guard let messagePrivateInternal = message as? DPAGMessageReceivedPrivateInternal else { break }
          self.handlePrivateInternalMessage(messagePrivateInternal, ownAccountGuid: ownAccountGuid, messageInfo: &messageInfo)
        case .internal:
          guard let messageInternal = message as? DPAGMessageReceivedInternal else { break }
          self.handleInternalMessage(messageInternal, ownAccountGuid: ownAccountGuid, messageInfo: &messageInfo)
        case .group:
          guard let messageGroup = message as? DPAGMessageReceivedGroup else { break }
          if messageGroup.fromAccountInfo.accountGuid != ownAccountGuid, messageGroup.pushInfo != "nopush" {
            messageInfo.messageGuidsWithNotification.messagesGroup.append(messageGroup.guid)
          }
          if messageGroup.fromAccountInfo.accountGuid == ownAccountGuid {
            isOwnMessage = true
          } else {
            contactToCheck = DPAGApplicationFacade.cache.contact(for: messageGroup.fromAccountInfo.accountGuid)
          }
        case .groupInvitation:
          guard let messageGroupInvitation = message as? DPAGMessageReceivedGroupInvitation else { break }
          if messageGroupInvitation.fromAccountInfo.accountGuid == ownAccountGuid {
            isOwnMessage = true
          } else {
            contactToCheck = DPAGApplicationFacade.cache.contact(for: messageGroupInvitation.fromAccountInfo.accountGuid)
          }
          let contentDecrypted = try messageGroupInvitation.contentDecrypted()
          if contentDecrypted.groupImageEncoded == nil {
            messageInfo.groupAutoUpdateGuids.insert(contentDecrypted.groupGuid)
          }
          let invitationObj = SIMSGroupInvitation(invitationGuid: messageGroupInvitation.guid, andGroupGuid: contentDecrypted.groupGuid)
          var checkPush = false
          switch contentDecrypted.groupType {
            case .managed, .restricted:
              messageInfo.groupAutoAcceptedGuids.insert(contentDecrypted.groupGuid)
              checkPush = true
            default:
              if messageGroupInvitation.fromAccountInfo.accountGuid == ownAccountGuid {
                messageInfo.groupAutoAcceptedGuids.insert(contentDecrypted.groupGuid)
              } else {
                checkPush = true
              }
          }
          if checkPush, messageGroupInvitation.fromAccountInfo.accountGuid != ownAccountGuid, messageGroupInvitation.pushInfo != "nopush" {
            messageInfo.messageGuidsWithNotification.messagesGroupInvitation.append(invitationObj)
          }
        case .channel:
          guard let messageChannel = message as? DPAGMessageReceivedChannel else { break }
          messageInfo.channelsToCheck.insert(messageChannel.toAccountGuid)
          if messageChannel.pushInfo != "nopush" {
            messageInfo.messageGuidsWithNotification.messagesChannel.append(messageChannel.guid)
          }
        case .confirmTimedMessageSent:
          break
        case .unknown:
          break
      }
    }
    if let contactToCheck = contactToCheck {
      if contactToCheck.publicKey == nil {
        messageInfo.profilInfoChangedGuids.insert(contactToCheck.guid)
      }
      if isOwnMessage, contactToCheck.isConfirmed == false {
        messageInfo.needsPrivateIndexUpdate = true
      }
    }
    return messageInfo
  }
  
  private func updateProfileInfo(forContactGuids contactGuids: [String]) {
    contactGuids.forEach { contactGuid in
      DPAGApplicationFacade.preferences.setNeedsProfileSynchronization(forProfileGuid: contactGuid)
    }
    DPAGApplicationFacade.server.getAccountsInfo(guids: contactGuids) { responseObject, _, errorMessage in
      guard errorMessage == nil, let dicts = responseObject as? [[AnyHashable: Any]] else { return }
      for dict in dicts {
        guard let dictAccountInfo = dict[DPAGStrings.JSON.Account.OBJECT_KEY] as? [String: Any], let contactGuid = dictAccountInfo[SIMS_GUID] as? String else { continue }
        let notificationToSend = DPAGApplicationFacade.contactsWorker.updateContact(contactGuid: contactGuid, withAccountJson: dictAccountInfo)
        DPAGApplicationFacade.preferences.setProfileSynchronizationDone(forProfileGuid: contactGuid)
        if let notificationToSend = notificationToSend {
          NotificationCenter.default.post(name: notificationToSend, object: nil, userInfo: [DPAGStrings.Notification.Contact.CHANGED__USERINFO_KEY__CONTACT_GUID: contactGuid])
        }
      }
    }
  }
  
  private func handleMessageInfo(_ messageInfo: InternalMessageInfo, ownAccountGuid: String) {
    if messageInfo.loadTimedMessages {
      self.performBlockInBackground {
        do {
          try DPAGApplicationFacade.backupWorker.loadTimedMessages()
        } catch {
          DPAGLog(error, message: "loadTimedMessages failed with exception")
        }
      }
      // DPAGApplicationFacade.preferences.forceNeedsConfigSynchronization()
    }
    if messageInfo.fetchOwnTempDevice {
      DPAGApplicationFacade.couplingWorker.fetchOwnTempDevice()
    }
    if messageInfo.removeConfirmedEmailAddressDB {
      do {
        // Eigene E-Mail-Adresse wurde entfernt
        try DPAGApplicationFacade.accountManager.removeConfirmedEmailAddressDB()
      } catch {
        DPAGLog(error)
      }
    }
    if messageInfo.removeConfirmedPhoneNumberDB {
      do {
        // Eigene Telefonnummer wurde entfernt
        try DPAGApplicationFacade.accountManager.removeConfirmedPhoneNumberDB()
      } catch {
        DPAGLog(error)
      }
    }
    if messageInfo.updateAccountId {
      // AccountID neu laden
      self.performBlockInBackground {
        DPAGApplicationFacade.accountManager.updateAccountID(accountGuid: ownAccountGuid)
      }
    }
    if messageInfo.privateIndexUpdateGuids.count > 0 {
      self.performBlockInBackground {
        do {
          try DPAGApplicationFacade.couplingWorker.fetchPrivateIndexEntries(entries: messageInfo.privateIndexUpdateGuids)
        } catch {
          DPAGLog(error, message: "fetchPrivateIndex failed with exception")
        }
      }
    }
    self.updateProfileInfo(forContactGuids: Array(messageInfo.profilInfoChangedGuids))
    let unknownContactGuids = self.receiveMessageDAO.filterContactGuidsForUnknown(contactGuids: messageInfo.unknownContactGuids)
    DPAGApplicationFacade.updateKnownContactsWorker.synchronize(accountGuids: Array(unknownContactGuids)) { _, _, _ in }
    if messageInfo.needsPrivateIndexUpdate {
      let lastSuccessFullSync = DPAGApplicationFacade.preferences.lastSuccessFullSyncPrivateIndex
      
      do {
        try DPAGApplicationFacade.couplingWorker.loadPrivateIndexFromServer(ifModifiedSince: lastSuccessFullSync, forceLoad: false)
      } catch {
        DPAGLog(error, message: "error loadPrivateIndexFromServer")
      }
    }
    messageInfo.streamsUpdatedMeta.forEach { streamGuid in
      NotificationCenter.default.post(name: DPAGStrings.Notification.ChatStream.NEEDS_UPDATE_META, object: self, userInfo: [DPAGStrings.Notification.ChatStream.NEEDS_UPDATE__USERINFO_KEY__STREAM_GUID: streamGuid])
    }
    messageInfo.groupAutoAcceptedGuids.forEach { groupGuid in
      DPAGApplicationFacade.chatRoomWorker.acceptInvitationForRoom(groupGuid) { _, _, _ in
      }
    }
    messageInfo.groupDeletedGuids.forEach { groupGuid in
      NotificationCenter.default.post(name: DPAGStrings.Notification.Group.WAS_DELETED, object: self, userInfo: [DPAGStrings.Notification.Group.WAS_DELETED__USERINFO_KEY__GROUP_GUID: groupGuid])
    }
    messageInfo.groupAutoUpdateGuids.forEach { groupGuid in
      DPAGApplicationFacade.chatRoomWorker.checkGroupSynchronization(forGroup: groupGuid, force: true, notify: true)
    }
    let channelCheckResult = self.receiveMessageDAO.filterChannelsForUnsubscribe(channelGuids: messageInfo.channelsToCheck)
    channelCheckResult.channelsToUnsubscribe.forEach { channelGuid in
      DPAGApplicationFacade.feedWorker.unsubscribeFeed(feedGuid: channelGuid, feedType: .channel) { _, _, _ in }
    }
    for contactGuid in messageInfo.contactsUpdated {
      NotificationCenter.default.post(name: DPAGStrings.Notification.Contact.CHANGED, object: self, userInfo: [DPAGStrings.Notification.Contact.CHANGED__USERINFO_KEY__CONTACT_GUID: contactGuid])
    }
  }
  
  private func handleMessages(_ messages: [DPAGMessageReceivedCore], ownAccountGuid: String) throws -> ReceivedMessagesWithNotification {
    self.handleMessagesBeforeSave(messages, ownAccountGuid: ownAccountGuid)
    DPAGLog("Start saving new messages")
    self.receiveMessageDAO.saveReceivedMessages(messages, ownAccountGuid: ownAccountGuid)
    DPAGLog("Finished saving new messages")
    // collect informations to do batch work afterwards
    let messageInfo = try self.handleMessagesAfterSave(messages, ownAccountGuid: ownAccountGuid)
    // do batch work
    self.handleMessageInfo(messageInfo, ownAccountGuid: ownAccountGuid)
    return messageInfo.messageGuidsWithNotification
  }
  
  private func handleMessagesBeforeSave(_ messages: [DPAGMessageReceivedCore], ownAccountGuid: String) {
    for message in messages {
      switch message.messageType {
        case .privateInternal:
          guard let messagePrivateInternal = message as? DPAGMessageReceivedPrivateInternal else { break }
          self.handlePrivateInternalMessageBeforeSave(messagePrivateInternal, ownAccountGuid: ownAccountGuid)
        case .private, .internal, .group, .groupInvitation, .channel, .confirmTimedMessageSent, .unknown:
          break
      }
    }
  }
  
  private func handlePrivateInternalMessageBeforeSave(_ messagePrivateInternal: DPAGMessageReceivedPrivateInternal, ownAccountGuid _: String) {
    guard let messageDecrypted = messagePrivateInternal.contentDecrypted else {
      return
    }
    
    if messageDecrypted.contentType == DPAGStrings.JSON.Message.ContentType.COMPANY_ENCRYPTION_INFO {
      if let seed = messageDecrypted.messageDict.unknownContent[DPAGStrings.Server.MessageReceivedPrivateInternalDecrypted.Response.COMPANY_ENCRYPTION_SEED] as? String, let salt = messageDecrypted.messageDict.unknownContent[DPAGStrings.Server.MessageReceivedPrivateInternalDecrypted.Response.COMPANY_ENCRYPTION_SALT] as? String {
        guard let account = DPAGApplicationFacade.cache.account, let ownContact = DPAGApplicationFacade.cache.contact(for: account.guid) else {
          return
        }
        
        var phoneNumber: String?
        var email: String?
        var diff: String?
        
        if let encryptionParts = messageDecrypted.messageDict.unknownContent[DPAGStrings.Server.MessageReceivedPrivateInternalDecrypted.Response.COMPANY_ENCRYPTION_PARTS] as? String {
          if encryptionParts.range(of: "phone") != nil {
            phoneNumber = ownContact.phoneNumber
          }
          if encryptionParts.range(of: "mail") != nil {
            email = ownContact.eMailAddress
          }
        }
        diff = messageDecrypted.messageDict.unknownContent[DPAGStrings.Server.MessageReceivedPrivateInternalDecrypted.Response.COMPANY_ENCRYPTION_DIFF] as? String
        
        let accountDAO: AccountDAOProtocol = AccountDAO()
        
        accountDAO.setCompanySeed(seed, salt: salt, phoneNumber: phoneNumber, email: email, diff: diff)
        
        // MDM Config neu lesen
        DPAGApplicationFacade.preferences.forceNeedsConfigSynchronization()
        
        // Eigentlich ist der Company PublicKey schon gesetzt.
        if account.companyPublicKey == nil {
          DPAGApplicationFacade.profileWorker.getCompanyInfo(withResponse: nil)
        }
      }
    } else if messageDecrypted.contentType == DPAGStrings.JSON.Message.ContentType.COMPANY_REQUEST_CONFIRM_PHONE {
      if let phoneNumber = messageDecrypted.messageDict.unknownContent[DPAGStrings.Server.MessageReceivedPrivateInternalDecrypted.Response.COMPANY_REQUEST_CONFIRM_PHONENUMBER] as? String, phoneNumber.isEmpty == false {
        DPAGApplicationFacade.preferences.validationPhoneNumber = phoneNumber
        
        NotificationCenter.default.post(name: DPAGStrings.Notification.Account.CONFIRMED_IDENTITIES_CHANGED, object: nil)
      }
    } else if messageDecrypted.contentType == DPAGStrings.JSON.Message.ContentType.COMPANY_REQUEST_CONFIRM_EMAIL {
      if let emailAddress = messageDecrypted.messageDict.unknownContent[DPAGStrings.Server.MessageReceivedPrivateInternalDecrypted.Response.COMPANY_REQUEST_CONFIRM_EMAILADDRESS] as? String, emailAddress.isEmpty == false {
        DPAGApplicationFacade.preferences.validationEmailAddress = emailAddress
        
        NotificationCenter.default.post(name: DPAGStrings.Notification.Account.CONFIRMED_IDENTITIES_CHANGED, object: nil)
      }
    }
  }
  
  private func handlePrivateInternalMessage(_ privateInternalMessageDict: DPAGMessageReceivedPrivateInternal, ownAccountGuid: String, messageInfo: inout InternalMessageInfo) {
    guard let messageDecrypted = privateInternalMessageDict.contentDecrypted else {
      return
    }
    
    if messageDecrypted.contentType == DPAGStrings.JSON.Message.ContentType.IMAGE, messageDecrypted.contentValue as? String != nil {
      let fromAccountGuid = privateInternalMessageDict.fromAccountInfo.accountGuid
      
      if let contact = DPAGApplicationFacade.cache.contact(for: fromAccountGuid) {
        contact.removeCachedImages()
        
        messageInfo.contactsUpdated.insert(fromAccountGuid)
      }
    } else if messageDecrypted.contentType == DPAGStrings.JSON.MessageInternal.ObjectKey.NEW_GROUP_MEMBERS, let newGuids = messageDecrypted.contentValue as? [String] {
      messageInfo.unknownContactGuids.formUnion(newGuids)
    } else if messageDecrypted.contentType == DPAGStrings.JSON.MessageInternal.ObjectKey.REMOVED_GROUP_MEMBERS, let removedGuids = messageDecrypted.contentValue as? [String] {
      if let groupGuid = messageDecrypted.contentDict?[DPAGStrings.Server.MessageReceivedPrivateInternalDecrypted.Response.GROUP_GUID] as? String {
        if removedGuids.contains(ownAccountGuid) {
          messageInfo.groupDeletedGuids.insert(groupGuid)
        }
      }
    }
  }
  
  private func handleInternalMessage(_ internalMessageDict: DPAGMessageReceivedInternal, ownAccountGuid: String, messageInfo: inout InternalMessageInfo) {
    if let data = internalMessageDict.confirmDownload {
      data.guids.forEach { guid in
        NotificationCenter.default.post(name: DPAGStrings.Notification.Message.METADATA_UPDATED, object: nil, userInfo: [DPAGStrings.Notification.Message.METADATA_UPDATED__USERINFO_KEY__MESSAGE_GUID: guid])
      }
    }
    
    if let data = internalMessageDict.confirmRead {
      data.guids.forEach { guid in
        NotificationCenter.default.post(name: DPAGStrings.Notification.Message.METADATA_UPDATED, object: nil, userInfo: [DPAGStrings.Notification.Message.METADATA_UPDATED__USERINFO_KEY__MESSAGE_GUID: guid])
      }
    }
    
    if let data = internalMessageDict.groupOwnerChanged {
      messageInfo.streamsUpdatedMeta.insert(data.roomGuid)
    }
    
    if let data = internalMessageDict.groupRemoved {
      if internalMessageDict.from != ownAccountGuid {
        NotificationCenter.default.post(name: DPAGStrings.Notification.Group.WAS_DELETED, object: self, userInfo: [DPAGStrings.Notification.Group.WAS_DELETED__USERINFO_KEY__GROUP_GUID: data.guid])
      } else {
        DPAGApplicationFacade.chatRoomWorker.removeRoom(data.guid)
      }
    }
    
    if let data = internalMessageDict.groupMembersNew {
      messageInfo.unknownContactGuids.formUnion(data.guids)
      
      if data.guids.contains(ownAccountGuid) {
        messageInfo.groupAutoUpdateGuids.insert(data.roomGuid)
      }
    }
    
    if let data = internalMessageDict.groupMembersRemoved {
      if data.guids.contains(ownAccountGuid), data.senderGuid == ownAccountGuid {
        DPAGApplicationFacade.chatRoomWorker.removeRoom(data.roomGuid)
      }
      messageInfo.streamsUpdatedMeta.insert(data.roomGuid)
    }
    
    if let data = internalMessageDict.groupMembersInvited {
      messageInfo.unknownContactGuids.formUnion(data.guids)
      messageInfo.streamsUpdatedMeta.insert(data.roomGuid)
    }
    
    if let data = internalMessageDict.groupMembersAdminGranted {
      messageInfo.streamsUpdatedMeta.insert(data.roomGuid)
    }
    
    if let data = internalMessageDict.groupMembersAdminRevoked {
      messageInfo.streamsUpdatedMeta.insert(data.roomGuid)
    }
    
    if let data = internalMessageDict.channelRemoved {
      NotificationCenter.default.post(name: DPAGStrings.Notification.Channel.WAS_DELETED, object: self, userInfo: [DPAGStrings.Notification.Channel.WAS_DELETED__USERINFO_KEY__CHANNEL_GUID: data.guid])
    }
    
    if let data = internalMessageDict.profilInfoChanged {
      if data.accountGuid != ownAccountGuid {
        messageInfo.profilInfoChangedGuids.insert(data.accountGuid)
      }
    }
    
    if let data = internalMessageDict.groupInfoChanged {
      DPAGApplicationFacade.chatRoomWorker.checkGroupSynchronization(forGroup: data.groupGuid, force: true, notify: true)
    }
    
    if let data = internalMessageDict.configVersionChanged {
      if let details = data.configDetails, let cmd = details["cmd"], cmd == "insUpdPrivateIndexEntry" {
        if let checksum = details["data-checksum"] as? String, let guid = details["guid"] as? String {
          messageInfo.privateIndexUpdateGuids[guid] = checksum
        }
      } else {
        DPAGApplicationFacade.preferences.forceNeedsConfigSynchronization()
      }
    }
    
    if internalMessageDict.confirmMessageSend != nil {
      self.performBlockInBackground {
        do {
          try DPAGApplicationFacade.backupWorker.loadTimedMessages()
        } catch {
          DPAGLog(error, message: "loadTimedMessages failed with exception")
        }
      }
      // DPAGApplicationFacade.preferences.forceNeedsConfigSynchronization()
    }
    
    if internalMessageDict.deviceCreated != nil || internalMessageDict.deviceRemoved != nil {
      DPAGApplicationFacade.couplingWorker.fetchOwnTempDevice()
    }
    
    if internalMessageDict.emailAddressRevoked != nil {
      do {
        // Eigene E-Mail-Adresse wurde entfernt
        try DPAGApplicationFacade.accountManager.removeConfirmedEmailAddressDB()
      } catch {
        DPAGLog(error)
      }
    }
    
    if internalMessageDict.phoneNumberRevoked != nil {
      do {
        // Eigene Telefonnummer wurde entfernt
        try DPAGApplicationFacade.accountManager.removeConfirmedPhoneNumberDB()
      } catch {
        DPAGLog(error)
      }
    }
    
    if let data = internalMessageDict.chatDeleted {
      if let contact = DPAGApplicationFacade.cache.contact(for: data.guid), let streamGuid = contact.streamGuid {
        DPAGApplicationFacade.contactsWorker.deletePrivateStream(streamGuid: streamGuid, syncWithServer: false, responseBlock: { _, _, _ in })
      }
    }
    
    if internalMessageDict.updateAccountId != nil {
      // AccountID neu laden
      self.performBlockInBackground {
        DPAGApplicationFacade.accountManager.updateAccountID(accountGuid: ownAccountGuid)
      }
    }
  }
  
  private func decodeMessage(messageItemDictionary: [AnyHashable: Any], type: DPAGMessageReceivedCore.Type) -> DPAGMessageReceivedCore? {
    if let message = try? DictionaryDecoder().decode(type, from: messageItemDictionary) {
      return message
    } else if let messageUndecodable = try? DictionaryDecoder().decode(DPAGMessageReceivedCore.self, from: messageItemDictionary) {
      // try to decode at least the message guid, to mark it as downloaded
      return messageUndecodable
    }
    return nil
  }
  
  private func dumpMessage(_ message: [AnyHashable:Any]) {
    for (blaKey, blaValue) in message {
      NSLog("••••••••• \(blaKey): \(blaValue)")
    }
  }
  private func decodeMessages(_ messages: [[AnyHashable: Any]]) -> [DPAGMessageReceivedCore] {
    var decodedMessages: [DPAGMessageReceivedCore] = []
    for messageDictionary in messages {
      for (messageAnyKey, messageAnyValue) in messageDictionary {
        guard let messageKey = messageAnyKey as? String else { continue }
        guard let messageDictionary = messageAnyValue as? [AnyHashable: Any] else { continue }
//        self.dumpMessage(messageDictionary)
        var decodedMessage: DPAGMessageReceivedCore?
        switch messageKey {
          case DPAGMessageReceivedListItem.CodingKeys.messagePrivate.rawValue:
            decodedMessage = self.decodeMessage(messageItemDictionary: messageDictionary, type: DPAGMessageReceivedPrivate.self)
          case DPAGMessageReceivedListItem.CodingKeys.messagePrivateInternal.rawValue:
            decodedMessage = self.decodeMessage(messageItemDictionary: messageDictionary, type: DPAGMessageReceivedPrivateInternal.self)
          case DPAGMessageReceivedListItem.CodingKeys.messageInternal.rawValue:
            decodedMessage = self.decodeMessage(messageItemDictionary: messageDictionary, type: DPAGMessageReceivedInternal.self)
          case DPAGMessageReceivedListItem.CodingKeys.messageGroup.rawValue:
            decodedMessage = self.decodeMessage(messageItemDictionary: messageDictionary, type: DPAGMessageReceivedGroup.self)
          case DPAGMessageReceivedListItem.CodingKeys.messageGroupInvitation.rawValue:
            decodedMessage = self.decodeMessage(messageItemDictionary: messageDictionary, type: DPAGMessageReceivedGroupInvitation.self)
          case DPAGMessageReceivedListItem.CodingKeys.messageChannel.rawValue, DPAGMessageReceivedListItem.CodingKeys.messageService.rawValue:
            decodedMessage = self.decodeMessage(messageItemDictionary: messageDictionary, type: DPAGMessageReceivedChannel.self)
          case DPAGMessageReceivedListItem.CodingKeys.messageConfirmSend.rawValue:
            decodedMessage = self.decodeMessage(messageItemDictionary: messageDictionary, type: DPAGMessageReceivedConfirmTimedMessageSend.self)
          default:
            // try to decode at least the message guid, to mark it as downloaded
            decodedMessage = self.decodeMessage(messageItemDictionary: messageDictionary, type: DPAGMessageReceivedCore.self)
        }
        if let decodedMessage = decodedMessage {
          decodedMessages.append(decodedMessage)
        }
      }
    }
    return decodedMessages
  }
  
  private func resendPrivateInternalMessages(_ privateInternalMessageGuids: [String]) throws {
    guard privateInternalMessageGuids.count > 0 else { return }
    let messageJsonsString = self.receiveMessageDAO.messageJSON(forPrivateInternalMessageGuids: privateInternalMessageGuids)
    let block: DPAGServiceResponseBlock = { _, _, errorMessage in
      guard errorMessage == nil else { return }
      self.receiveMessageDAO.deleteSentPrivateInternalMessages(privateInternalMessageGuids: privateInternalMessageGuids)
    }
    if let messageJsonsString = messageJsonsString {
      try DPAGApplicationFacade.server.sendInternalMessages(messageJsonsString: messageJsonsString, withResponse: block)
    }
  }
}
