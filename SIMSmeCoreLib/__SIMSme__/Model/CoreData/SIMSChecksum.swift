//
//  SIMSChecksum.swift
// ginlo
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSChecksum: SIMSManagedObject {
    @NSManaged var local_checksum: String?
    @NSManaged var accountRelationship: SIMSAccount?
    @NSManaged var contactRelationship: SIMSContact?
    @NSManaged var contactIndexEntryRelationship: SIMSContact?
    @NSManaged var deviceRelationship: SIMSDevice?
    @NSManaged var groupRelationship: SIMSGroup?
    @NSManaged var keyRelationship: SIMSKey?

    // Insert code here to add functionality to your managed object subclass

    @objc
    public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.CHECKSUM
    }
}
