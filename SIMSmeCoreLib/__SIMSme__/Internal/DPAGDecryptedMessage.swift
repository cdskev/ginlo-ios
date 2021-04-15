//
//  DPAGDecryptedMessage.swift
//  SIMSme
//
//  Created by RBU on 03/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import UIKit

public struct DPAGChatStreamCellStateImage {
    public let image: UIImage?
    public let tintColor: UIColor?
    public let accessibilityIdentifier: String
}

public enum DPAGChatStreamCellState: UInt {
    case sent,
        downloaded,
        read,
        failed,
        notSent

    public func statusImageAndTintColor() -> DPAGChatStreamCellStateImage? {
        switch self {
            case .sent:
                return DPAGChatStreamCellStateImage(image: DPAGImageProvider.shared[.kImageSendStateSent], tintColor: nil, accessibilityIdentifier: "cellStateSent")
            case .downloaded:
                return DPAGChatStreamCellStateImage(image: DPAGImageProvider.shared[.kImageSendStateReceived], tintColor: nil, accessibilityIdentifier: "cellStateReceived")
            case .read:
                return DPAGChatStreamCellStateImage(image: DPAGImageProvider.shared[.kImageSendStateRead], tintColor: DPAGColorProvider.shared[.imageSendStateReadTint], accessibilityIdentifier: "cellStateRead")
            case .failed:
                return DPAGChatStreamCellStateImage(image: DPAGImageProvider.shared[.kImageSendStateFailed], tintColor: DPAGColorProvider.shared[.imageSendStateFailedTint], accessibilityIdentifier: "cellStateFailed")
            default:
                return nil
        }
    }
}

public protocol DPAGCellWithProgress: AnyObject {
    var downloadCompletionBackground: DPAGCompletion? { get set }

    func showWorkInProgress()
    func updateDownloadProgress(_ progress: Progress, isAutoDownload: Bool)
    func cancelWorkInProgress()
    func hideWorkInProgress()
    func hideWorkInProgressWithCompletion(_ completion: @escaping DPAGCompletion)
}

public class DPAGDecryptedMessage: NSObject {
    public var messageType: DPAGMessageType = .unknown
    public var contentType: DPAGMessageContentType = .plain
    public var errorType: DPAGMessageSecurityError = .notChecked

    public var fromAccountGuid: String = "unknown"
    public var content: String?
    public var contentDesc: String?
    public var nickName: String?
    public var phone: String?
    public var profilKey: String?

    public var isOwnMessage: Bool = true
    public var isSent: Bool = false
    public var isReadLocal: Bool = false
    public var isReadServer: Bool = false
    public var isDownloaded: Bool = false
    public var isReadServerAttachment: Bool = false
    public var isDownloadedAttachment: Bool = false

    public var dateReadServer: Date?
    public var dateReadLocal: Date?
    public var dateDownloaded: Date?
    public var dateSendLocal: Date?
    public var dateSendServer: Date?

    public var sendOptions: DPAGSendMessageItemOptions?

    public var messageGuid: String
    public var streamGuid: String?
    public var encAesKey: String?
    public var encIv: String?
    public var decryptedAttachment: DPAGDecryptedAttachment?
    public var attachmentGuid: String?
    public var attachmentHash: String?
    public var attachmentProgress: Double = 0
    public weak var cellWithProgress: DPAGCellWithProgress?

    public var isSystemGenerated: Bool = false
    public var contentParsed: NSAttributedString?

    public var imagePreview: Data?
    public var additionalData: DPAGMessageDictionaryAdditionalData?

    public var sendingState: DPAGMessageState = .undefined
    public var confidenceState = DPAGConfidenceState.none

    public var attributedText: String?
    public var rangesWithLink: [NSTextCheckingResult]?

    public var rangeLineBreak: NSRange?

    public var isHighPriorityMessage = false

    public var recipients: [DPAGMessageRecipient] = []

    public var citationContent: DPAGCitationContent?

    public var vcardAccountID: String?
    public var vcardAccountGuid: String?

