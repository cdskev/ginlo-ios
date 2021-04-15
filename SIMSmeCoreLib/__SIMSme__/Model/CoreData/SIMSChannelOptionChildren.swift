//
//  SIMSChannelOptionChildren.swift
//  SIMSme
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSChannelOptionChildren: NSManagedObject {
    @NSManaged var forValue: String?
    @NSManaged var items: NSOrderedSet?
    @NSManaged var option: SIMSChannelOption?

    // Insert code here to add functionality to your managed object subclass

    @objc
    public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.CHANNEL_OPTION_CHILDREN
    }
}
