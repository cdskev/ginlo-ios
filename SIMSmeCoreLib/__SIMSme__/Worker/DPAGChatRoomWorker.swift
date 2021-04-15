//
//  DPAGChatRoomWorker.swift
//  SIMSme
//
//  Created by RBU on 25/01/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

public struct DPAGChatRoomCreationConfig {
    let groupGuid: String
    let groupName: String
    let groupImage: UIImage?
    let memberGuids: Set<String>
    let adminGuids: Set<String>
    let ownerGuid: String

    public init(groupGuid: String, groupName: String, groupImage: UIImage?, memberGuids: Set<String>, adminGuids: Set<String>, ownerGuid: String) {
        self.groupGuid = groupGuid
        self.groupName = groupName
        self.groupImage = groupImage
        self.memberGuids = memberGuids
        self.adminGuids = adminGuids
        self.ownerGuid = ownerGuid
    }
}

public struct DPAGChatRoomUpdateConfig {
    let groupGuid: String
    let groupName: String
    let groupImage: UIImage?
    let newMembers: Set<String>
    let removedMembers: Set<String>
    let newAdmins: Set<String>
    let removedAdmins: Set<String>
    let updateGroupData: Bool
    let groupType: String

    public init(groupGuid: String, groupName: String, groupImage: UIImage?, newMembers: Set<String>, removedMembers: Set<String>, newAdmins: Set<String>, removedAdmins: Set<String>, updateGroupData: Bool, type: DPAGGroupType) {
        self.groupGuid = groupGuid
        self.groupName = groupName
        self.groupImage = groupImage
        self.newMembers = newMembers
        self.removedMembers = removedMembers
        self.newAdmins = newAdmins
        self.removedAdmins = removedAdmins
        self.updateGroupData = updateGroupData
        switch type {
            case .default:
                self.groupType = "ChatRoom"
            case .restricted:
                self.groupType = "RestrictedRoom"
            case .managed:
                self.groupType = "ManagedRoom"
            case .announcement:
                self.groupType = "AnnouncementRoom"
        }
    }
}

public protocol DPAGChatRoomWorkerProtocol: AnyObject {
    func createGroup(config: DPAGChatRoomCreationConfig, responseBlock: @escaping DPAGServiceResponseBlock) throws
    func createAnnouncementGroup(config: DPAGChatRoomCreationConfig, responseBlock: @escaping DPAGServiceResponseBlock) throws
    func updateGroup(config: DPAGChatRoomUpdateConfig, responseBlock: @escaping DPAGServiceResponseBlock) throws
    func acceptInvitationForRoom(_ groupGuid: String, responseBlock: @escaping DPAGServiceResponseBlock)
    func declineInvitationForRoom(_ roomGuid: String, responseBlock: @escaping DPAGServiceResponseBlock)

    func removeSelfFromGroup(_ groupGuid: String, responseBlock: @escaping DPAGServiceResponseBlock)
    func removeRoom(_ groupGuid: String, responseBlock: @escaping DPAGServiceResponseBlock)

    func removeRoom(_ streamGuid: String)

    func checkGroupSynchronization(forGroup groupGuid: String, force: Bool, notify: Bool)
    func setGroupRemotelyDeleted(groupGuid: String)
    func isEditingEnabled(groupGuid: String) -> Bool

    func readGroupSilentTill(groupGuid: String, responseBlock: @escaping DPAGServiceResponseBlock)
}

class DPAGChatRoomWorker: DPAGChatRoomWorkerProtocol {
    let chatRoomDAO: ChatRoomDAOProtocol = ChatRoomDAO()
    var nickNameProvider: NickNameProviderProtocol = NickNameProvider()
    var groupService: GroupServiceProtocol = GroupService()

