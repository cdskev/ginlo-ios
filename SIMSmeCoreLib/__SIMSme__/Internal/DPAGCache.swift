//
//  DPAGCache.swift
//  SIMSme
//
//  Created by RBU on 05/11/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Contacts
import CoreData
import JFBCrypt
import UIKit

public struct DPAGContentLinkReplacerRegex {
    let regEx: NSRegularExpression
    let replacer: String
}

public struct DPAGContentLinkReplacerString {
    let pattern: String
    let replacer: String
}

public struct DPAGContentLinkReplacerRange {
    let url: URL
    let replacer: String
}

public class DPAGCache: NSObject {
    override init() {
        super.init()

        if AppConfig.isShareExtension == false {
            self.reinitCaches()
        }
    }

    public static let dataDetectorTypes: NSTextCheckingResult.CheckingType = [.link]

    static let dataDetector: NSDataDetector? = try? NSDataDetector(types: DPAGCache.dataDetectorTypes.rawValue)

    private let queueObjects: DispatchQueue = DispatchQueue(label: "de.dpag.simsme.DPAGCache.queueObjects", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)

    private let queueMessages: DispatchQueue = DispatchQueue(label: "de.dpag.simsme.DPAGCache.queueMessages", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    private let queueStreams: DispatchQueue = DispatchQueue(label: "de.dpag.simsme.DPAGCache.queueStreams", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    private let queueImages: DispatchQueue = DispatchQueue(label: "de.dpag.simsme.DPAGCache.queueImages", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    private let queueAesKeys: DispatchQueue = DispatchQueue(label: "de.dpag.simsme.DPAGCache.queueAesKey", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    private let queueContentLinkReplacer: DispatchQueue = DispatchQueue(label: "de.dpag.simsme.DPAGCache.queueContentLinkReplacer", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    private let queueAttrDict: DispatchQueue = DispatchQueue(label: "de.dpag.simsme.DPAGCache.queueAttrDict", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)

    private let queuePhoneNumber: DispatchQueue = DispatchQueue(label: "de.dpag.simsme.DPAGCache.queuePhoneNumber", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)

    private var objects: [String: DPAGObject] = [:]
    private var contacts: [String: DPAGContact] = [:]
    private var groups: [String: DPAGGroup] = [:]
    private var channels: [String: DPAGChannel] = [:]

    private var decryptedMessagesDict: [String: DPAGDecryptedMessage] = [:]
    private var decryptedStreamsDict: [String: DPAGDecryptedStream] = [:]
    private var cachedImagesDict: [String: [Int: [String: UIImage]]] = [:]
    private var cachedAesKeyDict: [String: String] = [:]
    private var cacheDecryptedDict: [String: [String: Any]] = [:]
    private var cachePhoneNumber: [String: String] = [:]
    private var cachedContentLinkReplacer: [String: [DPAGContentLinkReplacerRegex]] = [:]

    private var cachedTempDeviceInfo: [String: DPAGTempDeviceInfo] = [:]

    private lazy var fetchedResultsControllerContacts: NSFetchedResultsController<SIMSContactIndexEntry> = DPAGCache.frc(entityName: SIMSContactIndexEntry.entityName())
    private lazy var fetchedResultsControllerGroups: NSFetchedResultsController<SIMSGroup> = DPAGCache.frc(entityName: SIMSGroup.entityName())
    private lazy var fetchedResultsControllerChannels: NSFetchedResultsController<SIMSChannel> = DPAGCache.frc(entityName: SIMSChannel.entityName())
    private lazy var fetchedResultsControllerAccount: NSFetchedResultsController<SIMSAccount> = DPAGCache.frc(entityName: SIMSAccount.entityName())

    private var accountInternal: DPAGAccount?
    public var account: DPAGAccount? {
        var rc: DPAGAccount?
        self.queueObjects.sync {
            rc = self.accountInternal
        }

        return rc
    }

    public func initFetchedResultsController() {
        guard self.fetchedResultsControllerContacts.delegate == nil else {
            return
        }

        self.fetchedResultsControllerAccount.managedObjectContext.performAndWait {
            do {
                try self.fetchedResultsControllerAccount.performFetch()

                if let accountDB = self.fetchedResultsControllerAccount.fetchedObjects?.first {
                    let accountInternal = DPAGAccount(account: accountDB)

                    self.queueObjects.async(flags: .barrier) {
                        self.accountInternal = accountInternal
                    }
                }
            } catch {
                DPAGLog(error)
            }
        }
        self.fetchedResultsControllerAccount.delegate = self

        self.fetchedResultsControllerContacts.managedObjectContext.performAndWait {
            do {
                try self.fetchedResultsControllerContacts.performFetch()
            } catch {
                DPAGLog(error)
            }
        }
        self.fetchedResultsControllerContacts.delegate = self

        self.fetchedResultsControllerGroups.managedObjectContext.performAndWait {
            do {
                try self.fetchedResultsControllerGroups.performFetch()

                if let fetchedObjects = self.fetchedResultsControllerGroups.fetchedObjects {
                    for group in fetchedObjects {
                        if let groupCache = DPAGGroup(group: group) {
                            self.queueObjects.async(flags: .barrier) {
                                self.objects[groupCache.guid] = groupCache
                                self.groups[groupCache.guid] = groupCache
                            }
                        }
                    }
                }
            } catch {
                DPAGLog(error)
            }
        }
        self.fetchedResultsControllerGroups.delegate = self

        self.fetchedResultsControllerChannels.managedObjectContext.performAndWait {
            do {
                try self.fetchedResultsControllerChannels.performFetch()

                if let fetchedObjects = self.fetchedResultsControllerChannels.fetchedObjects {
                    for channel in fetchedObjects {
                        if let channelCache = DPAGChannel(channel: channel) {
                            self.queueObjects.async(flags: .barrier) {
                                self.objects[channelCache.guid] = channelCache
                                self.channels[channelCache.guid] = channelCache
                            }
                        }
                    }
                }
            } catch {
                DPAGLog(error)
            }
        }
        self.fetchedResultsControllerChannels.delegate = self
    }

//    public func allContactsLocal(entryType: DPAGContact.EntryTypeLocal, filter: ((DPAGContact) -> Bool)?) -> Set<DPAGContact>
//    {
//        var retVal: Set<DPAGContact> = Set()
//
//        self.queueObjects.sync { in
//
//            retVal = Set(self.contacts.values.filter { (contact) -> Bool in
//                contact.entryTypeLocal == entryType && contact.isDeleted == false && (filter?(contact) ?? true)
//            })
//        }
//        return retVal
//    }
//
//    public func allContactsServer(entryType: DPAGContact.EntryTypeServer, filter: ((DPAGContact) -> Bool)?) -> Set<DPAGContact>
//    {
//        var retVal: Set<DPAGContact> = Set()
//
//        self.queueObjects.sync { in
//
//            retVal = Set(self.contacts.values.filter { (contact) -> Bool in
//                contact.entryTypeServer == entryType && contact.isDeleted == false && (contact.entryTypeServer != .privat || contact.entryTypeLocal != .hidden) && (filter?(contact) ?? true)
//            })
//        }
//        return retVal
//    }
//
//    public func allContacts() -> [DPAGContact]
//    {
//        return Array(self.contacts.values)
//    }

    public func allGroups() -> [DPAGGroup] {
        Array(self.groups.values)
    }

    public func allChannels() -> [DPAGChannel] {
        Array(self.channels.values)
    }

    func getDecryptedDict(_ key: String) -> [String: Any]? {
        var retVal: [String: Any]?

        self.queueAttrDict.sync {
            retVal = self.cacheDecryptedDict[key]
        }

        return retVal
    }

    func setDecryptedDict(_ key: String, dict: [String: Any]) {
        self.queueAttrDict.async(flags: .barrier) {
            self.cacheDecryptedDict[key] = dict
        }
    }

    public func decryptedMessageFast(messageGuid: String) -> DPAGDecryptedMessage? {
        var decMessage: DPAGDecryptedMessage?

        self.queueMessages.sync {
            decMessage = self.decryptedMessagesDict[messageGuid]
        }

        return decMessage
    }

    public func decryptedMessage(messageGuid: String) -> DPAGDecryptedMessage? {
        var decMessage: DPAGDecryptedMessage?

        self.queueMessages.sync {
            decMessage = self.decryptedMessagesDict[messageGuid]
        }

        if decMessage != nil {
            return decMessage
        }

        DPAGApplicationFacade.persistance.loadWithBlock { localContext in

            if let message = SIMSMessage.findFirst(byGuid: messageGuid, in: localContext) {
                decMessage = DPAGApplicationFacade.cache.decryptedMessage(message, in: localContext)
            } else if let message = SIMSMessageToSend.findFirst(byGuid: messageGuid, in: localContext) {
                decMessage = DPAGApplicationFacade.cache.decryptedMessage(message, in: localContext)
            }
        }

        return decMessage
    }

    @discardableResult
    func decryptedMessage(_ messageIn: SIMSManagedObjectMessage?, in localContext: NSManagedObjectContext) -> DPAGDecryptedMessage? {
        guard let message = messageIn, let messageGuid = message.guid else {
            return nil
        }

        if (message as? SIMSMessage)?.data == nil, (message as? SIMSMessageToSend)?.data == nil {
            return nil
        }

        var decMessage: DPAGDecryptedMessage?

        self.queueMessages.sync {
            decMessage = self.decryptedMessagesDict[messageGuid]
        }

        if decMessage?.messageGuid == messageGuid {
            return decMessage
        }

        if message is SIMSMessage {
            decMessage = self.createDecryptedMessage(message: message as? SIMSMessage, in: localContext)
        } else if message is SIMSMessageToSend {
            decMessage = self.createDecryptedMessage(messageToSend: message as? SIMSMessageToSend, in: localContext)
        }

        return decMessage
    }

    func decryptedMessage(messageGuid: String, in _: NSManagedObjectContext?) -> DPAGDecryptedMessage? {
        var decMessage: DPAGDecryptedMessage?

        self.queueMessages.sync {
            decMessage = self.decryptedMessagesDict[messageGuid]
        }

        return decMessage
    }

    public func checkNotCheckedMessages() {
        do {
            try DPAGApplicationFacade.persistance.saveWithError { localContext in

                guard let account = SIMSAccount.mr_findFirst(in: localContext), let ownGuid = account.guid else {
                    return
                }

                let predicate: NSPredicate = NSCompoundPredicate(andPredicateWithSubpredicates:
                    [
                        NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.errorType), rightExpression: NSExpression(forConstantValue: DPAGMessageSecurityError.notChecked.rawValue)),
                        NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.fromAccountGuid), rightExpression: NSExpression(forConstantValue: ownGuid), modifier: .direct, type: .notEqualTo, options: []),
                        NSCompoundPredicate(orPredicateWithSubpredicates:
                            [
                                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.stream?.streamType), rightExpression: NSExpression(forConstantValue: DPAGStreamType.single.rawValue)),
                                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.stream?.streamType), rightExpression: NSExpression(forConstantValue: DPAGStreamType.group.rawValue))
                            ])
                    ])

                let allMessagesNotChecked = try SIMSMessage.findAll(in: localContext, with: predicate, relationshipKeyPathsForPrefetching: ["attributes"])

