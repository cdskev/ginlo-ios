//
//  SIMSPrivateInternalMessage.swift
//  SIMSme
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSPrivateInternalMessage: SIMSManagedObject {
    @NSManaged var data: String?
    @NSManaged var dataSignature: String?
    @NSManaged var dateSend: Date?
    @NSManaged var errorType: NSNumber?
    @NSManaged var fromAccountGuid: String?
    @NSManaged var fromKey: String?
    @NSManaged var hashes: String?
    @NSManaged var toAccountGuid: String?
    @NSManaged var toKey: String?

    // Insert code here to add functionality to your managed object subclass

    @objc
    public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.MESSAGE_PRIVATE_INTERNAL
    }
}
