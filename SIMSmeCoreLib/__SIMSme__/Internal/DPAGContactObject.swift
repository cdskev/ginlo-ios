//
//  DPAGContactObject.swift
// ginlo
//
//  Created by RBU on 08/06/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Contacts
import CoreData
import UIKit

public protocol DPAGSearchListModelEntry: Hashable {
    var sortString: String { get }

    func isBeforeInSearch(_ rhs: Self) -> Bool

    func isSearchResult(for: String) -> Bool
}

public class DPAGSearchListSelection<T: DPAGSearchListModelEntry> {
    public private(set) var objectsSelected: Set<T> = Set()
    public private(set) var objectsSelectedFixed: Set<T> = Set()

    public init() {}

    public func removeSelected(_ obj: T) {
        if self.objectsSelectedFixed.contains(obj) == false {
            self.objectsSelected.remove(obj)
        }
    }

    public func appendSelected(_ object: T) {
        self.objectsSelected.insert(object)
    }

    public func appendSelected(contentsOf manyObjects: Set<T>) {
        self.objectsSelected.formUnion(manyObjects)
    }

    public func appendSelectedFixed(contentsOf manyObjects: Set<T>) {
        self.objectsSelected.formUnion(manyObjects)
        self.objectsSelectedFixed.formUnion(manyObjects)
    }

    public func contains(_ obj: T) -> Bool {
        self.objectsSelected.contains(obj)
    }

    public func containsFixed(_ obj: T) -> Bool {
        self.objectsSelectedFixed.contains(obj)
    }
}

public class DPAGSearchListModel<T: DPAGSearchListModelEntry> {
    public let objects: Set<T>
    public private(set) var objectsSorted: [T]
    public private(set) var objectsFiltered: [T] = []

    public private(set) var objectsInSections: [String: [T]] = [:]
    public private(set) var sectionsChars: [String] = []

    public init(objects: Set<T>, objectsSorted: [T] = []) {
        self.objects = objects
        self.objectsSorted = objectsSorted

        self.createSections()
    }

    private func createSections() {
        if self.objectsSorted.isEmpty {
            self.objectsSorted = self.objects.sorted { (obj1, obj2) -> Bool in
                obj1.isBeforeInSearch(obj2)
            }
        }

        for object in self.objectsSorted {
            var sectionChar = "#"

            if let firstChar = object.sortString.first?.unicodeScalars.first, CharacterSet.letters.contains(firstChar) {
                sectionChar = String(firstChar).uppercased()
            }

            if self.sectionsChars.contains(sectionChar) == false {
                self.sectionsChars.append(sectionChar)
            }

            var charObjects = self.objectsInSections[sectionChar] ?? []

            charObjects.append(object)

            self.objectsInSections[sectionChar] = charObjects
        }

//        for (key, value) in objectsInSections
//        {
//            self.objectsInSections[key] = value.sorted(by: { (c1, c2) -> Bool in
//                return c1.isBeforeInSearch(c2)
//            })
//        }

        self.sectionsChars.sort()
    }

    public func filter(by text: String) -> Int {
        if text.isEmpty {
            self.objectsFiltered = []
            return 0
        }

        let lowerCaseFilter = text.lowercased()

        if self.objectsSorted is [DPAGContact] {
            let contactsFound: [DPAGContact.EntryTypeServer: [DPAGContact]]

            if AppConfig.isShareExtension {
                let cache = DPAGApplicationFacadeShareExt.cache
                let preferences = DPAGApplicationFacadeShareExt.preferences

                contactsFound = DPAGApplicationFacade.contactsWorker.searchContacts(groupId: preferences.sharedContainerConfig.groupID, searchText: lowerCaseFilter, orderByFirstName: cache.personSortOrder == .givenName)

            } else {
                let cache = DPAGApplicationFacade.cache
                let preferences = DPAGApplicationFacade.preferences

                contactsFound = DPAGApplicationFacade.contactsWorker.searchContacts(groupId: preferences.sharedContainerConfig.groupID, searchText: lowerCaseFilter, orderByFirstName: cache.personSortOrder == .givenName)
            }

            var contactsListed: [T] = []

            if let contacts = contactsFound[.privat] as? [T] {
                contactsListed.append(contentsOf: contacts)
            }
            if let contacts = contactsFound[.company] as? [T] {
                contactsListed.append(contentsOf: contacts)
            }
            if let contacts = contactsFound[.email] as? [T] {
                contactsListed.append(contentsOf: contacts)
            }

            self.objectsFiltered = contactsListed
        } else {
            self.objectsFiltered = self.objectsSorted.filter { (contact) -> Bool in
                contact.isSearchResult(for: lowerCaseFilter)
            }
        }
//        .sorted(by: { (c1, c2) -> Bool in
//            return c1.isBeforeInSearch(c2)
//        })

        return self.objectsFiltered.count
    }
}

public struct DPAGChannelCategory {
    public var ident: String?
    public var titleKey: String?
    public var imageKey: String?

    public var channelGuids: [String]?

    init(dictCategory: [String: Any]) {
        self.ident = dictCategory["ident"] as? String
        self.titleKey = dictCategory["titleKey"] as? String
        self.imageKey = dictCategory["imageKey"] as? String

        self.channelGuids = dictCategory["@items"] as? [String]
    }
}

public class DPAGChannelCategoryOption {
    var ident: String?
    var defaultValue: String?
}

public class DPAGChannelCategoryToggle: DPAGChannelCategoryOption {}

public class DPAGChannelOptionChildren {
    public private(set) var forValue: String?
    public private(set) var items: [DPAGChannelOption] = []
    public private(set) weak var option: DPAGChannelOption?

    init(children: SIMSChannelOptionChildren, channel: DPAGChannel, option: DPAGChannelOption) {
        self.forValue = children.forValue
        self.option = option

        var itemsNew: [DPAGChannelOption] = []

        if let items = children.items {
            for item in items {
                if let itemOption = item as? SIMSChannelToggle {
                    if let option = DPAGChannelToggle(channelOption: itemOption, channel: channel, parent: self) {
                        itemsNew.append(option)
                    }
                }
            }
        }

        self.items = itemsNew
    }
}

