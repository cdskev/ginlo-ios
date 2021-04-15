//
// Created by mg on 29.10.13.
// Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData

protocol DPAGContactModelFactoryProtocol: AnyObject {
    func newModel(accountGuid: String, publicKey: String?, in localContext: NSManagedObjectContext) -> SIMSContactIndexEntry?
    func newModel(accountJson accountDict: [AnyHashable: Any], in localContext: NSManagedObjectContext) -> SIMSContactIndexEntry?
    func newOrUpdateModel(withAccountJson accountDict: [AnyHashable: Any], in localContext: NSManagedObjectContext) -> SIMSContactIndexEntry?

    func updateModel(contact: SIMSContactIndexEntry, withAccountJson accountDict: [AnyHashable: Any], in localContext: NSManagedObjectContext) -> NSNotification.Name?

    func contact(accountDict: [AnyHashable: Any], phoneNumber: String?, in localContext: NSManagedObjectContext) -> SIMSContactIndexEntry?

    func getUnknownGuidsFromGroupMembers(groupMemberGuids: [String], in localContext: NSManagedObjectContext) -> [String]
}

class DPAGContactModelFactory: NSObject, DPAGContactModelFactoryProtocol {
    func newModel(accountGuid: String, publicKey: String?, in localContext: NSManagedObjectContext) -> SIMSContactIndexEntry? {
        DPAGLog(" create contact with guid %@", accountGuid)

        guard let contact = SIMSContactIndexEntry.mr_createEntity(in: localContext) else {
            return nil
        }

        contact.keyRelationship = SIMSKey.mr_findFirst(in: localContext)
        contact.guid = accountGuid
        contact[.PUBLIC_KEY] = publicKey
        contact[.CREATED_AT] = Date()
        contact[.STATUSMESSAGE] = ""

        _ = contact.createNewStream(in: localContext)

        if accountGuid == DPAGApplicationFacade.cache.account?.guid {
            contact.confidenceState = .high
        } else {
            contact.confidenceState = .low
        }

        return contact
    }

    func newModel(accountJson accountDict: [AnyHashable: Any], in localContext: NSManagedObjectContext) -> SIMSContactIndexEntry? {
        guard let guid = accountDict[SIMS_GUID] as? String, let publicKey = accountDict[SIMS_PUBLIC_KEY] as? String else {
            return nil
        }

        if let contact = self.newModel(accountGuid: guid, publicKey: publicKey, in: localContext) {
            if let mandantIdent = accountDict[DPAGStrings.WHITELABEL_MANDANT] as? String {
                contact[.MANDANT_IDENT] = mandantIdent
            }
            if let phone = accountDict[DPAGStrings.JSON.Account.PHONE] as? String {
                contact[.PHONE_NUMBER] = phone
            }
            if let email = accountDict[DPAGStrings.JSON.Account.EMAIL] as? String {
                contact[.EMAIL_ADDRESS] = email
            }
            if let accountID = accountDict[DPAGStrings.JSON.Account.ACCOUNT_ID] as? String {
                contact[.ACCOUNT_ID] = accountID
            }

            return contact
        }
        return nil
    }

    func newOrUpdateModel(withAccountJson accountDict: [AnyHashable: Any], in localContext: NSManagedObjectContext) -> SIMSContactIndexEntry? {
        guard let guid = accountDict[SIMS_GUID] as? String, let publicKey = accountDict[SIMS_PUBLIC_KEY] as? String else {
            return nil
        }

        var contact = SIMSContactIndexEntry.findFirst(byGuid: guid, in: localContext)

        if contact == nil {
            contact = self.newModel(accountGuid: guid, publicKey: publicKey, in: localContext)
        } else if publicKey != contact?[.PUBLIC_KEY] {
            contact?[.PUBLIC_KEY] = publicKey
        }

        if let contact = contact, contact.guid == guid {
            _ = self.updateModel(contact: contact, withAccountJson: accountDict, in: localContext)

            DPAGApplicationFacade.preferences.setProfileSynchronizationDone(forProfileGuid: guid)
        }
        return contact
    }

