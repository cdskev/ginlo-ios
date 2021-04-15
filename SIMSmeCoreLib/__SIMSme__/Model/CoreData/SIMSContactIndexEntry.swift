//
//  SIMSContactIndexEntry.swift
//  SIMSmeCore
//
//  Created by RBU on 07.12.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Contacts
import CoreData
import Foundation

public struct SIMSContactIndexEntryAesKeys {
    public let aesKey: String
    public let recipientEncAesKey: String
    public let senderEncAesKey: String

    init(withAesKey aesKey: String, recipientEncAesKey: String, senderEncAesKey: String) {
        self.aesKey = aesKey
        self.recipientEncAesKey = recipientEncAesKey
        self.senderEncAesKey = senderEncAesKey
    }
}

class SIMSContactIndexEntry: SIMSManagedObjectEncrypted {
    @NSManaged var stream: SIMSStream?
    @NSManaged var messageReceiver: Set<SIMSMessageReceiver>?

    enum AttrString: String {
        case ACCOUNT_ID
        case MANDANT_IDENT

        case NICKNAME
        case STATUSMESSAGE
        case IMAGE_DATA

        case PROFIL_KEY
        case STATUS_ENCRYPTED
        case NICKNAME_ENCRYPTED
        case IMAGE_CHECKSUM

        case PHONE_NUMBER = "PHONE"
        case EMAIL_ADDRESS = "EMAIL"
        case EMAIL_DOMAIN

        case LAST_NAME
        case FIRST_NAME
        case DEPARTMENT

        case PUBLIC_KEY
        case CHECKSUM
        // case KEY_IV = "KEY_IV"

        // case CONTACT_ENTRY_GUID = "CONTACT_ENTRY_GUID"
        case PRIVATE_INDEX_GUID
        case PRIVATE_INDEX_KEY
        case PRIVATE_INDEX_KEY_DATA
        case PRIVATE_INDEX_KEY_IV
        case PRIVATE_INDEX_DATA
        case PRIVATE_INDEX_SIGNATURE
        case PRIVATE_INDEX_CHECKSUM

        // WebMessenger
        case IS_FAVORITE

        case OOO_STATUS_STATUS_TEXT
        case OOO_STATUS_STATUS_VALID
        case OOO_STATUS_STATUS_STATE
    }

    private enum AttrStringPrivate: String {
        case AES_KEY
        case AES_KEY_RECIPIENT_ENCRYPTED
        case AES_KEY_SENDER_ENCRYPTED
    }

    enum AttrDate: String {
        case STATUS_MESSAGE_CREATED_AT
        case UPDATED_AT
        case CREATED_AT
    }

    enum AttrBool: String {
        case IS_DELETED
        case IS_BLOCKED
        case IS_FAVOURITE
        case IS_CONFIRMED
    }

    private static let CONFIDENCE_STATE = "CONFIDENCE_STATE"
    private static let ENTRY_TYPE_SERVER = "ENTRY_TYPE_SERVER"
    private static let ENTRY_TYPE_LOCAL = "ENTRY_TYPE_LOCAL"

    @objc
    public class func entityName() -> String { DPAGStrings.CoreData.Entities.CONTACT_INDEX_ENTRY }

    subscript(key: SIMSContactIndexEntry.AttrString) -> String? {
        get {
            var retVal = self.getAttribute(key.rawValue) as? String

            if key == SIMSContactIndexEntry.AttrString.PUBLIC_KEY, retVal == nil, let context = self.managedObjectContext, let account = SIMSAccount.mr_findFirst(in: context), self.guid == account.guid, let privateKey = account.privateKey {
                do {
                    let crypto = try CryptoHelperSimple(publicKey: privateKey, privateKey: privateKey)

                    retVal = try crypto.getPublicKeyFromPrivateKey()

                    self[.PUBLIC_KEY] = retVal
                } catch
                {}
            }
            if let hasVal = retVal, key == .PHONE_NUMBER, hasVal.hasPrefix(DPAGGuidPrefix.account) {
                retVal = ""
            }
            return retVal
        }
        set {
            if let aValue = newValue {
                let oldValue = self.getAttribute(key.rawValue) as? String

                if oldValue == aValue {
                    return
                }
                // Workaround fuer die kaputten WebClients
                if key == .PHONE_NUMBER, aValue.hasPrefix(DPAGGuidPrefix.account) {
                    return
                }

                self.setAttributeWithKey(key.rawValue, andValue: aValue)

                if key != .PRIVATE_INDEX_CHECKSUM, key != .IMAGE_CHECKSUM, key != .STATUS_ENCRYPTED, key != .NICKNAME_ENCRYPTED, self.getAttribute(SIMSContactIndexEntry.AttrString.PRIVATE_INDEX_CHECKSUM.rawValue) as? String != "" {
                    self.setAttributeWithKey(SIMSContactIndexEntry.AttrString.PRIVATE_INDEX_CHECKSUM.rawValue, andValue: "")
                    DPAGLog("Updateing SIMSContact : AccountGuid : %@", self.guid ?? "- unknown -")
                }

                switch key {
                case .PROFIL_KEY:
                    var tmp = self[.STATUS_ENCRYPTED]
                    self[.STATUS_ENCRYPTED] = nil
                    self[.STATUS_ENCRYPTED] = tmp
                    tmp = self[.NICKNAME_ENCRYPTED]
                    self[.NICKNAME_ENCRYPTED] = nil
                    self[.NICKNAME_ENCRYPTED] = tmp
                    tmp = self[.IMAGE_CHECKSUM]
                    self[.IMAGE_CHECKSUM] = nil
                    self[.IMAGE_CHECKSUM] = tmp
                case .STATUS_ENCRYPTED:
                    if let profilKey = self[.PROFIL_KEY] {
                        do {
                            let aStatus = try CryptoHelperDecrypter.decryptToString(encryptedString: aValue, withAesKeyDict: ["key": profilKey])

                            if self[.STATUSMESSAGE] != aStatus {
                                self[.STATUSMESSAGE] = aStatus

                                if self.entryTypeServer == .meMyselfAndI {
                                    DPAGApplicationFacade.statusWorker.updateStatus(aStatus, broadCast: false)
                                }
                            }
                        } catch {
                            DPAGLog(error)
                        }
                    }
                case .NICKNAME_ENCRYPTED:
                    if let profilKey = self[.PROFIL_KEY] {
                        do {
                            let aNickname = try CryptoHelperDecrypter.decryptToString(encryptedString: aValue, withAesKeyDict: ["key": profilKey])

                            if self[.NICKNAME] != aNickname {
                                self[.NICKNAME] = aNickname
                            }
                        } catch {
                            DPAGLog(error)
                        }
                    }
                case .IMAGE_CHECKSUM:
                    if let selfGuid = self.guid, self[.PROFIL_KEY] != nil {
                        // Image herunterladen
                        self.performBlockInBackground {
                            DPAGApplicationFacade.contactsWorker.loadAccountImage(accountGuid: selfGuid)
                        }
                    }
                default:
                    break
                }
            } else {
                self.removeAttribute(key.rawValue)
            }
        }
    }

