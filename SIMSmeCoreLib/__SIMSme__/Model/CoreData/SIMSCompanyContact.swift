//
//  SIMSCompanyContact.swift
// ginlo
//
//  Created by RBU on 03/11/2016.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSCompanyContact: SIMSManagedObject {
    @NSManaged var checksum: String?
    @NSManaged var data: String?
    @NSManaged var keyIv: String?
    @NSManaged var publicKey: String?

    // Insert code here to add functionality to your managed object subclass

    @objc
    public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.CONTACT_COMPANY
    }
}
