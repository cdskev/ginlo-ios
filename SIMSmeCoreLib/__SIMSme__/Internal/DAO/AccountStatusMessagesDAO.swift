//
//  AccountStatusMessagesDAO.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 15.08.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

protocol AccountStatusMessagesDAOProtocol {
    func loadStatusMessages() -> [String]

    func initStatus(defaultStatus: String)
    func updateStatus(message: String)
    func latestStatus() -> String?
    func removeMessage(atIndex idx: Int)
}

class AccountStatusMessagesDAO: AccountStatusMessagesDAOProtocol {
    static let MAXIMUM_NUMBER_OF_STATUS_MESSAGES = 10

    func loadStatusMessages() -> [String] {
        var retVal: [String] = []

        DPAGApplicationFacade.persistance.loadWithBlock { localContext in

            guard let statusMessages = SIMSAccountStateMessage.mr_findAllSorted(by: "idx", ascending: true, in: localContext) else {
                return
            }

            retVal = statusMessages.compactMap { ($0 as? SIMSAccountStateMessage)?.text }
        }

        return retVal
    }

    func initStatus(defaultStatus: String) {
        DPAGApplicationFacade.persistance.saveWithBlock { context in
            guard let account = SIMSAccount.mr_findAll(in: context)?.first as? SIMSAccount else {
                return
            }

            guard (account.stateMessages?.count ?? 0) == 0 else {
                return
            }

            guard let msgDefault = SIMSAccountStateMessage.mr_createEntity(in: context) else {
                return
            }

            msgDefault.idx = 0
            msgDefault.text = defaultStatus
            msgDefault.account = account
        }
    }

    func updateStatus(message: String) {
        DPAGApplicationFacade.persistance.saveWithBlock { context in

            guard let account = SIMSAccount.mr_findAll(in: context)?.first as? SIMSAccount else {
                return
            }

            // check if there is already a status messages with the same message
            let msgExisting = account.stateMessages?.first { ($0 as? SIMSAccountStateMessage)?.text == message } as? SIMSAccountStateMessage

            if let msgExisting = msgExisting, let msgExistingIndex = account.stateMessages?.index(of: msgExisting) {
                // existing status message becomes first in list
                if msgExistingIndex != 0 {
                    account.mutableOrderedSetValue(forKeyPath: #keyPath(SIMSAccount.stateMessages)).moveObjects(at: IndexSet(integer: msgExistingIndex), to: 0)
                }
            } else if let msg = SIMSAccountStateMessage.mr_createEntity(in: context) {
                // new status message becomes first in list
                msg.idx = 0
                msg.text = message
                account.mutableOrderedSetValue(forKeyPath: #keyPath(SIMSAccount.stateMessages)).insert(msg, at: 0)
            }

            self.cleanUpStatusMessages(for: account, in: context)
        }
    }

    private func cleanUpStatusMessages(for account: SIMSAccount, in context: NSManagedObjectContext) {
        // store not more than MAXIMUM_NUMBER_OF_STATUS_MESSAGES
        if let count = account.stateMessages?.count, count > AccountStatusMessagesDAO.MAXIMUM_NUMBER_OF_STATUS_MESSAGES {
            account.mutableOrderedSetValue(forKeyPath: #keyPath(SIMSAccount.stateMessages)).removeObjects(in: NSRange(location: 10, length: count - 10))

            // removed messages get account set to nil, search and destroy all of them
            if let stateMessagesWithoutAccount = SIMSAccountStateMessage.mr_findAll(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSAccountStateMessage.account), rightExpression: NSExpression(forConstantValue: nil)), in: context) {
                stateMessagesWithoutAccount.forEach { $0.mr_deleteEntity(in: context) }
            }
        }

        // clean up index after reordering
        account.stateMessages?.enumerateObjects { msg, idx, _ in
            (msg as? SIMSAccountStateMessage)?.idx = NSNumber(value: idx)
        }
    }

    func latestStatus() -> String? {
        var retVal: String?

        DPAGApplicationFacade.persistance.loadWithBlock { localContext in

            guard let account = SIMSAccount.mr_findAll(in: localContext)?.first as? SIMSAccount else {
                return
            }

            guard let statusMessage = (account.stateMessages?.firstObject as? SIMSAccountStateMessage)?.text, statusMessage.isEmpty == false else {
                return
            }

            retVal = statusMessage
        }

        return retVal
    }

    func removeMessage(atIndex idx: Int) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            guard let account = SIMSAccount.mr_findAll(in: localContext)?.first as? SIMSAccount else {
                return
            }

            guard (account.stateMessages?.count ?? 0) > idx else {
                return
            }

            guard let msg = account.stateMessages?[idx] as? SIMSAccountStateMessage else {
                return
            }

            account.mutableOrderedSetValue(forKeyPath: #keyPath(SIMSAccount.stateMessages)).removeObject(at: idx)
            msg.mr_deleteEntity(in: localContext)
        }
    }
}
