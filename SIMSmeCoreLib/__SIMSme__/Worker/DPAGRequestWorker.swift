//
//  DPAGRequestWorker.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 17.10.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

public protocol DPAGRequestWorkerProtocol: AnyObject {
    func requestSimsmeRecoveryKey(parameter: [AnyHashable: Any], response: @escaping DPAGServiceResponseBlock)

    func setSilentSingleChat(accountGuid: String, till: Date?, withResponse responseBlock: @escaping DPAGServiceResponseBlock)
    func setSilentGroupChat(groupGuid: String, till: Date?, withResponse responseBlock: @escaping DPAGServiceResponseBlock)

    func checkEmailAddress(eMailAddress: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock)

    func registerTestVoucher(withResponse responseBlock: @escaping DPAGServiceResponseBlock)

    func handleEvents(forBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void)
    func fetchBackgroundMessage(messageGuid: String, userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping ((_ result: UIBackgroundFetchResult) -> Void))

    func resetBadge(withResponse response: @escaping DPAGServiceResponseBlock)

    func setDeviceData() throws

    func getConfigVersions(withResponse responseBlock: @escaping DPAGServiceResponseBlock)
    func getConfiguration(withResponse responseBlock: @escaping DPAGServiceResponseBlock)
    func getCompanyLayout(withResponse responseBlock: @escaping DPAGServiceResponseBlock)
    func getCompanyConfig(withResponse responseBlock: @escaping DPAGServiceResponseBlock)
    func getCompanyLogo(withResponse responseBlock: @escaping DPAGServiceResponseBlock)

    func getMandanten(withResponse responseBlock: @escaping DPAGServiceResponseBlock)

    func requestEncryptionInfo(withResponse responseBlock: @escaping DPAGServiceResponseBlock)
    func createBackgroundAccessToken(withResponse response: @escaping DPAGServiceResponseBlock)
    func getTestVoucherInfo(withResponse responseBlock: @escaping DPAGServiceResponseBlock)
}

class DPAGRequestWorker: DPAGRequestWorkerProtocol {
    func getTestVoucherInfo(withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.getTestVoucherInfo(withResponse: responseBlock)
    }

    func createBackgroundAccessToken(withResponse response: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.createBackgroundAccessToken(withResponse: response)
    }

    func requestEncryptionInfo(withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.requestEncryptionInfo(withResponse: responseBlock)
    }

    func getMandanten(withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.getMandanten(withResponse: responseBlock)
    }

    func getCompanyLogo(withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.getCompanyLogo(withResponse: responseBlock)
    }

    func getCompanyConfig(withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.getCompanyConfig(withResponse: responseBlock)
    }

    func getCompanyLayout(withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.getCompanyLayout(withResponse: responseBlock)
    }

    func getConfiguration(withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.getConfiguration(withResponse: responseBlock)
    }

    func getConfigVersions(withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.getConfigVersions(withResponse: responseBlock)
    }

    func setDeviceData() throws {
        try DPAGApplicationFacade.server.setDeviceData()
    }

    func resetBadge(withResponse response: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.resetBadge(withResponse: response)
    }

    func fetchBackgroundMessage(messageGuid: String, userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping ((_ result: UIBackgroundFetchResult) -> Void)) {
        DPAGApplicationFacade.server.fetchBackgroundMessage(messageGuid: messageGuid, userInfo: userInfo, fetchCompletionHandler: completionHandler)
    }

    func handleEvents(forBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        DPAGApplicationFacade.server.handleEvents(forBackgroundURLSession: identifier, completionHandler: completionHandler)
    }

    func registerTestVoucher(withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.registerTestVoucher(withResponse: responseBlock)
    }

    func checkEmailAddress(eMailAddress: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.checkMailAddress(eMailAddress: eMailAddress, withResponse: responseBlock)
    }

    func setSilentSingleChat(accountGuid: String, till: Date?, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.setSilentSingleChat(accountGuid: accountGuid, till: DPAGFormatter.dateServer.string(from: till ?? Date.distantPast), withResponse: responseBlock)
    }

    func setSilentGroupChat(groupGuid: String, till: Date?, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.setSilentGroupChat(groupGuid: groupGuid, till: DPAGFormatter.dateServer.string(from: till ?? Date.distantPast), withResponse: responseBlock)
    }

    func requestSimsmeRecoveryKey(parameter: [AnyHashable: Any], response: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.requestSimsmeRecoveryKey(parameter: parameter, withResponse: response)
    }
}
