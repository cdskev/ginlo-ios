//
//  DPAGSendMessageOptions.swift
//  SIMSmeCore
//
//  Created by RBU on 03.08.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

public enum DPAGSendMessageOptionsViewMode: Int {
    case unknown,
        selfDestructCountDown,
        selfDestructDate,
        sendTime,
        highPriority
}

public class DPAGSendMessageOptions: NSObject {
    public var countDownSelfDestruction: TimeInterval?
    public var dateSelfDestruction: Date?
    public var dateToBeSend: Date?

    override fileprivate init() {
        super.init()
    }

    public var timerLabelDestructionCell: String {
        var resultString: String?

        if let countDownSelfDestruction = self.countDownSelfDestruction {
            var localizedString: String

            if countDownSelfDestruction > 1 {
                localizedString = DPAGLocalizedString("chats_selfdestruction_countdown_seconds")
            } else {
                localizedString = DPAGLocalizedString("chats_selfdestruction_countdown_second")
            }
            resultString = String(format: "%.0f %@", countDownSelfDestruction, localizedString)
        } else if let dateSelfDestruction = self.dateSelfDestruction {
            resultString = DateFormatter.localizedString(from: dateSelfDestruction, dateStyle: .short, timeStyle: .short)
        }

        return resultString ?? ""
    }

    public var timerLabelSendTimeCell: String {
        if let dateToBeSend = self.dateToBeSend {
            return DateFormatter.localizedString(from: dateToBeSend, dateStyle: .short, timeStyle: .short)
        }
        return ""
    }

    public func destructionDateForCountdown(messageGuid: String) -> Date? {
        var newDate: Date?

        if let countDownSelfDestruction = self.countDownSelfDestruction {
            if AppConfig.isShareExtension {
                let aTimeInterval = Date().timeIntervalSinceReferenceDate + countDownSelfDestruction

                newDate = Date(timeIntervalSinceReferenceDate: aTimeInterval)
            } else {
                if let sdm = SIMSSelfDestructMessage.mr_findFirst(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSSelfDestructMessage.messageGuid), rightExpression: NSExpression(forConstantValue: messageGuid))) {
                    newDate = sdm.dateDestruction
                } else {
                    let aTimeInterval = Date().timeIntervalSinceReferenceDate + countDownSelfDestruction

                    newDate = Date(timeIntervalSinceReferenceDate: aTimeInterval)
                }
            }
        } else {
            newDate = self.dateSelfDestruction
        }

        return newDate
    }
}

public class DPAGSendMessageItemOptions: DPAGSendMessageOptions {
    init(countDownSelfDestruction: TimeInterval?, dateSelfDestruction: Date?, dateToBeSend: Date?) {
        super.init()
        self.countDownSelfDestruction = countDownSelfDestruction
        self.dateSelfDestruction = dateSelfDestruction
        self.dateToBeSend = dateToBeSend
    }
}

public class DPAGSendMessageSendOptions: DPAGSendMessageOptions {
    public var messagePriorityHigh = false
    public var attachmentIsInternalCopy = false
    public var messageGuidCitation: String?

    public init(countDownSelfDestruction: TimeInterval?, dateSelfDestruction: Date?, dateToBeSend: Date?, messagePriorityHigh: Bool) {
        super.init()
        self.countDownSelfDestruction = countDownSelfDestruction
        self.dateSelfDestruction = dateSelfDestruction
        self.dateToBeSend = dateToBeSend

        self.messagePriorityHigh = messagePriorityHigh
    }

    override public func copy() -> Any {
        let retVal = DPAGSendMessageSendOptions(countDownSelfDestruction: self.countDownSelfDestruction, dateSelfDestruction: self.dateSelfDestruction, dateToBeSend: self.dateToBeSend, messagePriorityHigh: self.messagePriorityHigh)

        retVal.attachmentIsInternalCopy = self.attachmentIsInternalCopy
        retVal.messageGuidCitation = self.messageGuidCitation

        return retVal
    }
}

public class DPAGSendMessageViewOptions: DPAGSendMessageOptions {
    public static let sharedInstance = DPAGSendMessageViewOptions()

    public private(set) var selfDestructionEnabled: Bool?
    public private(set) var sendTimeEnabled: Bool?

