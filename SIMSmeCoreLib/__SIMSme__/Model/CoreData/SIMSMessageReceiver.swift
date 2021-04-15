//
//  SIMSMessageReceiver.swift
//  SIMSme
//
//  Created by RBU on 31/08/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSMessageReceiver: NSManagedObject {
    @NSManaged var sendsReadConfirmation: NSNumber?
    @NSManaged var dateDownloaded: Date?
    @NSManaged var dateRead: Date?
    @NSManaged var message: SIMSMessage?
    @NSManaged var contact: SIMSContact?
    @NSManaged var contactIndexEntry: SIMSContactIndexEntry?

    // Insert code here to add functionality to your managed object subclass

    @objc
    public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.MESSAGE_RECEIVER
    }
}
