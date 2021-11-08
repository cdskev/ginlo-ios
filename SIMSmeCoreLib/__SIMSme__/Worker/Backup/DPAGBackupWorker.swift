//
//  DPAGBackupWorker.m
// ginlo
//
//  Created by Yves Hetzer on 02.05.16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CommonCrypto
import CoreData
import objective_zip

public enum DPAGErrorBackup: Error {
  case errCrypto
  case errNoConfig
  case errNoTmpDir
  case errFileInvalid
  case errDataInvalid
  case errPasswordData
  case errNoAccount
  case errFileNotFound
  case errAccountData
  case errJsonEncoding
  case errDatabase
  case errEncoding
  case errServerResponse
  case errServer(errorCode: String, errorMessage: String)
}

public enum DPAGBackupFileState {
  case `default`,
       uploaded,
       uploading,
       downloading
}

public class DPAGBackupFileInfo {
  var name: String?
  public fileprivate(set) var appName: String?
  public fileprivate(set) var mandantIdent: String?
  
  public fileprivate(set) var backupDate: Date?
  
  public fileprivate(set) var filePath: URL?
  
  public fileprivate(set) var fileSize: NSNumber?
  
  var pbdkfSalt: String?
  var version: String?
  var pbdkfRounds: Int = 0
  
  // @property NSString* __nullable PhoneNumber;
  // @property NSString* __nullable EMailAddress;
  var aesKey: Data?
  
  var zipFile: OZZipFile?
  
  public fileprivate(set) var isUploading = false
  public fileprivate(set) var isUploaded = false
  public fileprivate(set) var isDownloading = false
  public private(set) var isDownloaded = false
  public fileprivate(set) var downloadingStatus = ""
  public fileprivate(set) var downloadingError: NSError?
  
  func openFile() throws {
    guard let filePath = self.filePath else { return }
    self.zipFile = try OZZipFile(fileName: filePath.path, mode: .unzip, error: ())
  }
  
  func closeFile() throws {
    try self.zipFile?.closeWithError()
    self.zipFile = nil
  }
  
  func existStream(name: String) throws -> Bool {
    guard let zipFile = self.zipFile else { return false }
    if try zipFile.locateFile(inZip: name, error: ()) != OZLocateFileResultFound {
      return false
    }
    return true
  }
  
  func loadAndDecryptStream(name: String) throws -> [Any]? {
    guard let zipFile = self.zipFile else { return nil }
    if try zipFile.locateFile(inZip: name, error: ()) != OZLocateFileResultFound {
      throw DPAGErrorBackup.errFileNotFound
    }
    var retVal: [Any]?
    try autoreleasepool {
      guard let data = try self.decryptedData() else { return }
      let jsonData = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
      if let jsonArr = jsonData as? [Any] {
        retVal = jsonArr
      } else if let jsonDict = jsonData as? [AnyHashable: Any] {
        retVal = [jsonDict]
      } else {
        throw DPAGErrorBackup.errFileInvalid
      }
    }
    return retVal
  }
  
  func decryptedData() throws -> Data? {
    var retVal: Data?
    try autoreleasepool {
      guard let aesKey = self.aesKey, let data = try self.encryptedData() else { return }
      retVal = try CryptoHelperDecrypter.decryptFromBackup(encryptedData: data, withAesKey: aesKey)
    }
    return retVal
  }
  
  func encryptedData() throws -> Data? {
    guard let zipFile = self.zipFile else { return nil }
    var retVal: Data?
    try autoreleasepool {
      let jsonStream = try zipFile.readCurrentFileInZipWithError()
      let buffer = try DPAGBackupFileInfo.loadZipData(zipStream: jsonStream)
      try jsonStream.finishedReadingWithError()
      retVal = buffer
    }
    return retVal
  }
  
  static func loadZipData(zipStream: OZZipReadStream) throws -> Data {
    var data = Data()
    repeat {
      guard let buffer = NSMutableData(length: 31 * 1_024) else { break }
      let len = try zipStream.readData(withBuffer: buffer, error: ())
      if len <= 0 {
        break
      }
      buffer.length = Int(len)
      data.append(buffer as Data)
    } while true
    return data
  }
  
  func getFileNames() throws -> [String] {
    guard let zipFile = self.zipFile else { return [] }
    var rc: [String] = []
    guard let zipFileInfos = try zipFile.listFileInZipInfosWithError() as? [OZFileInZipInfo] else { return [] }
    for zipFileInfo in zipFileInfos {
      rc.append(zipFileInfo.name)
    }
    return rc
  }
  
  func loadAttachment(fileName: String, attachment dataUrl: URL) throws {
    guard let zipFile = self.zipFile else { return }
    try autoreleasepool {
      let fileNameAttachments = "attachments/" + fileName.replacingOccurrences(of: ":", with: "_")
      if try zipFile.locateFile(inZip: fileNameAttachments, error: ()) == OZLocateFileResultFound {
        let stream = try zipFile.readCurrentFileInZipWithError()
        FileManager.default.createFile(atPath: dataUrl.path, contents: nil, attributes: nil)
        let dest = try FileHandle(forWritingTo: dataUrl)
        repeat {
          guard let buffer = NSMutableData(length: 63 * 1_024) else { break }
          let len = try stream.readData(withBuffer: buffer, error: ())
          if len <= 0 {
            break
          }
          buffer.length = Int(len)
          dest.write(buffer as Data)
        } while true
        try stream.finishedReadingWithError()
        dest.closeFile()
      }
    }
  }
}

private let DUMMY_DATA = "DUMMY-DATA"

public protocol DPAGBackupWorkerProtocol: AnyObject {
  func createMiniBackup(tempDevice: Bool) throws -> String
  func recoverMiniBackup(miniBackup: String, accountGuid: String, deviceGuid: String, deviceName deviceNameEncoded: String, publicKey pubKey: String, publicKeyFingerPrint publicKeySig: String, transId: String) throws
  func loadTimedMessages() throws
  func isICloudEnabled() throws -> Bool
  func listBackups(accountIDs: [String], orPhone phone: String?, queryResults: [Any], checkContent: Bool) throws -> [DPAGBackupFileInfo]
  func ensureBackupToken() throws
  func makeBackup(hudWithLabels: DPAGProgressHUDWithProgressDelegate?) -> Bool
  func loadKeyConfig() -> Bool
  func createKey(pwd: String) throws
  func deleteBackups(accountID: String) throws
  func checkPassword(backupFileInfo: DPAGBackupFileInfo, withPassword password: String) throws
  func recoverBackup(backupFileInfo: DPAGBackupFileInfo, hudWithLabels: DPAGProgressHUDWithProgressDelegate) throws
  func makeAutomaticBackup()
  func loadBlockedContacts() throws -> [String]
}

class DPAGBackupWorker: DPAGBackupWorkerProtocol, DPAGClassPerforming {
  static let sharedInstance = DPAGBackupWorker()
  
  private var exportMedia = true
  private var rounds = 0
  private var salt: Data?
  private var aesKey: Data?
  private var backupPassToken: String?
  private var isExportRunning = false
  private var isLoadingOwnAccount = false
  private var bAppWillResignActive = false
  
  init() {
    NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: DPAGStrings.Notification.Application.WILL_RESIGN_ACTIVE, object: nil)
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  @objc
  private func appWillResignActive() {
    self.bAppWillResignActive = true
  }
  
  /// ist iCloud erlaubt
  func isICloudEnabled() throws -> Bool {
    FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
  }
  
