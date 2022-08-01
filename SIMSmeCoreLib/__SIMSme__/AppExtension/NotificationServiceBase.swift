//
//  NotificationServiceBase.swift
// ginlo
//
//  Created by Matthias Röhricht on 20.03.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AFNetworking
import UserNotifications

open class NotificationServiceBase: UNNotificationServiceExtension {
  var _httpSessionManager: AFHTTPSessionManager?
  
  private func httpSessionManager(urlHttpService: String) -> AFHTTPSessionManager {
    if let _httpSessionManager = self._httpSessionManager {
      return _httpSessionManager
    }
    let defaultConfiguration = URLSessionConfiguration.ephemeral
    defaultConfiguration.httpMaximumConnectionsPerHost = 6
    defaultConfiguration.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
    defaultConfiguration.allowsCellularAccess = true
    defaultConfiguration.isDiscretionary = false
    defaultConfiguration.urlCache = nil
    defaultConfiguration.urlCredentialStorage = nil
    let manager = AFHTTPSessionManager(baseURL: URL(string: urlHttpService), sessionConfiguration: defaultConfiguration)
    DPAGExtensionHelper.initHttpSessionManager(manager: manager, qos: .userInitiated)
    self._httpSessionManager = manager
    return manager
  }
  
  public var contentHandler: ((UNNotificationContent) -> Void)?
  public var bestAttemptContent: UNMutableNotificationContent?
  
