//
//  DPAGCouplingWorker.swift
//  SIMSmeCore
//
//  Created by Yves Hetzer on 22.11.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import JFBCrypt

enum DPAGErrorCoupling: Error {
    case err007
    case err160
    case errNoAccount
    case errNoAccountCrypto
    case errNoDeviceCrypto
    case errNoAccountPublicKey
    case errNoDeviceNameEncryption
    case errNoCouplingDevice
    case errNoPublicKey
    case errNoTicketOrRequest
    case errCreateTransId
    case errToJson
    case errNoPassword
    case errNoTransId
    case errSignature
    case errServer(errorCode: String, errorMessage: String)
}

public enum DPAGCouplingSearchMode: Int {
    case phone,
        mail,
        accountID
}

public enum DPAGCouplingReqType: Int {
    case permanent,
        temporaer
}

class DPAGCouplingAccount {
    let accountId: String
    let guid: String
    let publicKey: String

    init?(data: [AnyHashable: Any]) {
        guard let accountId = data["accountID"] as? String, let guid = data["guid"] as? String, let publicKey = data["publicKey"] as? String else {
            return nil
        }

        self.accountId = accountId
        self.guid = guid
        self.publicKey = publicKey
    }
}

class DPAGCouplingDevice {
    var guid: String
    var deviceName: String?

    init(guid: String) {
        self.guid = guid
    }
}

class DPAGCouplingCouplingTicket {
    let transId: String
    let ts: String
    let tan: String
    let appData: String
    let signature: String

    init?(data: [AnyHashable: Any]) {
        guard let transId = data["transId"] as? String, let ts = data["ts"] as? String, let tan = data["tan"] as? String, let appData = data["appData"] as? String, let signature = data["sig"] as? String else { return nil }
        self.transId = transId
        self.ts = ts
        self.tan = tan
        self.appData = appData
        self.signature = signature
    }
}

public class DPAGCouplingCouplingRequest {
    let transId: String
    public let publicKey: String
    let encVrfy: String
    let reqType: String
    let appData: String
    let signature: String

    init?(data: [AnyHashable: Any]) {
        guard let transId = data["transId"] as? String, let publicKey = data["pubKey"] as? String, let encVrfy = data["encVrfy"] as? String, let reqType = data["reqType"] as? String, let appData = data["appData"] as? String, let signature = data["sig"] as? String else { return nil }
        self.transId = transId
        self.publicKey = publicKey
        self.encVrfy = encVrfy
        self.reqType = reqType
        self.appData = appData
        self.signature = signature
    }

    func checkSignature(accountGuid: String) throws -> Bool {
        let concatSignature = accountGuid + self.transId + self.publicKey + self.encVrfy + self.reqType + self.appData
        return try CryptoHelperVerifier.verifyData256(data: concatSignature, withSignature: self.signature, forPublicKey: self.publicKey)
    }
}

class DPAGCouplingCouplingResponse {
    let transId: String
    let publicKey: String
    let publicKeySig: String
    let kek: String
    let kekIV: String
    let encSyncData: String
    let appData: String
    let signature: String

    init?(data: [AnyHashable: Any]) {
        guard let transId = data["transId"] as? String, let publicKey = data["device"] as? String, let publicKeySig = data["devKeySig"] as? String, let kek = data["kek"] as? String, let kekIV = data["kekIV"] as? String, let encSyncData = data["encSyncData"] as? String, let appData = data["appData"] as? String, let signature = data["sig"] as? String else { return nil }
        self.transId = transId
        self.publicKey = publicKey
        self.publicKeySig = publicKeySig
        self.kek = kek
        self.kekIV = kekIV
        self.encSyncData = encSyncData
        self.appData = appData
        self.signature = signature
    }

    func checkSignature(accountPublicKey: String) throws -> Bool {
        let concatSignature = self.transId + self.publicKey + self.publicKeySig + self.kek + self.kekIV + self.encSyncData + self.appData
        return try CryptoHelperVerifier.verifyData256(data: concatSignature, withSignature: self.signature, forPublicKey: accountPublicKey)
    }
}

class DPAGTempDeviceInfos {
    let keys: String
    let createdAt: String
    let nextUpdate: String
    let signature: String

    var existingDevices: [DPAGTempDeviceInfo] = []

    init?(data: [AnyHashable: Any]) {
        guard let accountKeysList = data["AccountKeysList"] as? [AnyHashable: Any] else { return nil }
        guard let keys = accountKeysList["keys"] as? String, let createdAt = accountKeysList["createdAt"] as? String, let nextUpdate = accountKeysList["nextUpdate"] as? String, let signature = accountKeysList["sig"] as? String else { return nil }
        self.keys = keys
        self.createdAt = createdAt
        self.nextUpdate = nextUpdate
        self.signature = signature
        if let keysData = keys.data(using: .utf8), let existingDevices = try? JSONSerialization.jsonObject(with: keysData, options: .allowFragments), let existingDevicesArray = existingDevices as? [[AnyHashable: Any]] {
            for dict in existingDevicesArray {
                if let deviceInfo = DPAGTempDeviceInfo(data: dict) {
                    self.existingDevices.append(deviceInfo)
                }
            }
        }
    }

    func checkSignature(accountPublicKey: String) throws -> Bool {
        let concatSignature = self.keys + self.createdAt + self.nextUpdate
        return try CryptoHelperVerifier.verifyData256(data: concatSignature, withSignature: self.signature, forPublicKey: accountPublicKey)
    }
}

class DPAGTempDeviceInfo {
    var guid: String
    var pubKey: String
    var fingerprint: String
    var type: String
    var start: String
    var end: String

    init(guid: String, pubKey: String, fingerprint: String, type: String, start: String, end: String) {
        self.guid = guid
        self.pubKey = pubKey
        self.fingerprint = fingerprint
        self.type = type
        self.start = start
        self.end = end
    }

