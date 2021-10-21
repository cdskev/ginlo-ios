//
//  DPAGStatusWorker.swift
// ginlo
//
//  Created by RBU on 16/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import UIKit

public protocol DPAGStatusWorkerProtocol: AnyObject {
    func initStatus()
    func latestStatus() -> String
    func updateStatus(_ message: String, broadCast: Bool)
    // Für BA
    func updateStatus(_ message: String, oooState: String?, oooStatusText: String?, oooStateValid: String?, completion: DPAGServiceResponseBlock?)
    func removeMessage(atIndex idx: Int)
}

class DPAGStatusWorker: NSObject, DPAGStatusWorkerProtocol {
    private static let DEFAULT_STATUS = DPAGLocalizedString("settings.statusWorker.firstMessage")
    private static let DEFAULT_STATUS_B2B = DPAGLocalizedString("profile.oooStatus.oldState.active")

    private let accountStatusMessagesDAO: AccountStatusMessagesDAOProtocol = AccountStatusMessagesDAO()

    public func initStatus() {
        self.accountStatusMessagesDAO.initStatus(defaultStatus: DPAGApplicationFacade.preferences.isBaMandant ? DPAGStatusWorker.DEFAULT_STATUS_B2B : DPAGStatusWorker.DEFAULT_STATUS)
    }

    public func updateStatus(_ message: String, broadCast: Bool) {
        self.initStatus()

        self.accountStatusMessagesDAO.updateStatus(message: message)

        if broadCast {
            DPAGSendInternalMessageWorker.broadcastStatusUpdate(message)
        }
    }

    func updateStatus(_ message: String, oooState: String?, oooStatusText: String?, oooStateValid: String?, completion: DPAGServiceResponseBlock?) {
        DPAGSendInternalMessageWorker.broadcastStatusUpdate(message, oooState: oooState, oooStatusText: oooStatusText, oooStateValid: oooStateValid, completion: completion)
    }

    public func latestStatus() -> String {
        let statusDB = self.accountStatusMessagesDAO.latestStatus()

        return statusDB ?? DPAGStatusWorker.DEFAULT_STATUS
    }

    public func removeMessage(atIndex idx: Int) {
        self.initStatus()

        self.accountStatusMessagesDAO.removeMessage(atIndex: idx)
    }
}