                for msg in allMessagesNotChecked {
                    guard let msgGuid = msg.guid else { continue }

                    DPAGLog("checkMessage: %@", msgGuid)

                    self.checkNotCheckedMessage(message: msg, account: account, forceCheck: false, in: localContext)

                    if let decMessage = DPAGApplicationFacade.cache.decryptedMessage(msg, in: localContext) {
                        decMessage.errorType = DPAGMessageSecurityError(rawValue: msg.errorType?.intValue ?? DPAGMessageSecurityError.notChecked.rawValue) ?? DPAGMessageSecurityError.notChecked

                        if msg.errorType?.intValue == DPAGMessageSecurityError.none.rawValue {
                            decMessage.attachmentHash = DPAGApplicationFacade.messageCryptoWorker.decryptString(msg.attachmentHash256 ?? msg.attachmentHash, withKey: account.keyRelationship)
                            decMessage.decryptedAttachment?.attachmentHash = decMessage.attachmentHash
                        }
                    }
                }
            }
        } catch {
            DPAGLog(error)
        }
    }

    func addTempDeviceInfo(guid: String, tempDevice: DPAGTempDeviceInfo) {
        self.cachedTempDeviceInfo[guid] = tempDevice
    }

    func getTempDeviceInfo(guid: String) -> DPAGTempDeviceInfo? {
        self.cachedTempDeviceInfo[guid]
    }

    public func checkInvalidMessages() {
        do {
            try DPAGApplicationFacade.persistance.saveWithError { localContext in

                guard let account = SIMSAccount.mr_findFirst(in: localContext), let ownGuid = account.guid else {
                    return
                }

                let predicate: NSPredicate = NSCompoundPredicate(andPredicateWithSubpredicates:
                    [
                        NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.errorType), rightExpression: NSExpression(forConstantValue: DPAGMessageSecurityError.signatureInvalid.rawValue)),
                        NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.fromAccountGuid), rightExpression: NSExpression(forConstantValue: ownGuid), modifier: .direct, type: .notEqualTo, options: []),
                        NSCompoundPredicate(orPredicateWithSubpredicates:
                            [
                                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.stream?.streamType), rightExpression: NSExpression(forConstantValue: DPAGStreamType.single.rawValue)),
                                NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.stream?.streamType), rightExpression: NSExpression(forConstantValue: DPAGStreamType.group.rawValue))
                            ])
                    ])

                let allMessagesNotChecked = try SIMSMessage.findAll(in: localContext, with: predicate)

                for msg in allMessagesNotChecked {
                    guard let msgGuid = msg.guid else { continue }

                    DPAGLog("checkMessage: %@", msgGuid)

                    self.checkNotCheckedMessage(message: msg, account: account, forceCheck: true, in: localContext)

                    if let decMessage = DPAGApplicationFacade.cache.decryptedMessage(msg, in: localContext) {
                        decMessage.errorType = DPAGMessageSecurityError(rawValue: msg.errorType?.intValue ?? DPAGMessageSecurityError.notChecked.rawValue) ?? DPAGMessageSecurityError.notChecked

                        if msg.errorType?.intValue == DPAGMessageSecurityError.none.rawValue {
                            decMessage.attachmentHash = DPAGApplicationFacade.messageCryptoWorker.decryptString(msg.attachmentHash256 ?? msg.attachmentHash, withKey: account.keyRelationship)
                            decMessage.decryptedAttachment?.attachmentHash = decMessage.attachmentHash
                        }
                    }
                }
            }
        } catch {
            DPAGLog(error)
        }
    }

    private func checkChecksum(data: String, dataSHA: String, isSHA256: Bool, hashesString: String) -> (Bool, String) {
        var hashesString = hashesString

        let bytesValid = (isSHA256 ? data.sha256() : data.sha1()) == dataSHA
        hashesString.append(dataSHA)
        return (bytesValid, hashesString)
    }

    private func checkNotCheckedMessage(message msg: SIMSMessage, account: SIMSAccount, forceCheck: Bool, in _: NSManagedObjectContext) {
        if msg is SIMSChannelMessage {
            return
        }
        if !forceCheck {
            if (msg.errorType?.intValue ?? DPAGMessageSecurityError.none.rawValue) != DPAGMessageSecurityError.notChecked.rawValue {
                return
            }
        }

        let accountGuid = msg.fromAccountGuid ?? "???"

        let contactObj = DPAGApplicationFacade.cache.contact(for: accountGuid)

        guard let key = account.keyRelationship, let contact = contactObj, (contact.publicKey?.isEmpty ?? true) == false else {
            if contactObj?.isDeleted ?? false {
                msg.errorType = NSNumber(value: DPAGMessageSecurityError.none.rawValue)
                DPAGApplicationFacade.cache.removeMessage(guid: msg.guid)
            }
            return
        }

        if let message = msg as? SIMSGroupMessage {
            let signatureData1 = message.dataSignature?.data(using: .utf8)
            let signatureData256 = message.getAdditionalData(key: "dataSignature256")?.data(using: .utf8) ?? message.dataSignature256?.data(using: .utf8)
            let signatureDataTemp256 = message.getAdditionalData(key: "dataSignatureTemp256")?.data(using: .utf8)
            let isSHA256 = signatureData256 != nil

            var hashesString: String = ""
            var bytesValid = true
            var signatureObj: DPAGMessageSignatureGroup?

            if let signatureData = signatureDataTemp256 ?? signatureData256 ?? signatureData1 {
                do {
                    signatureObj = try JSONDecoder().decode(DPAGMessageSignatureGroup.self, from: signatureData)
                } catch {
                    DPAGLog(error, message: "checkNotCheckedMessage-error")
                }
            } else {
                bytesValid = false
            }

            var fromTempDeviceGuidValue: String?

            if let signature = signatureObj {
                //            let fromGuidSHAKey = String(format: "from/%@", accountGuid)
                //            let fromTempDeviceGuid = String(format: "from/%@/tempDevice/guid", accountGuid)
                //            let fromTempDeviceKey = String(format: "from/%@/tempDevice/key", accountGuid)
                //            let toGuidSHAKey = String(format: "to/%@", message.toGroupGuid)
                //            let keys = [SIMS_DATA, fromGuidSHAKey, fromTempDeviceGuid, fromTempDeviceKey, toGuidSHAKey]
                //
                fromTempDeviceGuidValue = message.getAdditionalData(key: "fromAccountTempDeviceGuid")
                let fromTempDeviceKeyValue = message.getAdditionalData(key: "fromAccountTempDeviceAesKey")

                let hashes = [signature.hashes.data, signature.hashes.fromHash, signature.hashes.fromTempDeviceGuid, signature.hashes.fromTempDeviceKeyHash, signature.hashes.toHash]
                let values = [message.data, message.fromAccountGuid, fromTempDeviceGuidValue, fromTempDeviceKeyValue, message.toGroupGuid]

                let required = [true, true, false, false, true]

                for i in 0 ..< min(hashes.count, values.count, required.count) {
                    if let dataSHA = hashes[i], let data = values[i], bytesValid {
                        (bytesValid, hashesString) = self.checkChecksum(data: data, dataSHA: dataSHA, isSHA256: isSHA256, hashesString: hashesString)
                    } else if required[i] {
                        bytesValid = false
                        break
                    }
                }

                if let attachmentSHA = signature.hashes.attachmentHash {
                    hashesString.append(attachmentSHA)

                    do {
                        if isSHA256 {
                            message.attachmentHash256 = try CryptoHelper.sharedInstance?.encrypt(string: attachmentSHA, with: key)
                        } else {
                            message.attachmentHash = try CryptoHelper.sharedInstance?.encrypt(string: attachmentSHA, with: key)
                        }
                    } catch {
                        DPAGLog(error)
                    }
                }

                if isSHA256 {
                    message.dataSignature256 = signature.signature
                    message.hashes256 = String(format: "%@", hashesString)
                } else {
                    message.dataSignature = signature.signature
                    message.hashes = String(format: "%@", hashesString)
                }
            } else {
                bytesValid = false
            }

            if bytesValid, let signature = signatureObj {
                if signatureDataTemp256 != nil, let signatureTempDevice = signature.signatureTempDevice, let accountPublicKey = contact.publicKey, let messageHashes = message.hashes256, let fromTempDeviceGuidValue = fromTempDeviceGuidValue, let messageDateSend = message.dateSendServer {
                    // Wechsel des Threads um die Ausführung aufzuqueuen ...
                    self.performBlockOnMainThread {
                        self.performBlockInBackground {
                            do {
                                let isValid = try DPAGApplicationFacade.couplingWorker.checkTempSignature(accountGuid: accountGuid, accountPublicKey: accountPublicKey, deviceGuid: fromTempDeviceGuidValue, signatureHashes: messageHashes, signatureTempDevice: signatureTempDevice, dateSendServer: messageDateSend)

                                DPAGApplicationFacade.persistance.saveWithBlock { localContextSave in

                                    if let messageSave = message.mr_(in: localContextSave) {
                                        if !isValid {
                                            DPAGLog("message signature is invalid")
                                            messageSave.errorType = NSNumber(value: DPAGMessageSecurityError.signatureInvalid.rawValue)
                                            DPAGLog("checkMessageInv: %@", messageSave.guid ?? "none")
                                        } else {
                                            messageSave.errorType = NSNumber(value: DPAGMessageSecurityError.none.rawValue)
                                            DPAGLog("checkMessageNone: %@", messageSave.guid ?? "none")
                                        }
                                    }
                                }
                            } catch {
                                DPAGLog(error)
                            }
                        }
                    }
                    return
                } else {
                    do {
                        // check signature
                        let isValid = (isSHA256 ? try CryptoHelperVerifier.verifyData256(data: message.hashes256, withSignature: message.dataSignature256, forPublicKey: contact.publicKey) : try CryptoHelperVerifier.verifyData(data: message.hashes, withSignature: message.dataSignature, forPublicKey: contact.publicKey))

                        if !isValid {
                            DPAGLog("message signature is invalid")
                            message.errorType = NSNumber(value: DPAGMessageSecurityError.signatureInvalid.rawValue)
                        } else {
                            message.errorType = NSNumber(value: DPAGMessageSecurityError.none.rawValue)
                        }
                    } catch {
                        DPAGLog(error)
                    }
                }
            } else {
                message.errorType = NSNumber(value: DPAGMessageSecurityError.hashesInvalid.rawValue)
            }
        } else if let message = msg as? SIMSPrivateMessage {
            let signatureData1 = message.dataSignature?.data(using: .utf8)
            let signatureData256 = message.getAdditionalData(key: "dataSignature256")?.data(using: .utf8) ?? message.dataSignature256?.data(using: .utf8)
            let signatureDataTemp256 = message.getAdditionalData(key: "dataSignatureTemp256")?.data(using: .utf8)
            let isSHA256 = signatureData256 != nil

            guard let signatureData = signatureDataTemp256 ?? signatureData256 ?? signatureData1 else {
                return
            }

            var hashesString: String = ""
            var bytesValid = true

            var signatureObj: DPAGMessageSignaturePrivate?

            do {
                signatureObj = try JSONDecoder().decode(DPAGMessageSignaturePrivate.self, from: signatureData)
            } catch {
                DPAGLog(error, message: "checkNotCheckedMessage-error")
            }

            guard let signature = signatureObj else {
                return
            }

//            let fromGuidSHAKey = String(format: "from/%@", accountGuid)
//            let fromSHAKey = String(format: "from/%@/key", accountGuid)
//            let fromTempDeviceGuid = String(format: "from/%@/tempDevice/guid", accountGuid)
//            let fromTempDeviceKey = String(format: "from/%@/tempDevice/key", accountGuid)
//            let toGuidSHAKey = String(format: "to/%@", message.toAccountGuid)
//            let toSHAKey = String(format: "to/%@/key", message.toAccountGuid)
//            let toTempDeviceGuid = String(format: "to/%@/tempDevice/guid", message.toAccountGuid)
//            let toTempDeviceKey = String(format: "to/%@/tempDevice/key", message.toAccountGuid)
//            let keys = [SIMS_DATA, fromGuidSHAKey, fromSHAKey, fromTempDeviceGuid, fromTempDeviceKey, toGuidSHAKey, toSHAKey, toTempDeviceGuid, toTempDeviceKey]

            let fromTempDeviceGuidValue = message.getAdditionalData(key: "fromAccountTempDeviceGuid")
            let fromTempDeviceKeyValue = message.getAdditionalData(key: "fromAccountTempDeviceAesKey")
            let toTempDeviceGuidValue = message.getAdditionalData(key: "toAccountTempDeviceGuid")
            let toTempDeviceKeyValue = message.getAdditionalData(key: "toAccountTempDeviceAesKey")

            let values = [message.data, message.fromAccountGuid, message.fromKey, fromTempDeviceGuidValue, fromTempDeviceKeyValue, message.toAccountGuid, message.toKey, toTempDeviceGuidValue, toTempDeviceKeyValue]
            let hashes = [signature.hashes.data, signature.hashes.fromHash, signature.hashes.fromKeyHash, signature.hashes.fromTempDeviceGuid, signature.hashes.fromTempDeviceKeyHash, signature.hashes.toHash, signature.hashes.toKeyHash, signature.hashes.toTempDeviceGuid, signature.hashes.toTempDeviceKeyHash]

            let required = [true, true, true, false, false, true, true, false, false]

            for i in 0 ..< min(hashes.count, required.count) {
                if let dataSHA = hashes[i], let data = values[i], bytesValid {
                    (bytesValid, hashesString) = self.checkChecksum(data: data, dataSHA: dataSHA, isSHA256: isSHA256, hashesString: hashesString)
                } else if required[i] {
                    bytesValid = false
                }
            }

            if let attachmentSHA = signature.hashes.attachmentHash {
                hashesString.append(attachmentSHA)

                do {
                    if isSHA256 {
                        message.attachmentHash256 = try CryptoHelper.sharedInstance?.encrypt(string: attachmentSHA, with: key)
                    } else {
                        message.attachmentHash = try CryptoHelper.sharedInstance?.encrypt(string: attachmentSHA, with: key)
                    }
                } catch {
                    DPAGLog(error)
                }
            }

            if isSHA256 {
                message.dataSignature256 = signature.signature
                message.hashes256 = String(format: "%@", hashesString)
            } else {
                message.dataSignature = signature.signature
                message.hashes = String(format: "%@", hashesString)
            }

            if !bytesValid {
                message.errorType = NSNumber(value: DPAGMessageSecurityError.hashesInvalid.rawValue)
                DPAGLog("checkMessageHashInv: %@", message.guid ?? "none")
            } else {
                do {
                    var isValid = false

                    if signatureDataTemp256 != nil, let signatureTempDevice = signature.signatureTempDevice, let accountPublicKey = contact.publicKey, let messageHashes = message.hashes256, let fromTempDeviceGuidValue = fromTempDeviceGuidValue, let messageDateSend = message.dateSendServer {
                        // Wechsel des Threads um die Ausführung aufzuqueuen ...
                        self.performBlockOnMainThread {
                            self.performBlockInBackground {
                                do {
                                    let isValid = try DPAGApplicationFacade.couplingWorker.checkTempSignature(accountGuid: accountGuid, accountPublicKey: accountPublicKey, deviceGuid: fromTempDeviceGuidValue, signatureHashes: messageHashes, signatureTempDevice: signatureTempDevice, dateSendServer: messageDateSend)

                                    DPAGApplicationFacade.persistance.saveWithBlock { localContextSave in

                                        if let messageSave = message.mr_(in: localContextSave) {
                                            if !isValid {
                                                DPAGLog("message signature is invalid")
                                                messageSave.errorType = NSNumber(value: DPAGMessageSecurityError.signatureInvalid.rawValue)
                                                DPAGLog("checkMessageInv: %@", messageSave.guid ?? "none")
                                            } else {
                                                messageSave.errorType = NSNumber(value: DPAGMessageSecurityError.none.rawValue as Int)
                                                DPAGLog("checkMessageNone: %@", messageSave.guid ?? "none")
                                            }
                                        }
                                    }
                                } catch {
                                    DPAGLog(error)
                                }
                            }
                        }
                        return
                    } else {
                        // check signature
                        isValid = (isSHA256 ? try CryptoHelperVerifier.verifyData256(data: message.hashes256, withSignature: message.dataSignature256, forPublicKey: contact.publicKey) : try CryptoHelperVerifier.verifyData(data: message.hashes, withSignature: message.dataSignature, forPublicKey: contact.publicKey ?? ""))
                    }

                    if !isValid {
                        DPAGLog("message signature is invalid")
                        message.errorType = NSNumber(value: DPAGMessageSecurityError.signatureInvalid.rawValue)
                        DPAGLog("checkMessageInv: %@", message.guid ?? "none")
                    } else {
                        message.errorType = NSNumber(value: DPAGMessageSecurityError.none.rawValue)
                        DPAGLog("checkMessageNone: %@", message.guid ?? "none")
                    }
                } catch {
                    DPAGLog(error)
                }
            }
        }
    }

    private func processPrivateGroupMessage(decMessagePart: DPAGDecryptedMessage, decryptedDictionary: DPAGMessageDictionary) -> DPAGDecryptedMessage {
        let decMessage = decMessagePart

        decMessage.nickName = decryptedDictionary.nick
        decMessage.phone = decryptedDictionary.phone
        decMessage.profilKey = decryptedDictionary.profilKey
        var contentWithLinks: String?
        if decMessage.contentType == .plain {
            contentWithLinks = decMessage.content
        } else if decMessage.contentType == .avCallInvitation {
            contentWithLinks = "📞"
        } else if decMessage.contentType == .controlMsgNG {
            contentWithLinks = ""
        } else if decMessage.contentType == .oooStatusMessage {
            contentWithLinks = decMessage.content
        } else if decMessage.contentType == .textRSS {
            contentWithLinks = decMessage.content
            if let rssString = decryptedDictionary.unknownContent[SIMS_DATA] as? String {
                contentWithLinks = rssString
                if let rssData = rssString.data(using: .utf8), let jsonRSS = try? JSONSerialization.jsonObject(with: rssData), let dictRSS = jsonRSS as? [AnyHashable: Any] {
                    if let text = dictRSS["text"] as? String {
                        var content = text
                        var contentWithLink = text
                        if let title = dictRSS["title"] as? String {
                            content = title + "\n" + content
                            contentWithLink = content
                            decMessage.rangeLineBreak = NSRange(location: (title as NSString).length, length: 1)
                        }
                        if let link = dictRSS["link"] as? String, let linkURL = URL(string: link) {
                            let linkReplacer = DPAGLocalizedString("chat.group.rss_channel.link_replacer.more")
                            content += " "
                            contentWithLink = content
                            decMessage.rangesWithLink = [NSTextCheckingResult.linkCheckingResult(range: NSRange(location: (content as NSString).length, length: (linkReplacer as NSString).length), url: linkURL)]
                            content += linkReplacer
                            contentWithLink += link
                        }
                        decMessage.content = contentWithLink
                        decMessage.attributedText = content
                        return decMessage
                    }
                }
            }
        } else if decMessage.contentType == .image || decMessage.contentType == .video {
            contentWithLinks = decMessage.contentDesc
        }
        if let contentWithLinks = contentWithLinks {
            if let dataDetector = DPAGCache.dataDetector {
                decMessage.rangesWithLink = dataDetector.matches(in: contentWithLinks, options: [], range: NSRange(location: 0, length: (contentWithLinks as NSString).length))
            }
            decMessage.attributedText = contentWithLinks
        }
        return decMessage
    }
    
    private func processPrivateMessage(message: SIMSMessage, decMessagePart: DPAGDecryptedMessage, decryptedDictionary: DPAGMessageDictionary, in localContext: NSManagedObjectContext) -> DPAGDecryptedMessage {
        let decMessage = decMessagePart
        let isOwnMessage = message.isOwnMessage
        let content = self.getContentIfValid(decryptedDictionary: decryptedDictionary, errorType: decMessage.errorType)
        if let privateMessage = message as? SIMSPrivateMessage, let decMessagePrivate = decMessage as? DPAGDecryptedMessagePrivate, let contactDB = (privateMessage.stream as? SIMSStream)?.contactIndexEntry, let contactGuid = isOwnMessage ? self.account?.guid ?? "" : contactDB.guid, let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
            decMessage.encAesKey = isOwnMessage ? privateMessage.fromKey : privateMessage.toKey
            decMessagePrivate.contactGuid = contactGuid
            if contact.guid.isSystemChatGuid == false, message.fromAccountGuid?.isSystemChatGuid ?? false {
                decMessage.isSystemGenerated = true
                decMessage.contentParsed = DPAGApplicationFacade.cache.parseSystemMessageContentAttributed(content, withAttributes: [:], in: localContext)
            }
            if contact.guid.isSystemChatGuid == false {
                if contact.isDeleted {
                    decMessage.confidenceState = .none
                } else {
                    decMessage.confidenceState = contact.confidence
                }
                decMessagePrivate.isSystemChat = false
                let nickLetters = contact.lettersForPlaceholder
                let textColorNick = DPAGHelperEx.color(forPlaceholderLetters: nickLetters)
                decMessagePrivate.textColorNick = textColorNick
                decMessagePrivate.contactName = contact.displayName
            } else {
                decMessagePrivate.isSystemChat = true
                decMessage.confidenceState = .high
            }
        }
        return decMessage
    }
    
    private func processGroupMessage(message: SIMSMessage, decMessagePart: DPAGDecryptedMessage, decryptedDictionary: DPAGMessageDictionary, in localContext: NSManagedObjectContext) -> DPAGDecryptedMessage {
        let decMessage = decMessagePart
        let isOwnMessage = message.isOwnMessage
        let content = self.getContentIfValid(decryptedDictionary: decryptedDictionary, errorType: decMessage.errorType)
        if let groupMessage = message as? SIMSGroupMessage, let decMessageGroup = decMessage as? DPAGDecryptedMessageGroup {
            decMessage.encAesKey = (groupMessage.stream as? SIMSGroupStream)?.groupAesKey
            if message.fromAccountGuid?.isSystemChatGuid ?? false {
                decMessage.isSystemGenerated = true
                decMessage.contentParsed = DPAGApplicationFacade.cache.parseSystemMessageContentAttributed(content, withAttributes: [:], in: localContext)
            }
            decMessage.confidenceState = (groupMessage.stream as? SIMSGroupStream)?.group?.confidenceState ?? .low
            if let contact = DPAGApplicationFacade.cache.contact(for: message.fromAccountGuid ?? "???") {
                if isOwnMessage == false {
                    let nickLetters = contact.lettersForPlaceholder
                    let textColorNick = DPAGHelperEx.color(forPlaceholderLetters: nickLetters)
                    decMessageGroup.textColorNick = textColorNick
                    decMessageGroup.contactName = contact.displayName
                    decMessageGroup.contactGuid = message.fromAccountGuid
                    decMessageGroup.contactReadOnly = contact.isReadOnly
                    if contact.isDeleted {
                        decMessage.confidenceState = .none
                    } else {
                        decMessage.confidenceState = contact.confidence
                    }
                } else {
                    decMessageGroup.contactGuid = contact.guid
                    decMessageGroup.contactName = contact.nickName
                }
            }
            decMessageGroup.groupType = (groupMessage.stream as? SIMSGroupStream)?.group?.typeGroup ?? DPAGGroupType.default
        }
        return decMessage
    }
    
    private func processChannelMessage(message: SIMSMessage, decMessagePart: DPAGDecryptedMessage, decryptedDictionary: DPAGMessageDictionary, in localContext: NSManagedObjectContext) -> DPAGDecryptedMessage {
        let decMessage = decMessagePart
        let content = self.getContentIfValid(decryptedDictionary: decryptedDictionary, errorType: decMessage.errorType)
        if let channelMessage = message as? SIMSChannelMessage, let decMessageChannel = decMessage as? DPAGDecryptedMessageChannel {
            if message.fromAccountGuid?.isSystemChatGuid ?? false {
                decMessage.isSystemGenerated = true
                decMessage.contentParsed = DPAGApplicationFacade.cache.parseSystemMessageContentAttributed(content, withAttributes: [:], in: localContext)
            }
            decMessageChannel.section = decryptedDictionary.channelSection
            decMessage.confidenceState = .high
            if let channel = (channelMessage.stream as? SIMSChannelStream)?.channel {
                decMessage.encAesKey = channel.aes_key
                decMessage.encIv = channel.iv
                decMessageChannel.feedType = channel.validFeedType
                decMessageChannel.channelGuid = channel.guid ?? "-"
                decMessageChannel.colorChatMessageSectionPre = channel.colorChatMessageSectionPre
                decMessageChannel.colorChatMessageSection = channel.colorChatMessageSection
                decMessageChannel.contentLinkReplacer = channel.contentLinkReplacer
                decMessage.attributedText = ""
                if let content = decMessage.content, decMessageChannel.feedType == .channel {
                    if let contentChannel = (DPAGApplicationFacade.feedWorker as? DPAGFeedWorkerProtocolSwift)?.replaceChannelLink(content, contentLinkReplacer: decMessageChannel.contentLinkReplacer) {
                        decMessageChannel.rangeLineBreak = (contentChannel.content as NSString).rangeOfCharacter(from: .newlines)
                        if let dataDetector = DPAGCache.dataDetector {
                            var results = dataDetector.matches(in: contentChannel.content, options: [], range: NSRange(location: 0, length: (contentChannel.content as NSString).length))
                            if let urlContentLink = contentChannel.urlContentLink, let rangeLink = contentChannel.rangeLink, rangeLink.location > 0 {
                                results.append(NSTextCheckingResult.linkCheckingResult(range: rangeLink, url: urlContentLink))
                            }
                            decMessage.rangesWithLink = results
                        }
                        decMessage.attributedText = contentChannel.content
                    }
                }
            }
        }
        return decMessage
    }
    
    private func createDecryptedMessage(message messageIn: SIMSMessage?, in localContext: NSManagedObjectContext) -> DPAGDecryptedMessage? {
        guard let message = messageIn, let messageGuid = message.guid else { return nil }
        let isOwnMessage = message.isOwnMessage
        guard let decryptedDictionary = message.decryptedMessageDictionary() else { return nil }
        let type = decryptedDictionary.contentType
        var decMessage: DPAGDecryptedMessage
        
        switch message.typeMessage {
            case .channel:
                decMessage = DPAGDecryptedMessageChannel(messageGuid: messageGuid, contentType: type)
            case .group:
                decMessage = DPAGDecryptedMessageGroup(messageGuid: messageGuid, contentType: type)
            case .private:
                decMessage = DPAGDecryptedMessagePrivate(messageGuid: messageGuid, contentType: type)
            case .unknown:
//                DPAGLog("createDecryptedMessage for unknown type", level: .error)
                return nil
        }
        decMessage.isOwnMessage = isOwnMessage
        decMessage.fromAccountGuid = message.fromAccountGuid ?? "???"
        decMessage.streamGuid = message.stream?.guid
        decMessage.messageType = message.typeMessage
        decMessage.sendingState = message.sendingStateValid
        decMessage.isReadLocal = message.attributes?.dateReadLocal != nil
        decMessage.isReadServer = message.dateReadServer != nil || message.attributes?.dateReadServer != nil
        decMessage.isReadServerAttachment = message.attributes?.dateReadServer != nil
        decMessage.isDownloaded = message.dateDownloaded != nil || message.attributes?.dateDownloaded != nil
        decMessage.isDownloadedAttachment = decMessage.isDownloaded
        decMessage.dateReadServer = message.dateReadServer ?? message.attributes?.dateReadServer
        decMessage.dateReadLocal = message.attributes?.dateReadLocal
        decMessage.dateDownloaded = message.dateDownloaded ?? message.attributes?.dateDownloaded
        decMessage.citationContent = decryptedDictionary.citationContent
        if (message.receiver?.count ?? 0) != 0 {
            decMessage.update(withRecipients: message.receiver ?? Set())
        }
        decMessage.errorType = DPAGMessageSecurityError(rawValue: message.errorType?.intValue ?? DPAGMessageSecurityError.notChecked.rawValue) ?? .notChecked
        decMessage.isHighPriorityMessage = message.optionsMessage.contains(.priorityHigh)
        let content = self.getContentIfValid(decryptedDictionary: decryptedDictionary, errorType: decMessage.errorType)
        decMessage.content = content
        decMessage.contentDesc = decryptedDictionary.contentDescription
        decMessage.additionalData = decryptedDictionary.additionalData
        decMessage.vcardAccountID = decryptedDictionary.vcardAccountID
        decMessage.vcardAccountGuid = decryptedDictionary.vcardAccountGuid
        
        switch message.typeMessage {
            case .group, .private:
                decMessage = processPrivateGroupMessage(decMessagePart: decMessage, decryptedDictionary: decryptedDictionary)
            case .channel, .unknown:
                break
        }
        decMessage.imagePreview = decryptedDictionary.imagePreviewData
        decMessage.isSent = isOwnMessage && message.sendingState.uintValue == DPAGMessageState.sentSucceeded.rawValue
        switch message.typeMessage {
            case .private:
                decMessage = processPrivateMessage(message: message, decMessagePart: decMessage, decryptedDictionary: decryptedDictionary, in: localContext)
            case .group:
                decMessage = processGroupMessage(message: message, decMessagePart: decMessage, decryptedDictionary: decryptedDictionary, in: localContext)
            case .channel:
                decMessage = processChannelMessage(message: message, decMessagePart: decMessage, decryptedDictionary: decryptedDictionary, in: localContext)
            case .unknown:
                break
        }
        decMessage.attachmentGuid = message.attachment
        decMessage.decryptedAttachment = decMessage.decryptedAttachment(in: message.stream)
        if decMessage.attachmentGuid != nil {
            if message.typeMessage == .channel {
                if message.attachmentHash != nil || message.attachmentHash256 != nil {
                    if let channel = (message.stream as? SIMSChannelStream)?.channel, let iv = channel.iv, let decAesKey = channel.aes_key {
                        do {
                            let aesKeyDict = ["key": decAesKey, "iv": iv]
                            decMessage.attachmentHash = try CryptoHelperDecrypter.decryptToString(encryptedString: message.attachmentHash256 ?? message.attachmentHash ?? "", withAesKeyDict: aesKeyDict)
                            decMessage.decryptedAttachment?.attachmentHash = decMessage.attachmentHash
                        } catch {
                            DPAGLog(error)
                        }
                    }
                }
            } else if message.errorType?.intValue == DPAGMessageSecurityError.notChecked.rawValue {
                DPAGApplicationFacade.persistance.saveWithBlock { localContextSave in
                    if let account = SIMSAccount.mr_findFirst(in: localContextSave), let messageSave = message.mr_(in: localContextSave) {
                        DPAGApplicationFacade.cache.checkNotCheckedMessage(message: messageSave, account: account, forceCheck: false, in: localContextSave)
                        decMessage.errorType = DPAGMessageSecurityError(rawValue: messageSave.errorType?.intValue ?? DPAGMessageSecurityError.notChecked.rawValue) ?? DPAGMessageSecurityError.notChecked
                        if messageSave.errorType?.intValue == DPAGMessageSecurityError.none.rawValue {
                            decMessage.attachmentHash = DPAGApplicationFacade.messageCryptoWorker.decryptString(messageSave.attachmentHash256 ?? messageSave.attachmentHash, withKey: account.keyRelationship)
                            decMessage.decryptedAttachment?.attachmentHash = decMessage.attachmentHash
                        }
                    }
                }
            } else if message.errorType?.intValue == DPAGMessageSecurityError.none.rawValue {
                decMessage.attachmentHash = DPAGApplicationFacade.messageCryptoWorker.decryptString(message.attachmentHash256 ?? message.attachmentHash, withKey: SIMSAccount.mr_findFirst(in: localContext)?.keyRelationship)
                decMessage.decryptedAttachment?.attachmentHash = decMessage.attachmentHash
            }
        }
        if let destructionDate = decryptedDictionary.destructionDate {
            let destructionConfiguration = DPAGSendMessageItemOptions(countDownSelfDestruction: nil, dateSelfDestruction: destructionDate, dateToBeSend: nil)
            decMessage.sendOptions = destructionConfiguration
        } else if let destructionCountdown = decryptedDictionary.destructionCountDown {
            let destructionConfiguration = DPAGSendMessageItemOptions(countDownSelfDestruction: TimeInterval(destructionCountdown), dateSelfDestruction: nil, dateToBeSend: nil)
            decMessage.sendOptions = destructionConfiguration
        }
        decMessage.dateSendLocal = message.dateSendLocal
        decMessage.dateSendServer = message.dateSendServer
        self.queueMessages.async(flags: .barrier) {
            self.decryptedMessagesDict[messageGuid] = decMessage
        }
        return decMessage
    }

    private func createDecryptedMessage(messageToSend messageIn: SIMSMessageToSend?, in localContext: NSManagedObjectContext) -> DPAGDecryptedMessage? {
        guard let message = messageIn, let messageGuid = message.guid else { return nil }
        let isGroupMessage = message.typeMessage == .group
        let isPrivateMessage = message.typeMessage == .private
        guard let decryptedDictionary = message.decryptedMessageDictionary(in: localContext) else { return nil }
        let type = decryptedDictionary.contentType
        let decMessage = (isPrivateMessage ? DPAGDecryptedMessagePrivate(messageGuid: messageGuid, contentType: type) : DPAGDecryptedMessageGroup(messageGuid: messageGuid, contentType: type))
        var contact: DPAGContact?

        decMessage.isOwnMessage = true
        decMessage.fromAccountGuid = DPAGApplicationFacade.cache.account?.guid ?? "unknown"
        decMessage.streamGuid = message.streamGuid
        decMessage.messageType = message.typeMessage
        decMessage.sendingState = message.sendingStateValid
        decMessage.errorType = .none
        decMessage.isHighPriorityMessage = message.optionsMessage.contains(.priorityHigh)
        let content = self.getContentIfValid(decryptedDictionary: decryptedDictionary, errorType: decMessage.errorType)
        decMessage.content = content
        decMessage.contentDesc = decryptedDictionary.contentDescription
        decMessage.additionalData = decryptedDictionary.additionalData
        if isPrivateMessage || isGroupMessage {
            decMessage.nickName = decryptedDictionary.nick
            decMessage.phone = decryptedDictionary.phone
            decMessage.profilKey = decryptedDictionary.profilKey
            var contentWithLinks: String?
            if decMessage.contentType == .plain {
                contentWithLinks = decMessage.content
            } else if decMessage.contentType == .image || decMessage.contentType == .video {
                contentWithLinks = decMessage.contentDesc
            }
            if let contentWithLinks = contentWithLinks {
                if let dataDetector = DPAGCache.dataDetector {
                    decMessage.rangesWithLink = dataDetector.matches(in: contentWithLinks, options: [], range: NSRange(location: 0, length: (contentWithLinks as NSString).length))
                }
                decMessage.attributedText = contentWithLinks
            }
        }
        decMessage.imagePreview = decryptedDictionary.imagePreviewData
        decMessage.isSent = message.sendingState.uintValue == DPAGMessageState.sentSucceeded.rawValue
        if let accountGuid = DPAGApplicationFacade.cache.account?.guid {
            contact = DPAGApplicationFacade.cache.contact(for: accountGuid)
        }
        if let privateMessage = message as? SIMSMessageToSendPrivate, let decMessagePrivate = decMessage as? DPAGDecryptedMessagePrivate, let stream = privateMessage.streamToSend(in: localContext) {
            decMessage.encAesKey = privateMessage.fromKey
            decMessage.confidenceState = stream.contactIndexEntry?.confidenceState ?? .low
            decMessagePrivate.isSystemChat = false
            decMessagePrivate.contactGuid = contact?.guid
            decMessagePrivate.contactName = contact?.nickName
        } else if let groupMessage = message as? SIMSMessageToSendGroup, let decMessageGroup = decMessage as? DPAGDecryptedMessageGroup, let stream = groupMessage.streamToSend(in: localContext) {
            decMessage.encAesKey = stream.groupAesKey
            decMessage.confidenceState = groupMessage.streamToSend(in: localContext)?.group?.confidenceState ?? .low
            decMessageGroup.contactGuid = contact?.guid
            decMessageGroup.contactName = contact?.nickName
        }
        decMessage.attachmentGuid = message.attachment
        decMessage.decryptedAttachment = decMessage.decryptedAttachment(in: SIMSMessageStream.findFirst(byGuid: message.streamGuid, in: localContext))
        if decMessage.attachmentGuid != nil {
            decMessage.attachmentHash = DPAGApplicationFacade.messageCryptoWorker.decryptString(message.attachmentHash256 ?? message.attachmentHash, withKey: SIMSAccount.mr_findFirst(in: localContext)?.keyRelationship)
            decMessage.decryptedAttachment?.attachmentHash = decMessage.attachmentHash
        }
        if let destructionDate = decryptedDictionary.destructionDate {
            let destructionConfiguration = DPAGSendMessageItemOptions(countDownSelfDestruction: nil, dateSelfDestruction: destructionDate, dateToBeSend: message.dateToSend)
            decMessage.sendOptions = destructionConfiguration
        } else if let destructionCountdown = decryptedDictionary.destructionCountDown {
            let destructionConfiguration = DPAGSendMessageItemOptions(countDownSelfDestruction: TimeInterval(destructionCountdown), dateSelfDestruction: nil, dateToBeSend: message.dateToSend)
            decMessage.sendOptions = destructionConfiguration
        } else {
            let destructionConfiguration = DPAGSendMessageItemOptions(countDownSelfDestruction: nil, dateSelfDestruction: nil, dateToBeSend: message.dateToSend)
            decMessage.sendOptions = destructionConfiguration
        }
        decMessage.dateSendLocal = message.dateToSend
        self.queueMessages.async(flags: .barrier) {
            self.decryptedMessagesDict[messageGuid] = decMessage
        }
        return decMessage
    }

    public func refreshDecryptedMessage(messageGuid: String) -> DPAGDecryptedMessage? {
        self.removeMessage(guid: messageGuid)
        var decryptedMessageNew: DPAGDecryptedMessage?
        DPAGApplicationFacade.persistance.loadWithBlock { localContext in
            if let message = SIMSMessage.findFirst(byGuid: messageGuid, in: localContext) {
                decryptedMessageNew = DPAGApplicationFacade.cache.decryptedMessage(message, in: localContext)
            } else if let message = SIMSMessageToSend.findFirst(byGuid: messageGuid, in: localContext) {
                decryptedMessageNew = DPAGApplicationFacade.cache.decryptedMessage(message, in: localContext)
            }
        }
        return decryptedMessageNew
    }

    public func refreshDecryptedStream(streamGuid: String) -> DPAGDecryptedStream? {
        self.removeStream(guid: streamGuid)
        return self.decryptedStream(streamGuid: streamGuid, in: nil)
    }

    public func rollbackChannel(channelGuid: String) {
        self.queueObjects.async(flags: .barrier) {
            self.objects.removeValue(forKey: channelGuid)
            self.channels.removeValue(forKey: channelGuid)
        }
        DPAGApplicationFacade.persistance.loadWithBlock { localContext in
            guard let feed = SIMSChannel.findFirst(byGuid: channelGuid, in: localContext) else { return }
            guard let channelCache = DPAGChannel(channel: feed) else { return }
            self.queueObjects.async(flags: .barrier) {
                self.objects[channelGuid] = channelCache
                self.channels[channelGuid] = channelCache
            }
        }
    }

    func getContentIfValid(decryptedDictionary: DPAGMessageDictionary, errorType: DPAGMessageSecurityError) -> String {
        switch errorType {
            case .hashesInvalid:
                return DPAGLocalizedString("chat.encryption.hashInvalid")
            case .signatureInvalid:
                return DPAGLocalizedString("chat.encryption.signatureIsInvalid")
            case .none, .notChecked, .pendingTempDeviceInfo:
                return decryptedDictionary.content ?? ""
        }
    }

    func decrypteStream(stream: SIMSMessageStream?) -> DPAGDecryptedStream? {
        guard let streamGuid = stream?.guid else { return nil }
        return self.decryptedStream(streamGuid: streamGuid)
    }

    public func decryptedStream(streamGuid: String) -> DPAGDecryptedStream? {
        var decStream: DPAGDecryptedStream?
        self.queueStreams.sync {
            decStream = self.decryptedStreamsDict[streamGuid]
        }
        return decStream
    }

    func decryptedStream(stream streamIn: SIMSMessageStream?, in localContext: NSManagedObjectContext) -> DPAGDecryptedStream? {
        guard let stream = streamIn, let streamGuid = stream.guid else { return nil }
        var decStream: DPAGDecryptedStream?
        self.queueStreams.sync {
            decStream = self.decryptedStreamsDict[streamGuid]
        }
        if decStream != nil {
            return decStream
        }
        decStream = self.createDecryptedStream(stream: stream, in: localContext)
        return decStream
    }

    public func decryptedStream(streamGuid: String, in localContext: NSManagedObjectContext?) -> DPAGDecryptedStream? {
        var decStream: DPAGDecryptedStream?

        self.queueStreams.sync {
            decStream = self.decryptedStreamsDict[streamGuid]
        }
        if decStream != nil {
            return decStream
        }
        if let localContext = localContext {
            decStream = self.createDecryptedStream(streamGuid: streamGuid, in: localContext)
        } else {
            DPAGApplicationFacade.persistance.loadWithBlock { localContext in
                decStream = self.createDecryptedStream(streamGuid: streamGuid, in: localContext)
            }
        }
        return decStream
    }

    func updateDecryptedStream(streamGuid: String) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            self.updateDecryptedStream(streamGuid: streamGuid, stream: nil, in: localContext)
        }
    }

    func updateDecryptedStream(streamGuid streamGuidIn: String?, stream: SIMSMessageStream?, in localContext: NSManagedObjectContext) {
        guard let streamGuid = streamGuidIn ?? stream?.guid else { return }
        var decStream: DPAGDecryptedStream?
        self.queueStreams.sync {
            decStream = self.decryptedStreamsDict[streamGuid]
        }
        if let decStream = decStream {
            if let stream = stream {
                self.updateDecryptedStream(streamDecrypted: decStream, stream: stream, in: localContext)
            } else if let stream = SIMSMessageStream.findFirst(byGuid: streamGuid, in: localContext) {
                self.updateDecryptedStream(streamDecrypted: decStream, stream: stream, in: localContext)
            }
        } else if let stream = stream {
            _ = self.createDecryptedStream(stream: stream, in: localContext)
        } else {
            _ = self.createDecryptedStream(streamGuid: streamGuid, in: localContext)
        }
    }

    fileprivate func createDecryptedStream(streamGuid: String, in localContext: NSManagedObjectContext) -> DPAGDecryptedStream? {
        self.createDecryptedStream(stream: SIMSMessageStream.findFirst(byGuid: streamGuid, in: localContext), in: localContext)
    }

    fileprivate func createDecryptedStream(stream streamIn: SIMSMessageStream?, in localContext: NSManagedObjectContext) -> DPAGDecryptedStream? {
        guard let stream = streamIn, let streamGuid = stream.guid else { return nil }
        let decStream: DPAGDecryptedStream
        switch stream.typeStream {
            case .channel:
                decStream = DPAGDecryptedStreamChannel(guid: streamGuid)
            case .group:
                decStream = DPAGDecryptedStreamGroup(guid: streamGuid)
            case .single:
                decStream = DPAGDecryptedStreamPrivate(guid: streamGuid)
            case .unknown:
                return nil
        }
        decStream.type = stream.typeStream
        self.updateDecryptedStream(streamDecrypted: decStream, stream: stream, in: localContext)
        self.queueStreams.async(flags: .barrier) {
            self.decryptedStreamsDict[streamGuid] = decStream
        }
        return decStream
    }

    private func updateDecryptedStream(streamDecrypted decStream: DPAGDecryptedStream, stream: SIMSMessageStream, in localContext: NSManagedObjectContext) {
        decStream.newMessagesCount = stream.countNewMessages()
        if let messageLatest = self.latestMessage(of: stream, in: localContext) {
            decStream.lastMessageDateFormatted = DPAGApplicationFacade.messageWorker.formatLastMessageDate(stream.lastMessageDate ?? (messageLatest is SIMSMessage ? (messageLatest as? SIMSMessage)?.dateSendServer : (messageLatest as? SIMSMessageToSend)?.dateCreated))
            if let decMessage = self.decryptedMessage(messageLatest, in: localContext) {
                decStream.previewText = self.previewTextForStreamsLatestMessage(messageLatest, decMessage: decMessage, in: localContext)
            }
        } else if let streamGroup = stream as? SIMSGroupStream {
            decStream.lastMessageDateFormatted = DPAGApplicationFacade.messageWorker.formatLastMessageDate(stream.lastMessageDate ?? streamGroup.group?.invitedAt)
        } else {
            decStream.lastMessageDateFormatted = DPAGApplicationFacade.messageWorker.formatLastMessageDate(stream.lastMessageDate)
        }
        decStream.hasUnreadHighPriorityMessages = stream.optionsStream.contains(.hasUnreadHighPriorityMessages)
        switch decStream.type {
            case .single:
                if let streamSingle = stream as? SIMSStream, let decStreamSingle = decStream as? DPAGDecryptedStreamPrivate {
                    decStreamSingle.isSystemChat = DPAGSystemChat.isSystemChat(streamSingle)
                    decStreamSingle.contactGuid = streamSingle.contactIndexEntry?.guid
                }
            case .group:
                if let streamGroup = stream as? SIMSGroupStream, let decStreamGroup = decStream as? DPAGDecryptedStreamGroup {
                    decStreamGroup.streamState = streamGroup.streamState
                    if let ownerGuid = streamGroup.group?.ownerGuid, let contact = DPAGApplicationFacade.cache.contact(for: ownerGuid), (streamGroup.group?.isConfirmed ?? false) == false {
                        decStreamGroup.streamName = String(format: "%@: %@", contact.displayName, streamGroup.group?.groupName ?? "")
                    } else {
                        decStreamGroup.streamName = streamGroup.group?.groupName
                    }
                    if let adminGuid = streamGroup.group?.ownerGuid {
                        if SIMSContactIndexEntry.findFirst(byGuid: adminGuid, in: localContext) == nil {
                            DPAGApplicationFacade.updateKnownContactsWorker.synchronize(accountGuid: adminGuid, response: { _, _, _ in })
                        }
                    }
                }
            case .channel:
                if let streamChannel = stream as? SIMSChannelStream, let channel = streamChannel.channel, let decStreamChannel = decStream as? DPAGDecryptedStreamChannel {
                    decStream.type = .channel
                    decStreamChannel.feedType = channel.validFeedType
                    decStreamChannel.streamName = channel.name_short
                    decStreamChannel.streamNameLong = channel.name_long
                    decStreamChannel.colorDate = channel.colorChatListDate
                    decStreamChannel.colorBackground = channel.colorChatListBackground
                    decStreamChannel.colorName = channel.colorChatListName
                    decStreamChannel.colorPreview = channel.colorChatListPreview
                    decStreamChannel.mandatory = channel.isMandatory
                    if let colorChatListBadgeText = channel.colorChatListBadgeText {
                        decStreamChannel.colorUnreadMessagesText = colorChatListBadgeText
                    }
                    if let colorChatListBadge = channel.colorChatListBadge {
                        decStreamChannel.colorUnreadMessagesBackground = colorChatListBadge
                    }
                    if let channelGuid = channel.guid {
                        let assetsList = DPAGApplicationFacade.feedWorker.assetsList(feedGuid: channelGuid)
                        var needChannelImages = false
                        if decStreamChannel.colorBackground == nil {
                            if let backImage = assetsList[.itemBackground] as? UIImage {
                                decStreamChannel.imageBackground = backImage
                            } else {
                                needChannelImages = true
                            }
                        }
                        if decStreamChannel.feedType == .channel {
                                decStreamChannel.imageForeground = assetsList[.itemForeground] as? UIImage
                                decStreamChannel.imageIcon = assetsList[.profile] as? UIImage
                                needChannelImages = decStreamChannel.imageForeground == nil || decStreamChannel.imageIcon == nil
                        }
                        if needChannelImages {
                            DPAGApplicationFacade.feedWorker.updateAssets(feedGuids: [channelGuid], feedType: decStreamChannel.feedType, completion: {
                                let assetsList = DPAGApplicationFacade.feedWorker.assetsList(feedGuid: channelGuid)
                                if decStreamChannel.colorBackground == nil {
                                    if let backImage = assetsList[.itemBackground] as? UIImage {
                                        decStreamChannel.imageBackground = backImage
                                    }
                                }
                                if decStreamChannel.feedType == .channel {
                                        decStreamChannel.imageForeground = assetsList[.itemForeground] as? UIImage
                                        decStreamChannel.imageIcon = assetsList[.profile] as? UIImage
                                }
                                NotificationCenter.default.post(name: DPAGStrings.Notification.ChatList.NEEDS_UPDATE, object: nil)

                            })
                        }
                    }
                }
            case .unknown:
                break
        }
    }

    func latestMessage(of stream: SIMSMessageStream, in localContext: NSManagedObjectContext) -> SIMSManagedObjectMessage? {
        let predMsgToSend = NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageToSend.streamGuid), rightExpression: NSExpression(forConstantValue: stream.guid ?? "unknown"))
        var messageToSendFirst: SIMSMessageToSend?
        if let messageToSend = SIMSMessageToSend.mr_findFirst(with: predMsgToSend, sortedBy: #keyPath(SIMSMessageToSend.dateCreated), ascending: false, in: localContext) {
            messageToSendFirst = messageToSend
        }
        if let messages = stream.messages, let msg = messages.lastObject as? SIMSMessage {
            if ((msg.fromAccountGuid?.isSystemChatGuid ?? false) == false || DPAGSystemChat.isSystemChat(stream) == true) || (stream.wasDeleted?.boolValue ?? false) {
                return (messageToSendFirst?.dateCreated?.isLaterThan(date: msg.dateSendServer ?? Date()) ?? false) ? messageToSendFirst : msg
            }
            var i = (messages.count - 2)
            while i > 0 {
                if let msg = messages[i] as? SIMSMessage, (msg.fromAccountGuid?.isSystemChatGuid ?? false) == false || DPAGSystemChat.isSystemChat(stream) == true {
                    return (messageToSendFirst?.dateCreated?.isLaterThan(date: msg.dateSendServer ?? Date()) ?? false) ? messageToSendFirst : msg
                }
                i -= 1
            }
        }
        return messageToSendFirst
    }

    func previewTextForStreamsLatestMessage(_: SIMSManagedObjectMessage, decMessage: DPAGDecryptedMessage, in localContext: NSManagedObjectContext) -> [DPAGDecryptedStreamPreviewTextItem] {
        var retVal: [DPAGDecryptedStreamPreviewTextItem] = []
        var contentType = decMessage.contentType
        if decMessage.errorType != .none, decMessage.errorType != .notChecked {
            contentType = .plain
        }
        if decMessage.isSelfDestructive, decMessage.isOwnMessage == false {
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = DPAGImageProvider.shared[.kImageChatPreviewDestroy]
            retVal.append(DPAGDecryptedStreamPreviewTextItem(attributedString: NSAttributedString(attachment: imageAttachment), tintColor: DPAGColorProvider.shared[.imageSendSelfDestructTint], spacerPre: true, spacerPost: true))
            retVal.append(DPAGDecryptedStreamPreviewTextItem(attributedString: NSAttributedString(string: DPAGLocalizedString("chat.selfdestruction.preview")), tintColor: nil, spacerPre: false, spacerPost: false))
        } else {
            var imagePreview: UIImage?
            let previewTextItem: DPAGDecryptedStreamPreviewTextItem
            switch contentType {
                case .controlMsgNG:
                    previewTextItem = DPAGDecryptedStreamPreviewTextItem(attributedString: NSAttributedString(string: ""), tintColor: DPAGColorProvider.shared[.imageSendHighPriorityTint], spacerPre: false, spacerPost: false)
                case .avCallInvitation:
                    previewTextItem = DPAGDecryptedStreamPreviewTextItem(attributedString: NSAttributedString(string: "📞"), tintColor: DPAGColorProvider.shared[.imageSendHighPriorityTint], spacerPre: false, spacerPost: false)
                case .plain, .oooStatusMessage, .textRSS:
                    if decMessage.isSystemGenerated {
                        previewTextItem = DPAGDecryptedStreamPreviewTextItem(attributedString: DPAGApplicationFacade.cache.parseSystemMessageContentAttributed(decMessage.content ?? "", withAttributes: [:], in: localContext), tintColor: nil, spacerPre: false, spacerPost: false)
                    } else if let decryptedMessageChannel = decMessage as? DPAGDecryptedMessageChannel, let content = decryptedMessageChannel.content {
                        let previewText: String
                        if decryptedMessageChannel.feedType == .channel {
                            previewText = (DPAGApplicationFacade.feedWorker as? DPAGFeedWorkerProtocolSwift)?.replaceChannelLink(content, contentLinkReplacer: decryptedMessageChannel.contentLinkReplacer).content ?? content
                        } else {
                            previewText = ""
                        }
                        previewTextItem = DPAGDecryptedStreamPreviewTextItem(attributedString: NSAttributedString(string: previewText), tintColor: nil, spacerPre: false, spacerPost: false)
                    } else {
                        previewTextItem = DPAGDecryptedStreamPreviewTextItem(attributedString: NSAttributedString(string: decMessage.content ?? ""), tintColor: nil, spacerPre: false, spacerPost: false)
                    }
                case .image:
                    previewTextItem = DPAGDecryptedStreamPreviewTextItem(attributedString: decMessage.previewText(textSendFailed: DPAGLocalizedString("chat.overview.preview.imageSent.failed"), textSent: DPAGLocalizedString("chat.overview.preview.imageSent"), textReceived: DPAGLocalizedString("chat.overview.preview.imageReceived")), tintColor: nil, spacerPre: false, spacerPost: false)
                    imagePreview = DPAGImageProvider.shared[.kImageChatPreviewImage]
                case .video:
                    previewTextItem = DPAGDecryptedStreamPreviewTextItem(attributedString: decMessage.previewText(textSendFailed: DPAGLocalizedString("chat.overview.preview.videoSent.failed"), textSent: DPAGLocalizedString("chat.overview.preview.videoSent"), textReceived: DPAGLocalizedString("chat.overview.preview.videoReceived")), tintColor: nil, spacerPre: false, spacerPost: false)
                    imagePreview = DPAGImageProvider.shared[.kImageChatPreviewVideo]
                case .location:
                    previewTextItem = DPAGDecryptedStreamPreviewTextItem(attributedString: decMessage.previewText(textSendFailed: DPAGLocalizedString("chat.overview.preview.locationSent.failed"), textSent: DPAGLocalizedString("chat.overview.preview.locationSent"), textReceived: DPAGLocalizedString("chat.overview.preview.locationReceived")), tintColor: nil, spacerPre: false, spacerPost: false)
                case .contact:
                    previewTextItem = DPAGDecryptedStreamPreviewTextItem(attributedString: decMessage.previewText(textSendFailed: DPAGLocalizedString("chat.overview.preview.contactSent.failed"), textSent: DPAGLocalizedString("chat.overview.preview.contactSent"), textReceived: DPAGLocalizedString("chat.overview.preview.contactReceived")), tintColor: nil, spacerPre: false, spacerPost: false)
                    imagePreview = DPAGImageProvider.shared[.kImageChatPreviewContact]
                case .voiceRec:
                    previewTextItem = DPAGDecryptedStreamPreviewTextItem(attributedString: decMessage.previewText(textSendFailed: DPAGLocalizedString("chat.overview.preview.VoiceSent.failed"), textSent: DPAGLocalizedString("chat.overview.preview.VoiceSent"), textReceived: DPAGLocalizedString("chat.overview.preview.VoiceReceived")), tintColor: nil, spacerPre: false, spacerPost: false)
                    imagePreview = DPAGImageProvider.shared[.kImageChatPreviewAudio]
                case .file:
                    previewTextItem = DPAGDecryptedStreamPreviewTextItem(attributedString: decMessage.previewText(textSendFailed: DPAGLocalizedString("chat.overview.preview.FileSent.failed"), textSent: DPAGLocalizedString("chat.overview.preview.FileSent"), textReceived: DPAGLocalizedString("chat.overview.preview.FileReceived")), tintColor: nil, spacerPre: false, spacerPost: false)
                    imagePreview = DPAGImageProvider.shared[.kImageChatPreviewFile]
            }
            if let imagePreview = imagePreview {
                let imageAttachment = NSTextAttachment()
                imageAttachment.image = imagePreview
                retVal.append(DPAGDecryptedStreamPreviewTextItem(attributedString: NSAttributedString(attachment: imageAttachment), tintColor: nil, spacerPre: true, spacerPost: true))
            }
            retVal.append(previewTextItem)
        }
        if decMessage.isSelfDestructive, decMessage.isOwnMessage, let imagePreviewDestroy = DPAGImageProvider.shared[.kImageChatPreviewDestroy] {
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = imagePreviewDestroy
            retVal.insert(DPAGDecryptedStreamPreviewTextItem(attributedString: NSAttributedString(attachment: imageAttachment), tintColor: DPAGColorProvider.shared[.imageSendSelfDestructTint], spacerPre: true, spacerPost: true), at: 0)
        }
        if decMessage.isHighPriorityMessage {
            retVal.insert(DPAGDecryptedStreamPreviewTextItem(attributedString: NSAttributedString(string: DPAGLocalizedString("chat.overview.preview.HighPriorityPre")), tintColor: DPAGColorProvider.shared[.imageSendHighPriorityTint], spacerPre: false, spacerPost: false), at: 0)
            if let imageHighPriority = DPAGImageProvider.shared[.kImageChatPreviewHighPriority] {
                let imageAttachment = NSTextAttachment()
                imageAttachment.image = imageHighPriority
                retVal.insert(DPAGDecryptedStreamPreviewTextItem(attributedString: NSAttributedString(attachment: imageAttachment), tintColor: DPAGColorProvider.shared[.imageSendHighPriorityTint], spacerPre: true, spacerPost: true), at: 0)
            }
        }
        if decMessage.isOwnMessage {
            if let imageSendStateAndColor = decMessage.statusImageAndTintColor(), let imageSendState = imageSendStateAndColor.image {
                let imageAttachment = NSTextAttachment()
                imageAttachment.image = imageSendState
                retVal.insert(DPAGDecryptedStreamPreviewTextItem(attributedString: NSAttributedString(attachment: imageAttachment), tintColor: imageSendStateAndColor.tintColor, spacerPre: true, spacerPost: true), at: 0)
            }
        }
        if decMessage.messageType == .group, decMessage.contentType != .textRSS, let contact = DPAGApplicationFacade.cache.contact(for: decMessage.fromAccountGuid) {
            retVal.insert(DPAGDecryptedStreamPreviewTextItem(attributedString: NSAttributedString(string: "\(contact.displayName): "), tintColor: nil, spacerPre: false, spacerPost: true), at: 0)
        }
        return retVal
    }

    func removeStream(guid: String?) {
        if let streamGuid = guid {
            self.queueStreams.async(flags: .barrier) {
                let oldValue = self.decryptedStreamsDict.removeValue(forKey: streamGuid)
                oldValue?.type = DPAGStreamType.unknown
            }
        }
    }

    func removeAllStreams() {
        self.queueStreams.async(flags: .barrier) {
            self.decryptedStreamsDict.removeAll()
        }
    }

    public func removeMessage(guid: String?) {
        if let messageGuid = guid {
            self.queueMessages.async(flags: .barrier) {
                let oldValue = self.decryptedMessagesDict.removeValue(forKey: messageGuid)
                oldValue?.messageType = .unknown
            }
        }
    }

    public func clearCache() {
        self.reinitCaches()
        self.queueStreams.async(flags: .barrier) {
            self.decryptedStreamsDict.removeAll()
        }
        self.queueMessages.async(flags: .barrier) {
            self.decryptedMessagesDict.removeAll()
        }
        self.queueImages.async(flags: .barrier) {
            self.cachedImagesDict.removeAll()
        }
        self.queueAesKeys.async(flags: .barrier) {
            self.cachedAesKeyDict.removeAll()
        }
        self.queueContentLinkReplacer.async(flags: .barrier) {
            self.cachedContentLinkReplacer.removeAll()
        }
    }

    func updateDecryptedMessage(guid: String, withNewGuid guidNew: String) {
        self.queueMessages.async(flags: .barrier) {
            if let decMessage = self.decryptedMessagesDict[guid] {
                decMessage.messageGuid = guidNew
                self.decryptedMessagesDict[guidNew] = decMessage
            }
        }
    }

    public func parseSystemMessageContent(_ messageContent: String, in localContext: NSManagedObjectContext) -> String {
        guard let regEx = try? NSRegularExpression(pattern: "([0-9]+):\\{[A-F0-9]{8}(?:-[A-F0-9]{4}){3}-[A-F0-9]{12}\\}", options: NSRegularExpression.Options.caseInsensitive), let regExWithNick = try? NSRegularExpression(pattern: "(([0-9]+):\\{[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}\\})\\|((?:[A-Za-z0-9+\\/]{4}\\n?)*(?:[A-Za-z0-9+\\/]{2}==|[A-Za-z0-9+\\/]{3}=)?)\\|", options: NSRegularExpression.Options()) else {
            return messageContent
        }

        var retValWithNick = messageContent

        regExWithNick.enumerateMatches(in: messageContent, options: .reportCompletion, range: NSRange(location: 0, length: (messageContent as NSString).length)) { result, _, _ in

            if let result = result, result.range.location != NSNotFound {
                let match = (messageContent as NSString).substring(with: result.range)
                let guid = (messageContent as NSString).substring(with: result.range(at: 1))
                let guidPrefix = (messageContent as NSString).substring(with: result.range(at: 2))

                if guidPrefix == "0" {
                    // contact guid
                    if let contact = DPAGApplicationFacade.cache.contact(for: guid) {
                        if contact.nickName == nil {
                            let nickNameBase64Encoded = (messageContent as NSString).substring(with: result.range(at: 3))
                            if let data = Data(base64Encoded: nickNameBase64Encoded, options: .ignoreUnknownCharacters), let nickName = String(data: data, encoding: .utf8), let contactDB = SIMSContactIndexEntry.findFirst(byGuid: guid, in: localContext) {
                                contactDB[.NICKNAME] = nickName
                                contact.nickName = nickName
                            }
                        }
                        retValWithNick = retValWithNick.replacingOccurrences(of: match, with: contact.displayName)
                    } else {
                        retValWithNick = retValWithNick.replacingOccurrences(of: match, with: DPAGLocalizedString("chats.contact.unknown"))
                    }
                } else if guidPrefix == "1" {
                    // contact guid
                    if let group = DPAGApplicationFacade.cache.group(for: guid) {
                        retValWithNick = retValWithNick.replacingOccurrences(of: match, with: group.name ?? "???")
                    } else if let group = SIMSGroup.findFirst(byGuid: guid, in: localContext) {
                        retValWithNick = retValWithNick.replacingOccurrences(of: match, with: group.groupName ?? "???")
                    }
                }
            }
        }

        var retVal = retValWithNick

        regEx.enumerateMatches(in: retValWithNick, options: .reportCompletion, range: NSRange(location: 0, length: (retValWithNick as NSString).length)) { result, _, _ in

            if let result = result, result.range.location != NSNotFound {
                let match = (retValWithNick as NSString).substring(with: result.range)

                if match.hasPrefix(.account) {
                    // contact guid
                    if let contact = DPAGApplicationFacade.cache.contact(for: match) {
                        retVal = retVal.replacingOccurrences(of: match, with: contact.displayName)
                    } else {
                        retVal = retVal.replacingOccurrences(of: match, with: DPAGLocalizedString("chats.contact.unknown"))
                    }
                } else if match.hasPrefix(.group) || match.hasPrefix(.streamGroup) {
                    // contact guid
                    if let group = DPAGApplicationFacade.cache.group(for: match) {
                        retVal = retVal.replacingOccurrences(of: match, with: group.name ?? "???")
                    } else if let group = SIMSGroup.findFirst(byGuid: match, in: localContext) {
                        retVal = retVal.replacingOccurrences(of: match, with: group.groupName ?? "???")
                    }
                }
            }
        }

        return retVal
    }

    public func parseSystemMessageContentAttributed(_ messageContent: String, withAttributes attributes: [NSAttributedString.Key: Any], in localContext: NSManagedObjectContext) -> NSAttributedString {
        guard let regEx = try? NSRegularExpression(pattern: "([0-9]+:)\\{[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}\\}", options: NSRegularExpression.Options.caseInsensitive), let regExWithNick = try? NSRegularExpression(pattern: "(([0-9]+:)\\{[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}\\})\\|((?:[A-Za-z0-9+\\/]{4}\\n?)*(?:[A-Za-z0-9+\\/]{2}==|[A-Za-z0-9+\\/]{3}=)?)\\|", options: NSRegularExpression.Options()) else {
            return NSMutableAttributedString(string: messageContent)
        }
        let retValWithNick: NSMutableAttributedString = NSMutableAttributedString(string: messageContent)
        var matchNick = regExWithNick.firstMatch(in: retValWithNick.string, options: .reportCompletion, range: NSRange(location: 0, length: (retValWithNick.string as NSString).length))
        repeat {
            guard let match = matchNick else { break }
            let guid = (retValWithNick.string as NSString).substring(with: match.range(at: 1))
            let guidPrefix = (retValWithNick.string as NSString).substring(with: match.range(at: 2))
            if guidPrefix.hasPrefix(.account) {
                // contact guid
                if let contact = DPAGApplicationFacade.cache.contact(for: guid) {
                    if contact.nickName == nil {
                        let nickNameBase64Encoded = (retValWithNick.string as NSString).substring(with: match.range(at: 3))
                        if let data = Data(base64Encoded: nickNameBase64Encoded, options: .ignoreUnknownCharacters), let nickName = String(data: data, encoding: .utf8), let contactDB = SIMSContactIndexEntry.findFirst(byGuid: guid, in: localContext) {
                            contactDB[.NICKNAME] = nickName
                            contact.nickName = nickName
                        }
                    }
                    retValWithNick.replaceCharacters(in: match.range, with: NSAttributedString(string: contact.displayName, attributes: attributes))
                } else {
                    retValWithNick.replaceCharacters(in: match.range, with: NSAttributedString(string: DPAGLocalizedString("chats.contact.unknown"), attributes: attributes))
                }
            } else if guidPrefix.hasPrefix(.group) || guidPrefix.hasPrefix(.streamGroup) {
                // contact guid
                if let group = DPAGApplicationFacade.cache.group(for: guid) {
                    retValWithNick.replaceCharacters(in: match.range, with: NSAttributedString(string: group.name ?? "???", attributes: attributes))
                } else if let group = SIMSGroup.findFirst(byGuid: guid, in: localContext) {
                    retValWithNick.replaceCharacters(in: match.range, with: NSAttributedString(string: group.groupName ?? "???", attributes: attributes))
                }
            }
            matchNick = regExWithNick.firstMatch(in: retValWithNick.string, options: .reportCompletion, range: NSRange(location: 0, length: (retValWithNick.string as NSString).length))
        } while matchNick != nil
        let retVal = retValWithNick
        var matchRet = regEx.firstMatch(in: retVal.string, options: .reportCompletion, range: NSRange(location: 0, length: (retVal.string as NSString).length))
        repeat {
            guard let match = matchRet else { break }
            let guid = (retVal.string as NSString).substring(with: match.range)
            if guid.hasPrefix(.account) {
                // contact guid
                if let contact = DPAGApplicationFacade.cache.contact(for: guid) {
                    retVal.replaceCharacters(in: match.range, with: NSAttributedString(string: contact.displayName, attributes: attributes))
                } else {
                    retVal.replaceCharacters(in: match.range, with: NSAttributedString(string: DPAGLocalizedString("chats.contact.unknown"), attributes: attributes))
                }
            } else if guid.hasPrefix(.group) || guid.hasPrefix(.streamGroup) {
                // contact guid
                if let group = DPAGApplicationFacade.cache.group(for: guid) {
                    retVal.replaceCharacters(in: match.range, with: NSAttributedString(string: group.name ?? "???", attributes: attributes))
                } else if let group = SIMSGroup.findFirst(byGuid: guid, in: localContext) {
                    retVal.replaceCharacters(in: match.range, with: NSAttributedString(string: group.groupName ?? "???", attributes: attributes))
                }
            }
            matchRet = regEx.firstMatch(in: retVal.string, options: .reportCompletion, range: NSRange(location: 0, length: (retVal.string as NSString).length))
        } while matchRet != nil
        return retVal
    }

    func cachedImage(streamGuid guid: String, type assetType: DPAGChannel.AssetType, scale: CGFloat) -> UIImage? {
        var retVal: UIImage?

        self.queueImages.sync {
            if let streamImages = self.cachedImagesDict[guid], let scaledImages = streamImages[Int(scale)], let image = scaledImages[assetType.rawValue] {
                retVal = image
            }
        }
        return retVal
    }

    func setCachedImage(_ image: UIImage?, streamGuid guid: String, type assetType: DPAGChannel.AssetType, scale: CGFloat) {
        self.queueImages.async(flags: .barrier) {
            var streamImages = self.cachedImagesDict[guid] ?? [:]
            var scaledImages = streamImages[Int(scale)] ?? [:]
            if image == nil {
                scaledImages.removeValue(forKey: assetType.rawValue)
            } else {
                scaledImages[assetType.rawValue] = image
            }
            streamImages[Int(scale)] = scaledImages
            self.cachedImagesDict[guid] = streamImages
        }
    }

    func cachedAesKey(key: String) -> String? {
        var retVal: String?
        self.queueAesKeys.sync {
            retVal = self.cachedAesKeyDict[key]
        }
        return retVal
    }

    func setCachedAesKey(aesKey: String?, forKey key: String) {
        self.queueAesKeys.async(flags: .barrier) {
            self.cachedAesKeyDict[key] = aesKey
        }
    }

    var cachedSortOrder: CNContactSortOrder = .userDefault
    func updateSortOrder() {
        self.cachedSortOrder = CNContactsUserDefaults.shared().sortOrder
    }

    public var personSortOrder: CNContactSortOrder {
        self.cachedSortOrder
    }

    var cachedDisplayNameOrder: CNContactDisplayNameOrder = .userDefault
    func updateDisplayNameOrder() {
        self.cachedDisplayNameOrder = CNContactFormatter.nameOrder(for: CNContact())
    }

    public var personDisplayNameOrder: CNContactDisplayNameOrder {
        self.cachedDisplayNameOrder
    }

    public var ownTempDeviceGuid: String?
    public var ownTempDevicePublicKey: String?

    public func reinitCaches() {
        self.updateSortOrder()
        self.updateDisplayNameOrder()
        self.loadHashedAccountSearchAttributes()
        self.ownTempDeviceGuid = nil
        self.ownTempDevicePublicKey = nil
    }

    public func hash(accountSearchAttribute: String, withSalt salt: String) -> String {
        var rc = accountSearchAttribute
        self.queuePhoneNumber.sync {
            if let hashed = self.cachePhoneNumber[salt + accountSearchAttribute] {
                rc = hashed
            } else if let hashed = JFBCrypt.hashPassword(accountSearchAttribute, withSalt: salt) {
                rc = hashed
            }
        }
        self.queuePhoneNumber.async(flags: .barrier) {
            self.cachePhoneNumber[salt + accountSearchAttribute] = rc
        }
        return rc
    }

    public func saveHashedAccountSearchAttributes() {
        if let url = DPAGConstantsGlobal.documentsDirectoryURL?.appendingPathComponent("hashedphonedata").appendingPathExtension("plist") {
            let data: NSMutableDictionary = NSMutableDictionary(dictionary: self.cachePhoneNumber)

            data.write(to: url, atomically: true)
        }
    }

    func loadHashedAccountSearchAttributes() {
        if let url = DPAGConstantsGlobal.documentsDirectoryURL?.appendingPathComponent("hashedphonedata").appendingPathExtension("plist") {
            if let data = NSMutableDictionary(contentsOf: url) {
                for key in data.keyEnumerator() {
                    if let keyString = key as? String, self.cachePhoneNumber[keyString] == nil {
                        self.cachePhoneNumber[keyString] = data[keyString] as? String
                    }
                }
            }
        }
    }

    func contentLinkReplacer(forService channel: SIMSChannel) -> [DPAGContentLinkReplacerRegex] {
        var retVal: [DPAGContentLinkReplacerRegex]?
        guard let channelGuid = channel.guid else { return [] }
        self.queueContentLinkReplacer.sync {
            retVal = self.cachedContentLinkReplacer[channelGuid]
        }
        if retVal == nil {
            if let replacerRegex: [DPAGContentLinkReplacerString] = channel.contentLinkReplacerRegex {
                var retValNew: [DPAGContentLinkReplacerRegex] = []

                for replacer in replacerRegex {
                    if let regEx = try? NSRegularExpression(pattern: replacer.pattern, options: NSRegularExpression.Options()) {
                        retValNew.append(DPAGContentLinkReplacerRegex(regEx: regEx, replacer: replacer.replacer))
                    }
                }
                if retValNew.count > 0 {
                    self.queueContentLinkReplacer.async(flags: .barrier) {
                        self.cachedContentLinkReplacer[channelGuid] = retValNew
                    }
                    retVal = retValNew
                }
            }
        }
        return retVal ?? []
    }

    func removeCachedContactImages(contactGuid: String) {
        self.queueObjects.sync {
            if let contact = self.objects[contactGuid] as? DPAGContact {
                contact.removeCachedImages()
            }
        }
    }

    func deleteObjectCache() {
        self.queueObjects.async(flags: .barrier) {
            self.objects.removeAll()
            self.contacts.removeAll()
            self.groups.removeAll()
            self.channels.removeAll()
        }
    }

    public func ownContact() -> DPAGContact? {
        guard let accountGuid = self.account?.guid else { return nil }
        return self.contact(for: accountGuid)
    }

    public func contact(for guid: String) -> DPAGContact? {
        self.object(forGuid: guid, frc: self.fetchedResultsControllerContacts) as? DPAGContact
    }

    func contact(for guid: String, contactDB: SIMSContactIndexEntry) -> DPAGContact? {
        if let contactCache = self.cachedContact(for: guid) {
            return contactCache
        }
        guard let contact = DPAGContact(contact: contactDB) else { return nil }
        self.queueObjects.async(flags: .barrier) {
            self.objects[contact.guid] = contact
            self.contacts[contact.guid] = contact
        }
        return contact
    }

    func cachedContact(for guid: String) -> DPAGContact? {
        var retVal: DPAGObject?
        self.queueObjects.sync {
            retVal = self.objects[guid]
        }
        return retVal as? DPAGContact
    }

    public func group(for guid: String) -> DPAGGroup? {
        self.object(forGuid: guid, frc: self.fetchedResultsControllerGroups) as? DPAGGroup
    }

    public func channel(for guid: String) -> DPAGChannel? {
        self.object(forGuid: guid, frc: self.fetchedResultsControllerChannels) as? DPAGChannel
    }

    private func object<T>(forGuid guid: String, frc controller: NSFetchedResultsController<T>) -> DPAGObject? where T: SIMSManagedObject {
        var retVal: DPAGObject?
        self.queueObjects.sync {
            retVal = self.objects[guid]
        }
        if retVal == nil {
            DPAGApplicationFacade.persistance.loadWithBlock { localContext in
                let request = NSFetchRequest<NSFetchRequestResult>()
                request.predicate = NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSManagedObject.guid), rightExpression: NSExpression(forConstantValue: guid))
                request.entity = controller.fetchRequest.entity
                request.fetchLimit = 1
                var results: [NSFetchRequestResult] = []
                let requestBlock = {
                    do {
                        results = try localContext.fetch(request)
                    } catch {
                        DPAGLog(error)
                    }
                }
                localContext.performAndWait(requestBlock)
                if let anManagedObject = results.first as? SIMSManagedObject, let dpagObject = DPAGCache.dpagObject(for: anManagedObject, in: controller.managedObjectContext) {
                    retVal = dpagObject
                    self.queueObjects.async(flags: .barrier) {
                        self.objects[dpagObject.guid] = dpagObject

                        if let contact = dpagObject as? DPAGContact {
                            self.contacts[dpagObject.guid] = contact
                        } else if let group = dpagObject as? DPAGGroup {
                            self.groups[dpagObject.guid] = group
                        }
                        if let channel = dpagObject as? DPAGChannel {
                            self.channels[dpagObject.guid] = channel
                        }
                    }
                }
            }
        }

        return retVal
    }

    private static func frc<T>(entityName: String) -> NSFetchedResultsController<T> {
        let fetchRequest = NSFetchRequest<T>(entityName: entityName)
        fetchRequest.sortDescriptors = []
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: NSManagedObjectContext.mr_rootSaving(), sectionNameKeyPath: nil, cacheName: nil)
        return fetchedResultsController
    }

    fileprivate static func dpagObject(for anManagedObject: SIMSManagedObject, in _: NSManagedObjectContext) -> DPAGObject? {
        if let obj = anManagedObject as? SIMSContactIndexEntry {
            return DPAGContact(contact: obj)
        }
        if let obj = anManagedObject as? SIMSGroup {
            return DPAGGroup(group: obj)
        }
        if let obj = anManagedObject as? SIMSChannel {
            return DPAGChannel(channel: obj)
        }

        return nil
    }

    private var updatedContactsFTSInfo: [String: FtsDatabaseContact] = [:]
    private var updatedContactGuids: Set<String> = Set()
    private var updatedGroupGuids: Set<String> = Set()

    func loadContact(contact: SIMSContactIndexEntry) {
        guard let contactGuid = contact.guid else { return }
        var contactFound: DPAGContact?
        self.queueObjects.sync {
            contactFound = self.contacts[contactGuid]
        }
        guard contactFound == nil else { return }
        guard let dpagContact = DPAGContact(contact: contact) else { return }
        self.queueObjects.async(flags: .barrier) {
            self.objects[dpagContact.guid] = dpagContact
            self.contacts[dpagContact.guid] = dpagContact
        }
    }
}