    private func updateModelInternal(_ contact: SIMSContactIndexEntry, withAccountJson accountDict: [AnyHashable: Any], in localContext: NSManagedObjectContext) -> Bool {
        var doNotifyReadOnly = false

        guard CryptoHelper.sharedInstance?.isPrivateKeyInMemory() ?? false, let guid = accountDict[SIMS_GUID] as? String else {
            return doNotifyReadOnly
        }

        if let phone = accountDict[DPAGStrings.JSON.Account.PHONE] as? String, contact[.PHONE_NUMBER] != phone {
            contact[.PHONE_NUMBER] = phone
        }
        if let email = accountDict[DPAGStrings.JSON.Account.EMAIL] as? String, contact[.EMAIL_ADDRESS] != email {
            contact[.EMAIL_ADDRESS] = email
        }
        if let accountID = accountDict[SIMS_ACCOUNT_ID] as? String, contact[.ACCOUNT_ID] != accountID {
            contact[.ACCOUNT_ID] = accountID

            doNotifyReadOnly = doNotifyReadOnly || (contact[.IMAGE_CHECKSUM] == nil)
        }

        if guid == contact.guid {
            if let publicKey = accountDict[SIMS_PUBLIC_KEY] as? String, publicKey != contact[.PUBLIC_KEY] {
                contact[.PUBLIC_KEY] = publicKey
            }

            if let statusEncrypted = accountDict[DPAGStrings.JSON.Account.STATUS] as? String, statusEncrypted != contact[.STATUS_ENCRYPTED] {
                contact[.STATUS_ENCRYPTED] = statusEncrypted
            }

            if let nicknameEncrypted = accountDict[DPAGStrings.JSON.Account.NICKNAME] as? String, nicknameEncrypted != contact[.NICKNAME_ENCRYPTED] {
                contact[.NICKNAME_ENCRYPTED] = nicknameEncrypted

                DPAGApplicationFacade.cache.contact(for: guid)?.removeCachedImages()

                doNotifyReadOnly = doNotifyReadOnly || (contact[.IMAGE_CHECKSUM] == nil)
            }

            // TODO: checksumme vergleichen
            if let imageChecksum = accountDict[DPAGStrings.JSON.Account.IMAGE_CHECKSUM] as? String, imageChecksum != contact[.IMAGE_CHECKSUM] {
                contact[.IMAGE_CHECKSUM] = imageChecksum
            }

            if let mandantIdent = accountDict[DPAGStrings.WHITELABEL_MANDANT] as? String, mandantIdent != contact[.MANDANT_IDENT] {
                contact[.MANDANT_IDENT] = mandantIdent
            }
        } else {
            _ = contact.createNewStream(in: localContext)

            let publicKey = accountDict[SIMS_PUBLIC_KEY] as? String

            contact.guid = guid
            contact[.CREATED_AT] = Date()
            contact[.PUBLIC_KEY] = publicKey

            if let mandantIdent = accountDict[DPAGStrings.WHITELABEL_MANDANT] as? String {
                contact[.MANDANT_IDENT] = mandantIdent
            }
        }

        let contactStreamOptionsValue = contact.stream?.optionsStream ?? []

        if let readOnly = accountDict[DPAGStrings.Server.ProfilInfo.Response.READONLY] as? String {
            if readOnly == "1" {
                if contactStreamOptionsValue.contains(.isReadOnly) == false {
                    contact.stream?.optionsStream = contactStreamOptionsValue.union(.isReadOnly)
                    doNotifyReadOnly = true
                }
            } else if contactStreamOptionsValue.contains(.isReadOnly) {
                contact.stream?.optionsStream = contactStreamOptionsValue.subtracting(.isReadOnly)
                doNotifyReadOnly = true
            }
        } else if contactStreamOptionsValue.contains(.isReadOnly) {
            contact.stream?.optionsStream = contactStreamOptionsValue.subtracting(.isReadOnly)
            doNotifyReadOnly = true
        }

        return doNotifyReadOnly
    }

    func updateModel(contact: SIMSContactIndexEntry, withAccountJson accountDict: [AnyHashable: Any], in localContext: NSManagedObjectContext) -> NSNotification.Name? {
        let doNotifyReadOnly = self.updateModelInternal(contact, withAccountJson: accountDict, in: localContext)

        if doNotifyReadOnly {
            return DPAGStrings.Notification.Contact.CHANGED
        }

        return nil
    }

    func contact(accountDict: [AnyHashable: Any], phoneNumber: String?, in localContext: NSManagedObjectContext) -> SIMSContactIndexEntry? {
        if let accountGuid = accountDict[SIMS_GUID] as? String {
            return SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext)
        }

        return (SIMSContactIndexEntry.mr_findAll(in: localContext) as? [SIMSContactIndexEntry])?.filter({ (contact) -> Bool in
            contact.phoneNumber == phoneNumber
        }).max(by: { (contact1, contact2) -> Bool in
            if let date1 = contact1[.CREATED_AT] {
                if let date2 = contact2[.CREATED_AT] {
                    return date1.compare(date2) == .orderedAscending
                }
                return true
            }
            return contact2[.CREATED_AT] == nil
        })
    }

    func getUnknownGuidsFromGroupMembers(groupMemberGuids: [String], in localContext: NSManagedObjectContext) -> [String] {
        let unknownMembers = groupMemberGuids.filter { (memberGuid) -> Bool in

            SIMSContactIndexEntry.findFirst(byGuid: memberGuid, in: localContext) == nil
        }

        return unknownMembers
    }
}
