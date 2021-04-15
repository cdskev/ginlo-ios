//
//  DPAGSynchronizationHelper.swift
//  SIMSmeUIBaseLib
//
//  Created by Robert Burchert on 09.04.19.
//  Copyright © 2019 Deutsche Post AG. All rights reserved.
//

import SIMSmeCore
import UIKit
import Contacts

public class DPAGSynchronizationHelperAddressbook {
    private weak var progressHUDSyncInfo: DPAGProgressHUDWithLabelProtocol?

    public init() {}

    public func syncDomainAddressbook(completion: @escaping () -> Void) {
        self.progressHUDSyncInfo = DPAGProgressHUDWithLabel.sharedInstanceLabel.showForBackgroundProcess(true, completion: { [weak self] _ in
            guard self != nil else { return }
            do {
                try DPAGApplicationFacade.preferences.createSimsmeRecoveryBlobs()
            } catch {
                DPAGLog(error)
            }
            DPAGApplicationFacade.companyAdressbook.setOwnAdressInformation { [weak self] responseObject, _, errorMessage in
                if errorMessage != nil {
                    DPAGProgressHUDWithLabel.sharedInstanceLabel.hide(true, completion: completion)
                } else if responseObject != nil {
                    let observer = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfo, object: nil, queue: .main, using: { [weak self] aNotification in
                        self?.handleIndexSyncInfoDomain(aNotification)
                    })
                    if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), contact.eMailDomain != nil {
                        DPAGApplicationFacade.companyAdressbook.updateDomainIndexWithServer()
                    }
                    NotificationCenter.default.removeObserver(observer)
                    DPAGApplicationFacade.preferences.didAskForCompanyEmail = true
                    DPAGProgressHUDWithLabel.sharedInstanceLabel.hide(true, completion: completion)
                } else {
                    DPAGProgressHUDWithLabel.sharedInstanceLabel.hide(true, completion: completion)
                }
            }
        }) as? DPAGProgressHUDWithLabelProtocol
        self.progressHUDSyncInfo?.labelTitle.text = DPAGLocalizedString("settings.companyprofile.code.email.createSimsmeRecoveryBlobs")
    }

    public func syncDomainAndCompanyAddressbookNoHUD(completion: @escaping () -> Void, completionOnError: @escaping (String?, String) -> Void) {
        do {
            try DPAGApplicationFacade.preferences.createSimsmeRecoveryBlobs()
        } catch {
            DPAGLog(error)
        }
        DPAGApplicationFacade.companyAdressbook.setOwnAdressInformation { (responseObject: Any?, errorCode: String?, errorMessage: String?) in
            if let errorMessage = errorMessage {
                completionOnError(errorCode, errorMessage)
                return
            }
            if responseObject == nil {
                completionOnError("Invalid Response", "Invalid Response")
                return
            }
            var observer = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfo, object: nil, queue: .main, using: { aNotification in
                self.handleIndexSyncInfoDomain(aNotification)
            })
            if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), contact.eMailDomain != nil {
                DPAGApplicationFacade.companyAdressbook.updateDomainIndexWithServer()
            }
            NotificationCenter.default.removeObserver(observer)
            DPAGApplicationFacade.preferences.didAskForCompanyEmail = true
            if DPAGApplicationFacade.preferences.isCompanyManagedState {
                observer = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfo, object: nil, queue: .main, using: { aNotification in
                    self.handleIndexSyncInfoCompany(aNotification)
                })
                do {
                    self.progressHUDSyncInfo?.labelTitle.text = DPAGLocalizedString("companyAdressbook.waitForCompanyIndexInfo")
                    try DPAGApplicationFacade.companyAdressbook.waitForCompanyIndexInfo(timeInterval: TimeInterval(120))
                    DPAGApplicationFacade.companyAdressbook.updateCompanyIndexWithServer(cacheVersionCompanyIndexServer: "-")
                    NotificationCenter.default.post(name: DPAGStrings.Notification.Menu.MENU_NEW_REINIT, object: nil)
                } catch {
                    DPAGLog(error)
                }

                NotificationCenter.default.removeObserver(observer)
            }
            completion()
        }
    }

    public func syncDomainAndCompanyAddressbook(completion: @escaping () -> Void, completionOnError: @escaping (String?, String) -> Void) {
        self.progressHUDSyncInfo = DPAGProgressHUDWithLabel.sharedInstanceLabel.showForBackgroundProcess(true, completion: { [weak self] _ in
            guard self != nil else { return }
            self?.syncDomainAndCompanyAddressbookNoHUD(completion: { [] in
                DPAGProgressHUDWithLabel.sharedInstanceLabel.hide(true, completion: completion)
            }, completionOnError: { [] (errorCode: String?, errorMessage: String) in
                DPAGProgressHUDWithLabel.sharedInstanceLabel.hide(true, completion: { [] in
                    completionOnError(errorCode, errorMessage)
                })
            })
        }) as? DPAGProgressHUDWithLabelProtocol
        self.progressHUDSyncInfo?.labelTitle.text = DPAGLocalizedString("settings.companyprofile.code.email.createSimsmeRecoveryBlobs")
    }

    public func syncPrivateAddressbookNoHUD(completion: @escaping () -> Void) {
        if CNContactStore.authorizationStatus(for: .contacts) != .authorized {
            completion()
            return
        }
        let observer = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfo, object: nil, queue: .main, using: { aNotification in
            self.handleKnownContactsSyncInfo(aNotification)
        })
        DPAGApplicationFacade.updateKnownContactsWorker.initMandanten { _, _, _ in
            NotificationCenter.default.removeObserver(observer)
            completion()
        }
    }

    public func syncPrivateAddressbook(completion: @escaping () -> Void) {
        self.progressHUDSyncInfo = DPAGProgressHUDWithLabel.sharedInstanceLabel.showForBackgroundProcess(true, completion: { [weak self] _ in
            self?.syncPrivateAddressbookNoHUD(completion: { [] in
                DPAGProgressHUDWithLabel.sharedInstanceLabel.hide(true, completion: completion)
            })
        }) as? DPAGProgressHUDWithLabelProtocol
    }

    public func syncCompanyAddressbookNoHUD(completion: @escaping () -> Void) {
        if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), contact.eMailDomain != nil {
            let observerDomainIndexSync = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfo, object: nil, queue: .main, using: { aNotification in
                self.handleIndexSyncInfoDomain(aNotification)
            })
            DPAGApplicationFacade.companyAdressbook.updateDomainIndexWithServer()
            NotificationCenter.default.removeObserver(observerDomainIndexSync)
        }
        if DPAGApplicationFacade.preferences.isCompanyManagedState {
            let observerCompanyIndexSync = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfo, object: nil, queue: .main, using: { aNotification in
                self.handleIndexSyncInfoCompany(aNotification)
            })
            do {
                self.progressHUDSyncInfo?.labelTitle.text = DPAGLocalizedString("companyAdressbook.waitForCompanyIndexInfo")
                try DPAGApplicationFacade.companyAdressbook.waitForCompanyIndexInfo(timeInterval: TimeInterval(120))
                DPAGApplicationFacade.companyAdressbook.updateCompanyIndexWithServer(cacheVersionCompanyIndexServer: "-")
            } catch {
                DPAGLog(error)
            }
            NotificationCenter.default.removeObserver(observerCompanyIndexSync)
        }
       completion()
    }
    
    public func syncCompanyAddressbook(completion: @escaping () -> Void) {
        self.progressHUDSyncInfo = DPAGProgressHUDWithLabel.sharedInstanceLabel.showForBackgroundProcess(true, completion: { [weak self] _ in
            self?.syncCompanyAddressbookNoHUD(completion: { [] in
                DPAGProgressHUDWithLabel.sharedInstanceLabel.hide(true, completion: completion)
            })
        }) as? DPAGProgressHUDWithLabelProtocol
    }

    private func handleIndexSyncInfoDomain(_ aNotification: Notification) {
        self.handleIndexSyncInfo(aNotification, prefix: DPAGLocalizedString("companyAdressbook.syncDomainPre"))
    }

    private func handleIndexSyncInfoCompany(_ aNotification: Notification) {
        self.handleIndexSyncInfo(aNotification, prefix: DPAGLocalizedString("companyAdressbook.syncCompanyPre"))
    }

    private func handleIndexSyncInfo(_ aNotification: Notification, prefix: String) {
        guard let syncInfoState = aNotification.userInfo?[DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyState] as? DPAGCompanyAdressbookWorkerSyncInfoState else { return }
        guard let step = aNotification.userInfo?[DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyProgressStep] as? Int, let stepMax = aNotification.userInfo?[DPAGStrings.Notification.CompanyAdressbookWorker.SyncInfoKeyProgressMax] as? Int
        else {
            self.progressHUDSyncInfo?.labelTitle.text = prefix + ": " + DPAGLocalizedString("companyAdressbook.syncInfo." + syncInfoState.rawValue)
            return
        }
        self.progressHUDSyncInfo?.labelTitle.text = prefix + ": " + DPAGLocalizedString("companyAdressbook.syncInfo." + syncInfoState.rawValue) + " \(step)/\(stepMax)"
    }

    private func handleKnownContactsSyncInfo(_ aNotification: Notification) {
        guard let syncInfoState = aNotification.userInfo?[DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyState] as? DPAGUpdateKnownContactsWorkerSyncInfoState else { return }
        guard let step = aNotification.userInfo?[DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyProgressStep] as? Int else {
            self.progressHUDSyncInfo?.labelTitle.text = DPAGLocalizedString("updateKnownContacts.syncInfo." + syncInfoState.rawValue)
            return
        }
        guard let stepMax = aNotification.userInfo?[DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyProgressMax] as? Int else {
            self.progressHUDSyncInfo?.labelTitle.text = DPAGLocalizedString("updateKnownContacts.syncInfo." + syncInfoState.rawValue) + " \(step)"
            return
        }
        self.progressHUDSyncInfo?.labelTitle.text = DPAGLocalizedString("updateKnownContacts.syncInfo." + syncInfoState.rawValue) + " \(step)/\(stepMax)"
    }
}
