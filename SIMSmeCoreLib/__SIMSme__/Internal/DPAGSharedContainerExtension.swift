//
//  DPAGSharedContainerLib.swift
//  SIMSmeCore
//
//  Created by Matthias Röhricht on 08.03.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

public struct DPAGSharedContainerConfig: Codable {
    public let keychainAccessGroupName: String
    public let groupID: String
    public let urlHttpService: String

    public init(keychainAccessGroupName: String, groupID: String, urlHttpService: String) {
        self.keychainAccessGroupName = keychainAccessGroupName
        self.groupID = groupID
        self.urlHttpService = urlHttpService
    }
}

public class DPAGSharedContainerExtensionBase {
    struct KeyContainer: Codable {
        let encryptedData: String
        let signedData: String
        let encAesKey: String
        let publicKey: String
    }

    func saveData(config: DPAGSharedContainerConfig, filename: String, crypto: CryptoHelperSimple) throws {
        // JSON erstellen
        if let infoData = try self.getCacheInfos() {
            // verschlüsseln
            if let encString = try self.encryptString(clearJSONString: infoData, crypto: crypto) {
                self.deleteData(config: config, filename: filename)
                // encString Speichern
                self.writeIntoSharedContainer(encJSONString: encString, config: config, filename: filename)
            }
        }
    }

    func convertData<T: Encodable>(containerData: T) throws -> String? {
        let data = try JSONEncoder().encode(containerData)

        let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)

        // Convert JSON back to Data
        let jsonData = try JSONSerialization.data(withJSONObject: json)

        // cast Data to String
        let resultNSString = String(data: jsonData, encoding: .utf8)

        return resultNSString
    }

    public func getCacheInfos() throws -> String? {
        nil
    }

    public func deleteData(config: DPAGSharedContainerConfig, filename: String) {
        let fileManager = FileManager.default
        if let containerUrl = fileManager.containerURL(forSecurityApplicationGroupIdentifier: config.groupID) {
            let fullPath = containerUrl.appendingPathComponent(filename)

            if fileManager.fileExists(atPath: fullPath.path) {
                do {
                    try fileManager.removeItem(atPath: fullPath.path)
                } catch let error as NSError {
                    DPAGLog(error, message: "ERROR DELETE SHAREDCONTAINER")
                }
            }
        }
    }

    private func writeIntoSharedContainer(encJSONString: String, config: DPAGSharedContainerConfig, filename: String) {
        let fileManager = FileManager.default
        if let containerUrl = fileManager.containerURL(forSecurityApplicationGroupIdentifier: config.groupID) {
            let newFile = containerUrl.appendingPathComponent(filename)
            do {
                try encJSONString.write(to: newFile, atomically: false, encoding: .utf8)
            } catch let error as NSError {
                DPAGLog(error, message: "ERROR WRITING SHAREDCONTAINER")
            }
        }
    }

    func encryptString(clearJSONString: String, crypto: CryptoHelperSimple) throws -> String? {
        // VERSCHLÜSSELN:
        let aesKeyNew: String = try CryptoHelperEncrypter.getNewRawAesKey()
        let aesKeyIV: String = try CryptoHelperEncrypter.getNewRawIV()

        var decAesKeyDic: [AnyHashable: Any] = [:]
        decAesKeyDic["key"] = aesKeyNew
        decAesKeyDic["iv"] = aesKeyIV

        // Verschlüsseln der Daten mit dec-AES-Key
        let encryptedData = try CryptoHelperEncrypter.encrypt(string: clearJSONString, withAesKeyDict: decAesKeyDic)

        // Erstellen der Signatur
        let signedData = try crypto.signData256(data: encryptedData)

        // Verschlüsseln des dec-AES-Key
        let pubKey = try crypto.getPublicKeyFromPrivateKey()

        guard let decAesKeyDicString = decAesKeyDic.JSONString else { return nil }

        let encAesKey = try CryptoHelperEncrypter.encrypt(string: decAesKeyDicString, withPublicKey: pubKey)

        let keyContainer = KeyContainer(encryptedData: encryptedData, signedData: signedData, encAesKey: encAesKey, publicKey: pubKey)

        return try self.convertData(containerData: keyContainer)
    }

    func readKeyContainer(config: DPAGSharedContainerConfig, filename: String) -> KeyContainer? {
        let fileManager = FileManager.default
        if let containerUrl = fileManager.containerURL(forSecurityApplicationGroupIdentifier: config.groupID) {
            let fileURL = containerUrl.appendingPathComponent(filename)

            var encJSONString: String
            do {
                encJSONString = try String(contentsOf: fileURL, encoding: .utf8)
                let newjsonData = encJSONString.data(using: .utf8)

                // Convert JSON Data back to KeyContainer Struct
                var decodedKeyContainer: KeyContainer?

                if let data = newjsonData {
                    decodedKeyContainer = try JSONDecoder().decode(KeyContainer.self, from: data)
                    return decodedKeyContainer
                }
            } catch {
                DPAGLog(error)
            }
        }
        return nil
    }

    func decryptKeyContainer(encKeyContainer: KeyContainer, config _: DPAGSharedContainerConfig, privateKey: String) throws -> Data? {
        var retVal: Data?
        let crypto = try CryptoHelperSimple(publicKey: encKeyContainer.publicKey, privateKey: privateKey)

        guard let decAesKey = try crypto.decryptAesKey(encryptedAeskey: encKeyContainer.encAesKey) else {
            return nil
        }

        if try CryptoHelperVerifier.verifyData256(data: encKeyContainer.encryptedData, withSignature: encKeyContainer.signedData, forPublicKey: encKeyContainer.publicKey) {
            if let decAesKeyData = decAesKey.data(using: .utf8), let AesKeyDic = try JSONSerialization.jsonObject(with: decAesKeyData) as? [AnyHashable: Any] {
                // Entschlüsseln der Daten mit dec-AES-Key
                let decryptData = try CryptoHelperDecrypter.decrypt(encryptedString: encKeyContainer.encryptedData, withAesKeyDict: AesKeyDic)
                let resultNSString = String(data: decryptData, encoding: .utf8)

                retVal = resultNSString?.data(using: .utf8)
            }
        }

        return retVal
    }
}