public class DPAGChannelToggle: DPAGChannelOption {
    override public func childrenForCurrentValue() -> [DPAGChannelOption]? {
        for children in self.children {
            if self.isOn, children.forValue == "on" {
                return children.items
            }
            if self.isOn == false, children.forValue == "off" {
                return children.items
            }
        }

        return nil
    }

    static func filter2Dict(filterValue: String?) -> [String: [String: [String]]] {
        if filterValue?.isEmpty ?? true {
            return [:]
        }

        guard let data = filterValue?.data(using: .utf8) else {
            return [:]
        }

        var retVal: [String: [String: [String]]] = [:]

        do {
            if let dictFilter = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: String] {
                for (key, obj) in dictFilter {
                    if obj.isEmpty {
                        retVal[key] = [:]
                    } else {
                        let arrAnd = obj.components(separatedBy: "&")
                        var dictFilterKeys: [String: [String]] = [:]

                        for andElem in arrAnd {
                            let arrOr = andElem.components(separatedBy: "|")
                            var arrOrKey: String?
                            var arrVals: [String] = []

                            for orElem in arrOr {
                                let arrVal = orElem.components(separatedBy: "=")

                                if arrVal.count == 2 {
                                    arrOrKey = arrVal[0]

                                    arrVals.append(arrVal[1])
                                }
                            }

                            if let arrOrKey = arrOrKey {
                                dictFilterKeys[arrOrKey] = arrVals
                            }
                        }

                        retVal[key] = dictFilterKeys
                    }
                }
            }
        } catch {
            DPAGLog(error)
        }

        return retVal
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
            for childOption in children {
                retVal = DPAGChannelOption.mergeFilterDicts(retVal, dict2: childOption.filterForCurrentValue())
            }
        }
        return retVal
    }

    public var isOn: Bool {
        self.value == "on" || self.value == "always"
    }

    public func setOn(_ on: Bool) {
        if self.value != "always" {
            self.value = on ? "on" : "off"
        }
    }

    public func isEnabled() -> Bool {
        self.value != "always"
    }

    override public func setDefaultValue(_ defaultValue: String) {
        if self.value != "always" {
            super.setDefaultValue(defaultValue)
        }
    }
}

public class DPAGChannelOption {
    public private(set) var filterValue: String?
    public private(set) var ident: String = ""
    public private(set) var label: String?
    public private(set) var labelSub: String?
    public fileprivate(set) var value: String?
    weak var channel: DPAGChannel?
    var children: [DPAGChannelOptionChildren] = []
    public private(set) weak var parent: DPAGChannelOptionChildren?

    public class func identFromIdent(_ ident: String?, channel: String) -> String? {
        guard let ident = ident else {
            return nil
        }

        let retVal = String(format: "%@ - %@", channel, ident)

        return retVal
    }

    init?(channelOption: SIMSChannelOption, channel: DPAGChannel, parent: DPAGChannelOptionChildren?) {
        guard let ident = channelOption.ident else {
            return nil
        }

        self.ident = ident
        self.filterValue = channelOption.filterValue
        self.label = channelOption.label
        self.labelSub = channelOption.labelSub
        self.value = channelOption.value
        self.channel = channel
        self.parent = parent

        self.children.removeAll()

        for child in channelOption.children ?? Set() {
            self.children.append(DPAGChannelOptionChildren(children: child, channel: channel, option: self))
        }
    }

    fileprivate func save(in localContext: NSManagedObjectContext) {
        guard let option = SIMSChannelOption.mr_findFirst(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSChannelOption.ident), rightExpression: NSExpression(forConstantValue: self.ident)), in: localContext) else {
            return
        }

        if option.value != self.value {
            option.value = self.value
        }

        for child in self.children {
            for option in child.items {
                option.save(in: localContext)
            }
        }
    }

    public func childrenForCurrentValue() -> [DPAGChannelOption]? {
        nil
    }

    func filterForCurrentValue() -> [String: [String]] {
        [:]
    }

    class func mergeFilterDicts(_ dict: [String: [String]], dict2: [String: [String]]) -> [String: [String]] {
        if dict.keys.count == 0 {
            return dict2
        }
        if dict2.keys.count == 0 {
            return dict
        }

        let dictLoop = dict.count < dict2.count ? dict : dict2
        let dictTest = dict.count < dict2.count ? dict2 : dict

        var dictLoopNew = dictTest

        for filterKey in dictLoop.keys {
            let arrTest = dictTest[filterKey]
            var arrLoop = dictLoop[filterKey]

            if let arrTest = arrTest {
                if arrLoop != nil {
                    for arrValue in arrTest {
                        if arrLoop?.contains(arrValue) == false {
                            arrLoop?.append(arrValue)
                        }
//                        if arrLoop?.firstIndex(of: arrValue) == nil {
//                            arrLoop?.append(arrValue)
//                        }
                    }
                } else {
                    arrLoop = arrTest
                }
            }
            dictLoopNew[filterKey] = arrLoop
        }

        return dictLoopNew
    }

    public func setDefaultValue(_ defaultValue: String) {
        self.value = defaultValue
    }

    fileprivate func option(forIdent ident: String) -> DPAGChannelOption? {
        if self.ident == ident {
            return self
        }

        for child in self.children {
            for option in child.items {
                if let retVal = option.option(forIdent: ident) {
                    return retVal
                }
            }
        }

        return nil
    }
}

public class DPAGObject: Hashable {
    public static func == (lhs: DPAGObject, rhs: DPAGObject) -> Bool {
        lhs.guid == rhs.guid
    }

//    public var hashValue: Int
//    {
//        return self.guid.hashValue
//    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.guid)
    }

    public var guid: String

    init(guid: String) {
        self.guid = guid
    }

    func update(with _: SIMSManagedObject) {}
}

