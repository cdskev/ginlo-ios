//
//  SIMSMessageAttributes.swift
// ginlo
//
//  Created by RBU on 09/06/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSMessageAttributes: NSManagedObject {
    @NSManaged var dateDownloaded: Date?
    @NSManaged var dateReadLocal: Date?
    @NSManaged var dateReadServer: Date?
    @NSManaged var message: SIMSMessage?

    // Insert code here to add functionality to your managed object subclass
}