    private subscript(key: SIMSContactIndexEntry.AttrStringPrivate) -> String? {
        get { self.getAttribute(key.rawValue) as? String }
        set { if let aValue = newValue { self.setAttributeWithKey(key.rawValue, andValue: aValue) } }
    }

    subscript(key: SIMSContactIndexEntry.AttrDate) -> Date? {
        get {
            if let date = self.getAttribute(key.rawValue) as? String {
                return DPAGFormatter.date.date(from: date)
            }
            return nil
        }
        set {
            if let aValue = newValue {
                self.setAttributeWithKey(key.rawValue, andValue: DPAGFormatter.date.string(from: aValue))
            }
        }
    }

    subscript(key: SIMSContactIndexEntry.AttrBool) -> Bool {
        get { self.getAttribute(key.rawValue) as? Bool ?? false }
        set {
            let aValue = newValue
            let oldValue = self.getAttribute(key.rawValue) as? Bool

            if oldValue == aValue {
                return
            }
            self.setAttributeWithKey(key.rawValue, andValue: aValue)

            self.setAttributeWithKey(SIMSContactIndexEntry.AttrString.PRIVATE_INDEX_CHECKSUM.rawValue, andValue: "")
            DPAGLog("Updateing SIMSContact : AccountGuid : %@", self.guid ?? "- unknown -")

            self.setAttributeWithKey(key.rawValue, andValue: aValue)

            switch key {
            case .IS_DELETED:
                self.stream?.wasDeleted = NSNumber(value: aValue)
            case .IS_BLOCKED:
                if let stream = self.stream {
                    stream.optionsStream = aValue ? stream.optionsStream.union(.blocked) : stream.optionsStream.subtracting(.blocked)
                }
            default:
                break
            }
        }
    }

    var entryTypeServer: DPAGContact.EntryTypeServer {
        get {
            let retVal = DPAGContact.EntryTypeServer(rawValue: (self.getAttribute(SIMSContactIndexEntry.ENTRY_TYPE_SERVER) as? NSNumber)?.intValue ?? DPAGContact.EntryTypeServer.privat.rawValue)

            return retVal ?? .privat
        }
        set {
            self.setAttributeWithKey(SIMSContactIndexEntry.ENTRY_TYPE_SERVER, andValue: NSNumber(value: newValue.rawValue))
        }
    }

    var entryTypeLocal: DPAGContact.EntryTypeLocal {
        get {
            let retVal = DPAGContact.EntryTypeLocal(rawValue: (self.getAttribute(SIMSContactIndexEntry.ENTRY_TYPE_LOCAL) as? NSNumber)?.intValue ?? DPAGContact.EntryTypeLocal.hidden.rawValue)

            return retVal ?? DPAGContact.EntryTypeLocal.hidden
        }
        set {
            let aValue = newValue
            let oldValue = self.getAttribute(SIMSContactIndexEntry.ENTRY_TYPE_LOCAL) as? NSNumber

            if oldValue != nil, oldValue?.intValue == aValue.rawValue {
                return
            }

            self.setAttributeWithKey(SIMSContactIndexEntry.AttrString.PRIVATE_INDEX_CHECKSUM.rawValue, andValue: "")
            self.setAttributeWithKey(SIMSContactIndexEntry.ENTRY_TYPE_LOCAL, andValue: NSNumber(value: newValue.rawValue))
        }
    }

    var confidenceState: DPAGConfidenceState {
        get {
            if let numState = self.getAttribute(SIMSContactIndexEntry.CONFIDENCE_STATE) as? NSNumber {
                return DPAGConfidenceState(rawValue: numState.uintValue) ?? .low
            }
            return .low
        }
        set {
            let currentConfidenceState = (self.getAttribute(SIMSContactIndexEntry.CONFIDENCE_STATE) as? NSNumber)?.uintValue ?? DPAGConfidenceState.low.rawValue

            if currentConfidenceState < newValue.rawValue {
                self.setAttributeWithKey(SIMSContactIndexEntry.CONFIDENCE_STATE, andValue: NSNumber(value: newValue.rawValue))

                // Checksumme zurücksetzen (Update forcieren)
                self.setAttributeWithKey(SIMSContactIndexEntry.AttrString.PRIVATE_INDEX_CHECKSUM.rawValue, andValue: "")

                let currentState = self.confidenceState

                self.stream?.isConfirmed = NSNumber(value: self.isConfirmed)

                if let messages = self.stream?.messages {
                    for msgObj in messages {
                        if let msg = msgObj as? SIMSMessage, let msgGuid = msg.guid {
                            DPAGApplicationFacade.cache.decryptedMessageFast(messageGuid: msgGuid)?.confidenceState = currentState
                        }
                    }
                }
            }
        }
    }

    @discardableResult
    func createNewStream(in localContext: NSManagedObjectContext) -> SIMSStream? {
        self.setAttributeWithKey(SIMSContactIndexEntry.CONFIDENCE_STATE, andValue: NSNumber(value: DPAGConfidenceState.low.rawValue))

        if let stream = SIMSStream.mr_createEntity(in: localContext) {
            stream.typeStream = .single

            stream.optionsStream = DPAGApplicationFacade.preferences.streamVisibilitySingle ? [] : [.filtered]
            stream.guid = DPAGFunctionsGlobal.uuid()
            stream.contactIndexEntry = self
            stream.isConfirmed = NSNumber(value: self.isConfirmed)
            stream.wasDeleted = NSNumber(value: false)

            self.stream = stream
        }

        return self.stream
    }

    var isConfirmed: Bool {
        (self[.IS_CONFIRMED] || self.confidenceState.rawValue > DPAGConfidenceState.low.rawValue)
    }

    func setConfirmed() {
        self[.IS_CONFIRMED] = true
        if let stream = self.stream {
            stream.isConfirmed = NSNumber(value: self.isConfirmed)
        }
    }

    var isSystemContact: Bool {
        self.guid == DPAGConstantsGlobal.kSystemChatAccountGuid
    }

