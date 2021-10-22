//
//  DPAGApplicationFacade.accountManager.swift
// ginlo
//
//  Created by RBU on 04/11/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import NSHash
import UIKit

enum DPAGErrorAccountManager: Error {
    case errDatabase
}

struct DPAGNewAccountConfiguration {
    let sharedSecret: String
    let deviceGuid: String
    let deviceToken: String
    let keyGuid: String
    let pubKeyDevice: String?
    let deviceCrypto: CryptoHelper?
    let accountCrypto: CryptoHelperCreate
    let decPrivateKeyAccount: String?
    let deviceName: String
    let publicKeyFingerprintDevice: String?
    let encAesKey: String?
    let decAesKey: String?
    let phoneNumber: String?
    let emailAddress: String?
    let emailDomain: String?
    let publicKeyAccount: String?
    let cockpitToken: String?
    let cockpitData: String?

    init(phoneNumber: String?, emailAddress: String?, emailDomain: String?, cockpitToken: String?, cockpitData: String?, password: String) throws {
        self.phoneNumber = phoneNumber
        self.emailAddress = emailAddress
        self.emailDomain = emailDomain
        self.cockpitToken = cockpitToken
        self.cockpitData = cockpitData
        self.sharedSecret = DPAGFunctionsGlobal.uuid()
        self.deviceGuid = DPAGFunctionsGlobal.uuid(prefix: .device)
        self.deviceToken = DPAGFunctionsGlobal.uuid()
        self.keyGuid = DPAGFunctionsGlobal.uuid(prefix: .key)
        self.accountCrypto = try CryptoHelperCreate()
        self.deviceCrypto = CryptoHelper.sharedInstance
        try self.deviceCrypto?.generateKeyPairAndSaveitToKeyChain()
        try self.deviceCrypto?.encryptPrivateKey(password: password)
        DPAGApplicationFacade.preferences.passwordSetAt = Date()
        self.deviceName = UIDevice.current.name
        self.decAesKey = try CryptoHelperEncrypter.getNewAesKey()
        try DPAGFileHelper.setFolderRightsForBackup(allowBackupFlag: false)
        if let pubKeyDevice = self.deviceCrypto?.publicKey, let decAesKey = self.decAesKey {
            self.pubKeyDevice = pubKeyDevice
            self.publicKeyAccount = self.accountCrypto.publicKey
            self.decPrivateKeyAccount = try self.accountCrypto.getDecryptedPrivateKey()
            self.publicKeyFingerprintDevice = pubKeyDevice.sha1()
            self.encAesKey = try CryptoHelperEncrypter.encrypt(string: decAesKey, withPublicKey: pubKeyDevice)
            DPAGApplicationFacade.preferences.clearBootStrapping()
            _ = DPAGApplicationFacade.preferences.savePasswordToUsedPasswords(password, accountPublicKey: pubKeyDevice)
        } else {
            self.pubKeyDevice = nil
            self.publicKeyAccount = nil
            self.decPrivateKeyAccount = nil
            self.publicKeyFingerprintDevice = nil
            self.encAesKey = nil
        }
    }
}

public protocol DPAGAccountManagerProtocol: AnyObject {
    func getOsName() -> String

    func resetDatabase()
    func resetAccount()
    func deleteAccount(force: Bool, withResponse responseBlock: @escaping DPAGServiceResponseBlock)

    func createAccount(password: String, phoneNumber: String?, emailAddress: String?, emailDomain: String?, endpoint: String?, responseBlock: @escaping DPAGServiceResponseBlock) -> String

    // Automatische Registrierung MDM
    func createAutomaticAccount(password: String, eMailAddress: String, cockpitToken: String, cockpitData: String, responseBlock: @escaping DPAGServiceResponseBlock) throws -> String

    func loadAccountImage(accountGuid: String, response: DPAGServiceResponseBlock)
    func loadAccountInfo(accountGuid: String, response: DPAGServiceResponseBlock)

    func isConfirmationValid(code: String, responseBlock: @escaping DPAGServiceResponseBlock)
    func confirmAccount(code: String, responseBlock: @escaping DPAGServiceResponseBlock)

    func ensureCompanyRecoveryPassword() throws
    func hasCompanyRecoveryPasswordFile() throws -> Bool
    func decryptCompanyRecoveryPasswordFile(password: String) throws -> Bool

