//
//  SIMSAccountStateMessage.swift
// ginlo
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSAccountStateMessage: NSManagedObject {
    @NSManaged var idx: NSNumber?
    @NSManaged var text: String?
    @NSManaged var account: SIMSAccount?

    // Insert code here to add functionality to your managed object subclass

    @objc
    public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.ACCOUNT_STATE_MESSAGE
    }
}
