//
//  DPAGNotificationStateUpdateWorker.swift
//  SIMSme
//
//  Created by RBU on 27/01/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGRegisterNotificationDelegate: AnyObject {
    func didRegisterForRemoteNotifications()
    func didFailToRegisterForRemoteNotifications(_ error: Error)
}

extension DPAGRegisterNotificationDelegate {
    func didFailToRegisterForRemoteNotifications(_: Error) {}
}

public protocol DPAGNotificationStateUpdateWorkerProtocol: AnyObject {
    var delegate: DPAGNotificationWorkerDelegate? { get set }
    var worker: DPAGSetNotificationDefaultsWorker? { get set }

    func update(_ state: DPAGNotificationRegistrationState)
}

class DPAGNotificationStateUpdateWorker: NSObject, DPAGNotificationStateUpdateWorkerProtocol {
    weak var delegate: DPAGNotificationWorkerDelegate?

    var worker: DPAGSetNotificationDefaultsWorker?

    func update(_ state: DPAGNotificationRegistrationState) {
        DPAGLog("current notification state %i", state.rawValue)
        DPAGApplicationFacade.preferences.notificationRegistrationState = .pending
        DPAGSimsMeController.sharedInstance.registerRemotePushNotifications(self)
    }
}

extension DPAGNotificationStateUpdateWorker: DPAGRegisterNotificationDelegate {
    func didRegisterForRemoteNotifications() {
        if DPAGApplicationFacade.preferences.notificationRegistrationNeedsDefaults {
            DPAGApplicationFacade.preferences.notificationRegistrationState = .setDefaults

            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async { [weak self] in

                guard let strongSelf = self else { return }

                strongSelf.worker = DPAGSetNotificationDefaultsWorker()
                strongSelf.worker?.delegate = self
                strongSelf.worker?.start()
            }
        } else {
            self.notificationSetupComplete()
        }
    }

    func didFailToRegisterForRemoteNotifications(_ error: Error) {
        DPAGApplicationFacade.preferences.notificationRegistrationState = .failed
        DPAGApplicationFacade.preferences.notificationRegistrationError = error.localizedDescription

        self.delegate?.notificationSetupDidFail()
        self.worker = nil
    }
}

// MARK: - DPAGNotificationWorkerDelegate

extension DPAGNotificationStateUpdateWorker: DPAGNotificationWorkerDelegate {
    func notificationSetupComplete() {
        DPAGApplicationFacade.preferences.notificationRegistrationState = .allowed
        DPAGApplicationFacade.preferences.notificationRegistrationNeedsDefaults = false
        DPAGApplicationFacade.preferences.notificationRegistrationError = ""

        self.delegate?.notificationSetupComplete()
        self.worker = nil
    }

    func notificationSetupDidFail() {
        self.delegate?.notificationSetupDidFail()
        self.worker = nil
    }
}