    func hasSimsmeRecoveryPasswordFile() throws -> Bool
    func decryptSimsmeRecoveryPasswordFile(password: String) throws -> Bool

    func ensureAccountProfilKey() throws

    func initiate(nickName: String, firstName: String?, lastName: String?)
    func save(nickName: String)
    func save(firstName: String, lastName: String)
    func save(eMailAddress: String, eMailDomain: String?)
    func confirmCompanyEmailStatus() -> String?
    func confirmCompanyPhoneNumberStatus() -> String?
    func save(phoneNumber: String)
    func updateAccountID(accountGuid: String)

    func updateConfirmedIdentitiesWithServer(cacheVersionConfirmedIdentitiesServer: String)

    func removeConfirmedEmailAddress(withResponse responseBlock: @escaping DPAGServiceResponseBlock)
    func removeConfirmedPhoneNumber(withResponse responseBlock: @escaping DPAGServiceResponseBlock)
    func removeConfirmedEmailAddressDB() throws
    func removeConfirmedPhoneNumberDB() throws

    func hasAccount() -> Bool
    func isFirstRunOrBrokenSetup() -> Bool
    func accountStateSetup() -> DPAGAccountState
    
    func autoConfirmAccount(accountID: String)
}

class DPAGAccountManager: NSObject, DPAGAccountManagerProtocol {
    var createAccountGuid: String?
    let accountDAO: AccountDAOProtocol = AccountDAO()

    func accountStateSetup() -> DPAGAccountState {
        accountDAO.getAccountState() ?? DPAGAccountState.unknown
    }

    func autoConfirmAccount(accountID: String) {
        accountDAO.confirmAccount(accountID: accountID)
    }
    
    func isFirstRunOrBrokenSetup() -> Bool {
        var isFirstRun = accountDAO.isDeviceFirstRun() ?? true
        if isFirstRun == false, let deviceCrypto = CryptoHelper.sharedInstance, deviceCrypto.hasPrivateKey(), ((try? deviceCrypto.aesKeyFileExists(forPasswordProtectedKey: true)) ?? false) == false {
            DPAGLog("Has private key, but the PBKDF key file is missing. Most probable, the app settings were not properly restored from backup")
            isFirstRun = true
        }
        return isFirstRun
    }

    func hasAccount() -> Bool {
        accountDAO.hasAccount() ?? false
    }

    func getOsName() -> String {
        let device = UIDevice.current
        let osName = device.systemName + " " + device.systemVersion
        return osName
    }

    func resetDatabase() {
        do {
            try DPAGApplicationFacade.persistance.deleteAllObjects()
        } catch {
            DPAGLog(error)
        }
    }

    func resetAccount() {
        DPAGApplicationFacade.preferences.reset()
        do {
            try DPAGApplicationFacade.persistance.deleteAllObjects()
        } catch {
            DPAGLog(error, message: "Error database cleanup")
        }
        DPAGApplicationFacade.cache.deleteObjectCache()
        DPAGApplicationFacade.preferences.deleteUsedHashedPasswords()
        DPAGApplicationFacade.preferences.deletePreferencesAesKey()
        DPAGHelperEx.clearDocumentsFolder()
        if let helper = CryptoHelper.sharedInstance {
            helper.resetCryptoHelper()
            helper.deleteDecryptedPrivateKeyinKeyChain()
            helper.deleteEncryptedPrivateKeyinKeyChain()
            helper.deleteDecryptedPrivateKeyForTouchID()
        }
        DPAGApplicationFacade.sharedContainer.deleteData(config: DPAGApplicationFacade.preferences.sharedContainerConfig, filename: DPAGApplicationFacade.sharedContainer.fileName)
        DPAGApplicationFacade.sharedContainerSending.deleteData(config: DPAGApplicationFacade.preferences.sharedContainerConfig, filename: DPAGApplicationFacade.sharedContainerSending.fileName)
    }

