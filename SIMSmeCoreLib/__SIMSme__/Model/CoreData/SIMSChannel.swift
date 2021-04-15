//
//  SIMSChannel.swift
//  SIMSme
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSChannel: SIMSManagedObject {
    @NSManaged var aes_key: String?
    @NSManaged var checksum: String?
    @NSManaged var iv: String?
    @NSManaged var layout: String?
    @NSManaged var name_long: String?
    @NSManaged var name_short: String?
    @NSManaged var options: String?
    @NSManaged var subscribed: NSNumber?
    @NSManaged var additionalData: String?
    @NSManaged var assets: Set<SIMSChannelAsset>?
    @NSManaged var rootOptions: NSOrderedSet?
    @NSManaged var stream: SIMSChannelStream?
    @NSManaged var feedType: NSNumber?

    @objc
    public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.CHANNEL
    }

    var validFeedType: DPAGChannelType {
        DPAGChannelType(rawValue: self.feedType?.intValue ?? DPAGChannelType.channel.rawValue) ?? .channel
    }

    private lazy var extendedDict: [String: Any] = [:]

    private var _promotedCategoryIdents: [String]?
    private var _promotedCategoryExternalUrls: [String: String]?

    func updateWithDictionary(_ dict: [String: Any]) {
        self.name_long = dict[DPAGStrings.JSON.Channel.DESC] as? String
        self.name_short = dict[DPAGStrings.JSON.Channel.DESC_SHORT] as? String
        self.options = dict[DPAGStrings.JSON.Channel.OPTIONS] as? String
        self.aes_key = dict[DPAGStrings.JSON.Channel.AES_KEY] as? String
        self.iv = dict[DPAGStrings.JSON.Channel.IV] as? String
        self.updateTextsWithDict(dict)
        self.updatePromotedWithDict(dict)
        if let dictLayout = dict[DPAGStrings.JSON.Channel.LAYOUT] as? [String: Any] {
            self.updateLayoutWithDict(dictLayout)
        }
        if let rootOptions = self.rootOptions {
            let rootOptionsOld = NSOrderedSet(orderedSet: rootOptions)

            for rootOption in rootOptionsOld {
                (rootOption as? SIMSChannelOption)?.channel = nil
            }
        }
        if let items = dict[DPAGStrings.JSON.ChannelOption.SUBITEMS] as? [[String: Any]] {
            for item in items {
                if let managedObjectContext = self.managedObjectContext, let rootOption = SIMSChannelOption.optionForDict(item, channel: self.guid ?? "???", in: managedObjectContext) {
                    rootOption.channel = self
                }
            }
        }
        if let channelDefinition = dict.JSONString {
            self.layout = channelDefinition
        }
    }

    func loadExtendedData() {
        if self.layout == nil {
            return
        }
        if let data = self.layout?.data(using: .utf8) {
            do {
                if let item = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] {
                    self.loadExtendedDataWithDict(item)
                }
            } catch {
                DPAGLog(error)
            }
        }
    }

    func loadExtendedDataWithDict(_ dict: [String: Any]) {
        DPAGLog("loadExtendedDataWithDict for channel %@", self.guid ?? "")
        self.updateTextsWithDict(dict)
        self.updatePromotedWithDict(dict)
        self.updateLayoutWithDict(dict)
        self.updateAdditionalDataWithDict(dict)
    }

    func updatePromotedWithDict(_ dict: [String: Any]) {
        if let dictPromoted = dict[DPAGStrings.JSON.Channel.PROMOTED] as? [String: Any], let promEnabled = dictPromoted[DPAGStrings.JSON.Channel.PROMOTED_ENABLED] as? String {
            self.extendedDict["_promoted"] = NSNumber(value: (promEnabled.lowercased() == "true") as Bool)
            self.extendedDict["_externalURL"] = dictPromoted[DPAGStrings.JSON.Channel.PROMOTED_EXTERNAL_URL] as? String
        } else {
            self.extendedDict.removeValue(forKey: "_promoted")
            self.extendedDict.removeValue(forKey: "_externalURL")
        }
        self._promotedCategoryIdents = []
        self._promotedCategoryExternalUrls = [:]
        if let arrPromotedCategory = dict[DPAGStrings.JSON.Channel.PROMOTED_CATEGORY] as? [[String: Any]] {
            for dictPromoCat in arrPromotedCategory {
                if let catIdent = dictPromoCat[DPAGStrings.JSON.Channel.PROMOTED_CATEGORY_IDENT] as? String {
                    self._promotedCategoryIdents?.append(catIdent)

                    if let externalURL = dictPromoCat[DPAGStrings.JSON.Channel.PROMOTED_EXTERNAL_URL] as? String {
                        self._promotedCategoryExternalUrls?[catIdent] = externalURL
                    }
                }
            }
        }
    }

    func promotedCategoryExternalUrls() -> [String: String]? {
        DPAGFunctionsGlobal.synchronizedReturn(self) { () -> [String: String]? in
            if self._promotedCategoryExternalUrls == nil {
                if self.layout == nil {
                    return nil
                }
                self.loadExtendedData()
            }
            return self._promotedCategoryExternalUrls
        }
    }

    func promotedCategoryIdents() -> [String]? {
        DPAGFunctionsGlobal.synchronizedReturn(self) { () -> [String]? in
            if self._promotedCategoryIdents == nil {
                if self.layout == nil {
                    return []
                }
                self.loadExtendedData()
            }
            return self._promotedCategoryIdents
        }
    }

    func updateAdditionalDataWithDict(_ dict: [String: Any]) {
        if let serviceID = dict[DPAGStrings.JSON.Channel.SERVICE_ID] as? String {
            self.extendedDict["_serviceID"] = serviceID
        }
    }

    func updateTextsWithDict(_ dict: [String: Any]) {
        self.extendedDict["_searchText"] = dict[DPAGStrings.JSON.Channel.SEARCH_TEXT] as? String ?? ""
        self.extendedDict["_welcomeText"] = dict[DPAGStrings.JSON.Channel.WELCOME_TEXT] as? String ?? ""
        self.extendedDict["_recommendationText"] = dict[DPAGStrings.JSON.Channel.RECOMMENDATION_TEXT] as? String ?? ""
        self.extendedDict["_contentLinkReplacer"] = dict[DPAGStrings.JSON.Channel.LINK_REPLACER] as? String ?? ""
        self.extendedDict["_contentLinkReplacerRegex"] = dict[DPAGStrings.JSON.Channel.LINK_REPLACER] as? [[String: String]] ?? []
        if let dictFeedback = dict[DPAGStrings.JSON.Channel.FEEDBACK_CONTACT] as? [String: Any] {
            self.extendedDict["_feedbackContactNickname"] = dictFeedback[DPAGStrings.JSON.Channel.FEEDBACK_CONTACT_NICKNAME] as? String ?? ""
            self.extendedDict["_feedbackContactPhoneNumber"] = dictFeedback[DPAGStrings.JSON.Channel.FEEDBACK_CONTACT_PHONENUMBER] as? String ?? ""
        } else {
            self.extendedDict["_feedbackContactNickname"] = ""
            self.extendedDict["_feedbackContactPhoneNumber"] = ""
        }
    }

    func updateLayoutWithDict(_ dict: [String: Any]) {
        let dictLayout = dict[DPAGStrings.JSON.Channel.LAYOUT] as? [String: Any] ?? dict

        self.scanDict(dictLayout, forColorKey: DPAGStrings.JSON.Channel.LAYOUT_COLOR_LABEL_DISABLED, valueKey: "_colorDetailsLabelDisabled")
        self.scanDict(dictLayout, forColorKey: DPAGStrings.JSON.Channel.LAYOUT_COLOR_LABEL_ENABLED, valueKey: "_colorDetailsLabelEnabled")
        self.scanDict(dictLayout, forColorKey: DPAGStrings.JSON.Channel.LAYOUT_COLOR_TEXT, valueKey: "_colorDetailsText")
        self.scanDict(dictLayout, forColorKey: "settings_color_toggle", valueKey: "_colorDetailsToggle")
        self.scanDict(dictLayout, forColorKey: "settings_color_toggle_off", valueKey: "_colorDetailsToggleOff")
        self.scanDict(dictLayout, forColorKey: "settings_color_button_follow", valueKey: "_colorDetailsButtonFollow")
        self.scanDict(dictLayout, forColorKey: "settings_color_button_follow_text", valueKey: "_colorDetailsButtonFollowText")
        self.scanDict(dictLayout, forColorKey: "settings_color_button_follow_disabled", valueKey: "_colorDetailsButtonFollowDisabled")
        self.scanDict(dictLayout, forColorKey: "settings_color_button_follow_text_disabled", valueKey: "_colorDetailsButtonFollowTextDisabled")
        self.scanDict(dictLayout, forColorKey: "asset_ib_color", valueKey: "_colorDetailsBackgroundLogo")
        self.scanDict(dictLayout, forColorKey: "asset_cb_color", valueKey: "_colorDetailsBackground")
        self.scanDict(dictLayout, forColorKey: "overview_color_time", valueKey: "_colorChatListDate")
        self.scanDict(dictLayout, forColorKey: "overview_color_name", valueKey: "_colorChatListName")
        self.scanDict(dictLayout, forColorKey: "overview_color_preview", valueKey: "_colorChatListPreview")
        self.scanDict(dictLayout, forColorKey: "overview_bkcolor_bubble", valueKey: "_colorChatListBadge")
        self.scanDict(dictLayout, forColorKey: "overview_color_bubble", valueKey: "_colorChatListBadgeText")
        self.scanDict(dictLayout, forColorKey: "asset_ib_color", valueKey: "_colorChatListBackground")
        self.scanDict(dictLayout, forColorKey: "asset_cb_color", valueKey: "_colorChatBackground")
        self.scanDict(dictLayout, forColorKey: "asset_ib_color", valueKey: "_colorChatBackgroundLogo")
        self.scanDict(dictLayout, forColorKey: "msg_color_time", valueKey: "_colorChatMessageDate")
        self.scanDict(dictLayout, forColorKey: "msg_color_section_active", valueKey: "_colorChatMessageSection")
        self.scanDict(dictLayout, forColorKey: "msg_color_section_inactive", valueKey: "_colorChatMessageSectionPre")
        self.scanDict(dictLayout, forColorKey: "msg_color_bubble", valueKey: "_colorChatMessageBubble")
        self.scanDict(dictLayout, forColorKey: "msg_color_bubble_welcome", valueKey: "_colorChatMessageBubbleWelcome")
        self.scanDict(dictLayout, forColorKey: "msg_color_bubble_welcome_text", valueKey: "_colorChatMessageBubbleWelcomeText")
        self.scanDict(dictLayout, forColorKey: "head_bkcolor", valueKey: "_colorNavigationbar")
        self.scanDict(dictLayout, forColorKey: "head_color", valueKey: "_colorNavigationbarText")
        self.scanDict(dictLayout, forColorKey: "menu_bkcolor", valueKey: "_colorMenu")
        self.scanDict(dictLayout, forColorKey: "menu_color", valueKey: "_colorMenuText")
    }

    func scanDict(_ dictLayout: [String: Any], forColorKey dictKey: String, valueKey: String) {
        if let colorToParseDict = dictLayout[dictKey] as? String {
            if let color = UIColor.scanColor(colorToParseDict) {
                self.extendedDict[valueKey] = color
            }
        }
    }

    func colorWithKey(_ colorKey: String, colorDefault: UIColor?) -> UIColor? {
        DPAGFunctionsGlobal.synchronizedReturn(self) { () -> UIColor? in
            if self.extendedDict[colorKey] == nil {
                if self.layout == nil {
                    return colorDefault
                }
                self.loadExtendedData()
            }
            return (self.extendedDict[colorKey] as? UIColor) ?? colorDefault
        }
    }

    func textWithKey(_ textKey: String) -> String? {
        DPAGFunctionsGlobal.synchronizedReturn(self) { () -> String? in
            if self.extendedDict[textKey] == nil {
                if self.layout == nil {
                    return nil
                }
                self.loadExtendedData()
            }
            return self.extendedDict[textKey] as? String
        }
    }

    func additionalDataWithKey(_ key: String) -> String? {
        DPAGFunctionsGlobal.synchronizedReturn(self) { () -> String? in
            if self.extendedDict[key] == nil {
                if self.layout == nil {
                    return nil
                }
                self.loadExtendedData()
            }
            return self.extendedDict[key] as? String
        }
    }

    var colorDetailsLabelEnabled: UIColor? {
        self.colorWithKey("_colorDetailsLabelEnabled", colorDefault: nil)
    }

    var colorDetailsLabelDisabled: UIColor? {
        self.colorWithKey("_colorDetailsLabelDisabled", colorDefault: nil)
    }

    var colorDetailsText: UIColor? {
        self.colorWithKey("_colorDetailsText", colorDefault: nil)
    }

    var colorDetailsToggle: UIColor? {
        self.colorWithKey("_colorDetailsToggle", colorDefault: nil)
    }

    var colorDetailsToggleOff: UIColor? {
        self.colorWithKey("_colorDetailsToggleOff", colorDefault: nil)
    }

    var colorDetailsButtonFollow: UIColor? {
        self.colorWithKey("_colorDetailsButtonFollow", colorDefault: nil)
    }

    var colorDetailsButtonFollowText: UIColor? {
        self.colorWithKey("_colorDetailsButtonFollowText", colorDefault: nil)
    }

    var colorDetailsButtonFollowDisabled: UIColor? {
        self.colorWithKey("_colorDetailsButtonFollowDisabled", colorDefault: nil)
    }

    var colorDetailsButtonFollowTextDisabled: UIColor? {
        self.colorWithKey("_colorDetailsButtonFollowTextDisabled", colorDefault: nil)
    }

    var colorDetailsBackground: UIColor? {
        self.colorWithKey("_colorDetailsBackground", colorDefault: nil)
    }

    var colorDetailsBackgroundLogo: UIColor? {
        self.colorWithKey("_colorDetailsBackgroundLogo", colorDefault: nil)
    }

    var colorChatListDate: UIColor? {
        self.colorWithKey("_colorChatListDate", colorDefault: nil)
    }

    var colorChatListName: UIColor? {
        self.colorWithKey("_colorChatListName", colorDefault: nil)
    }

    var colorChatListPreview: UIColor? {
        self.colorWithKey("_colorChatListPreview", colorDefault: nil)
    }

    var colorChatListBadge: UIColor? {
        self.colorWithKey("_colorChatListBadge", colorDefault: nil)
    }

    var colorChatListBadgeText: UIColor? {
        self.colorWithKey("_colorChatListBadgeText", colorDefault: nil)
    }

    var colorChatListBackground: UIColor? {
        self.colorWithKey("_colorChatListBackground", colorDefault: nil)
    }

    var colorChatBackground: UIColor? {
        self.colorWithKey("_colorChatBackground", colorDefault: nil)
    }

    var colorChatBackgroundLogo: UIColor? {
        self.colorWithKey("_colorChatBackgroundLogo", colorDefault: nil)
    }

    var colorChatMessageDate: UIColor? {
        self.colorWithKey("_colorChatMessageDate", colorDefault: nil)
    }

    var colorChatMessageSection: UIColor? {
        self.colorWithKey("_colorChatMessageSection", colorDefault: nil)
    }

    var colorChatMessageSectionPre: UIColor? {
        self.colorWithKey("_colorChatMessageSectionPre", colorDefault: nil)
    }

    var colorChatMessageBubble: UIColor? {
        self.colorWithKey("_colorChatMessageBubble", colorDefault: nil)
    }

    var colorChatMessageBubbleWelcome: UIColor? {
        self.colorWithKey("_colorChatMessageBubbleWelcome", colorDefault: nil)
    }

    var colorChatMessageBubbleWelcomeText: UIColor? {
        self.colorWithKey("_colorChatMessageBubbleWelcomeText", colorDefault: nil)
    }

    var colorNavigationbar: UIColor? {
        self.colorWithKey("_colorNavigationbar", colorDefault: nil)
    }

    var colorNavigationbarText: UIColor? {
        switch self.validFeedType {
            case .channel:
                return self.colorWithKey("_colorNavigationbarText", colorDefault: nil)
            case .service:
                return self.colorWithKey("_colorNavigationbarText", colorDefault: nil)
        }
    }

    var colorNavigationbarAction: UIColor? {
        self.colorWithKey("_colorNavigationbarText", colorDefault: nil)
    }

    var colorMenu: UIColor? {
        self.colorWithKey("_colorMenu", colorDefault: nil)
    }

    var colorMenuText: UIColor? {
        self.colorWithKey("_colorMenuText", colorDefault: nil)
    }

    var searchText: String? {
        self.textWithKey("_searchText")
    }

    var welcomeText: String? {
        self.textWithKey("_welcomeText")
    }

    var recommendationText: String? {
        self.textWithKey("_recommendationText")
    }

    var contentLinkReplacer: String? {
        self.textWithKey("_contentLinkReplacer")
    }

    var contentLinkReplacerRegex: [DPAGContentLinkReplacerString]? {
        DPAGFunctionsGlobal.synchronizedReturn(self) { () -> [DPAGContentLinkReplacerString] in
            if self.extendedDict["_contentLinkReplacerRegex"] == nil {
                if self.layout == nil {
                    return []
                }
                self.loadExtendedData()
            }
            if let replacerArr = self.extendedDict["_contentLinkReplacerRegex"] as? [[String: String]] {
                var retVal: [DPAGContentLinkReplacerString] = []
                for replacerItem in replacerArr {
                    if let regEx = replacerItem["regex"], let replacer = replacerItem["value"] {
                        retVal.append(DPAGContentLinkReplacerString(pattern: regEx, replacer: replacer))
                    }
                }
                return retVal
            }
            return []
        }
    }

    var feedbackContactPhoneNumber: String? {
        self.textWithKey("_feedbackContactPhoneNumber")
    }

    var feedbackContactNickname: String? {
        self.textWithKey("_feedbackContactNickname")
    }

    var serviceID: String? {
        self.additionalDataWithKey("_serviceID")
    }

    var isHidden: Bool {
        self.options?.components(separatedBy: ",").contains("hiddenChannel") ?? false
    }

    var isReadOnly: Bool {
        self.options?.components(separatedBy: ",").contains("readOnly") ?? false
    }

    var isMandatory: Bool {
        self.options?.components(separatedBy: ",").contains("mandatory") ?? false
    }

    var isRecommended: Bool {
        self.options?.components(separatedBy: ",").contains("recommended") ?? false
    }

    var isPromoted: Bool {
        DPAGFunctionsGlobal.synchronizedReturn(self) { () -> Bool in

            if self.extendedDict["_promoted"] == nil {
                if self.layout == nil {
                    return false
                }

                self.loadExtendedData()
            }
            return (self.extendedDict["_promoted"] as? NSNumber)?.boolValue ?? false
        }
    }

    var externalURL: String? {
        DPAGFunctionsGlobal.synchronizedReturn(self) { () -> String? in
            if self.extendedDict["_externalURL"] == nil, self.isPromoted {
                if self.layout == nil {
                    return nil
                }
            }
            return self.extendedDict["_externalURL"] as? String
        }
    }

    var notificationEnabled: Bool {
        get {
            if let value = DPAGApplicationFacade.preferences[String(format: "%@-%@", self.guid ?? "-", DPAGPreferences.PropString.kNotificationChannelChatEnabled.rawValue)] as? String {
                return value != DPAGPreferences.kValueNotificationDisabled
            }
            // default ist true
            return true
        }
        set {
            let key = String(format: "%@-%@", self.guid ?? "-", DPAGPreferences.PropString.kNotificationChannelChatEnabled.rawValue)
            DPAGApplicationFacade.preferences[key] = newValue ? DPAGPreferences.kValueNotificationEnabled : DPAGPreferences.kValueNotificationDisabled
        }
    }

    func currentFilter() -> String {
        var dictFilter: [String: [String]] = [:]

        if let rootOptions = self.rootOptions {
            for rootOptionObj in rootOptions {
                if let rootOption = rootOptionObj as? SIMSChannelOption {
                    dictFilter = DPAGChannelOption.mergeFilterDicts(dictFilter, dict2: rootOption.filterForCurrentValue())
                }
            }
        }

        return DPAGChannel.joinFilter(dictFilter)
    }
}
