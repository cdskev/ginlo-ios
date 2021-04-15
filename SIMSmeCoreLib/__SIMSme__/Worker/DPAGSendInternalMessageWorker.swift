//
//  DPAGSendInternalMessageWorker.m
//  SIMSme
//
//  Created by RBU on 17/06/2015.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

public class DPAGSendInternalMessageWorker: NSObject {
    class func broadcastGroupImage(_ encoded: String, groupGuid: String, toGroupMember members: [String]) {
        DPAGHelperEx.saveBase64Image(encodedImage: encoded, forGroupGuid: groupGuid)

        if let jsonString = self.getJsonStringForGroup(groupGuid, withImage: encoded) {
            self.broadcastJson(jsonString, toAccountGuids: members)
        }
    }

    class func broadcastGroupName(_ groupName: String, groupGuid: String, toGroupMember members: [String]) {
        if let jsonString = self.getJsonStringForGroup(groupGuid, withName: groupName) {
            self.broadcastJson(jsonString, toAccountGuids: members)
        }
    }

    public class func broadcastProfileImage(_ encoded: String) {
        self.broadcastProfilUpdate(nickname: nil, status: nil, image: encoded, oooState: nil, oooStatusText: nil, oooStatusValid: nil, completion: nil)
    }

    class func broadcastStatusUpdate(_ status: String) {
        self.broadcastProfilUpdate(nickname: nil, status: status, image: nil, oooState: nil, oooStatusText: nil, oooStatusValid: nil, completion: nil)
    }

    class func broadcastStatusUpdate(_ status: String, oooState: String?, oooStatusText: String?, oooStateValid: String?, completion: DPAGServiceResponseBlock?) {
        self.broadcastProfilUpdate(nickname: nil, status: status, image: nil, oooState: oooState, oooStatusText: oooStatusText, oooStatusValid: oooStateValid, completion: completion)
    }

    public class func broadcastProfilUpdate(nickname: String?, status: String?, image: String?, oooState: String?, oooStatusText: String?, oooStatusValid: String?, completion: DPAGServiceResponseBlock?) {
        // Versand als öffentliche Methode
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            guard let account = SIMSAccount.mr_findFirst(in: localContext), let accountGuid = account.guid, let contact = SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) else {
                return
            }

            var encryptedNickname: String?
            var encryptedStatus: String?
            var encryptedImage: String?
            var encryptedOooStatus: String?
            var recipients: [String] = []

