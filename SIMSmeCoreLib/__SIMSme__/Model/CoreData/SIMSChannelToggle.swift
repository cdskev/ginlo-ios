//
//  SIMSChannelToggle.swift
//  SIMSme
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSChannelToggle: SIMSChannelOption {
    // Insert code here to add functionality to your managed object subclass

    @objc
    override public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.CHANNEL_OPTION_TOGGLE
    }

    class func toggleForDict(_ dict: [String: Any], channel: String, in context: NSManagedObjectContext) -> SIMSChannelOption? {
        if let ident = DPAGChannelOption.identFromIdent(dict[DPAGStrings.JSON.ChannelOption.IDENT] as? String, channel: channel) {
            let toggle = SIMSChannelToggle.mr_findFirst(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSChannelToggle.ident), rightExpression: NSExpression(forConstantValue: ident)), in: context) ?? SIMSChannelToggle.mr_createEntity(in: context)

            toggle?.loadWithDictionary(dict, channel: channel)

            return toggle
        }
        return nil
    }

    override func loadWithDictionary(_ dict: [String: Any], channel: String) {
        super.loadWithDictionary(dict, channel: channel)

        self.filterValue = ""

        var dictFilter: [String: String] = [:]

        if let filterValue = dict[DPAGStrings.JSON.ChannelOptionToggle.FILTER_STATE_ON] as? String {
            dictFilter["on"] = filterValue
        }
        if let filterValue = dict[DPAGStrings.JSON.ChannelOptionToggle.FILTER_STATE_OFF] as? String {
            dictFilter["off"] = filterValue

            if dictFilter["on"] == dictFilter["off"] {
                self.value = "always"
            }
        }

        self.filterValue = dictFilter.JSONString

        for child in self.children ?? Set() {
            child.option = nil
        }
        self.parent = nil

        if let children = dict[DPAGStrings.JSON.ChannelOptionToggle.CHILDREN] as? [[String: Any]] {
            for childrenDict in children {
                let childrenType = childrenDict[DPAGStrings.JSON.ChannelOptionToggle.CHILDREN_TOGGLE_STATE] as? String

                if let managedObjectContext = self.managedObjectContext, let childrenArray = childrenDict[DPAGStrings.JSON.ChannelOption.SUBITEMS] as? [[String: Any]], let optionChildren = SIMSChannelOptionChildren.mr_createEntity(in: managedObjectContext) {
                    if childrenType == "on" {
                        optionChildren.forValue = "on"
                    } else {
                        optionChildren.forValue = "off"
                    }

                    for childDict in childrenArray {
                        if let option = SIMSChannelOption.optionForDict(childDict, channel: channel, in: managedObjectContext) {
                            option.parent = optionChildren
                        }
                    }

                    optionChildren.option = self
                }
            }
        }
    }

    override func childrenForCurrentValue() -> NSOrderedSet? {
        for children in self.children ?? Set() {
            if self.isOn, children.forValue == "on" {
                return children.items
            }
            if self.isOn == false, children.forValue == "off" {
                return children.items
            }
        }

        return nil
    }

    override func filterForCurrentValue() -> [String: [String]] {
        let dictFilter = DPAGChannelToggle.filter2Dict(filterValue: self.filterValue)

        var retVal: [String: [String]] = [:]

        if self.isOn {
            if let dictOn = dictFilter["on"], dictOn.keys.count > 0 {
                retVal = DPAGChannelOption.mergeFilterDicts(retVal, dict2: dictOn)
            }
        } else {
            if let dictOff = dictFilter["off"], dictOff.keys.count > 0 {
                retVal = DPAGChannelOption.mergeFilterDicts(retVal, dict2: dictOff)
            }
        }

        if let children = self.childrenForCurrentValue() {
            for childOptionObj in children {
                if let childOption = childOptionObj as? SIMSChannelOption {
                    retVal = DPAGChannelOption.mergeFilterDicts(retVal, dict2: childOption.filterForCurrentValue())
                }
            }
        }
        return retVal
    }

    var isOn: Bool {
        self.value == "on" || self.value == "always"
    }
}