public class DPAGChannel: DPAGObject {
    public enum AssetType: String, CaseIterable {
        case itemBackground = "ib",
            itemForeground = "pl",
            chatBackground = "cb",
            profile = "ic",
            itemPromotedBackground = "prb",
            itemPromotedForeground = "prl"
    }

    public private(set) var aes_key: String?
    public private(set) var checksum: String?
    public private(set) var iv: String?
    public private(set) var name_long: String?
    public private(set) var name_short: String?
    public private(set) var options: String?
    public private(set) var additionalData: String?
    public private(set) var stream: String?
    public private(set) var feedType: DPAGChannelType = .channel
    public private(set) var rootOptions: [DPAGChannelOption] = []

    public private(set) var serviceID: String?
    public private(set) var isSubscribed: Bool = false
    public private(set) var isDeleted: Bool = false
    public private(set) var isMandatory: Bool = false
    public private(set) var isPromoted: Bool = false
    public private(set) var externalURL: String?
    public private(set) var searchText: String?

    public private(set) var promotedCategoryIdents: [String]?
    public private(set) var promotedCategoryExternalUrls: [String: String]?

    public private(set) var colorChatBackground: UIColor?
    public private(set) var colorChatBackgroundLogo: UIColor?
    public private(set) var colorChatListBackground: UIColor?

    public private(set) var colorNavigationbar: UIColor?
    public private(set) var colorNavigationbarAction: UIColor?
    public private(set) var colorNavigationbarText: UIColor?

    public private(set) var colorDetailsButtonFollow: UIColor?
    public private(set) var colorDetailsButtonFollowText: UIColor?
    public private(set) var colorDetailsButtonFollowDisabled: UIColor?
    public private(set) var colorDetailsBackground: UIColor?
    public private(set) var colorDetailsBackgroundLogo: UIColor?
    public private(set) var colorDetailsLabelEnabled: UIColor?
    public private(set) var colorDetailsLabelDisabled: UIColor?
    public private(set) var colorDetailsToggle: UIColor?
    public private(set) var colorDetailsToggleOff: UIColor?
    public private(set) var colorDetailsText: UIColor?

    public private(set) var recommendationText: String?
    public private(set) var feedbackContactPhoneNumber: String?
    public private(set) var feedbackContactNickname: String?

    private var layout: String?

    init?(channel: SIMSChannel) {
        guard let guid = channel.guid else {
            return nil
        }

        super.init(guid: guid)

        self.update(with: channel)
    }

    override func update(with obj: SIMSManagedObject) {
        guard let channel = obj as? SIMSChannel else {
            return
        }
        guard let guid = channel.guid else {
            return
        }

        self.guid = guid

        self.aes_key = channel.aes_key
        self.checksum = channel.checksum
        self.iv = channel.iv
        self.name_long = channel.name_long
        self.name_short = channel.name_short
        self.options = channel.options
        self.additionalData = channel.additionalData

        self.feedType = channel.validFeedType

        self.stream = channel.stream?.guid

        self.serviceID = channel.serviceID
        self.isSubscribed = (channel.subscribed?.boolValue ?? false)
        self.isDeleted = (channel.stream?.wasDeleted?.boolValue ?? false)
        self.isMandatory = channel.isMandatory
        self.isPromoted = channel.isPromoted
        self.externalURL = channel.externalURL
        self.searchText = channel.searchText

        self.promotedCategoryIdents = channel.promotedCategoryIdents()
        self.promotedCategoryExternalUrls = channel.promotedCategoryExternalUrls()

        self.colorChatBackground = channel.colorChatBackground
        self.colorChatBackgroundLogo = channel.colorChatBackgroundLogo
        self.colorChatListBackground = channel.colorChatListBackground

        self.colorNavigationbar = channel.colorNavigationbar
        self.colorNavigationbarAction = channel.colorNavigationbarAction
        self.colorNavigationbarText = channel.colorNavigationbarText

        self.colorDetailsButtonFollow = channel.colorDetailsButtonFollow
        self.colorDetailsButtonFollowText = channel.colorDetailsButtonFollowText
        self.colorDetailsButtonFollowDisabled = channel.colorDetailsButtonFollowDisabled
        self.colorDetailsBackground = channel.colorDetailsBackground
        self.colorDetailsBackgroundLogo = channel.colorDetailsBackgroundLogo
        self.colorDetailsLabelEnabled = channel.colorDetailsLabelEnabled
        self.colorDetailsLabelDisabled = channel.colorDetailsLabelDisabled
        self.colorDetailsToggle = channel.colorDetailsToggle
        self.colorDetailsToggleOff = channel.colorDetailsToggleOff
        self.colorDetailsText = channel.colorDetailsText

        self.recommendationText = channel.recommendationText
        self.feedbackContactPhoneNumber = channel.feedbackContactPhoneNumber
        self.feedbackContactNickname = channel.feedbackContactNickname

        self.layout = channel.layout

        var rootOptionsNew: [DPAGChannelOption] = []

        if let rootOptions = channel.rootOptions {
            for rootOption in rootOptions {
                if let rootOptionElem = rootOption as? SIMSChannelToggle {
                    if let option = DPAGChannelToggle(channelOption: rootOptionElem, channel: self, parent: nil) {
                        rootOptionsNew.append(option)
                    }
                }
            }
        }

        self.rootOptions = rootOptionsNew
    }

    public func rollback() {
        DPAGApplicationFacade.cache.rollbackChannel(channelGuid: self.guid)
    }

