//
//  SIMSChannelOption.swift
// ginlo
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSChannelOption: SIMSManagedObjectInstance {
    @NSManaged var filterValue: String?
    @NSManaged var ident: String?
    @NSManaged var label: String?
    @NSManaged var labelSub: String?
    @NSManaged var value: String?
    @NSManaged var channel: SIMSChannel?
    @NSManaged var children: Set<SIMSChannelOptionChildren>?
    @NSManaged var parent: SIMSChannelOptionChildren?

    // Insert code here to add functionality to your managed object subclass

    @objc
    public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.CHANNEL_OPTION
    }

    func loadWithDictionary(_ dict: [String: Any], channel: String) {
        self.ident = DPAGChannelOption.identFromIdent(dict[DPAGStrings.JSON.ChannelOption.IDENT] as? String, channel: channel)
        self.label = dict[DPAGStrings.JSON.ChannelOption.LABEL] as? String
        self.labelSub = dict[DPAGStrings.JSON.ChannelOption.LABEL_SUB] as? String
        self.value = self.value != nil ? self.value : dict[DPAGStrings.JSON.ChannelOption.DEFAULT_VALUE] as? String
    }

    class func optionForDict(_ dict: [String: Any], channel: String, in context: NSManagedObjectContext) -> SIMSChannelOption? {
        if let childType = dict[DPAGStrings.JSON.ChannelOption.TYPE] as? String {
            if childType == DPAGStrings.JSON.ChannelOption.TYPE_TOGGLE {
                return SIMSChannelToggle.toggleForDict(dict, channel: channel, in: context)
            }
        }

        return nil
    }

    func childrenForCurrentValue() -> NSOrderedSet? {
        nil
    }

    func filterForCurrentValue() -> [String: [String]] {
        [:]
    }

    func reset() {
        self.value = nil

        for child in self.children ?? Set() {
            if let items = child.items {
                for item in items {
                    (item as? SIMSChannelOption)?.reset()
                }
            }
        }
    }
}