    func createAccount(password: String, phoneNumber: String?, emailAddress: String?, emailDomain: String?, endpoint: String?, responseBlock: @escaping DPAGServiceResponseBlock) -> String {
        if DPAGHelperEx.isNetworkReachable() == false {
            responseBlock(nil, nil, "service.networkFailure")
        }
        self.resetAccount()
        if let endpoint = endpoint {
            EndpointDAO.save(endpoint: endpoint)
        }
        let createAccountGuid = DPAGFunctionsGlobal.uuid(prefix: .account)
        self.createAccountGuid = createAccountGuid
        self.performBlockInBackground { [weak self] in
            do {
                try self?.createConfiguration(password: password, phoneNumber: phoneNumber, emailAddress: emailAddress, emailDomain: emailDomain, responseBlock: responseBlock)
            } catch {
                DPAGLog(error)
                responseBlock(nil, nil, error.localizedDescription)
            }
        }
        return createAccountGuid
    }

    private func createConfiguration(password: String, phoneNumber: String?, emailAddress: String?, emailDomain: String?, responseBlock: @escaping DPAGServiceResponseBlock) throws {
        if DPAGHelperEx.isNetworkReachable() == false {
            responseBlock(nil, nil, "service.networkFailure")
        }
        let config = try DPAGNewAccountConfiguration(phoneNumber: phoneNumber, emailAddress: emailAddress, emailDomain: emailDomain, cockpitToken: nil, cockpitData: nil, password: password)
        try self.createEntitiesWithConfig(config, responseBlock: responseBlock)
    }

    func createAutomaticAccount(password: String, eMailAddress: String, cockpitToken: String, cockpitData: String, responseBlock: @escaping DPAGServiceResponseBlock) throws -> String {
        if DPAGHelperEx.isNetworkReachable() == false {
            responseBlock(nil, nil, "service.networkFailure")
        }
        self.resetAccount()
        let createAccountGuid = DPAGFunctionsGlobal.uuid(prefix: .account)
        self.createAccountGuid = createAccountGuid
        let config = try DPAGNewAccountConfiguration(phoneNumber: nil, emailAddress: eMailAddress, emailDomain: nil, cockpitToken: cockpitToken, cockpitData: cockpitData, password: password)
        try self.createEntitiesWithConfig(config, responseBlock: responseBlock)
        return createAccountGuid
    }

    private func createEntitiesWithConfig(_ config: DPAGNewAccountConfiguration, responseBlock: @escaping DPAGServiceResponseBlock) throws {
        var keyDict: [String: [String: Any]] = [:]
        var accountDict: [String: [String: Any]] = [:]
        let accountGuid = self.createAccountGuid ?? DPAGFunctionsGlobal.uuid(prefix: .account)
        let deviceGuid = config.deviceGuid
        let keyGuid = config.keyGuid
        let signData = try config.accountCrypto.signData(data: config.publicKeyFingerprintDevice ?? "") // to pass
        let accountConfig = try accountDAO.createAccount(config: config, accountGuid: accountGuid, signData: signData)
        DPAGApplicationFacade.statusWorker.initStatus()
        keyDict = [ // To be build outside the db call
            DPAGStrings.JSON.Key.OBJECT_KEY: [
                DPAGStrings.JSON.Key.GUID: keyGuid,
                DPAGStrings.JSON.Key.ACCOUNT_GUID: accountGuid,
                DPAGStrings.JSON.Key.DEVICE_GUID: deviceGuid,
                DPAGStrings.JSON.Key.DATA: try config.deviceCrypto?.encryptWithPrivateKey(string: config.decAesKey ?? " ") ?? "???" // To add later
            ]
        ]
        var innerAccountDict: [String: Any] = [:]
        innerAccountDict[DPAGStrings.JSON.Account.GUID] = accountGuid
        innerAccountDict[DPAGStrings.JSON.Account.PUBLIC_KEY] = config.publicKeyAccount?.replacingOccurrences(of: "RSAPublicKey", with: "RSAKeyValue") ?? ""
        innerAccountDict[DPAGStrings.JSON.Account.KEY_GUID] = keyGuid
        innerAccountDict[DPAGStrings.JSON.Account.DATA] = accountConfig.accountDictEnc
        if let phone = config.phoneNumber {
            innerAccountDict[DPAGStrings.JSON.Account.PHONE] = phone
        }
        if let email = config.emailAddress {
            innerAccountDict[DPAGStrings.JSON.Account.EMAIL] = email
        }
        accountDict = [
            DPAGStrings.JSON.Account.OBJECT_KEY: innerAccountDict
        ]
        guard let jsonMetadata = [keyDict, accountDict, accountConfig.deviceDict].JSONString else {
            // TODO: clean up database
            responseBlock(nil, nil, "service.ERR-0001")
            return
        }
        DPAGApplicationFacade.model.update(with: nil)
        DPAGApplicationFacade.preferences[.kNotificationNicknameEnabled] = DPAGPreferences.kValueNotificationEnabled
        if let cockpitToken = config.cockpitToken, let cockpitData = config.cockpitData {
            // Account mit eMail + AutoToken anlegen
            try DPAGApplicationFacade.server.createAutomaticAccount(metadata: jsonMetadata, cockpitToken: cockpitToken, cockpitData: cockpitData, responseBlock: responseBlock)
        } else {
            // Account mit Telefonnummer anlegen
            try DPAGApplicationFacade.server.createAccount(metadata: jsonMetadata, responseBlock: responseBlock)
        }
    }