    fileprivate var cellHeightDictionary: [String: [NSValue: CGFloat]] = [:]

    public init(messageGuid: String, contentType type: String?) {
        self.messageGuid = messageGuid

        super.init()

        self.setType(type)
    }

    // Soll das Bild automatisch gesichert werden
    public func shouldSaveAutomatic() -> Bool {
        false
    }

    public func updateAttachmentProgress(withProgress progress: Progress, isAutoDownload: Bool) {
        if self.cellWithProgress != nil, self.attachmentProgress != progress.fractionCompleted {
            self.attachmentProgress = progress.fractionCompleted
            DispatchQueue.main.async { [weak self] in
                self?.cellWithProgress?.updateDownloadProgress(progress, isAutoDownload: isAutoDownload)
            }
        }
    }

    public var messageDate: Date? {
        self.isOwnMessage ? self.dateSendLocal : self.dateSendServer
    }

    func statusImageAndTintColor() -> DPAGChatStreamCellStateImage? {
        switch self.sendingState {
            case .sentFailed:
                return DPAGChatStreamCellStateImage(image: DPAGImageProvider.shared[.kImageSendStateFailed], tintColor: DPAGColorProvider.shared[.imageSendStateFailedTint], accessibilityIdentifier: "cellStateFailed")
            case .sentSucceeded:
                if self.isReadServer {
                    return DPAGChatStreamCellStateImage(image: DPAGImageProvider.shared[.kImageSendStateRead], tintColor: DPAGColorProvider.shared[.imageSendStateReadTint], accessibilityIdentifier: "cellStateRead")
                } else if self.isDownloaded {
                    return DPAGChatStreamCellStateImage(image: DPAGImageProvider.shared[.kImageSendStateReceived], tintColor: nil, accessibilityIdentifier: "cellStateReceived")
                } else if self.isSent {
                    if self.dateSendServer == nil, self.dateSendLocal?.isInFuture ?? false {
                        return DPAGChatStreamCellStateImage(image: DPAGImageProvider.shared[.kImageChatPreviewTimedMessage], tintColor: DPAGColorProvider.shared[.imageSendDelayedTint], accessibilityIdentifier: "cellStateTimed")
                    }
                    return DPAGChatStreamCellStateImage(image: DPAGImageProvider.shared[.kImageSendStateSent], tintColor: nil, accessibilityIdentifier: "cellStateSent")
                }
                return nil // DPAGImageProvider.shared[.kImageSendStateFailed]
            case .undefined:
                return DPAGChatStreamCellStateImage(image: DPAGImageProvider.shared[.kImageChatPreviewTimedMessage], tintColor: DPAGColorProvider.shared[.imageSendDelayedTint], accessibilityIdentifier: "cellStateTimed")
            case .sending:
                return nil
        }
    }

    func previewText(textSendFailed: String, textSent: String, textReceived: String) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [:]

        if self.isOwnMessage {
            if self.sendingState == .sentFailed {
                return NSAttributedString(string: textSendFailed, attributes: attributes)
            } else if let contentDesc = self.contentDesc, contentDesc.isEmpty == false {
                return NSAttributedString(string: contentDesc, attributes: attributes)
            }
            return NSAttributedString(string: textSent, attributes: attributes)
        } else if let contentDesc = self.contentDesc, contentDesc.isEmpty == false {
            return NSAttributedString(string: contentDesc, attributes: attributes)
        }
        return NSAttributedString(string: textReceived, attributes: attributes)
    }
}

public class DPAGDecryptedMessagePrivate: DPAGDecryptedMessage {
    public var isSystemChat = false
    public var textColorNick: UIColor?
    public var contactName: String?
    public var contactGuid: String?

    // Soll das Bild automatisch gesichert werden
    override public func shouldSaveAutomatic() -> Bool {
        true
    }
}

public class DPAGDecryptedMessageGroup: DPAGDecryptedMessage {
    public var textColorNick: UIColor?
    public var contactName: String?
    public var contactGuid: String?
    public var groupType: DPAGGroupType = .default
    public var contactReadOnly: Bool = false