    func aesKey(accountPublicKey: String, createNew: Bool) throws -> DPAGContactAesKeys? {
        if let aesKey = self[.AES_KEY], let recipientEncAesKey = self[.AES_KEY_RECIPIENT_ENCRYPTED], let senderEncAesKey = self[.AES_KEY_SENDER_ENCRYPTED] {
            return DPAGContactAesKeys(aesKey: aesKey, recipientEncAesKey: recipientEncAesKey, senderEncAesKey: senderEncAesKey)
        }

        if createNew, let publicKey = self[.PUBLIC_KEY] {
            let aesKeyNew = try CryptoHelperEncrypter.getNewRawAesKey()

            let recipientEncAesKey = try CryptoHelperEncrypter.encrypt(string: aesKeyNew, withPublicKey: publicKey)
            let senderEncAesKey = try CryptoHelperEncrypter.encrypt(string: aesKeyNew, withPublicKey: accountPublicKey)

            self[.AES_KEY] = aesKeyNew
            self[.AES_KEY_RECIPIENT_ENCRYPTED] = recipientEncAesKey
            self[.AES_KEY_SENDER_ENCRYPTED] = senderEncAesKey

            return DPAGContactAesKeys(aesKey: aesKeyNew, recipientEncAesKey: recipientEncAesKey, senderEncAesKey: senderEncAesKey)
        }
        return nil
    }

    func ensureProfilKey() throws {
        if self[.PROFIL_KEY] == nil, self.entryTypeServer == .meMyselfAndI {
            let aProfilKey = try CryptoHelperEncrypter.getNewRawAesKey()

            self[.PROFIL_KEY] = aProfilKey
        }
    }

    func encryptWithProfilKey(_ data: String?) throws -> String? {
        guard let data = data, let profilKey = self[.PROFIL_KEY] else { return nil }

        return try CryptoHelperEncrypter.encrypt(string: data, withAesKeyDict: ["key": profilKey])
    }

    func encryptWithProfilKey(_ data: String?, iv: String) throws -> String? {
        guard let data = data, let profilKey = self[.PROFIL_KEY] else { return nil }

        return try CryptoHelperEncrypter.encrypt(string: data, withAesKeyDict: ["key": profilKey, "iv": iv])
    }

    func setImageEncrypted(_ aImageEncrypted: String) throws {
        if let profilKey = self[.PROFIL_KEY] {
            // und entschlüsseln
            let aImage = try CryptoHelperDecrypter.decryptToString(encryptedString: aImageEncrypted, withAesKeyDict: ["key": profilKey])

            // und speichern
            self[.IMAGE_DATA] = aImage
        }
    }

    var isReadOnly: Bool {
        self.stream?.optionsStream.contains(.isReadOnly) ?? true
    }

    var streamState: DPAGChatStreamState {
        let streamState: DPAGChatStreamState = (self[.IS_DELETED] || DPAGSystemChat.isSystemChat(self.stream) || self[.IS_BLOCKED] || self.isReadOnly) ? .readOnly : .write

        return streamState
    }

    func removeAllMessages() {
        self.stream?.messages?.forEach { ($0 as? NSManagedObject)?.mr_deleteEntity() }
    }

    func update(withJsonData jsonData: Data) -> Bool {
        guard let innerDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [AnyHashable: Any] else {
            return false
        }

        guard let innerDictInfo = innerDict["AdressInformation-v1"] as? [AnyHashable: Any] else {
            return false
        }

        var updated = false

        if self.entryTypeServer != .meMyselfAndI {
            if let emailAddress = innerDictInfo["email"] as? String, self[.EMAIL_ADDRESS] != emailAddress {
                self[.EMAIL_ADDRESS] = emailAddress
                updated = true
            }

            if let phoneNumber = innerDictInfo["phone"] as? String, self[.PHONE_NUMBER] != phoneNumber {
                self[.PHONE_NUMBER] = phoneNumber
                updated = true
            }
        }

        if let firstName = innerDictInfo["firstname"] as? String, self[.FIRST_NAME] != firstName {
            self[.FIRST_NAME] = firstName
            updated = true
        }

        if let name = (innerDictInfo["name"] as? String) ?? (innerDictInfo["lastname"] as? String), self[.LAST_NAME] != name {
            self[.LAST_NAME] = name
            updated = true
        }

        if let department = innerDictInfo["department"] as? String, self[.DEPARTMENT] != department {
            self[.DEPARTMENT] = department
            updated = true
        }

        if let innerDictContact = innerDict["ContactInformation-v1"] as? [AnyHashable: Any] {
            if let profileImage = innerDictContact["profileImage"] as? String, self[.IMAGE_DATA] != profileImage {
                self[.IMAGE_DATA] = profileImage
                updated = true
            }
            if let nickname = innerDictContact["nickname"] as? String, self[.NICKNAME] != nickname {
                self[.NICKNAME] = nickname
                updated = true
            }
            if let state = innerDictContact["state"] as? String, self[.STATUSMESSAGE] != state {
                self[.STATUSMESSAGE] = state
                updated = true
            }
        }

        if updated {
            self[.UPDATED_AT] = Date()

            if let guid = self.guid {
                DPAGApplicationFacade.cache.cachedContact(for: guid)?.removeCachedImages()
            }
        }

        return true
    }

    private func imageDataEncoded(forContact contact: CNContact) -> String? {
        if self.guid == DPAGApplicationFacade.cache.account?.guid, self[.IMAGE_DATA] != nil {
            return nil
        }

        guard self[.IMAGE_CHECKSUM] == nil,
            contact.imageDataAvailable,
            let imageData = contact.imageData,
            let editedImage = imageData.contactImageDataEncoded(),
            self[.IMAGE_DATA] != editedImage else {
            return nil
        }

        return editedImage
    }