    func readGroupSilentTill(groupGuid: String, responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.getRoom(roomGuid: groupGuid) { responseObject, errorCode, errorMessage in
            var silentTill: Date?
            if errorMessage == nil, let chatRoomDict = responseObject as? [AnyHashable: Any],
               let dict = (chatRoomDict[DPAGStrings.Server.Group.Response.OBJECT_KEY] ??
                            chatRoomDict[DPAGStrings.Server.Group.Response.OBJECT_KEY_MANAGED] ??
                            chatRoomDict[DPAGStrings.Server.Group.Response.OBJECT_KEY_RESTRICTED] ??
                            chatRoomDict[DPAGStrings.Server.Group.Response.OBJECT_KEY_ANNOUNCEMENT]) as? [AnyHashable: Any] {
                if let silentTillString = dict[DPAGStrings.Server.Group.Response.PUSH_SILENT_TILL] as? String {
                    silentTill = DPAGFormatter.dateServer.date(from: silentTillString)
                } else {
                    silentTill = nil
                }
            }
            responseBlock(silentTill, errorCode, errorMessage)
        }
    }

    func isEditingEnabled(groupGuid: String) -> Bool {
        self.chatRoomDAO.isEditingEnabled(groupGuid: groupGuid)
    }

    func setGroupRemotelyDeleted(groupGuid: String) {
        self.chatRoomDAO.setGroupRemotelyDeleted(groupGuid: groupGuid)
    }

    private func createGroup(ofType groupType: String, andConfig config: DPAGChatRoomCreationConfig, responseBlock: @escaping DPAGServiceResponseBlock) throws {
        var groupStructureDict: [String: Any] = [:]
        groupStructureDict[DPAGStrings.JSON.Group.GROUP_NAME] = config.groupName as AnyObject?
        groupStructureDict[DPAGStrings.JSON.Group.ROOM_TYPE] = groupType
        groupStructureDict[DPAGStrings.JSON.Group.GROUP_TYPE] = groupType
        let encodedImage = config.groupImage?.groupImageDataEncoded()
        if let encodedImage = encodedImage {
            groupStructureDict[DPAGStrings.JSON.Group.GROUP_IMAGE] = encodedImage
        }
        guard let groupStructureJson = groupStructureDict.JSONString else {
            responseBlock(nil, nil, nil)
            return
        }
        let decAesKey = try CryptoHelperEncrypter.getNewAesKey()
        guard let decAesKeyDict = try XMLReader.dictionary(forXMLString: decAesKey), decAesKeyDict["key"] as? String != nil, let keyIV = decAesKeyDict["iv"] as? String else {
            responseBlock(nil, nil, nil)
            return
        }
        let encJson = try CryptoHelperEncrypter.encrypt(string: groupStructureJson, withAesKey: decAesKey)
        let groupDict = [
            groupType: [
                DPAGStrings.Server.Group.Request.GUID: config.groupGuid,
                DPAGStrings.Server.Group.Request.ROOM_TYPE: groupType,
                DPAGStrings.Server.Group.Request.GROUP_TYPE: groupType,
                DPAGStrings.Server.Group.Request.OWNER: config.ownerGuid,
                DPAGStrings.Server.Group.Request.DATA: encJson,
                DPAGStrings.Server.Group.Request.KEY_IV: keyIV
            ]
        ]
        guard let groupJson = groupDict.JSONString else {
            responseBlock(nil, nil, nil)
            return
        }
        let addMembersJSON = try self.chatRoomDAO.getJsonStringForAddMembers(config.memberGuids, groupGuid: config.groupGuid, groupName: config.groupName, groupAesKey: decAesKey, isNewGroup: true, groupType: groupType)
        var nickNameEncoded: String?
        if DPAGApplicationFacade.preferences.sendNickname, let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let nickname = contact.nickName, let nickEncoded = nickname.data(using: .utf8)?.base64EncodedString(options: .lineLength76Characters) {
            nickNameEncoded = nickEncoded
        }
        try DPAGApplicationFacade.server.createGroup(withData: groupJson, addMembersJSON: addMembersJSON, adminJSON: config.adminGuids.joined(separator: ","), nickNameEncoded: nickNameEncoded, withResponse: { responseObject, errorCode, errorMessage in
            if errorMessage != nil {
                responseBlock(responseObject, errorCode, errorMessage)
            } else if let dict = (responseObject as? [String: Any])?[DPAGStrings.JSON.MessageInternal.ObjectKey.GROUP_INFO_RESULT] as? [String: Any] {
                if let encodedImage = encodedImage {
                    DPAGHelperEx.saveBase64Image(encodedImage: encodedImage, forGroupGuid: config.groupGuid)
                }
                self.chatRoomDAO.createGroupStream(config: config, aesKey: decAesKey, groupType)
                // DPAGApplicationFacade.preferences.setGroupSynchronizationDone(forGroupGuid: groupGuid)
                if let encodedImage = encodedImage, let notSend = dict[DPAGStrings.JSON.MessageInternal.GroupInfoResult.NOT_SEND_GUIDS_ARRAY] as? [String] {
                    if notSend.count > 0 {
                        DPAGSendInternalMessageWorker.broadcastGroupImage(encodedImage, groupGuid: config.groupGuid, toGroupMember: notSend)
                    }
                }
                responseBlock(responseObject, errorCode, errorMessage)
            }
        })
    }
    
