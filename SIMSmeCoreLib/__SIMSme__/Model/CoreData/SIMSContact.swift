//
//  SIMSContact.swift
//  SIMSme
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Contacts
import ContactsUI
import CoreData
import Foundation

class SIMSContact: SIMSManagedObjectEncrypted {
    @NSManaged var createdAt: Date?
    @NSManaged var wasDeleted: NSNumber?
    @NSManaged var displayName: String?
    @NSManaged var phone: String?
    @NSManaged var publicKey: String?
    @NSManaged var recordRef: NSNumber?
    @NSManaged var statusMessage: String?
    @NSManaged var statusMessageCreatedAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var stream: SIMSStream?
    @NSManaged var messageReceiver: Set<SIMSMessageReceiver>?

    // Insert code here to add functionality to your managed object subclass

    private static let CONFIDENCE_STATE = "confidenceStatus"
    private static let STATE = "contactState"
    private static let NICKNAME = "contactNickname"
    private static let MANDANT_IDENT = "contactMandantIdent"
    private static let PROFIL_KEY = "Profil-Key"
    private static let STATUS_ENCRYPTED = "statusEncrypted"
    private static let NICKNAME_ENCRYPTED = "nicknameEncrypted"
    private static let IMAGE_CHECKSUM = "image_checksum"
    private static let AES_KEY = "contactAesKey"
    private static let AES_KEY_RECIPIENT_ENCRYPTED = "contactAesKeyRecipientEncrypted"
    private static let AES_KEY_SENDER_ENCRYPTED = "contactAesKeySenderEncrypted"
    private static let ACCOUNT_ID = "accountID"

    static let CONTACT_NAME_UNKNOWN = DPAGLocalizedString("chats.contact.unknown", comment: "")

    @objc
    class func entityName() -> String {
        DPAGStrings.CoreData.Entities.CONTACT
    }

    private var accountID: String? {
        let anAccountID = self.getAttribute(SIMSContact.ACCOUNT_ID) as? String
        return anAccountID
    }

    private var confidenceState: DPAGConfidenceState {
        if let numState = self.getAttribute(SIMSContact.CONFIDENCE_STATE) as? NSNumber {
            return DPAGConfidenceState(rawValue: numState.uintValue) ?? .low
        }
        return .low
    }

    func isConfirmed() -> Bool {
        let myState = self.confidenceState
        return myState.rawValue > DPAGConfidenceState.low.rawValue
    }

    private func isSystemContact() -> Bool {
        self.guid == DPAGConstantsGlobal.kSystemChatAccountGuid
    }

    override public var description: String {
        String(format: "accountGuid %@  phone %@  displayName %@  hasStream \(self.stream != nil)", self.guid ?? "", self.phone ?? "", self.displayName ?? "")
    }

    private func removeAllMessages() {
        self.stream?.messages?.forEach { ($0 as? NSManagedObject)?.mr_deleteEntity() }
    }

    private func aesKeyWithAccountPublicKey(_: String, createNew _: Bool) -> DPAGContactAesKeys? {
        if let aesKey = self.getAttribute(SIMSContact.AES_KEY) as? String, let recipientEncAesKey = self.getAttribute(SIMSContact.AES_KEY_RECIPIENT_ENCRYPTED) as? String, let senderEncAesKey = self.getAttribute(SIMSContact.AES_KEY_SENDER_ENCRYPTED) as? String {
            return DPAGContactAesKeys(aesKey: aesKey, recipientEncAesKey: recipientEncAesKey, senderEncAesKey: senderEncAesKey)
        }
        return nil
    }

    private var mandantIdent: String {
        let mandantIdent = self.getAttribute(SIMSContact.MANDANT_IDENT) as? String
        return mandantIdent ?? DPAGMandant.default.ident
    }

    private var nickName: String? {
        let aNickName = self.getAttribute(SIMSContact.NICKNAME) as? String
        return aNickName
    }

    private var profilKey: String? {
        let aProfilKey = self.getAttribute(SIMSContact.PROFIL_KEY) as? String
        return aProfilKey
    }

    private var statusEncrypted: String? {
        let aStatus = self.getAttribute(SIMSContact.STATUS_ENCRYPTED) as? String
        return aStatus
    }