    func update(withContactIdentifier contactIdentifier: String) {
        self.entryTypeLocal = .privat

        let blockImageOnly = {
            if let contact = try? CNContactStore().unifiedContact(withIdentifier: contactIdentifier, keysToFetch: [CNContactImageDataKey as CNKeyDescriptor, CNContactImageDataAvailableKey as CNKeyDescriptor]) {
                if let editedImage = self.imageDataEncoded(forContact: contact) {
                    self[.IMAGE_DATA] = editedImage
                    self[.UPDATED_AT] = Date()

                    if let guid = self.guid {
                        DPAGApplicationFacade.cache.contact(for: guid)?.removeCachedImages()
                    }
                }
            }
        }

        let blockAllKeys = {
            if let contact = try? CNContactStore().unifiedContact(withIdentifier: contactIdentifier, keysToFetch: [CNContactGivenNameKey as CNKeyDescriptor, CNContactFamilyNameKey as CNKeyDescriptor, CNContactPhoneNumbersKey as CNKeyDescriptor, CNContactEmailAddressesKey as CNKeyDescriptor, CNContactDepartmentNameKey as CNKeyDescriptor, CNContactImageDataKey as CNKeyDescriptor, CNContactImageDataAvailableKey as CNKeyDescriptor]) {
                var updated = false

                if contact.givenName.isEmpty == false, self[.FIRST_NAME] != contact.givenName {
                    self[.FIRST_NAME] = contact.givenName
                    updated = true
                }
                if contact.familyName.isEmpty == false, self[.LAST_NAME] != contact.familyName {
                    self[.LAST_NAME] = contact.familyName
                    updated = true
                }
                if contact.departmentName.isEmpty == false, self[.DEPARTMENT] != contact.departmentName {
                    self[.DEPARTMENT] = contact.departmentName
                    updated = true
                }
                if self[.PHONE_NUMBER] == nil, let phoneNumberCN = contact.phoneNumbers.first?.value.stringValue, self[.PHONE_NUMBER] != phoneNumberCN {
                    self[.PHONE_NUMBER] = phoneNumberCN
                    updated = true
                }
                if self[.EMAIL_ADDRESS] == nil, let emailAddressCN = contact.emailAddresses.first?.value, self[.EMAIL_ADDRESS] != emailAddressCN as String {
                    self[.EMAIL_ADDRESS] = emailAddressCN as String
                    updated = true
                }

                if let editedImage = self.imageDataEncoded(forContact: contact) {
                    self[.IMAGE_DATA] = editedImage
                    updated = true
                }

                if updated {
                    self[.UPDATED_AT] = Date()

                    if let guid = self.guid {
                        DPAGApplicationFacade.cache.contact(for: guid)?.removeCachedImages()
                    }
                }
            }
        }

        let blockMailKeys = {
            if let contact = try? CNContactStore().unifiedContact(withIdentifier: contactIdentifier, keysToFetch: [CNContactGivenNameKey as CNKeyDescriptor, CNContactFamilyNameKey as CNKeyDescriptor, CNContactPhoneNumbersKey as CNKeyDescriptor, CNContactEmailAddressesKey as CNKeyDescriptor, CNContactDepartmentNameKey as CNKeyDescriptor, CNContactImageDataKey as CNKeyDescriptor, CNContactImageDataAvailableKey as CNKeyDescriptor]) {
                var updated = false

                if contact.departmentName.isEmpty == false, self[.DEPARTMENT] != contact.departmentName {
                    self[.DEPARTMENT] = contact.departmentName
                    updated = true
                }
                if self[.PHONE_NUMBER] == nil, let phoneNumberCN = contact.phoneNumbers.first?.value.stringValue, self[.PHONE_NUMBER] != phoneNumberCN {
                    self[.PHONE_NUMBER] = phoneNumberCN
                    updated = true
                }

                if let editedImage = self.imageDataEncoded(forContact: contact) {
                    self[.IMAGE_DATA] = editedImage
                    updated = true
                }

                if updated {
                    self[.UPDATED_AT] = Date()

                    if let guid = self.guid {
                        DPAGApplicationFacade.cache.contact(for: guid)?.removeCachedImages()
                    }
                }
            }
        }

        switch self.entryTypeServer {
        case .company:
            blockImageOnly()
        case .email:
            blockMailKeys()
        case .meMyselfAndI:

            if DPAGApplicationFacade.preferences.isCompanyManagedState {
                blockImageOnly()
            } else {
                blockAllKeys()
            }
        case .privat:
            blockAllKeys()
        }
    }

    func backupExportAccount() -> [AnyHashable: Any] {
        // Eigenen Account Backupen
        var innerData: [AnyHashable: Any] = [:]

        if let val = self[.NICKNAME] {
            innerData["nickname"] = val
        }
        if let val = self[.PHONE_NUMBER] {
            innerData["phone"] = val
        }
        if let val = self[.EMAIL_ADDRESS] {
            innerData["email"] = val
        }
        if let val = self[.PROFIL_KEY] {
            innerData["profileKey"] = val
        }

        return innerData
    }

    func backupExportFullBackup() -> [AnyHashable: Any]? {
        let innerData = self.exportInnerDataPK()

        var rc: [AnyHashable: Any] = [:]

        for key in innerData.keys {
            if let value = innerData[key] {
                rc[key] = value
            }
        }
        return rc
    }

    func backupExportMiniBackup() -> [AnyHashable: Any]? {
        let innerData = self.exportInnerData()

        var rc: [AnyHashable: Any] = [:]

        for key in innerData.keys {
            if let value = innerData[key] {
                rc[key] = value
            }
        }
        return rc
    }

    func backupImportAccount(innerAccountInfo: [AnyHashable: Any]) {
        // Eigenen Account importieren
        self.entryTypeLocal = .hidden
        self.entryTypeServer = .meMyselfAndI

        self[.EMAIL_DOMAIN] = innerAccountInfo["companyDomain"] as? String
        self[.PHONE_NUMBER] = innerAccountInfo["phone"] as? String
        self[.EMAIL_ADDRESS] = innerAccountInfo["email"] as? String
        self[.PUBLIC_KEY] = innerAccountInfo["publicKey"] as? String ?? innerAccountInfo["publickKey"] as? String
        self[.NICKNAME] = innerAccountInfo["nickname"] as? String

        self[.PROFIL_KEY] = innerAccountInfo["profileKey"] as? String
        self[.ACCOUNT_ID] = innerAccountInfo["accountID"] as? String

        if self[.EMAIL_ADDRESS] != nil {
            DPAGApplicationFacade.preferences.didAskForCompanyEmail = true
        }
        if self[.PHONE_NUMBER] != nil {
            DPAGApplicationFacade.preferences.didAskForCompanyPhoneNumber = true
        }
    }

    func backupImportChat(singleChatBackupInfo: [AnyHashable: Any]) {
        if let lastMessageDate = singleChatBackupInfo["lastModifiedDate"] as? String {
            self.stream?.lastMessageDate = DPAGFormatter.date.date(from: lastMessageDate)
        }
        if (singleChatBackupInfo["confirmed"] as? String) == "false" {
            self.stream?.isConfirmed = NSNumber(value: false)
        }
        if self.isDeleted {
            self.stream?.wasDeleted = true
        }
    }