    func confirmAccount(code: String, responseBlock: @escaping DPAGServiceResponseBlock) {
        if DPAGHelperEx.isNetworkReachable() == false {
            responseBlock(nil, nil, "service.networkFailure")
        }
        // Default ON
        DPAGApplicationFacade.preferences.simsmeRecoveryEnabled = true
        DPAGApplicationFacade.server.confirmAccount(code: code) { [weak self] responseObject, errorCode, errorMessage in
            if errorMessage != nil {
                responseBlock(nil, errorCode, errorMessage)
            } else if let accountID = self?.validateResponseForAccountConfirmation(dictionary: responseObject as? [AnyHashable: Any]) {
                self?.accountDAO.confirmAccount(accountID: accountID)
                DPAGApplicationFacade.model.update(with: nil)
                responseBlock(responseObject, errorCode, errorMessage)
            } else {
                responseBlock(nil, "service.tryAgainLater", "service.tryAgainLater")
            }
        }
    }

    func isConfirmationValid(code: String, responseBlock: @escaping DPAGServiceResponseBlock) {
        if DPAGHelperEx.isNetworkReachable() == false {
            responseBlock(nil, nil, "service.networkFailure")
        }
        DPAGApplicationFacade.server.isConfirmationValid(code: code) { responseObject, errorCode, errorMessage in
            if errorMessage != nil {
                responseBlock(nil, errorCode, errorMessage)
            } else {
                responseBlock(responseObject, errorCode, errorMessage)
            }
        }
    }

    func deleteAccount(force: Bool, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        if DPAGHelperEx.isNetworkReachable() == false {
            responseBlock(nil, nil, "service.networkFailure")
        }
        DPAGApplicationFacade.server.deleteAccount { responseObject, errorCode, errorMessage in
            if force == false && errorMessage != nil {
                responseBlock(nil, errorCode, errorMessage)
            } else if force || self.validateResponseForAccountDeletion(accountGuid: (responseObject as? [String])?.first) {
                OperationQueue.main.addOperation {
                    NotificationCenter.default.post(name: DPAGStrings.Notification.Application.SECURITY_RESET_APP, object: nil)
                    responseBlock(responseObject, nil, nil)
                }
            } else {
                responseBlock(nil, "service.tryAgainLater", "service.tryAgainLater")
            }
        }
    }

    private func validateResponseForAccountDeletion(accountGuid: String?) -> Bool {
        accountGuid != nil && accountGuid == DPAGApplicationFacade.cache.account?.guid
    }

    func validateResponseForAccountConfirmation(dictionary: [AnyHashable: Any]?) -> String? {
        var accountID: String?
        if let dictAccount = dictionary?[DPAGStrings.JSON.Account.OBJECT_KEY] as? [AnyHashable: Any], DPAGApplicationFacade.persistance.findAccount(forDictionary: dictAccount) != nil {
            accountID = dictAccount[DPAGStrings.JSON.Account.ACCOUNT_ID] as? String
        }
        return accountID
    }

    func ensureCompanyRecoveryPassword() throws {
        if !DPAGApplicationFacade.preferences.isRecoveryDisabled {
            try DPAGApplicationFacade.preferences.ensureRecoveryBlobs()
        }
    }

    func hasCompanyRecoveryPasswordFile() throws -> Bool {
        guard let companyPrivateKeyBackupPath = try CryptoHelper.sharedInstance?.companyPrivateKeyBackupPath() else { return false }
        if FileManager.default.fileExists(atPath: companyPrivateKeyBackupPath.path) {
            return true
        }
        return false
    }

