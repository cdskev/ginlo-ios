//
//  GNScanAddContactViewController.swift
//  SIMSmeUILib
//
//  Created by Imdat Solak on 06.09.21.
//  Copyright © 2021 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class GNScanAddContactViewController: DPAGViewControllerWithKeyboard {
    
    private func searchAccount(accountID: String) {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
            DPAGApplicationFacade.contactsWorker.searchAccount(searchData: accountID, searchMode: .accountID) { responseObject, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    if let errorMessage = errorMessage {
                        self?.presentErrorAlert(alertConfig: AlertConfigError(titleIdentifier: "attention", messageIdentifier: errorMessage))
                    } else if let guids = responseObject as? [String] {
                        if let account = DPAGApplicationFacade.cache.account, let contactSelf = DPAGApplicationFacade.cache.contact(for: account.guid) {
                            if guids.count > 1 {
                                let nextVC = DPAGApplicationFacadeUIContacts.contactNewSelectVC(contactGuids: guids)
                                self?.navigationController?.pushViewController(nextVC, animated: true)
                            } else if let guid = guids.first, let contactCache = DPAGApplicationFacade.cache.contact(for: guid) {
                                switch contactCache.entryTypeServer {
                                    case .company:
                                        let nextVC = DPAGApplicationFacadeUIContacts.contactDetailsVC(contact: contactCache)
                                        self?.navigationController?.pushViewController(nextVC, animated: true)
                                    case .email:
                                        if contactCache.eMailDomain == contactSelf.eMailDomain {
                                            let nextVC = DPAGApplicationFacadeUIContacts.contactDetailsVC(contact: contactCache)
                                            self?.navigationController?.pushViewController(nextVC, animated: true)
                                        } else {
                                            let nextVC = DPAGApplicationFacadeUIContacts.contactNewCreateVC(contact: contactCache)
                                            self?.navigationController?.pushViewController(nextVC, animated: true)
                                        }
                                    case .meMyselfAndI:
                                        break
                                    case .privat:
                                        let nextVC = DPAGApplicationFacadeUIContacts.contactNewCreateVC(contact: contactCache)
                                        self?.navigationController?.pushViewController(nextVC, animated: true)
                                }
                            } else {
                                let nextVC = DPAGApplicationFacadeUIContacts.contactNotFoundVC(searchData: accountID, searchMode: .accountID)
                                self?.navigationController?.pushViewController(nextVC, animated: true)
                            }
                        } else {
                            let nextVC = DPAGApplicationFacadeUIContacts.contactNotFoundVC(searchData: accountID, searchMode: .accountID)
                            self?.navigationController?.pushViewController(nextVC, animated: true)
                        }
                    }
                }
            }
        }
    }

}
