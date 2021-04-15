//
//  SIMSAccount.swift
//  SIMSme
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

extension SIMSAccount {
    @NSManaged var hasChanged: NSNumber?
    @NSManaged var key_guid: String?
    @NSManaged private var state: NSNumber?
    @NSManaged var additionalData: String?
    @NSManaged var stateMessages: NSOrderedSet?
}

class SIMSAccount: SIMSManagedObjectEncrypted {
    @NSManaged private var phone: String?
    @NSManaged private var publicKey: String?

    // Insert code here to add functionality to your managed object subclass

    private static let PROFIL_KEY = "Profil-Key"
    private static let ACCOUNT_STATE = "accountState"
    private static let ACCOUNT_ID = "accountID"
    private static let SHARED_SECRET = "sharedSecret"
    private static let PRIVATE_KEY = "privateKey"
    private static let PROFILE_NAME = "profileName"
    private static let COMPANY_FIRST_NAME = "companyFirstName"
    private static let COMPANY_LAST_NAME = "companyLastName"
    private static let COMPANY_DEPARTMENT = "companyDepartment"
    private static let COMPANY_EMAIL = "companyEMail"
    private static let COMPANY_EMAIL_ENCRYPTION = "companyEMailEncryption"
    private static let COMPANY_EMAIL_DOMAIN = "companyEMailDomain"

    private static let COMPANY_EMAIL_ADDRESS_STATUS = "companyEMailStatus"
    private static let COMPANY_EMAIL_ADDRESS_TRIES_LEFT = "companyEMailTriesLeft"

    private static let COMPANY_PHONE_NUMBER_STATUS = "companyPhoneNumberStatus"
    private static let COMPANY_PHONE_NUMBER_TRIES_LEFT = "companyPhoneNumberTriesLeft"

    private static let COMPANY_INFO = "companyInfo"
    private static let COMPANY_INFO_SEED = "companyInfoSeed"
    private static let COMPANY_INFO_SALT = "companyInfoSalt"
    private static let COMPANY_INFO_USER_RESTRICTED_INDEX = "userRestrictedIndex"
    private static let COMPANY_INFO_ENCRYPTION_EMAIL = "companyInfoEncryptionEmail"
    private static let COMPANY_INFO_ENCRYPTION_PHONE_NUMBER = "companyInfoEncryptionPhoneNumber"
    private static let COMPANY_INFO_ENCRYPTION_DIFF = "companyInfoEncryptionDiff"
    private static let COMPANY_INFO_ENCRYPTION_COMPANY_KEY = "companyInfoEncryptionCompanyKey"
    private static let COMPANY_INFO_ENCRYPTION_COMPANY_USER_DATA_KEY = "companyInfoEncryptionUserDataKey"

    private static let BACKUP_PASSTOKEN = "backupPasstoken"

    override public var description: String {
        String(format: "account: %@  id: %@", self.guid ?? "", self.accountID ?? "")
    }

