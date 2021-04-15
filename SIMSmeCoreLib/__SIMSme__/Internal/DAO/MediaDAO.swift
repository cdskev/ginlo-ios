//
//  MediaDAO.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 07.08.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

protocol MediaDAOProtocol {
    func loadMediaViewAttachments(selectedMediaType: DPAGMediaSelectionOptions, allFileAttachmentGuids: [String]) -> [DPAGDecryptedAttachment]

    func loadFileViewAttachments(allFileAttachmentGuids: [String]) -> [DPAGDecryptedAttachment]
}

class MediaDAO: MediaDAOProtocol {
    func loadMediaViewAttachments(selectedMediaType: DPAGMediaSelectionOptions, allFileAttachmentGuids: [String]) -> [DPAGDecryptedAttachment] {
        var attachments: [DPAGDecryptedAttachment] = []

        do {
            try DPAGApplicationFacade.persistance.saveWithError { localContext in

                let attachmentPredicateToSend = NSCompoundPredicate(andPredicateWithSubpredicates:
                    [
                        NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageToSend.messageType), rightNotExpression: NSExpression(forConstantValue: DPAGMessageType.channel.rawValue)),
                        NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageToSend.attachment), rightNotExpression: NSExpression(forConstantValue: nil)),
                        NSPredicate(format: "attachment IN %@", allFileAttachmentGuids)
                    ])

                let attachmentPredicate = NSCompoundPredicate(andPredicateWithSubpredicates:
                    [
                        NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.messageType), rightNotExpression: NSExpression(forConstantValue: DPAGMessageType.channel.rawValue)),
                        NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.attachment), rightNotExpression: NSExpression(forConstantValue: nil)),
                        NSPredicate(format: "attachment IN %@", allFileAttachmentGuids)
                    ])

                var allMessages: [SIMSManagedObjectMessage] = []

                if let msgs = SIMSMessageToSend.mr_findAllSorted(by: "dateToSend", ascending: false, with: attachmentPredicateToSend, in: localContext) as? [SIMSManagedObjectMessage] {
                    allMessages += msgs
                }

                let msgs = try SIMSMessage.findAll(in: localContext, with: attachmentPredicate, sortDescriptors: [NSSortDescriptor(keyPath: \SIMSMessage.dateSendServer, ascending: false)])

                allMessages += msgs as [SIMSManagedObjectMessage]

                for message in allMessages {
                    guard let messageGuid = message.guid, messageGuid.hasPrefix(.temp) == false, message.sendingState.uintValue != DPAGMessageState.sentFailed.rawValue, message.sendingState.uintValue != DPAGMessageState.sending.rawValue else {
                        continue
                    }

                    guard let stream = (message as? SIMSMessage)?.stream ?? ((message as? SIMSMessageToSendPrivate)?.streamToSend(in: localContext) ?? (message as? SIMSMessageToSendGroup)?.streamToSend(in: localContext)) else {
                        continue
                    }

                    guard let decMessage = DPAGApplicationFacade.cache.decryptedMessage(message, in: localContext) else {
                        continue
                    }

                    guard !decMessage.isSelfDestructive || decMessage.isOwnMessage,
                        AttachmentHelper.attachmentAlreadySavedForGuid(decMessage.attachmentGuid),
                        (selectedMediaType.contains(.audio) && decMessage.contentType == .voiceRec)
                        || ((decMessage.contentType == .image
                                || (decMessage.contentType == .plain && decMessage.imagePreview != nil))
                            && selectedMediaType.contains(.imageVideo))
                        || (decMessage.contentType == .video
                            && selectedMediaType.contains(.imageVideo)) else {
                        continue
                    }

                    guard let decAttachment = decMessage.decryptedAttachment(in: stream) else {
                        continue
                    }

                    attachments.append(decAttachment)
                }
            }
        } catch {
            DPAGLog(error)
        }

        return attachments
    }

    func loadFileViewAttachments(allFileAttachmentGuids: [String]) -> [DPAGDecryptedAttachment] {
        var attachments: [DPAGDecryptedAttachment] = []

        do {
            try DPAGApplicationFacade.persistance.saveWithError { localContext in

                let attachmentPredicateToSend = NSCompoundPredicate(andPredicateWithSubpredicates:
                    [
                        NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageToSend.messageType), rightNotExpression: NSExpression(forConstantValue: DPAGMessageType.channel.rawValue)),
                        NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessageToSend.attachment), rightNotExpression: NSExpression(forConstantValue: nil)),
                        NSPredicate(format: "attachment IN %@", allFileAttachmentGuids)
                    ])

                let attachmentPredicate = NSCompoundPredicate(andPredicateWithSubpredicates:
                    [
                        NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.messageType), rightNotExpression: NSExpression(forConstantValue: DPAGMessageType.channel.rawValue)),
                        NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.attachment), rightNotExpression: NSExpression(forConstantValue: nil)),
                        NSPredicate(format: "attachment IN %@", allFileAttachmentGuids)
                    ])

                var allMessages: [SIMSManagedObjectMessage] = []

                if let msgs = SIMSMessageToSend.mr_findAllSorted(by: "dateToSend", ascending: false, with: attachmentPredicateToSend, in: localContext) as? [SIMSManagedObjectMessage] {
                    allMessages += msgs
                }

                let msgs = try SIMSMessage.findAll(in: localContext, with: attachmentPredicate, sortDescriptors: [NSSortDescriptor(keyPath: \SIMSMessage.dateSendServer, ascending: false)])

                allMessages += msgs as [SIMSManagedObjectMessage]

                for message in allMessages {
                    guard let messageGuid = message.guid, messageGuid.hasPrefix(.temp) == false, message.sendingState.uintValue != DPAGMessageState.sentFailed.rawValue, message.sendingState.uintValue != DPAGMessageState.sending.rawValue else {
                        continue
                    }

                    if let stream = (message as? SIMSMessage)?.stream ?? ((message as? SIMSMessageToSendPrivate)?.streamToSend(in: localContext) ?? (message as? SIMSMessageToSendGroup)?.streamToSend(in: localContext)) {
                        guard let decMessage = DPAGApplicationFacade.cache.decryptedMessage(message, in: localContext) else { return }

                        if !decMessage.isSelfDestructive || decMessage.isOwnMessage, AttachmentHelper.attachmentAlreadySavedForGuid(decMessage.attachmentGuid), decMessage.contentType == .file {
                            guard let decAttachment = decMessage.decryptedAttachment(in: stream) else { return }

                            attachments.append(decAttachment)
                        }
                    }
                }
            }
        } catch {
            DPAGLog(error)
        }

        return attachments
    }
}