    public private(set) var messagePriorityHigh = false

    public var messageGuidCitation: String?

    public var sendOptionsViewMode: DPAGSendMessageOptionsViewMode = .unknown

    public func reset() {
        self.selfDestructionEnabled = false
        self.sendTimeEnabled = false
        self.countDownSelfDestruction = nil
        self.dateSelfDestruction = nil
        self.dateToBeSend = nil
        self.sendOptionsViewMode = .unknown
        self.messagePriorityHigh = false
        self.messageGuidCitation = nil
    }

    public func switchHighPriority() {
        self.messagePriorityHigh = !self.messagePriorityHigh
    }

    public func switchSelfDestruction() {
        let selfDestructionEnabledBefore = self.selfDestructionEnabled ?? false
        var selfDestructionEnabledAfter = selfDestructionEnabledBefore

        if self.selfDestructionEnabled == nil {
            selfDestructionEnabledAfter = true
        } else {
            selfDestructionEnabledAfter = !selfDestructionEnabledBefore

            if selfDestructionEnabledAfter == false {
                self.dateSelfDestruction = nil
                self.countDownSelfDestruction = nil
            }
        }

        self.selfDestructionEnabled = selfDestructionEnabledAfter

        if selfDestructionEnabledAfter {
            if self.countDownSelfDestruction != nil {
                self.sendOptionsViewMode = .selfDestructCountDown
            } else if self.dateSelfDestruction != nil {
                self.sendOptionsViewMode = .selfDestructDate

                if selfDestructionEnabledBefore == false {
                    let nextDate = Date().addingMinutes(1)

                    self.dateSelfDestruction = nextDate
                }
            } else {
                self.countDownSelfDestruction = TimeInterval(1)
                self.sendOptionsViewMode = .selfDestructCountDown
            }
        } else {
            self.sendOptionsViewMode = (self.sendTimeEnabled ?? false) ? .sendTime : .unknown
        }
    }

    public func switchSelfDestructionToCountDown(_ isCountDown: Bool) {
        if isCountDown {
            if self.countDownSelfDestruction == nil {
                self.countDownSelfDestruction = 1
            }
            self.dateSelfDestruction = nil
            self.sendOptionsViewMode = .selfDestructCountDown
        } else {
            self.countDownSelfDestruction = nil

            if self.dateSelfDestruction == nil {
                let nextDate = Date().addingMinutes(1)

                self.dateSelfDestruction = nextDate
            }
            self.sendOptionsViewMode = .selfDestructDate
        }
    }

    public func switchSendTimed() {
        let sendTimeEnabledBefore = self.sendTimeEnabled ?? false

        if self.sendTimeEnabled == nil {
            self.sendTimeEnabled = true
        } else {
            self.sendTimeEnabled = !sendTimeEnabledBefore

            if self.sendTimeEnabled == false {
                self.dateToBeSend = nil
            }
        }

        if sendTimeEnabledBefore == false {
            let nextDate = Date().addingMinutes(1)
            let cal = Calendar.current

            var dc = cal.dateComponents([.era, .year, .month, .day, .hour, .minute], from: nextDate)

            dc.second = 0

            self.dateToBeSend = cal.date(from: dc)
        }

        self.sendOptionsViewMode = (self.sendTimeEnabled ?? false) ? .sendTime : ((self.selfDestructionEnabled ?? false) ? (self.countDownSelfDestruction != nil ? .selfDestructCountDown : .selfDestructDate) : .unknown)
    }
}

public class DPAGSendMessageRecipient {
    public static let NULL_RECEIVER = DPAGSendMessageRecipient(recipientGuid: "")

    public let recipientGuid: String

    public var tempDeviceGuid: String?
    public var tempDevicePublicKey: String?

    public var contact: DPAGContact?

    public init(recipientGuid: String) {
        self.recipientGuid = recipientGuid

        if AppConfig.isShareExtension == false {
            self.contact = DPAGApplicationFacade.cache.contact(for: recipientGuid)
        }
    }

    public var isGroup: Bool {
        recipientGuid.hasPrefix(DPAGGuidPrefix.streamGroup)
    }

    public func setTempDevice(guid: String, publicKey: String) {
        self.tempDeviceGuid = guid
        self.tempDevicePublicKey = publicKey
    }
}