    func createGroup(config: DPAGChatRoomCreationConfig, responseBlock: @escaping DPAGServiceResponseBlock) throws {
        do {
            try createGroup(ofType: DPAGStrings.Server.Group.Request.OBJECT_KEY, andConfig: config, responseBlock: responseBlock)
        } catch {
            throw(error)
        }
    }

    func createAnnouncementGroup(config: DPAGChatRoomCreationConfig, responseBlock: @escaping DPAGServiceResponseBlock) throws {
        do {
            try createGroup(ofType: DPAGStrings.Server.Group.Request.OBJECT_KEY_ANNOUNCEMENT, andConfig: config, responseBlock: responseBlock)
        } catch  {
            throw(error)
        }
    }

    func updateGroup(config: DPAGChatRoomUpdateConfig, responseBlock: @escaping DPAGServiceResponseBlock) throws {
        let aesKeyGroup = self.chatRoomDAO.aesKey(forGroupGuid: config.groupGuid)
        guard let decAesKey = aesKeyGroup else { return }
        let encodedImage = config.groupImage?.groupImageDataEncoded()
        var keyIV: String?
        var encJson: String?
        var groupStructureDict: [String: Any] = [:]
        // We need to send the group type always otherwise the receiving clients might detect
        // this as defeault group type
        groupStructureDict[DPAGStrings.JSON.Group.ROOM_TYPE] = config.groupType
        groupStructureDict[DPAGStrings.JSON.Group.GROUP_TYPE] = config.groupType
        if config.updateGroupData {
            groupStructureDict[DPAGStrings.JSON.Group.GROUP_NAME] = config.groupName
            if let encodedImage = encodedImage {
                groupStructureDict[DPAGStrings.JSON.Group.GROUP_IMAGE] = encodedImage
            }
        }
        guard let groupStructureJson = groupStructureDict.JSONString else { return }
        let decAesKeyDict: [AnyHashable: Any]?
        do {
            decAesKeyDict = try XMLReader.dictionary(forXMLString: decAesKey)
        } catch {
            return
        }
        guard let aesKey = decAesKeyDict?["key"] as? String else { return }
        let ivData = DPAGHelperEx.iv128Bit()
        let iv = ivData.base64EncodedString()
        encJson = try CryptoHelperEncrypter.encrypt(string: groupStructureJson, withAesKeyDict: ["key": aesKey, "iv": iv])
        keyIV = iv
        let addMembersJSON = try self.chatRoomDAO.getJsonStringForAddMembers(config.newMembers, groupGuid: config.groupGuid, groupName: config.groupName, groupAesKey: decAesKey, isNewGroup: false, groupType: config.groupType)
        var nickNameEncoded: String?
        if DPAGApplicationFacade.preferences.sendNickname, let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let nickname = contact.nickName, let nickEncoded = nickname.data(using: .utf8)?.base64EncodedString(options: .lineLength76Characters) {
            nickNameEncoded = nickEncoded
        }
        DPAGApplicationFacade.server.updateGroup(groupGuid: config.groupGuid, data: encJson, keyIV: keyIV, newMembersJSON: addMembersJSON, removedMembers: Array(config.removedMembers), newAdmins: Array(config.newAdmins), removedAdmins: Array(config.removedAdmins), nickNameEncoded: nickNameEncoded) { responseObject, errorCode, errorMessage in
            if let errorMessage = errorMessage {
                let isGroupRemovedOrMembershipCanceled = self.isGroupChatDeletedErrorMessage(errorMessage) || self.isNoMemberOfChatErrorMessage(errorMessage)
                if isGroupRemovedOrMembershipCanceled {
                    DPAGApplicationFacade.chatRoomWorker.removeRoom(config.groupGuid)
                }
                responseBlock(responseObject, errorCode, errorMessage)
            } else if let chatRoomDict = responseObject as? [String: Any],
                      let dict = (chatRoomDict[DPAGStrings.Server.Group.Response.OBJECT_KEY] ??
                                    chatRoomDict[DPAGStrings.Server.Group.Response.OBJECT_KEY_MANAGED] ??
                                    chatRoomDict[DPAGStrings.Server.Group.Response.OBJECT_KEY_ANNOUNCEMENT]) as? [String: Any] {
                if let encodedImage = encodedImage {
                    DPAGHelperEx.saveBase64Image(encodedImage: encodedImage, forGroupGuid: config.groupGuid)
                }
                let unknownGuids = self.chatRoomDAO.updateGroupAndReturnUnknownContactGuids(config: config, responseDict: dict)
                let notSendGroupData = (chatRoomDict[DPAGStrings.JSON.MessageInternal.ObjectKey.GROUP_INFO_RESULT] as? [String: Any])?[DPAGStrings.JSON.MessageInternal.GroupInfoResult.NOT_SEND_GUIDS_ARRAY] as? [String]
                let notSendAddMembers = (chatRoomDict[DPAGStrings.JSON.MessageInternal.ObjectKey.GROUP_ADD_MEMBERS_RESULT] as? [String: Any])?[DPAGStrings.JSON.MessageInternal.GroupAddMembersResult.NOT_SEND_GUIDS_ARRAY] as? [String]
                let notSendRemoveMembers = (chatRoomDict[DPAGStrings.JSON.MessageInternal.ObjectKey.GROUP_REMOVE_MEMBERS_RESULT] as? [String: Any])?[DPAGStrings.JSON.MessageInternal.GroupRemoveMembersResult.NOT_SEND_GUIDS_ARRAY] as? [String]
                let block = {
                    if let notSendGroupData = notSendGroupData, config.updateGroupData, notSendGroupData.count > 0 {
                        DPAGSendInternalMessageWorker.broadcastGroupName(config.groupName, groupGuid: config.groupGuid, toGroupMember: notSendGroupData)
                        if let encodedImage = encodedImage {
                            DPAGSendInternalMessageWorker.broadcastGroupImage(encodedImage, groupGuid: config.groupGuid, toGroupMember: notSendGroupData)
                        }
                    }
                    if let notSendAddMembers = notSendAddMembers, notSendAddMembers.count > 0, let encodedImage = encodedImage {
                        DPAGSendInternalMessageWorker.broadcastGroupImage(encodedImage, groupGuid: config.groupGuid, toGroupMember: notSendAddMembers)
                    }
                    if let notSendRemoveMembers = notSendRemoveMembers, notSendRemoveMembers.count > 0 {
                        DPAGSendInternalMessageWorker.broadcastRemovedGroupMembers(Array(config.removedMembers), forGroup: config.groupGuid, tos: notSendRemoveMembers)
                    }
                    responseBlock(responseObject, errorCode, errorMessage)
                }
                DPAGApplicationFacade.preferences.setGroupSynchronizationDone(forGroupGuid: config.groupGuid)
                if unknownGuids.count > 0 {
                    DPAGApplicationFacade.updateKnownContactsWorker.synchronize(accountGuids: unknownGuids, response: { _, _, _ in
                        block()
                    })
                } else {
                    block()
                }
            } else {
                responseBlock(responseObject, errorCode, errorMessage)
            }
        }
    }