    // Soll das Bild automatisch gesichert werden
    override public func shouldSaveAutomatic() -> Bool {
        true
    }
}

public class DPAGDecryptedMessageChannel: DPAGDecryptedMessage {
    public var channelGuid: String = ""
    public var serviceID: String = ""
    public internal(set) var feedType: DPAGChannelType = .channel
    public var section: String?

    public var colorChatMessageSectionPre: UIColor?
    public var colorChatMessageSection: UIColor?

    public var contentLinkReplacer: String?
    public var contentLinkReplacerRegex: [DPAGContentLinkReplacerRegex] = []
}

public extension DPAGDecryptedMessage {
    var isSelfDestructive: Bool {
        self.sendOptions?.countDownSelfDestruction != nil || self.sendOptions?.dateSelfDestruction != nil
    }

    func preferredCellHeightForTableSize(_ tableSize: CGSize, category: UIContentSizeCategory) -> CGFloat {
        let key = "\(category)"
        if let cellHeight = self.cellHeightDictionary[key]?[NSValue(cgSize: tableSize)] {
            return cellHeight
        }
        return 0
    }

    func resetPreferredCellHeights() {
        self.cellHeightDictionary.removeAll()
    }

    func setPreferredCellHeight(_ height: CGFloat, forTableSize tableSize: CGSize, preferredContentSizeCategory: UIContentSizeCategory) {
        let key = "\(preferredContentSizeCategory)"
        var dict = self.cellHeightDictionary[key] ?? [:]
        dict[NSValue(cgSize: tableSize)] = height
        self.cellHeightDictionary[key] = dict
    }

    fileprivate func setType(_ typeIn: String?) {
        self.contentType = DPAGMessageContentType.contentType(for: typeIn)
    }

    internal func decryptedAttachment(in stream: SIMSMessageStream?) -> DPAGDecryptedAttachment? {
        guard let attachmentGuid = self.attachmentGuid else { return nil }
        let decryptedAttachment = DPAGDecryptedAttachment(attachmentGuid: attachmentGuid, messageGuid: self.messageGuid)
        if let imagePreview = self.imagePreview {
            decryptedAttachment.thumb = UIImage(data: imagePreview)
        } else if self.contentType != .file, let content = self.content {
            if let imageData = Data(base64Encoded: content, options: .ignoreUnknownCharacters) {
                decryptedAttachment.thumb = UIImage(data: imageData)
            }
        }
        decryptedAttachment.isOwnMessage = self.isOwnMessage
        decryptedAttachment.isReadLocal = self.isReadLocal
        decryptedAttachment.isReadServer = self.isReadServerAttachment
        decryptedAttachment.encAesKey = self.encAesKey
        decryptedAttachment.encIv = self.encIv
        decryptedAttachment.attachmentType = self.getAttachmentType(for: self.contentType)
        decryptedAttachment.attachmentHash = self.attachmentHash
        decryptedAttachment.messageType = self.messageType
        decryptedAttachment.additionalData = self.additionalData
        decryptedAttachment.messageDate = self.messageDate
        decryptedAttachment.streamGuid = self.streamGuid
        decryptedAttachment.fromAccountGuid = self.fromAccountGuid
        if self.isOwnMessage {
            decryptedAttachment.contactName = DPAGApplicationFacade.cache.contact(for: self.fromAccountGuid)?.nickName
        } else {
            if self.messageType == .private {
                decryptedAttachment.contactName = DPAGApplicationFacade.cache.contact(for: self.fromAccountGuid)?.displayName
            } else if self.messageType == .group {
                decryptedAttachment.contactName = DPAGApplicationFacade.cache.contact(for: self.fromAccountGuid)?.displayName
            } else if self.messageType == .channel {
                decryptedAttachment.contactName = (stream as? SIMSChannelStream)?.channel?.name_short
            }
        }
        return decryptedAttachment
    }

