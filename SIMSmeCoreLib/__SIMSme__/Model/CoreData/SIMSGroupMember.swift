//
//  SIMSGroupMember.swift
// ginlo
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSGroupMember: SIMSManagedObjectInstance {
    @NSManaged var accountGuid: String?
    @NSManaged var groups: Set<SIMSGroup>?

    // Insert code here to add functionality to your managed object subclass

    @objc
    public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.GROUP_MEMBER
    }

    func isEqualToMember(_ member: SIMSGroupMember) -> Bool {
        if self == member {
            return true
        }
        if self.accountGuid == member.accountGuid {
            return true
        }
        return false
    }
}