    func acceptInvitationForRoom(_ groupGuid: String, responseBlock: @escaping DPAGServiceResponseBlock) {
        let nickNameEncoded = self.nickNameProvider.getEncodedSendNickName()
        self.groupService.acceptInvitationToRoom(groupId: groupGuid, nickNameEncoded: nickNameEncoded) { [weak self] result in
            switch result {
            case let .success(response):
                self?.handleAcceptGroupInvitationSuccess(response: response, groupGuid: groupGuid, responseBlock: responseBlock)
            case let .failure(error):
                let publicInfo = error.getPublicInfo()
                responseBlock(nil, publicInfo.errorMessage, publicInfo.errorCode)
            }
        }
    }

    func declineInvitationForRoom(_ roomGuid: String, responseBlock: @escaping DPAGServiceResponseBlock) {
        var nickNameEncoded: String?
        if DPAGApplicationFacade.preferences.sendNickname, let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let nickname = contact.nickName, let nickEncoded = nickname.data(using: .utf8)?.base64EncodedString(options: .lineLength76Characters) {
            nickNameEncoded = nickEncoded
        }
        DPAGApplicationFacade.server.declineInvitationForRoom(roomGuid: roomGuid, nickNameEncoded: nickNameEncoded) { responseObject, errorCode, errorMessage in
            if let errorMessage = errorMessage {
                let isGroupRemovedOrMembershipCanceled = self.isGroupChatDeletedErrorMessage(errorMessage) || self.isNoMemberOfChatErrorMessage(errorMessage)
                if isGroupRemovedOrMembershipCanceled {
                    DPAGApplicationFacade.chatRoomWorker.removeRoom(roomGuid)
                    responseBlock(responseObject, nil, nil)
                } else {
                    responseBlock(responseObject, errorCode, errorMessage)
                }
            } else if let dict = (responseObject as? [String: Any])?[DPAGStrings.JSON.MessageInternal.ObjectKey.GROUP_REMOVE_MEMBERS_RESULT] as? [String: Any] {
                if let notSend = dict[DPAGStrings.JSON.MessageInternal.GroupRemoveMembersResult.NOT_SEND_GUIDS_ARRAY] as? [String] {
                    if notSend.count > 0 {
                        if let ownGuid = DPAGApplicationFacade.cache.account?.guid {
                            DPAGSendInternalMessageWorker.broadcastRemovedGroupMembers([ownGuid], forGroup: roomGuid, tos: notSend)
                        }
                    }
                }
                DPAGApplicationFacade.chatRoomWorker.removeRoom(roomGuid)
                responseBlock(responseObject, errorCode, errorMessage)
            } else {
                responseBlock(nil, nil, "service.tryAgainLater")
            }
        }
    }

