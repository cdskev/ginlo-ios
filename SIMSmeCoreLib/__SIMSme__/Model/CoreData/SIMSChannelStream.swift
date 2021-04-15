//
//  SIMSChannelStream.swift
//  SIMSme
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSChannelStream: SIMSMessageStream {
    @NSManaged var channel: SIMSChannel?

    // Insert code here to add functionality to your managed object subclass

    @objc
    override public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.STREAM_CHANNEL
    }

    var streamState: DPAGChatStreamState {
        // if ([self.channel isReadOnly] || [self wasDeleted])
        // {
        return .readOnly
        // }

        // return DPAGChatStreamWriteState
    }

    override func countNewMessages() -> Int {
        let numNewMessages = super.countNewMessages()

        return numNewMessages
    }
}
