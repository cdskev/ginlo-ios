//
//  SIMSMessageToSend.swift
//  SIMSme
//
//  Created by RBU on 02/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSMessageToSend: SIMSManagedObjectMessage {
    @NSManaged var dateCreated: Date?
    @NSManaged var dateToSend: Date?
    @NSManaged var additionalData: String?
    @NSManaged var streamGuid: String?

    // Insert code here to add functionality to your managed object subclass

    @objc
    public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.MESSAGE_TO_SEND
    }

    static var sectionFormatter: DateFormatter = {
        let formatter = DateFormatter()

        formatter.doesRelativeDateFormatting = true

        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    static var sectionFormatterStatic: DateFormatter = {
        let formatter = DateFormatter()

        formatter.dateFormat = "yyyy-MM-dd"

        return formatter
    }()

    func refreshSectionTitle() {
        let sectionDate = self.dateToSend ?? Date()

        let tmp = DPAGFormatter.messageSectionDateRelativ.string(from: sectionDate)

        self.willChangeValue(forKey: "sectionTitle")
        self.setPrimitiveValue(tmp, forKey: "sectionTitle")
        self.didChangeValue(forKey: "sectionTitle")
    }

    @objc var sectionTitle: String {
        // Create and cache the section identifier on demand.

        self.willAccessValue(forKey: "sectionTitle")
        var tmp: String? = self.primitiveValue(forKey: "sectionTitle") as? String
        self.didAccessValue(forKey: "sectionTitle")

        if tmp == nil {
            let sectionDate = self.dateToSend ?? Date()

            tmp = DPAGFormatter.messageSectionDateRelativ.string(from: sectionDate)

            self.setPrimitiveValue(tmp, forKey: "sectionTitle")
        }
        return tmp ?? "-"
    }

    var sectionTitleDate: String {
        let sectionDate = self.dateToSend ?? Date()

        let tmp = DPAGFormatter.messageSectionDate.string(from: sectionDate)

        return tmp
    }

    var sendingStateValid: DPAGMessageState {
        DPAGMessageState(rawValue: self.sendingState.uintValue) ?? .undefined
    }

    func decryptedMessageDictionary(in localContext: NSManagedObjectContext) -> DPAGMessageDictionary? {
        var decryptedDictionary: DPAGMessageDictionary?

        if let groupMessage = self as? SIMSMessageToSendGroup, let groupStream = SIMSMessageStream.findFirst(byGuid: groupMessage.streamGuid, in: localContext) as? SIMSGroupStream {
            if let decAesKey = groupStream.group?.aesKey {
                decryptedDictionary = DPAGApplicationFacade.messageCryptoWorker.decryptGroupMessageToSendDict(groupMessage, decAesKey: decAesKey)
            }
        } else if let privateMessage = self as? SIMSMessageToSendPrivate {
            decryptedDictionary = DPAGApplicationFacade.messageCryptoWorker.decryptOwnMessageToSendDict(privateMessage)
        }

        return decryptedDictionary
    }
}
