//
//  SIMSChannelMessage.swift
// ginlo
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSChannelMessage: SIMSMessage {
    @NSManaged var fromKey: String?
    @NSManaged var toAccountGuid: String?
    @NSManaged var toKey: String?

    // Insert code here to add functionality to your managed object subclass

    override public var description: String {
        String(format: "guid %@   fromAccGuid \(String(describing: self.fromAccountGuid))  hasStream \(self.stream != nil), dateSendLocal \(String(describing: self.dateSendLocal)), dateSendServer \(String(describing: self.dateSendServer))", self.guid ?? "")
    }

    @objc
    override public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.MESSAGE_CHANNEL
    }
}
