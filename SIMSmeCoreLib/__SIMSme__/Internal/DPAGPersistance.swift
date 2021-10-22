//
//  DPAGPersistance.swift
// ginlo
//
//  Created by RBU on 05/11/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import MagicalRecord

public enum DPAGPersistanceError: Error {
    case errException(stsackTrace: String)
}

protocol DPAGPersistanceProtocol: AnyObject {
    func loadWithBlock(_ block: @escaping ((NSManagedObjectContext) -> Void))
    func loadWithError(_ block: @escaping ((NSManagedObjectContext) throws -> Void)) throws

    func saveWithBlock(_ block: ((_ localContext: NSManagedObjectContext) -> Void)?)
    func saveWithError(_ block: ((_ localContext: NSManagedObjectContext) throws -> Void)?) throws

    func deleteAllObjects() throws
    func findAccount(forDictionary dic: [AnyHashable: Any]) -> DPAGAccount?
    func deleteMessage(_ message: SIMSManagedObjectMessage, in localContext: NSManagedObjectContext)
    func deleteMessageForStream(_ messageGuid: String)
}

class DPAGPersistance: NSObject, DPAGPersistanceProtocol {
    static let DPAGPersistanceWillSaveContextNotification: Notification.Name = Notification.Name("DPAGPersistanceWillSaveContextNotification")
    static let DPAGPersistanceDidSaveContextNotification: Notification.Name = Notification.Name("DPAGPersistanceDidSaveContextNotification")

    var streams: [String: SIMSMessageStream] = [:]

