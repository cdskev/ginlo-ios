//
//  DPAGProfileWorker.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 17.10.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

public protocol DPAGProfileWorkerProtocol: AnyObject {
    func emailAddressConfirmed() -> String?
    func saveAvailableEmailAddressConfirmationTries(triesLeft: Int)

    func phoneNumberConfirmed() -> String?
    func saveAvailablePhoneNumberConfirmationTries(triesLeft: Int)

    func getCompanyInfo(withResponse responseBlock: DPAGServiceResponseBlock?)

    func loadStatusMessages() -> [String]

    func setAutoGenerateConfirmReadMessage(enabled: Bool, withResponse responseBlock: @escaping DPAGServiceResponseBlock)
    func setPublicOnlineState(enabled: Bool, withResponse responseBlock: DPAGServiceResponseBlock?)

    func checkForOwnOooStatus(completion: @escaping DPAGCompletion)

    func setIsWriting(accountGuid: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock)
    func resetIsWriting(accountGuid: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock)
    func getOnlineState(accountGuid: String, lastKnownState: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock)
}

class DPAGProfileWorker: DPAGProfileWorkerProtocol {
    let accountDAO: AccountDAOProtocol = AccountDAO()

    func setIsWriting(accountGuid: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.setIsWriting(accountGuid: accountGuid, withResponse: responseBlock)
    }

    func resetIsWriting(accountGuid: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.resetIsWriting(accountGuid: accountGuid, withResponse: responseBlock)
    }

    func getOnlineState(accountGuid: String, lastKnownState: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.getOnlineState(accountGuid: accountGuid, lastKnownState: lastKnownState, withResponse: responseBlock)
    }

    func checkForOwnOooStatus(completion: @escaping DPAGCompletion) {
        guard let ownGuid = DPAGApplicationFacade.cache.account?.guid, DPAGApplicationFacade.preferences.checkForOwnOooStatus() else {
            return
        }

        DPAGApplicationFacade.server.getOnlineStateBatch(guids: [ownGuid]) { response, _, _ in
            guard response != nil else { return }

            DPAGApplicationFacade.preferences.updateCheckForOwnOooStatus()

            guard let result = response as? [[String: Any]] else {
                return
            }

            var found = false

            for stateObject in result {
                guard let accountGuid = stateObject["accountGuid"] as? String else {
                    continue
                }
                guard accountGuid == accountGuid else {
                    continue
                }

                guard let oooState = (stateObject["oooStatus"] as? [String: Any])?["statusState"] as? String, oooState == "ooo" else {
                    continue
                }

                found = true
                break
            }

            if found {
                completion()
            }
        }
    }

    func setAutoGenerateConfirmReadMessage(enabled: Bool, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.setAutoGenerateConfirmReadMessage(enabled: enabled, withResponse: responseBlock)
    }

    func setPublicOnlineState(enabled: Bool, withResponse responseBlock: DPAGServiceResponseBlock?) {
        DPAGApplicationFacade.server.setPublicOnlineState(enabled: enabled) { responseObject, errorCode, errorMessage in

            if errorMessage == nil {
                DPAGApplicationFacade.preferences.publicOnlineStateEnabled = enabled
            }

            responseBlock?(responseObject, errorCode, errorMessage)
        }
    }

    func loadStatusMessages() -> [String] {
        let accountStatusMessagesDAO: AccountStatusMessagesDAOProtocol = AccountStatusMessagesDAO()
        let accountStatusMessages = accountStatusMessagesDAO.loadStatusMessages()

        return accountStatusMessages
    }

    func getCompanyInfo(withResponse responseBlock: DPAGServiceResponseBlock?) {
        DPAGApplicationFacade.server.getCompanyInfo(withResponse: { [weak self] responseObject, errorCode, errorMessage in

            if errorMessage == nil, let dictCompany = (responseObject as? [AnyHashable: Any])?[DPAGStrings.JSON.Company.OBJECT_KEY] as? CompanyInfoDictionary {
                self?.accountDAO.setCompanyInfo(dictCompany)

                NotificationCenter.default.post(name: DPAGStrings.Notification.Menu.MENU_NEW_REINIT, object: nil)
            }

            responseBlock?(responseObject, errorCode, errorMessage)
        })
    }

    func phoneNumberConfirmed() -> String? {
        let rc = DPAGApplicationFacade.accountManager.confirmCompanyPhoneNumberStatus()

        DPAGApplicationFacade.preferences.didAskForCompanyPhoneNumber = true

        return rc
    }

    func saveAvailablePhoneNumberConfirmationTries(triesLeft: Int) {
        self.accountDAO.saveAvailablePhoneNumberConfirmationTries(triesLeft: triesLeft)
    }

    func saveAvailableEmailAddressConfirmationTries(triesLeft: Int) {
        self.accountDAO.saveAvailableEmailAddressConfirmationTries(triesLeft: triesLeft)
    }

    func emailAddressConfirmed() -> String? {
        let rc = DPAGApplicationFacade.accountManager.confirmCompanyEmailStatus()

        return rc
    }
}
