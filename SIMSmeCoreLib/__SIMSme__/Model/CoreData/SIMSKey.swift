//
//  SIMSKey.swift
// ginlo
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSKey: SIMSManagedObject {
    @NSManaged var aes_key: String?
    @NSManaged var device_guid: String?
    @NSManaged var accountRelationship: SIMSAccount?
    @NSManaged var checksumRelationships: Set<SIMSChecksum>?
    @NSManaged var contactRelationships: Set<SIMSContact>?
    @NSManaged var contactIndexEntryRelationships: Set<SIMSContact>?
    @NSManaged var deviceRelationship: SIMSDevice?
    @NSManaged var groupRelationships: Set<SIMSGroup>?

    // Insert code here to add functionality to your managed object subclass

    @objc
    public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.KEY
    }
}