    public func save() {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            for option in self.rootOptions {
                option.save(in: localContext)
            }
        }
    }

    public var streamState: DPAGChatStreamState {
        .readOnly
    }

    public func externalURLForPromotedCategory(_ categoryIdent: String?) -> String? {
        guard let ident = categoryIdent else { return nil }

        return self.promotedCategoryExternalUrls?[ident]
    }

    private func loadDefaults(_ items: [[String: Any]], withDict: [String: String]) -> [String: String] {
        var dict = withDict

        for dictItem in items {
            if let optionIdent = dictItem[DPAGStrings.JSON.ChannelOption.DEFAULT_VALUE] as? String, let optionvalue = dictItem[DPAGStrings.JSON.ChannelOption.IDENT] as? String {
                if optionIdent.isEmpty == false {
                    if let optionIdentWithChannel = DPAGChannelOption.identFromIdent(optionIdent, channel: self.guid) {
                        dict.updateValue(optionvalue, forKey: optionIdentWithChannel)
                    }
                }

                if let children = dictItem[DPAGStrings.JSON.ChannelOptionToggle.CHILDREN] as? [[String: Any]] {
                    for dictChild in children {
                        if let subitems = dictChild[DPAGStrings.JSON.ChannelOption.SUBITEMS] as? [[String: Any]] {
                            dict = self.loadDefaults(subitems, withDict: dict)
                        }
                    }
                }
            }
        }

        return dict
    }

    public func optionValuesForCategory(_ categoryIdent: String?) -> [String: String] {
        if let data = self.layout?.data(using: .utf8) {
            do {
                if let item = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] {
                    var retVal: [String: String] = [:]

                    if let items = item["@items"] as? [[String: Any]] {
                        retVal = self.loadDefaults(items, withDict: retVal)
                    }

                    if categoryIdent == nil {
                        return retVal
                    }

                    if let allCats = item["@categories"] as? [[String: Any]] {
                        for dictCat in allCats {
                            if let ident = dictCat["ident"] as? String {
                                let options = dictCat["@children"] as? [[String: Any]]

                                if categoryIdent == ident {
                                    guard let optionsCat = options, optionsCat.count > 0 else {
                                        return retVal
                                    }

                                    for option in optionsCat {
                                        if let optionIdent = option["ident"] as? String, let optionvalue = option["value"] as? String {
                                            if optionIdent.isEmpty == false {
                                                if let optionIdentKey = DPAGChannelOption.identFromIdent(optionIdent, channel: self.guid) {
                                                    retVal[optionIdentKey] = optionvalue
                                                }
                                            }
                                        }
                                    }

                                    return retVal
                                }
                            }
                        }
                    }
                }
            } catch {
                DPAGLog(error)
            }
        }
        return [:]
    }

    public func currentFilter() -> String {
        var dictFilter: [String: [String]] = [:]

        for rootOption in self.rootOptions {
            dictFilter = DPAGChannelOption.mergeFilterDicts(dictFilter, dict2: rootOption.filterForCurrentValue())
        }

        return DPAGChannel.joinFilter(dictFilter)
    }

    class func joinFilter(_ dictFilter: [String: [String]]?) -> String {
        var filter: String?

        dictFilter?.forEach {
            var filterVal: String?

            for val in $0.1 {
                if filterVal != nil {
                    filterVal = filterVal?.appendingFormat("|%@=%@", $0.0, val)
                } else {
                    filterVal = String(format: "%@=%@", $0.0, val)
                }
            }

            if let filterVal = filterVal {
                if filter != nil {
                    filter = filter?.appendingFormat("|%@", filterVal)
                } else {
                    filter = filterVal
                }
            }
        }

        return filter ?? ""
    }

    public func option(forIdent ident: String) -> DPAGChannelOption? {
        for option in self.rootOptions {
            if let retVal = option.option(forIdent: ident) {
                return retVal
            }
        }
        return nil
    }
}

public class DPAGAccount: DPAGObject {
    public private(set) var hasChanged: NSNumber?
    private var key_guid: String?
    public private(set) var keyGuid: String?

    public private(set) var accountState: DPAGAccountState = .unknown
    public private(set) var sharedSecret: String?
    public private(set) var privateKey: String?
    public private(set) var companyEMailAddressStatus: DPAGAccountCompanyEmailStatus = .none
    public private(set) var triesLeftEmail: Int = 0
    public private(set) var companyPhoneNumberStatus: DPAGAccountCompanyPhoneNumberStatus = .none
    public private(set) var triesLeftPhoneNumber: Int = 0
    public private(set) var isCompanyAccountEmailConfirmed: Bool = false
    public private(set) var isCompanyAccountPhoneNumberConfirmed: Bool = true
    public private(set) var companyManagedState: DPAGAccountCompanyManagedState = .unknown
    public private(set) var isCompanyUserRestricted: Bool = false
    public private(set) var companyPublicKey: String?
    public private(set) var companyGuid: String?
    public private(set) var companyName: String?
    public private(set) var companySeed: String?
    public private(set) var companySalt: String?
    public private(set) var companyEncryptionEmail: String?
    public private(set) var companyEncryptionPhoneNumber: String?
    public private(set) var aesKeyCompany: String?
    public private(set) var aesKeyCompanyUserData: String?

    init?(account: DPAGSharedContainerExtensionSending.Account) {
        super.init(guid: account.guid)

        self.update(with: account)
    }

    func update(with account: DPAGSharedContainerExtensionSending.Account) {
        self.isCompanyUserRestricted = account.isCompanyUserRestricted
    }

    init?(account: SIMSAccount) {
        guard let guid = account.guid else {
            return nil
        }

        super.init(guid: guid)

        self.update(with: account)
    }

    override func update(with obj: SIMSManagedObject) {
        guard let account = obj as? SIMSAccount else {
            return
        }
        guard let guid = account.guid else {
            return
        }

        self.guid = guid

        self.hasChanged = account.hasChanged
        self.key_guid = account.key_guid
        self.keyGuid = account.keyRelationship?.guid

        self.accountState = account.accountState
        self.sharedSecret = account.sharedSecret
        self.privateKey = account.privateKey

        self.companyEMailAddressStatus = account.companyEMailAddressStatus
        self.triesLeftEmail = account.triesLeftEmail
        self.isCompanyAccountEmailConfirmed = account.isCompanyAccountEmailConfirmed()

        self.companyPhoneNumberStatus = account.companyPhoneNumberStatus
        self.triesLeftPhoneNumber = account.triesLeftPhoneNumber
        self.isCompanyAccountPhoneNumberConfirmed = account.isCompanyAccountPhoneNumberConfirmed()

        self.companyManagedState = account.companyManagedState
        self.isCompanyUserRestricted = account.isCompanyUserRestricted
        self.companyPublicKey = account.companyPublicKey
        self.companyGuid = account.companyInfo[SIMS_GUID] as? String
        self.companyName = account.companyName
        self.companySalt = account.companySalt
        self.companySeed = account.companySeed
        self.companyEncryptionEmail = account.companyEncryptionEmail
        self.companyEncryptionPhoneNumber = account.companyEncryptionPhoneNumber
        self.aesKeyCompany = account.aesKeyCompany
        self.aesKeyCompanyUserData = account.aesKeyCompanyUserData
    }

