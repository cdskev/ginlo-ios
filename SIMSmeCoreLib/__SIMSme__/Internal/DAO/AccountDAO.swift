//
//  AccountDAO.swift
//  SIMSmeCore
//
//  Created by Maxime Bentin on 07.08.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

typealias KeyDictionary = [String: [String: Any]]
typealias AccountDictionary = [String: [String: Any]]
typealias CompanyInfoDictionary = [AnyHashable: Any]

struct AccountCreationConfig {
    let deviceDict: DeviceDictionary
    let accountDictEnc: String?
}

class ConfirmedIdentities {
    var notify: Bool?
}

protocol AccountDAOProtocol {
    func getAccountState() -> DPAGAccountState?
    func isDeviceFirstRun() -> Bool?
    func hasAccount() -> Bool?
    func createAccount(config: DPAGNewAccountConfiguration, accountGuid: String, signData: String) throws -> AccountCreationConfig
    func saveNickName(_ nickName: String) -> String?
    func ensureAccountProfilKey() throws
    func initAccountNames(nickName: String, firstName: String?, lastName: String?) -> String?
    func save(firstName: String, lastName: String)
    func confirmCompanyEmailStatus() -> String?
    func save(eMailAddress: String, eMailDomain: String?) -> String?
    func confirmCompanyPhoneNumberStatus() -> String?
    func save(phoneNumber: String) -> String?
    func updateContactWithAccountID(accountGuid: String, accountID: String)
    func updateConfirmedIdentities(responseDict: [AnyHashable: Any]) throws -> ConfirmedIdentities
    func removeConfirmedEmailAddress()
    func removeConfirmedPhoneNumber()
    func confirmAccount(accountID: String)
    func confirmAccount() -> String?
    func setRecoverBackupState()
    func saveCompanyInfos(dictCompany: [AnyHashable: Any])
    func saveAvailablePhoneNumberConfirmationTries(triesLeft: Int)
    func saveAvailableEmailAddressConfirmationTries(triesLeft: Int)

    func updateCompanyUserRestrictedIndex(userRestrictedIndex: String)

    func setCompanyInfo(_ companyInfo: CompanyInfoDictionary)

    func setCompanySeed(_ seed: String, salt: String, phoneNumber: String?, email: String?, diff: String?)
}