    func decryptCompanyRecoveryPasswordFile(password: String) throws -> Bool {
        if (try hasCompanyRecoveryPasswordFile()) == false {
            return false
        }
        return try CryptoHelper.sharedInstance?.decryptBackupPrivateKey(password: password, backupMode: .fullBackup) ?? false
    }

    func hasSimsmeRecoveryPasswordFile() throws -> Bool {
        guard let simsmePrivateKeyBackupPath = try CryptoHelper.sharedInstance?.simsmeRecoveryPrivateKeyBackupPath() else { return false }
        if FileManager.default.fileExists(atPath: simsmePrivateKeyBackupPath.path) {
            return true
        }
        return false
    }

    func decryptSimsmeRecoveryPasswordFile(password: String) throws -> Bool {
        if (try hasSimsmeRecoveryPasswordFile()) == false {
            return false
        }
        return try CryptoHelper.sharedInstance?.decryptBackupPrivateKey(password: password, backupMode: .miniBackup) ?? false
    }

    func loadAccountImage(accountGuid: String, response: DPAGServiceResponseBlock) {
        var rc: String?
        var errorCodeBlock: String?
        var errorMessageBlock: String?
        let semaphore = DispatchSemaphore(value: 0)
        let responseBlock: DPAGServiceResponseBlock = { responseObject, errorCode, errorMessage in
            defer {
                semaphore.signal()
            }
            if let errorMessage = errorMessage {
                // Fehlermeldung loggen und weiterleiten
                DPAGLog(errorMessage)
                if errorMessage != "service.ERR-0007" {
                    errorCodeBlock = errorCode
                    errorMessageBlock = errorMessage
                }
            } else if let arr = responseObject as? [Any], arr.count > 0 {
                rc = arr.first as? String
            }
        }
        DPAGApplicationFacade.server.getAccountImage(guid: accountGuid, withResponse: responseBlock)
        _ = semaphore.wait(wallTimeout: DispatchWallTime.distantFuture)
        response(rc, errorCodeBlock, errorMessageBlock)
    }

    func loadAccountInfo(accountGuid: String, response: DPAGServiceResponseBlock) {
        var rc: [AnyHashable: Any]?
        var errorCodeBlock: String?
        var errorMessageBlock: String?
        let semaphore = DispatchSemaphore(value: 0)
        let responseBlock: DPAGServiceResponseBlock = { responseObject, errorCode, errorMessage in
            defer {
                semaphore.signal()
            }
            if let errorMessage = errorMessage {
                // Fehlermeldung loggen und weiterleiten
                DPAGLog(errorMessage)
                if errorMessage != "service.ERR-0007" {
                    errorCodeBlock = errorCode
                    errorMessageBlock = errorMessage
                }
            } else if let dict = responseObject as? [AnyHashable: Any] {
                rc = dict
            }
        }
        DPAGApplicationFacade.server.getAccountInfo(guid: accountGuid, withProfile: true, withTempDevice: false, withResponse: responseBlock)
        _ = semaphore.wait(wallTimeout: DispatchWallTime.distantFuture)
        response(rc, errorCodeBlock, errorMessageBlock)
    }

    func save(nickName: String) {
        if let accountGuid = accountDAO.saveNickName(nickName),
            let contact = DPAGApplicationFacade.cache.contact(for: accountGuid) {
            if contact.hasImage == false {
                contact.removeCachedImages()
            }
        }
    }

    func ensureAccountProfilKey() throws {
        try accountDAO.ensureAccountProfilKey()
    }

    func initiate(nickName: String, firstName: String?, lastName: String?) {
        if let accountGuid = accountDAO.initAccountNames(nickName: nickName, firstName: firstName, lastName: lastName) {
            DPAGApplicationFacade.statusWorker.initStatus()
            DPAGApplicationFacade.cache.contact(for: accountGuid)?.removeCachedImages()
        }
    }

    func save(firstName: String, lastName: String) {
        accountDAO.save(firstName: firstName, lastName: lastName)
    }

    func confirmCompanyEmailStatus() -> String? {
        let rc = accountDAO.confirmCompanyEmailStatus()
        if rc != nil {
            DPAGApplicationFacade.preferences.validationEmailAddress = nil
            DPAGApplicationFacade.preferences.validationEmailDomain = nil
        }
        NotificationCenter.default.post(name: DPAGStrings.Notification.Account.CONFIRMED_IDENTITIES_CHANGED, object: nil)
        return rc
    }