    var accountSending: DPAGSharedContainerExtensionSending.Account {
        DPAGSharedContainerExtensionSending.Account(account: self)
    }
}

public class DPAGContactEdit: DPAGObject {
    public var nickname: String?
    public var status: String?
    public var firstName: String?
    public var lastName: String?
    public var eMailAddress: String?
    public var phoneNumber: String?
    public var department: String?
    public var image: UIImage?

    override public init(guid: String) {
        super.init(guid: guid)
    }
}

public class DPAGPerson: DPAGObject, DPAGSearchListModelEntry {
    public struct DPAGPersonEmailAddress {
        public var label: String?
        public var value: String
    }

    public struct DPAGPersonPhoneNumber {
        public var label: String?
        public var value: String
    }

    public private(set) var firstName: String?
    public private(set) var lastName: String?
    public private(set) var eMailAddresses: [DPAGPersonEmailAddress] = []
    public private(set) var phoneNumbers: [DPAGPersonPhoneNumber] = []
    public private(set) var image: UIImage?

    init?(contact: CNContact) {
        if contact.givenName.isEmpty, contact.familyName.isEmpty {
            return nil
        }
        if contact.phoneNumbers.count == 0, contact.emailAddresses.count == 0 {
            return nil
        }

        super.init(guid: UUID().uuidString)

        self.firstName = contact.givenName
        self.lastName = contact.familyName
        for emailAddress in contact.emailAddresses {
            self.eMailAddresses.append(DPAGPersonEmailAddress(label: emailAddress.label, value: emailAddress.value as String))
        }
        for phoneNumber in contact.phoneNumbers {
            self.phoneNumbers.append(DPAGPersonPhoneNumber(label: phoneNumber.label, value: phoneNumber.value.stringValue))
        }

        if contact.imageDataAvailable, let imageData = contact.imageData, let image = UIImage(data: imageData) {
            self.image = image
        }
    }

    public var sortString: String {
        var retVal: String?

        switch DPAGApplicationFacade.cache.personSortOrder {
        case .familyName:
            retVal = self.lastName ?? self.firstName
        case .givenName, .userDefault, .none:
            retVal = self.firstName ?? self.lastName
        @unknown default:
            DPAGLog("Switch with unknown value: \(DPAGApplicationFacade.cache.personSortOrder.rawValue)", level: .warning)
        }

        return retVal ?? ""
    }

    public func isBeforeInSearch(_ rhs: DPAGPerson) -> Bool {
        self.sortString.lowercased() < rhs.sortString.lowercased()
    }

    public func isSearchResult(for text: String) -> Bool {
        if self.firstName?.lowercased().range(of: text) != nil {
            return true
        }
        if self.lastName?.lowercased().range(of: text) != nil {
            return true
        }
        return false
    }

    public var displayName: String {
        var retVal: String?

        switch DPAGApplicationFacade.cache.personDisplayNameOrder {
        case .familyNameFirst:
            if let lastName = self.lastName {
                retVal = lastName

                if let firstName = self.firstName {
                    retVal = lastName + " " + firstName
                }
            } else {
                retVal = self.firstName
            }
        case .givenNameFirst, .userDefault:
            if let firstName = self.firstName {
                retVal = firstName

                if let lastName = self.lastName {
                    retVal = firstName + " " + lastName
                }
            } else {
                retVal = self.lastName
            }
        @unknown default:
            DPAGLog("Switch with unknown value: \(DPAGApplicationFacade.cache.personDisplayNameOrder.rawValue)", level: .warning)
        }

        return retVal ?? ""
    }
}

public enum DPAGContactImageType: Int {
    private static let kSizeContactInfoImage = CGSize(width: 200, height: 200)
    private static let kSizeChatListImage = CGSize(width: 64, height: 64)
    private static let kSizeContactImage = CGSize(width: 48, height: 48)
    private static let kSizeChatStreamImage = CGSize(width: 40, height: 40)
    private static let kSizeChatStreamInfoImage = CGSize(width: 30, height: 30)

    case barButton, chat, contactList, chatList, profile, barButtonSettings

    var size: CGSize {
        switch self {
        case .barButtonSettings:
            return DPAGContactImageType.kSizeChatStreamInfoImage

        case .barButton:
            return DPAGContactImageType.kSizeChatStreamInfoImage

        case .chat:
            return DPAGContactImageType.kSizeChatStreamImage

        case .contactList:
            return DPAGContactImageType.kSizeContactImage

        case .chatList:
            return DPAGContactImageType.kSizeChatListImage

        case .profile:
            return DPAGContactImageType.kSizeContactInfoImage
        }
    }
}

public struct DPAGContactAesKeys: Codable {
    public let aesKey: String
    public let recipientEncAesKey: String
    public let senderEncAesKey: String

    public init(aesKey: String, recipientEncAesKey: String, senderEncAesKey: String) {
        self.aesKey = aesKey
        self.recipientEncAesKey = recipientEncAesKey
        self.senderEncAesKey = senderEncAesKey
    }
}

public class DPAGGroup: DPAGObject, DPAGSearchListModelEntry {
    public private(set) var name: String?
    public private(set) var aesKey: String?
    public private(set) var memberNames: String?
    public private(set) var countMembers: Int = 0
    public private(set) var guidOwner: String?
    public private(set) var groupType: DPAGGroupType = .default
    public private(set) var isDeleted: Bool = false
    public private(set) var isReadOnly: Bool = false
    public private(set) var confidenceState: DPAGConfidenceState = .none
    public private(set) var isConfirmed: Bool = false
    public private(set) var lastMessageDate: Date?
    public private(set) var imageData: String?
    public private(set) var adminGuids: [String] = []
    public private(set) var memberGuids: [String] = []

