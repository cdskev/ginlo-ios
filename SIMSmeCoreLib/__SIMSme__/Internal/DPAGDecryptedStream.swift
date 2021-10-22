//
//  DPAGDecryptedStream.swift
// ginlo
//
//  Created by RBU on 03/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

public struct DPAGDecryptedStreamPreviewTextItem {
    public let attributedString: NSAttributedString
    public let tintColor: UIColor?
    public private(set) var spacerPre: Bool = false
    public private(set) var spacerPost: Bool = false
}

public class DPAGDecryptedStream: NSObject {
    public var guid: String
    public var type: DPAGStreamType = .unknown
    public var lastMessageDateFormatted: String?
    public var newMessagesCount = 0

    public var previewText: [DPAGDecryptedStreamPreviewTextItem] = []

    public var colorUnreadMessagesBackground: UIColor?
    public var colorUnreadMessagesText: UIColor?

    public var hasUnreadHighPriorityMessages = false

    public init(guid: String) {
        self.guid = guid

        super.init()
    }

    public var name: String? {
        if AppConfig.isShareExtension {
            let cache = DPAGApplicationFacadeShareExt.cache

            if let decStreamPrivate = self as? DPAGDecryptedStreamPrivate, let contactGuid = decStreamPrivate.contactGuid, let contact = cache.contact(for: contactGuid) {
                return contact.displayName
            } else if let decStreamGroup = self as? DPAGDecryptedStreamGroup, let group = cache.group(for: decStreamGroup.guid) {
                return group.name
            } else if let decStreamChannel = self as? DPAGDecryptedStreamChannel {
                return decStreamChannel.streamName
            }
        } else {
            let cache = DPAGApplicationFacade.cache

            if let decStreamPrivate = self as? DPAGDecryptedStreamPrivate, let contactGuid = decStreamPrivate.contactGuid, let contact = cache.contact(for: contactGuid) {
                return contact.displayName
            } else if let decStreamGroup = self as? DPAGDecryptedStreamGroup, let group = cache.group(for: decStreamGroup.guid) {
                return group.name
            } else if let decStreamChannel = self as? DPAGDecryptedStreamChannel {
                return decStreamChannel.streamName
            }
        }

        return nil
    }

    public func isSearchResult(searchText: String) -> Bool {
        self.name?.lowercased().contains(searchText.lowercased()) ?? false
    }
}

public class DPAGDecryptedStreamPrivate: DPAGDecryptedStream {
    public var isSystemChat = false
    public var contactGuid: String?

    public var lastOnlineDate: Date?
    public var oooState = false

    override public init(guid: String) {
        super.init(guid: guid)

        self.type = .single
    }

    init(contactStream: DPAGSharedContainerExtensionSending.ContactStream) {
        super.init(guid: contactStream.guid)

        self.type = .single

        self.contactGuid = contactStream.contactGuid
    }
}

public class DPAGDecryptedStreamGroup: DPAGDecryptedStream {
    public var streamName: String?
    public var streamState: DPAGChatStreamState = .readOnly

    override public init(guid: String) {
        super.init(guid: guid)

        self.type = .group
    }
}

public class DPAGDecryptedStreamChannel: DPAGDecryptedStream {
    public var streamName: String?
    public var streamNameLong: String?
    public var colorBackground: UIColor?
    public var imageBackground: UIImage?
    public var imageForeground: UIImage?
    public var imageIcon: UIImage?
    public var colorDate: UIColor?
    public var colorPreview: UIColor?
    public var colorName: UIColor?

    public var mandatory: Bool = false

    public var feedType: DPAGChannelType = .channel

    override public init(guid: String) {
        super.init(guid: guid)

        self.type = .channel
    }

    override public func isSearchResult(searchText: String) -> Bool {
        super.isSearchResult(searchText: searchText) || (self.streamNameLong?.lowercased().contains(searchText.lowercased()) ?? false)
    }
}