    init?(data: [AnyHashable: Any]) {
        guard let guid = data["deviceGuid"] as? String else { return nil }
        guard let pubKey = data["pubKey"] as? String else { return nil }
        guard let fingerprint = data["fingerprint"] as? String else { return nil }
        guard let type = data["type"] as? String else { return nil }
        guard let validity = data["validity"] as? [AnyHashable: Any] else { return nil }
        guard let start = validity["start"] as? String else { return nil }
        guard let end = validity["end"] as? String else { return nil }
        self.guid = guid
        self.pubKey = pubKey
        self.fingerprint = fingerprint
        self.type = type
        self.start = start
        self.end = end
    }

    func getExternalJson() -> [AnyHashable: Any] {
        let tempDeviceInfo: [String: Any] = ["type": self.type, "deviceGuid": self.guid, "fingerprint": self.fingerprint, "pubKey": self.pubKey, "validity": ["start": self.start, "end": self.end]]
        return tempDeviceInfo
    }
}

public protocol DPAGCouplingWorkerProtocol: AnyObject {
    var deviceName: String? { get set }
    var couplingTan: String? { get }
    var hasCouplingRequest: Bool { get }
    var couplingRequest: DPAGCouplingCouplingRequest? { get }
    func fetchPendingMessagesForPreview() throws
    func fetchPendingMessages()
    func checkTempSignature(accountGuid: String, accountPublicKey: String, deviceGuid fromTempDeviceGuid: String, signatureHashes signHashes: String, signatureTempDevice: String, dateSendServer: Date) throws -> Bool
    func loadPrivateIndexFromServer(ifModifiedSince: String?, forceLoad: Bool) throws
    func fetchPrivateIndexEntries(entries: [String: String]) throws
    func savePrivateIndexToServer()
    func fetchOwnTempDevice()
    func setDeviceNameInternal(guid: String, deviceName deviceNameEncoded: String) throws -> [Any]?
    func deleteTempDevice(guid: String) throws
    func initialise() throws
    func getCouplingRequest() throws
    func getCouplingResponse() throws -> Bool
    func getCouplingAccountGuid() -> String?
    func getCouplingDeviceName() -> String?
    func getCouplingDeviceOs() -> String?
    func getCouplingTempDevice() -> Bool
    func confirmCouplingRequest() throws
    func cancelCoupling() throws
    func setPasswordOptions(password: String, enabled enabledPassword: Bool)
    func selectExistingAccount(data: String, searchMode mode: DPAGCouplingSearchMode) throws
    func requestCoupling(tan: String, reqType type: DPAGCouplingReqType) throws
    func createDevice() throws -> Bool
}

class DPAGCouplingWorker: DPAGCouplingWorkerProtocol {
    static let sharedInstance = DPAGCouplingWorker()
    private let couplingDAO: CouplingDAOProtocol = CouplingDAO()
    var couplingTan: String?
    private var couplingTransId: String?
    private var couplingAccount: DPAGCouplingAccount?
    private var couplingDevice: DPAGCouplingDevice?
    private var couplingTicket: DPAGCouplingCouplingTicket?
    private(set) var couplingRequest: DPAGCouplingCouplingRequest?
    private var couplingResponse: DPAGCouplingCouplingResponse?
    var password: String?
    private var enabledPassword = false
    var deviceName: String?
    var hasCouplingRequest = false
    private var isSavingPrivateIndex = false
    private var restartSavePrivateIndex = false

    func setPasswordOptions(password: String, enabled enabledPassword: Bool) {
        self.password = password
        self.enabledPassword = enabledPassword
    }