    func save(eMailAddress: String, eMailDomain: String?) {
        let accountGuid = accountDAO.save(eMailAddress: eMailAddress, eMailDomain: eMailDomain)
        if accountGuid != nil {
            DPAGApplicationFacade.preferences.validationEmailAddress = eMailAddress
            DPAGApplicationFacade.preferences.validationEmailDomain = eMailDomain
        }
        NotificationCenter.default.post(name: DPAGStrings.Notification.Account.CONFIRMED_IDENTITIES_CHANGED, object: nil)
    }

    func confirmCompanyPhoneNumberStatus() -> String? {
        let rc = accountDAO.confirmCompanyPhoneNumberStatus()
        if rc != nil {
            DPAGApplicationFacade.preferences.validationPhoneNumber = nil
        }
        NotificationCenter.default.post(name: DPAGStrings.Notification.Account.CONFIRMED_IDENTITIES_CHANGED, object: nil)
        return rc
    }

    func save(phoneNumber: String) {
        let accountGuid = accountDAO.save(phoneNumber: phoneNumber)
        if accountGuid != nil {
            DPAGApplicationFacade.preferences.validationPhoneNumber = phoneNumber
        }
        NotificationCenter.default.post(name: DPAGStrings.Notification.Account.CONFIRMED_IDENTITIES_CHANGED, object: nil)
    }

    func updateAccountID(accountGuid: String) {
        DPAGApplicationFacade.server.getAccountInfo(guid: accountGuid, withProfile: false, withTempDevice: false) { [weak self] responseObject, _, errorMessage in
            if errorMessage == nil, let responseDict = responseObject as? [AnyHashable: Any], let dictAccountInfo = responseDict[DPAGStrings.JSON.Account.OBJECT_KEY] as? [AnyHashable: Any], let accountID = dictAccountInfo[SIMS_ACCOUNT_ID] as? String {
                self?.accountDAO.updateContactWithAccountID(accountGuid: accountGuid, accountID: accountID)
            }
        }
    }

    func updateConfirmedIdentitiesWithServer(cacheVersionConfirmedIdentitiesServer: String) {
        if DPAGHelperEx.isNetworkReachable() == false {
            return
        }
        DPAGApplicationFacade.server.getConfirmedIdentities { [weak self] responseObject, _, errorMessage in
            if errorMessage != nil {
                return
            } else if let dict = responseObject as? [AnyHashable: Any] {
                if let accountID = dict[DPAGStrings.JSON.Account.ACCOUNT_ID] as? String, let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), accountID == contact.accountID {
                    var notify = false
                    do {
                        let confirmedIdentities = try self?.accountDAO.updateConfirmedIdentities(responseDict: dict)
                        notify = confirmedIdentities?.notify ?? false
                    } catch {
                        DPAGLog(error)
                        return
                    }
                    if notify {
                        NotificationCenter.default.post(name: DPAGStrings.Notification.Account.CONFIRMED_IDENTITIES_CHANGED, object: nil)
                    }
                }
                DPAGApplicationFacade.preferences.cacheVersionTaskCompleted(DPAGPreferences.PropString.kCacheVersionConfirmedIdentities, cacheVersionServer: cacheVersionConfirmedIdentitiesServer)
            } else {
                return
            }
        }
    }

    func removeConfirmedEmailAddress(withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.removeConfirmedEmailAddress(withResponse: responseBlock)
    }

    func removeConfirmedPhoneNumber(withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.removeConfirmedPhoneNumber(withResponse: responseBlock)
    }

    func removeConfirmedEmailAddressDB() throws {
        accountDAO.removeConfirmedEmailAddress()
        try DPAGApplicationFacade.preferences.ensureRecoveryBlobs()
        NotificationCenter.default.post(name: DPAGStrings.Notification.Account.CONFIRMED_IDENTITIES_CHANGED, object: nil)
    }

    func removeConfirmedPhoneNumberDB() throws {
        accountDAO.removeConfirmedPhoneNumber()
        try DPAGApplicationFacade.preferences.ensureRecoveryBlobs()
        NotificationCenter.default.post(name: DPAGStrings.Notification.Account.CONFIRMED_IDENTITIES_CHANGED, object: nil)
    }
}