    init(group: DPAGSharedContainerExtensionSending.Group) {
        super.init(guid: group.guid)
        self.update(with: group)
    }

    func update(with group: DPAGSharedContainerExtensionSending.Group) {
        self.name = group.name
        self.aesKey = group.aesKey
        self.memberNames = group.memberNames
        self.countMembers = group.countMembers
        self.guidOwner = group.guidOwner
        self.groupType = DPAGGroupType(rawValue: group.groupType) ?? .default
        self.isDeleted = group.isDeleted
        self.memberNames = group.memberNames
        self.confidenceState = DPAGConfidenceState(rawValue: group.confidenceState) ?? .none
        self.isConfirmed = group.isConfirmed
        self.isReadOnly = group.isReadOnly
        self.aesKey = group.aesKey
        self.lastMessageDate = group.lastMessageDate
        self.imageData = group.imageData
    }

    init?(group: SIMSGroup) {
        guard let guid = group.guid else { return nil }
        super.init(guid: guid)
        self.update(with: group)
    }

    override func update(with obj: SIMSManagedObject) {
        guard let group = obj as? SIMSGroup else { return }
        self.name = group.groupName
        self.aesKey = group.aesKey
        self.memberNames = group.memberNames()
        self.countMembers = group.memberCount()
        self.guidOwner = group.ownerGuid
        self.groupType = group.typeGroup
        self.isDeleted = group.wasDeleted || (group.stream?.wasDeleted?.boolValue ?? false)
        self.confidenceState = group.confidenceState
        self.isConfirmed = group.stream?.isConfirmed?.boolValue ?? false
        self.isReadOnly = group.isReadonly || (group.stream?.optionsStream.contains(.isReadOnly) ?? false) || (group.stream?.streamState ?? .readOnly) != .write
        self.adminGuids = group.adminGuids
        self.memberGuids = group.members?.compactMap { $0.accountGuid } ?? []
        self.lastMessageDate = group.stream?.lastMessageDate
        if let decAesKey = group.aesKey {
            do {
                if let decAesKeyDict = try XMLReader.dictionary(forXMLString: decAesKey) {
                    self.aesKey = decAesKeyDict["key"] as? String
                }
            } catch {
                DPAGLog(error)
            }
        }
    }

    var groupSending: DPAGSharedContainerExtensionSending.Group {
        DPAGSharedContainerExtensionSending.Group(group: self)
    }

    public var streamState: DPAGChatStreamState {
        (self.isDeleted || self.isReadOnly || self.isConfirmed == false) ? .readOnly : .write
    }

    public var sortString: String {
        self.name ?? "??"
    }

    public func isBeforeInSearch(_ rhs: DPAGGroup) -> Bool {
        if self.sortString.lowercased() == rhs.sortString.lowercased() {
            return self.guid < rhs.guid
        }
        return self.sortString.lowercased() < rhs.sortString.lowercased()
    }

    public func isSearchResult(for text: String) -> Bool {
        self.name?.lowercased().range(of: text) != nil
    }
}

public class DPAGContact: DPAGObject, DPAGSearchListModelEntry {
    static let CONTACT_NAME_UNKNOWN = DPAGLocalizedString("chats.contact.unknown", comment: "")

    public enum EntryTypeServer: Int {
        case privat, company, email, meMyselfAndI
    }

    public enum EntryTypeLocal: Int {
        case hidden, privat
    }

    public private(set) var accountID: String?

    public private(set) var publicKey: String?
    public private(set) var profilKey: String?

    public private(set) var firstName: String?
    public private(set) var lastName: String?
    public private(set) var department: String?

    public private(set) var eMailAddress: String?
    public private(set) var eMailDomain: String?
    public private(set) var phoneNumber: String?

    public private(set) var attributedDisplayName: NSAttributedString?

    public private(set) var statusMessage: String?

    public private(set) var confidence: DPAGConfidenceState = .low

    public private(set) var createdAt: Date?
    public private(set) var statusMessageCreatedAt: Date?
    public private(set) var updatedAt: Date?
    public private(set) var lastMessageDate: Date?
    public private(set) var streamGuid: String?

    public private(set) var mandantIdent: String = DPAGMandant.IDENT_DEFAULT
    public internal(set) var nickName: String?

    public private(set) var isDeleted: Bool = false
    public private(set) var isConfirmed: Bool = false
    public private(set) var isBlocked = false

    private var _isReadOnly = false
    public private(set) var isReadOnly: Bool {
        get {
            if AppConfig.isShareExtension {
                let cache = DPAGApplicationFacadeShareExt.cache
                guard ((cache.account?.isCompanyUserRestricted ?? false) && self.entryTypeServer != .company) == false else {
                    return true
                }
            } else {
                let cache = DPAGApplicationFacade.cache
                guard ((cache.account?.isCompanyUserRestricted ?? false) && self.entryTypeServer != .company) == false else {
                    return true
                }
            }
            return self._isReadOnly
        }
        set {
            self._isReadOnly = newValue
        }
    }

    private var _streamState: DPAGChatStreamState = .readOnly
    public private(set) var streamState: DPAGChatStreamState {
        get {
            if AppConfig.isShareExtension {
                let cache = DPAGApplicationFacadeShareExt.cache
                guard ((cache.account?.isCompanyUserRestricted ?? false) && self.entryTypeServer != .company) == false else {
                    return .readOnly
                }
            } else {
                let cache = DPAGApplicationFacade.cache
                guard ((cache.account?.isCompanyUserRestricted ?? false) && self.entryTypeServer != .company) == false else {
                    return .readOnly
                }
            }
            return self._streamState
        }
        set {
            self._streamState = newValue
        }
    }

    public private(set) var checksum: String?
    public private(set) var imageChecksum: String?