    override init() {
        super.init()
        MagicalRecord.setErrorHandlerTarget(self, action: #selector(DPAGPersistance.customErrorHandler(_:)))
    }

    @objc
    func customErrorHandler(_ error: NSError) {
        var errorString = ""
        errorString.append("MagicalRecord SQLError\n")
        let userInfo = error.userInfo
        for detailedErrorItem in userInfo.values {
            if let detailedError = detailedErrorItem as? [AnyObject] {
                for eItem in detailedError {
                    if let e = eItem as? NSError {
                        errorString.append("Error Details: \(e.userInfo)\n")
                    }
                }
            } else if let detailedErrorItemObj = detailedErrorItem as? NSObject {
                errorString.append("Error: \(detailedErrorItemObj)\n")
            }
        }
        errorString.append("Error Message: \(error.localizedDescription)\n")
        errorString.append("Error Domain: \(error.domain) (\(error.code))\n")
        if let localizedRecoverySuggestion = error.localizedRecoverySuggestion {
            errorString.append("Recovery Suggestion: \(localizedRecoverySuggestion)\n")
        }
        DPAGLog("%@", errorString)
    }

    func loadWithError(_ block: @escaping ((NSManagedObjectContext) throws -> Void)) throws {
        guard let persistentStoreCoordinator = NSManagedObjectContext.mr_rootSaving().persistentStoreCoordinator else { return }
        let localContext: NSManagedObjectContext = NSManagedObjectContext.mr_context(with: persistentStoreCoordinator)
        var errorBlock: Error?
        localContext.performAndWait {
            tryC {
                do {
                    try block(localContext)
                    let countChangedObjects = (localContext.insertedObjects.count + localContext.updatedObjects.count + localContext.deletedObjects.count)
                    if localContext.hasChanges, countChangedObjects != 0 {
                        assert(false, "Changes On Load")
                    }
                } catch {
                    errorBlock = error
                    localContext.reset()
                }
            }.catch { exception in
                errorBlock = DPAGPersistanceError.errException(stsackTrace: exception.callStackSymbols.joined())
                localContext.reset()
            }
        }
        if let error = errorBlock {
            throw error
        }
    }

    func loadWithBlock(_ block: @escaping ((NSManagedObjectContext) -> Void)) {
        guard let persistentStoreCoordinator = NSManagedObjectContext.mr_rootSaving().persistentStoreCoordinator else { return }
        let localContext: NSManagedObjectContext = NSManagedObjectContext.mr_context(with: persistentStoreCoordinator)
        localContext.performBlockAndWait({
            block(localContext)
            let countChangedObjects = (localContext.insertedObjects.count + localContext.updatedObjects.count + localContext.deletedObjects.count)
            if localContext.hasChanges, countChangedObjects != 0 {
                // What is the alternative here to crashing?
                // assert(false, "Changes On Load")
            }
        }, rethrowExceptions: true)
    }

    func saveWithError(_ block: ((_ localContext: NSManagedObjectContext) throws -> Void)?) throws {
        let localContext = NSManagedObjectContext.mr_context(withParent: NSManagedObjectContext.mr_rootSaving())
        localContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        var errorBlock: Error?
        localContext.performAndWait {
            tryC {
                do {
                    try block?(localContext)
                    NotificationCenter.default.post(name: DPAGPersistance.DPAGPersistanceWillSaveContextNotification, object: nil)
                    let managedObjectsUpd = localContext.updatedObjects
                    for managedObj in managedObjectsUpd {
                        if let managedObjEnc = managedObj as? SIMSManagedObjectEncrypted {
                            DPAGLog("beforeSave: %@", managedObj)
                            try managedObjEnc.beforeSave()
                        }
                    }
                    let managedObjectsIns = localContext.insertedObjects
                    for managedObj in managedObjectsIns {
                        if let managedObjEnc = managedObj as? SIMSManagedObjectEncrypted {
                            DPAGLog("beforeSave: %@", managedObj)
                            try managedObjEnc.beforeSave()
                        }
                    }
                    if localContext.hasChanges {
                        localContext.mr_save(options: [MRSaveOptions.parentContexts, MRSaveOptions.synchronously]) { _, error in
                            if let error = error {
                                DPAGLog("failed to save context with error: %@", error.localizedDescription)
                                errorBlock = error
                            }
                        }
                    }
                    localContext.reset()
                    NotificationCenter.default.post(name: DPAGPersistance.DPAGPersistanceDidSaveContextNotification, object: nil)
                } catch {
                    errorBlock = error
                    localContext.reset()
                }
            }.catch { exception in
                errorBlock = DPAGPersistanceError.errException(stsackTrace: exception.callStackSymbols.joined())
                localContext.reset()
            }
        }
        if let error = errorBlock {
            throw error
        }
    }

    func saveWithBlock(_ block: ((_ localContext: NSManagedObjectContext) -> Void)?) {
        let localContext = NSManagedObjectContext.mr_context(withParent: NSManagedObjectContext.mr_rootSaving())
        localContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        localContext.performBlockAndWait({
            if block != nil {
                block?(localContext)
            }
            NotificationCenter.default.post(name: DPAGPersistance.DPAGPersistanceWillSaveContextNotification, object: nil)
            let managedObjectsUpd = localContext.updatedObjects
            for managedObj in managedObjectsUpd {
                if let managedObjEnc = managedObj as? SIMSManagedObjectEncrypted {
                    DPAGLog("beforeSave: %@", managedObj)
                    try? managedObjEnc.beforeSave()
                }
            }
            let managedObjectsIns = localContext.insertedObjects
            for managedObj in managedObjectsIns {
                if let managedObjEnc = managedObj as? SIMSManagedObjectEncrypted {
                    DPAGLog("beforeSave: %@", managedObj)
                    try? managedObjEnc.beforeSave()
                }
            }
            if localContext.hasChanges {
                localContext.mr_save(options: [MRSaveOptions.parentContexts, MRSaveOptions.synchronously]) { _, error in
                    if let error = error {
                        DPAGLog("failed to save context with error: %@", error.localizedDescription)
                    }
                }
            }
            localContext.reset()
            NotificationCenter.default.post(name: DPAGPersistance.DPAGPersistanceDidSaveContextNotification, object: nil)
        }, rethrowExceptions: true)
    }

    func findAccount(forDictionary dic: [AnyHashable: Any]) -> DPAGAccount? {
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) else { return nil }
        guard let publicKey_ = dic["publicKey"] as? String, publicKey_ == contact.publicKey else { return nil }
        guard let guid_ = dic["guid"] as? String, guid_ == account.guid else { return nil }
        guard let keyGuid_ = dic["keyGuid"] as? String, keyGuid_ == account.keyGuid else { return nil }
        return account
    }