  func createKey(pwd: String) throws {
    self.rounds = 80_000
    let dataSalt = try CryptoHelperEncrypter.getNewSalt()
    guard let salt = Data(base64Encoded: dataSalt, options: .ignoreUnknownCharacters) else {
      throw DPAGErrorBackup.errEncoding
    }
    self.salt = salt
    guard let passwordData = pwd.data(using: .utf8) else {
      throw DPAGErrorBackup.errEncoding
    }
    var derivedKeyData = Data(repeating: UInt8(0), count: 32)
    let derivationStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
      salt.withUnsafeBytes { saltBytes in
        CCKeyDerivationPBKDF(
          CCPBKDFAlgorithm(kCCPBKDF2),
          pwd, passwordData.count,
          saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
          CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
          UInt32(rounds),
          derivedKeyBytes.bindMemory(to: UInt8.self).baseAddress, 32
        )
      }
    }
    if derivationStatus != 0 {
      throw DPAGErrorBackup.errEncoding
    }
    self.aesKey = derivedKeyData
    DPAGApplicationFacade.persistance.saveWithBlock { localContextSave in
      guard let account = SIMSAccount.mr_findFirst(in: localContextSave) else { return }
      account.setAttributeWithKey("pbdkfSalt", andValue: salt.base64EncodedString(options: .lineLength64Characters))
      account.setAttributeWithKey("pbdkfRounds", andValue: String(self.rounds))
      account.setAttributeWithKey("backupKey", andValue: derivedKeyData.base64EncodedString(options: .lineLength64Characters))
    }
  }
  
  func loadKeyConfig() -> Bool {
    var bRC = false
    DPAGApplicationFacade.persistance.loadWithBlock { localContext in
      guard let account = SIMSAccount.mr_findFirst(in: localContext) else { return }
      guard let salt = account.getAttribute("pbdkfSalt") as? String else { return }
      guard let rounds = account.getAttribute("pbdkfRounds") as? String else { return }
      guard let backupKey = account.getAttribute("backupKey") as? String else { return }
      guard let backupPasstoken = account.getAttribute("backupPasstoken") as? String else { return }
      self.salt = Data(base64Encoded: salt, options: .ignoreUnknownCharacters)
      self.rounds = Int(rounds) ?? 0
      self.aesKey = Data(base64Encoded: backupKey, options: .ignoreUnknownCharacters)
      self.backupPassToken = backupPasstoken
      bRC = true
    }
    return bRC
  }
  
  var hasBackupToken: Bool {
    var bRC = false
    DPAGApplicationFacade.persistance.loadWithBlock { localContext in
      guard let account = SIMSAccount.mr_findFirst(in: localContext) else { return }
      let backupPasstoken = account.getAttribute("backupPasstoken") as? String
      if backupPasstoken?.isEmpty ?? true {
        return
      }
      self.backupPassToken = backupPasstoken
      bRC = true
    }
    return bRC
  }
  
  func accountBackup(zipFile: OZZipFile?, writeOutput backupString: inout String?, backupMode mode: DPAGBackupMode) throws {
    var jsonDataBlock: Data?
    try DPAGApplicationFacade.persistance.loadWithError { localContext in
      guard let account = SIMSAccount.mr_findFirst(in: localContext), let accountGuid = account.guid, let contact = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) else { return }
      var innerData: [AnyHashable: Any] = [:]
      innerData["guid"] = accountGuid
      innerData.merge(contact.backupExportAccount(), uniquingKeysWith: { (_, value2) -> Any in
        value2
      })
      innerData["publicKey"] = contact.publicKey
      innerData["accountID"] = contact.accountID
      if mode != .miniBackupTempDevice {
        let accountPrivateKey = account.getAttribute(SIMS_PRIVATE_KEY)
        innerData["privateKey"] = accountPrivateKey
      }
      innerData["mandant"] = DPAGMandant.default.ident
      if mode == .fullBackup {
        innerData["companyInfo"] = account.companyInfo
        innerData["backupPasstoken"] = self.backupPassToken
      } else {
        let companyInfo = account.companyInfo
        var miniDict: [AnyHashable: Any] = [:]
        if let companyPublicKey = companyInfo["publicKey"] {
          miniDict["companyPublicKey"] = companyPublicKey
          if mode != .miniBackupTempDevice {
            if let companyKey = DPAGApplicationFacade.cache.account?.aesKeyCompany {
              miniDict["companyKey"] = companyKey
            }
            if let companyUserDataKey = DPAGApplicationFacade.cache.account?.aesKeyCompanyUserData {
              miniDict["companyUserDataKey"] = companyUserDataKey
            }
          } else {
            if let appConfig = DPAGApplicationFacade.preferences.getRawMdmConfig(), let AppConfig = appConfig["AppConfig"] {
              miniDict["AppConfig"] = AppConfig
            }
          }
          miniDict["state"] = companyInfo["state"]
          miniDict["guid"] = companyInfo["guid"]
          miniDict["name"] = companyInfo["name"]
          innerData["companyInfo"] = miniDict
        }
      }
      if account.isCompanyAccountEmailConfirmed() {
        if let emailDomain = contact.emailDomain {
          innerData["companyDomain"] = emailDomain
        }
        if let emailAdressCompanyEncryption = account.emailAdressCompanyEncryption, emailAdressCompanyEncryption.isEmpty == false {
          innerData["companyEmailAdress"] = emailAdressCompanyEncryption
        }
      }
      if account.isCompanyAccountPhoneNumberConfirmed() {
        if let phoneNumberCompanyEncryption = account.companyEncryptionPhoneNumber, phoneNumberCompanyEncryption.isEmpty == false {
          innerData["companyPhoneNumber"] = phoneNumberCompanyEncryption
        }
      }
      let dataDict = ["AccountBackup": innerData]
      let jsonData = try JSONSerialization.data(withJSONObject: dataDict, options: [])
      if let zipFile = zipFile {
        try self.writeFile(fileName: "account.json", inZipFile: zipFile, andData: jsonData)
      }
      jsonDataBlock = jsonData
    }
    if let jsonData = jsonDataBlock, backupString != nil, let jsonStr = String(data: jsonData, encoding: .utf8) {
      backupString?.append(jsonStr)
    }
  }
  
  func contactBackup(zipFile: OZZipFile?, writeOutput backupString: inout String?, backupMode mode: DPAGBackupMode, deletedCompanyContactsOnly: Bool) throws {
    var jsonDataBlock: Data?
    try DPAGApplicationFacade.persistance.loadWithError { localContext in
      let allContacts = try SIMSContactIndexEntry.findAll(in: localContext)
      var rc: [[AnyHashable: Any]] = []
      var contactsWritten: [String: SIMSContactIndexEntry] = [:]
      for contact in allContacts {
        guard let contactGuid = contact.guid else { continue }
        guard contactsWritten[contactGuid] == nil else { continue }
        contactsWritten[contactGuid] = contact
        if deletedCompanyContactsOnly {
          guard contact.isDeleted, contact.entryTypeServer == .company else { return }
        }
        var innerData: [AnyHashable: Any]?
        switch mode {
          case .miniBackupTempDevice:
            innerData = contact.backupExportMiniBackup()
          case .fullBackup, .miniBackup:
            innerData = contact.backupExportFullBackup()
        }
        if let innerData = innerData {
          if deletedCompanyContactsOnly {
            rc.append(["DeletedCompanyContactBackup": innerData])
          } else {
            rc.append(["ContactBackup": innerData])
          }
        }
      }
      let jsonData = try JSONSerialization.data(withJSONObject: rc, options: [])
      if let zipFile = zipFile {
        try self.writeFile(fileName: "contacts.json", inZipFile: zipFile, andData: jsonData)
      }
      jsonDataBlock = jsonData
    }
    if let jsonData = jsonDataBlock, (backupString?.isEmpty ?? true) == false, let jsonStr = String(data: jsonData, encoding: .utf8) {
      backupString?.append(",")
      backupString?.append(jsonStr)
    }
  }
  
  func channelBackup(zipFile: OZZipFile) throws {
    try DPAGApplicationFacade.persistance.loadWithError { localContext in
      let pred = NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSChannel.feedType), rightExpression: NSExpression(forConstantValue: DPAGChannelType.channel.rawValue))
      let allChannels = try SIMSChannel.findAll(in: localContext, with: pred)
      var rc: [[AnyHashable: Any]] = []
      for channel in allChannels {
        guard let channelGuid = channel.guid, channel.subscribed?.boolValue ?? false else { continue }
        var innerData: [AnyHashable: Any] = [:]
        innerData["guid"] = channel.guid
        let channelOptions = try SIMSChannelOption.findAll(in: localContext, with: NSPredicate(format: "ident BEGINSWITH %@", channelGuid))
        var currentOptions: [String] = []
        for opt in channelOptions {
          if opt.value == "on", let ident = opt.ident {
            currentOptions.append(String(ident[ident.index(channelGuid.endIndex, offsetBy: 3)...]))
          }
        }
        innerData["@ident"] = currentOptions
        if channel.notificationEnabled {
          innerData["notification"] = "enabled"
        } else {
          innerData["notification"] = "disabled"
        }
        if let lastMessageDate = channel.stream?.lastMessageDate {
          innerData["lastModifiedDate"] = DPAGFormatter.date.string(from: lastMessageDate)
        }
        rc.append(["ChannelBackup": innerData])
      }
      let jsonData = try JSONSerialization.data(withJSONObject: rc, options: [])
      try self.writeFile(fileName: "channels.json", inZipFile: zipFile, andData: jsonData)
    }
  }
  
  func convertChannelMessageToBackupJson(message: SIMSChannelMessage, zip zipFile: OZZipFile) throws -> [AnyHashable: Any]? {
    if message.attachment != nil, self.exportMedia == false {
      return nil
    }
    var innerData: [AnyHashable: Any] = [:]
    if let guid = message.guid {
      innerData["guid"] = guid
    }
    if let data = message.data {
      innerData["data"] = data
    }
    try self.convertAttachment(for: message, toDict: &innerData, zipFile: zipFile)
    self.convertSignatures(for: message, toDict: &innerData)
    self.convertDates(for: message, toDict: &innerData)
    self.convertStates(for: message, toDict: &innerData)
    return ["ChannelMessage": innerData]
  }
  
  func singleChatBackup(zipFile: OZZipFile?, writeOutput backupString: inout String?, backupMode mode: DPAGBackupMode, includeDeletedCompanyContactsConversation: Bool) throws {
    var innerBackup: String?
    if (backupString?.isEmpty ?? true) == false {
      backupString?.append(",[")
      innerBackup = String()
    }
    try DPAGApplicationFacade.persistance.loadWithError { localContext in
      let allStreams = try SIMSStream.findAll(in: localContext, relationshipKeyPathsForPrefetching: ["contactIndexEntry", "messages", "messages.attributes"])
      var contactsWritten: [String: SIMSContactIndexEntry] = [:]
      for stream in allStreams {
        guard stream.lastMessageDate != nil else { continue }
        guard let contact = stream.contactIndexEntry, let contactGuid = contact.guid else { continue }
        if includeDeletedCompanyContactsConversation {
          guard contact.entryTypeServer == .company || (stream.wasDeleted?.boolValue ?? false) == false else { continue }
        } else {
          guard (stream.wasDeleted?.boolValue ?? false) == false else { continue }
        }
        guard contactsWritten[contactGuid] == nil else { continue }
        contactsWritten[contactGuid] = contact
        try self.singleChatBackup(messagestream: stream, zip: zipFile, writeOutput: &innerBackup, backupMode: mode, in: localContext)
      }
    }
    if (backupString?.isEmpty ?? true) == false, let innerBackup = innerBackup {
      backupString?.append(innerBackup)
      backupString?.append("]")
    }
  }
  
  func singleChatBackup(messagestream: SIMSStream, zip zipFile: OZZipFile?, writeOutput backupString: inout String?, backupMode mode: DPAGBackupMode, in localContext: NSManagedObjectContext) throws {
    guard let contactGuid = messagestream.contactIndexEntry?.guid else { return }
    var innerData: [AnyHashable: Any] = [:]
    innerData["guid"] = contactGuid
    if let lastMessageDate = messagestream.lastMessageDate {
      innerData["lastModifiedDate"] = DPAGFormatter.date.string(from: lastMessageDate)
    }
    if (messagestream.isConfirmed?.boolValue ?? false) == false {
      innerData["confirmed"] = "false"
    }
    var messageDicts: [[AnyHashable: Any]] = []
    if mode != .miniBackupTempDevice {
      if let messages = messagestream.messages {
        for message in messages {
          if let messagePrivate = message as? SIMSPrivateMessage {
            if let backupData = try self.convertSingleMessageToBackupJson(message: messagePrivate, zip: zipFile, writeOutput: &backupString, backupMode: mode) {
              messageDicts.append(backupData)
            }
          }
        }
      }
      if let messagestreamGuid = messagestream.guid {
        let predicate = NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageToSendPrivate.streamGuid), rightExpression: NSExpression(forConstantValue: messagestreamGuid))
        let timedMessages = try SIMSMessageToSendPrivate.findAll(in: localContext, with: predicate)
        for message in timedMessages {
          if let backupData = try self.convertTimedSingleMessageToBackupJson(message: message, zip: zipFile, writeOutput: &backupString, backupMode: mode) {
            messageDicts.append(backupData)
          }
        }
      }
    }
    var backupObject: Any
    switch mode {
      case .fullBackup:
        var rc: [[AnyHashable: Any]] = []
        rc.append(["SingleChatBackup": innerData])
        rc.append(contentsOf: messageDicts)
        backupObject = rc
      case .miniBackup, .miniBackupTempDevice:
        innerData["messages"] = messageDicts
        backupObject = ["SingleChatBackup": innerData]
    }
    let jsonData = try JSONSerialization.data(withJSONObject: backupObject, options: [])
    let fileName = contactGuid.replacingOccurrences(of: ":", with: "_").appending(".json")
    if let zipFile = zipFile {
      try self.writeFile(fileName: fileName, inZipFile: zipFile, andData: jsonData)
    }
    if backupString != nil, let jsonStr = String(data: jsonData, encoding: .utf8) {
      if (backupString?.isEmpty ?? true) == false {
        backupString?.append(",")
      }
      backupString?.append(jsonStr)
    }
  }
  
  func writeFile(fileName: String, inZipFile zipFile: OZZipFile, andData jsonData: Data) throws {
    try autoreleasepool {
      guard self.bAppWillResignActive == false, let aesKey = self.aesKey else { throw DPAGErrorBackup.errCrypto }
      let jsonDataEncrypted = try CryptoHelperEncrypter.encryptForBackup(data: jsonData, withAesKey: aesKey)
      if AppConfig.buildConfigurationMode == .DEBUG {
        let checkData = try CryptoHelperDecrypter.decryptFromBackup(encryptedData: jsonDataEncrypted, withAesKey: aesKey)
        if jsonData != checkData {
          throw DPAGErrorBackup.errCrypto
        }
      }
      let stream = try zipFile.writeInZip(withName: fileName, compressionLevel: .default, error: ())
      for i in stride(from: 0, to: jsonDataEncrypted.count, by: 31 * 1_024) {
        let next = min(i + (31 * 1_024), jsonDataEncrypted.count)
        try stream.write(jsonDataEncrypted[i ..< next], error: ())
      }
      try stream.finishedWritingWithError()
    }
  }
  
  func saveAttachment(fileUrl: URL, withFileName fileNameIn: String, into zipFile: OZZipFile) throws {
    let fileName = "attachments/" + fileNameIn.replacingOccurrences(of: ":", with: "_")
    try autoreleasepool {
      guard self.bAppWillResignActive == false, let source = FileHandle(forReadingAtPath: fileUrl.path) else { throw DPAGErrorBackup.errCrypto }
      defer {
        source.closeFile()
      }
      let stream = try zipFile.writeInZip(withName: fileName, compressionLevel: .default, error: ())
      repeat {
        let data = source.readData(ofLength: 31 * 1_024)
        if data.count <= 0 {
          break
        }
        try stream.write(data, error: ())
      } while true
      try stream.finishedWritingWithError()
    }
  }
  
  func convertSingleMessageToBackupJson(message: SIMSPrivateMessage, zip zipFile: OZZipFile?, writeOutput _: inout String?, backupMode mode: DPAGBackupMode) throws -> [AnyHashable: Any]? {
    if message.attachment != nil, self.exportMedia == false, mode == .fullBackup {
      return nil
    }
    var innerData: [AnyHashable: Any] = [:]
    if let guid = message.guid {
      innerData["guid"] = guid
    }
    if mode == .fullBackup {
      self.convertKeys(for: message, toDict: &innerData)
      if let data = message.data {
        innerData["data"] = data
      }
      try self.convertAttachment(for: message, toDict: &innerData, zipFile: zipFile)
      self.convertSignatures(for: message, toDict: &innerData)
    }
    self.convertDates(for: message, toDict: &innerData)
    self.convertStates(for: message, toDict: &innerData)
    return ["PrivateMessage": innerData]
  }
  
  func convertTimedSingleMessageToBackupJson(message: SIMSMessageToSendPrivate, zip zipFile: OZZipFile?, writeOutput _: inout String?, backupMode mode: DPAGBackupMode) throws -> [AnyHashable: Any]? {
    if message.attachment != nil, self.exportMedia == false, mode == .fullBackup {
      return nil
    }
    var innerData: [AnyHashable: Any] = [:]
    if let guid = message.guid {
      innerData["guid"] = guid
    }
    if mode == .fullBackup {
      self.convertKeys(for: message, toDict: &innerData)
      if let data = message.data {
        innerData["data"] = data
      }
      try self.convertAttachment(for: message, toDict: &innerData, zipFile: zipFile)
      self.convertSignatures(for: message, toDict: &innerData)
    }
    self.convertDates(for: message, toDict: &innerData)
    self.convertStates(for: message, toDict: &innerData)
    return ["TimedPrivateMessage": innerData]
  }
  
  func groupChatBackup(zipFile: OZZipFile?, writeOutput backupString: inout String?, backupMode mode: DPAGBackupMode) throws {
    var innerBackup: String?
    if (backupString?.isEmpty ?? true) == false {
      backupString?.append(",[")
      innerBackup = String()
    }
    try DPAGApplicationFacade.persistance.loadWithError { localContext in
      let allStreams = try SIMSGroupStream.findAll(in: localContext, relationshipKeyPathsForPrefetching: ["group", "messages", "messages.attributes"])
      for stream in allStreams {
        guard (stream.wasDeleted?.boolValue ?? false) == false else { continue }
        try self.groupChatBackup(messagestream: stream, zip: zipFile, writeOutput: &innerBackup, backupMode: mode, in: localContext)
      }
    }
    if (backupString?.isEmpty ?? true) == false, let innerBackup = innerBackup {
      backupString?.append(innerBackup)
      backupString?.append("]")
    }
  }
  
  func groupChatBackup(messagestream: SIMSGroupStream, zip zipFile: OZZipFile?, writeOutput backupString: inout String?, backupMode mode: DPAGBackupMode, in localContext: NSManagedObjectContext) throws {
    guard let group = messagestream.group, let groupGuid = group.guid else { return }
    var innerData: [AnyHashable: Any] = [:]
    innerData["type"] = group.typeName
    innerData["guid"] = groupGuid
    if let ownerGuid = group.ownerGuid {
      innerData["owner"] = ownerGuid
    }
    innerData["name"] = group.groupName
    if let invitedAt = group.invitedAt {
      innerData["invitedDate"] = DPAGFormatter.date.string(from: invitedAt)
    }
    if let encodedImage = DPAGHelperEx.encodedImage(forGroupGuid: groupGuid) {
      innerData["groupImage"] = encodedImage
    }
    var members: [String] = []
    for member in group.members ?? Set() {
      if let accountGuid = member.accountGuid {
        members.append(accountGuid)
      }
    }
    innerData["member"] = members
    innerData["admins"] = group.adminGuids
    if let decAesKeyXML = group.aesKey {
      let decAesKeyDict = try XMLReader.dictionary(forXMLString: decAesKeyXML)
      innerData["aes_key"] = decAesKeyDict?["key"]
      innerData["iv"] = decAesKeyDict?["iv"]
    }
    if let lastMessageDate = messagestream.lastMessageDate {
      innerData["lastModifiedDate"] = DPAGFormatter.date.string(from: lastMessageDate)
    }
    if (messagestream.isConfirmed?.boolValue ?? false) == false {
      innerData["confirmed"] = "false"
    }
    var messageDicts: [[AnyHashable: Any]] = []
    if mode != .miniBackupTempDevice {
      if let messages = messagestream.messages {
        for message in messages {
          if let messageGroup = message as? SIMSGroupMessage {
            if let backupData = try self.convertGroupMessageToBackupJson(message: messageGroup, zip: zipFile, writeOutput: &backupString, backupMode: mode) {
              messageDicts.append(backupData)
            }
          }
        }
      }
      if let messagestreamGuid = messagestream.guid {
        let predicate = NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageToSendGroup.streamGuid), rightExpression: NSExpression(forConstantValue: messagestreamGuid))
        let timedMessages = try SIMSMessageToSendGroup.findAll(in: localContext, with: predicate)
        for message in timedMessages {
          if let backupData = try self.convertTimedGroupMessageToBackupJson(message: message, zip: zipFile, writeOutput: &backupString, backupMode: mode) {
            messageDicts.append(backupData)
          }
        }
      }
    }
    var backupObject: Any
    switch mode {
      case .fullBackup:
        var rc: [[AnyHashable: Any]] = []
        rc.append(["ChatRoomBackup": innerData])
        rc.append(contentsOf: messageDicts)
        backupObject = rc
      case .miniBackup, .miniBackupTempDevice:
        innerData["messages"] = messageDicts
        if (messagestream.isConfirmed?.boolValue ?? false) == false {
          innerData["confirmed"] = "unconfirmed"
        } else {
          innerData["confirmed"] = "unblocked"
        }
        innerData["members"] = members
        backupObject = ["ChatRoomBackup": innerData]
    }
    let jsonData = try JSONSerialization.data(withJSONObject: backupObject, options: [])
    let fileName = groupGuid.replacingOccurrences(of: ":", with: "_").appending(".json")
    if let zipFile = zipFile {
      try self.writeFile(fileName: fileName, inZipFile: zipFile, andData: jsonData)
    }
    if backupString != nil, let jsonStr = String(data: jsonData, encoding: .utf8) {
      if (backupString?.isEmpty ?? true) == false {
        backupString?.append(",")
      }
      backupString?.append(jsonStr)
    }
  }
  
  func convertGroupMessageToBackupJson(message: SIMSGroupMessage, zip zipFile: OZZipFile?, writeOutput _: inout String?, backupMode mode: DPAGBackupMode) throws -> [AnyHashable: Any]? {
    guard let guid = message.guid else { return nil }
    if message.attachment != nil && self.exportMedia == false && mode == .fullBackup {
      return nil
    }
    var innerData: [AnyHashable: Any] = [:]
    innerData["guid"] = guid
    if mode == .fullBackup || guid.hasPrefix(.messageInternalPrioOne) {
      self.convertKeys(for: message, toDict: &innerData)
      if let data = message.data {
        innerData["data"] = data
      }
      try self.convertAttachment(for: message, toDict: &innerData, zipFile: zipFile)
      self.convertSignatures(for: message, toDict: &innerData)
    }
    if (message.receiver?.count ?? 0) > 0 {
      var arrayReceiver: [[AnyHashable: Any]] = []
      for receiver in message.receiver ?? Set() {
        var dictReceiver: [AnyHashable: Any] = [:]
        dictReceiver["guid"] = receiver.contactIndexEntry?.guid ?? "-"
        dictReceiver["sendsReadConfirmation"] = (receiver.sendsReadConfirmation?.boolValue ?? false) ? "true" : "false"
        if let dateRead = receiver.dateRead {
          dictReceiver["dateRead"] = DPAGFormatter.date.string(from: dateRead)
        }
        if let dateDownloaded = receiver.dateDownloaded {
          dictReceiver["dateDownloaded"] = DPAGFormatter.date.string(from: dateDownloaded)
        }
        arrayReceiver.append(["Receiver": dictReceiver])
      }
      innerData["receiver"] = arrayReceiver
    }
    self.convertDates(for: message, toDict: &innerData)
    self.convertStates(for: message, toDict: &innerData)
    return ["GroupMessage": innerData]
  }
  
  func convertTimedGroupMessageToBackupJson(message: SIMSMessageToSendGroup, zip zipFile: OZZipFile?, writeOutput _: inout String?, backupMode mode: DPAGBackupMode) throws -> [AnyHashable: Any]? {
    if message.attachment != nil, self.exportMedia == false, mode == .fullBackup {
      return nil
    }
    var innerData: [AnyHashable: Any] = [:]
    if let guid = message.guid {
      innerData["guid"] = guid
    }
    if mode == .fullBackup {
      self.convertKeys(for: message, toDict: &innerData)
      if let data = message.data {
        innerData["data"] = data
      }
      try self.convertAttachment(for: message, toDict: &innerData, zipFile: zipFile)
      self.convertSignatures(for: message, toDict: &innerData)
    }
    self.convertDates(for: message, toDict: &innerData)
    self.convertStates(for: message, toDict: &innerData)
    return ["TimedGroupMessage": innerData]
  }
  
  func accountBackupInfo(zipFile: OZZipFile) throws {
    guard let salt = self.salt else { throw DPAGErrorBackup.errNoConfig }
    var innerData: [AnyHashable: Any] = [:]
    innerData["version"] = "2"
    innerData["app"] = Bundle.main.infoDictionary?[kCFBundleExecutableKey as String] as? String ?? (Bundle.main.infoDictionary?[kCFBundleIdentifierKey as String] as? String ?? "SIMSme")
    innerData["appName"] = DPAGMandant.default.name
    innerData["salt"] = DPAGApplicationFacade.preferences.saltClient
    innerData["date"] = DPAGFormatter.date.string(from: Date())
    innerData["pbdkfRounds"] = NSNumber(value: self.rounds)
    innerData["pbdkfSalt"] = salt.base64EncodedString(options: .lineLength64Characters)
    innerData["mandant"] = DPAGMandant.default.ident
    innerData["mandantLabel"] = DPAGMandant.default.label
    let dataDict = ["BackupInfo": innerData]
    let jsonData = try JSONSerialization.data(withJSONObject: dataDict, options: [])
    let stream = try zipFile.writeInZip(withName: "info.json", compressionLevel: .default, error: ())
    try stream.write(jsonData, error: ())
    try stream.finishedWritingWithError()
  }
  
  func createBackupPasstoken() throws {
    guard let accountGuid = DPAGApplicationFacade.cache.account?.guid else { return }
    var errorCodeBlock: String?
    var errorMessageBlock: String?
    let semaphore = DispatchSemaphore(value: 0)
    let responseBlock: DPAGServiceResponseBlock = { responseObject, errorCode, errorMessage in
      defer {
        semaphore.signal()
      }
      if let errorMessage = errorMessage {
        // TODO: Fehlermeldung anzeigen
        DPAGLog(errorMessage)
        errorMessageBlock = errorMessage
        errorCodeBlock = errorCode
      } else if let backupPassToken = (responseObject as? [String])?.first {
        self.backupPassToken = backupPassToken
        DPAGApplicationFacade.persistance.saveWithBlock { localContextSave in
          let account = SIMSAccount.mr_findFirst(in: localContextSave)
          account?.setAttributeWithKey("backupPasstoken", andValue: backupPassToken)
        }
      }
    }
    DPAGApplicationFacade.server.createBackupPasstoken(accountGuid: accountGuid, withResponse: responseBlock)
    _ = semaphore.wait(timeout: .distantFuture)
    if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
      throw DPAGErrorBackup.errServer(errorCode: errorCode, errorMessage: errorMessage)
    }
  }
  
  func ensureBackupToken() throws {
    if self.hasBackupToken == false {
      try self.createBackupPasstoken()
    }
  }
  
  func makeAutomaticBackup() {
    guard let lastBackup = DPAGApplicationFacade.preferences.backupLastDate else { return }
    guard DPAGApplicationFacade.preferences.isBackupDisabled == false else { return }
    let nextScheduledBackup: Date
    switch DPAGApplicationFacade.preferences.backupInterval ?? .disabled {
      case .disabled:
        return
      case .daily:
        if AppConfig.buildConfigurationMode == .DEBUG {
          nextScheduledBackup = lastBackup.addingMinutes(5)
        } else {
          nextScheduledBackup = lastBackup.addingDays(1)
        }
      case .weekly:
        if AppConfig.buildConfigurationMode == .DEBUG {
          nextScheduledBackup = lastBackup.addingMinutes(30)
        } else {
          nextScheduledBackup = lastBackup.addingDays(7)
        }
      case .monthly:
        if AppConfig.buildConfigurationMode == .DEBUG {
          nextScheduledBackup = lastBackup.addingMinutes(60)
        } else {
          nextScheduledBackup = lastBackup.addingDays(30)
        }
    }
    if nextScheduledBackup.isInPast {
      _ = self.makeBackup(hudWithLabels: nil)
    }
  }
  
  func isSavedICloud(fileUrl: URL) -> Bool {
    do {
      let resVals = try fileUrl.resourceValues(forKeys: [.ubiquitousItemIsUploadedKey])
      return resVals.ubiquitousItemIsUploaded ?? false
    } catch {
      return false
    }
  }
  
  func makeBackup(hudWithLabels: DPAGProgressHUDWithProgressDelegate?) -> Bool {
    guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let accountID = contact.accountID else { return true }
    var shouldStartBackup = true
    if self.isExportRunning {
      shouldStartBackup = false
    }
    if shouldStartBackup == false {
      return true
    }
    defer {
      self.isExportRunning = false
    }
    do {
      self.isExportRunning = true
      self.bAppWillResignActive = false
      try self.ensureBackupToken()
      self.exportMedia = DPAGApplicationFacade.preferences.backupSaveMedia()
      let maxStep = 9
      var step = 0
      self.setProgressState(step: step, maxSteps: maxStep, andText: DPAGLocalizedString("backup.backup.prepare"), hudWithLabels: hudWithLabels)
      step += 1
      try self.ensureBackupToken()
      if self.loadKeyConfig() == false {
        throw DPAGErrorBackup.errNoConfig
      }
      let fileManager = FileManager.default
      guard let directoryPath = DPAGFunctionsGlobal.pathForCustomTMPDirectory() else { throw DPAGErrorBackup.errNoTmpDir }
      let exportPath = directoryPath.appendingPathComponent("backup.zip")
      if fileManager.fileExists(atPath: exportPath.path) {
        try? fileManager.removeItem(at: exportPath)
      }
      let zipFile = try OZZipFile(fileName: exportPath.path, mode: .create, error: ())
      self.setProgressState(step: step, maxSteps: maxStep, andText: DPAGLocalizedString("backup.backup.account"), hudWithLabels: hudWithLabels)
      step += 1
      var nilOutput: String?
      try self.accountBackup(zipFile: zipFile, writeOutput: &nilOutput, backupMode: .fullBackup)
      self.setProgressState(step: step, maxSteps: maxStep, andText: DPAGLocalizedString("backup.backup.contacts"), hudWithLabels: hudWithLabels)
      step += 1
      try self.contactBackup(zipFile: zipFile, writeOutput: &nilOutput, backupMode: .fullBackup, deletedCompanyContactsOnly: DPAGApplicationFacade.preferences.isBaMandant)
      if DPAGApplicationFacade.preferences.isChannelsAllowed {
        self.setProgressState(step: step, maxSteps: maxStep, andText: DPAGLocalizedString("backup.backup.channel"), hudWithLabels: hudWithLabels)
        step += 1
        try self.channelBackup(zipFile: zipFile)
      }
      self.setProgressState(step: step, maxSteps: maxStep, andText: DPAGLocalizedString("backup.backup.chats"), hudWithLabels: hudWithLabels)
      step += 1
      try self.singleChatBackup(zipFile: zipFile, writeOutput: &nilOutput, backupMode: .fullBackup, includeDeletedCompanyContactsConversation: DPAGApplicationFacade.preferences.isBaMandant)
      self.setProgressState(step: step, maxSteps: maxStep, andText: DPAGLocalizedString("backup.backup.groups"), hudWithLabels: hudWithLabels)
      step += 1
      try self.groupChatBackup(zipFile: zipFile, writeOutput: &nilOutput, backupMode: .fullBackup)
      self.setProgressState(step: step, maxSteps: maxStep, andText: DPAGLocalizedString("backup.backup.info"), hudWithLabels: hudWithLabels)
      step += 1
      try self.accountBackupInfo(zipFile: zipFile)
      try zipFile.closeWithError()
      if let ubiquityContainer = fileManager.url(forUbiquityContainerIdentifier: nil) {
        self.setProgressState(step: step, maxSteps: maxStep, andText: DPAGLocalizedString("backup.backup.icloud"), hudWithLabels: hudWithLabels)
        step += 1
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyyMMdd"
        var fileName = String(format: "backup-%@.simsbck", dateFormatter.string(from: Date()))
        let backupName = String(format: "SIMSme-%@", accountID)
        let backupPath = ubiquityContainer.appendingPathComponent(backupName, isDirectory: true)
        var backupFile = backupPath.appendingPathComponent(fileName)
        var idx = 1
        while fileManager.fileExists(atPath: backupFile.path) {
          fileName = String(format: "backup-%@-%05d.simsbck", dateFormatter.string(from: Date()), idx)
          idx += 1
          backupFile = backupPath.appendingPathComponent(fileName)
        }
        try fileManager.createDirectory(at: backupPath, withIntermediateDirectories: true, attributes: nil)
        let fileAttributes = try fileManager.attributesOfItem(atPath: exportPath.path)
        let fileSize = fileAttributes[.size] as? NSNumber
        try fileManager.setUbiquitous(true, itemAt: exportPath, destinationURL: backupFile)
        self.setProgressState(step: step, maxSteps: maxStep, andText: DPAGLocalizedString("backup.backup.check"), hudWithLabels: hudWithLabels)
        step += 1
        let fileInfo = DPAGBackupFileInfo()
        fileInfo.filePath = backupFile
        repeat {
          defer {
            try? fileInfo.closeFile()
          }
          try fileInfo.openFile()
          fileInfo.aesKey = self.aesKey
          let files = try fileInfo.getFileNames()
          for fileName in files {
            guard fileName.hasSuffix(".json") else { continue }
            guard fileName.hasPrefix("info") == false else { continue }
            _ = try fileInfo.loadAndDecryptStream(name: fileName)
          }
          _ = try fileInfo.loadAndDecryptStream(name: "account.json")
          break
        } while true
        self.deleteOldBackups(backupPath: backupPath, skipFile: backupFile)
        if let phoneNumber = contact.phoneNumber {
          let backupNameOld = String(format: "SIMSme-%@", phoneNumber.md5())
          let backupPathOld = ubiquityContainer.appendingPathComponent(backupNameOld, isDirectory: true)
          try? fileManager.removeItem(at: backupPathOld)
        }
        let now = Date()
        DPAGApplicationFacade.preferences.backupLastDate = now
        DPAGApplicationFacade.preferences.backupLastFileSize = fileSize
        DPAGApplicationFacade.preferences.backupLastFile = backupFile.path
        self.performBlockInBackground { [weak self] in
          Thread.sleep(forTimeInterval: 60)
          self?.deleteOldBackups(backupPath: backupPath, skipFile: backupFile)
        }
        return true
      }
    } catch {
      DPAGLog(error)
    }
    return false
  }
  
  func deleteOldBackups(backupPath: URL, skipFile backupFile: URL) {
    do {
      let fileManager = FileManager.default
      let tmpDirectory = try fileManager.contentsOfDirectory(at: backupPath, includingPropertiesForKeys: nil, options: []).sorted { (obj1, obj2) -> Bool in
        var fileName1 = obj1.lastPathComponent
        var fileName2 = obj2.lastPathComponent
        if fileName1.count < fileName2.count {
          fileName1 = obj1.deletingPathExtension().lastPathComponent.appending("-00000.simsbck")
        }
        if fileName2.count < fileName1.count {
          fileName2 = obj2.deletingPathExtension().lastPathComponent.appending("-00000.simsbck")
        }
        return fileName1 > fileName2
      }
      var hasValidBackup = false
      for i in 0 ..< tmpDirectory.count {
        let fileUrl = tmpDirectory[i]
        if self.isSavedICloud(fileUrl: fileUrl) {
          if hasValidBackup {
            if fileUrl == backupFile {
              DPAGLog("Skipping File %@", fileUrl.path)
            } else {
              DPAGLog("Deleting File %@", fileUrl.path)
              try? fileManager.removeItem(at: fileUrl)
            }
          } else {
            hasValidBackup = true
          }
        } else {
          if fileUrl == backupFile {
            DPAGLog("Skipping File %@", fileUrl.path)
          } else {
            DPAGLog("Deleting File %@", fileUrl.path)
            try? fileManager.removeItem(at: fileUrl)
          }
        }
      }
    } catch {
      DPAGLog(error)
    }
  }
  
  // MARK: - recovery
  
  func setProgressState(step: Int, maxSteps max: Int, andText text: String, hudWithLabels: DPAGProgressHUDWithProgressDelegate?) {
    guard let hudWithLabels = hudWithLabels else { return }
    let f = CGFloat(step) / CGFloat(max)
    self.performBlockOnMainThread {
      hudWithLabels.setProgress(f, withText: text)
    }
  }
  
  func recoverBackup(backupFileInfo: DPAGBackupFileInfo, hudWithLabels: DPAGProgressHUDWithProgressDelegate) throws {
    try backupFileInfo.openFile()
    defer {
      try? backupFileInfo.closeFile()
    }
    let maxStep = 7
    var step = 0
    self.setProgressState(step: step, maxSteps: maxStep, andText: DPAGLocalizedString("backup.recover.account"), hudWithLabels: hudWithLabels)
    step += 1
    try self.recoverAccount(backupFileInfo: backupFileInfo)
    self.setProgressState(step: step, maxSteps: maxStep, andText: DPAGLocalizedString("backup.recover.contacts"), hudWithLabels: hudWithLabels)
    step += 1
    try DPAGApplicationFacade.couplingWorker.loadPrivateIndexFromServer(ifModifiedSince: nil, forceLoad: true)
    try self.recoverContacts(backupFileInfo: backupFileInfo, fromMinibackup: nil, backupMode: .fullBackup)
    self.setProgressState(step: step, maxSteps: maxStep, andText: DPAGLocalizedString("backup.recover.chats"), hudWithLabels: hudWithLabels)
    step += 1
    try self.recoverSingleChatStream(backupFileInfo: backupFileInfo)
    self.setProgressState(step: step, maxSteps: maxStep, andText: DPAGLocalizedString("backup.recover.groups"), hudWithLabels: hudWithLabels)
    step += 1
    try self.recoverGroupChatStream(backupFileInfo: backupFileInfo)
    self.setProgressState(step: step, maxSteps: maxStep, andText: DPAGLocalizedString("backup.recover.timed"), hudWithLabels: hudWithLabels)
    step += 1
    try self.loadTimedMessages()
    if DPAGApplicationFacade.preferences.isChannelsAllowed {
      self.setProgressState(step: step, maxSteps: maxStep, andText: DPAGLocalizedString("backup.recover.channel"), hudWithLabels: hudWithLabels)
      step += 1
      try self.loadChannels()
      try self.recoverChannels(backupFileInfo: backupFileInfo)
    }
    self.setProgressState(step: step, maxSteps: maxStep, andText: DPAGLocalizedString("backup.recover.profil"), hudWithLabels: hudWithLabels)
    step += 1
    try self.recoverAccountInfo()
    DPAGApplicationFacade.companyAdressbook.syncAdressInformations()
    DPAGApplicationFacade.preferences.didAskForCompanyEmail = true
    DPAGApplicationFacade.preferences.didAskForCompanyPhoneNumber = true
    DPAGApplicationFacade.preferences.didAskForPushPreview = true
    DPAGApplicationFacade.server.setBackgroundPushNotification(enable: true) { _, _, errorMessage in
      if errorMessage == nil {
        DPAGApplicationFacade.preferences.backgroundAccessTokenSyncEnabled = true
        DPAGApplicationFacade.server.setPreviewPushNotification(enable: true) { _, _, errorMessage in
          if errorMessage == nil {
            DPAGApplicationFacade.preferences.previewPushNotification = true
          }
        }
      }
    }
    try DPAGApplicationFacade.devicesWorker.createShareExtensionDevice(withResponse: nil)
    if backupFileInfo.version == "1", DPAGApplicationFacade.preferences.isBaMandant == false {
      self.setProgressState(step: step, maxSteps: maxStep, andText: DPAGLocalizedString("backup.recover.contacts"), hudWithLabels: hudWithLabels)
      step += 1
      DPAGApplicationFacade.updateKnownContactsWorker.updateWithAddressbook()
    }
    DPAGApplicationFacade.preferences.apnIdentifier = ""
    DPAGApplicationFacade.preferences.isInAppNotificationEnabled = true
  }
  
  func checkPassword(backupFileInfo: DPAGBackupFileInfo, withPassword password: String) throws {
    guard let filePath = backupFileInfo.filePath, let pbdkfSalt = backupFileInfo.pbdkfSalt, let salt = Data(base64Encoded: pbdkfSalt, options: .ignoreUnknownCharacters) else { throw DPAGErrorBackup.errNoConfig }
    guard let passwordData = password.data(using: .utf8) else { throw DPAGErrorBackup.errPasswordData }
    var derivedKeyData = Data(repeating: UInt8(0), count: 32)
    let derivationStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
      salt.withUnsafeBytes { saltBytes in
        CCKeyDerivationPBKDF(
          CCPBKDFAlgorithm(kCCPBKDF2),
          password, passwordData.count,
          saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
          CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
          UInt32(backupFileInfo.pbdkfRounds),
          derivedKeyBytes.bindMemory(to: UInt8.self).baseAddress, 32
        )
      }
    }
    if derivationStatus != 0 {
      throw DPAGErrorBackup.errPasswordData
    }
    let aesKey = derivedKeyData
    let zipFile = try OZZipFile(fileName: filePath.path, mode: .unzip, error: ())
    defer {
      try? zipFile.closeWithError()
    }
    if try zipFile.locateFile(inZip: "account.json", error: ()) != OZLocateFileResultFound {
      throw DPAGErrorBackup.errFileInvalid
    }
    let accountJsonStream = try zipFile.readCurrentFileInZipWithError()
    let buffer = try DPAGBackupFileInfo.loadZipData(zipStream: accountJsonStream)
    try accountJsonStream.finishedReadingWithError()
    let decryptedData = try CryptoHelperDecrypter.decryptFromBackup(encryptedData: buffer, withAesKey: aesKey)
    guard let accountJson = try JSONSerialization.jsonObject(with: decryptedData, options: .allowFragments) as? [AnyHashable: Any], let accountInnerJson = accountJson["AccountBackup"] as? [AnyHashable: Any] else { throw DPAGErrorBackup.errFileInvalid }
    //        Because of ginloNow, we can't have this any more:
    //
    //        let phoneNumber = accountInnerJson["phone"] as? String
    //        let eMailAddress = accountInnerJson["email"] as? String
    //        if phoneNumber == nil, eMailAddress == nil {
    //            throw DPAGErrorBackup.errFileInvalid
    //        }
    backupFileInfo.aesKey = aesKey
  }
  
  func deleteBackups(accountID: String) throws {
    let array = try self.listBackups(accountIDs: [accountID], orPhone: nil, onlyOwnContainer: true)
    for fileInfo in array {
      if let filePath = fileInfo.filePath {
        try? FileManager.default.removeItem(at: filePath)
      }
    }
  }
  
  func listBackups(accountIDs: [String], orPhone phone: String?, queryResults: [Any], checkContent: Bool) throws -> [DPAGBackupFileInfo] {
    var validFolderNames: [String] = []
    if let phone = phone {
      let backupName = String(format: "SIMSme-%@", phone.md5())
      validFolderNames.append(backupName)
    }
    for accountID in accountIDs {
      let backupName = String(format: "SIMSme-%@", accountID)
      validFolderNames.append(backupName)
    }
    var results: [DPAGBackupFileInfo] = []
    for result in queryResults where result is NSMetadataItem {
      if let aResult = result as? NSMetadataItem {
        guard let itemURL = aResult.value(forAttribute: NSMetadataItemURLKey) as? URL, let itemFSSize = aResult.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber, let itemDisplayName = aResult.value(forAttribute: NSMetadataItemDisplayNameKey) as? String, let itemIsUploaded = aResult.value(forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? Bool, let itemIsUploading = aResult.value(forAttribute: NSMetadataUbiquitousItemIsUploadingKey) as? Bool, let itemIsDownloading = aResult.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? Bool, let itemDownloadingStatus = aResult.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String else {
          continue
        }
        let pathPart = itemURL.deletingLastPathComponent().lastPathComponent
        let namePart = itemURL.lastPathComponent
        guard validFolderNames.contains(where: { (folderName) -> Bool in
          pathPart.hasPrefix(folderName)
        }) else {
          continue
        }
        guard namePart.hasPrefix("backup-"), namePart.hasSuffix(".simsbck") else { continue }
        var item: DPAGBackupFileInfo?
        if checkContent {
          item = self.loadBackupFileInfo(fileURL: itemURL, name: itemDisplayName, fileSize: itemFSSize)
        } else {
          let fileInfo = DPAGBackupFileInfo()
          fileInfo.filePath = itemURL
          fileInfo.fileSize = itemFSSize
          item = fileInfo
        }
        if let item = item {
          item.isUploading = itemIsUploading
          item.isUploaded = itemIsUploaded
          item.isDownloading = itemIsDownloading
          item.downloadingStatus = itemDownloadingStatus
          item.downloadingError = aResult.value(forAttribute: NSMetadataUbiquitousItemDownloadingErrorKey) as? NSError
          results.append(item)
        }
      }
    }
    return results
  }
  
  private func loadBackupFileInfo(fileURL: URL, name: String, fileSize: NSNumber?) -> DPAGBackupFileInfo? {
    do {
      let zipFile = try OZZipFile(fileName: fileURL.path, mode: .unzip, error: ())
      defer {
        try? zipFile.closeWithError()
      }
      if try zipFile.locateFile(inZip: "info.json", error: ()) != OZLocateFileResultFound {
        return nil
      }
      let infoJson = try zipFile.readCurrentFileInZipWithError()
      let buffer = try DPAGBackupFileInfo.loadZipData(zipStream: infoJson)
      let jsonData = try JSONSerialization.jsonObject(with: buffer, options: .allowFragments)
      try infoJson.finishedReadingWithError()
      if let jsonDict = (jsonData as? [AnyHashable: Any])?["BackupInfo"] as? [AnyHashable: Any] {
        guard let version = jsonDict["version"] as? String, version == "1" || version == "2" else { return nil }
        let app = jsonDict["app"] as? String
        let appName = jsonDict["appName"] as? String
        let mandant = jsonDict["mandant"] as? String
        let mandantLabel = jsonDict["mandantLabel"] as? String
        let date = jsonDict["date"] as? String
        let pbdkfRounds = jsonDict["pbdkfRounds"] as? NSNumber
        let pbdkfSalt = jsonDict["pbdkfSalt"] as? String
        let fileInfo = DPAGBackupFileInfo()
        fileInfo.appName = app
        if let mandantLabel = mandantLabel {
          fileInfo.appName = mandantLabel
        }
        if let appName = appName {
          fileInfo.appName = appName
        }
        fileInfo.name = name
        fileInfo.mandantIdent = mandant
        if let date = date {
          fileInfo.backupDate = DPAGFormatter.date.date(from: date)
        }
        fileInfo.filePath = fileURL
        fileInfo.pbdkfSalt = pbdkfSalt
        fileInfo.version = version
        fileInfo.pbdkfRounds = pbdkfRounds?.intValue ?? 0
        if let fileSize = fileSize {
          fileInfo.fileSize = fileSize
        } else {
          let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
          let fileSize = fileAttributes[.size] as? NSNumber
          fileInfo.fileSize = fileSize
        }
        return fileInfo
      }
    } catch {
      DPAGLog(error, message: "Error reading Zip-File")
    }
    return nil
  }
  
  func listBackups(accountIDs: [String], orPhone phone: String?, onlyOwnContainer onlyOwn: Bool) throws -> [DPAGBackupFileInfo] {
    var rc: [DPAGBackupFileInfo] = []
    let fileManager = FileManager.default
    var validContainer: [String] = []
    validContainer.append("")
    if onlyOwn == false, DPAGApplicationFacade.preferences.isBaMandant {
      validContainer.append(AppConfig.iCloudContainerTest)
      validContainer.append(AppConfig.iCloudContainerRelease)
    }
    for identifier in validContainer {
      guard let ubiquityContainer = fileManager.url(forUbiquityContainerIdentifier: identifier.isEmpty ? nil : identifier) else { continue }
      try fileManager.startDownloadingUbiquitousItem(at: ubiquityContainer)
      let tmpDirectory = try fileManager.contentsOfDirectory(at: ubiquityContainer, includingPropertiesForKeys: nil, options: [])
      var validFileNames: [String] = []
      if let phone = phone {
        let backupName = String(format: "SIMSme-%@", phone.md5())
        validFileNames.append(backupName)
      }
      for accountID in accountIDs {
        let backupName = String(format: "SIMSme-%@", accountID)
        validFileNames.append(backupName)
      }
      for existingDirectory in tmpDirectory {
        let path = existingDirectory.lastPathComponent
        guard path.hasPrefix("SIMSme-") else { continue }
        if validFileNames.contains(where: { (pathPart) -> Bool in
          path.hasPrefix(pathPart)
        }) == false {
          continue
        }
        let tmpFiles = try fileManager.contentsOfDirectory(at: existingDirectory, includingPropertiesForKeys: nil, options: [])
        for existingFile in tmpFiles {
          let fileName = existingFile.lastPathComponent
          guard fileName.hasPrefix("backup-") else { continue }
          guard fileName.hasSuffix(".simsbck") else { continue }
          if let item = self.loadBackupFileInfo(fileURL: existingFile, name: fileName, fileSize: nil) {
            rc.append(item)
          }
        }
      }
    }
    return rc
  }
  
  func recoverAccount(backupFileInfo: DPAGBackupFileInfo) throws {
    let arr = try backupFileInfo.loadAndDecryptStream(name: "account.json")
    guard let accountInfo = arr?.first as? [AnyHashable: Any], let innerAccountInfo = accountInfo["AccountBackup"] as? [AnyHashable: Any] else { return }
    try DPAGApplicationFacade.persistance.saveWithError { localContext in
      SIMSContactIndexEntry.mr_truncateAll(in: localContext)
      guard let account = SIMSAccount.mr_findFirst(in: localContext), let contact = SIMSContactIndexEntry.mr_createEntity(in: localContext), let device = SIMSDevice.mr_findFirst(in: localContext), let simsKey = SIMSKey.mr_findFirst(in: localContext) else { throw DPAGErrorBackup.errNoAccount }
      guard let accountGuid = innerAccountInfo["guid"] as? String else { throw DPAGErrorBackup.errAccountData }
      let deviceGuid = DPAGFunctionsGlobal.uuid(prefix: .device)
      let keyGuid = DPAGFunctionsGlobal.uuid(prefix: .key)
      account.guid = accountGuid
      contact.keyRelationship = SIMSKey.mr_findFirst(in: localContext)
      contact.guid = accountGuid
      contact.backupImportAccount(innerAccountInfo: innerAccountInfo)
      guard let privateKey = innerAccountInfo["privateKey"] as? String, let contactPublicKey = contact.publicKey, let backupPasstoken = innerAccountInfo["backupPasstoken"] as? String else { throw DPAGErrorBackup.errAccountData }
      account.backupPasstoken = backupPasstoken
      account.accountState = .recoverBackup
      account.privateKey = privateKey
      if let companyInfo = innerAccountInfo["companyInfo"] as? [AnyHashable: Any] {
        account.companyInfo = companyInfo
        if companyInfo["guid"] != nil {
          DPAGApplicationFacade.preferences.isCompanyManagedState = true
        }
        if let emailAdressCompanyEncryption = innerAccountInfo["companyEmailAdress"] as? String, emailAdressCompanyEncryption.isEmpty == false { // Backup vor 2.1.5
          if let seed = account.companySeed, let salt = account.companySalt {
            account.setCompanySeed(seed, salt: salt, phoneNumber: innerAccountInfo["phone"] as? String, email: emailAdressCompanyEncryption, diff: nil)
          }
        }
      }
      device.guid = deviceGuid
      let passtoken = DPAGFunctionsGlobal.uuid()
      device.passToken = passtoken
      device.account_guid = account.guid
      let accountCrypto = try CryptoHelperSimple(publicKey: contactPublicKey, privateKey: privateKey)
      if let publicKeyFingerprintDevice = device.public_key?.sha1() {
        let signData = try accountCrypto.signData(data: publicKeyFingerprintDevice)
        device.signedPublicRSAFingerprint = signData
      }
      simsKey.guid = keyGuid
      simsKey.device_guid = deviceGuid
      let keyDict = [
        DPAGStrings.JSON.Key.OBJECT_KEY: [
          DPAGStrings.JSON.Key.GUID: keyGuid,
          DPAGStrings.JSON.Key.ACCOUNT_GUID: accountGuid,
          DPAGStrings.JSON.Key.DEVICE_GUID: deviceGuid,
          DPAGStrings.JSON.Key.DATA: ""
        ]
      ]
      let deviceDict = try device.deviceDictionary(type: "permanent")
      let createdevice = [deviceDict, keyDict]
      let jsonData = try JSONSerialization.data(withJSONObject: createdevice, options: [])
      DPAGApplicationFacade.model.recoveryAccountguid = String(accountGuid[accountGuid.index(accountGuid.startIndex, offsetBy: 2)...])
      DPAGApplicationFacade.model.recoveryPasstoken = backupPasstoken
      guard let recoverData = String(data: jsonData, encoding: .utf8) else { throw DPAGErrorBackup.errJsonEncoding }
      try self.createDevice(accountGuid: accountGuid, phoneNumber: contact.phoneNumber, withData: recoverData)
      DPAGApplicationFacade.model.update(with: localContext)
    }
    DPAGCryptoHelper.resetAccountCrypto()
    DPAGApplicationFacade.cache.clearCache()
  }
  
  func recoverAccountInfo() throws {
    try self.recoverAccountInfoInternal(recoverProfile: true, andEmail: true, andAutoGenerateMessages: true)
  }
  
  func recoverAccountInfoInternal(recoverProfile: Bool, andEmail emailDomain: Bool, andAutoGenerateMessages autoGenerateMessages: Bool) throws {
    try DPAGApplicationFacade.persistance.saveWithError { localContext in
      guard let account = SIMSAccount.mr_findFirst(in: localContext), let accountGuid = account.guid, let contact = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) else { throw DPAGErrorBackup.errNoAccount }
      if recoverProfile {
        contact.loadImageAndInfo()
      }
      if emailDomain {
        self.loadOwnAdressInformation(account: account, in: localContext)
        account.accountState = .confirmed
        if contact.emailDomain != nil {
          self.loadOwnAdressInformation(account: account, in: localContext)
        }
      }
      if autoGenerateMessages {
        if let autoGeneratedMessages = try self.loadAutoGeneratedMessages() {
          if let confirmReadMessages = autoGeneratedMessages["confirmRead"] as? String {
            DPAGApplicationFacade.preferences.markMessagesAsReadEnabled = (confirmReadMessages == "1")
          }
        }
      }
    }
  }
  
  func loadOwnAdressInformation(account: SIMSAccount, in localContext: NSManagedObjectContext) {
    guard let accountGuid = account.guid else { return }
    let serverAdressesResponse = DPAGApplicationFacade.companyAdressbook.loadAdressInformationBatch(guids: [accountGuid], type: .email)
    guard let serverAdresses = serverAdressesResponse.responseArray else { return }
    guard let emailDomain = DPAGApplicationFacade.cache.contact(for: accountGuid)?.eMailDomain, let aesKey = try? account.aesKey(emailDomain: emailDomain) else { return }
    for serverAdress in serverAdresses {
      guard let kvPre = serverAdress as? [AnyHashable: Any], let kv = kvPre["AdressInformation"] as? [AnyHashable: Any] else { continue }
      guard kv["guid"] as? String != nil, let keyIv = kv["key-iv"] as? String, let data = kv["data"] as? String, kv["publicKey"] as? String != nil else { continue }
      guard let jsonData = try? CryptoHelperDecrypter.decrypt(encryptedData: data, withAesKey: aesKey, andIv: keyIv) else { continue }
      if let contact = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) {
        if contact.update(withJsonData: jsonData) {
          account.companyEMailAddressStatus = .confirmed
        }
      }
    }
  }
  
  func loadAutoGeneratedMessages() throws -> [AnyHashable: Any]? {
    var retVal: [AnyHashable: Any]?
    var errorCodeBlock: String?
    var errorMessageBlock: String?
    let semaphore = DispatchSemaphore(value: 0)
    let responseBlock: DPAGServiceResponseBlock = { responseObject, errorCode, errorMessage in
      defer {
        semaphore.signal()
      }
      if let errorMessage = errorMessage {
        DPAGLog(errorMessage)
        if errorMessage != "service.ERR-0007" {
          errorMessageBlock = errorMessage
          errorCodeBlock = errorCode
        }
      } else if let rc = responseObject as? [AnyHashable: Any] {
        retVal = rc
      }
    }
    DPAGApplicationFacade.server.getAutoGeneratedMessages(withResponse: responseBlock)
    _ = semaphore.wait(timeout: .distantFuture)
    if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
      throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
    }
    return retVal
  }
  
  func loadBlockedContacts() throws -> [String] {
    var retVal: [String] = []
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
      } else if let rc = responseObject as? [String] {
        retVal = rc
      }
    }
    DPAGApplicationFacade.server.getBlocked(withResponse: responseBlock)
    _ = semaphore.wait(timeout: .distantFuture)
    if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
      throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
    }
    return retVal
  }
  
  func recoverContacts(backupFileInfo: DPAGBackupFileInfo?, fromMinibackup backupData: [[AnyHashable: Any]]?, backupMode mode: DPAGBackupMode) throws {
    var contacts: [[AnyHashable: Any]]?
    if mode == .fullBackup, let backupFileInfo = backupFileInfo {
      guard try backupFileInfo.existStream(name: "contacts.json") else { return }
      contacts = try backupFileInfo.loadAndDecryptStream(name: "contacts.json") as? [[AnyHashable: Any]]
    } else {
      contacts = backupData
    }
    guard let contactsToRecover = contacts else { return }
    let blockedAccounts = try self.loadBlockedContacts()
    DPAGApplicationFacade.persistance.saveWithBlock { localContext in
      for contactBackup in contactsToRecover {
        guard let innerContact = (contactBackup["ContactBackup"] ?? contactBackup["DeletedCompanyContactBackup"]) as? [AnyHashable: Any] else { continue }
        guard let guid = innerContact["guid"] as? String ?? innerContact["accountGuid"] as? String else { continue }
        guard let contact = SIMSContactIndexEntry.findFirst(byGuid: guid, in: localContext) ?? SIMSContactIndexEntry.mr_createEntity(in: localContext) else { continue }
        contact.keyRelationship = SIMSKey.mr_findFirst(in: localContext)
        contact.guid = guid
        contact.backupImport(innerContact: innerContact, blockedAccounts: blockedAccounts, in: localContext)
      }
    }
  }
  
  func recoverPrivateMessage(singleMessage: [AnyHashable: Any], backupFileInfo: DPAGBackupFileInfo?, accountInfo account: SIMSAccount, contactInfo contact: SIMSContactIndexEntry, orderId nextOrderId: UInt64, backupMode mode: DPAGBackupMode, in localContext: NSManagedObjectContext) throws {
    guard let guid = singleMessage["guid"] as? String else { return }
    guard let privateMessage = (SIMSMessage.findFirst(byGuid: guid, in: localContext) ?? SIMSPrivateMessage.mr_createEntity(in: localContext)) as? SIMSPrivateMessage else { return }
    privateMessage.guid = guid
    self.recoverDates(fromDict: singleMessage, forMessage: privateMessage, in: localContext)
    if mode == .fullBackup {
      self.recoverKeys(fromDict: singleMessage, forPrivateMessage: privateMessage)
      if let backupFileInfo = backupFileInfo {
        try self.recoverAttachment(fromDict: singleMessage, forMessage: privateMessage, accountInfo: account, backupFileInfo: backupFileInfo)
      }
      let data = singleMessage["data"] as? String
      privateMessage.data = data
    } else {
      privateMessage.fromKey = DUMMY_DATA
      privateMessage.toKey = DUMMY_DATA
      privateMessage.toAccountGuid = DUMMY_DATA
      privateMessage.fromAccountGuid = DUMMY_DATA
    }
    self.recoverStates(fromDict: singleMessage, forMessage: privateMessage)
    privateMessage.typeMessage = .private
    privateMessage.messageOrderId = NSNumber(value: nextOrderId)
    privateMessage.stream = contact.stream
    if privateMessage.attributes?.dateReadLocal == nil, privateMessage.fromAccountGuid != account.guid, let stream = privateMessage.stream {
      stream.optionsStream = stream.optionsStream.union(privateMessage.optionsMessage.contains(.priorityHigh) ? [.hasUnreadMessages, .hasUnreadHighPriorityMessages] : [.hasUnreadMessages])
    }
    if let isSystemMessageStr = singleMessage["isSystemMessage"] as? String {
      if (isSystemMessageStr as NSString).boolValue {
        privateMessage.fromAccountGuid = DPAGConstantsGlobal.kSystemChatAccountGuid
      }
    }
    if account.guid == privateMessage.fromAccountGuid {
      if guid.hasPrefix(.messageChat) {
        privateMessage.sendingState = NSNumber(value: DPAGMessageState.sentSucceeded.rawValue)
      }
    }
  }
  
  func recoverTimedPrivateMessage(singleMessage: [AnyHashable: Any], backupFileInfo: DPAGBackupFileInfo?, accountInfo account: SIMSAccount, contactInfo contact: SIMSContactIndexEntry, orderId _: UInt64, backupMode mode: DPAGBackupMode, in localContext: NSManagedObjectContext) throws {
    guard let guid = singleMessage["guid"] as? String, let streamGuid = contact.stream?.guid else { return }
    guard let privateMessage = SIMSMessageToSendPrivate.findFirst(byGuid: guid, in: localContext) ?? SIMSMessageToSendPrivate.mr_createEntity(in: localContext) else { return }
    privateMessage.guid = guid
    self.recoverDates(fromDict: singleMessage, forTimedMessage: privateMessage)
    if mode == .fullBackup {
      self.recoverKeys(fromDict: singleMessage, forPrivateMessage: privateMessage)
      if let backupFileInfo = backupFileInfo {
        try self.recoverAttachment(fromDict: singleMessage, forMessage: privateMessage, accountInfo: account, backupFileInfo: backupFileInfo)
      }
      let data = singleMessage["data"] as? String
      privateMessage.data = data
    } else {
      privateMessage.fromKey = DUMMY_DATA
      privateMessage.toKey = DUMMY_DATA
      privateMessage.toAccountGuid = DUMMY_DATA
    }
    self.recoverStates(fromDict: singleMessage, forTimedMessage: privateMessage)
    privateMessage.typeMessage = .private
    privateMessage.streamGuid = streamGuid
  }
  
  func recoverTimedPrivateMessageFromServer(timedMessage: [AnyHashable: Any], in localContext: NSManagedObjectContext) throws {
    guard let guid = timedMessage["guid"] as? String, let messageDataStr = timedMessage["data"] as? String else { return }
    guard let privateMessage = SIMSMessageToSendPrivate.findFirst(byGuid: guid, in: localContext) ?? SIMSMessageToSendPrivate.mr_createEntity(in: localContext) else { throw DPAGErrorBackup.errDatabase }
    guard let messageData = messageDataStr.data(using: .utf8) else { throw DPAGErrorBackup.errEncoding }
    guard let jsonData = try JSONSerialization.jsonObject(with: messageData, options: .allowFragments) as? [AnyHashable: Any] else { throw DPAGErrorBackup.errJsonEncoding }
    guard let singleMessage = jsonData["PrivateMessage"] as? [AnyHashable: Any] else { throw DPAGErrorBackup.errFileInvalid }
    privateMessage.guid = guid
    guard let fromDict = singleMessage["from"] as? [AnyHashable: Any], let fromAccountGuid = fromDict.keys.first as? String, let fromKey = (fromDict[fromAccountGuid] as? [AnyHashable: Any])?["key"] as? String else { throw DPAGErrorBackup.errFileInvalid }
    guard let toDict = (singleMessage["to"] as? [[AnyHashable: Any]])?.first, let toAccountGuid = toDict.keys.first as? String, let toKey = (toDict[toAccountGuid] as? [AnyHashable: Any])?["key"] as? String else { throw DPAGErrorBackup.errFileInvalid }
    let data = singleMessage["data"] as? String
    if let attachment = singleMessage["attachment"] as? [String], let attachmentStr = attachment.first {
      let attachmentGuid = DPAGFunctionsGlobal.uuid()
      DPAGAttachmentWorker.saveEncryptedAttachment(attachmentStr, forGuid: attachmentGuid)
      privateMessage.attachment = attachmentGuid
    }
    let sendDate = timedMessage["sendDate"] as? String
    let createdDate = timedMessage["dateCreated"] as? String
    if let sendDate = sendDate, let dateToSend = DPAGFormatter.dateServer.date(from: sendDate) {
      privateMessage.dateToSend = dateToSend
    }
    if let createdDate = createdDate, let dateCreated = DPAGFormatter.dateServer.date(from: createdDate) {
      privateMessage.dateCreated = dateCreated
    } else {
      privateMessage.dateCreated = Date()
    }
    privateMessage.data = data
    privateMessage.fromKey = fromKey
    privateMessage.toAccountGuid = toAccountGuid
    privateMessage.toKey = toKey
    self.saveRecoveredSignatures(fromDict: singleMessage, forMessage: privateMessage)
    if let sendingFailed = singleMessage["sendingFailed"] as? String, sendingFailed == "true" {
      privateMessage.sendingState = NSNumber(value: DPAGMessageState.sentFailed.rawValue)
    }
    privateMessage.typeMessage = .private
    if let contact = SIMSContactIndexEntry.findFirst(byGuid: toAccountGuid, in: localContext), let streamGuid = contact.stream?.guid {
      privateMessage.streamGuid = streamGuid
      if let stream = privateMessage.streamToSend(in: localContext) {
        stream.lastMessageDate = privateMessage.dateCreated
        DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: privateMessage.streamGuid, stream: stream, in: localContext)
      }
    }
  }
  
  func recoverSingleChatStreamInternal(backupFileInfo: DPAGBackupFileInfo?, stream: [[AnyHashable: Any]], backupMode mode: DPAGBackupMode) throws {
    try DPAGApplicationFacade.persistance.saveWithError { localContext in
      var contactStream: SIMSContactIndexEntry?
      guard let account = SIMSAccount.mr_findFirst(in: localContext) else { return }
      var orderId: UInt64 = 1
      for jsonDict in stream {
        if contactStream == nil, let singleChatBackupInfo = jsonDict["SingleChatBackup"] as? [AnyHashable: Any] {
          guard var guid = singleChatBackupInfo["guid"] as? String else { throw DPAGErrorBackup.errDataInvalid }
          if guid.hasPrefix(.streamGroup) {
            if let members = singleChatBackupInfo["members"] as? [String] {
              for memberGuid in members where memberGuid != account.guid {
                guid = memberGuid
              }
            }
          }
          guard let contact = SIMSContactIndexEntry.findFirst(byGuid: guid, in: localContext) ?? DPAGApplicationFacade.contactFactory.newModel(accountGuid: guid, publicKey: nil, in: localContext) else { throw DPAGErrorBackup.errDatabase }
          contactStream = contact
          contact.backupImportChat(singleChatBackupInfo: singleChatBackupInfo)
          DPAGLog("Will try to recover single chat \(guid)")
          if let messages = singleChatBackupInfo["messages"] as? [[AnyHashable: Any]] {
//            DPAGLog("•••• Will try to recover messages single chat; 'messages' = \(messages)")
            for message in messages {
              if let singleMessage = message["PrivateMessage"] as? [AnyHashable: Any] {
                do {
                  try self.recoverPrivateMessage(singleMessage: singleMessage, backupFileInfo: backupFileInfo, accountInfo: account, contactInfo: contact, orderId: orderId, backupMode: mode, in: localContext)
                } catch {
                  DPAGLog("•••• •••• Could not recover message = \(singleMessage)")
                }
                orderId += 1
              }
              if let timedSingleMessage = message["TimedPrivateMessage"] as? [AnyHashable: Any] {
                do {
                  try self.recoverTimedPrivateMessage(singleMessage: timedSingleMessage, backupFileInfo: backupFileInfo, accountInfo: account, contactInfo: contact, orderId: orderId, backupMode: mode, in: localContext)
                } catch {
                  DPAGLog("•••• •••• Could not recover timed message = \(timedSingleMessage)")
                }
                orderId += 1
              }
            }
          }
          continue
        }
        guard let contact = contactStream else { break                }
        if let singleMessage = jsonDict["PrivateMessage"] as? [AnyHashable: Any] {
          do {
            try self.recoverPrivateMessage(singleMessage: singleMessage, backupFileInfo: backupFileInfo, accountInfo: account, contactInfo: contact, orderId: orderId, backupMode: mode, in: localContext)
          } catch {
            DPAGLog("•••• •••• Could not recover message = \(singleMessage)")
          }
          orderId += 1
        }
        if let timedSingleMessage = jsonDict["TimedPrivateMessage"] as? [AnyHashable: Any] {
          do {
            try self.recoverTimedPrivateMessage(singleMessage: timedSingleMessage, backupFileInfo: backupFileInfo, accountInfo: account, contactInfo: contact, orderId: orderId, backupMode: mode, in: localContext)
          } catch {
            DPAGLog("•••• •••• Could not recover timed message = \(timedSingleMessage)")
          }
          orderId += 1
        }
      }
    }
  }
  
  func recoverSingleChatStream(backupFileInfo: DPAGBackupFileInfo) throws {
    let allFileNames = try backupFileInfo.getFileNames()
    for filename in allFileNames where filename.hasPrefix("0_") {
      try autoreleasepool {
        if let stream = try backupFileInfo.loadAndDecryptStream(name: filename) as? [[AnyHashable: Any]] {
          try self.recoverSingleChatStreamInternal(backupFileInfo: backupFileInfo, stream: stream, backupMode: .fullBackup)
        }
      }
    }
  }
  
  func recoverGroupChatStreamInternal(backupFileInfo: DPAGBackupFileInfo?, existingServerGroups: [String: [AnyHashable: Any]], stream: [[AnyHashable: Any]], backupMode mode: DPAGBackupMode) throws -> [String: [AnyHashable: Any]] {
    var removableGroupGuids: [String] = []
    try DPAGApplicationFacade.persistance.saveWithError { localContext in
      guard let account = SIMSAccount.mr_findFirst(in: localContext), let accountGuid = account.guid else { throw DPAGErrorBackup.errDatabase }
      var groupRecovered: SIMSGroup?
      var orderId: UInt64 = 1
      for jsonDict in stream {
        if groupRecovered == nil {
          guard let groupChatBackupInfo = jsonDict["ChatRoomBackup"] as? [AnyHashable: Any] else { continue }
          guard let guid = groupChatBackupInfo["guid"] as? String else { continue}
          guard let aesKey = groupChatBackupInfo["aes_key"] as? String, let iv = groupChatBackupInfo["iv"] as? String else { continue }
          guard let stream = (SIMSMessageStream.findFirst(byGuid: guid, in: localContext) ?? SIMSGroupStream.mr_createEntity(in: localContext)) as? SIMSGroupStream else { continue }
          guard let group = SIMSGroup.findFirst(byGuid: guid, in: localContext) ?? SIMSGroup.mr_createEntity(in: localContext) else { continue }
          DPAGLog("Will try to recover group \(group.guid)")
          groupRecovered = group
          let lastMessageDate = groupChatBackupInfo["lastModifiedDate"] as? String
          let owner = groupChatBackupInfo["owner"] as? String
          let name = groupChatBackupInfo["name"] as? String
          let invitedDate = groupChatBackupInfo["invitedDate"] as? String
          let serverChatRoomInfo = existingServerGroups[guid]
          stream.isConfirmed = true
          if groupChatBackupInfo["confirmed"] as? String == "false" {
            stream.isConfirmed = NSNumber(value: false)
          }
          stream.guid = guid
          stream.typeStream = .group
          stream.optionsStream = []
          group.guid = guid
          stream.group = group
          if let type = groupChatBackupInfo["type"] as? String {
            group.typeName = type
          }
          let keyAttr = ["key": aesKey, "iv": iv]
          let decAesKey = XMLWriter.xmlString(from: keyAttr)
          group.aesKey = decAesKey
          group.groupName = name
          group.ownerGuid = owner
          if let invitedDate = invitedDate {
            group.invitedAt = DPAGFormatter.date.date(from: invitedDate)
          } else {
            group.invitedAt = Date()
          }
          if let groupImage = groupChatBackupInfo["groupImage"] as? String {
            DPAGHelperEx.saveBase64Image(encodedImage: groupImage, forGroupGuid: guid)
          }
          if let lastMessageDate = lastMessageDate {
            stream.lastMessageDate = DPAGFormatter.date.date(from: lastMessageDate)
          } else {
            stream.lastMessageDate = Date()
          }
          let key = SIMSKey.mr_findFirst(in: localContext)
          group.keyRelationship = key
          var members = groupChatBackupInfo["member"] as? [String]
          var admins = groupChatBackupInfo["admins"] as? [String]
          if let serverChatRoomInfo = serverChatRoomInfo {
            members = serverChatRoomInfo["member"] as? [String]
            admins = serverChatRoomInfo["admins"] as? [String]
          }
          if let members = members {
            group.updateMembers(memberGuids: members, ownGuid: accountGuid, in: localContext)
          }
          if let admins = admins {
            group.updateAdmins(adminGuids: admins)
          }
          if serverChatRoomInfo == nil {
            stream.wasDeleted = true
          } else {
            removableGroupGuids.append(guid)
          }
          group.updateStatus(in: localContext)
          DPAGLog("Will try to recover single chat \(group.guid)")
          if let messages = groupChatBackupInfo["messages"] as? [[AnyHashable: Any]] {
//            DPAGLog("•••• Will try to recover messages of Group; 'messages' = \(messages)")
            for message in messages {
              if let groupMessageDict = message["GroupMessage"] as? [AnyHashable: Any] {
                do {
                  try self.recoverGroupMessage(groupMessageDict: groupMessageDict, backupFileInfo: backupFileInfo, accountInfo: account, contactInfo: group, orderId: orderId, backupMode: mode, in: localContext)
                } catch {
                  DPAGLog("•••• •••• Could not recover group message = \(groupMessageDict)")
                }
                orderId += 1
              }
              if let timedGroupMessageDict = message["TimedGroupMessage"] as? [AnyHashable: Any] {
                do {
                  try self.recoverTimedGroupMessage(groupMessageDict: timedGroupMessageDict, backupFileInfo: backupFileInfo, accountInfo: account, contactInfo: group, orderId: orderId, backupMode: mode, in: localContext)
                } catch {
                  DPAGLog("•••• •••• Could not recover (timed) group message = \(timedGroupMessageDict)")
                }
                orderId += 1
              }
            }
          }
          continue
        }
        guard let group = groupRecovered else { break }
        if let groupMessageDict = jsonDict["GroupMessage"] as? [AnyHashable: Any] {
          do {
            try self.recoverGroupMessage(groupMessageDict: groupMessageDict, backupFileInfo: backupFileInfo, accountInfo: account, contactInfo: group, orderId: orderId, backupMode: mode, in: localContext)
          } catch {
            DPAGLog("•••• •••• Could not recover group message = \(groupMessageDict)")
          }
          orderId += 1
        }
        if let timedGroupMessageDict = jsonDict["TimedGroupMessage"] as? [AnyHashable: Any] {
          do {
            try self.recoverTimedGroupMessage(groupMessageDict: timedGroupMessageDict, backupFileInfo: backupFileInfo, accountInfo: account, contactInfo: group, orderId: orderId, backupMode: mode, in: localContext)
          } catch {
            DPAGLog("•••• •••• Could not recover (timed) group message = \(timedGroupMessageDict)")
          }
          orderId += 1
        }
      }
    }
    return existingServerGroups.filter({ (key, _) -> Bool in
      removableGroupGuids.contains(key) == false
    })
  }
  
  func recoverGroupChatStream(backupFileInfo: DPAGBackupFileInfo) throws {
    let currentRoomInfos = try self.loadCurrentRoomInfos()
    var mutableDict: [String: [AnyHashable: Any]] = [:]
    for chatRoom in currentRoomInfos {
      if let chatroomDict = chatRoom["ChatRoom"] as? [AnyHashable: Any] ??
          chatRoom["ManagedRoom"] as? [AnyHashable: Any] ??
          chatRoom["AnnouncementRoom"] as? [AnyHashable: Any] ??
          chatRoom["RestrictedRoom"] as? [AnyHashable: Any] {
        if let chatRoomGuid = chatroomDict["guid"] as? String {
          mutableDict[chatRoomGuid] = chatroomDict
        }
      }
    }
    let allFileNames = try backupFileInfo.getFileNames()
    for filename in allFileNames where filename.hasPrefix("7_") {
      if let stream = try backupFileInfo.loadAndDecryptStream(name: filename) as? [[AnyHashable: Any]] {
        mutableDict = try self.recoverGroupChatStreamInternal(backupFileInfo: backupFileInfo, existingServerGroups: mutableDict, stream: stream, backupMode: .fullBackup)
      }
    }
    if mutableDict.isEmpty == false {
      try DPAGApplicationFacade.persistance.loadWithError { localContext in
        let allKeys = mutableDict.keys
        for roomGuid in allKeys {
          try self.leaveGroup(groupGuid: roomGuid, in: localContext)
        }
      }
    }
  }
  
  func recoverGroupMessage(groupMessageDict: [AnyHashable: Any], backupFileInfo: DPAGBackupFileInfo?, accountInfo account: SIMSAccount, contactInfo group: SIMSGroup, orderId nextOrderId: UInt64, backupMode mode: DPAGBackupMode, in localContext: NSManagedObjectContext) throws {
    guard let groupGuid = group.guid, let guid = groupMessageDict["guid"] as? String else { throw DPAGErrorBackup.errDataInvalid }
    guard let groupMessage = (SIMSMessage.findFirst(byGuid: guid, in: localContext) ?? SIMSGroupMessage.mr_createEntity(in: localContext)) as? SIMSGroupMessage else { throw DPAGErrorBackup.errDatabase }
    groupMessage.guid = guid
    if let receiver = groupMessageDict["receiver"] as? [[AnyHashable: Any]], receiver.isEmpty == false {
      for receiverDictObj in receiver {
        guard let dictReceiver = receiverDictObj["Receiver"] as? [AnyHashable: Any] else { continue }
        guard let receiverGuid = dictReceiver["guid"] as? String else { continue }
        if groupMessage.receiver?.filter({ $0.contact?.guid == receiverGuid }).isEmpty ?? true {
          guard let contact = SIMSContactIndexEntry.findFirst(byGuid: receiverGuid, in: localContext) else { continue }
          guard let messageReceiver = SIMSMessageReceiver.mr_createEntity(in: localContext) else { continue }
          let sendsReadConfirmation = dictReceiver["sendsReadConfirmation"] as? String
          let dateRead = dictReceiver["dateRead"] as? String
          let dateDownloaded = dictReceiver["dateDownloaded"] as? String
          messageReceiver.contactIndexEntry = contact
          messageReceiver.sendsReadConfirmation = NSNumber(value: sendsReadConfirmation == "true")
          messageReceiver.message = groupMessage
          if let dateRead = dateRead {
            messageReceiver.dateRead = DPAGFormatter.date.date(from: dateRead)
          }
          if let dateDownloaded = dateDownloaded {
            messageReceiver.dateDownloaded = DPAGFormatter.date.date(from: dateDownloaded)
          }
        }
      }
    }
    self.recoverDates(fromDict: groupMessageDict, forMessage: groupMessage, in: localContext)
    if mode == .fullBackup || guid.hasPrefix(.messageInternalPrioOne) {
      self.recoverKeys(fromDict: groupMessageDict, forGroupMessage: groupMessage)
      if let backupFileInfo = backupFileInfo {
        try self.recoverAttachment(fromDict: groupMessageDict, forMessage: groupMessage, accountInfo: account, backupFileInfo: backupFileInfo)
      }
      let data = groupMessageDict["data"] as? String
      groupMessage.data = data
    } else {
      groupMessage.toGroupGuid = groupGuid
      groupMessage.fromAccountGuid = DUMMY_DATA
    }
    self.recoverStates(fromDict: groupMessageDict, forMessage: groupMessage)
    groupMessage.typeMessage = .group
    groupMessage.messageOrderId = NSNumber(value: nextOrderId)
    groupMessage.stream = group.stream
    if groupMessage.attributes?.dateReadLocal == nil, groupMessage.fromAccountGuid != account.guid, let stream = groupMessage.stream {
      stream.optionsStream = stream.optionsStream.union(groupMessage.optionsMessage.contains(.priorityHigh) ? [.hasUnreadMessages, .hasUnreadHighPriorityMessages] : [.hasUnreadMessages])
    }
    if let isSystemMessageStr = groupMessageDict["isSystemMessage"] as? String {
      if (isSystemMessageStr as NSString).boolValue {
        groupMessage.fromAccountGuid = DPAGConstantsGlobal.kSystemChatAccountGuid
      }
    }
    if account.guid == groupMessage.fromAccountGuid {
      if guid.hasPrefix(.messageGroup) {
        groupMessage.sendingState = NSNumber(value: DPAGMessageState.sentSucceeded.rawValue)
      }
    }
  }
  
  func recoverTimedGroupMessage(groupMessageDict: [AnyHashable: Any], backupFileInfo: DPAGBackupFileInfo?, accountInfo account: SIMSAccount, contactInfo group: SIMSGroup, orderId _: UInt64, backupMode mode: DPAGBackupMode, in localContext: NSManagedObjectContext) throws {
    guard let guid = groupMessageDict["guid"] as? String, let streamGuid = group.stream?.guid, let groupGuid = group.guid else { return }
    guard let groupMessage = SIMSMessageToSendGroup.findFirst(byGuid: guid, in: localContext) ?? SIMSMessageToSendGroup.mr_createEntity(in: localContext) else { return }
    groupMessage.guid = guid
    self.recoverDates(fromDict: groupMessageDict, forTimedMessage: groupMessage)
    if mode == .fullBackup {
      self.recoverKeys(fromDict: groupMessageDict, forPrivateMessage: groupMessage)
      if let backupFileInfo = backupFileInfo {
        try self.recoverAttachment(fromDict: groupMessageDict, forMessage: groupMessage, accountInfo: account, backupFileInfo: backupFileInfo)
      }
      let data = groupMessageDict["data"] as? String
      groupMessage.data = data
    }
    self.recoverStates(fromDict: groupMessageDict, forTimedMessage: groupMessage)
    groupMessage.typeMessage = .group
    groupMessage.streamGuid = streamGuid
    groupMessage.toGroupGuid = groupGuid
  }
  
  func recoverTimedGroupMessageFromServer(timedMessage groupMessageDict: [AnyHashable: Any], in localContext: NSManagedObjectContext) throws {
    guard let guid = groupMessageDict["guid"] as? String else { return }
    guard let to = groupMessageDict["to"] as? String, let messageDataStr = groupMessageDict["data"] as? String, let messageData = messageDataStr.data(using: .utf8) else { return }
    guard let group = SIMSGroup.findFirst(byGuid: to, in: localContext), let streamGuid = group.stream?.guid else { return }
    guard let groupMessage = SIMSMessageToSendGroup.findFirst(byGuid: guid, in: localContext) ?? SIMSMessageToSendGroup.mr_createEntity(in: localContext) else { return }
    groupMessage.guid = guid
    let sendDate = groupMessageDict["sendDate"] as? String
    guard let jsonData = try JSONSerialization.jsonObject(with: messageData, options: .allowFragments) as? [AnyHashable: Any], let groupMessageDict = jsonData["GroupMessage"] as? [AnyHashable: Any] else { return }
    let data = groupMessageDict["data"] as? String
    if let attachment = groupMessageDict["attachment"] as? [String], let attachmentContent = attachment.first {
      let attachmentGuid = DPAGFunctionsGlobal.uuid()
      DPAGAttachmentWorker.saveEncryptedAttachment(attachmentContent, forGuid: attachmentGuid)
      groupMessage.attachment = attachmentGuid
    }
    if let sendDate = sendDate, let dateToSend = DPAGFormatter.dateServer.date(from: sendDate) {
      groupMessage.dateToSend = dateToSend
    }
    groupMessage.dateCreated = Date()
    groupMessage.data = data
    groupMessage.toGroupGuid = to
    self.saveRecoveredSignatures(fromDict: groupMessageDict, forMessage: groupMessage)
    if let sendingFailed = groupMessageDict["sendingFailed"] as? String, sendingFailed == "true" {
      groupMessage.sendingState = NSNumber(value: DPAGMessageState.sentFailed.rawValue)
    }
    groupMessage.typeMessage = .group
    groupMessage.streamGuid = streamGuid
  }
  
  func recoverKeys(fromDict dict: [AnyHashable: Any], forPrivateMessage message: SIMSManagedObjectMessage) {
    guard let fromDict = dict["from"] as? [AnyHashable: Any] else { return }
    guard let fromAccountGuid = fromDict.keys.first as? String else { return }
    guard let fromKey = (fromDict[fromAccountGuid] as? [AnyHashable: Any])?["key"] as? String else { return }
    let fromKey2 = (fromDict[fromAccountGuid] as? [AnyHashable: Any])?["key2"] as? String
    guard let toDict = (dict["to"] as? [[AnyHashable: Any]])?.first else { return }
    guard let toAccountGuid = toDict.keys.first as? String else { return }
    guard let toKey = (toDict[toAccountGuid] as? [AnyHashable: Any])?["key"] as? String else { return }
    let toKey2 = (toDict[toAccountGuid] as? [AnyHashable: Any])?["key2"] as? String
    let aesKey2IV = dict["key2-iv"] as? String
    if let privateMessage = message as? SIMSPrivateMessage {
      privateMessage.fromAccountGuid = fromAccountGuid
      privateMessage.fromKey = fromKey
      privateMessage.fromKey2 = fromKey2
      privateMessage.toAccountGuid = toAccountGuid
      privateMessage.toKey = toKey
      privateMessage.toKey2 = toKey2
      privateMessage.aesKey2IV = aesKey2IV
    } else if let privateMessage = message as? SIMSMessageToSendPrivate {
      privateMessage.fromKey = fromKey
      privateMessage.fromKey2 = fromKey2
      privateMessage.toAccountGuid = toAccountGuid
      privateMessage.toKey = toKey
      privateMessage.toKey2 = toKey2
      
      privateMessage.aesKey2IV = aesKey2IV
    }
  }
  
  func recoverKeys(fromDict dict: [AnyHashable: Any], forGroupMessage message: SIMSManagedObjectMessage) {
    guard let fromDict = dict["from"] as? [AnyHashable: Any], let fromAccountGuid = fromDict.keys.first as? String, let to = dict["to"] as? String else { return }
    if let groupMessage = message as? SIMSGroupMessage {
      groupMessage.fromAccountGuid = fromAccountGuid
      groupMessage.toGroupGuid = to
    } else if let groupMessage = message as? SIMSMessageToSendGroup {
      groupMessage.toGroupGuid = to
    }
  }

    func recoverAttachment(fromDict dict: [AnyHashable: Any], forMessage message: SIMSManagedObjectMessage, accountInfo account: SIMSAccount, backupFileInfo: DPAGBackupFileInfo) throws {
      guard let attachment = dict["attachment"] as? [String], attachment.isEmpty == false else { return }
      guard let attachmentGuid = attachment.first else { return }
      guard let dataUrl = AttachmentHelper.attachmentFilePath(guid: attachmentGuid) else { return }
      let fileManager = FileManager.default
      if fileManager.fileExists(atPath: dataUrl.path) {
        try fileManager.removeItem(at: dataUrl)
      }
      message.attachment = attachmentGuid
      try backupFileInfo.loadAttachment(fileName: attachmentGuid, attachment: dataUrl)
      self.recoverSignature(fromDict: dict, forMessage: message, accountInfo: account)
    }

    func recoverDates(fromDict dict: [AnyHashable: Any], forMessage message: SIMSMessage, in localContext: NSManagedObjectContext) {
      if message.attributes == nil {
        message.attributes = SIMSMessageAttributes.mr_createEntity(in: localContext)
      }
      if let dateSendServer = dict["datesend"] as? String {
        message.dateSendServer = DPAGFormatter.date.date(from: dateSendServer) ?? Date()
      } else {
        message.dateSendServer = Date()
      }
      if let dateDownloaded = dict["datedownloaded"] as? String {
        message.dateDownloaded = DPAGFormatter.date.date(from: dateDownloaded)
        message.attributes?.dateDownloaded = message.dateDownloaded
      }
      if let dateReadServer = dict["dateread"] as? String {
        message.dateReadServer = DPAGFormatter.date.date(from: dateReadServer)
        message.attributes?.dateReadServer = message.dateReadServer
      }
      if let localReadDate = dict["localReadDate"] as? String {
        message.dateReadLocal = DPAGFormatter.date.date(from: localReadDate)
        message.attributes?.dateReadLocal = DPAGFormatter.date.date(from: localReadDate)
      }
      if let localSendDate = dict["localSendDate"] as? String {
        message.dateSendLocal = DPAGFormatter.date.date(from: localSendDate) ?? Date()
      } else {
        message.dateSendLocal = Date()
      }
    }

    func recoverDates(fromDict dict: [AnyHashable: Any], forTimedMessage message: SIMSMessageToSend) {
      if let dateToSend = dict["dateToSend"] as? String {
        message.dateToSend = DPAGFormatter.date.date(from: dateToSend) ?? Date()
      }
      if let dateCreated = dict["dateCreated"] as? String {
        message.dateCreated = DPAGFormatter.date.date(from: dateCreated) ?? Date()
      }
    }

    func recoverStates(fromDict dict: [AnyHashable: Any], forMessage message: SIMSMessage) {
      message.errorType = NSNumber(value: DPAGMessageSecurityError.none.rawValue)
      if let signatureValid = dict["signatureValid"] as? String, signatureValid == "false" {
        message.errorType = NSNumber(value: DPAGMessageSecurityError.signatureInvalid.rawValue)
      }
      self.saveRecoveredSignatures(fromDict: dict, forMessage: message)
      if let sendingFailed = dict["sendingFailed"] as? String, sendingFailed == "true" {
        message.sendingState = NSNumber(value: DPAGMessageState.sentFailed.rawValue)
      }
      if let priorityHigh = dict[DPAGStrings.JSON.Message.PRIORITY] as? String, priorityHigh == "true" {
        message.optionsMessage = message.optionsMessage.union(.priorityHigh)
      }
    }

    func recoverStates(fromDict dict: [AnyHashable: Any], forTimedMessage message: SIMSMessageToSend) {
      self.saveRecoveredSignatures(fromDict: dict, forMessage: message)
      if let sendingFailed = dict["sendingFailed"] as? String, sendingFailed == "true" {
        message.sendingState = NSNumber(value: DPAGMessageState.sentFailed.rawValue)
      }
      if let priorityHigh = dict[DPAGStrings.JSON.Message.PRIORITY] as? String, priorityHigh == "true" {
        message.optionsMessage = message.optionsMessage.union(.priorityHigh)
      }
    }

    func recoverSignature(fromDict dict: [AnyHashable: Any], forMessage message: SIMSManagedObjectMessage, accountInfo account: SIMSAccount) {
      guard let signature = dict["signature"] as? [AnyHashable: Any] else { return }
      guard let hashes = signature["hashes"] as? [AnyHashable: Any] else { return }
      guard let attachmentSha = hashes["attachment/0"] as? String else { return }
      guard let deviceCrypto = CryptoHelper.sharedInstance else { return }
      guard let key = account.keyRelationship else { return }
      message.attachmentHash = try? deviceCrypto.encrypt(string: attachmentSha, with: key)
      guard let signature256 = dict["signature-sha256"] as? [AnyHashable: Any] else { return }
      guard let hashes256 = signature256["hashes"] as? [AnyHashable: Any] else { return }
      guard let attachmentSha256 = hashes256["attachment/0"] as? String else { return }
      message.attachmentHash256 = try? deviceCrypto.encrypt(string: attachmentSha256, with: key)
    }

    func saveRecoveredSignatures(fromDict dict: [AnyHashable: Any], forMessage message: SIMSManagedObjectMessage) {
      if let signature = dict["signature"] as? [AnyHashable: AnyHashable], let jsonData = try? JSONSerialization.data(withJSONObject: signature, options: []) {
        message.rawSignature = String(data: jsonData, encoding: .utf8)
      }
      if let signature = dict["signature-sha256"] as? [AnyHashable: AnyHashable], let jsonData = try? JSONSerialization.data(withJSONObject: signature, options: []) {
        message.rawSignature256 = String(data: jsonData, encoding: .utf8)
      }
    }

    func loadTimedMessages() throws {
      var serverMessageGuids = try self.loadTimedMessageGuids()
      try DPAGApplicationFacade.persistance.saveWithError { localContext in
        let allTimedMessages = try SIMSMessageToSend.findAll(in: localContext)
        for message in allTimedMessages {
          if let messageGuid = message.guid, let idx = serverMessageGuids.firstIndex(of: messageGuid) {
            serverMessageGuids.remove(at: idx)
          } else {
            message.streamGuid = "{hiddenstream}"
          }
        }
        if serverMessageGuids.isEmpty == false {
          for i in stride(from: 0, to: serverMessageGuids.count, by: 10) {
            let fromIndex = i
            let toIndex = min(fromIndex + 10, serverMessageGuids.count)
            let guids = Array(serverMessageGuids[fromIndex ..< (toIndex - fromIndex)])
            let messages = try self.loadTimedMessages(messageGuids: guids)
            for message in messages {
              guard let innerDict = message["TimedMessage"] as? [AnyHashable: Any] else { continue }
              guard let guid = innerDict["guid"] as? String else { continue }
              guard (innerDict["data"] as? String) != nil else { continue }
              guard (innerDict["sendDate"] as? String) != nil else { continue }
              if guid.hasPrefix(.messageChat) {
                try self.recoverTimedPrivateMessageFromServer(timedMessage: innerDict, in: localContext)
              } else if guid.hasPrefix(.messageGroup) {
                try self.recoverTimedGroupMessageFromServer(timedMessage: innerDict, in: localContext)
              }
            }
          }
        }
      }
    }

    func convertAttachment(for message: SIMSManagedObjectMessage, toDict dict: inout [AnyHashable: Any], zipFile: OZZipFile?) throws {
      if let attachment = message.attachment {
        if let zipFile = zipFile, AttachmentHelper.attachmentAlreadySavedForGuid(attachment), let dataUrl = AttachmentHelper.attachmentFilePath(guid: attachment) {
          try self.saveAttachment(fileUrl: dataUrl, withFileName: attachment, into: zipFile)
        }
        dict["attachment"] = [attachment]
      }
    }

    func convertDates(for message: SIMSMessage, toDict dict: inout [AnyHashable: Any]) {
      if let datesend = message.dateSendServer {
        dict["datesend"] = DPAGFormatter.date.string(from: datesend)
      }
      if let dateDownloaded = message.attributes?.dateDownloaded ?? message.dateDownloaded {
        dict["datedownloaded"] = DPAGFormatter.date.string(from: dateDownloaded)
      }
      if let dateReadServer = message.attributes?.dateReadServer ?? message.dateReadServer {
        dict["dateread"] = DPAGFormatter.date.string(from: dateReadServer)
      }
      if let dateReadLocal = message.attributes?.dateReadLocal ?? message.dateReadLocal {
        dict["localReadDate"] = DPAGFormatter.date.string(from: dateReadLocal)
      }
      if let dateSendLocal = message.dateSendLocal {
        dict["localSendDate"] = DPAGFormatter.date.string(from: dateSendLocal)
      }
    }

    func convertStates(for message: SIMSMessage, toDict dict: inout [AnyHashable: Any]) {
      if message.sendingStateValid == .sentFailed {
        dict["sendingFailed"] = "true"
      } else if message.sendingStateValid == .sentSucceeded {
        dict["sendingFailed"] = "false"
      }
      let errorType = (message.errorType?.intValue ?? DPAGMessageSecurityError.none.rawValue)
      if errorType == DPAGMessageSecurityError.hashesInvalid.rawValue || errorType == DPAGMessageSecurityError.signatureInvalid.rawValue {
        dict["signatureValid"] = "false"
      } else {
        dict["signatureValid"] = "true"
      }
      if message.optionsMessage.contains(.priorityHigh) {
        dict[DPAGStrings.JSON.Message.PRIORITY] = "true"
      }
    }

    func convertDates(for message: SIMSMessageToSend, toDict dict: inout [AnyHashable: Any]) {
      if let dateToSend = message.dateToSend {
        dict["dateToSend"] = DPAGFormatter.date.string(from: dateToSend)
      }
      if let dateCreated = message.dateCreated {
        dict["dateCreated"] = DPAGFormatter.date.string(from: dateCreated)
      }
    }

    func convertStates(for message: SIMSMessageToSend, toDict dict: inout [AnyHashable: Any]) {
      if message.sendingStateValid == .sentFailed {
        dict["sendingFailed"] = "true"
      } else if message.sendingStateValid == .sentSucceeded {
        dict["sendingFailed"] = "false"
      }
      dict["signatureValid"] = "true"
      if message.optionsMessage.contains(.priorityHigh) {
        dict[DPAGStrings.JSON.Message.PRIORITY] = "true"
      }
    }

    func convertSignatures(for message: SIMSManagedObjectMessage, toDict dict: inout [AnyHashable: Any]) {
      if let rawSignature = message.rawSignature, let jsonData = rawSignature.data(using: .utf8) {
        do {
          let jsonDict = try JSONSerialization.jsonObject(with: jsonData, options: [])
          dict["signature"] = jsonDict
        } catch {
          DPAGLog(error)
        }
      }
      if let rawSignature256 = message.rawSignature256, let jsonData = rawSignature256.data(using: .utf8) {
        do {
          let jsonDict = try JSONSerialization.jsonObject(with: jsonData, options: [])
          dict["signature-sha256"] = jsonDict
        } catch {
          DPAGLog(error)
        }
      }
    }

    func convertKeys(for messageObj: SIMSManagedObjectMessage, toDict dict: inout [AnyHashable: Any]) {
      if let message = messageObj as? SIMSPrivateMessage {
        let fromKeyDict = message.fromKey2 != nil ? ["key": message.fromKey, "key2": message.fromKey2] : ["key": message.fromKey]
        let fromDict = [message.fromAccountGuid: fromKeyDict]
        dict["from"] = fromDict
        let toKeyDict = message.toKey2 != nil ? ["key": message.toKey, "key2": message.toKey2] : ["key": message.toKey]
        let toDict = [message.toAccountGuid: toKeyDict]
        dict["to"] = [toDict]
        if let aesKey2IV = message.aesKey2IV {
          dict["key2-iv"] = aesKey2IV
        }
      } else if let message = messageObj as? SIMSMessageToSendPrivate {
        let fromKeyDict = message.fromKey2 != nil ? ["key": message.fromKey, "key2": message.fromKey2] : ["key": message.fromKey]
        let fromAccount = DPAGApplicationFacade.cache.account?.guid
        let fromDict = [fromAccount: fromKeyDict]
        dict["from"] = fromDict
        let toKeyDict = message.toKey2 != nil ? ["key": message.toKey, "key2": message.toKey2] : ["key": message.toKey]
        let toDict = [message.toAccountGuid: toKeyDict]
        dict["to"] = [toDict]
        if let aesKey2IV = message.aesKey2IV {
          dict["key2-iv"] = aesKey2IV
        }
      } else if let message = messageObj as? SIMSGroupMessage {
        let fromKeyDict = ["key": ""]
        let fromDict = [message.fromAccountGuid: fromKeyDict]
        dict["from"] = fromDict
        dict["to"] = message.toGroupGuid
      } else if let message = messageObj as? SIMSMessageToSendGroup {
        let fromKeyDict = ["key": ""]
        let fromAccount = DPAGApplicationFacade.cache.account?.guid
        let fromDict = [fromAccount: fromKeyDict]
        dict["from"] = fromDict
        let toKeyDict = ["key": message.toGroupGuid]
        let toDict = [message.toGroupGuid: toKeyDict]
        dict["to"] = [toDict]
      }
    }

    func loadChannelGuids() throws -> [String] {
      var channelGuids: [String] = []
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
        } else if let rc = responseObject as? [[AnyHashable: Any]] {
          DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            for channel in rc {
              guard let channelShort = channel["Channel"] as? [AnyHashable: Any] else { continue }
              guard let guid = channelShort["guid"] as? String else { continue }
              guard let channel = SIMSChannel.findFirst(byGuid: guid, in: localContext) ?? SIMSChannel.mr_createEntity(in: localContext) else { continue }
              channelGuids.append(guid)
              let checksum = channelShort["checksum"] as? String
              let shortDesc = channelShort["short_desc"] as? String
              channel.guid = guid
              channel.name_short = shortDesc
              channel.checksum = checksum
              channel.feedType = NSNumber(value: DPAGChannelType.channel.rawValue)
            }
          }
        }
      }
      DPAGApplicationFacade.server.getChannels(withResponse: responseBlock)
      _ = semaphore.wait(timeout: .distantFuture)
      if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
        throw DPAGErrorBackup.errServer(errorCode: errorCode, errorMessage: errorMessage)
      }
      return channelGuids
    }

    func loadChannels() throws {
      DPAGLog("Start Loading Channels")
      let channelGuids = try self.loadChannelGuids()
      var errorCodeBlock: String?
      var errorMessageBlock: String?
      let semaphore = DispatchSemaphore(value: 0)
      DPAGApplicationFacade.feedWorker.updateFeeds(feedGuids: channelGuids, feedType: .channel, feedUpdatedBlock: { _, errorCode, errorMessage in
        defer {
          semaphore.signal()
        }
        if let errorMessage = errorMessage {
          DPAGLog(errorMessage)
          errorMessageBlock = errorMessage
          errorCodeBlock = errorCode
        }
      })
      _ = semaphore.wait(timeout: .distantFuture)
      if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
        throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
      }
      DPAGLog("Finished Loading Channels")
    }

    func recoverChannels(backupFileInfo: DPAGBackupFileInfo) throws {
      guard let channels = try backupFileInfo.loadAndDecryptStream(name: "channels.json") as? [[AnyHashable: Any]] else { return }
      var channelGuids: [String] = []
      var channelsToSend: [[AnyHashable: Any]] = []
      try DPAGApplicationFacade.persistance.saveWithError { localContext in
        
        for channelBackup in channels {
          guard let innerChannel = channelBackup["ChannelBackup"] as? [AnyHashable: Any] else { continue }
          guard let guid = innerChannel["guid"] as? String else { continue }
          guard let channel = SIMSChannel.findFirst(byGuid: guid, in: localContext) else { continue }
          guard let channelStream = (SIMSMessageStream.findFirst(byGuid: guid, in: localContext) ?? SIMSChannelStream.mr_createEntity(in: localContext)) as? SIMSChannelStream else { continue }
          channel.subscribed = true
          channel.feedType = NSNumber(value: DPAGChannelType.channel.rawValue)
          channelGuids.append(guid)
          channelStream.guid = channel.guid
          channelStream.isConfirmed = true
          channelStream.typeStream = .channel
          if let lastMessageDate = innerChannel["lastModifiedDate"] as? String {
            channelStream.lastMessageDate = DPAGFormatter.date.date(from: lastMessageDate)
          }
          channel.stream = channelStream
          let channelOptions = try SIMSChannelOption.findAll(in: localContext, with: NSPredicate(format: "ident BEGINSWITH %@", guid))
          let selectedOptions = innerChannel["@ident"] as? [String]
          for opt in channelOptions {
            guard let ident = opt.ident else { continue }
            let option = String(ident[ident.index(guid.endIndex, offsetBy: 3)...])
            if selectedOptions?.contains(option) ?? false {
              opt.value = "on"
            }
          }
          let currentFilter = channel.currentFilter()
          var innerDict: [String: String] = [:]
          if let notification = innerChannel["notification"] as? String {
            innerDict["notification"] = notification
            if notification == "disabled" {
              channel.notificationEnabled = false
            }
          }
          innerDict["guid"] = guid
          innerDict["filter"] = currentFilter
          channelsToSend.append(["Channel": innerDict])
        }
      }
      try self.setFollowedChannels(channelInfos: channelsToSend)
      self.loadChannelAssets(channelGuids: channelGuids)
    }

    func recoverChannelMessage(singleMessage: [AnyHashable: Any], backupFileInfo: DPAGBackupFileInfo, accountInfo account: SIMSAccount, channelStream: SIMSChannelStream, orderId nextOrderId: UInt64, in localContext: NSManagedObjectContext) throws {
      guard let guid = singleMessage["guid"] as? String else { return }
      guard let channelMessage = (SIMSMessage.findFirst(byGuid: guid, in: localContext) ?? SIMSChannelMessage.mr_createEntity(in: localContext)) as? SIMSChannelMessage, let channelGuid = channelStream.channel?.guid else { return }
      channelMessage.guid = guid
      channelMessage.fromAccountGuid = channelGuid
      channelMessage.fromKey = channelStream.channel?.aes_key ?? ""
      channelMessage.toAccountGuid = account.guid ?? "unknown"
      channelMessage.toKey = ""
      try self.recoverAttachment(fromDict: singleMessage, forMessage: channelMessage, accountInfo: account, backupFileInfo: backupFileInfo)
      self.recoverDates(fromDict: singleMessage, forMessage: channelMessage, in: localContext)
      let data = singleMessage["data"] as? String
      channelMessage.data = data
      self.recoverStates(fromDict: singleMessage, forMessage: channelMessage)
      channelMessage.typeMessage = .channel
      channelMessage.messageOrderId = NSNumber(value: nextOrderId)
      channelMessage.stream = channelStream
      if channelMessage.attributes?.dateReadLocal == nil, let stream = channelMessage.stream {
        stream.optionsStream = stream.optionsStream.union(channelMessage.optionsMessage.contains(.priorityHigh) ? [.hasUnreadMessages, .hasUnreadHighPriorityMessages] : [.hasUnreadMessages])
      }
      if let isSystemMessageStr = singleMessage["isSystemMessage"] as? String {
        if (isSystemMessageStr as NSString).boolValue {
          channelMessage.fromAccountGuid = DPAGConstantsGlobal.kSystemChatAccountGuid
        }
      }
    }

    func setFollowedChannels(channelInfos: [[AnyHashable: Any]]) throws {
      var errorCodeBlock: String?
      var errorMessageBlock: String?
      let semaphore = DispatchSemaphore(value: 0)
      let responseBlock: DPAGServiceResponseBlock = { _, errorCode, errorMessage in
        defer {
          semaphore.signal()
        }
        if let errorMessage = errorMessage {
          DPAGLog(errorMessage)
          errorMessageBlock = errorMessage
          errorCodeBlock = errorCode
        }
      }
      DPAGApplicationFacade.server.setFollowedChannels(channelInfos: channelInfos, withResponse: responseBlock)
      _ = semaphore.wait(timeout: .distantFuture)
      if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
        throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
      }
    }

    func setFollowedServices(channelInfos: [[AnyHashable: Any]]) throws {
      var errorCodeBlock: String?
      var errorMessageBlock: String?
      let semaphore = DispatchSemaphore(value: 0)
      let responseBlock: DPAGServiceResponseBlock = { _, errorCode, errorMessage in
        defer {
          semaphore.signal()
        }
        if let errorMessage = errorMessage {
          DPAGLog(errorMessage)
          errorMessageBlock = errorMessage
          errorCodeBlock = errorCode
        }
      }
      DPAGApplicationFacade.server.setFollowedServices(serviceInfos: channelInfos, withResponse: responseBlock)
      _ = semaphore.wait(timeout: .distantFuture)
      if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
        throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
      }
    }

    func loadChannelAssets(channelGuids: [String]) {
      let semaphore = DispatchSemaphore(value: 0)
      DPAGApplicationFacade.feedWorker.updateAssets(feedGuids: channelGuids, feedType: .channel) {
        semaphore.signal()
      }
      _ = semaphore.wait(timeout: .distantFuture)
    }

    func loadTimedMessageGuids() throws -> [String] {
      var retVal: [String] = []
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
        } else if let rc = responseObject as? [String] {
          retVal = rc
        }
      }
      DPAGApplicationFacade.server.getTimedMessageGuids(withResponse: responseBlock)
      _ = semaphore.wait(timeout: .distantFuture)
      if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
        throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
      }
      return retVal
    }

    func loadTimedMessages(messageGuids: [String]) throws -> [[AnyHashable: Any]] {
      var retVal: [[AnyHashable: Any]] = []
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
        } else if let rc = responseObject as? [[AnyHashable: Any]] {
          retVal = rc
        }
      }
      DPAGApplicationFacade.server.getTimedMessages(messageGuids: messageGuids, withResponse: responseBlock)
      _ = semaphore.wait(timeout: .distantFuture)
      if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
          throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
      }
      return retVal
    }

    func loadCurrentRoomInfos() throws -> [[AnyHashable: Any]] {
      var retVal: [[AnyHashable: Any]]?
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
        } else if let rc = responseObject as? [[AnyHashable: Any]] {
          retVal = rc
        }
      }
      DPAGApplicationFacade.server.getCurrentRoomInfo(withResponse: responseBlock)
      _ = semaphore.wait(timeout: .distantFuture)
      if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
        throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
      }
      if let retVal = retVal {
        return retVal
      }
      throw DPAGErrorBackup.errServerResponse
    }

    func leaveGroup(groupGuid: String, in _: NSManagedObjectContext) throws {
      guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) else { return }
      var errorCodeBlock: String?
      var errorMessageBlock: String?
      let semaphore = DispatchSemaphore(value: 0)
      let responseBlock: DPAGServiceResponseBlock = { _, errorCode, errorMessage in
        defer {
          semaphore.signal()
        }
        if let errorMessage = errorMessage {
          DPAGLog(errorMessage)
          errorMessageBlock = errorMessage
          errorCodeBlock = errorCode
        }
      }
      var nickNameEncoded: String?
      if DPAGApplicationFacade.preferences.sendNickname {
        let nickName = contact.nickName
        nickNameEncoded = nickName?.data(using: .utf8)?.base64EncodedString(options: .lineLength76Characters)
      }
      DPAGApplicationFacade.server.removeMember(accountGuid: account.guid, fromRoom: groupGuid, nickNameEncoded: nickNameEncoded, withResponse: responseBlock)
      _ = semaphore.wait(timeout: .distantFuture)
      if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
        throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
      }
    }

    func createDevice(accountGuid: String, phoneNumber: String?, withData metaData: String) throws {
      var errorCodeBlock: String?
      var errorMessageBlock: String?
      let semaphore = DispatchSemaphore(value: 0)
      let responseBlock: DPAGServiceResponseBlock = { _, errorCode, errorMessage in
        defer {
          semaphore.signal()
        }
        if let errorMessage = errorMessage {
          DPAGLog(errorMessage)
          if errorMessage == DPAGLocalizedString("service.error403") {
            errorMessageBlock = "service.error403.backup"
            errorCodeBlock = errorCode
          } else {
            errorMessageBlock = errorMessage
            errorCodeBlock = errorCode
          }
        }
      }
      DPAGApplicationFacade.server.createDeviceInAccount(accountGuid: accountGuid, phoneNumber: phoneNumber, metadata: metaData, withResponse: responseBlock)
      _ = semaphore.wait(timeout: .distantFuture)
      if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
        throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
      }
    }

    func createMiniBackup(tempDevice: Bool) throws -> String {
      var result: String? = "["
      let mode: DPAGBackupMode = tempDevice ? .miniBackupTempDevice : .miniBackup
      try self.accountBackup(zipFile: nil, writeOutput: &result, backupMode: mode)
      try self.contactBackup(zipFile: nil, writeOutput: &result, backupMode: mode, deletedCompanyContactsOnly: mode != .miniBackupTempDevice)
      try self.singleChatBackup(zipFile: nil, writeOutput: &result, backupMode: mode, includeDeletedCompanyContactsConversation: mode != .miniBackupTempDevice)
      try self.groupChatBackup(zipFile: nil, writeOutput: &result, backupMode: mode)
      if let retVal = result {
        return retVal + "]"
      }
      return ""
    }

    func recoverAccount(innerAccountInfo: [AnyHashable: Any], accountGuid: String, deviceGuid: String, publicKey pubKey: String, publicKeyFingerPrint publicKeySig: String) throws -> String {
      var deviceData: String?
      try DPAGApplicationFacade.persistance.saveWithError { localContext in
        guard let account = SIMSAccount.mr_createEntity(in: localContext), let device = SIMSDevice.mr_createEntity(in: localContext), let simsKey = SIMSKey.mr_createEntity(in: localContext), let contact = SIMSContactIndexEntry.mr_createEntity(in: localContext) else { throw DPAGErrorBackup.errDatabase }
        guard let deviceCrypto = CryptoHelper.sharedInstance else { throw DPAGErrorBackup.errCrypto }
        account.guid = innerAccountInfo["guid"] as? String
        account.accountState = .recoverBackup
        guard let privateKey = innerAccountInfo["privateKey"] as? String else { throw DPAGErrorBackup.errAccountData }
        account.privateKey = privateKey
        if let companyInfo = innerAccountInfo["companyInfo"] as? [AnyHashable: Any], let companyGuid = companyInfo["guid"] as? String {
          var ci: [AnyHashable: Any] = [:]
          DPAGApplicationFacade.preferences.isCompanyManagedState = true
          if let publicKey = companyInfo["publicKey"] {
            ci["publicKey"] = publicKey
          } else if let companyPublicKey = companyInfo["companyPublicKey"] {
            ci["companyPublicKey"] = companyPublicKey
          }
          ci["state"] = companyInfo["state"]
          ci["guid"] = companyGuid
          ci["name"] = companyInfo["name"]
          account.companyInfo = ci
          if let companyKey = companyInfo["companyKey"] as? String {
            account.setCompanyKey(companyKey)
          }
          if let companyUserDataKey = companyInfo["companyUserDataKey"] as? String {
            account.setCompanyUserDataKey(companyUserDataKey)
          }
        }
        device.guid = deviceGuid
        let passtoken = DPAGFunctionsGlobal.uuid()
        device.passToken = passtoken
        device.public_key = pubKey
        device.signedPublicRSAFingerprint = publicKeySig
        device.account_guid = accountGuid
        device.ownDevice = NSNumber(value: 1)
        simsKey.guid = DPAGFunctionsGlobal.uuid(prefix: .key)
        simsKey.device_guid = deviceGuid
        simsKey.deviceRelationship = device
        simsKey.accountRelationship = account
        contact.keyRelationship = simsKey
        contact.guid = account.guid
        contact.backupImportAccount(innerAccountInfo: innerAccountInfo)
        let ownPubKey = try deviceCrypto.getPublicKeyFromPrivateKey()
        let aesKey = try CryptoHelperEncrypter.getNewAesKey()
        let encAesKey = try CryptoHelperEncrypter.encrypt(string: aesKey, withPublicKey: ownPubKey)
        simsKey.aes_key = encAesKey
        let deviceDict = try device.deviceDictionary(type: "permanent")
        deviceData = deviceDict.JSONString
        DPAGApplicationFacade.model.update(with: localContext)
        DPAGSystemChat.systemChat(in: localContext)
      }
      DPAGApplicationFacade.cache.clearCache()
      if let deviceData = deviceData {
        return deviceData
      }
      throw DPAGErrorBackup.errAccountData
    }

    func createAdditionalDevice(accountGuid: String, transId transaktionId: String, device deviceString: String) throws -> [Any] {
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
          if errorMessage != "service.ERR-0007", errorMessage != "service.networkFailure" {
            errorMessageBlock = errorMessage
            errorCodeBlock = errorCode
          }
        } else if let rc = responseObject as? [Any] {
          retVal = rc
        }
      }
      DPAGApplicationFacade.server.createAdditionalDevice(accountGuid: accountGuid, transId: transaktionId, device: deviceString, withResponse: responseBlock)
      _ = semaphore.wait(timeout: .distantFuture)
      if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
        throw DPAGErrorBackup.errServer(errorCode: errorCode, errorMessage: errorMessage)
      }
      if let retVal = retVal {
        return retVal
      }
      throw DPAGErrorBackup.errServerResponse
    }

    func recoverMiniBackup(miniBackup: String, accountGuid: String, deviceGuid: String, deviceName deviceNameEncoded: String, publicKey pubKey: String, publicKeyFingerPrint publicKeySig: String, transId: String) throws {
      try autoreleasepool {
        guard let miniBackupData = miniBackup.data(using: .utf8) else { throw DPAGErrorBackup.errDataInvalid }
        let jsonData = try JSONSerialization.jsonObject(with: miniBackupData, options: .allowFragments)
        var existingRooms: [String: [AnyHashable: Any]]?
        if let backup = jsonData as? [Any] {
          for backupEntry in backup {
            if let entry = backupEntry as? [AnyHashable: Any] {
              if let accountBackup = entry["AccountBackup"] as? [AnyHashable: Any] {
                let deviceData = try self.recoverAccount(innerAccountInfo: accountBackup, accountGuid: accountGuid, deviceGuid: deviceGuid, publicKey: pubKey, publicKeyFingerPrint: publicKeySig)
                _ = try self.createAdditionalDevice(accountGuid: accountGuid, transId: transId, device: deviceData)
                _ = try DPAGApplicationFacade.couplingWorker.setDeviceNameInternal(guid: deviceGuid, deviceName: deviceNameEncoded)
                try DPAGApplicationFacade.couplingWorker.loadPrivateIndexFromServer(ifModifiedSince: nil, forceLoad: true)
              }
            } else if let entries = backupEntry as? [[AnyHashable: Any]], let firstEntry = entries.first {
              if firstEntry["DeletedCompanyContactBackup"] != nil {
                for contactEntry in entries {
                  try self.recoverContacts(backupFileInfo: nil, fromMinibackup: [contactEntry], backupMode: .miniBackup)
                }
              }
              if firstEntry["SingleChatBackup"] != nil {
                for chatEntry in entries {
                  try self.recoverSingleChatStreamInternal(backupFileInfo: nil, stream: [chatEntry], backupMode: .miniBackup)
                }
              }
              if firstEntry["ChatRoomBackup"] != nil {
                if existingRooms == nil {
                  let currentRoomInfos = try self.loadCurrentRoomInfos()
                  var mutableDict: [String: [AnyHashable: Any]] = [:]
                  for chatRoom in currentRoomInfos {
                    if let chatroomDict = chatRoom["ChatRoom"] as? [AnyHashable: Any] ?? chatRoom["ManagedRoom"] as? [AnyHashable: Any] ?? chatRoom["AnnouncementRoom"] as? [AnyHashable: Any] ?? chatRoom["RestrictedRoom"] as? [AnyHashable: Any] {
                        if let chatRoomGuid = chatroomDict["guid"] as? String {
                          mutableDict[chatRoomGuid] = chatroomDict
                        }
                      }
                    }
                    existingRooms = mutableDict
                  }
                  if let existingRooms = existingRooms {
                    for roomEntry in entries {
                      _ = try self.recoverGroupChatStreamInternal(backupFileInfo: nil, existingServerGroups: existingRooms, stream: [roomEntry], backupMode: .miniBackup)
                    }
                  }
              }
          }
        }
        DPAGApplicationFacade.preferences.didAskForPushPreview = true
        DPAGApplicationFacade.server.setBackgroundPushNotification(enable: true) { _, _, errorMessage in
          guard errorMessage == nil else { return }
          DPAGApplicationFacade.preferences.backgroundAccessTokenSyncEnabled = true
          DPAGApplicationFacade.server.setPreviewPushNotification(enable: true) { _, _, errorMessage in
            guard errorMessage == nil else { return }
            DPAGApplicationFacade.preferences.previewPushNotification = true
          }
        }
        try DPAGApplicationFacade.devicesWorker.createShareExtensionDevice(withResponse: nil)
      }
      try self.recoverAccountInfo()
    }
  }
}