    func initialise() throws {
        self.clearMember()
        guard let tan = CryptoHelper.sharedInstance?.createCouplingTan() else { throw DPAGErrorCoupling.errCreateTransId }
        self.couplingTan = tan
        guard let accountCrypto = DPAGCryptoHelper.newAccountCrypto() else { throw DPAGErrorCoupling.errNoAccountCrypto }
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) else { throw DPAGErrorCoupling.errNoAccount }
        guard let contactPublicKey = contact.publicKey else { throw DPAGErrorCoupling.errNoAccountPublicKey }
        guard let transId = try CryptoHelperGenerator.generateTransId(tan: tan, publicKey: contactPublicKey, account: account.guid) else { throw DPAGErrorCoupling.errCreateTransId }
        let ts = CryptoHelper.newDateInDLFormat()
        let appData = "{}"
        let tanEncrypted = try CryptoHelperEncrypter.encrypt(string: tan, withPublicKey: contactPublicKey)
        let concatSignature = String(format: "%@%@%@%@", transId, tanEncrypted, ts, appData)
        let signature = try accountCrypto.signData256(data: concatSignature)
        _ = try self.initialiseCoupling(transId: transId, timestamp: ts, tan: tanEncrypted, appData: appData, signature: signature)
        self.couplingTransId = transId
    }

    private func clearMember() {
        self.couplingTransId = nil
        self.couplingAccount = nil
        self.couplingDevice = nil
        self.couplingTicket = nil
        self.couplingRequest = nil
        self.couplingResponse = nil
    }

    func cancelCoupling() throws {
        guard let couplingTransId = self.couplingTransId else { return }
        _ = try self.cancelCouplingInternal(transId: couplingTransId)
        self.couplingTransId = nil
        self.couplingTan = nil
    }

    func initialiseCoupling(transId: String, timestamp ts: String, tan tan1: String, appData: String, signature sig: String) throws -> String? {
        var retVal: String?
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
            } else if let rc = responseObject as? [String] {
                retVal = rc.first
            }
        }
        DPAGApplicationFacade.server.initialiseCoupling(transId: transId, timestamp: ts, tan: tan1, appData: appData, signature: sig, withResponse: responseBlock)
        _ = semaphore.wait(timeout: .distantFuture)
        if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
            throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
        }
        return retVal
    }

    func cancelCouplingInternal(transId: String) throws -> String? {
        var retVal: String?
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
            } else if let rc = responseObject as? [String] {
                retVal = rc.first
            }
        }
        DPAGApplicationFacade.server.cancelCoupling(transId: transId, withResponse: responseBlock)
        _ = semaphore.wait(timeout: .distantFuture)
        if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
            throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
        }
        return retVal
    }

    func selectExistingAccount(data: String, searchMode mode: DPAGCouplingSearchMode) throws {
        self.clearMember()
        let searchMode: String
        var searchData: String
        let salt = DPAGMandant.default.salt
        switch mode {
            case .phone:
                searchMode = "phone"
                let phoneNumberNormalized = DPAGCountryCodes.sharedInstance.normalizePhoneNumber(data, countryCodeAccount: nil, useCountryCode: nil)
                searchData = DPAGApplicationFacade.cache.hash(accountSearchAttribute: phoneNumberNormalized, withSalt: salt)
            case .mail:
                searchMode = "mail"
                searchData = data.lowercased()
                searchData = JFBCrypt.hashPassword(searchData, withSalt: salt)
            case .accountID:
                searchMode = "accountID"
                searchData = data
        }
        guard let rc = try self.getAccountInfo(searchData: searchData, searchMode: searchMode), let account = rc.first as? [AnyHashable: Any], let accountDict = account["Account"] as? [AnyHashable: Any], let ca = DPAGCouplingAccount(data: accountDict) else { throw DPAGErrorCoupling.err007 }
        self.couplingAccount = ca
        AppConfig.setIdleTimerDisabled(true)
    }


    func getAccountInfo(searchData: String, searchMode mode: String) throws -> [Any]? {
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
                if errorMessage != "service.ERR-0007" {
                    errorMessageBlock = errorMessage
                    errorCodeBlock = errorCode
                }
            } else if let rc = responseObject as? [Any] {
                retVal = rc
            }
        }
        DPAGApplicationFacade.server.getAccountInfoAnonymous(data: searchData, searchMode: mode, withResponse: responseBlock)
        _ = semaphore.wait(timeout: .distantFuture)
        if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
            throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
        }
        return retVal
    }

    func requestCoupling(tan: String, reqType type: DPAGCouplingReqType) throws {
        guard let couplingAccount = self.couplingAccount else { throw DPAGErrorCoupling.errNoAccount }
        guard let password = self.password else { throw DPAGErrorCoupling.errNoPassword }
        if self.couplingDevice == nil {
            let deviceGuid = DPAGFunctionsGlobal.uuid(prefix: .device)
            let deviceCrypto = CryptoHelper.sharedInstance
            try deviceCrypto?.generateKeyPairAndSaveitToKeyChain()
            try deviceCrypto?.encryptPrivateKey(password: password)
            self.couplingDevice = DPAGCouplingDevice(guid: deviceGuid)
        }
        guard let couplingDevice = self.couplingDevice else { throw DPAGErrorCoupling.errNoCouplingDevice }
        let accountGuid = couplingAccount.guid
        guard let publicKey = CryptoHelper.sharedInstance?.publicKey else { throw DPAGErrorCoupling.errNoPublicKey }
        guard let transId = try CryptoHelperGenerator.generateTransId(tan: tan, publicKey: couplingAccount.publicKey, account: couplingAccount.guid) else { throw DPAGErrorCoupling.errCreateTransId }
        var reqType = "0x0101"
        if type == .temporaer {
            reqType = "0x0201"
        }
        self.couplingDevice?.deviceName = self.deviceName
        let deviceOs = DPAGApplicationFacade.accountManager.getOsName()
        guard let encodedDeviceName = self.couplingDevice?.deviceName?.data(using: .utf8)?.base64EncodedString(options: .lineLength76Characters) else { throw DPAGErrorCoupling.errNoDeviceNameEncryption }
        let appDataDict = ["deviceName": encodedDeviceName, "deviceGuid": couplingDevice.guid, "deviceOs": deviceOs]
        guard let appData = appDataDict.JSONString else { throw DPAGErrorCoupling.errToJson }
        let concatSignatureVrfy = tan + transId + publicKey
        let encVrfy = try CryptoHelperEncrypter.hashAndEncrypt(string: concatSignatureVrfy, withPublicKey: couplingAccount.publicKey)
        let concatSignature = couplingAccount.guid + transId + publicKey + encVrfy + reqType + appData
        guard let signature = try CryptoHelper.sharedInstance?.signData256(data: concatSignature) else { throw DPAGErrorCoupling.errCreateTransId }
        let retVal = try self.requestCouplingInternal(accountGuid: accountGuid, transId: transId, pubKey: publicKey, encVrfy: encVrfy, reqType: reqType, appData: appData, signature: signature)
        if retVal == nil {
            throw DPAGErrorCoupling.err160
        }
        self.couplingTransId = retVal
        self.couplingTan = tan
        AppConfig.setIdleTimerDisabled(false)
    }

    func requestCouplingInternal(accountGuid: String, transId transaktionId: String, pubKey publicKey: String, encVrfy vrfy: String, reqType type: String, appData: String, signature sig: String) throws -> String? {
        var retVal: String?
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
            } else if let rc = responseObject as? [String] {
                retVal = rc.first
            }
        }
        DPAGApplicationFacade.server.requestCoupling(accountGuid: accountGuid, transId: transaktionId, pubKey: publicKey, encVrfy: vrfy, reqType: type, appData: appData, signature: sig, withResponse: responseBlock)
        _ = semaphore.wait(timeout: .distantFuture)
        if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
            throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
        }
        return retVal
    }

    func getCouplingRequest() throws {
        self.hasCouplingRequest = false
        guard let couplingTransId = self.couplingTransId, let accountGuid = DPAGApplicationFacade.cache.account?.guid else { return }
        if let rc = try self.getCouplingRequestInternal(transId: couplingTransId) as? [[AnyHashable: Any]] {
            for dict in rc {
                if let dictCT = dict["CT"] as? [AnyHashable: Any] {
                    let ticket = DPAGCouplingCouplingTicket(data: dictCT)

                    self.couplingTicket = ticket
                }
                if let dictCREG = dict["CREQ"] as? [AnyHashable: Any] {
                    let request = DPAGCouplingCouplingRequest(data: dictCREG)

                    self.couplingRequest = request
                }
            }
        }
        guard let couplingRequest = self.couplingRequest, self.couplingTicket != nil else { throw DPAGErrorCoupling.errNoTicketOrRequest }
        if try couplingRequest.checkSignature(accountGuid: accountGuid) == false {
            // TODO: Fehlermeldung erzeugen...
            return
        }
        self.hasCouplingRequest = true
    }

    func getCouplingRequestInternal(transId: String) throws -> [Any]? {
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
        DPAGApplicationFacade.server.getCouplingRequest(transId: transId, withResponse: responseBlock)
        _ = semaphore.wait(timeout: .distantFuture)
        if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
            throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
        }
        return retVal
    }

    func confirmCouplingRequest() throws {
        guard let accountGuid = DPAGApplicationFacade.cache.account?.guid else { throw DPAGErrorCoupling.errNoAccountCrypto }
        guard let accountCrypto = DPAGCryptoHelper.newAccountCrypto() else { throw DPAGErrorCoupling.errNoAccountCrypto }
        guard let couplingRequest = self.couplingRequest, self.couplingTicket != nil else { throw DPAGErrorCoupling.errNoTicketOrRequest }
        if try couplingRequest.checkSignature(accountGuid: accountGuid) == false {
            throw DPAGErrorCoupling.errSignature
        }
        guard let transId = self.couplingTransId else { throw DPAGErrorCoupling.errNoTransId }
        let device = couplingRequest.publicKey
        let deviceKeySig = try accountCrypto.signData256(data: device)
        let backup = try DPAGApplicationFacade.backupWorker.createMiniBackup(tempDevice: self.getCouplingTempDevice())
        let encryptionGCM = try CryptoHelperEncrypter.encryptGCM(string: backup)
        let kekIV = encryptionGCM.iv
        guard let aesKey = ["key": encryptionGCM.key, "iv": encryptionGCM.iv, "aad": encryptionGCM.aad, "authTag": encryptionGCM.authTag].JSONString else { throw DPAGErrorCoupling.errToJson }
        let kek = try CryptoHelperEncrypter.encrypt(string: aesKey, withPublicKey: device)
        let appData = couplingRequest.appData
        let signaturePre = transId + device + deviceKeySig
        let signaturePost = encryptionGCM.encryptedString + appData
        let concatSignature = signaturePre + (kek + kekIV) + signaturePost
        let signature = try accountCrypto.signData256(data: concatSignature)
        _ = try self.responseCoupling(transId: transId, device: device, devKeySig: deviceKeySig, kek: kek, kekIV: kekIV, encSyncData: encryptionGCM.encryptedString, appData: appData, signature: signature)
        if self.getCouplingTempDevice() {
            try self.addTempDeviceInfo()
        }
    }

    func responseCoupling(transId: String, device publicKey: String, devKeySig verifyData: String, kek aesKey: String, kekIV aesKeyIV: String, encSyncData minibackup: String, appData: String, signature sig: String) throws -> [Any]? {
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
        DPAGApplicationFacade.server.responseCoupling(transId: transId, device: publicKey, devKeySig: verifyData, key: aesKey, keyIV: aesKeyIV, encSyncData: minibackup, appData: appData, signature: sig, withResponse: responseBlock)
        _ = semaphore.wait(timeout: .distantFuture)
        if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
            throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
        }
        return retVal
    }

    func getCouplingResponse() throws -> Bool {
        guard let couplingAccount = self.couplingAccount, let couplingTransId = self.couplingTransId else { return false }
        guard let rc = try self.getCouplingResponseInternal(accountGuid: couplingAccount.guid, transaktionId: couplingTransId) as? [[AnyHashable: Any]] else { return false }
        for dict in rc {
            if let dictCRESP = dict["CRESP"] as? [AnyHashable: Any] {
                let response = DPAGCouplingCouplingResponse(data: dictCRESP)
                self.couplingResponse = response
                break
            }
        }
        guard let couplingResponse = self.couplingResponse else { return false }
        if try couplingResponse.checkSignature(accountPublicKey: couplingAccount.publicKey) == false {
            return false
        }
        return true
    }

    func getCouplingResponseInternal(accountGuid: String, transaktionId: String) throws -> [Any]? {
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
        DPAGApplicationFacade.server.getCouplingResponse(accountGuid: accountGuid, transId: transaktionId, withResponse: responseBlock)
        _ = semaphore.wait(timeout: .distantFuture)
        if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
            throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
        }
        return retVal
    }

    func createDevice() throws -> Bool {
        guard let couplingResponse = self.couplingResponse, let couplingAccount = self.couplingAccount, let couplingDevice = self.couplingDevice, let couplingTransId = self.couplingTransId else { return false }
        if try couplingResponse.checkSignature(accountPublicKey: couplingAccount.publicKey) == false {
            return false
        }
        let aesKey = try CryptoHelper.sharedInstance?.decryptWithPrivateKey(encryptedString: couplingResponse.kek)
        guard let aesKeyData = aesKey?.data(using: .utf8) else { return false }
        guard let jsonData = try JSONSerialization.jsonObject(with: aesKeyData, options: .allowFragments) as? [AnyHashable: Any] else { return false }
        let minibackup = try CryptoHelperDecrypter.decryptGCM(encryptedString: couplingResponse.encSyncData, withAesKeyDict: jsonData)
        guard let pubKey = CryptoHelper.sharedInstance?.publicKey else { return false }
        guard let encodedDeviceName = self.deviceName?.data(using: .utf8)?.base64EncodedString(options: .lineLength76Characters) else { return false }
        try DPAGApplicationFacade.backupWorker.recoverMiniBackup(miniBackup: minibackup, accountGuid: couplingAccount.guid, deviceGuid: couplingDevice.guid, deviceName: encodedDeviceName, publicKey: pubKey, publicKeyFingerPrint: couplingResponse.publicKeySig, transId: couplingTransId)
        try DPAGApplicationFacade.server.setDeviceData()
        if self.enabledPassword == false {
            DPAGApplicationFacade.preferences.passwordOnStartEnabled = false
            try CryptoHelper.sharedInstance?.putDecryptedPKFromHeapInKeyChain()
        }
        DPAGApplicationFacade.preferences.simsmeRecoveryEnabled = true
        DPAGApplicationFacade.preferences.setHasPendingMessages(pending: true)
        try DPAGApplicationFacade.couplingWorker.fetchPendingMessagesForPreview()
        DispatchQueue.global(qos: .background).async {
            DPAGApplicationFacade.couplingWorker.fetchPendingMessages()
            do {
                try DPAGApplicationFacade.backupWorker.loadTimedMessages()
            } catch {
                DPAGLog("error loadTimedMessages: \(error)")
            }
        }
        return true
    }

    func getCouplingAccountGuid() -> String? {
        self.couplingAccount?.guid
    }

    func getCouplingDeviceName() -> String? {
        guard let appDataJson = self.couplingRequest?.appData, let appData = appDataJson.data(using: .utf8), let jsonData = try? JSONSerialization.jsonObject(with: appData, options: .allowFragments), let jsonDataDict = jsonData as? [AnyHashable: Any] else { return nil }
        if let name = jsonDataDict["deviceName"] as? String, let decodedNameData = Data(base64Encoded: name, options: .ignoreUnknownCharacters) {
            let decodedName = String(data: decodedNameData, encoding: .utf8)
            return decodedName
        }
        return nil
    }

    func getCouplingDeviceOs() -> String? {
        guard let appDataJson = self.couplingRequest?.appData, let appData = appDataJson.data(using: .utf8), let jsonData = try? JSONSerialization.jsonObject(with: appData, options: .allowFragments), let jsonDataDict = jsonData as? [AnyHashable: Any] else { return nil }
        return jsonDataDict["deviceOs"] as? String
    }

    func getCouplingTempDevice() -> Bool {
        if let reqType = self.couplingRequest?.reqType, reqType == "0x0201" || reqType == "untrusted" {
            return true
        }
        return false
    }

    func getCouplingDeviceGuid() -> String? {
        guard let appDataJson = self.couplingRequest?.appData, let appData = appDataJson.data(using: .utf8), let jsonData = try? JSONSerialization.jsonObject(with: appData, options: .allowFragments), let jsonDataDict = jsonData as? [AnyHashable: Any] else { return nil }
        return jsonDataDict["deviceGuid"] as? String
    }

    func fetchPendingMessages() {
        do {
            try self.fetchPendingMessagesIntern()
        } catch {
            DPAGLog(error)
        }
    }

    func fetchPendingMessagesForPreview() throws {
        let pendingGuids = self.couplingDAO.getPendingMessageGuidsForPreview()
        guard pendingGuids.isEmpty == false else { return }
        guard let messages = try self.getMessages(guids: pendingGuids.joined(separator: ",")) as? [[AnyHashable: Any]] else { return }
        self.couplingDAO.savePendingMessages(messages: messages)
    }

    func fetchPendingMessagesIntern() throws {
        let pendingGuids = try self.couplingDAO.getPendingMessageGuids()
        guard pendingGuids.isEmpty == false else {
            DPAGApplicationFacade.preferences.setHasPendingMessages(pending: false)
            return
        }
        guard let messages = try self.getMessages(guids: pendingGuids.joined(separator: ",")) as? [[AnyHashable: Any]] else { return }
        let foundGuids = self.couplingDAO.savePendingMessages(messages: messages)
        if pendingGuids.count > foundGuids.count {
            let removableGuids = pendingGuids.filter { foundGuids.contains($0) == false }
            self.couplingDAO.removeRemovablePendingMessageGuids(removableGuids: removableGuids)
        }
        DispatchQueue.global(qos: .background).async {
            DPAGApplicationFacade.couplingWorker.fetchPendingMessages()
        }
    }

    func getMessages(guids: String) throws -> [Any]? {
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
        DPAGApplicationFacade.server.getMessages(guids: guids, withResponse: responseBlock)
        _ = semaphore.wait(timeout: .distantFuture)
        if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
            throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
        }
        return retVal
    }

    func setDeviceNameInternal(guid: String, deviceName deviceNameEncoded: String) throws -> [Any]? {
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
                errorMessageBlock = errorMessage
                errorCodeBlock = errorCode
            } else if let rc = responseObject as? [Any] {
                retVal = rc
            }
        }
        DPAGApplicationFacade.server.setDeviceName(guid: guid, deviceName: deviceNameEncoded, withResponse: responseBlock)
        _ = semaphore.wait(timeout: .distantFuture)
        if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
            throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
        }
        return retVal
    }

    func addTempDeviceInfo() throws {
        guard let accountGuid = DPAGApplicationFacade.cache.account?.guid, let contact = DPAGApplicationFacade.cache.contact(for: accountGuid), let contactPublicKey = contact.publicKey else { throw DPAGErrorCoupling.errNoAccountPublicKey }
        guard let accountCrypto = DPAGCryptoHelper.newAccountCrypto() else { throw DPAGErrorCoupling.errNoAccountCrypto }
        guard let rc = try self.getTempDeviceInfoInternal(guid: accountGuid) as? [[AnyHashable: Any]] else { return }
        var deviceInfos: DPAGTempDeviceInfos?
        if rc.count == 1, let dataTempDevice = rc.first, let deviceInfosTmp = DPAGTempDeviceInfos(data: dataTempDevice) {
            if try deviceInfosTmp.checkSignature(accountPublicKey: contactPublicKey) {
                deviceInfos = deviceInfosTmp
            }
        }
        guard let couplingRequest = self.couplingRequest, let couplingDeviceGuid = self.getCouplingDeviceGuid() else { throw DPAGErrorCoupling.errNoTicketOrRequest }
        let now = Date()
        let end = now.addingHours(6)
        let di = DPAGTempDeviceInfo(guid: couplingDeviceGuid, pubKey: couplingRequest.publicKey, fingerprint: couplingRequest.publicKey.sha256(), type: "0x0201", start: DPAGFormatter.dateServer.string(from: now), end: DPAGFormatter.dateServer.string(from: end))
        let startTime = di.start
        let endTime = di.end
        var keys: [[AnyHashable: Any]] = []
        if let deviceInfos = deviceInfos {
            for di2 in deviceInfos.existingDevices {
                keys.append(di2.getExternalJson())
            }
        }
        keys.append(di.getExternalJson())
        guard let jsonString = keys.JSONString else { throw DPAGErrorCoupling.errToJson }
        let concatString = jsonString + startTime + endTime
        let signature = try accountCrypto.signData256(data: concatString)
        _ = try self.setTempDeviceInfoInternal(keys: jsonString, createdAt: startTime, nextUpdate: endTime, sig: signature)
        self.fetchOwnTempDevice()
    }

    func setTempDeviceInfoInternal(keys: String, createdAt createdAtString: String, nextUpdate nextUpdateString: String, sig signature: String) throws -> [Any]? {
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
                errorMessageBlock = errorMessage
                errorCodeBlock = errorCode
            } else if let rc = responseObject as? [Any] {
                retVal = rc
            }
        }
        DPAGApplicationFacade.server.setTempDeviceInfo(keys: keys, createdAt: createdAtString, nextUpdate: nextUpdateString, sig: signature, withResponse: responseBlock)
        _ = semaphore.wait(timeout: .distantFuture)
        if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
            throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
        }
        return retVal
    }

    func getTempDeviceInfoInternal(guid: String) throws -> [Any]? {
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
                errorMessageBlock = errorMessage
                errorCodeBlock = errorCode
            } else if let rc = responseObject as? [Any] {
                retVal = rc
            }
        }
        DPAGApplicationFacade.server.getTempDeviceInfo(accountGuid: guid, withResponse: responseBlock)
        _ = semaphore.wait(timeout: .distantFuture)
        if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
            throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
        }
        return retVal
    }

    func deleteTempDevice(guid: String) throws {
        guard let accountGuid = DPAGApplicationFacade.cache.account?.guid, let contact = DPAGApplicationFacade.cache.contact(for: accountGuid), let contactPublicKey = contact.publicKey else { throw DPAGErrorCoupling.errNoAccountPublicKey }
        guard let rc = try self.getTempDeviceInfoInternal(guid: accountGuid) as? [[AnyHashable: Any]] else { return }
        guard let accountCrypto = DPAGCryptoHelper.newAccountCrypto() else { throw DPAGErrorCoupling.errNoAccountCrypto }
        var deviceInfos: DPAGTempDeviceInfos?
        if rc.count == 1, let data = rc.first, let deviceInfosTmp = DPAGTempDeviceInfos(data: data), try deviceInfosTmp.checkSignature(accountPublicKey: contactPublicKey) {
            deviceInfos = deviceInfosTmp
        }
        let now = Date()
        let startTime = DPAGFormatter.dateServer.string(from: now)
        let end = now.addingHours(6)
        let endTime = DPAGFormatter.dateServer.string(from: end)
        var keys: [[AnyHashable: Any]] = []
        if let deviceInfos = deviceInfos {
            for di2 in deviceInfos.existingDevices {
                if di2.guid == guid, let dateEnd = DPAGFormatter.dateServer.date(from: di2.end) {
                    if now.minutes(before: dateEnd) != 0 {
                        di2.end = startTime
                    }
                }
                keys.append(di2.getExternalJson())
            }
        }
        guard let jsonString = keys.JSONString else { throw DPAGErrorCoupling.errToJson }
        let concatString = jsonString + startTime + endTime
        let signature = try accountCrypto.signData256(data: concatString)
        _ = try self.setTempDeviceInfoInternal(keys: jsonString, createdAt: startTime, nextUpdate: endTime, sig: signature)
        self.fetchOwnTempDevice()
    }

    func fetchOwnTempDevice() {
        guard let ownAccountGuid = DPAGApplicationFacade.cache.account?.guid else { return }
        let responseBlock: DPAGServiceResponseBlock = { responseObject, _, errorMessage in
            if let errorMessage = errorMessage {
                DPAGLog(errorMessage)
            } else if let dict = (responseObject as? [AnyHashable: Any])?["Account"] as? [AnyHashable: Any] {
                guard let accountGuid = DPAGApplicationFacade.cache.account?.guid, let contact = DPAGApplicationFacade.cache.contact(for: accountGuid), let contactPublicKey = contact.publicKey else { return }
                guard let tempDeviceGuid = dict["tempDeviceGuid"] as? String, let publickKey = dict["publicKeyTempDevice"] as? String, let pkSign256 = dict["pkSign256TempDevice"] as? String else {
                    DPAGApplicationFacade.cache.ownTempDeviceGuid = nil
                    DPAGApplicationFacade.cache.ownTempDevicePublicKey = nil
                    return
                }
                guard publickKey.isEmpty == false, pkSign256.isEmpty == false else {
                    DPAGApplicationFacade.cache.ownTempDeviceGuid = nil
                    DPAGApplicationFacade.cache.ownTempDevicePublicKey = nil
                    return
                }
                do {
                    if try CryptoHelperVerifier.verifyData256(data: publickKey, withSignature: pkSign256, forPublicKey: contactPublicKey) == false {
                        DPAGApplicationFacade.cache.ownTempDeviceGuid = nil
                        DPAGApplicationFacade.cache.ownTempDevicePublicKey = nil
                    } else {
                        DPAGApplicationFacade.cache.ownTempDeviceGuid = tempDeviceGuid
                        DPAGApplicationFacade.cache.ownTempDevicePublicKey = publickKey
                    }
                } catch {
                    DPAGApplicationFacade.cache.ownTempDeviceGuid = nil
                    DPAGApplicationFacade.cache.ownTempDevicePublicKey = nil
                }
            }
        }
        DPAGApplicationFacade.server.getAccountInfo(guid: ownAccountGuid, withProfile: false, withTempDevice: true, withResponse: responseBlock)
    }

    func checkTempSignature(accountGuid: String, accountPublicKey: String, deviceGuid fromTempDeviceGuid: String, signatureHashes signHashes: String, signatureTempDevice: String, dateSendServer: Date) throws -> Bool {
        var diTmp = DPAGApplicationFacade.cache.getTempDeviceInfo(guid: fromTempDeviceGuid)
        if diTmp == nil {
            guard let rc = try self.getTempDeviceInfoInternal(guid: accountGuid) as? [[AnyHashable: Any]] else { return false }
            guard rc.count == 1, let data = rc.first, let deviceInfos = DPAGTempDeviceInfos(data: data), try deviceInfos.checkSignature(accountPublicKey: accountPublicKey) else { return false }
            for deviceInfo in deviceInfos.existingDevices {
                DPAGApplicationFacade.cache.addTempDeviceInfo(guid: deviceInfo.guid, tempDevice: deviceInfo)
                if deviceInfo.guid == fromTempDeviceGuid {
                    diTmp = deviceInfo
                    break
                }
            }
        }
        guard let di = diTmp, let dateStart = DPAGFormatter.dateServer.date(from: di.start), let dateEnd = DPAGFormatter.dateServer.date(from: di.end) else { return false }
        if dateSendServer.isEarlierThan(date: dateStart) {
            return false
        }
        if dateSendServer.isLaterThan(date: dateEnd) {
            return false
        }
        return try CryptoHelperVerifier.verifyData256(data: signHashes, withSignature: signatureTempDevice, forPublicKey: di.pubKey)
    }

    func savePrivateIndexToServer() {
        if self.isSavingPrivateIndex {
            self.restartSavePrivateIndex = true
            return
        }
        guard let accountState = DPAGApplicationFacade.cache.account?.accountState else { return }
        if accountState == .unknown || accountState == .recoverBackup {
            return
        }
        DPAGFunctionsGlobal.synchronized(self) {
            defer {
                self.isSavingPrivateIndex = false
                if self.restartSavePrivateIndex {
                    self.restartSavePrivateIndex = false
                    DispatchQueue.global(qos: .background).async { [weak self] in
                        Thread.sleep(forTimeInterval: 1)
                        self?.savePrivateIndexToServer()
                    }
                }
            }
            self.isSavingPrivateIndex = true
            let contactInformationsForSave = self.couplingDAO.getContactInformationForPrivateIndexSave()
            var contactChecksums: [String: String] = [:]
            contactInformationsForSave.forEach { contactGuid, contactInformationForSave in
                do {
                    DPAGLog("calling insUpdPrivateIndex %@", contactGuid)
                    if let checksumArr = try self.insUpdPrivateIndexEntry(data: contactInformationForSave) as? [String], let checksum = checksumArr.first {
                        contactChecksums[contactGuid] = checksum
                    }
                } catch {
                    DPAGLog(error)
                }
            }
            self.couplingDAO.updateContactChecksums(contactChecksums: contactChecksums)
        }
    }

    private func insUpdPrivateIndexEntry(data: [String: String]) throws -> [Any]? {
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
                errorMessageBlock = errorMessage
                errorCodeBlock = errorCode
            } else if let rc = responseObject as? [Any] {
                retVal = rc
            }
        }
        DPAGApplicationFacade.server.insUpdPrivateIndex(data: data, withResponse: responseBlock)
        _ = semaphore.wait(timeout: .distantFuture)
        if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
            throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
        }
        return retVal
    }

    func loadPrivateIndexFromServer(ifModifiedSince: String?, forceLoad: Bool) throws {
        guard let accountGuid = DPAGApplicationFacade.cache.account?.guid, let contact = DPAGApplicationFacade.cache.contact(for: accountGuid), let contactPublicKey = contact.publicKey else { return }
        guard let accountCrypto = DPAGCryptoHelper.newAccountCrypto() else { throw DPAGErrorCoupling.errNoAccountCrypto }
        do {
            guard let serverContacts = try self.listPrivateIndexEntries(ifModifiedSince: ifModifiedSince) as? [[AnyHashable: Any]] else { return }
            let serverContactsFiltered = try self.filterServerPrivateIndexEntries(serverContacts: serverContacts, accountCrypto: accountCrypto, accountPublicKey: contactPublicKey)
            let privateIndexGuidsToDelete = try self.couplingDAO.savePrivateIndexServerEntries(serverContacts: serverContactsFiltered, forceLoad: forceLoad)
            if privateIndexGuidsToDelete.isEmpty == false {
                _ = try self.deletePrivateIndexEntries(guids: Array(privateIndexGuidsToDelete))
                DPAGLog("Deleted private index entries with guid: \(privateIndexGuidsToDelete)")
            }
        } catch {
            DPAGLog(error)
        }
    }

    private func filterServerPrivateIndexEntries(serverContacts: [[AnyHashable: Any]], accountCrypto: CryptoHelperAccount, accountPublicKey: String) throws -> [CouplingDAOPrivateIndexServerEntryDecrypted] {
        var validEntries: [String: CouplingDAOPrivateIndexServerEntryDecrypted] = [:]
        for entry in serverContacts {
            guard let innerDict = entry["PrivateIndexEntry"] as? [AnyHashable: Any] else { continue }
            if innerDict["dateDeleted"] as? String != nil {
                DPAGLog("Contact private index skipped on dateDeleted not nil.")
                continue
            }
            guard let keyData = innerDict["key-data"] as? String, let keyIv = innerDict["key-iv"] as? String, let data = innerDict["data"] as? String else {
                DPAGLog("Contact private index skipped on getting data and keys.")
                continue
            }
            let guid = innerDict["guid"] as? String
            let checksum = innerDict["data-checksum"] as? String
            var dateModified: Date?
            if let dateModifiedStr = innerDict["dateModified"] as? String {
                dateModified = DPAGFormatter.dateServer.date(from: dateModifiedStr) ?? DPAGFormatter.date.date(from: dateModifiedStr)
            }
            guard let signature = innerDict["signature"] as? String else {
                DPAGLog("Contact private index skipped on getting signature.")
                continue
            }
            if try CryptoHelperVerifier.verifyDataRaw256(data: data, withSignature: signature, forPublicKey: accountPublicKey) == false {
                DPAGLog("Contact private index skipped on data verification")
                continue
            }
            let aesKey = try accountCrypto.decryptWithPrivateKey(encryptedString: keyData)
            let aesKeyDict = ["key": aesKey, "iv": keyIv]
            let decryptEntry = try CryptoHelperDecrypter.decrypt(encryptedString: data, withAesKeyDict: aesKeyDict)
            guard let jsonData = try? JSONSerialization.jsonObject(with: decryptEntry, options: .allowFragments), let jsonDataDict = jsonData as? [AnyHashable: Any] else {
                DPAGLog("Contact private index skipped on data getting decrypted json")
                continue
            }
            guard let accountGuid = jsonDataDict["accountGuid"] as? String else {
                DPAGLog("Contact private index skipped on getting accountGuid")
                continue
            }
            let newEntry = CouplingDAOPrivateIndexServerEntryDecrypted(accountGuid: accountGuid, checksum: checksum, guid: guid, dateModified: dateModified, innerDict: innerDict, jsonDataDict: jsonDataDict)
            if let existingEntry = validEntries[accountGuid], self.shouldSkipDuplicatedEntry(existingEntry: existingEntry, duplicatedEntry: newEntry) {
                continue
            }
            validEntries[accountGuid] = newEntry
        }
        return Array(validEntries.values)
    }

    func shouldSkipDuplicatedEntry(existingEntry: CouplingDAOPrivateIndexServerEntryDecrypted, duplicatedEntry: CouplingDAOPrivateIndexServerEntryDecrypted) -> Bool {
        guard let dateModifiedDuplicated = duplicatedEntry.dateModified else {
            DPAGLog("Contact private index skipped on missing dateModified on duplicate")
            return true
        }
        guard let dateModifiedExisting = existingEntry.dateModified else {
            DPAGLog("Contact private index replaced on missing dateModified on existing")
            return false
        }
        let duplicateIsOlder = dateModifiedExisting > dateModifiedDuplicated
        if duplicateIsOlder {
            DPAGLog("Contact private index skipped on earlier dateModified on duplicate")
        } else {
            DPAGLog("Contact private index replaced on earlier dateModified on existing")
        }
        return duplicateIsOlder
    }

    func listPrivateIndexEntries(ifModifiedSince: String?) throws -> [Any]? {
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
                errorMessageBlock = errorMessage
                errorCodeBlock = errorCode
            } else if let rc = responseObject as? [Any] {
                retVal = rc
            }
        }
        DPAGApplicationFacade.server.listPrivateIndexEntries(ifModifiedSince: ifModifiedSince, withResponse: responseBlock)
        _ = semaphore.wait(timeout: .distantFuture)
        if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
            throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
        }
        return retVal
    }

    func getPrivateIndexEntries(guids: [String]) throws -> [Any]? {
        DPAGLog("Fetch PrivateIndex :%@", guids)
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
                errorMessageBlock = errorMessage
                errorCodeBlock = errorCode
            } else if let rc = responseObject as? [Any] {
                retVal = rc
            }
        }
        DPAGApplicationFacade.server.getPrivateIndexEntries(guids: guids.joined(separator: ","), withResponse: responseBlock)
        _ = semaphore.wait(timeout: .distantFuture)
        if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
            throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
        }
        return retVal
    }

    func fetchPrivateIndexEntries(entries: [String: String]) throws {
        guard let accountGuid = DPAGApplicationFacade.cache.account?.guid, let contact = DPAGApplicationFacade.cache.contact(for: accountGuid), let contactPublicKey = contact.publicKey else { return }
        guard let accountCrypto = DPAGCryptoHelper.newAccountCrypto() else { throw DPAGErrorCoupling.errNoAccountCrypto }
        guard self.isSavingPrivateIndex == false else { return }
        do {
            let result = try self.couplingDAO.checkForChangesOnContacts(contactPrivateIndexGuidsAndServerChecksums: entries)
            if result.foundLocalChanges {
                self.savePrivateIndexToServer()
            }
            if result.foundAllGuids {
                return
            }
            guard let serverContacts = try self.getPrivateIndexEntries(guids: Array(entries.keys)) as? [[AnyHashable: Any]] else { return }
            let serverContactsFiltered = try self.filterServerPrivateIndexEntries(serverContacts: serverContacts, accountCrypto: accountCrypto, accountPublicKey: contactPublicKey)
            let privateIndexGuidsToDelete = try self.couplingDAO.savePrivateIndexServerEntries(serverContacts: serverContactsFiltered, forceLoad: false)
            if privateIndexGuidsToDelete.isEmpty == false {
                _ = try self.deletePrivateIndexEntries(guids: Array(privateIndexGuidsToDelete))
                DPAGLog("Deleted private index entries with guid: \(privateIndexGuidsToDelete)")
            }
        } catch {
            DPAGLog(error)
        }
    }

    func deletePrivateIndexEntries(guids: [String]) throws -> [Any]? {
        DPAGLog("Fetch PrivateIndex :%@", guids)
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
                errorMessageBlock = errorMessage
                errorCodeBlock = errorCode
            } else if let rc = responseObject as? [Any] {
                retVal = rc
            }
        }
        DPAGApplicationFacade.server.deletePrivateIndexEntries(guids: guids.joined(separator: ","), withResponse: responseBlock)
        _ = semaphore.wait(timeout: .distantFuture)
        if let errorMessage = errorMessageBlock, let errorCode = errorCodeBlock {
            throw DPAGErrorCoupling.errServer(errorCode: errorCode, errorMessage: errorMessage)
        }
        return retVal
    }
}