    public func deleteAllObjects() {
        self.saveWithBlock { localContext in
            SIMSAccount.mr_truncateAll(in: localContext)
            SIMSAccountStateMessage.mr_truncateAll(in: localContext)
            SIMSContact.mr_truncateAll(in: localContext)
            SIMSContactIndexEntry.mr_truncateAll(in: localContext)
            SIMSCompanyContact.mr_truncateAll(in: localContext)
            SIMSDevice.mr_truncateAll(in: localContext)
            SIMSKey.mr_truncateAll(in: localContext)
            SIMSPrivateMessage.mr_truncateAll(in: localContext)
            SIMSStream.mr_truncateAll(in: localContext)
            SIMSGroupMember.mr_truncateAll(in: localContext)
            SIMSGroupMessage.mr_truncateAll(in: localContext)
            SIMSGroupStream.mr_truncateAll(in: localContext)
            SIMSGroup.mr_truncateAll(in: localContext)
            SIMSChannel.mr_truncateAll(in: localContext)
            SIMSChannelAsset.mr_truncateAll(in: localContext)
            SIMSChannelMessage.mr_truncateAll(in: localContext)
            SIMSChannelOption.mr_truncateAll(in: localContext)
            SIMSChannelOptionChildren.mr_truncateAll(in: localContext)
            SIMSChannelStream.mr_truncateAll(in: localContext)
            SIMSChannelToggle.mr_truncateAll(in: localContext)
            SIMSSelfDestructMessage.mr_truncateAll(in: localContext)
            SIMSPrivateInternalMessage.mr_truncateAll(in: localContext)
            SIMSChecksum.mr_truncateAll(in: localContext)
            SIMSMessageToSendPrivate.mr_truncateAll(in: localContext)
            SIMSMessageToSendGroup.mr_truncateAll(in: localContext)
            SIMSMessageToSend.mr_truncateAll(in: localContext)
        }
        DPAGDBFullTextHelper.deleteAllObjects(withGroupId: DPAGApplicationFacade.preferences.sharedContainerConfig.groupID)
    }

    func countManagedObjects() { /*
     NSArray *keys = [SIMSKey MR_findAll]
     NSArray *accounts = [SIMSAccount MR_findAll]
     NSArray *devices = [SIMSDevice MR_findAll]
     NSArray *contacts = [SIMSContact MR_findAll]
     NSArray *messages = [SIMSPrivateMessage MR_findAll]
     NSArray *streams = [SIMSStream MR_findAll]
     NSArray *groups = [SIMSGroupStream MR_findAll]
     NSArray *groupMessages = [SIMSGroupMessage MR_findAll];*/
    }

    public func deleteMessage(_ message: SIMSManagedObjectMessage, in localContext: NSManagedObjectContext) {
        guard let messageGuid = message.guid else {
            return
        }

        DPAGApplicationFacade.cache.removeMessage(guid: messageGuid)

        if message.attachment != nil {
            DPAGAttachmentWorker.removeEncryptedAttachment(guid: message.attachment)
        }

        if let messageSent = message as? SIMSMessage {
            var hasUnreadMessages = false
            if let msgLast = messageSent.stream?.messages?.lastObject as? SIMSMessage {
                hasUnreadMessages = msgLast.attributes?.dateReadLocal == nil
            }
            messageSent.stream = nil

            if let messageStream = messageSent.stream, hasUnreadMessages == false {
                messageStream.optionsStream = messageStream.optionsStream.subtracting([.hasUnreadMessages, .hasUnreadHighPriorityMessages])
            }
        }

        if let sdm = SIMSSelfDestructMessage.mr_findFirst(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSSelfDestructMessage.messageGuid), rightExpression: NSExpression(forConstantValue: messageGuid)), in: localContext) {
            sdm.mr_deleteEntity(in: localContext)
        }
        message.mr_deleteEntity(in: localContext)
    }

    public func deleteMessageForStream(_ messageGuid: String) {
        self.saveWithBlock { (localContext: NSManagedObjectContext) in

            if let message = SIMSMessage.findFirst(byGuid: messageGuid, in: localContext) {
                let stream = message.stream

                self.deleteMessage(message, in: localContext)

                if let messageStream = stream {
                    var hasUnreadMessages = false

                    if let msgLast = messageStream.messages?.lastObject as? SIMSMessage {
                        hasUnreadMessages = msgLast.attributes?.dateReadLocal == nil
                    }

                    if hasUnreadMessages == false {
                        messageStream.optionsStream = messageStream.optionsStream.subtracting([.hasUnreadMessages, .hasUnreadHighPriorityMessages])
                    }
                }
            } else if let message = SIMSMessageToSend.findFirst(byGuid: messageGuid, in: localContext) {
                self.deleteMessage(message, in: localContext)
            }
        }
    }
}
