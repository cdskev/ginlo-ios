//
//  SIMSSelfDestructMessage.swift
// ginlo
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSSelfDestructMessage: NSManagedObject {
    @NSManaged var dateDestruction: Date?
    @NSManaged var messageGuid: String?

    // Insert code here to add functionality to your managed object subclass

    @objc
    public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.MESSAGE_SELF_DESTRUCT
    }
}