public class DPAGSharedContainerExtensionSending: DPAGSharedContainerExtensionBase {
    public let fileName = "sharedContainerExtensionSending.txt"
    static let itemKey = "private_key_shareExt"

    struct Colors: Codable {
        let companyColorMain: Int?
        let companyColorMainContrast: Int?
        let companyColorAction: Int?
        let companyColorActionContrast: Int?
        let companyColorSecLevelHigh: Int?
        let companyColorSecLevelHighContrast: Int?
        let companyColorSecLevelMed: Int?
        let companyColorSecLevelMedContrast: Int?
        let companyColorSecLevelLow: Int?
        let companyColorSecLevelLowContrast: Int?
    }

    struct Mandant: Codable {
        let ident: String
        let label: String
        let salt: String

        init(mandant: DPAGMandant) {
            self.ident = mandant.ident
            self.label = mandant.label
            self.salt = mandant.salt
        }
    }

    struct Preferences: Codable {
        let isBaMandant: Bool
        let isFCDPMandant: Bool
        let isWhiteLabelBuild: Bool
        let mandantIdent: String?
        let mandantLabel: String?
        let saltClient: String?

        let companyIndexName: String?
        let isCompanyManagedState: Bool

        let canSendMedia: Bool

        let sendNickname: Bool

        let sharedContainerConfig: DPAGSharedContainerConfig

        let imageOptionsForSending: DPAGImageOptions
        let videoOptionsForSending: DPAGVideoOptions
        let maxLengthForSentVideos: TimeInterval
        let maxFileSize: UInt64

        let contactsPrivateCount: Int
        let contactsCompanyCount: Int
        let contactsDomainCount: Int

        let contactsPrivateFullTextSearchEnabled: Bool
        let contactsCompanyFullTextSearchEnabled: Bool
        let contactsDomainFullTextSearchEnabled: Bool

        let lastRecentlyUsedContactsPrivate: [String]
        let lastRecentlyUsedContactsCompany: [String]
        let lastRecentlyUsedContactsDomain: [String]

        let mandanten: [Mandant]

        let colors: Colors
    }

    struct Account: Codable {
        let guid: String
        let isCompanyUserRestricted: Bool

        init(account: DPAGAccount) {
            self.guid = account.guid
            self.isCompanyUserRestricted = account.isCompanyUserRestricted
        }
    }

    struct Device: Codable {
        let guid: String
        let passToken: String
    }