    private var nicknameEncrypted: String? {
        let aNickName = self.getAttribute(SIMSContact.NICKNAME_ENCRYPTED) as? String
        return aNickName
    }

    private var imageChecksum: String? {
        let aCheckSum = self.getAttribute(SIMSContact.IMAGE_CHECKSUM) as? String
        return aCheckSum
    }

    private var isReadOnly: Bool {
        self.stream?.optionsStream.contains(.isReadOnly) ?? true
    }

    private var isBlocked: Bool {
        var state: Int = 0
        if let stateNum = self.getAttribute(SIMSContact.STATE) as? NSNumber {
            state = stateNum.intValue
        }
        return (state & DPAGContactStateMask.blocked.rawValue) == DPAGContactStateMask.blocked.rawValue
    }

    private var streamState: DPAGChatStreamState {
        var streamState: DPAGChatStreamState = .read
        streamState = ((self.wasDeleted?.boolValue ?? false) || DPAGSystemChat.isSystemChat(self.stream) || self.isBlocked) ? .readOnly : .write
        return streamState
    }

    func migrate(into contactIndexEntry: SIMSContactIndexEntry, in localContext: NSManagedObjectContext, addressBookContacts: [Int: CNContact]) {
        guard let contactGuid = self.guid else { return }
        contactIndexEntry.keyRelationship = self.keyRelationship
        contactIndexEntry[.PUBLIC_KEY] = self.publicKey
        contactIndexEntry[.ACCOUNT_ID] = self.accountID
        contactIndexEntry[.MANDANT_IDENT] = self.mandantIdent
        contactIndexEntry[.PROFIL_KEY] = self.profilKey
        contactIndexEntry[.NICKNAME] = self.nickName
        contactIndexEntry[.NICKNAME_ENCRYPTED] = self.nicknameEncrypted
        contactIndexEntry[.PHONE_NUMBER] = self.phone
        contactIndexEntry[.STATUSMESSAGE] = self.statusMessage
        contactIndexEntry[.STATUS_ENCRYPTED] = self.statusEncrypted
        contactIndexEntry[.IS_BLOCKED] = self.isBlocked
        contactIndexEntry[.IS_CONFIRMED] = self.isConfirmed()
        contactIndexEntry[.IS_DELETED] = self.wasDeleted?.boolValue ?? false
        contactIndexEntry[.IMAGE_CHECKSUM] = self.imageChecksum
        contactIndexEntry[.CREATED_AT] = self.createdAt ?? Date()
        contactIndexEntry[.UPDATED_AT] = self.updatedAt ?? Date()
        contactIndexEntry[.IMAGE_DATA] = DPAGHelperEx.encodedImage(forGroupGuid: contactGuid)
        DPAGHelperEx.removeEncodedImage(forGroupGuid: contactGuid)
        contactIndexEntry.entryTypeLocal = .hidden
        if let contactRecordRef = self.recordRef, contactRecordRef.intValue != 0, let contactAB = addressBookContacts[contactRecordRef.intValue] {
            contactIndexEntry.entryTypeLocal = .privat
            contactIndexEntry[.FIRST_NAME] = contactAB.givenName
            contactIndexEntry[.LAST_NAME] = contactAB.familyName
            contactIndexEntry[.DEPARTMENT] = contactAB.departmentName
            if let emailAddress = contactAB.emailAddresses.first {
                contactIndexEntry[.EMAIL_ADDRESS] = emailAddress.value as String
            }
        }
        contactIndexEntry.confidenceState = self.confidenceState
        let contactMessageReceiver = self.messageReceiver ?? Set()
        self.messageReceiver?.removeAll()
        for mr in contactMessageReceiver {
            mr.contactIndexEntry = contactIndexEntry
            mr.contact = nil
        }
        contactIndexEntry.messageReceiver?.formUnion(contactMessageReceiver)
        if let stream = self.stream {
            if contactGuid.isSystemChatGuid == false, stream.messages?.count ?? 0 > 0 || stream.lastMessageDate != nil {
                contactIndexEntry.entryTypeLocal = .privat
            }
            contactIndexEntry.stream = stream
            stream.contactIndexEntry = contactIndexEntry
        } else {
            contactIndexEntry.createNewStream(in: localContext)
        }
        contactIndexEntry.entryTypeServer = .privat
    }
}
