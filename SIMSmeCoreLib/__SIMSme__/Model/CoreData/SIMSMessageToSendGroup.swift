//
//  SIMSMessageToSendGroup.swift
// ginlo
//
//  Created by RBU on 02/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSMessageToSendGroup: SIMSMessageToSend {
    @NSManaged var toGroupGuid: String?

    // Insert code here to add functionality to your managed object subclass

    @objc
    override public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.MESSAGE_TO_SEND_GROUP
    }

    func streamToSend(in localContext: NSManagedObjectContext) -> SIMSGroupStream? {
        SIMSMessageStream.mr_findFirst(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageStream.guid), rightExpression: NSExpression(forConstantValue: self.streamGuid == "{hiddenstream}" ? self.toGroupGuid : self.streamGuid)), in: localContext) as? SIMSGroupStream
    }
}