    struct Contact: Codable {
        let guid: String
        let accountID: String?
        var publicKey: String?
        let firstName: String?
        let lastName: String?
        let nickName: String?
        let statusMessage: String?
        let mandantIdent: String

        let eMailAddress: String?
        let eMailDomain: String?
        let phoneNumber: String?

        let confidenceState: UInt
        let streamGuid: String?

        let isDeleted: Bool
        let isConfirmed: Bool
        let isBlocked: Bool
        let isReadOnly: Bool

        let entryTypeLocal: Int
        let entryTypeServer: Int

        let imageDataStr: String?
        let lastMessageDate: Date?

        let aesKeys: DPAGContactAesKeys?

        init(contact: DPAGContact) {
            self.guid = contact.guid
            self.accountID = contact.accountID
            self.publicKey = contact.publicKey
            self.firstName = contact.firstName
            self.lastName = contact.lastName
            self.nickName = contact.nickName
            self.statusMessage = contact.statusMessage
            self.mandantIdent = contact.mandantIdent

            self.eMailAddress = contact.eMailAddress
            self.eMailDomain = contact.eMailDomain
            self.phoneNumber = contact.phoneNumber

            self.isDeleted = contact.isDeleted
            self.isConfirmed = contact.isConfirmed
            self.isBlocked = contact.isBlocked
            self.isReadOnly = contact.isReadOnly

            self.confidenceState = contact.confidence.rawValue
            self.streamGuid = contact.streamGuid

            self.entryTypeLocal = contact.entryTypeLocal.rawValue
            self.entryTypeServer = contact.entryTypeServer.rawValue

            self.imageDataStr = nil
            self.lastMessageDate = contact.lastMessageDate

            self.aesKeys = contact.aesKeys
        }
    }

    struct Chat: Codable {
        let guid: String
        let accountID: String?
        let publicKey: String?
        let firstName: String?
        let lastName: String?
        let nickName: String?
        let statusMessage: String?
        let mandantIdent: String

        let eMailAddress: String?
        let eMailDomain: String?
        let phoneNumber: String?

        let confidenceState: UInt
        let streamGuid: String?

        let isDeleted: Bool
        let isConfirmed: Bool
        let isBlocked: Bool
        let isReadOnly: Bool

        let entryTypeLocal: Int
        let entryTypeServer: Int

        let imageDataStr: String?
        let lastMessageDate: Date?

        let aesKeys: DPAGContactAesKeys?

        init(contact: DPAGContact) {
            self.guid = contact.guid
            self.accountID = contact.accountID
            self.publicKey = contact.publicKey
            self.firstName = contact.firstName
            self.lastName = contact.lastName
            self.nickName = contact.nickName
            self.statusMessage = contact.statusMessage
            self.mandantIdent = contact.mandantIdent

            self.eMailAddress = contact.eMailAddress
            self.eMailDomain = contact.eMailDomain
            self.phoneNumber = contact.phoneNumber

            self.confidenceState = contact.confidence.rawValue
            self.streamGuid = contact.streamGuid

            self.isDeleted = contact.isDeleted
            self.isConfirmed = contact.isConfirmed
            self.isBlocked = contact.isBlocked
            self.isReadOnly = contact.isReadOnly

            self.entryTypeLocal = contact.entryTypeLocal.rawValue
            self.entryTypeServer = contact.entryTypeServer.rawValue

            self.imageDataStr = (contact.imageDataStr?.count ?? 128_000) > 127_000 ? nil : contact.imageDataStr
            self.lastMessageDate = contact.lastMessageDate

            self.aesKeys = contact.aesKeys
        }
    }

    struct Group: Codable {
        let guid: String
        let name: String?
        let countMembers: Int
        let guidOwner: String?
        let groupType: Int
        let isDeleted: Bool
        let memberNames: String?
        let confidenceState: UInt
        let isConfirmed: Bool
        let isReadOnly: Bool
        let aesKey: String?
        let lastMessageDate: Date?
        let imageData: String?

        init(group: DPAGGroup) {
            self.guid = group.guid
            self.name = group.name
            self.countMembers = group.countMembers
            self.guidOwner = group.guidOwner
            self.groupType = group.groupType.rawValue
            self.isDeleted = group.isDeleted
            self.memberNames = group.memberNames
            self.confidenceState = group.confidenceState.rawValue
            self.isConfirmed = group.isConfirmed
            self.isReadOnly = group.isReadOnly
            self.aesKey = group.aesKey
            self.lastMessageDate = group.lastMessageDate

            let imageData = DPAGHelperEx.encodedImage(forGroupGuid: group.guid)
            self.imageData = (imageData?.count ?? 128_000) > 127_000 ? nil : imageData
        }
    }