    func backupImport(innerContact: [AnyHashable: Any], blockedAccounts: [String], in localContext: NSManagedObjectContext) {
        // Für 2.0 Backup
        guard let guid = self.guid else {
            return
        }

        self[.ACCOUNT_ID] = innerContact["accountID"] as? String
        self[.FIRST_NAME] = innerContact["firstname"] as? String
        self[.LAST_NAME] = (innerContact["name"] as? String) ?? (innerContact["lastname"] as? String)

        self[.EMAIL_ADDRESS] = innerContact["domain"] as? String
        self[.EMAIL_DOMAIN] = innerContact["email"] as? String
        self[.DEPARTMENT] = innerContact["department"] as? String

        self[.PHONE_NUMBER] = innerContact["phone"] as? String
        self[.PUBLIC_KEY] = innerContact["publicKey"] as? String

        if let profilKey = innerContact["profileKey"] as? String, profilKey.isEmpty == false {
            self[.PROFIL_KEY] = profilKey
        }
        if let nickname = innerContact["nickname"] as? String, nickname.isEmpty == false {
            self[.NICKNAME] = nickname
        }
        self[.CREATED_AT] = Date()
        self[.STATUSMESSAGE] = ""

        if self.stream == nil {
            self.createNewStream(in: localContext)
        }

        self.setAttributeWithKey(SIMSContactIndexEntry.CONFIDENCE_STATE, andValue: NSNumber(value: DPAGConfidenceState.low.rawValue))

        if let mandant = innerContact["mandant"] as? String {
            self[.MANDANT_IDENT] = mandant
        }

        if let aesKey = innerContact["aesKey"] as? String, let recipientEncAesKey = innerContact["recipientEncAesKey"] as? String, let senderEncAesKey = innerContact["senderEncAesKey"] as? String {
            self[.AES_KEY] = aesKey
            self[.AES_KEY_SENDER_ENCRYPTED] = senderEncAesKey
            self[.AES_KEY_RECIPIENT_ENCRYPTED] = recipientEncAesKey
        }

        if let trustSate = innerContact["trustState"] as? String {
            switch trustSate {
            case "none":
                self.confidenceState = .none

            case "low":
                self.confidenceState = .low

            case "medium":
                self.confidenceState = .middle

            case "high":
                self.confidenceState = .high

            default:
                break
            }
        }
        
        if let deleted = innerContact["deleted"] as? String, deleted == "true" {
            self.entryTypeLocal = .hidden
            self[.IS_DELETED] = true
        } else {
            self.entryTypeLocal = (innerContact["visible"] as? String) == "false" ? .hidden : .privat
        }

        if let contactClass = innerContact["class"] as? String {
            self.setEntryTypeServer(entryTypeAsString: contactClass)
        } else {
            self.entryTypeServer = .privat
        }

        if let confirmed = innerContact["confirmed"] as? String {
            if confirmed == "true" || confirmed == "unblocked" {
                self.stream?.isConfirmed = true
                self[.IS_CONFIRMED] = true
            }
        }

        if blockedAccounts.contains(guid) {
            self[.IS_BLOCKED] = true
        }

        self.loadImageAndInfo()
    }

    private func setEntryTypeServer(entryTypeAsString: String) {
        switch entryTypeAsString {
        case "CompanyIndexEntry":
            if self[.IS_DELETED] {
                self.entryTypeServer = .company
            } else {
                self.entryTypeServer = .privat
            }
            
        case "DomainIndexEntry":
            if self[.IS_DELETED] {
                self.entryTypeServer = .email
            } else {
                self.entryTypeServer = .privat
            }
            
        case "OwnAccountEntry":
            self.entryTypeServer = .meMyselfAndI
            
        default:
            self.entryTypeServer = .privat
        }
    }

    func loadImageAndInfo() {
        guard let guid = self.guid else {
            return
        }

        if let profilKey = self[.PROFIL_KEY] {
            DPAGApplicationFacade.accountManager.loadAccountImage(accountGuid: guid) { rc, _, _ in

                do {
                    if let imageEncrypted = rc as? String {
                        let profilImage = try CryptoHelperDecrypter.decryptToString(encryptedString: imageEncrypted, withAesKeyDict: ["key": profilKey])

                        self[.IMAGE_DATA] = profilImage
                    }
                } catch {
                    DPAGLog(error)
                }
            }

            DPAGApplicationFacade.accountManager.loadAccountInfo(accountGuid: guid) { rc, _, _ in

                if let accountInfo = rc as? [AnyHashable: Any] {
                    if let innerAccountInfo = accountInfo[DPAGStrings.JSON.Account.OBJECT_KEY] as? [AnyHashable: Any] {
                        if let encryptedStatus = innerAccountInfo[DPAGStrings.JSON.Account.STATUS] as? String {
                            self[.STATUS_ENCRYPTED] = encryptedStatus
                        }

                        if let encryptedNickname = innerAccountInfo[DPAGStrings.JSON.Account.NICKNAME] as? String {
                            self[.NICKNAME_ENCRYPTED] = encryptedNickname
                        }
                    }
                }
            }
        }
    }

    class func decryptAddressCompanyData(data: String, aesKey: String) -> (Data?, [AnyHashable: Any]?) {
        guard let dataJSON = data.data(using: .utf8) else {
            return (nil, nil)
        }

        var dataContactJSON: String?
        var dataIVJSON: String?

        var jsonObj: [AnyHashable: Any]?
        do {
            jsonObj = try JSONSerialization.jsonObject(with: dataJSON, options: []) as? [AnyHashable: Any]

            dataContactJSON = jsonObj?["data"] as? String
            dataIVJSON = jsonObj?["iv"] as? String
        } catch {
            return (nil, nil)
        }

        guard let dataContact = dataContactJSON, let dataIV = dataIVJSON else {
            return (nil, nil)
        }

        let aesKeyDict = [
            "key": aesKey,
            "iv": dataIV
        ]

        do {
            let jsonData = try CryptoHelperDecrypter.decrypt(encryptedString: dataContact, withAesKeyDict: aesKeyDict)

            return (jsonData, jsonObj)
        } catch {
            return (nil, nil)
        }
    }

