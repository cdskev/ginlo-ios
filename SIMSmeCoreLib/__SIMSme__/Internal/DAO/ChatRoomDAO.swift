//
//  ChatRoomDAO.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 05.08.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

struct ChatRoomDAOUpdateGroupResult {
    let unknownGuids: [String]
    let doNotify: Bool
}

protocol ChatRoomDAOProtocol {
    func isEditingEnabled(groupGuid: String) -> Bool
    func setGroupRemotelyDeleted(groupGuid: String)
    func getJsonStringForAddMembers(_ memberGuids: Set<String>, groupGuid: String, groupName: String, groupAesKey: String, isNewGroup: Bool, groupType: String?) throws -> String
    func createGroupStream(config: DPAGChatRoomCreationConfig, aesKey decAesKey: String, _ type: String)
    func aesKey(forGroupGuid groupGuid: String) -> String?
    func updateGroupAndReturnUnknownContactGuids(config: DPAGChatRoomUpdateConfig, responseDict dict: [String: Any]) -> [String]
    func updateGroup(groupGuid: String, responseDict dict: [AnyHashable: Any]) -> ChatRoomDAOUpdateGroupResult
    func removeRoom(roomGuid: String) throws
    func updateGroup(groupGuid: String, ownGuid: String, apiGroup: API.Response.Group, unknownGuids: inout [String])
}

class ChatRoomDAO: ChatRoomDAOProtocol {
    private let queueDBAccess: DispatchQueue = DispatchQueue(label: "de.dpag.simsme.ChatRoomDAO.queue", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)

    func isEditingEnabled(groupGuid: String) -> Bool {
        var enabled = true
        self.queueDBAccess.sync(flags: .barrier) {
            DPAGApplicationFacade.persistance.loadWithBlock { localContext in
                if let stream = SIMSMessageStream.findFirst(byGuid: groupGuid, in: localContext) as? SIMSGroupStream {
                    enabled = enabled && (stream.streamState == .write)
                }
            }
        }
        return enabled
    }

    func setGroupRemotelyDeleted(groupGuid: String) {
        self.queueDBAccess.sync(flags: .barrier) {
            DPAGApplicationFacade.persistance.saveWithBlock { localContext in
                if let group = SIMSGroup.findFirst(byGuid: groupGuid, in: localContext) {
                    if group.wasDeleted == false {
                        group.wasDeleted = true
                    }
                }
            }
        }
    }

    func getJsonStringForAddMembers(_ memberGuids: Set<String>, groupGuid: String, groupName: String, groupAesKey: String, isNewGroup: Bool, groupType: String? = "ChatRoom") throws -> String {
        var addMembersJSON: String?
        try self.queueDBAccess.sync(flags: .barrier) {
            try DPAGApplicationFacade.persistance.loadWithError { localContext in
                let recipients = memberGuids.compactMap { (memberGuid) -> SIMSContactIndexEntry? in
                    SIMSContactIndexEntry.findFirst(byGuid: memberGuid, in: localContext)
                }
                let invGroupType: String
                if let groupType = groupType {
                    invGroupType = groupType
                } else {
                    invGroupType = "ChatRoom"
                }
                if let messages = try DPAGApplicationFacade.messageFactory.invitationForGroup(groupGuid: groupGuid, groupName: groupName, groupAesKey: groupAesKey, forRecipients: recipients, isNewGroup: isNewGroup, groupType: invGroupType, in: localContext) {
                    addMembersJSON = messages.JSONString
                }
            }
        }
        return addMembersJSON ?? ""
    }

    func createGroupStream(config: DPAGChatRoomCreationConfig, aesKey decAesKey: String, _ type: String = "ChatRoom") {
        self.queueDBAccess.sync(flags: .barrier) {
            DPAGApplicationFacade.persistance.saveWithBlock { localContext in
                guard let groupStream = self.createGroupStream(config.groupName, ownerGuid: config.ownerGuid, groupGuid: config.groupGuid, decAesKey: decAesKey, in: localContext), let group = groupStream.group, let ownGuid = DPAGApplicationFacade.cache.account?.guid else { return }
                var newMemberGuids = config.memberGuids
                newMemberGuids.insert(config.ownerGuid)
                _ = group.updateMembers(memberGuids: Array(newMemberGuids), ownGuid: ownGuid, in: localContext)
                var newAdminGuids = config.adminGuids
                newAdminGuids.insert(config.ownerGuid)
                group.typeName = type
                group.updateAdmins(adminGuids: Array(newAdminGuids))
                group.updateStatus(in: localContext)
                // DPAGApplicationFacade.cache.updateDecryptedStreamWithGuid(groupGuid, stream: groupStream, in: localContext)
            }
        }
    }

