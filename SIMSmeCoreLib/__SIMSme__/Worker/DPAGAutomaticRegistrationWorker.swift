//
//  DPAGAutomaticRegistrationWorker.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 27.09.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

public enum DPAGErrorAutomaticRegistration: Error {
    case error(String)

    var localizedDescription: String {
        switch self {
            case let .error(errorMessage):
                return errorMessage
        }
    }
}

public protocol DPAGAutomaticRegistrationWorkerProtocol: AnyObject {
    func doStep1(registrationValues: DPAGAutomaticRegistrationPreferences, password: String) throws
    func doStep2(registrationValues: DPAGAutomaticRegistrationPreferences) throws
    func doStep3() throws
    func doStep4() throws -> [AnyHashable: Any]?
    func doStep5()
    func doStep6()
    func doStep7(registrationValues: DPAGAutomaticRegistrationPreferences) throws
}

class DPAGAutomaticRegistrationWorker: DPAGAutomaticRegistrationWorkerProtocol {
    let accountDAO: AccountDAOProtocol = AccountDAO()

    func doStep1(registrationValues: DPAGAutomaticRegistrationPreferences, password: String) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var innerData: [AnyHashable: Any] = [:]
        innerData["name"] = registrationValues.lastName
        innerData["firstname"] = registrationValues.firstName
        innerData["email"] = registrationValues.eMailAddress
        let dataDict = ["AdressInformation-v1": innerData]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dataDict, options: []) else { throw DPAGErrorAutomaticRegistration.error("service.ERR-0001") }
        guard let jsonObject = String(data: jsonData, encoding: .utf8) else { throw DPAGErrorAutomaticRegistration.error("service.ERR-0001") }
        if CryptoHelper.sharedInstance == nil {
            throw DPAGErrorAutomaticRegistration.error("service.ERR-0001")
        }
        let cockpitData = try CryptoHelperEncrypter.encyptAdressData(decryptedData: jsonObject, withToken: registrationValues.loginCode)
        guard let cockpitDataJson = try? JSONSerialization.data(withJSONObject: cockpitData, options: []) else { throw DPAGErrorAutomaticRegistration.error("service.ERR-0001") }
        guard let cockpitDataString = String(data: cockpitDataJson, encoding: .utf8) else { throw DPAGErrorAutomaticRegistration.error("service.ERR-0001") }
        var errorMessageBlock: String?
        _ = try DPAGApplicationFacade.accountManager.createAutomaticAccount(password: password, eMailAddress: registrationValues.eMailAddress, cockpitToken: registrationValues.loginCode, cockpitData: cockpitDataString, responseBlock: { responseObject, _, errorMessage in
            defer {
                semaphore.signal()
            }
            if let errorMessage = errorMessage {
                errorMessageBlock = errorMessage
            } else if let responseArr = responseObject as? [Any] {
                if responseArr.count != 1 {
                    errorMessageBlock = "service.ERR-0001"
                }
            } else {
                errorMessageBlock = "service.ERR-0001"
            }
        })
        _ = semaphore.wait(wallTimeout: .distantFuture)
        if let errorMessageBlock = errorMessageBlock {
            throw DPAGErrorAutomaticRegistration.error(errorMessageBlock)
        }
        accountDAO.setRecoverBackupState()
        DPAGApplicationFacade.preferences.migrationVersion = .versionCurrent
        DPAGCryptoHelper.resetAccountCrypto()
        DPAGApplicationFacade.cache.clearCache()
    }

    func doStep2(registrationValues: DPAGAutomaticRegistrationPreferences) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var domain: String?
        var errorMessageBlock: String?
        DPAGApplicationFacade.companyAdressbook.validateMailAddress(eMailAddress: registrationValues.eMailAddress) { responseObject, _, errorMessage in
            defer {
                semaphore.signal()
            }
            if let errorMessage = errorMessage {
                errorMessageBlock = errorMessage
            } else if let responseArr = responseObject as? [String] {
                if responseArr.count != 1 {
                    errorMessageBlock = "service.ERR-0001"
                } else {
                    domain = responseArr.first
                }
            } else {
                errorMessageBlock = "service.ERR-0001"
            }
        }
        _ = semaphore.wait(wallTimeout: .distantFuture)
        if let errorMessageBlock = errorMessageBlock {
            throw DPAGErrorAutomaticRegistration.error(errorMessageBlock)
        }
        DPAGApplicationFacade.accountManager.save(firstName: registrationValues.firstName, lastName: registrationValues.lastName)
        DPAGApplicationFacade.accountManager.save(eMailAddress: registrationValues.eMailAddress, eMailDomain: domain)
        _ = DPAGApplicationFacade.accountManager.confirmCompanyEmailStatus()
        DPAGApplicationFacade.companyAdressbook.setOwnAdressInformation { responseObject, _, errorMessage in
            defer {
                semaphore.signal()
            }
            if let errorMessage = errorMessage {
                errorMessageBlock = errorMessage
            } else if responseObject is [Any] {} else {
                errorMessageBlock = "service.ERR-0001"
            }
        }
        _ = semaphore.wait(wallTimeout: .distantFuture)
        if let errorMessageBlock = errorMessageBlock {
            throw DPAGErrorAutomaticRegistration.error(errorMessageBlock)
        }
    }

    func doStep3() throws {
        let semaphore = DispatchSemaphore(value: 0)
        var errorMessageBlock: String?
        DPAGApplicationFacade.server.getCompanyInfo { [weak self] responseObject, _, errorMessage in
            defer {
                semaphore.signal()
            }
            if let errorMessage = errorMessage {
                errorMessageBlock = errorMessage
            } else if let dictCompany = (responseObject as? [AnyHashable: Any])?[DPAGStrings.JSON.Company.OBJECT_KEY] as? [AnyHashable: Any] {
                self?.accountDAO.saveCompanyInfos(dictCompany: dictCompany)
            } else {
                errorMessageBlock = "service.ERR-0001"
            }
        }
        _ = semaphore.wait(wallTimeout: .distantFuture)
        if let errorMessageBlock = errorMessageBlock {
            throw DPAGErrorAutomaticRegistration.error(errorMessageBlock)
        }
        var accountStateManaged = DPAGAccountCompanyManagedState.unknown
        DPAGApplicationFacade.companyAdressbook.checkCompanyManagement { _, errorMessage, companyName, _, accountStateManagedBlock in
            defer {
                semaphore.signal()
            }
            if let errorMessage = errorMessage {
                errorMessageBlock = errorMessage
            } else if companyName != nil {
                accountStateManaged = accountStateManagedBlock
            } else {
                errorMessageBlock = "service.ERR-0001"
            }
        }
        _ = semaphore.wait(wallTimeout: .distantFuture)
        if let errorMessageBlock = errorMessageBlock {
            throw DPAGErrorAutomaticRegistration.error(errorMessageBlock)
        }
        if accountStateManaged != .accepted {
            throw DPAGErrorAutomaticRegistration.error("registration.ERR-9001")
        }
        try DPAGApplicationFacade.accountManager.ensureCompanyRecoveryPassword()
        DPAGApplicationFacade.preferences.isCompanyManagedState = true
        try DPAGApplicationFacade.companyAdressbook.waitForCompanyIndexInfo(timeInterval: TimeInterval(120))
        if let account = DPAGApplicationFacade.cache.account {
            if account.aesKeyCompany == nil {
                throw DPAGErrorAutomaticRegistration.error("registration.ERR-9002")
            }
            if account.aesKeyCompanyUserData == nil {
                throw DPAGErrorAutomaticRegistration.error("registration.ERR-9003")
            }
        }
    }

    func doStep4() throws -> [AnyHashable: Any]? {
        let semaphore = DispatchSemaphore(value: 0)
        var errorMessageBlock: String?
        DPAGApplicationFacade.server.getCompanyConfig { responseObject, _, errorMessage in
            defer {
                semaphore.signal()
            }
            if let errorMessage = errorMessage {
                errorMessageBlock = errorMessage
            } else if let responseDict = responseObject as? [AnyHashable: Any], let dict = responseDict["CompanyMdmConfig"] as? [AnyHashable: Any], let encryptedConfig = dict["data"] as? String, let iv = dict["iv"] as? String {
                if let account = DPAGApplicationFacade.cache.account {
                    do {
                        _ = try DPAGApplicationFacade.preferences.setCompanyConfig(encryptedConfig, iv: iv, companyAesKey: account.aesKeyCompany)
                    } catch {
                        errorMessageBlock = error.localizedDescription
                    }
                }
            }
        }
        _ = semaphore.wait(wallTimeout: .distantFuture)
        if let errorMessageBlock = errorMessageBlock {
            throw DPAGErrorAutomaticRegistration.error(errorMessageBlock)
        }
        var checksumLogo: String?
        var companyLayout: [AnyHashable: Any]?
        DPAGApplicationFacade.server.getCompanyLayout { responseObject, _, errorMessage in
            defer {
                semaphore.signal()
            }
            if let errorMessage = errorMessage {
                errorMessageBlock = errorMessage
            } else if let responseDict = responseObject as? [AnyHashable: Any] {
                guard let dict = responseDict["CompanyLayout"] as? [AnyHashable: Any] else { return }
                companyLayout = dict
                guard let logoDict = responseDict["CompanyLogo"] as? [AnyHashable: Any] else { return }
                if let checksumLogo1 = logoDict["checksum"] as? String {
                    checksumLogo = checksumLogo1
                }
            } else {
                errorMessageBlock = "service.ERR-0001"
            }
        }
        _ = semaphore.wait(wallTimeout: .distantFuture)
        if let errorMessageBlock = errorMessageBlock {
            throw DPAGErrorAutomaticRegistration.error(errorMessageBlock)
        }
        guard let checksumLogo2 = checksumLogo else { return companyLayout }
        DPAGApplicationFacade.server.getCompanyLogo { responseObject, _, errorMessage in
            defer {
                semaphore.signal()
            }
            if let errorMessage = errorMessage {
                errorMessageBlock = errorMessage
            } else if let responseDict = responseObject as? [AnyHashable: Any] {
                guard let dict = responseDict["CompanyLogo"] as? [AnyHashable: Any], let data = dict["data"] as? String else { return }
                DPAGApplicationFacade.preferences.setCompanyLogo(data, checksum: checksumLogo2)
                NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DESIGN_LOGO_UPDATED, object: nil)
            } else {
                errorMessageBlock = "service.ERR-0001"
            }
        }
        _ = semaphore.wait(wallTimeout: .distantFuture)
        if let errorMessageBlock = errorMessageBlock {
            throw DPAGErrorAutomaticRegistration.error(errorMessageBlock)
        }
        return companyLayout
    }

    func doStep5() {
        DPAGApplicationFacade.companyAdressbook.updateCompanyIndexWithServer(cacheVersionCompanyIndexServer: "-")
    }

    func doStep6() {
        DPAGApplicationFacade.companyAdressbook.updateDomainIndexWithServer()
    }

    func doStep7(registrationValues: DPAGAutomaticRegistrationPreferences) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var errorMessageBlock: String?
        let profileName = registrationValues.firstName + " " + registrationValues.lastName
        DPAGApplicationFacade.accountManager.initiate(nickName: profileName, firstName: registrationValues.firstName, lastName: registrationValues.lastName)
        let status = DPAGApplicationFacade.statusWorker.latestStatus()
        DPAGApplicationFacade.preferences.isInAppNotificationEnabled = true
        DPAGApplicationFacade.server.setPublicOnlineState(enabled: true) { _, _, errorMessage in
            if let errorMessage = errorMessage {
                errorMessageBlock = errorMessage
            }
        }
        DPAGSendInternalMessageWorker.broadcastProfilUpdate(nickname: profileName, status: status, image: nil, oooState: nil, oooStatusText: nil, oooStatusValid: nil) { _, _, errorMessage in
            defer {
                semaphore.signal()
            }
            if let errorMessage = errorMessage {
                errorMessageBlock = errorMessage
            }
        }
        if let errorMessageBlock = errorMessageBlock {
            throw DPAGErrorAutomaticRegistration.error(errorMessageBlock)
        }
        try DPAGApplicationFacade.devicesWorker.createShareExtensionDevice { _, _, errorMessage in
            if let errorMessage = errorMessage {
                errorMessageBlock = errorMessage
            }
        }
        if let errorMessageBlock = errorMessageBlock {
            throw DPAGErrorAutomaticRegistration.error(errorMessageBlock)
        }
        if let accountGuid = accountDAO.confirmAccount() {
            DPAGApplicationFacade.accountManager.updateAccountID(accountGuid: accountGuid)
        }
    }
}