    public private(set) var entryTypeServer: DPAGContact.EntryTypeServer = .privat
    public private(set) var entryTypeLocal: DPAGContact.EntryTypeLocal = .hidden

    public private(set) var imageDataStr: String?
    public private(set) var hasImage: Bool = false

    public private(set) var oooStatusState: String?
    public private(set) var oooStatusText: String?
    public private(set) var oooStatusValid: String?

    public private(set) var aesKeys: DPAGContactAesKeys?

    init?(contactSearchFTS: String) {
        guard let data = contactSearchFTS.data(using: .utf8), let attributes = try? JSONDecoder().decode(DPAGDBFullTextHelper.FtsDatabaseContactAttributes.self, from: data) else { return nil }
        super.init(guid: attributes.accountGuid)
        self.accountID = attributes.accountID
        self.firstName = attributes.firstName
        self.lastName = attributes.lastName
        if AppConfig.isShareExtension {
            self.mandantIdent = attributes.mandant ?? (DPAGApplicationFacadeShareExt.preferences.mandantIdent ?? DPAGMandant.default.ident)
        } else {
            self.mandantIdent = attributes.mandant ?? (DPAGApplicationFacade.preferences.mandantIdent ?? DPAGMandant.default.ident)
        }
        self.department = attributes.department
        self.nickName = attributes.nickName
        self.statusMessage = attributes.status
        self.eMailAddress = attributes.eMailAddress
        self.phoneNumber = attributes.phoneNumber
        self.confidence = DPAGConfidenceState(rawValue: attributes.confidenceState) ?? .none
        self.entryTypeServer = EntryTypeServer(rawValue: attributes.entryTypeServer) ?? .privat
    }

    init(contact: DPAGSharedContainerExtensionSending.Contact) {
        super.init(guid: contact.guid)
        self.update(with: contact)
    }

    init(chat: DPAGSharedContainerExtensionSending.Chat) {
        super.init(guid: chat.guid)
        self.update(with: chat)
    }

    func update(with contact: DPAGSharedContainerExtensionSending.Contact) {
        self.accountID = contact.accountID
        self.publicKey = contact.publicKey
        self.firstName = contact.firstName
        self.lastName = contact.lastName
        self.nickName = contact.nickName
        self.statusMessage = contact.statusMessage
        self.mandantIdent = contact.mandantIdent
        self.eMailAddress = contact.eMailAddress
        self.eMailDomain = contact.eMailDomain
        self.phoneNumber = contact.phoneNumber
        self.confidence = DPAGConfidenceState(rawValue: contact.confidenceState) ?? .none
        self.streamGuid = contact.streamGuid
        self.isDeleted = contact.isDeleted
        self.isConfirmed = contact.isConfirmed
        self.isBlocked = contact.isBlocked
        self.isReadOnly = contact.isReadOnly
        self.entryTypeLocal = EntryTypeLocal(rawValue: contact.entryTypeLocal) ?? .hidden
        self.entryTypeServer = EntryTypeServer(rawValue: contact.entryTypeServer) ?? .privat
        self.imageDataStr = contact.imageDataStr
        self.lastMessageDate = contact.lastMessageDate
        self.aesKeys = contact.aesKeys
    }

    func update(with chat: DPAGSharedContainerExtensionSending.Chat) {
        self.accountID = chat.accountID
        self.publicKey = chat.publicKey
        self.firstName = chat.firstName
        self.lastName = chat.lastName
        self.nickName = chat.nickName
        self.statusMessage = chat.statusMessage
        self.mandantIdent = chat.mandantIdent
        self.eMailAddress = chat.eMailAddress
        self.eMailDomain = chat.eMailDomain
        self.phoneNumber = chat.phoneNumber
        self.confidence = DPAGConfidenceState(rawValue: chat.confidenceState) ?? .none
        self.streamGuid = chat.streamGuid
        self.isDeleted = chat.isDeleted
        self.isConfirmed = chat.isConfirmed
        self.isBlocked = chat.isBlocked
        self.isReadOnly = chat.isReadOnly
        self.entryTypeLocal = EntryTypeLocal(rawValue: chat.entryTypeLocal) ?? .hidden
        self.entryTypeServer = EntryTypeServer(rawValue: chat.entryTypeServer) ?? .privat
        self.imageDataStr = chat.imageDataStr
        self.lastMessageDate = chat.lastMessageDate
        self.aesKeys = chat.aesKeys
    }

    init?(contact: SIMSContactIndexEntry) {
        guard let guid = contact.guid else { return nil }
        super.init(guid: guid)
        self.update(with: contact)
    }

    override func update(with obj: SIMSManagedObject) {
        guard let contact = obj as? SIMSContactIndexEntry else { return }
        self.accountID = contact[.ACCOUNT_ID]
        self.entryTypeServer = contact.entryTypeServer
        self.entryTypeLocal = contact.entryTypeLocal
        self.createdAt = contact[.CREATED_AT]
        self.isDeleted = contact[.IS_DELETED]
        self.lastMessageDate = contact.stream?.lastMessageDate
        self.profilKey = contact[.PROFIL_KEY]
        self.phoneNumber = contact[.PHONE_NUMBER]
        self.eMailAddress = contact[.EMAIL_ADDRESS]
        self.eMailDomain = contact[.EMAIL_DOMAIN]
        self.firstName = contact[.FIRST_NAME]
        self.lastName = contact[.LAST_NAME]
        self.department = contact[.DEPARTMENT]
        self.mandantIdent = contact[.MANDANT_IDENT] ?? DPAGMandant.default.ident
        self.publicKey = contact[.PUBLIC_KEY]
        self.updatedAt = contact[.UPDATED_AT]
        self.streamGuid = contact.stream?.guid
        self.nickName = contact[.NICKNAME]
        self.statusMessage = contact[.STATUSMESSAGE]
        self.statusMessageCreatedAt = contact[.STATUS_MESSAGE_CREATED_AT]
        self.isBlocked = contact[.IS_BLOCKED]
        self.isReadOnly = contact.isReadOnly
        self.isConfirmed = contact.isConfirmed
        self.streamState = contact.streamState
        self.checksum = contact[.CHECKSUM]
        self.imageChecksum = contact[.IMAGE_CHECKSUM]
        self.imageDataStr = contact[.IMAGE_DATA]
        self.removeCachedImages()
        self.confidence = contact.confidenceState
        self.lettersForPlaceholderInternal = nil
        self.oooStatusState = contact[.OOO_STATUS_STATUS_STATE]
        self.oooStatusText = contact[.OOO_STATUS_STATUS_TEXT]
        self.oooStatusValid = contact[.OOO_STATUS_STATUS_VALID]
        do {
            self.aesKeys = try contact.aesKey(accountPublicKey: "", createNew: false)
        } catch {
            DPAGLog("error: \(error)")
        }
    }