class AccountDAO: AccountDAOProtocol {
    func saveAvailablePhoneNumberConfirmationTries(triesLeft: Int) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            if let account = SIMSAccount.mr_findFirst(in: localContext) {
                account.triesLeftPhoneNumber = triesLeft

                if triesLeft <= 0 {
                    account.companyPhoneNumberStatus = DPAGAccountCompanyPhoneNumberStatus.confirm_FAILED
                }
            }
        }
    }

    func saveAvailableEmailAddressConfirmationTries(triesLeft: Int) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            if let account = SIMSAccount.mr_findFirst(in: localContext) {
                account.triesLeftEmail = triesLeft

                if triesLeft <= 0 {
                    account.companyEMailAddressStatus = .confirm_FAILED
                }
            }
        }
    }

    func setCompanyInfo(_ companyInfo: CompanyInfoDictionary) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            if let account = SIMSAccount.mr_findFirst(in: localContext) {
                account.companyInfo = companyInfo
            }
        }
    }

    func updateCompanyUserRestrictedIndex(userRestrictedIndex: String) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            if let account = SIMSAccount.mr_findFirst(in: localContext) {
                account.companyInfo = ["userRestrictedIndex": userRestrictedIndex]
            }
        }
    }

    func getAccountState() -> DPAGAccountState? {
        var accountState: DPAGAccountState?

        DPAGApplicationFacade.persistance.loadWithBlock { localContext in
            guard let account = SIMSAccount.mr_findFirst(in: localContext) else { return }

            accountState = account.accountState
        }

        return accountState
    }

    func isDeviceFirstRun() -> Bool? {
        var isFirstRun: Bool?
        DPAGApplicationFacade.persistance.loadWithBlock { localContext in

            guard let account = SIMSAccount.mr_findFirst(in: localContext), SIMSDevice.mr_findFirst(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSDevice.ownDevice), rightExpression: NSExpression(forConstantValue: 1)), in: localContext) ?? SIMSDevice.mr_findFirst(in: localContext) != nil else {
                return
            }

            isFirstRun = false

            DPAGLog("account state \(account.accountState.rawValue) guid: %@", account.guid ?? "noGuid")
        }

        return isFirstRun
    }

    func hasAccount() -> Bool? {
        var hasAccount: Bool?

        DPAGApplicationFacade.persistance.loadWithBlock { localContext in
            hasAccount = SIMSAccount.mr_findFirst(in: localContext) != nil
        }

        return hasAccount
    }

    // MARK: CreateAccount

    func createAccount(config: DPAGNewAccountConfiguration, accountGuid: String, signData: String) throws -> AccountCreationConfig {
        var deviceDict = DeviceDictionary()
        var accountDictEncrypted: String?

        try DPAGApplicationFacade.persistance.saveWithError { localContext in
            guard var account = SIMSAccount.mr_createEntity(in: localContext), var device = SIMSDevice.mr_createEntity(in: localContext), var simsKey = SIMSKey.mr_createEntity(in: localContext), var contact = SIMSContactIndexEntry.mr_createEntity(in: localContext) else {
                throw DPAGErrorAccountManager.errDatabase
            }

            DPAGLog("account guid: %@", accountGuid)
            account.guid = accountGuid
            device.account_guid = account.guid
            contact.guid = accountGuid

            self.configAccountForCreation(account: &account, config: config)
            self.configDeviceForCreation(device: &device, config: config, signData: signData)
            self.configContactForCreation(contact: &contact, config: config)
            self.configKeyForCreation(simsKey: &simsKey, config: config)

            device.keyRelationship = simsKey
            account.keyRelationship = simsKey
            contact.keyRelationship = simsKey

            deviceDict = try device.deviceDictionary(type: "permanent")

            guard let encAttrsAccount = try account.getEncryptedAttributes() else {
                return
            }

            accountDictEncrypted = encAttrsAccount

            _ = DPAGSystemChat.systemChat(in: localContext)
        }

        return AccountCreationConfig(deviceDict: deviceDict, accountDictEnc: accountDictEncrypted)
    }

    private func configAccountForCreation(account: inout SIMSAccount, config: DPAGNewAccountConfiguration) {
        account.sharedSecret = config.sharedSecret
        account.accountState = .waitForConfirm
        account.privateKey = config.decPrivateKeyAccount

        if config.phoneNumber != nil {
            account.companyPhoneNumberStatus = .confirmed
        } else if config.emailAddress != nil {
            account.companyEMailAddressStatus = .confirmed
        }
    }

    private func configDeviceForCreation(device: inout SIMSDevice, config: DPAGNewAccountConfiguration, signData: String) {
        device.guid = config.deviceGuid
        device.name = config.deviceName
        device.passToken = config.deviceToken
        device.public_key = config.pubKeyDevice
        device.sharedSecret = config.sharedSecret
        device.publicRSAFingerprint = config.publicKeyFingerprintDevice
        device.ownDevice = 1
        device.signedPublicRSAFingerprint = signData
    }

    private func configContactForCreation(contact: inout SIMSContactIndexEntry, config: DPAGNewAccountConfiguration) {
        contact.entryTypeLocal = .hidden
        contact.entryTypeServer = .meMyselfAndI
        contact[.PHONE_NUMBER] = config.phoneNumber
        contact[.EMAIL_ADDRESS] = config.emailAddress
        contact[.EMAIL_DOMAIN] = config.emailDomain
        contact[.PUBLIC_KEY] = config.publicKeyAccount
    }

    private func configKeyForCreation(simsKey: inout SIMSKey, config: DPAGNewAccountConfiguration) {
        DPAGLog("key guid: %@", config.keyGuid)
        simsKey.guid = config.keyGuid
        simsKey.aes_key = config.encAesKey
        simsKey.device_guid = config.deviceGuid
    }

    // MARK: Create Account end

    func saveNickName(_ nickName: String) -> String? {
        var accountGuidRet: String?
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            if let account = SIMSAccount.mr_findFirst(in: localContext),
                let accountGuid = account.guid,
                let contact = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) {
                accountGuidRet = accountGuid
                contact[.NICKNAME] = nickName
            }
        }

        return accountGuidRet
    }

    func ensureAccountProfilKey() throws {
        try DPAGApplicationFacade.persistance.saveWithError { localContext in

            if let account = SIMSAccount.mr_findFirst(in: localContext), let accountGuid = account.guid, let contact = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) {
                try contact.ensureProfilKey()
            }
        }
    }

    func initAccountNames(nickName: String, firstName: String?, lastName: String?) -> String? {
        var accountGuidRet: String?
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            if let account = SIMSAccount.mr_findFirst(in: localContext), let accountGuid = account.guid, let contact = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) {
                accountGuidRet = accountGuid

                contact[.NICKNAME] = nickName
                contact[.FIRST_NAME] = firstName
                contact[.LAST_NAME] = lastName
            }
        }
        return accountGuidRet
    }

    func save(firstName: String, lastName: String) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            if let account = SIMSAccount.mr_findFirst(in: localContext), let accountGuid = account.guid, let contact = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) {
                contact[.FIRST_NAME] = firstName
                contact[.LAST_NAME] = lastName
            }
        }
    }

    func confirmCompanyEmailStatus() -> String? {
        var rc: String?
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            if let email = DPAGApplicationFacade.preferences.validationEmailAddress, let account = SIMSAccount.mr_findFirst(in: localContext), let accountGuid = account.guid, let contact = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) {
                contact[.EMAIL_ADDRESS] = email
                contact[.EMAIL_DOMAIN] = DPAGApplicationFacade.preferences.validationEmailDomain

                account.companyEMailAddressStatus = .confirmed

                rc = email
            }
        }
        return rc
    }

    func save(eMailAddress _: String, eMailDomain _: String?) -> String? {
        var accountGuidRet: String?
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            if let account = SIMSAccount.mr_findFirst(in: localContext) {
                account.companyEMailAddressStatus = .wait_CONFIRM
                account.triesLeftEmail = 10
                accountGuidRet = account.guid
            }
        }

        return accountGuidRet
    }

    func confirmCompanyPhoneNumberStatus() -> String? {
        var rc: String?
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            if let phoneNumber = DPAGApplicationFacade.preferences.validationPhoneNumber, let account = SIMSAccount.mr_findFirst(in: localContext), let accountGuid = account.guid, let contact = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) {
                contact[.PHONE_NUMBER] = phoneNumber

                account.companyPhoneNumberStatus = .confirmed

                rc = phoneNumber
            }
        }
        return rc
    }

    func save(phoneNumber _: String) -> String? {
        var accountGuidRet: String?
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            if let account = SIMSAccount.mr_findFirst(in: localContext) {
                accountGuidRet = account.guid

                account.companyPhoneNumberStatus = .wait_CONFIRM
                account.triesLeftPhoneNumber = 10
            }
        }
        return accountGuidRet
    }

    func updateContactWithAccountID(accountGuid: String, accountID: String) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            if let contact = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) {
                contact[.ACCOUNT_ID] = accountID
            }
        }
    }

    func updateConfirmedIdentities(responseDict: [AnyHashable: Any]) throws -> ConfirmedIdentities {
        var confirmedIdentities = ConfirmedIdentities()
        try DPAGApplicationFacade.persistance.saveWithError { localContext in

            guard var account = SIMSAccount.mr_findFirst(in: localContext), let accountGuid = account.guid, var contact = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) else {
                throw DPAGErrorAccountManager.errDatabase
            }

            try self.checkConfirmedPhoneNumber(dict: responseDict, contact: &contact, account: &account, confirmedIdentities: &confirmedIdentities)
            try self.checkPendingPhoneNumbers(dict: responseDict, account: &account, confirmedIdentities: &confirmedIdentities)
            try self.checkConfirmedEmailAddresses(dict: responseDict, contact: &contact, account: &account, confirmedIdentities: &confirmedIdentities)
            try self.checkPendingEmailAddresses(dict: responseDict, account: &account, confirmedIdentities: &confirmedIdentities)
        }

        return confirmedIdentities
    }

    private func checkConfirmedPhoneNumber(dict: [AnyHashable: Any], contact: inout SIMSContactIndexEntry, account: inout SIMSAccount, confirmedIdentities: inout ConfirmedIdentities) throws {
        if let confirmedPhoneNumbers = dict["confirmedPhone"] as? [String] {
            if let confirmedPhoneNumber = confirmedPhoneNumbers.first {
                if let decryptedPhoneNumber = try DPAGCryptoHelper.newAccountCrypto()?.decryptWithPrivateKey(encryptedString: confirmedPhoneNumber), decryptedPhoneNumber.isEmpty == false {
                    if contact[.PHONE_NUMBER] != decryptedPhoneNumber {
                        contact[.PHONE_NUMBER] = decryptedPhoneNumber
                        confirmedIdentities.notify = true
                    }
                    account.companyPhoneNumberStatus = .confirmed
                }
            } else if (contact[.PHONE_NUMBER]?.isEmpty ?? true) == false {
                if (dict["confirmedMail"] as? [String])?.first != nil {
                    contact[.PHONE_NUMBER] = nil

                    if account.companyPhoneNumberStatus == .confirmed {
                        account.companyPhoneNumberStatus = .none
                    }
                    confirmedIdentities.notify = true
                }
            }
        }
    }

    private func checkPendingPhoneNumbers(dict: [AnyHashable: Any], account: inout SIMSAccount, confirmedIdentities: inout ConfirmedIdentities) throws {
        if let pendingPhoneNumbers = dict["pendingPhone"] as? [String] {
            if let pendingPhoneNumber = pendingPhoneNumbers.first, let decryptedPhoneNumber = try DPAGCryptoHelper.newAccountCrypto()?.decryptWithPrivateKey(encryptedString: pendingPhoneNumber), decryptedPhoneNumber.isEmpty == false {
                if DPAGApplicationFacade.preferences.validationPhoneNumber != decryptedPhoneNumber {
                    DPAGApplicationFacade.preferences.validationPhoneNumber = decryptedPhoneNumber
                    confirmedIdentities.notify = true
                }
                account.companyPhoneNumberStatus = .wait_CONFIRM
            } else {
                if DPAGApplicationFacade.preferences.validationPhoneNumber != nil {
                    confirmedIdentities.notify = true
                }
                DPAGApplicationFacade.preferences.validationPhoneNumber = nil
            }
        }
    }

    private func checkConfirmedEmailAddresses(dict: [AnyHashable: Any], contact: inout SIMSContactIndexEntry, account: inout SIMSAccount, confirmedIdentities: inout ConfirmedIdentities) throws {
        if let confirmedEmailAddresses = dict["confirmedMail"] as? [String] {
            if let confirmedEmailAddress = confirmedEmailAddresses.first {
                if let decryptedEmailAddress = try DPAGCryptoHelper.newAccountCrypto()?.decryptWithPrivateKey(encryptedString: confirmedEmailAddress), decryptedEmailAddress.isEmpty == false {
                    if contact[.EMAIL_ADDRESS] != decryptedEmailAddress {
                        contact[.EMAIL_ADDRESS] = decryptedEmailAddress
                        confirmedIdentities.notify = true
                    }
                    account.companyEMailAddressStatus = .confirmed
                }
            } else if (contact[.EMAIL_ADDRESS]?.isEmpty ?? true) == false {
                if (dict["confirmedPhone"] as? [String])?.first != nil {
                    contact[.EMAIL_ADDRESS] = nil
                    contact[.EMAIL_DOMAIN] = nil

                    if account.companyEMailAddressStatus == .confirmed {
                        account.companyEMailAddressStatus = .none
                    }
                    confirmedIdentities.notify = true
                }
            }
        }
    }

    private func checkPendingEmailAddresses(dict: [AnyHashable: Any], account: inout SIMSAccount, confirmedIdentities: inout ConfirmedIdentities) throws {
        if let pendingEmailAddresses = dict["pendingMail"] as? [String] {
            if let pendingEmailAddress = pendingEmailAddresses.first, let decryptedEmailAddress = try DPAGCryptoHelper.newAccountCrypto()?.decryptWithPrivateKey(encryptedString: pendingEmailAddress), decryptedEmailAddress.isEmpty == false {
                if DPAGApplicationFacade.preferences.validationEmailAddress != decryptedEmailAddress {
                    DPAGApplicationFacade.preferences.validationEmailAddress = decryptedEmailAddress
                    confirmedIdentities.notify = true
                }
                account.companyEMailAddressStatus = .wait_CONFIRM
            } else {
                if DPAGApplicationFacade.preferences.validationEmailAddress != nil {
                    confirmedIdentities.notify = true
                }
                DPAGApplicationFacade.preferences.validationEmailAddress = nil
            }
        }
    }

    func removeConfirmedEmailAddress() {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            if let account = SIMSAccount.mr_findFirst(in: localContext), let accountGuid = account.guid, let contact = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) {
                account.companyEMailAddressStatus = .none
                contact[.EMAIL_ADDRESS] = nil
                contact[.EMAIL_DOMAIN] = nil
            }
        }
    }

    func removeConfirmedPhoneNumber() {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            if let account = SIMSAccount.mr_findFirst(in: localContext), let accountGuid = account.guid, let contact = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) {
                account.companyPhoneNumberStatus = .none
                contact[.PHONE_NUMBER] = nil
            }
        }
    }

    func confirmAccount(accountID: String) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            if let account = SIMSAccount.mr_findFirst(in: localContext), let accountGuid = account.guid, let contact = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) {
                contact[.ACCOUNT_ID] = accountID

                account.accountState = .confirmed
            }
        }
    }

    func confirmAccount() -> String? {
        var accountGuid: String?
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            if let account = SIMSAccount.mr_findFirst(in: localContext) {
                account.accountState = .confirmed
                accountGuid = account.guid
            }
        }
        return accountGuid
    }

    func setRecoverBackupState() {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            guard let account = SIMSAccount.mr_findFirst(in: localContext), account.guid != nil else {
                return
            }

            account.accountState = .recoverBackup
            account.companyPhoneNumberStatus = .none

            DPAGApplicationFacade.model.update(with: localContext)
        }
    }

    func saveCompanyInfos(dictCompany: [AnyHashable: Any]) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            if let account = SIMSAccount.mr_findFirst(in: localContext) {
                account.companyInfo = dictCompany
            }
        }
    }

    func setCompanySeed(_ seed: String, salt: String, phoneNumber: String?, email: String?, diff: String?) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            if let account = SIMSAccount.mr_findFirst(in: localContext) {
                account.setCompanySeed(seed, salt: salt, phoneNumber: phoneNumber, email: email, diff: diff)

                DPAGApplicationFacade.cache.account?.update(with: account)
            }
        }
    }
}