    func updateStatusForAllGroups(in localContext: NSManagedObjectContext) {
        if let contactGuid = self.guid {
            do {
                let allMembers = try SIMSGroupMember.findAll(in: localContext, with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSGroupMember.accountGuid), rightExpression: NSExpression(forConstantValue: contactGuid)), relationshipKeyPathsForPrefetching: ["groups"])

                for member in allMembers {
                    for group in member.groups ?? Set() {
                        group.updateStatus(in: localContext)
                    }
                }
            } catch {
                DPAGLog(error)
            }
        }
    }

    var serverChecksum: String? {
        get {
            self[.PRIVATE_INDEX_CHECKSUM]
        }
        set {
            self[.PRIVATE_INDEX_CHECKSUM] = newValue
        }
    }

    func exportInnerDataPK() -> [String: Any?] {
        var innerData: [String: Any?] = [:]

        switch self.entryTypeServer {
        case .privat:
            innerData["class"] = "PrivateIndexEntry"

        case .company:
            innerData["class"] = "CompanyIndexEntry"

        case .email:
            innerData["class"] = "DomainIndexEntry"

        case .meMyselfAndI:
            innerData["class"] = "OwnAccountEntry"
        }

        innerData["phone"] = self[.PHONE_NUMBER]
        innerData["profileKey"] = self[.PROFIL_KEY]
        innerData["nickname"] = self[.NICKNAME]

        innerData["mandant"] = self[.MANDANT_IDENT]

        innerData["accountID"] = self[.ACCOUNT_ID]
        innerData["firstname"] = self[.FIRST_NAME]
        innerData["name"] = self[.LAST_NAME]
        innerData["lastname"] = self[.LAST_NAME]
        innerData["email"] = self[.EMAIL_ADDRESS]
        innerData["domain"] = self[.EMAIL_DOMAIN]
        innerData["department"] = self[.DEPARTMENT]

        if self.guid == nil {
            // Kann eigentlich nicht auftreten
            if self.entryTypeServer == .meMyselfAndI {
                innerData["accountGuid"] = DPAGApplicationFacade.cache.account?.guid
            }
        } else {
            innerData["accountGuid"] = self.guid
        }

        if let publicKey = self[.PUBLIC_KEY] {
            innerData["publicKey"] = publicKey

            do {
                if let aesKeys = try self.aesKey(accountPublicKey: publicKey, createNew: false) {
                    innerData["aesKey"] = aesKeys.aesKey
                    innerData["recipientEncAesKey"] = aesKeys.recipientEncAesKey
                    innerData["senderEncAesKey"] = aesKeys.senderEncAesKey
                }
            } catch
            {}
        }

        switch self.confidenceState {
        case .none:
            innerData["trustState"] = "none"

        case .low:
            innerData["trustState"] = "low"

        case .middle:
            innerData["trustState"] = "medium"

        case .high:
            innerData["trustState"] = "high"
        }

        innerData["deleted"] = self.isDeleted ? "true" : "false"

        if !self.isConfirmed {
            innerData["confirmed"] = "unconfirmed"
        } else {
            if self[.IS_BLOCKED] {
                innerData["confirmed"] = "blocked"
            } else {
                innerData["confirmed"] = "unblocked"
            }
        }

        innerData["visible"] = (self.entryTypeLocal == .privat) ? "true" : "false"

        return innerData
    }

    func exportInnerData() -> [String: Any?] {
        var innerData: [String: Any?] = [:]

        switch self.entryTypeServer {
        case .privat:
            innerData["class"] = "PrivateIndexEntry"

        case .company:
            innerData["class"] = "CompanyIndexEntry"

        case .email:
            innerData["class"] = "DomainIndexEntry"

        case .meMyselfAndI:
            innerData["class"] = "OwnAccountEntry"
        }

        innerData["accountID"] = self[.ACCOUNT_ID]

        if self.guid == nil {
            // Kann eigentlich nicht auftreten
            if self.entryTypeServer == .meMyselfAndI {
                innerData["accountGuid"] = DPAGApplicationFacade.cache.account?.guid
            }
        } else {
            innerData["accountGuid"] = self.guid
        }

        innerData["publicKey"] = self[.PUBLIC_KEY]

        switch self.confidenceState {
        case .none:
            innerData["trustState"] = "none"

        case .low:
            innerData["trustState"] = "low"

        case .middle:
            innerData["trustState"] = "medium"

        case .high:
            innerData["trustState"] = "high"
        }

        innerData["deleted"] = self.isDeleted ? "true" : "false"

        // Anpassung an WebClient
        if !self.isConfirmed {
            innerData["confirmed"] = "unconfirmed"
        } else {
            if self[.IS_BLOCKED] {
                innerData["confirmed"] = "blocked"
            } else {
                innerData["confirmed"] = "unblocked"
            }
        }

        innerData["profileKey"] = self[.PROFIL_KEY]
        innerData["mandant"] = self[.MANDANT_IDENT]
        innerData["email"] = self[.EMAIL_ADDRESS]
        innerData["phone"] = self[.PHONE_NUMBER]
        innerData["name"] = self[.LAST_NAME]
        innerData["lastname"] = self[.LAST_NAME]
        innerData["firstname"] = self[.FIRST_NAME]
        innerData["department"] = self[.DEPARTMENT]
        innerData["nickname"] = self[.NICKNAME]
        innerData["state"] = self[.STATUSMESSAGE]
        innerData["image"] = self[.IMAGE_DATA]

        innerData["favorite"] = self[.IS_FAVORITE]

        innerData["domain"] = self[.EMAIL_DOMAIN]

        innerData["visible"] = (self.entryTypeLocal == .privat) ? "true" : "false"

        if self.entryTypeServer == .meMyselfAndI, self[.OOO_STATUS_STATUS_STATE] != nil {
            var innerDataOooStatus: [String: Any?] = [:]
            if let v = self[.OOO_STATUS_STATUS_TEXT] {
                innerDataOooStatus["statusText"] = v
            }
            if let v = self[.OOO_STATUS_STATUS_VALID] {
                innerDataOooStatus["statusValid"] = v
            }
            if let v = self[.OOO_STATUS_STATUS_STATE] {
                innerDataOooStatus["statusState"] = v
            }
            innerData["oooStatus"] = innerDataOooStatus
        }

        return innerData
    }

    func exportServer() throws -> [String: String]? {
        guard self.guid != nil else {
            return nil
        }

        let innerData = exportInnerData()

        /* {
         "PrivateIndexEntry":{
             "guid":"5001:{C64A625D-B1FA-41E9-A137-40B5E6AC7A11}",
             "key-data":"dheuh2382suwswswUHseuh==",
             "tempdevice":"3:{26277232-AAAA-AAAA-AAAA-878722878}",
             "key-data-tempdevice":"3432dwede3324eed==",
             "key-iv":"sgwzgw1672N==",
             "data":"73628437hdzedez378328ze7ddew7d74===",
             "signature":"ddhhdbhddhr384deded==",
             "data-checksum":"e3383838"
             "dateModified ":"2017-10-05 20:04:19.250+0200",
             "dateDeleted":"2017-10-05 20:04:19.250+0200"

         }
         */
        let accountCrypto = DPAGCryptoHelper.newAccountCrypto()

        if self[.PRIVATE_INDEX_GUID] == nil {
            // Wenn noch nicht angelegt
            self[.PRIVATE_INDEX_GUID] = DPAGFunctionsGlobal.uuid(prefix: .privateIndex)
        }

        let decAesKey = try CryptoHelperEncrypter.getNewRawAesKey()

        self[.PRIVATE_INDEX_KEY] = decAesKey

        if let ownPublicKey = try accountCrypto?.getPublicKeyFromPrivateKey() {
            let encAesKey = try CryptoHelperEncrypter.encrypt(string: decAesKey, withPublicKey: ownPublicKey)
            self[.PRIVATE_INDEX_KEY_DATA] = encAesKey
        }

        let ivData = try CryptoHelperEncrypter.getNewRawIV()

        self[.PRIVATE_INDEX_KEY_IV] = ivData

        if let innerJson = innerData.JSONString {
            let keyDict: [String: String] = ["key": decAesKey, "iv": ivData]
            let encryptedString = try CryptoHelperEncrypter.encrypt(string: innerJson, withAesKeyDict: keyDict)

            self[.PRIVATE_INDEX_DATA] = encryptedString

            let signature = try accountCrypto?.signDataRaw256(data: encryptedString)

            self[.PRIVATE_INDEX_SIGNATURE] = signature
        }
        let rc: [String: String] = ["guid": self[.PRIVATE_INDEX_GUID] ?? "",
                                    "key-data": self[.PRIVATE_INDEX_KEY_DATA] ?? "",
                                    "key-iv": self[.PRIVATE_INDEX_KEY_IV] ?? "",
                                    "data": self[.PRIVATE_INDEX_DATA] ?? "",
                                    "signature": self[.PRIVATE_INDEX_SIGNATURE] ?? ""]

        return rc
    }

    func importHelper(fromDict: [AnyHashable: Any], fromKey: String, toKey: AttrString) {
        if let value = fromDict[fromKey] as? String {
            self.setAttributeWithKey(toKey.rawValue, andValue: value)
        }
    }

    func importServer(innerContactInfo: [AnyHashable: Any], indexEntry: [AnyHashable: Any], in localContext: NSManagedObjectContext) {
        if let className = innerContactInfo["class"] as? String {
            switch className {
            case "PrivateIndexEntry":
                guard self.entryTypeServer == .privat else {
                    return
                }

            case "CompanyIndexEntry", "DomainIndexEntry":
                // do not update non-private-index contacts
                return

            case "OwnIndexEntry", "OwnAccountEntry":
                // synchronizing out-of-office state, department, first name, last name, …
                self.entryTypeServer = .meMyselfAndI

            default:
                break
            }
        }

        self.importHelper(fromDict: indexEntry, fromKey: "guid", toKey: SIMSContactIndexEntry.AttrString.PRIVATE_INDEX_GUID)
        self.importHelper(fromDict: indexEntry, fromKey: "key-data", toKey: SIMSContactIndexEntry.AttrString.PRIVATE_INDEX_KEY_DATA)
        self.importHelper(fromDict: indexEntry, fromKey: "key-iv", toKey: SIMSContactIndexEntry.AttrString.PRIVATE_INDEX_KEY_IV)
        self.importHelper(fromDict: indexEntry, fromKey: "data", toKey: SIMSContactIndexEntry.AttrString.PRIVATE_INDEX_DATA)
        self.importHelper(fromDict: indexEntry, fromKey: "signature", toKey: SIMSContactIndexEntry.AttrString.PRIVATE_INDEX_SIGNATURE)

        if let accountGuid = innerContactInfo["accountGuid"] as? String {
            self.guid = accountGuid
        }

        if let trustSate = innerContactInfo["trustState"] as? String {
            switch trustSate {
            case "none":
                self.confidenceState = .none

            case "low":
                self.confidenceState = .low

            case "medium":
                self.confidenceState = .middle

            case "high":
                self.confidenceState = .high
            default:
                break
            }
        }

        if self.confidenceState != .none {
            if self.stream == nil, self.entryTypeServer != .meMyselfAndI {
                self.createNewStream(in: localContext)
            }
        }

        if let v = innerContactInfo["deleted"] as? String, v == "true" {
            DPAGLog("Contact set as deleted: %@", guid ?? "")
            self[.IS_DELETED] = true
        } else {
            self[.IS_DELETED] = false
        }

        if let confirmed = innerContactInfo["confirmed"] as? String {
            if confirmed == "true" || confirmed == "unblocked" {
                self.stream?.isConfirmed = true
                self[.IS_CONFIRMED] = true
            }
            if confirmed == "unblocked" {
                self.entryTypeLocal = .privat
            }
        }

        self.importHelper(fromDict: innerContactInfo, fromKey: "accountID", toKey: SIMSContactIndexEntry.AttrString.ACCOUNT_ID)

        self.importHelper(fromDict: innerContactInfo, fromKey: "publicKey", toKey: SIMSContactIndexEntry.AttrString.PUBLIC_KEY)
        self.importHelper(fromDict: innerContactInfo, fromKey: "profileKey", toKey: SIMSContactIndexEntry.AttrString.PROFIL_KEY)
        self.importHelper(fromDict: innerContactInfo, fromKey: "mandant", toKey: SIMSContactIndexEntry.AttrString.MANDANT_IDENT)
        self.importHelper(fromDict: innerContactInfo, fromKey: "email", toKey: SIMSContactIndexEntry.AttrString.EMAIL_ADDRESS)
        self.importHelper(fromDict: innerContactInfo, fromKey: "phone", toKey: SIMSContactIndexEntry.AttrString.PHONE_NUMBER)
        
        self.importHelper(fromDict: innerContactInfo, fromKey: "lastname", toKey: SIMSContactIndexEntry.AttrString.LAST_NAME)
        self.importHelper(fromDict: innerContactInfo, fromKey: "name", toKey: SIMSContactIndexEntry.AttrString.LAST_NAME)
        self.importHelper(fromDict: innerContactInfo, fromKey: "firstname", toKey: SIMSContactIndexEntry.AttrString.FIRST_NAME)

        self.importHelper(fromDict: innerContactInfo, fromKey: "department", toKey: SIMSContactIndexEntry.AttrString.DEPARTMENT)
        self.importHelper(fromDict: innerContactInfo, fromKey: "nickname", toKey: SIMSContactIndexEntry.AttrString.NICKNAME)
        self.importHelper(fromDict: innerContactInfo, fromKey: "state", toKey: SIMSContactIndexEntry.AttrString.STATUSMESSAGE)
        self.importHelper(fromDict: innerContactInfo, fromKey: "image", toKey: SIMSContactIndexEntry.AttrString.IMAGE_DATA)
        self.importHelper(fromDict: innerContactInfo, fromKey: "favorite", toKey: SIMSContactIndexEntry.AttrString.IS_FAVORITE)

        self.importHelper(fromDict: innerContactInfo, fromKey: "domain", toKey: SIMSContactIndexEntry.AttrString.EMAIL_DOMAIN)

        if self.entryTypeServer == .meMyselfAndI {
            if let guid = self.guid, let contact = SIMSContactIndexEntry.findFirst(byGuid: guid, in: localContext), let newDomain = innerContactInfo["domain"] as? String {
                if newDomain != contact[.EMAIL_DOMAIN] {
                    contact[.EMAIL_DOMAIN] = newDomain
                    DPAGApplicationFacade.preferences.forceNeedsConfigSynchronization()
                    DPAGApplicationFacade.preferences.forceNeedsDomainIndexSynchronisation()
                }
            }
            if let oooStatus = innerContactInfo["oooStatus"] as? [String: Any] {
                self.importHelper(fromDict: oooStatus, fromKey: "statusText", toKey: SIMSContactIndexEntry.AttrString.OOO_STATUS_STATUS_TEXT)

                self.importHelper(fromDict: oooStatus, fromKey: "statusValid", toKey: SIMSContactIndexEntry.AttrString.OOO_STATUS_STATUS_VALID)

                self.importHelper(fromDict: oooStatus, fromKey: "statusState", toKey: SIMSContactIndexEntry.AttrString.OOO_STATUS_STATUS_STATE)
            }
            if let oldState = innerContactInfo["state"] as? String {
                DPAGApplicationFacade.statusWorker.updateStatus(oldState, broadCast: false)
            }
        }

        if let visible = innerContactInfo["visible"] as? String {
            if visible == "true" {
                self.entryTypeLocal = .privat
            } else {
                self.entryTypeLocal = .hidden
            }
        }

        // Ganz am Ende
        if let dataChecksum = indexEntry["data-checksum"] as? String {
            self[.PRIVATE_INDEX_CHECKSUM] = dataChecksum
        }
    }

    var privateIndexGuid: String? {
        self[.PRIVATE_INDEX_GUID]
    }

    var shouldSaveServer: Bool {
        if self.isSystemContact {
            return false
        }
        if self.entryTypeServer == .privat || self.entryTypeServer == .meMyselfAndI {
            return true
        }
        if self.entryTypeLocal == .privat {
            return true
        }
        return false
    }

    var phoneNumber: String? {
        self[.PHONE_NUMBER]
    }

    var emailDomain: String? {
        self[.EMAIL_DOMAIN]
    }

    var publicKey: String? {
        self[.PUBLIC_KEY]
    }

    var accountID: String? {
        self[.ACCOUNT_ID]
    }

    func setAccountId(_ accountID: String) {
        self[.ACCOUNT_ID] = accountID
    }

    func setOooStatus(_ state: String, statusText: String?, statusValid: String?) {
        self[.OOO_STATUS_STATUS_STATE] = state
        self[.OOO_STATUS_STATUS_TEXT] = statusText
        self[.OOO_STATUS_STATUS_VALID] = statusValid
    }

    private var searchableAttributes: [String?] {
        [
            self[.ACCOUNT_ID],
            self[.FIRST_NAME],
            self[.LAST_NAME],
            self[.PHONE_NUMBER],
            self[.EMAIL_ADDRESS],
            self[.DEPARTMENT],
            self[.NICKNAME]
        ]
    }

    private var ftsAttributes: DPAGDBFullTextHelper.FtsDatabaseContactAttributes {
        DPAGDBFullTextHelper.FtsDatabaseContactAttributes(accountGuid: self.guid ?? "???", accountID: self.accountID, firstName: self[.FIRST_NAME], lastName: self[.LAST_NAME], mandant: self[.MANDANT_IDENT], entryTypeServer: self.entryTypeServer.rawValue, confidenceState: self.confidenceState.rawValue, phoneNumber: self.phoneNumber, eMailAddress: self[.EMAIL_ADDRESS], department: self[.DEPARTMENT], nickName: self[.NICKNAME], status: self[.STATUSMESSAGE])
    }

    var ftsContact: FtsDatabaseContact? {
        guard let guid = self.guid, self.entryTypeServer != .privat || self.entryTypeLocal != .hidden else {
            return nil
        }

        guard let attributesJSONData = try? JSONEncoder().encode(self.ftsAttributes), let displayAttributes = String(data: attributesJSONData, encoding: .utf8) else {
            return nil
        }

        var mandant: String? = self[.MANDANT_IDENT]

        if DPAGApplicationFacade.preferences.mandantIdent == mandant {
            mandant = nil
        }

        guard let contactDBInfo = FtsDatabaseContact(accountGuid: guid, sortStringFirstName: self.sortString(personSortOrder: .givenName), sortStringLastName: self.sortString(personSortOrder: .familyName), displayAttributes: displayAttributes, searchAttributes: self.searchableAttributes.compactMap({ $0 }).joined(separator: " "), deleted: self[.IS_DELETED]) else {
            return nil
        }

        return contactDBInfo
    }

    private func sortString(personSortOrder: CNContactSortOrder) -> String {
        var retVal: String

        switch personSortOrder {
        case .familyName:
            retVal = (self[.LAST_NAME] ?? "") + (self[.FIRST_NAME] ?? "")
        case .givenName, .userDefault, .none:
            retVal = (self[.FIRST_NAME] ?? "") + (self[.LAST_NAME] ?? "")
        @unknown default:
            DPAGLog("Switch with unknown value: \(personSortOrder.rawValue)", level: .warning)
            retVal = ""
        }

        retVal += (self[.NICKNAME] ?? "") + (self.accountID ?? "")

        if let mandantIdent = self[.MANDANT_IDENT], mandantIdent != DPAGApplicationFacade.preferences.mandantIdent {
            retVal += mandantIdent
        }

        return retVal.lowercased()
    }

    func confirmAndConfide() {
        if self.confidenceState.rawValue < DPAGConfidenceState.middle.rawValue {
            self.confidenceState = .middle
            self.entryTypeLocal = .privat

            if let localContext = self.managedObjectContext {
                self.updateStatusForAllGroups(in: localContext)
            }
        }
        if (self.stream?.isConfirmed ?? true) == false {
            self.stream?.isConfirmed = NSNumber(value: true)
        }
    }
}