    struct ContactStream: Codable {
        let guid: String
        let contactGuid: String
    }

    public struct Container: Codable {
        let preferences: Preferences
        let account: Account
        let device: Device
        let contacts: [Contact]
        let contactStreams: [ContactStream]
        let groups: [Group]
        let chats: [Chat]
    }

    override public init() {
        super.init()
    }

    public func readfile(config: DPAGSharedContainerConfig) throws -> Container? {
        // encString Lesen
        // encString zum KeyContainer
        if let encKeyContainer = self.readKeyContainer(config: config, filename: self.fileName) {
            // enc KeyContainer entschlüsseln
            if let privateKey = self.getShareExtKey(config: config), let decContainer = try self.decryptKeyContainer(encKeyContainer: encKeyContainer, config: config, privateKey: privateKey) {
                do {
                    return try JSONDecoder().decode(Container.self, from: decContainer)
                } catch {
                    DPAGLog(error)
                }
            }
        }
        return nil
    }

    public func getShareExtKey(config: DPAGSharedContainerConfig) -> String? {
        let queryLoad: [String: AnyObject] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: DPAGSharedContainerExtensionSending.itemKey as AnyObject,
            kSecReturnData as String: kCFBooleanTrue,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrAccessGroup as String: config.keychainAccessGroupName as AnyObject
        ]

        var result: AnyObject?

        let resultCodeLoad = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(queryLoad as CFDictionary, UnsafeMutablePointer($0))
        }

        if resultCodeLoad == noErr {
            if let result = result as? Data, let keyValue = String(data: result, encoding: .utf8) {
                // Found successfully
                return keyValue
            }
        } else {
            DPAGLog("Error loading from Keychain: \(resultCodeLoad)")
        }
        return nil
    }
}

public class DPAGSharedContainerExtension: DPAGSharedContainerExtensionBase {
    public let fileName = "file.txt"
    static let itemKey = "private_key_pushPreview"

    struct SharedContainer: Codable {
        let account: Account
        var contacts: [String: Contact]
        var groups: [String: Group]
    }

    struct Contact: Codable {
        let guid: String
        let name: String
        let confidenceState: UInt
    }

    struct GroupPreference: Codable {
        let name: String
        let aesKey: String
    }

    struct Group: Codable {
        let guid: String
        let groupPreference: GroupPreference
    }

    struct AccountPreference: Codable {
        let httpUsername: String
        let backgroundAccessToken: String
        let publicKey: String
    }

    struct Account: Codable {
        let guid: String
        let accountPreference: AccountPreference

        init(guid: String, accountPreference: AccountPreference) {
            self.guid = guid
            self.accountPreference = accountPreference
        }
    }

    override init() {
        super.init()
    }

    func readfile(config: DPAGSharedContainerConfig) throws -> SharedContainer? {
        // encString Lesen
        // encString zum KeyContainer
        if let encKeyContainer = self.readKeyContainer(config: config, filename: self.fileName) {
            // enc KeyContainer entschlüsseln
            if let privateKey = self.getPushPreviewKey(config: config), let decsharedContainer = try self.decryptKeyContainer(encKeyContainer: encKeyContainer, config: config, privateKey: privateKey) {
                do {
                    return try JSONDecoder().decode(SharedContainer.self, from: decsharedContainer)
                } catch {
                    DPAGLog(error)
                }
            }
        }
        return nil
    }

    func getPushPreviewKey(config: DPAGSharedContainerConfig) -> String? {
        let queryLoad: [String: AnyObject] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: DPAGSharedContainerExtension.itemKey as AnyObject,
            kSecReturnData as String: kCFBooleanTrue,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrAccessGroup as String: config.keychainAccessGroupName as AnyObject
        ]

        var result: AnyObject?

        let resultCodeLoad = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(queryLoad as CFDictionary, UnsafeMutablePointer($0))
        }

        if resultCodeLoad == noErr {
            if let result = result as? Data, let keyValue = String(data: result, encoding: .utf8) {
                // Found successfully
                return keyValue
            }
        } else {
            DPAGLog("Error loading from Keychain: \(resultCodeLoad)")
        }
        return nil
    }
}
