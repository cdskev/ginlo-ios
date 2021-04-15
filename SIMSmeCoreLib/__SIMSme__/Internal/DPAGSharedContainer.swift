//
//  DPAGSharedContainer.swift
//  SIMSmeCore
//
//  Created by Matthias Röhricht on 06.03.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

public class DPAGSharedContainerSending: DPAGSharedContainerExtensionSending {
    private let appExtensionDAO: AppExtensionDAOProtocol = AppExtensionDAO()

    public func saveData(config: DPAGSharedContainerConfig) throws {
        guard let crypto = DPAGCryptoHelper.newAccountCrypto() else {
            return
        }

        try super.saveData(config: config, filename: self.fileName, crypto: crypto)
    }

    override public func getCacheInfos() throws -> String? {
        // ACHTUNG: Die Methode wird im Hintergrund aufgerufen, nachdem der Schlüssel weggeworfen wurde. Automatisches Entschlüsseln der Attribute (z.B. AccountID) geht daher nicht ....

        guard /* let httpUsername = DPAGApplicationFacade.model.httpUsername, */ let accountCache = DPAGApplicationFacade.cache.account /* , let contact = DPAGApplicationFacade.cache.contact(for: accountCache.guid), let publicKey = contact.publicKey */, let deviceGuid = DPAGApplicationFacade.preferences.shareExtensionDeviceGuid, let devicePasstoken = DPAGApplicationFacade.preferences.shareExtensionDevicePasstoken else {
            return nil
        }

//        let accountInfo = AccountPreference(httpUsername: httpUsername, backgroundAccessToken: backgroundAccessToken, publicKey: publicKey)
        var contacts: [Contact] = []
        var contactStreams: [ContactStream] = []
        var groups: [Group] = []

        try self.appExtensionDAO.getContactsAndContactStreamsForShareExtension(account: accountCache, contacts: &contacts, contactStreams: &contactStreams)

        for group in DPAGApplicationFacade.cache.allGroups().filter({ (group) -> Bool in
            group.isConfirmed && group.isDeleted == false && group.isReadOnly == false
        }) {
            let sCGroup = group.groupSending

            groups.append(sCGroup)
        }

        let chats = try self.appExtensionDAO.getConversationsForShareExtension()

        let preferences = DPAGApplicationFacade.preferences.preferencesSendingExtension()

        return try self.convertData(containerData: Container(preferences: preferences, account: accountCache.accountSending, device: Device(guid: deviceGuid, passToken: devicePasstoken), contacts: contacts, contactStreams: contactStreams, groups: groups, chats: chats))
    }
}

public class DPAGSharedContainer: DPAGSharedContainerExtension {
    private let appExtensionDAO: AppExtensionDAOProtocol = AppExtensionDAO()

    public func saveData(config: DPAGSharedContainerConfig) throws {
        guard let crypto = DPAGCryptoHelper.newAccountCrypto() else {
            return
        }

        try super.saveData(config: config, filename: self.fileName, crypto: crypto)
    }

    override public func getCacheInfos() throws -> String? {
        guard let httpUsername = DPAGApplicationFacade.model.httpUsername, let backgroundAccessToken = DPAGApplicationFacade.preferences.backgroundAccessToken, let accountCache = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: accountCache.guid), let publicKey = contact.publicKey else {
            return nil
        }

        let accountInfo = AccountPreference(httpUsername: httpUsername, backgroundAccessToken: backgroundAccessToken, publicKey: publicKey)
        let account = Account(guid: accountCache.guid, accountPreference: accountInfo)
        let contacts = try self.appExtensionDAO.getContactsForNotificationExtension(account: accountCache)
        var groups: [String: Group] = [:]

        for group in DPAGApplicationFacade.cache.allGroups().filter({ (group) -> Bool in
            group.isConfirmed && group.isDeleted == false
        }) {
            let aesKey = group.aesKey ?? "??"
            let name = group.name ?? "??"

            let groupPreference = GroupPreference(name: name, aesKey: aesKey)
            let sCGroup = Group(guid: group.guid, groupPreference: groupPreference)
            groups[sCGroup.guid] = sCGroup
        }

        return try self.convertData(containerData: SharedContainer(account: account, contacts: contacts, groups: groups))
    }
}