    func updateDownloaded(withDate dateDownload: Date) {
        self.isDownloaded = true
        self.dateDownloaded = dateDownload
    }

    internal func updateDownloaded(withDate dateDownload: Date, recipients: Set<SIMSMessageReceiver>) {
        var isDownloaded = true
        for recipient in recipients {
            isDownloaded = isDownloaded && (recipient.dateDownloaded != nil)
            if let recipientDec = self.recipients.first(where: { $0.contactGuid == recipient.contactIndexEntry?.guid }) {
                recipientDec.dateDownloaded = recipient.dateDownloaded
            }
        }
        self.isDownloaded = isDownloaded
        if isDownloaded {
            self.dateDownloaded = dateDownload
        }
    }

    func updateRead(withDate dateRead: Date) {
        self.isReadServer = true
        self.dateReadServer = dateRead
    }

    func updateReadLocal(withDate dateRead: Date) {
        self.isReadLocal = true
        self.dateReadLocal = dateRead
    }

    internal func updateRead(withDate dateRead: Date, recipients: Set<SIMSMessageReceiver>) {
        var isRead = true
        for recipient in recipients {
            isRead = isRead && (recipient.dateRead != nil)
            if let recipientDec = self.recipients.first(where: { $0.contactGuid == recipient.contactIndexEntry?.guid }) {
                recipientDec.dateRead = recipient.dateRead
            }
        }
        self.isReadServer = isRead
        if isRead {
            self.dateReadServer = dateRead
        }
    }

    internal func update(withRecipients recipients: Set<SIMSMessageReceiver>) {
        var isDownloaded = true
        var isRead = true
        self.recipients.removeAll()
        for recipient in recipients {
            if let contactGuid = recipient.contactIndexEntry?.guid {
                self.recipients.append(DPAGMessageRecipient(contactGuid: contactGuid, sendsReadConfirmation: recipient.sendsReadConfirmation?.boolValue ?? false, dateRead: recipient.dateRead, dateDownloaded: recipient.dateDownloaded))
            }
            isDownloaded = isDownloaded && (recipient.dateDownloaded != nil)
            isRead = isRead && (recipient.dateRead != nil)
        }
        self.isReadServer = isRead
        self.isDownloaded = isDownloaded
    }

    func getAttachmentType(for contentType: DPAGMessageContentType) -> DPAGAttachmentType {
        switch contentType {
            case .plain:
                return DPAGAttachmentType.image
            case .image:
                return DPAGAttachmentType.image
            case .voiceRec:
                return DPAGAttachmentType.voiceRec
            case .file:
                return DPAGAttachmentType.file
            default:
                return DPAGAttachmentType.video
        }
    }

    func markDecryptedMessageAsReadAttachment() {
        if self.isReadServerAttachment || self.isOwnMessage {
            return
        }
        var streamGuid: String?
        if self is DPAGDecryptedMessagePrivate {
            streamGuid = self.fromAccountGuid
        } else if let decGroup = self as? DPAGDecryptedMessageGroup {
            streamGuid = decGroup.streamGuid
        }
        guard let chatGuid = streamGuid else { return }
        if Thread.isMainThread == false {
            DPAGApplicationFacade.messageWorker.markMessageAsReadAttachment(messageGuid: self.messageGuid, chatGuid: chatGuid, messageType: self.messageType)
        } else {
            self.performBlockInBackground { [weak self] in
                guard let strongSelf = self else { return }
                DPAGApplicationFacade.messageWorker.markMessageAsReadAttachment(messageGuid: strongSelf.messageGuid, chatGuid: chatGuid, messageType: strongSelf.messageType)
            }
        }
    }

    var statusCode: DPAGChatStreamCellState {
        var state: DPAGChatStreamCellState = .notSent
        let sendingState = self.sendingState
        if sendingState == .sentFailed {
            state = .failed
        } else if sendingState == .sentSucceeded {
            state = .sent
            if self.isReadServer {
                state = .read
            } else if self.isDownloaded {
                state = .downloaded
            }
        }
        return state
    }
}