    func isGroupChatDeletedErrorMessage(_ errorMessage: String) -> Bool {
        DPAGStrings.ErrorCode.GROUP_DELETED == errorMessage
    }

    func isNoMemberOfChatErrorMessage(_ errorMessage: String) -> Bool {
        DPAGStrings.ErrorCode.NO_MEMBER_OF_CHAT_ROOM == errorMessage
    }

    func forceDeleteGroupLocally(_ errorMessage: String) -> Bool {
        (errorMessage == DPAGStrings.ErrorCode.NO_MEMBER_OF_CHAT_ROOM || errorMessage == DPAGStrings.ErrorCode.GUID_UNKNOWN || errorMessage == DPAGStrings.ErrorCode.GROUP_DELETED)
    }

    func removeSelfFromGroup(_ groupGuid: String, responseBlock: @escaping DPAGServiceResponseBlock) {
        var guidAccount: String?
        var nickNameEncoded: String?
        if let accountGuid = DPAGApplicationFacade.cache.account?.guid {
            guidAccount = accountGuid
        }
        if DPAGApplicationFacade.preferences.sendNickname, let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let nickname = contact.nickName, let nickEncoded = nickname.data(using: .utf8)?.base64EncodedString(options: .lineLength76Characters) {
            nickNameEncoded = nickEncoded
        }
        guard let accountGuid = guidAccount else {
            responseBlock(nil, nil, nil)
            return
        }
        DPAGApplicationFacade.server.removeMember(accountGuid: accountGuid, fromRoom: groupGuid, nickNameEncoded: nickNameEncoded) { responseObject, errorCode, errorMessage in
            if let errorMessage = errorMessage {
                if self.forceDeleteGroupLocally(errorMessage) == false {
                    responseBlock(responseObject, errorCode, errorMessage)
                } else {
                    DPAGApplicationFacade.chatRoomWorker.removeRoom(groupGuid)
                    responseBlock([accountGuid], nil, nil)
                }
            } else if let dict = (responseObject as? [String: Any])?[DPAGStrings.JSON.MessageInternal.ObjectKey.GROUP_REMOVE_MEMBERS_RESULT] as? [String: Any] {
                if let notSend = dict[DPAGStrings.JSON.MessageInternal.GroupRemoveMembersResult.NOT_SEND_GUIDS_ARRAY] as? [String] {
                    if notSend.count > 0 {
                        DPAGSendInternalMessageWorker.broadcastRemovedGroupMembers([accountGuid], forGroup: groupGuid, tos: notSend)
                    }
                }
                self.removeRoom(groupGuid)
                responseBlock([accountGuid], nil, nil)
            } else {
                responseBlock(nil, nil, "service.tryAgainLater")
            }
        }
    }