    var contactSending: DPAGSharedContainerExtensionSending.Contact {
        DPAGSharedContainerExtensionSending.Contact(contact: self)
    }

    public func isSearchResult(for text: String) -> Bool {
        if self.firstName?.lowercased().range(of: text) != nil {
            return true
        }
        if self.lastName?.lowercased().range(of: text) != nil {
            return true
        }
        if self.nickName?.lowercased().range(of: text) != nil {
            return true
        }
        if self.accountID?.lowercased().range(of: text) != nil {
            return true
        }
        if self.phoneNumber?.lowercased().range(of: text) != nil {
            return true
        }
        if self.eMailAddress?.lowercased().range(of: text) != nil {
            return true
        }
        if self.eMailDomain?.lowercased().range(of: text) != nil {
            return true
        }
        return false
    }

    public var displayName: String {
        if self.guid.isSystemChatGuid {
            return String(format: DPAGLocalizedString("chat.system.nickname"), DPAGMandant.default.name)
        }

        var retVal: String?
        let personDisplayNameOrder: CNContactDisplayNameOrder

        if AppConfig.isShareExtension {
            personDisplayNameOrder = DPAGApplicationFacadeShareExt.cache.personDisplayNameOrder
        } else {
            personDisplayNameOrder = DPAGApplicationFacade.cache.personDisplayNameOrder
        }

        switch personDisplayNameOrder {
        case .familyNameFirst:
            if let lastName = self.lastName, lastName.isEmpty == false {
                retVal = lastName

                if let firstName = self.firstName, firstName.isEmpty == false {
                    retVal = lastName + " " + firstName
                }
            } else if let firstName = self.firstName, firstName.isEmpty == false {
                retVal = self.firstName
            }
        case .givenNameFirst, .userDefault:
            if let firstName = self.firstName, firstName.isEmpty == false {
                retVal = firstName

                if let lastName = self.lastName, lastName.isEmpty == false {
                    retVal = firstName + " " + lastName
                }
            } else if let lastName = self.lastName, lastName.isEmpty == false {
                retVal = self.lastName
            }
        @unknown default:
            DPAGLog("Switch with unknown value: \(personDisplayNameOrder.rawValue)", level: .warning)
        }

        return (retVal ?? self.nickName) ?? (self.accountID ?? DPAGContact.CONTACT_NAME_UNKNOWN)
    }

    public func isBeforeInSearch(_ rhs: DPAGContact) -> Bool {
        if self.sortString.lowercased() == rhs.sortString.lowercased() {
            if self.mandantIdent.lowercased() == rhs.mandantIdent.lowercased() {
                return (self.accountID ?? "") < (rhs.accountID ?? "")
            }
            return self.mandantIdent < rhs.mandantIdent
        }
        return self.sortString.lowercased() < rhs.sortString.lowercased()
    }

    public var statusMessageFallback: String? {
        if self.mandantIdent == "default", self.statusMessage?.isEmpty ?? true {
            return DPAGLocalizedString("settings.statusWorker.firstMessage.default", comment: "")
        }
        return self.statusMessage
    }

    private var images: [DPAGContactImageType: UIImage] = [:]

    public func image(for imageType: DPAGContactImageType) -> UIImage? {
        if let image = self.images[imageType] {
            return image
        }
        if let imageDataStr = self.imageDataStr, let imageData = Data(base64Encoded: imageDataStr, options: .ignoreUnknownCharacters), let image = imageData.resized(size: imageType.size)?.circleImage() {
            self.images[imageType] = image
            self.hasImage = true
            return image
        }
        let letters = self.lettersForPlaceholder
        let color = DPAGHelperEx.color(forPlaceholderLetters: letters)
        if let image = DPAGUIImageHelper.imageForPlaceholder(color: color, letters: letters, imageType: imageType) {
            self.images[imageType] = image
            return image
        }
        return DPAGImageProvider.shared[.kImagePlaceholderSingle]
    }

    func removeCachedImages() {
        self.images.removeAll()
        self.hasImage = false
    }

    public var sortString: String {
        var retVal: String

        let personSortOrder: CNContactSortOrder

        if AppConfig.isShareExtension {
            personSortOrder = DPAGApplicationFacadeShareExt.cache.personSortOrder
        } else {
            personSortOrder = DPAGApplicationFacade.cache.personSortOrder
        }

        switch personSortOrder {
        case .familyName:
            retVal = (self.lastName ?? "") + (self.firstName ?? "")
        case .givenName, .userDefault, .none:
            retVal = (self.firstName ?? "") + (self.lastName ?? "")
        @unknown default:
            DPAGLog("Switch with unknown value: \(personSortOrder.rawValue)", level: .warning)
            retVal = ""
        }

        return retVal + (self.nickName ?? "")
    }

    private var lettersForPlaceholderInternal: String?

    var lettersForPlaceholder: String {
        if let lettersForPlaceholderInternal = self.lettersForPlaceholderInternal {
            return lettersForPlaceholderInternal
        }

        let name = self.displayName

        let letters = DPAGUIImageHelper.lettersForPlaceholder(name: name)

        self.lettersForPlaceholderInternal = letters

        return letters
    }

    public func setIsDeleted(_ isDeleted: Bool) {
        self.isDeleted = isDeleted
    }
}
