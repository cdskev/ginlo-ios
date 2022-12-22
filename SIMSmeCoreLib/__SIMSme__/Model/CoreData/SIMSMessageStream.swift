//
//  SIMSMessageStream.swift
// ginlo
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSMessageStream: SIMSManagedObject {
    @NSManaged var draft: String?
    @NSManaged var isConfirmed: NSNumber?
    @NSManaged var lastMessageDate: Date?
    @NSManaged var options: NSNumber?
    @NSManaged private(set) var streamType: NSNumber?
    @NSManaged var wasDeleted: NSNumber?
    @NSManaged var messages: NSOrderedSet?

    // Insert code here to add functionality to your managed object subclass

    @objc
    public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.STREAM
    }

    var optionsStream: DPAGStreamOption {
        get {
            if let options = self.options {
                return DPAGStreamOption(rawValue: options.intValue)
            }
            return []
        }
        set {
            self.options = NSNumber(value: newValue.rawValue)
        }
    }

    var typeStream: DPAGStreamType {
        get {
            DPAGStreamType(rawValue: self.streamType?.intValue ?? DPAGStreamType.unknown.rawValue) ?? .unknown
        }
        set {
            self.streamType = NSNumber(value: newValue.rawValue)
        }
    }

    func predNewMessagesFilter() -> NSPredicate {
        let ownGuid = DPAGApplicationFacade.cache.account?.guid

        return NSCompoundPredicate(andPredicateWithSubpredicates:
            [
                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.fromAccountGuid), rightNotExpression: NSExpression(forConstantValue: ownGuid ?? "unknown")),
                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.fromAccountGuid), rightNotExpression: NSExpression(forConstantValue: DPAGConstantsGlobal.kSystemChatAccountGuid)),
                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.data), rightNotExpression: NSExpression(forConstantValue: nil)),
                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.attributes?.dateReadLocal), rightExpression: NSExpression(forConstantValue: nil))
            ])
    }

    func countNewMessages() -> Int {
        var rc = 0
        tryC {
            rc = self.messages?.filtered(using: self.predNewMessagesFilter()).count ?? 0
        }
        .catch { exception in

            DPAGLog("%@", exception)
        }
        return rc
    }
}
