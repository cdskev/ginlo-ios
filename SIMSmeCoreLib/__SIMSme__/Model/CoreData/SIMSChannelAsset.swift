//
//  SIMSChannelAsset.swift
//  SIMSme
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSChannelAsset: NSManagedObject {
    @NSManaged var data: String?
    @NSManaged var type: String?
    @NSManaged var channel: SIMSChannel?

    // Insert code here to add functionality to your managed object subclass

    @objc
    public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.CHANNEL_ASSET
    }
}
