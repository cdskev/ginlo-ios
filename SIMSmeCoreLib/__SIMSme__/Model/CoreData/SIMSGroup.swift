//
//  SIMSGroup.swift
//  SIMSme
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

public struct SIMSGroupInvitation {
    public let invitationGuid: String
    public let groupGuid: String

    public init(invitationGuid: String, andGroupGuid groupGuid: String) {
        self.invitationGuid = invitationGuid
        self.groupGuid = groupGuid
    }
}

class SIMSGroup: SIMSManagedObjectEncrypted {
    @NSManaged var createdAt: Date?
    @NSManaged var invitedAt: Date?
    @NSManaged var ownerGuid: String?
    @NSManaged var members: Set<SIMSGroupMember>?
    @NSManaged var stream: SIMSGroupStream?
    @NSManaged var jsonData: String?
    @NSManaged var type: NSNumber?
    @NSManaged var additionalData: String?

    // Insert code here to add functionality to your managed object subclass

    private static let ADMINS = "admins"
    private static let WRITERS = "writers"

    var adminGuids: [String] {
        if let jsonData = self.jsonData {
            do {
                if let data = jsonData.data(using: .utf8), let jsonDict = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any], let adminGuids = jsonDict[SIMSGroup.ADMINS] as? [String] {
                    return adminGuids
                }
            } catch {
                DPAGLog(error)
            }
        }
        return []
    }

    var writerGuids: [String] {
        if let jsonData = self.jsonData {
            do {
                if let data = jsonData.data(using: .utf8), let jsonDict = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any], let writerGuids = jsonDict[SIMSGroup.WRITERS] as? [String] {
                    return writerGuids
                }
            } catch {
                DPAGLog(error)
            }
        }
        return []
    }

    @objc
    public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.GROUP
    }

    private static let ATTRIBUTE_NAME = "groupName"
    private static let ATTRIBUTE_AES_KEY = "groupAesKey"
    private static let ATTRIBUTE_IMAGE = "groupImage"
    private static let ATTRIBUTE_STATUS = "groupStatus"
    private static let ATTRIBUTE_READONLY = "readonly"
    private static let ATTRIBUTE_DELETED = "groupDeleted"
    private static let ATTRIBUTE_CONFIRMED = "groupConfirmed"

    var isConfirmed: Bool {
        get {
            (self.getAttribute(SIMSGroup.ATTRIBUTE_CONFIRMED) as? String == "true") || (self.stream?.isConfirmed?.boolValue ?? false)
        }
        set {
            self.setAttributeWithKey(SIMSGroup.ATTRIBUTE_CONFIRMED, andValue: newValue ? "true" : "false")
            self.stream?.isConfirmed = NSNumber(value: newValue)
        }
    }

    var wasDeleted: Bool {
        get {
            (self.getAttribute(SIMSGroup.ATTRIBUTE_DELETED) as? String == "true") || (self.stream?.wasDeleted?.boolValue ?? false)
        }
        set {
            self.setAttributeWithKey(SIMSGroup.ATTRIBUTE_DELETED, andValue: newValue ? "true" : "false")
            self.stream?.wasDeleted = NSNumber(value: newValue)
        }
    }

    var isReadonly: Bool {
        get {
            self.getAttribute(SIMSGroup.ATTRIBUTE_READONLY) as? String == "true"
        }
        set {
            self.setAttributeWithKey(SIMSGroup.ATTRIBUTE_READONLY, andValue: newValue ? "true" : "false")
        }
    }

    var aesKey: String? {
        get {
            self.getAttribute(SIMSGroup.ATTRIBUTE_AES_KEY) as? String
        }
        set {
            if let newValue = newValue {
                self.setAttributeWithKey(SIMSGroup.ATTRIBUTE_AES_KEY, andValue: newValue)
            }
        }
    }

    var groupName: String? {
        get {
            self.getAttribute(SIMSGroup.ATTRIBUTE_NAME) as? String
        }
        set {
            if let newValue = newValue {
                self.setAttributeWithKey(SIMSGroup.ATTRIBUTE_NAME, andValue: newValue)
            }
        }
    }

    var confidenceState: DPAGConfidenceState {
        get {
            switch self.typeGroup {
                case .restricted, .managed:
                    return .high
                default:
                    if let stateNum = self.getAttribute(SIMSGroup.ATTRIBUTE_STATUS) as? NSNumber {
                        return DPAGConfidenceState(rawValue: stateNum.uintValue) ?? .low
                    }
                    return .low
            }
        }
        set {
            var newValueCopy = newValue
            switch self.typeGroup {
                case .restricted, .managed:
                    newValueCopy = .high
                default:
                    break
            }
            let currentConfidenceState = (self.getAttribute(SIMSGroup.ATTRIBUTE_STATUS) as? NSNumber)?.uintValue ?? DPAGConfidenceState.low.rawValue
            if currentConfidenceState != newValueCopy.rawValue {
                self.setAttributeWithKey(SIMSGroup.ATTRIBUTE_STATUS, andValue: NSNumber(value: newValueCopy.rawValue))
                let currentState = self.confidenceState
                if let messages = self.stream?.messages {
                    for msgObj in messages {
                        if let msg = msgObj as? SIMSMessage, let msgGuid = msg.guid {
                            DPAGApplicationFacade.cache.decryptedMessageFast(messageGuid: msgGuid)?.confidenceState = currentState
                        }
                    }
                }
                let groupGuid = self.guid ?? "häh"
                NotificationCenter.default.post(name: DPAGStrings.Notification.Group.CONFIDENCE_UPDATED, object: nil, userInfo: [DPAGStrings.Notification.Group.CONFIDENCE_UPDATED__USERINFO_KEY__GROUP_GUID: groupGuid, DPAGStrings.Notification.Group.CONFIDENCE_UPDATED__USERINFO_KEY__NEW_STATE: NSNumber(value: currentState.rawValue)])
            }
        }
    }

    func memberNames() -> String {
        var memberNames = [String]()
        for member in self.members ?? Set() {
            if let accountGuid = member.accountGuid, let contact = DPAGApplicationFacade.cache.contact(for: accountGuid) {
                memberNames.append(contact.displayName)
            }
        }
        memberNames.sort()
        return memberNames.joined(separator: ", ")
    }

    func memberCount() -> Int {
        self.members?.count ?? 0
    }

    func removeMember(memberGuid: String, in localContext: NSManagedObjectContext) {
        let members = self.members ?? Set()
        for member in members where member.accountGuid == memberGuid {
            self.members?.remove(member)
            member.groups?.remove(self)
            if (member.groups?.count ?? 0) == 0 {
                member.mr_deleteEntity(in: localContext)
            }
            break
        }
    }

    func removeMembers(in localContext: NSManagedObjectContext) {
        let members = self.members ?? Set()
        for member in members {
            self.members?.remove(member)
            member.groups?.remove(self)
            if (member.groups?.count ?? 0) == 0 {
                member.mr_deleteEntity(in: localContext)
            }
        }
    }

    @discardableResult
    func updateMembers(memberGuids: [String], ownGuid: String, in localContext: NSManagedObjectContext) -> [String] {
        let members = self.members ?? Set()
        for member in members {
            if let accountGuid = member.accountGuid, memberGuids.contains(accountGuid) == false {
                self.members?.remove(member)
                member.groups?.remove(self)
                if (member.groups?.count ?? 0) == 0 {
                    member.mr_deleteEntity(in: localContext)
                }
            }
        }
        var unknownGuids: [String] = []
        memberGuids.forEach { memberGuid in
            if let member = SIMSGroupMember.mr_findFirst(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSGroupMember.accountGuid), rightExpression: NSExpression(forConstantValue: memberGuid)), in: localContext) ?? SIMSGroupMember.mr_createEntity(in: localContext) {
                member.accountGuid = memberGuid
                if memberGuid != ownGuid {
                    if SIMSContactIndexEntry.findFirst(byGuid: memberGuid, in: localContext) == nil {
                        unknownGuids.append(memberGuid)
                    }
                }
                member.groups?.insert(self)
            }
        }
        return unknownGuids
    }

    func updateAdmins(adminGuids: [String]) {
        self.jsonData = [SIMSGroup.ADMINS: adminGuids, SIMSGroup.WRITERS: self.writerGuids].JSONString
    }

    func updateWriters(writerGuids: [String]) {
        self.jsonData = [SIMSGroup.ADMINS: self.adminGuids, SIMSGroup.WRITERS: writerGuids].JSONString
    }

    func addAdmin(_ guid: String) {
        var newAdmins = self.adminGuids
        newAdmins.append(guid)
        self.updateAdmins(adminGuids: newAdmins)
    }

    func removeAdmin(_ guid: String) {
        var newAdmins = self.adminGuids
        if let idx = newAdmins.firstIndex(of: guid) {
            newAdmins.remove(at: idx)
            self.updateAdmins(adminGuids: newAdmins)
        }
    }

    func update(withData data: String, keyIV: String?) {
        guard let decAesKey = self.getAttribute(SIMSGroup.ATTRIBUTE_AES_KEY) as? String else { return }
        do {
            guard let decAesKeyDict = try XMLReader.dictionary(forXMLString: decAesKey), let aesKey = decAesKeyDict["key"] as? String, let iv = decAesKeyDict["iv"] as? String else { return }
            let jsonData = try CryptoHelperDecrypter.decrypt(encryptedString: data, withAesKeyDict: ["key": aesKey, "iv": keyIV ?? iv])
            if let jsonDict = try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any] {
                if let name = jsonDict[DPAGStrings.JSON.Group.GROUP_NAME] as? String {
                    self.groupName = name
                }
                DPAGLog("Received SIMGSGroup::update(withData: \(jsonDict) ... )")
                if let roomtype = jsonDict["roomtype"] as? String {
                    DPAGLog(".... containing ROOM TYPE = \(roomtype)")
                    self.typeName = roomtype
                }
                if let encodedImage = jsonDict[DPAGStrings.JSON.Group.GROUP_IMAGE] as? String, let guid = self.guid {
                    DPAGHelperEx.saveBase64Image(encodedImage: encodedImage, forGroupGuid: guid)
                }
            }
        } catch {
            DPAGLog(error)
        }
    }

    var typeName: String {
        get {
            switch self.typeGroup {
                case .default:
                    return "ChatRoom"
                case .restricted:
                    return "RestrictedRoom"
                case .managed:
                    return "ManagedRoom"
                case .announcement:
                    return "AnnouncementRoom"
            }
        }
        set {
            if newValue == "RestrictedRoom" {
                self.type = NSNumber(value: DPAGGroupType.restricted.rawValue)
            } else if newValue == "ManagedRoom" {
                self.type = NSNumber(value: DPAGGroupType.managed.rawValue)
            } else if newValue == "AnnouncementRoom" {
                self.type = NSNumber(value: DPAGGroupType.announcement.rawValue)
            } else {
                self.type = NSNumber(value: DPAGGroupType.default.rawValue)
            }
        }
    }

    var typeGroup: DPAGGroupType {
        DPAGGroupType(rawValue: self.type?.intValue ?? DPAGGroupType.default.rawValue) ?? DPAGGroupType.default
    }

    func updateStatus(in localContext: NSManagedObjectContext) {
        var confidenceStatus: DPAGConfidenceState = .high
        let ownGuid = DPAGApplicationFacade.cache.account?.guid
        let members = self.members ?? Set()
        if members.count != 0 {
            for member in members {
                var newStatus: DPAGConfidenceState = .low
                if member.accountGuid == ownGuid {
                    newStatus = .high
                } else if let accountGuid = member.accountGuid, let contact = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) {
                    newStatus = contact.confidenceState
                }
                confidenceStatus = newStatus.rawValue < confidenceStatus.rawValue ? newStatus : confidenceStatus
                if confidenceStatus.rawValue <= DPAGConfidenceState.low.rawValue {
                    break
                }
            }
        } else {
            confidenceStatus = .low
        }
        if self.confidenceState != confidenceStatus {
            self.confidenceState = confidenceStatus
        }
        switch self.typeGroup {
            case .restricted, .managed:
                if let ownerGuid = self.ownerGuid, let ownerContact = SIMSContactIndexEntry.findFirst(byGuid: ownerGuid, in: localContext), ownerContact.confidenceState != .high {
                    ownerContact.confidenceState = .high
                }
            default:
                break
        }
    }
}
