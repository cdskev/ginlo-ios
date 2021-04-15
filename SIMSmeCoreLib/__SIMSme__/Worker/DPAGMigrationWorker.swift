//
//  DPAGMigrationWorker.swift
//  SIMSmeCore
//
//  Created by RBU on 12.12.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Contacts
import ContactsUI
import CoreData
import UIKit

public protocol DPAGMigrationWorkerDelegate: AnyObject {
    func setMigrationInfo(_ info: String)
}

public protocol DPAGMigrationWorkerProtocol: AnyObject {
    func startMigration3Dot3(withDelegate delegate: DPAGMigrationWorkerDelegate)
}

class DPAGMigrationWorker: DPAGMigrationWorkerProtocol {
    func startMigration3Dot3(withDelegate delegate: DPAGMigrationWorkerDelegate) {
        delegate.setMigrationInfo("migration.info.init")

        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            guard let contacts = SIMSCompanyContact.mr_findAll(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSCompanyContact.guid), rightExpression: NSExpression(forConstantValue: DPAGGuidPrefix.companyUser.rawValue), modifier: .direct, type: .beginsWith, options: []), in: localContext) else {
                return
            }

            for contactObj in contacts {
                if let contact = contactObj as? SIMSCompanyContact {
                    contact.checksum = nil
                }
            }
        }

        DPAGApplicationFacade.preferences.forceUpdateCompanyIndex()
    }
}