    func removeRoom(_ groupGuid: String, responseBlock: @escaping DPAGServiceResponseBlock) {
        var nickNameEncoded: String?
        if DPAGApplicationFacade.preferences.sendNickname, let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let nickname = contact.nickName, let nickEncoded = nickname.data(using: .utf8)?.base64EncodedString(options: .lineLength76Characters) {
            nickNameEncoded = nickEncoded
        }
        DPAGApplicationFacade.server.removeRoom(roomGuid: groupGuid, nickNameEncoded: nickNameEncoded) { responseObject, errorCode, errorMessage in
            if errorMessage == nil || DPAGStrings.ErrorCode.GROUP_DELETED == errorMessage {
                self.removeRoom(groupGuid)
                responseBlock(responseObject, nil, nil)
            } else {
                responseBlock(responseObject, errorCode, errorMessage)
            }
        }
    }

    private func updateGroupWithResponse(dict: [AnyHashable: Any], groupGuid: String, notify: Bool) {
        let updateResult = self.chatRoomDAO.updateGroup(groupGuid: groupGuid, responseDict: dict)
        DPAGApplicationFacade.preferences.setGroupSynchronizationDone(forGroupGuid: groupGuid)
        let pushSilentTill = dict[DPAGStrings.Server.Group.Response.PUSH_SILENT_TILL] as? String ?? ""
        if updateResult.unknownGuids.count > 0 {
            DPAGApplicationFacade.updateKnownContactsWorker.synchronize(accountGuids: updateResult.unknownGuids) { _, _, errorMessage in
                if notify || updateResult.doNotify, errorMessage == nil {
                    NotificationCenter.default.post(name: DPAGStrings.Notification.ChatStream.NEEDS_UPDATE, object: self, userInfo: [DPAGStrings.Notification.ChatStream.NEEDS_UPDATE__USERINFO_KEY__STREAM_GUID: groupGuid, DPAGStrings.Notification.ChatStream.NEEDS_UPDATE__USERINFO_KEY__PUSH_SILENT_TILL: pushSilentTill])
                    NotificationCenter.default.post(name: DPAGStrings.Notification.ChatStream.NEEDS_UPDATE_META, object: self, userInfo: [DPAGStrings.Notification.ChatStream.NEEDS_UPDATE__USERINFO_KEY__STREAM_GUID: groupGuid])
                }
            }
        } else if notify || updateResult.doNotify {
            NotificationCenter.default.post(name: DPAGStrings.Notification.ChatStream.NEEDS_UPDATE, object: self, userInfo: [DPAGStrings.Notification.ChatStream.NEEDS_UPDATE__USERINFO_KEY__STREAM_GUID: groupGuid, DPAGStrings.Notification.ChatStream.NEEDS_UPDATE__USERINFO_KEY__PUSH_SILENT_TILL: pushSilentTill])
            NotificationCenter.default.post(name: DPAGStrings.Notification.ChatStream.NEEDS_UPDATE_META, object: self, userInfo: [DPAGStrings.Notification.ChatStream.NEEDS_UPDATE__USERINFO_KEY__STREAM_GUID: groupGuid])
        }
    }