  override open func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    self.contentHandler = contentHandler
    self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
    contentHandler(request.content)
  }
  
  override open func serviceExtensionTimeWillExpire() {
    // Called just before the extension will be terminated by the system.
    // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
    if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
      contentHandler(bestAttemptContent)
    }
  }
  
  public final func handleContent(_ request: UNNotificationRequest, config: DPAGSharedContainerConfig, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    DPAGLog("IMDAT::Received push notification, request = \(request)")
    guard let bestAttemptContent = self.bestAttemptContent, let messageGuid = bestAttemptContent.userInfo["messageGuid"] as? String else {
      DPAGLog("no MessageGuid")
      contentHandler(request.content)
      return
    }
    do {
      // Lesen des PrivatKey aus der KeyChain
      guard let privateKey = DPAGSharedContainerExtension().getPushPreviewKey(config: config) else {
        DPAGLog("no privateKey")
        contentHandler(bestAttemptContent)
        return
      }
      // Lesen der Infos
      guard let sharedContainer = try DPAGSharedContainerExtension().readfile(config: config) else {
        DPAGLog("no sharedContainer")
        contentHandler(bestAttemptContent)
        return
      }
      // privat
      if messageGuid.starts(with: "100"), let senderGuid = bestAttemptContent.userInfo["senderGuid"] as? String, let contact = sharedContainer.contacts[senderGuid] {
        if contact.confidenceState > DPAGConfidenceState.low.rawValue {
          try self.loadMessageValues(httpUsername: sharedContainer.account.accountPreference.httpUsername, httpPassword: sharedContainer.account.accountPreference.backgroundAccessToken, messageGuid: messageGuid, publicKey: sharedContainer.account.accountPreference.publicKey, privateKey: privateKey, groupAesKey: nil, config: config) { _, content in
            // TODO: ISO-AV-Call Interpretation here
            if let content = content {
              bestAttemptContent.title = contact.name
              bestAttemptContent.body = self.getBody(content: content)
              if let locKey = ((bestAttemptContent.userInfo["aps"] as? [AnyHashable: Any])?["alert"] as? [AnyHashable: Any])?["loc-key"] as? String, locKey == "push.newPNexHigh" {
                bestAttemptContent.body = "!!! " + bestAttemptContent.body
              }
              let contentType = DPAGMessageContentType.contentType(for: content.contentType)
              if contentType == .avCallInvitation {
                bestAttemptContent.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "ringing.aiff"))
              }
            } else {
              DPAGLog("no content")
            }
            contentHandler(bestAttemptContent)
          }
        } else {
          bestAttemptContent.title = contact.name
          contentHandler(bestAttemptContent)
        }
        return
      }
      // Gruppe
      else if messageGuid.starts(with: "101"), let senderGuid = bestAttemptContent.userInfo["senderGuid"] as? String, let group = sharedContainer.groups[senderGuid] {
        let groupName = group.groupPreference.name
        // TODO: ISO-AV-Call Interpretation here (Group-Call)
        try self.loadMessageValues(httpUsername: sharedContainer.account.accountPreference.httpUsername, httpPassword: sharedContainer.account.accountPreference.backgroundAccessToken, messageGuid: messageGuid, publicKey: sharedContainer.account.accountPreference.publicKey, privateKey: privateKey, groupAesKey: group.groupPreference.aesKey, config: config) { fromAccountGuid, content in
          if let content = content {
            if DPAGMessageContentType.contentType(for: content.contentType) != .textRSS {
              if let contactName = sharedContainer.contacts[fromAccountGuid]?.name {
                bestAttemptContent.title = contactName + "@" + groupName
              } else if let contactName = content.nick {
                bestAttemptContent.title = contactName + "@" + groupName
              } else {
                bestAttemptContent.title = "@" + groupName
              }
            } else {
              bestAttemptContent.title = "@" + groupName
            }
            bestAttemptContent.body = self.getBody(content: content)
            if let locKey = ((bestAttemptContent.userInfo["aps"] as? [AnyHashable: Any])?["alert"] as? [AnyHashable: Any])?["loc-key"] as? String, locKey == "push.newPNexHigh" {
              bestAttemptContent.body = "!!! " + bestAttemptContent.body
            }
            let contentType = DPAGMessageContentType.contentType(for: content.contentType)
            if contentType == .avCallInvitation {
              bestAttemptContent.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "ringing.aiff"))
            }
          } else {
            DPAGLog("no content")
          }
          contentHandler(bestAttemptContent)
        }
        return
      } else {
        DPAGLog("no Message to Handle")
        contentHandler(bestAttemptContent)
      }
    } catch {
      DPAGLog(error)
    }
    contentHandler(bestAttemptContent)
  }
  
  func loadMessageValues(httpUsername: String, httpPassword: String, messageGuid: String, publicKey: String, privateKey: String, groupAesKey: String?, config: DPAGSharedContainerConfig, completion: @escaping (String, DPAGMessageDictionary?) -> Void) throws {
    try self.loadServerMessage(httpUsername: httpUsername, httpPassword: httpPassword, messageGuid: messageGuid, config: config) { (fromAccountGuid: String?, msg: DPAGMessageReceivedCore?) in
      var content: DPAGMessageDictionary?
      var contactGuid: String = fromAccountGuid ?? ""
      do {
        if let messagePrivate = msg as? DPAGMessageReceivedPrivate {
          contactGuid = messagePrivate.fromAccountInfo.accountGuid
          let data = messagePrivate.data
          let key = messagePrivate.toAccountInfo.encAesKey
          let key2 = messagePrivate.toAccountInfo.encAesKey2
          let aesKey2IV = messagePrivate.aesKey2IV
          let accountCrypto = try CryptoHelperSimple(publicKey: publicKey, privateKey: privateKey)
          content = self.decryptMessageDict(data, encAesKey: key, encAesKey2: key2, aesKeyIV: aesKey2IV, accountCrypto: accountCrypto)
        } else if let messageGroup = msg as? DPAGMessageReceivedGroup, let groupAesKey = groupAesKey {
          contactGuid = messageGroup.fromAccountInfo.accountGuid
          let data = messageGroup.data
          content = self.decryptGroupMessageData(data, decAesKey: groupAesKey)
        }
        try self.markMessageDownload(httpUsername: httpUsername, httpPassword: httpPassword, messageGuid: messageGuid, config: config)
      } catch {
        DPAGLog(error)
      }
      completion(contactGuid, content)
    }
  }
  
  func loadServerMessage(httpUsername: String, httpPassword: String, messageGuid: String, config: DPAGSharedContainerConfig, completion: @escaping (String?, DPAGMessageReceivedCore?) -> Void) throws {
    try self.getServerMessage(httpUsername: httpUsername, httpPassword: httpPassword, messageGuid: messageGuid, config: config) { responseObject, _ in
      if let dictMessage = responseObject as? [AnyHashable: Any] {
        if let dictMessagePrivate = dictMessage[DPAGStrings.JSON.MessagePrivate.OBJECT_KEY] as? [AnyHashable: Any], let messagePrivate = try? DictionaryDecoder().decode(DPAGMessageReceivedPrivate.self, from: dictMessagePrivate), messagePrivate.guid == messageGuid {
          completion(messagePrivate.fromAccountInfo.accountGuid, messagePrivate)
        } else if let dictMessageGroup = dictMessage[DPAGStrings.JSON.MessageGroup.OBJECT_KEY] as? [AnyHashable: Any], let messageGroup = try? DictionaryDecoder().decode(DPAGMessageReceivedGroup.self, from: dictMessageGroup), messageGroup.guid == messageGuid {
          completion(messageGroup.fromAccountInfo.accountGuid, messageGroup)
        } else {
          completion(nil, nil)
        }
      } else {
        completion(nil, nil)
      }
    }
  }
  
  func decryptMessageDict(_ encMessageDict: String?, encAesKey: String?, encAesKey2: String?, aesKeyIV iv: String?, accountCrypto: CryptoHelperSimple) -> DPAGMessageDictionary? {
    guard let messageDict = encMessageDict else {
      return nil
    }
    var decryptedMessageDict: DPAGMessageDictionary?
    do {
      if let encAesKey2 = encAesKey2, let iv = iv {
        guard let decAesKey = try accountCrypto.decryptAesKey(encryptedAeskey: encAesKey2) else {
          return decryptedMessageDict
        }
        if let decMessage = self.decryptMessageDict(messageDict, decAesKeyDictionary: DPAGAesKeyDecrypted(aesKey: decAesKey, iv: iv)) {
          decryptedMessageDict = self.decryptedMessageDict(decMessage)
        }
      } else if let encAesKey = encAesKey {
        guard let decAesKey = try accountCrypto.decryptAesKey(encryptedAeskey: encAesKey) else {
          return decryptedMessageDict
        }
        if let decMessage = self.decryptMessageDict(messageDict, decAesKey: decAesKey) {
          decryptedMessageDict = self.decryptedMessageDict(decMessage)
        }
      }
    } catch {
      DPAGLog(error)
    }
    return decryptedMessageDict
  }
  
  func decryptMessageDict(_ encMessageDict: String, decAesKeyDictionary decAesKeyDict: DPAGAesKeyDecrypted) -> String? {
    var decMessage: String?
    do {
      decMessage = try CryptoHelperDecrypter.decryptToString(encryptedString: encMessageDict, withAesKeyDict: decAesKeyDict.dict)
    } catch {
      DPAGLog(error)
    }
    return decMessage
  }
  
  func decryptMessageDict(_ encMessageDict: String, decAesKey: String) -> String? {
    var decMessage: String?
    do {
      decMessage = try CryptoHelperDecrypter.decryptToString(encryptedString: encMessageDict, withAesKey: decAesKey)
    } catch {
      DPAGLog(error)
    }
    return decMessage
  }
  
  func decryptGroupMessageData(_ messageData: String, decAesKey: String) -> DPAGMessageDictionary? {
    var decryptedMessageDict: DPAGMessageDictionary?
    if let encMessageData = Data(base64Encoded: messageData), encMessageData.count >= 16 {
      let iv = encMessageData.subdata(in: 0 ..< 16).base64EncodedString()
      let dataString = encMessageData.subdata(in: 16 ..< encMessageData.count).base64EncodedString()
      let aesKeyDict = DPAGAesKeyDecrypted(aesKey: decAesKey, iv: iv)
      if let decJsonString = self.decryptMessageDict(dataString, decAesKeyDictionary: aesKeyDict) {
        decryptedMessageDict = self.decryptedMessageDict(decJsonString)
      }
    }
    return decryptedMessageDict
  }
  
  private func decryptedMessageDict(_ decMessage: String) -> DPAGMessageDictionary? {
    guard let data = decMessage.data(using: .utf8) else {
      return nil
    }
    do {
      if let messageDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
        return DPAGMessageDictionary(dict: messageDict)
      }
    } catch let error as NSError {
      DPAGLog(error, message: "error decrypting data")
    }
    return nil
  }
  
  func getServerMessage(httpUsername: String, httpPassword: String, messageGuid: String, config: DPAGSharedContainerConfig, completion: @escaping (Any?, Error?) -> Void) throws {
    let urlRequest = try self.request(httpUsername: httpUsername, httpPassword: httpPassword, messageGuid: messageGuid, config: config, parameters: [
      "cmd": "getSingleMessage",
      "guid": messageGuid
    ])
    let dataTask = self.httpSessionManager(urlHttpService: config.urlHttpService).uploadTask(with: urlRequest as URLRequest, from: nil, progress: { _ in
    }, completionHandler: { _, responseObject, error in
      completion(responseObject, error)
    })
    dataTask.resume()
  }
  
  private func markMessageDownload(httpUsername: String, httpPassword: String, messageGuid: String, config: DPAGSharedContainerConfig) throws {
    let guids: [String] = [messageGuid]
    if let messageGuids = guids.JSONString {
      let urlRequest = try self.request(httpUsername: httpUsername, httpPassword: httpPassword, messageGuid: messageGuid, config: config, parameters: [
        "cmd": "setMessageState",
        "state": "prefetched",
        "guids": messageGuids
      ])
      let dataTask = self.httpSessionManager(urlHttpService: config.urlHttpService).uploadTask(with: urlRequest as URLRequest, from: nil, progress: { _ in
      }, completionHandler: { _, _, _ in
      })
      dataTask.resume()
    }
  }
  
  private func request(httpUsername: String, httpPassword: String, messageGuid _: String, config: DPAGSharedContainerConfig, parameters: [AnyHashable: Any]) throws -> NSMutableURLRequest {
    let urlString = config.urlHttpService + "/BackgroundService"
    let requestSerializer = self.httpSessionManager(urlHttpService: config.urlHttpService).requestSerializer
    
    do {
      let urlRequest = try requestSerializer.request(withMethod: "POST", urlString: urlString, parameters: parameters)
      urlRequest.setValue("application/x-www-form-urlencoded ; charset=UTF-8", forHTTPHeaderField: "Content-Type")
      if let urlRequestUrl = urlRequest.url {
        let authorizationMessageRef = CFHTTPMessageCreateRequest(kCFAllocatorDefault, urlRequest.httpMethod as CFString, urlRequestUrl as CFURL, kCFHTTPVersion1_1).takeRetainedValue()
        // Encodes usernameRef and passwordRef in Base64
        CFHTTPMessageAddAuthentication(authorizationMessageRef, nil, httpUsername as CFString, httpPassword as CFString, kCFHTTPAuthenticationSchemeBasic, false)
        // Creates the 'Basic - <encoded_username_and_password>' string for the HTTP header
        if let authorizationStringRef = CFHTTPMessageCopyHeaderFieldValue(authorizationMessageRef, "Authorization" as CFString)?.takeRetainedValue() {
          // Add authorizationStringRef as value for 'Authorization' HTTP header
          urlRequest.setValue(authorizationStringRef as String, forHTTPHeaderField: "Authorization")
        }
      }
      let bundle = Bundle.main
      if let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
        urlRequest.addValue(appVersion, forHTTPHeaderField: "X-Client-Version")
      }
      let appName = String(format: "%@", (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? "SIMSme")
      urlRequest.addValue(appName, forHTTPHeaderField: "X-Client-App")
      urlRequest.addValue("gzip", forHTTPHeaderField: "Accept-Encoding")
      urlRequest.addValue("keep-alive", forHTTPHeaderField: "Connection")
      if parameters["cmd"] != nil, let command = parameters["cmd"] as? String {
        urlRequest.addValue(command, forHTTPHeaderField: "X-Client-Command")
      }
      return urlRequest
    } catch {
      throw error
    }
  }
  
  private func getBody(content: DPAGMessageDictionary) -> String {
    let contentType = DPAGMessageContentType.contentType(for: content.contentType)
    var contentText = content.content
    var contentDesc = content.contentDescription
    if content.destructionDate != nil || content.destructionCountDown != nil {
      contentText = "💣"
      contentDesc = "💣"
    }
    var returnValue: String
    switch contentType {
      case .avCallInvitation:
        returnValue = "📞"
      case .plain:
        returnValue = contentText ?? ""
      case .oooStatusMessage:
        returnValue = contentText ?? ""
      case .textRSS:
        returnValue = contentText ?? ""
        if let rssString = content.unknownContent[SIMS_DATA] as? String {
          returnValue = rssString
          if let rssData = rssString.data(using: .utf8), let jsonRSS = try? JSONSerialization.jsonObject(with: rssData), let dictRSS = jsonRSS as? [AnyHashable: Any] {
            if let text = dictRSS["text"] as? String {
              var content = text
              if let title = dictRSS["title"] as? String {
                content = title + "\n" + content
              }
              returnValue = content
            }
          }
        }
      case .image:
        let desc = NSLocalizedString("chat.localPush.messageType.image", comment: "")
        returnValue = "\(desc) \(contentDesc ?? "")"
      case .video:
        let desc = NSLocalizedString("chat.localPush.messageType.video", comment: "")
        returnValue = "\(desc) \(contentDesc ?? "")"
      case .voiceRec:
        let desc = NSLocalizedString("chat.localPush.messageType.voiceRec", comment: "")
        returnValue = "\(desc) \(contentDesc ?? "")"
      case .location:
        let desc = NSLocalizedString("chat.localPush.messageType.location", comment: "")
        returnValue = "\(desc) \(contentDesc ?? "")"
      case .contact:
        let desc = NSLocalizedString("chat.localPush.messageType.contact", comment: "")
        returnValue = "\(desc) \(contentDesc ?? "")"
      case .file:
        let desc = NSLocalizedString("chat.localPush.messageType.file", comment: "")
        returnValue = "\(desc) \(contentDesc ?? "")"
      case .controlMsgNG:
        returnValue = ""
    }
    return returnValue
  }
}