    private func createGroupStream(_ groupName: String, ownerGuid: String, groupGuid: String, decAesKey: String, in localContext: NSManagedObjectContext) -> SIMSGroupStream? {
        guard let stream = SIMSMessageStream.findFirst(byGuid: groupGuid, in: localContext) as? SIMSGroupStream ?? SIMSGroupStream.mr_createEntity(in: localContext) else { return nil }
        stream.guid = groupGuid
        stream.typeStream = .group
        stream.optionsStream = DPAGApplicationFacade.preferences.streamVisibilityGroup ? [] : [.filtered]
        guard let group = SIMSGroup.findFirst(byGuid: groupGuid, in: localContext) ?? SIMSGroup.mr_createEntity(in: localContext) else {
            stream.mr_deleteEntity(in: localContext)
            return nil
        }
        group.guid = groupGuid
        stream.group = group
        stream.group?.isConfirmed = true
        group.aesKey = decAesKey
        group.groupName = groupName
        group.ownerGuid = ownerGuid
        group.invitedAt = Date()
        stream.lastMessageDate = group.invitedAt
        let key = SIMSKey.mr_findFirst(in: localContext)
        group.keyRelationship = key
        group.members?.removeAll()
        if let member = SIMSGroupMember.mr_findFirst(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSGroupMember.accountGuid), rightExpression: NSExpression(forConstantValue: ownerGuid)), in: localContext) ?? SIMSGroupMember.mr_createEntity(in: localContext) {
            member.accountGuid = ownerGuid
            group.members?.insert(member)
        }
        return stream
    }

    func aesKey(forGroupGuid groupGuid: String) -> String? {
        var aesKeyGroup: String?
        self.queueDBAccess.sync(flags: .barrier) {
            DPAGApplicationFacade.persistance.loadWithBlock { localContext in
                if let group = SIMSGroup.findFirst(byGuid: groupGuid, in: localContext), let decAesKey = group.aesKey {
                    aesKeyGroup = decAesKey
                }
            }
        }
        return aesKeyGroup
    }

    func updateGroupAndReturnUnknownContactGuids(config: DPAGChatRoomUpdateConfig, responseDict dict: [String: Any]) -> [String] {
        var unknownGuids: [String] = []
        self.queueDBAccess.sync(flags: .barrier) {
            DPAGApplicationFacade.persistance.saveWithBlock { localContext in
                guard let group = SIMSGroup.findFirst(byGuid: config.groupGuid, in: localContext), let ownGuid = DPAGApplicationFacade.cache.account?.guid else { return }
                group.groupName = config.groupName
                if let data = dict[DPAGStrings.Server.Group.Response.DATA] as? String {
                    group.update(withData: data, keyIV: dict[DPAGStrings.Server.Group.Response.KEY_IV] as? String)
                }
                if let ownerGuid = dict[DPAGStrings.Server.Group.Response.OWNER] as? String {
                    group.ownerGuid = ownerGuid
                }
                if let currentMemberGuids = dict[DPAGStrings.Server.Group.Response.MEMBER] as? [String] {
                    unknownGuids += group.updateMembers(memberGuids: currentMemberGuids, ownGuid: ownGuid, in: localContext)
                }
                if let adminGuids = dict[DPAGStrings.Server.Group.Response.ADMINS] as? [String] {
                    group.updateAdmins(adminGuids: adminGuids)
                }
                if let writerGuids = dict[DPAGStrings.Server.Group.Response.WRITERS] as? [String] {
                    group.updateWriters(writerGuids: writerGuids)
                }
                group.updateStatus(in: localContext)
                DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: config.groupGuid, stream: group.stream, in: localContext)
            }
        }

        return unknownGuids
    }

    func updateGroup(groupGuid: String, responseDict dict: [AnyHashable: Any]) -> ChatRoomDAOUpdateGroupResult {
        var unknownGuids: [String] = []
        var doNotify = false
        self.queueDBAccess.sync(flags: .barrier) {
            DPAGApplicationFacade.persistance.saveWithBlock { localContext in
                guard let group = SIMSGroup.findFirst(byGuid: groupGuid, in: localContext), let ownGuid = DPAGApplicationFacade.cache.account?.guid else { return }
                if let data = dict[DPAGStrings.Server.Group.Response.DATA] as? String {
                    group.update(withData: data, keyIV: dict[DPAGStrings.Server.Group.Response.KEY_IV] as? String)
                }
                if let ownerGuid = dict[DPAGStrings.Server.Group.Response.OWNER] as? String {
                    group.ownerGuid = ownerGuid
                }
                if let memberGuids = dict[DPAGStrings.Server.Group.Response.MEMBER] as? [String] {
                    unknownGuids += group.updateMembers(memberGuids: memberGuids, ownGuid: ownGuid, in: localContext)
                }
                if let adminGuids = dict[DPAGStrings.Server.Group.Response.ADMINS] as? [String] {
                    group.updateAdmins(adminGuids: adminGuids)
                }
                if let writerGuids = dict[DPAGStrings.Server.Group.Response.WRITERS] as? [String] {
                    group.updateWriters(writerGuids: writerGuids)
                }
                let groupStreamOptionsValue = (group.stream?.optionsStream ?? [])
                if let readOnly = dict[DPAGStrings.Server.Group.Response.READONLY] as? String {
                    if readOnly == "1" {
                        if groupStreamOptionsValue.contains(.isReadOnly) == false {
                            group.stream?.optionsStream = groupStreamOptionsValue.union(.isReadOnly)
                            doNotify = true
                        }
                    } else if groupStreamOptionsValue.contains(.isReadOnly) {
                        group.stream?.optionsStream = groupStreamOptionsValue.subtracting(.isReadOnly)
                        doNotify = true
                    }
                } else if groupStreamOptionsValue.contains(.isReadOnly) {
                    group.stream?.optionsStream = groupStreamOptionsValue.subtracting(.isReadOnly)
                    doNotify = true
                }
                group.updateStatus(in: localContext)
                DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: groupGuid, stream: group.stream, in: localContext)
            }
        }
        return ChatRoomDAOUpdateGroupResult(unknownGuids: unknownGuids, doNotify: doNotify)
    }

    func removeRoom(roomGuid: String) throws {
        try self.queueDBAccess.sync(flags: .barrier) {
            try DPAGApplicationFacade.persistance.saveWithError { localContext in
                if let group = SIMSGroup.findFirst(byGuid: roomGuid, in: localContext) {
                    group.removeMembers(in: localContext)
                    let groupStream = group.stream
                    if let messages = groupStream?.messages?.array {
                        messages.forEach { obj in
                            if let msg = obj as? SIMSMessage {
                                DPAGApplicationFacade.persistance.deleteMessage(msg, in: localContext)
                            }
                        }
                    }
                    group.mr_deleteEntity(in: localContext)
                    groupStream?.mr_deleteEntity(in: localContext)
                }
                let timedMessages = try SIMSMessageToSendGroup.findAll(in: localContext, with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageToSend.streamGuid), rightExpression: NSExpression(forConstantValue: roomGuid)))
                for timedMessage in timedMessages {
                    DPAGApplicationFacade.persistance.deleteMessage(timedMessage, in: localContext)
                }
                DPAGApplicationFacade.cache.removeStream(guid: roomGuid)
            }
        }
    }

    func updateGroup(groupGuid: String, ownGuid: String, apiGroup: API.Response.Group, unknownGuids: inout [String]) {
        var unknownUserIds: [String] = []
        self.queueDBAccess.sync(flags: .barrier) {
            DPAGApplicationFacade.persistance.saveWithBlock { localContext in
                guard let groupStream = SIMSMessageStream.findFirst(byGuid: groupGuid, in: localContext) as? SIMSGroupStream, let group = groupStream.group else { return }
                if let data = apiGroup.data {
                    group.update(withData: data, keyIV: apiGroup.keyIv)
                }
                if let ownerGuid = apiGroup.ownerId {
                    group.ownerGuid = ownerGuid
                }
                if let memberGuids = apiGroup.memberIds {
                    unknownUserIds += group.updateMembers(memberGuids: memberGuids, ownGuid: ownGuid, in: localContext)
                }
                if let adminGuids = apiGroup.adminIds {
                    group.updateAdmins(adminGuids: adminGuids)
                }
                if let writerGuids = apiGroup.writerIds {
                    group.updateWriters(writerGuids: writerGuids)
                }
                group.updateStatus(in: localContext)
                group.isConfirmed = true
                group.wasDeleted = false
                DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: groupGuid, stream: groupStream, in: localContext)
            }
        }
        unknownGuids += unknownUserIds
    }
}