extension DPAGCache: NSFetchedResultsControllerDelegate {
    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        AppConfig.backgroundTaskExecution {
            DPAGDBFullTextHelper.insertOrUpdateContacts(withGroupId: DPAGApplicationFacade.preferences.sharedContainerConfig.groupID, contactInfos: Array(self.updatedContactsFTSInfo.values))
        }
        DPAGApplicationFacade.companyAdressbook.updateFullTextStates(localContext: controller.managedObjectContext)
        self.updatedContactsFTSInfo.removeAll()
        for contactGuid in self.updatedContactGuids {
            self.performBlockOnMainThread {
                NotificationCenter.default.post(name: DPAGStrings.Notification.Contact.CHANGED, object: nil, userInfo: [DPAGStrings.Notification.Contact.CHANGED__USERINFO_KEY__CONTACT_GUID: contactGuid])
            }
        }
        self.updatedContactGuids.removeAll()
        for groupGuid in self.updatedGroupGuids {
            self.performBlockOnMainThread {
                NotificationCenter.default.post(name: DPAGStrings.Notification.Group.CHANGED, object: nil, userInfo: [DPAGStrings.Notification.Group.CHANGED__USERINFO_KEY__GROUP_GUID: groupGuid])
            }
        }
        self.updatedGroupGuids.removeAll()
        if controller == self.fetchedResultsControllerContacts && DPAGApplicationFacade.cache.account?.accountState == .confirmed && (DPAGApplicationFacade.preferences.isBaMandant || AppConfig.multiDeviceAllowed) {
            self.performBlockInBackground {
                DPAGApplicationFacade.couplingWorker.savePrivateIndexToServer()
            }
        }
    }

    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at _: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath _: IndexPath?) {
        if controller == self.fetchedResultsControllerAccount {
            switch type {
                case .insert:
                    if let accountDB = anObject as? SIMSAccount {
                        self.accountInternal = DPAGAccount(account: accountDB)
                    }
                case .update, .move:
                    if let accountDB = anObject as? SIMSAccount {
                        self.account?.update(with: accountDB)
                    }
                case .delete:
                    self.accountInternal = nil
                @unknown default:
                    DPAGLog("Switch with unknown value: \(type.rawValue)", level: .warning)
            }
            return
        }
        switch type {
            case .insert:
                if let aManagedObject = anObject as? SIMSManagedObject, let guid = aManagedObject.guid {
                    var dkObject: DPAGObject?
                    self.queueObjects.sync {
                        dkObject = self.objects[guid]
                    }
                    if let dkObject = dkObject {
                        dkObject.update(with: aManagedObject)
                        if let aContact = aManagedObject as? SIMSContactIndexEntry {
                            self.updatedContactGuids.insert(guid)
                            self.updatedContactsFTSInfo[guid] = aContact.ftsContact
                        }
                        if aManagedObject is SIMSGroup {
                            self.updatedGroupGuids.insert(guid)
                        }
                    } else if controller == self.fetchedResultsControllerContacts, let aContact = aManagedObject as? SIMSContactIndexEntry {
                        self.updatedContactsFTSInfo[guid] = aContact.ftsContact

                        //                        if let contactCache = DPAGContact(contact: aContact)
                        //                        {
                        //                            self.objects[contactCache.guid] = contactCache
                        //                            self.contacts[contactCache.guid] = contactCache
                        //                        }
                    } else if controller == self.fetchedResultsControllerGroups, let aGroup = aManagedObject as? SIMSGroup {
                        if let groupCache = DPAGGroup(group: aGroup) {
                            self.queueObjects.async(flags: .barrier) {
                                self.objects[groupCache.guid] = groupCache
                                self.groups[groupCache.guid] = groupCache
                            }
                        }
                    } else if controller == self.fetchedResultsControllerChannels, let aChannel = aManagedObject as? SIMSChannel {
                        if let channelCache = DPAGChannel(channel: aChannel) {
                            self.queueObjects.async(flags: .barrier) {
                                self.objects[channelCache.guid] = channelCache
                                self.channels[channelCache.guid] = channelCache
                            }
                        }
                    }
                }
            case .update, .move:
                if let aManagedObject = anObject as? SIMSManagedObject, let guid = aManagedObject.guid {
                    var dkObject: DPAGObject?
                    self.queueObjects.sync {
                        dkObject = self.objects[guid]
                    }
                    if let dkObject = dkObject {
                        dkObject.update(with: aManagedObject)
                        if let aContact = aManagedObject as? SIMSContactIndexEntry {
                            self.updatedContactGuids.insert(guid)
                            self.updatedContactsFTSInfo[guid] = aContact.ftsContact
                        }
                        if aManagedObject is SIMSGroup {
                            self.updatedGroupGuids.insert(guid)
                        }
                    } else if controller == self.fetchedResultsControllerContacts, let aContact = aManagedObject as? SIMSContactIndexEntry {
                        self.updatedContactsFTSInfo[guid] = aContact.ftsContact
                        //                        if let contactCache = DPAGContact(contact: aContact)
                        //                        {
                        //                            self.objects[contactCache.guid] = contactCache
                        //                            self.contacts[contactCache.guid] = contactCache
                        //                        }
                    } else if controller == self.fetchedResultsControllerGroups, let aGroup = aManagedObject as? SIMSGroup {
                        if let groupCache = DPAGGroup(group: aGroup) {
                            self.queueObjects.async(flags: .barrier) {
                                self.objects[groupCache.guid] = groupCache
                                self.groups[groupCache.guid] = groupCache
                            }
                        }
                    } else if controller == self.fetchedResultsControllerChannels, let aChannel = aManagedObject as? SIMSChannel {
                        if let channelCache = DPAGChannel(channel: aChannel) {
                            self.queueObjects.async(flags: .barrier) {
                                self.objects[channelCache.guid] = channelCache
                                self.channels[channelCache.guid] = channelCache
                            }
                        }
                    }
                }
            case .delete:
                break
                // no guid available
                /* if let anDKManagedObject = anObject as? DK_ManagedObjectBase
                 {
                 NSLog("didChange %@", anDKManagedObject.uuid.uuidString)
                 let guid = anDKManagedObject.uuid

                 self.queueObjects.sync { in

                 _ = self.objects.removeValue(forKey: guid)
                 }
                 } */
            @unknown default:
                DPAGLog("Switch with unknown value: \(type.rawValue)", level: .warning)
        }
    }

//    func loadObject(_ aManagedObject: SIMSManagedObject, in localContext: NSManagedObjectContext)
//    {
//        guard let guid = aManagedObject.guid else
//        {
//            return
//        }
//        self.queueObjects.sync { in
//
//            if let dkObject = self.objects[guid]
//            {
//                dkObject.update(with: aManagedObject)
//            }
//            else if let aContact = aManagedObject as? SIMSContactIndexEntry
//            {
//                if let contactCache = DPAGContact(contact: aContact)
//                {
//                    self.objects[contactCache.guid] = contactCache
//                    self.contacts[contactCache.guid] = contactCache
//                }
//            }
//            else if let aGroup = aManagedObject as? SIMSGroup
//            {
//                if let groupCache = DPAGGroup(group: aGroup)
//                {
//                    self.objects[groupCache.guid] = groupCache
//                    self.groups[groupCache.guid] = groupCache
//                }
//            }
//        }
//    }
}