    func checkGroupSynchronization(forGroup groupGuid: String, force: Bool, notify: Bool) {
        if force || DPAGApplicationFacade.preferences.needsGroupSynchronization(forGroupGuid: groupGuid) {
            DPAGApplicationFacade.server.getRoom(roomGuid: groupGuid) { responseObject, _, errorMessage in
                if errorMessage == nil, let chatRoomDict = responseObject as? [AnyHashable: Any],
                   let dict = (chatRoomDict[DPAGStrings.Server.Group.Response.OBJECT_KEY] ??
                                chatRoomDict[DPAGStrings.Server.Group.Response.OBJECT_KEY_MANAGED] ??
                                chatRoomDict[DPAGStrings.Server.Group.Response.OBJECT_KEY_RESTRICTED] ??
                                chatRoomDict[DPAGStrings.Server.Group.Response.OBJECT_KEY_ANNOUNCEMENT]) as? [AnyHashable: Any] {
                    self.updateGroupWithResponse(dict: dict, groupGuid: groupGuid, notify: notify)
                }
            }
        }
    }

    func removeRoom(_ streamGuid: String) {
        do {
            try self.chatRoomDAO.removeRoom(roomGuid: streamGuid)
        } catch {
            DPAGLog(error)
        }
        DPAGUIImageHelper.removeCachedGroupImage(guid: streamGuid)
        DPAGHelperEx.removeEncodedImage(forGroupGuid: streamGuid)
    }

    // MARK: - Private

    private func handleAcceptGroupInvitationSuccess(response: API.Response.AcceptGroupInvitationResponse, groupGuid: String, responseBlock: @escaping DPAGServiceResponseBlock) {
        guard let ownGuid = DPAGApplicationFacade.cache.account?.guid, let apiGroup = response.getGroup() else {
            responseBlock(nil, nil, "service.tryAgainLater")
            return
        }
        var unknownGuids: [String] = []
        self.updateGroup(groupGuid: groupGuid, ownGuid: ownGuid, apiGroup: apiGroup, unknownGuids: &unknownGuids)
        if let result = response.result {
            self.broadcastNewGroupMembers(groupGuid: groupGuid, result: result, ownGuid: ownGuid, unknownGuids: unknownGuids, completion: {
                responseBlock(groupGuid, nil, nil)
            })
        } else {
            responseBlock(groupGuid, nil, nil)
        }
    }

    private func updateGroup(groupGuid: String, ownGuid: String, apiGroup: API.Response.Group, unknownGuids: inout [String]) {
        self.chatRoomDAO.updateGroup(groupGuid: groupGuid, ownGuid: ownGuid, apiGroup: apiGroup, unknownGuids: &unknownGuids)
        DPAGApplicationFacade.preferences.setGroupSynchronizationDone(forGroupGuid: groupGuid)
    }

    private func broadcastNewGroupMembers(groupGuid: String, result: API.Response.GroupAddMembersResult, ownGuid: String, unknownGuids: [String], completion: @escaping () -> Void) {
        guard let notSendGuids = result.notSendUserIds else {
            completion()
            return
        }
        if unknownGuids.isEmpty {
            DPAGSendInternalMessageWorker.broadcastNewGroupMembers([ownGuid], forGroup: groupGuid, tos: notSendGuids)
            completion()
        } else {
            DPAGApplicationFacade.updateKnownContactsWorker.synchronize(accountGuids: unknownGuids, response: { _, _, _ in
                // TODO: check error
                DPAGSendInternalMessageWorker.broadcastNewGroupMembers([ownGuid], forGroup: groupGuid, tos: notSendGuids)
                completion()
            })
        }
    }
}
