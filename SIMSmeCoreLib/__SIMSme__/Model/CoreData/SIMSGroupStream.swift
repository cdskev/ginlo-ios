//
//  SIMSGroupStream.swift
// ginlo
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSGroupStream: SIMSMessageStream {
    @NSManaged public var group: SIMSGroup?

    // Insert code here to add functionality to your managed object subclass

    @objc
    override public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.STREAM_GROUP
    }

    override func countNewMessages() -> Int {
        let numNewMessages = super.countNewMessages()

        return numNewMessages
    }

    var streamState: DPAGChatStreamState {
        var streamState: DPAGChatStreamState = .read

        let isReadOnlyOption = self.optionsStream.contains(.isReadOnly)
        let isDeleted = (self.wasDeleted?.boolValue ?? false)
        let isNotConfirmed = (self.isConfirmed?.boolValue ?? false) == false

        streamState = (isReadOnlyOption || isDeleted || isNotConfirmed) ? .readOnly : .write

        if let group = self.group, group.typeGroup == .restricted {
            if let ownAccountGuid = DPAGApplicationFacade.cache.account?.guid {
                if group.writerGuids.contains(ownAccountGuid) == false {
                    streamState = .readOnly
                }
            }
        }

        return streamState
    }

    var groupAesKey: String? {
        if let aesKeyXMLString = self.group?.aesKey {
            if let decAesKeyDict = try? XMLReader.dictionary(forXMLString: aesKeyXMLString) {
                return decAesKeyDict["key"] as? String
            }
        }
        return nil
    }
}
