//
//  SIMSMessageToSendPrivate.swift
// ginlo
//
//  Created by RBU on 02/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSMessageToSendPrivate: SIMSMessageToSend {
    @NSManaged var fromKey: String?
    @NSManaged var fromKey2: String?
    @NSManaged var toAccountGuid: String?
    @NSManaged var toKey: String?
    @NSManaged var toKey2: String?
    @NSManaged var aesKey2IV: String?

    // Insert code here to add functionality to your managed object subclass

    @objc
    override public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.MESSAGE_TO_SEND_PRIVATE
    }

    func streamToSend(in localContext: NSManagedObjectContext) -> SIMSStream? {
        SIMSMessageStream.mr_findFirst(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageStream.guid), rightExpression: NSExpression(forConstantValue: self.streamGuid == "{hiddenstream}" ? self.toAccountGuid : self.streamGuid)), in: localContext) as? SIMSStream
    }
}
