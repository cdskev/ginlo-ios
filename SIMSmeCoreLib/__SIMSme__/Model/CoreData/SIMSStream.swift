//
//  SIMSStream.swift
// ginlo
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSStream: SIMSMessageStream {
    @NSManaged var contact: SIMSContact?
    @NSManaged var contactIndexEntry: SIMSContactIndexEntry?

    // Insert code here to add functionality to your managed object subclass

    override public var description: String {
        String(format: "messages \(self.messages?.count ?? 0)  lastMessageDate %@  contact: %@", self.lastMessageDate?.description ?? "", self.contactIndexEntry?.description ?? "")
    }

    @objc
    override public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.STREAM_PRIVATE
    }

    override func predNewMessagesFilter() -> NSPredicate {
        if DPAGConstantsGlobal.kSystemChatAccountGuid == self.contactIndexEntry?.guid {
            return NSCompoundPredicate(andPredicateWithSubpredicates:
                [
                    NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.dateReadLocal), rightNotExpression: NSExpression(forConstantValue: nil)),
                    NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.attributes?.dateReadLocal), rightExpression: NSExpression(forConstantValue: nil))
                ])
        }

        return super.predNewMessagesFilter()
    }

    override func countNewMessages() -> Int {
        let numNewMessages = super.countNewMessages()

        return numNewMessages
    }
}