    @objc
    public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.ACCOUNT
    }

    var accountState: DPAGAccountState {
        get {
            let retVal: DPAGAccountState = DPAGAccountState(rawValue: self.state?.intValue ?? DPAGAccountState.unknown.rawValue) ?? .unknown

            if retVal != .confirmed, let anAccountState = self.getAttribute(SIMSAccount.ACCOUNT_STATE) as? String, let accountStateInt = Int(anAccountState), let accountState = DPAGAccountState(rawValue: accountStateInt) {
                if accountStateInt > retVal.rawValue {
                    return accountState
                }
            }

            return retVal
        }
        set {
            self.state = NSNumber(value: newValue.rawValue)
            self.setAttributeWithKey(SIMSAccount.ACCOUNT_STATE, andValue: String(newValue.rawValue))
        }
    }

    private var accountID: String? {
        get {
            let anAccountID = self.getAttribute(SIMSAccount.ACCOUNT_ID) as? String

            return anAccountID
        }
        set {
            if let anAccountID = newValue, anAccountID != self.accountID {
                self.setAttributeWithKey(SIMSAccount.ACCOUNT_ID, andValue: anAccountID)

                if let localContext = self.managedObjectContext, let accountGuid = self.guid, let contact = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) {
                    contact[.ACCOUNT_ID] = anAccountID
                }
            }
        }
    }

    var sharedSecret: String? {
        get {
            let aSharedSecret = self.getAttribute(SIMSAccount.SHARED_SECRET) as? String

            return aSharedSecret
        }
        set {
            if let aSharedSecret = newValue {
                self.setAttributeWithKey(SIMSAccount.SHARED_SECRET, andValue: aSharedSecret)
            }
        }
    }

    var backupPasstoken: String? {
        get {
            self.getAttribute(SIMSAccount.BACKUP_PASSTOKEN) as? String
        }
        set {
            if let newValue = newValue {
                self.setAttributeWithKey(SIMSAccount.BACKUP_PASSTOKEN, andValue: newValue)
            }
        }
    }

    var privateKey: String? {
        get {
            let aPrivateKey = self.getAttribute(SIMSAccount.PRIVATE_KEY) as? String

            return aPrivateKey
        }
        set {
            if let aPrivateKey = newValue {
                self.setAttributeWithKey(SIMSAccount.PRIVATE_KEY, andValue: aPrivateKey)
            }
        }
    }

    private var profilKey: String? {
        let aProfilKey = self.getAttribute(SIMSAccount.PROFIL_KEY) as? String

        return aProfilKey
//        set {
//            if let aProfilKey = newValue
//            {
//                self.setAttributeWithKey(SIMSAccount.PROFIL_KEY, andValue:aProfilKey)
//            }
//        }
    }

    private var nickName: String? {
        let aNickname = self.getAttribute(SIMSAccount.PROFILE_NAME) as? String

        return aNickname
//        set {
//            if let aNickname = newValue
//            {
//                ensureProfilKey()
//                self.setAttributeWithKey(SIMSAccount.PROFILE_NAME, andValue:aNickname)
//            }
//        }
    }

    var emailAdressCompanyEncryption: String? {
        let value = self.getAttribute(SIMSAccount.COMPANY_EMAIL_ENCRYPTION) as? String

        return value
    }

    private var emailAdress: String? {
        let aEmailAdress = self.getAttribute(SIMSAccount.COMPANY_EMAIL) as? String

        return aEmailAdress
    }

    private var emailDomain: String? {
        let aEmaiDomain = self.getAttribute(SIMSAccount.COMPANY_EMAIL_DOMAIN) as? String

        return aEmaiDomain
    }

    func aesKey(emailDomain: String) throws -> Data {
        let rounds: UInt32 = 80_000

        // Domäne in NSData umwandeln
        guard let passwordData = emailDomain.data(using: .utf8) else {
            throw DPAGErrorCrypto.errData
        }

        // Ausgabe des Schlüessels
        let saltArr: [UInt8] = Array(repeating: 0, count: 32)
        let salt = Data(saltArr)

        let aesKey = try CryptoHelper.pbkdfKey(passwordData: passwordData, salt: salt, rounds: rounds, length: 32)

        return aesKey
    }

    var companyEMailAddressStatus: DPAGAccountCompanyEmailStatus {
        get {
            if let statusString = self.getAttribute(SIMSAccount.COMPANY_EMAIL_ADDRESS_STATUS) as? String, let statusInt = Int(statusString) {
                return DPAGAccountCompanyEmailStatus(rawValue: statusInt) ?? .none
            }

            return DPAGAccountCompanyEmailStatus.none
        }
        set {
            let value = String(format: "%li", newValue.rawValue)
            self.setAttributeWithKey(SIMSAccount.COMPANY_EMAIL_ADDRESS_STATUS, andValue: value)
        }
    }

    var companyPhoneNumberStatus: DPAGAccountCompanyPhoneNumberStatus {
        get {
            if let statusString = self.getAttribute(SIMSAccount.COMPANY_PHONE_NUMBER_STATUS) as? String, let statusInt = Int(statusString) {
                return DPAGAccountCompanyPhoneNumberStatus(rawValue: statusInt) ?? .none
            }

            return DPAGAccountCompanyPhoneNumberStatus.none
        }
        set {
            let value = String(format: "%li", newValue.rawValue)

            self.setAttributeWithKey(SIMSAccount.COMPANY_PHONE_NUMBER_STATUS, andValue: value)
        }
    }

    var triesLeftEmail: Int {
        get {
            if let triesLeftString = self.getAttribute(SIMSAccount.COMPANY_EMAIL_ADDRESS_TRIES_LEFT) as? String, let triesLeftInt = Int(triesLeftString) {
                return triesLeftInt
            }

            return 10
        }
        set {
            let value = String(format: "%li", newValue)
            self.setAttributeWithKey(SIMSAccount.COMPANY_EMAIL_ADDRESS_TRIES_LEFT, andValue: value)
        }
    }

    var triesLeftPhoneNumber: Int {
        get {
            if let triesLeftString = self.getAttribute(SIMSAccount.COMPANY_PHONE_NUMBER_TRIES_LEFT) as? String, let triesLeftInt = Int(triesLeftString) {
                return triesLeftInt
            }

            return 0
        }
        set {
            let value = String(format: "%li", newValue)
            self.setAttributeWithKey(SIMSAccount.COMPANY_PHONE_NUMBER_TRIES_LEFT, andValue: value)
        }
    }

    func isCompanyAccountEmailConfirmed() -> Bool {
        self.companyEMailAddressStatus == .confirmed
    }

    func isCompanyAccountPhoneNumberConfirmed() -> Bool {
        self.companyPhoneNumberStatus == .confirmed
    }

    var companyInfo: [AnyHashable: Any] {
        get {
            self.getAttribute(SIMSAccount.COMPANY_INFO) as? [AnyHashable: Any] ?? [:]
        }
        set {
            var companyInfo = self.getAttribute(SIMSAccount.COMPANY_INFO) as? [AnyHashable: Any] ?? [:]

            if let resIndex = newValue[SIMSAccount.COMPANY_INFO_USER_RESTRICTED_INDEX] as? String, resIndex != companyInfo[SIMSAccount.COMPANY_INFO_USER_RESTRICTED_INDEX] as? String {
                DPAGApplicationFacade.preferences.resetGroupSynchronizations()
            }

            var hasChanges = false

            for (key, value) in newValue {
                if let valueCurrent = companyInfo[key] {
                    if let valueCurrentEquatable = valueCurrent as? NSObject, let valueEquatable = value as? NSObject {
                        if valueCurrentEquatable != valueEquatable {
                            companyInfo[key] = value
                            hasChanges = true
                        }
                    } else {
                        companyInfo[key] = value
                        hasChanges = true
                    }
                } else {
                    companyInfo[key] = value
                    hasChanges = true
                }
            }

            if hasChanges {
                self.setAttributeWithKey(SIMSAccount.COMPANY_INFO, andValue: companyInfo)
            }
        }
    }

    func setCompanySeed(_ seed: String, salt: String, phoneNumber: String?, email: String?, diff: String?) {
        var companyInfo = self.companyInfo

        companyInfo[SIMSAccount.COMPANY_INFO_SEED] = seed
        companyInfo[SIMSAccount.COMPANY_INFO_SALT] = salt
        if let phoneNumber = phoneNumber {
            companyInfo[SIMSAccount.COMPANY_INFO_ENCRYPTION_PHONE_NUMBER] = phoneNumber
        }
        if let email = email {
            companyInfo[SIMSAccount.COMPANY_INFO_ENCRYPTION_EMAIL] = email
        }
        if let diff = diff {
            companyInfo[SIMSAccount.COMPANY_INFO_ENCRYPTION_DIFF] = diff
        }

        self.companyInfo = companyInfo
    }

    func setCompanyKey(_ key: String) {
        self.companyInfo[SIMSAccount.COMPANY_INFO_ENCRYPTION_COMPANY_KEY] = key
    }

    func setCompanyUserDataKey(_ key: String) {
        self.companyInfo[SIMSAccount.COMPANY_INFO_ENCRYPTION_COMPANY_USER_DATA_KEY] = key
    }

    func updateCompanyManagedState(_ accountManagedStateText: String?) {
        if let accountManagedStateText = accountManagedStateText {
            var companyInfo = self.companyInfo

            if companyInfo["state"] == nil || (companyInfo["state"] is String) == false {
                companyInfo["state"] = accountManagedStateText

                self.companyInfo = companyInfo
            } else if let accountManagedStateTextLocal = companyInfo["state"] as? String, accountManagedStateTextLocal != accountManagedStateText {
                companyInfo["state"] = accountManagedStateText

                self.companyInfo = companyInfo
            }
        }
    }

    var companyManagedState: DPAGAccountCompanyManagedState {
        if let state = self.companyInfo["state"] as? String {
            switch state {
            case "ManagedAccountAccepted":
                return .accepted
            case "ManagedAccountAcceptedEmailRequired":
                return .acceptedEmailRequired
            case "ManagedAccountAcceptedPhoneRequired":
                return .acceptedPhoneRequired
            case "ManagedAccountAcceptedEmailFailed":
                return .acceptedEmailFailed
            case "ManagedAccountAcceptedPhoneFailed":
                return .acceptedPhoneFailed
            case "ManagedAccountPendingValidation":
                return .acceptedPendingValidation
            case "ManagedAccountDenied":
                return .declined
            case "ManagedAccountNew":
                return .requested
            default:
                return .requested
            }
        }

        return .unknown
    }

    var companyPublicKey: String? {
        self.companyInfo["publicKey"] as? String
    }

    var companyUserDataKey: String? {
        self.companyInfo["userDataKey"] as? String
    }

    var companyName: String? {
        self.companyInfo["name"] as? String
    }

    var companySeed: String? {
        self.companyInfo[SIMSAccount.COMPANY_INFO_SEED] as? String
    }

    var companySalt: String? {
        self.companyInfo[SIMSAccount.COMPANY_INFO_SALT] as? String
    }

    var companyEncryptionPhoneNumber: String? {
        self.companyInfo[SIMSAccount.COMPANY_INFO_ENCRYPTION_PHONE_NUMBER] as? String
    }

    var companyEncryptionEmail: String? {
        self.companyInfo[SIMSAccount.COMPANY_INFO_ENCRYPTION_EMAIL] as? String
    }

    var isCompanyUserRestricted: Bool {
        var isCompanyUserRestricted: Bool = false

        if let companyUserRestrictedString = self.companyInfo[SIMSAccount.COMPANY_INFO_USER_RESTRICTED_INDEX] as? String {
            isCompanyUserRestricted = (Int(companyUserRestrictedString) ?? 0) != 0
        }
        return isCompanyUserRestricted
    }

    var aesKeyCompany: String? {
        if let rawKey = self.companyInfo[SIMSAccount.COMPANY_INFO_ENCRYPTION_COMPANY_KEY] as? String {
            return rawKey
        }
        if let seed = self.companySeed, let salt = self.companySalt {
            let diff = self.companyInfo[SIMSAccount.COMPANY_INFO_ENCRYPTION_DIFF] as? String

            if let deviceCrypto = CryptoHelper.sharedInstance, let aesKeyOptional = try? deviceCrypto.aesKey(forPhone: self.companyEncryptionPhoneNumber, email: self.companyEncryptionEmail, seed: seed, salt: salt, diff: diff) {
                return aesKeyOptional
            }
        }

        return nil
    }

    var aesKeyCompanyUserData: String? {
        guard let aesKey = self.aesKeyCompany else {
            return nil
        }

        if let rawKey = self.companyInfo[SIMSAccount.COMPANY_INFO_ENCRYPTION_COMPANY_USER_DATA_KEY] as? String {
            return rawKey
        }

        guard let userDataKey64 = self.companyUserDataKey, let userDataKeyData = userDataKey64.data(using: .utf8) else {
            return nil
        }

        var dataJSON: String?
        var dataIVJSON: String?

        do {
            let jsonObj = try JSONSerialization.jsonObject(with: userDataKeyData, options: []) as? [AnyHashable: Any]

            dataJSON = jsonObj?["data"] as? String
            dataIVJSON = jsonObj?["iv"] as? String
        } catch {
            return nil
        }

        guard let data = dataJSON, let dataIV = dataIVJSON else {
            return nil
        }

        guard let aesKeyCompanyUserData = try? CryptoHelperDecrypter.decryptCompanyEncryptedString(encryptedString: data, iv: dataIV, aesKey: aesKey), aesKeyCompanyUserData.isEmpty == false else {
            return nil
        }

        return aesKeyCompanyUserData
    }

    func migrate(intoContact contact: SIMSContactIndexEntry, in localContext: NSManagedObjectContext) {
        guard let accountGuid = self.guid else {
            return
        }

        if let seed = self.companySeed, let salt = self.companySalt {
            self.setCompanySeed(seed, salt: salt, phoneNumber: self.phone, email: self.emailAdressCompanyEncryption, diff: nil)
        }

        self.companyPhoneNumberStatus = .confirmed

        contact.guid = accountGuid
        contact.keyRelationship = self.keyRelationship ?? SIMSKey.mr_findFirst(in: localContext)

        contact[.PUBLIC_KEY] = self.publicKey
        contact[.ACCOUNT_ID] = self.accountID
        contact[.EMAIL_ADDRESS] = self.emailAdress
        contact[.EMAIL_DOMAIN] = self.emailDomain
        contact[.MANDANT_IDENT] = DPAGMandant.default.ident
        contact[.PROFIL_KEY] = self.profilKey
        contact[.NICKNAME] = self.nickName
        contact[.PHONE_NUMBER] = self.phone
        contact[.STATUSMESSAGE] = DPAGApplicationFacade.statusWorker.latestStatus()

        contact[.CREATED_AT] = Date()
        contact[.UPDATED_AT] = Date()

        contact[.IMAGE_DATA] = DPAGHelperEx.encodedImage(forGroupGuid: accountGuid)

        DPAGHelperEx.removeEncodedImage(forGroupGuid: accountGuid)

        contact.confidenceState = .high
        contact.entryTypeLocal = .hidden
        contact.entryTypeServer = .meMyselfAndI
    }
}
