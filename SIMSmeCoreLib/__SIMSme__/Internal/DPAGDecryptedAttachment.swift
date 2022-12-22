//
//  DPAGDecryptedAttachment.swift
// ginlo
//
//  Created by RBU on 03/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

public class DPAGDecryptedAttachment: NSObject {
    public var attachmentType: DPAGAttachmentType = .unknown
    public var messageType: DPAGMessageType = .unknown
    public var isOwnMessage: Bool = false
    public var isReadServer: Bool = false
    public var isReadLocal: Bool = false
    var encAesKey: String?
    var encIv: String?
    public var attachmentGuid: String
    var attachmentHash: String?
    public var messageGuid: String
    public var streamGuid: String?
    public var fromAccountGuid: String?
    public var messageDate: Date?
    public var thumb: UIImage?
    public var contactName: String?
    public var additionalData: DPAGMessageDictionaryAdditionalData?

    init(attachmentGuid: String, messageGuid: String) {
        self.attachmentGuid = attachmentGuid
        self.messageGuid = messageGuid

        super.init()
    }

    func markAttachmentAsRead() {
        guard self.isReadServer == false, self.isOwnMessage == false else {
            return
        }

        var chatGuid: String?

        if self.messageType == .private {
            chatGuid = self.fromAccountGuid
        } else if self.messageType == .group {
            chatGuid = self.streamGuid
        }

        if let chatGuid = chatGuid {
            if Thread.isMainThread == false {
                DPAGApplicationFacade.messageWorker.markMessageAsReadAttachment(messageGuid: self.messageGuid, chatGuid: chatGuid, messageType: self.messageType)
            } else {
                let messageGuid = self.messageGuid
                let messageType = self.messageType

                self.performBlockInBackground {
                    DPAGApplicationFacade.messageWorker.markMessageAsReadAttachment(messageGuid: messageGuid, chatGuid: chatGuid, messageType: messageType)
                }
            }
        }
    }
}

public protocol DPAGMediaViewAttachmentProtocol: AnyObject {
    var messageGuid: String { get }
    var decryptedAttachment: DPAGDecryptedAttachment? { get }
}

public class DPAGMediaViewAttachment: DPAGMediaViewAttachmentProtocol {
    public let messageGuid: String
    public private(set) var decryptedAttachment: DPAGDecryptedAttachment?

    public init(messageGuid: String, decryptedAttachment: DPAGDecryptedAttachment? = nil) {
        self.messageGuid = messageGuid
        self.decryptedAttachment = decryptedAttachment
    }
}