            do {
                try contact.ensureProfilKey()

                if nickname != nil {
                    encryptedNickname = try contact.encryptWithProfilKey(nickname)
                }

                if status != nil {
                    encryptedStatus = try contact.encryptWithProfilKey(status)
                }

                if image != nil {
                    encryptedImage = try contact.encryptWithProfilKey(image)
                }

                if let oooState = oooState {
                    // ooo Status lokal Speichern
                    contact.setOooStatus(oooState, statusText: oooStatusText, statusValid: oooStatusValid)
                    if status != nil {
                        contact[.STATUSMESSAGE] = status
                    }
                    // ooo Status verschlüsseln
                    var statusJson: [String: String] = [:]
                    if oooState == "ooo" {
                        if let text = oooStatusText {
                            let iv = try CryptoHelperEncrypter.getNewRawIV()

                            statusJson["statusTextIV"] = iv
                            statusJson["statusText"] = try contact.encryptWithProfilKey(text, iv: iv)
                        }
                        if let statusValid = oooStatusValid {
                            statusJson["statusValid"] = statusValid
                        }
                    }
                    statusJson["statusState"] = oooState

                    encryptedOooStatus = statusJson.JSONString
                }

                let ownGuid = accountGuid

                DPAGApplicationFacade.persistance.loadWithBlock({ localContext in

                    if let contacts = SIMSContactIndexEntry.mr_findAll(in: localContext) as? [SIMSContactIndexEntry] {
                        for contact in contacts {
                            if let contactGuid = contact.guid, contactGuid.isSystemChatGuid == false, contactGuid != ownGuid, contact[.IS_DELETED] == false, (contact.publicKey?.isEmpty ?? true) == false {
                                recipients.append(contactGuid)
                            }
                        }
                    }
                })
            } catch {
                DPAGLog(error)
                return
            }
            let block: DPAGServiceResponseBlock = { responseObject, errorCode, errorMessage in

                if errorMessage == nil {
                    if let responseDict = responseObject as? [String: Any], let dict = responseDict[DPAGStrings.Server.ProfilInfo.PROFILE_INFO_RESULT] as? [String: Any] {
                        if let notSend = dict[DPAGStrings.Server.ProfilInfo.NOT_SEND] as? [String], notSend.count > 0 {
                            // Alte Methode
                            if let nickname = nickname, let jsonString = self.getJsonStringForNicknameUpdate(nickname) {
                                self.broadcastJson(jsonString, toAccountGuids: notSend)
                            }
                            // Alte Methode
                            if let status = status, let jsonString = self.getJsonStringForStatusUpdate(status) {
                                self.broadcastJson(jsonString, toAccountGuids: notSend)
                            }

                            // Alte Methode
                            if let image = image, let jsonString = self.getJsonStringForProfileImage(image) {
                                self.broadcastJson(jsonString, toAccountGuids: notSend)
                            }
                        }
                    }
                } else {
                    DPAGApplicationFacade.preferences.setProfileInfoServerNeedsUpdate()

                    // Alte Methode
                    if let nickname = nickname, let jsonString = self.getJsonStringForNicknameUpdate(nickname) {
                        self.broadcastJson(jsonString)
                    }
                    // Alte Methode
                    if let status = status, let jsonString = self.getJsonStringForStatusUpdate(status) {
                        self.broadcastJson(jsonString)
                    }

                    // Alte Methode
                    if let image = image, let jsonString = self.getJsonStringForProfileImage(image) {
                        self.broadcastJson(jsonString)
                    }
                }

                completion?(responseObject, errorCode, errorMessage)
            }
            DPAGApplicationFacade.server.setProfilInfo(nickname: encryptedNickname, andStatus: encryptedStatus, andImage: encryptedImage, oooStatus: encryptedOooStatus, toAccounts: recipients, withResponse: block)
        }
    }

    public class func sendProfileToContacts(_ contactGuids: [String]) {
        // TODO: Update auf neuen oooStatus ..
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) else {
            return
        }

        var jsonString: String?

        if let nickName = contact.nickName {
            jsonString = self.getJsonStringForNicknameUpdate(nickName)
        }

        if let jsonString = jsonString {
            self.broadcastJson(jsonString, toAccountGuids: contactGuids)
        }

        // Den Rest mit neuer Methode verschicken
        let block: DPAGServiceResponseBlock = { responseObject, _, errorMessage in

            if errorMessage == nil {
                if let responseDict = responseObject as? [AnyHashable: Any], let dict = responseDict[DPAGStrings.Server.ProfilInfo.PROFILE_INFO_RESULT] as? [AnyHashable: Any] {
                    if let notSend = dict[DPAGStrings.Server.ProfilInfo.NOT_SEND] as? [String], notSend.count > 0 {
                        // Alte Methode
                        let status = DPAGApplicationFacade.statusWorker.latestStatus()

                        if let jsonString = self.getJsonStringForStatusUpdate(status) {
                            self.broadcastJson(jsonString, toAccountGuids: notSend)
                        }

                        // Alte Methode
                        if let image = contact.imageDataStr, let jsonString = self.getJsonStringForProfileImage(image) {
                            self.broadcastJson(jsonString, toAccountGuids: notSend)
                        }
                    }
                }
            } else {
                // Alte Methode
                let status = DPAGApplicationFacade.statusWorker.latestStatus()

                if let jsonString = self.getJsonStringForStatusUpdate(status) {
                    self.broadcastJson(jsonString)
                }

                // Alte Methode
                if let image = contact.imageDataStr, let jsonString = self.getJsonStringForProfileImage(image) {
                    self.broadcastJson(jsonString)
                }
            }
        }
        DPAGApplicationFacade.server.setProfilInfo(nickname: nil, andStatus: nil, andImage: nil, oooStatus: nil, toAccounts: contactGuids, withResponse: block)
    }

    public class func broadcastNicknameUpdate(_ text: String) {
        self.broadcastProfilUpdate(nickname: text, status: nil, image: nil, oooState: nil, oooStatusText: nil, oooStatusValid: nil, completion: nil)
    }

    class func broadcastNewGroupMembers(_ newGuids: [String], forGroup groupGuid: String, tos recipients: [String]) {
        if let jsonString = self.getJsonStringForNewGroupMembers(newGuids, inGroup: groupGuid) {
            self.sendInternalMessage(jsonString, tos: recipients)
        }
    }

    class func broadcastRemovedGroupMembers(_ newGuids: [String], forGroup groupGuid: String, tos recipients: [String]) {
        if let jsonString = self.getJsonStringForRemovedGroupMembers(newGuids, inGroup: groupGuid) {
            self.sendInternalMessage(jsonString, tos: recipients)
        }
    }

    private class func broadcastJson(_ json: String) {
        var recipients: [String] = []

        DPAGApplicationFacade.persistance.loadWithBlock { localContext in

            if let contacts = SIMSContactIndexEntry.mr_findAll(in: localContext) {
                recipients = contacts.compactMap { obj in
                    (obj as? SIMSContactIndexEntry)?.guid
                }
            }
        }
        self.sendInternalMessage(json, tos: recipients)
    }

    private class func broadcastJson(_ json: String, toAccountGuids accountGuids: [String]) {
        DPAGFunctionsGlobal.synchronized(self) {
            self.sendInternalMessage(json, tos: accountGuids)
        }
    }

    private class func getJsonStringForNewGroupMembers(_ guids: [String], inGroup groupGuid: String) -> String? {
        let dataDict: [String: Any] = [
            DPAGStrings.JSON.MessagePrivateInternal.CONTENT: guids,
            DPAGStrings.JSON.MessagePrivateInternal.GROUP_GUID: groupGuid,
            DPAGStrings.JSON.MessagePrivateInternal.CONTENT_TYPE: DPAGStrings.JSON.MessagePrivateInternal.ContentType.NEW_GROUP_MEMBERS
        ]

        return dataDict.JSONString
    }

    private class func getJsonStringForRemovedGroupMembers(_ guids: [String], inGroup groupGuid: String) -> String? {
        let dataDict: [String: Any] = [
            DPAGStrings.JSON.MessagePrivateInternal.CONTENT: guids,
            DPAGStrings.JSON.MessagePrivateInternal.GROUP_GUID: groupGuid,
            DPAGStrings.JSON.MessagePrivateInternal.CONTENT_TYPE: DPAGStrings.JSON.MessagePrivateInternal.ContentType.REMOVED_GROUP_MEMBERS
        ]

        return dataDict.JSONString
    }

    private class func getJsonStringForStatusUpdate(_ status: String) -> String? {
        let dataDict: [String: Any] = [
            DPAGStrings.JSON.MessagePrivateInternal.CONTENT: status,
            DPAGStrings.JSON.MessagePrivateInternal.CONTENT_TYPE: DPAGStrings.JSON.MessagePrivateInternal.ContentType.STATUS
        ]

        return dataDict.JSONString
    }

    private class func getJsonStringForNicknameUpdate(_ name: String) -> String? {
        let dataDict: [String: Any] = [
            DPAGStrings.JSON.MessagePrivateInternal.CONTENT: name,
            DPAGStrings.JSON.MessagePrivateInternal.CONTENT_TYPE: DPAGStrings.JSON.MessagePrivateInternal.ContentType.NICKNAME
        ]

        return dataDict.JSONString
    }

    private class func getJsonStringForProfileImage(_ encoded: String) -> String? {
        let dataDict: [String: Any] = [
            DPAGStrings.JSON.MessagePrivateInternal.CONTENT: encoded,
            DPAGStrings.JSON.MessagePrivateInternal.CONTENT_TYPE: DPAGStrings.JSON.MessagePrivateInternal.ContentType.IMAGE
        ]

        return dataDict.JSONString
    }

    private class func getJsonStringForGroup(_ streamGuid: String, withImage encoded: String) -> String? {
        let dataDict: [String: Any] = [
            DPAGStrings.JSON.MessagePrivateInternal.CONTENT: encoded,
            DPAGStrings.JSON.MessagePrivateInternal.GROUP_GUID: streamGuid,
            DPAGStrings.JSON.MessagePrivateInternal.CONTENT_TYPE: DPAGStrings.JSON.MessagePrivateInternal.ContentType.GROUP_IMAGE
        ]

        return dataDict.JSONString
    }

    private class func getJsonStringForGroup(_ streamGuid: String, withName encoded: String) -> String? {
        let dataDict: [String: Any] = [
            DPAGStrings.JSON.MessagePrivateInternal.CONTENT: encoded,
            DPAGStrings.JSON.MessagePrivateInternal.GROUP_GUID: streamGuid,
            DPAGStrings.JSON.MessagePrivateInternal.CONTENT_TYPE: DPAGStrings.JSON.MessagePrivateInternal.ContentType.GROUP_NAME
        ]

        return dataDict.JSONString
    }

    private class func sendInternalMessage(_ json: String, tos recipients: [String]) {
        self.sendInternalMessages([String](repeating: json, count: recipients.count), tos: recipients)
    }

    private class func sendInternalMessages(_ jsons: [String], tos recipients: [String]) {
        var arrMsgGuids: [String] = []
        var messageJsonsString: String?

        DPAGApplicationFacade.persistance.saveWithBlock { localContext in

            var arrMsgs: [[AnyHashable: Any]] = []
            let ownGuid = DPAGApplicationFacade.cache.account?.guid

            for idx in 0 ..< recipients.count {
                if idx >= jsons.count {
                    break
                }

                let json = jsons[idx]
                let recipientGuid = recipients[idx]

                if recipientGuid.isSystemChatGuid == false, ownGuid != recipientGuid {
                    if let recipient = SIMSContactIndexEntry.findFirst(byGuid: recipientGuid, in: localContext), (recipient[.PUBLIC_KEY]?.isEmpty ?? true) == false, recipient[.IS_DELETED] == false {
                        do {
                            if let message = SIMSPrivateInternalMessage.mr_createEntity(in: localContext), let messageGuid = message.guid, let messageDict = try DPAGApplicationFacade.messageFactory.internalMessageDictionary(text: json, forRecipient: recipient, writeTo: message, in: localContext) {
                                arrMsgs.append(messageDict)
                                arrMsgGuids.append(messageGuid)
                            }
                        } catch {
                            DPAGLog(error)
                        }
                    }
                }
            }
            messageJsonsString = arrMsgs.JSONString
        }

        if arrMsgGuids.count > 0, let messageJsonsString = messageJsonsString {
            let block: DPAGServiceResponseBlock = { _, _, errorMessage in

                if errorMessage == nil {
                    DPAGApplicationFacade.persistance.saveWithBlock { localContext in

                        for guid in arrMsgGuids {
                            let msg = SIMSPrivateInternalMessage.findFirst(byGuid: guid, in: localContext)

                            msg?.mr_deleteEntity(in: localContext)
                        }
                    }
                }
            }
            do {
                try DPAGApplicationFacade.server.sendInternalMessages(messageJsonsString: messageJsonsString, withResponse: block)
            } catch {
                DPAGLog(error)
            }
        }
    }
}
