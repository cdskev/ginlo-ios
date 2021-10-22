//
//  SIMSMessage.swift
// ginlo
//
//  Created by RBU on 19/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

class SIMSMessage: SIMSManagedObjectMessage {
    @NSManaged var dateDownloaded: Date?
    @NSManaged var dateReadLocal: Date?
    @NSManaged var dateReadServer: Date?
    @NSManaged var dateSendLocal: Date?
    @NSManaged var dateSendServer: Date?
    @NSManaged var errorType: NSNumber?
    @NSManaged var fromAccountGuid: String?
    @NSManaged var hashes: String?
    @NSManaged var hashes256: String?
    @NSManaged var messageOrderId: NSNumber?
    @NSManaged var additionalData: String?
    @NSManaged var stream: SIMSMessageStream?
    @NSManaged var attributes: SIMSMessageAttributes?
    @NSManaged var receiver: Set<SIMSMessageReceiver>?

    // Insert code here to add functionality to your managed object subclass

    @objc
    public class func entityName() -> String {
        DPAGStrings.CoreData.Entities.MESSAGE
    }

    /*
     - (void) setSectionTitle:(NSString *)sectionTitle
     {
     [self willChangeValueForKey:@"sectionTitle"]
     [self setPrimitiveValue:sectionTitle forKey:@"sectionTitle"]
     [self didChangeValueForKey:@"sectionTitle"]
     }
     */

    func refreshSectionTitle() {
        let sectionDate = self.dateSendServer ?? Date()

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
            let sectionDate = self.dateSendServer ?? Date()

            tmp = DPAGFormatter.messageSectionDateRelativ.string(from: sectionDate)

            self.setPrimitiveValue(tmp, forKey: "sectionTitle")
        }
        return tmp ?? "-"
    }

    var sectionTitleDate: String {
        let sectionDate = self.dateSendServer ?? Date()

        let tmp = DPAGFormatter.messageSectionDate.string(from: sectionDate)

        return tmp
    }

    var sendingStateValid: DPAGMessageState {
        DPAGMessageState(rawValue: self.sendingState.uintValue) ?? .undefined
    }

    var additionalDataDict: [String: String]?
    var additionalDataDictChanged = false

    @discardableResult
    func getAdditionalData(key: String) -> String? {
        if self.additionalDataDict == nil {
            if let additionalData = self.additionalData, let additionalDataData = additionalData.data(using: .utf8) {
                do {
                    if let dict = try JSONSerialization.jsonObject(with: additionalDataData, options: []) as? [String: String] {
                        additionalDataDict = dict
                    }
                } catch {
                    DPAGLog(error, message: "JSON dictionary.data -> string failed")
                }
            }
            if self.additionalDataDict == nil {
                self.additionalDataDict = [:]
            }
        }
        return self.additionalDataDict?[key]
    }

    func setAdditionalData(key: String, value: String?) {
        if self.additionalDataDict == nil {
            self.getAdditionalData(key: key)
        }
        if let value = value {
            self.additionalDataDict?[key] = value
        } else {
            self.additionalDataDict?.removeValue(forKey: key)
        }
        self.additionalDataDictChanged = false
        self.additionalData = self.additionalDataDict?.JSONString
    }

    var isOwnMessage: Bool {
        self.fromAccountGuid == DPAGApplicationFacade.cache.account?.guid
    }

    func decryptedMessageDictionary() -> DPAGMessageDictionary? {
        if self.data == nil {
            return nil
        }

        var decryptedDictionary: DPAGMessageDictionary?

        switch self.typeMessage {
        case .private:
            if let privateMessage = self as? SIMSPrivateMessage {
                if privateMessage.fromKey == "DUMMY-DATA" {
                    DPAGLog("decryptedMessageDictionary nil for DUMMY-DATA", level: .warning)
                    return nil
                }
                decryptedDictionary = DPAGApplicationFacade.messageCryptoWorker.decryptMessageDict(privateMessage)
            }
        case .group:
            if let groupMessage = self as? SIMSGroupMessage {
                if let decAesKey = (groupMessage.stream as? SIMSGroupStream)?.group?.aesKey {
                    decryptedDictionary = DPAGApplicationFacade.messageCryptoWorker.decryptGroupMessageDict(groupMessage, decAesKey: decAesKey)
                }
            }
        case .channel:
            if let channelMessage = self as? SIMSChannelMessage, let channelStream = channelMessage.stream as? SIMSChannelStream {
                if let iv = channelStream.channel?.iv, let decAesKey = channelStream.channel?.aes_key {
                    let aesKeyDict = DPAGAesKeyDecrypted(aesKey: decAesKey, iv: iv)

                    decryptedDictionary = DPAGApplicationFacade.messageCryptoWorker.decryptChannelMessage(channelMessage, decAesKeyDict: aesKeyDict)
                }
            }
        case .unknown:
//            DPAGLog("decryptedMessageDictionary nil for message type unknown", level: .error)
            return nil
        }

        return decryptedDictionary
    }
}
