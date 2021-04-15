//
//  SetSilentHelper.swift
//  SIMSmeUILib
//
//  Created by Evgenii Kononenko on 25.04.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation
import SIMSmeCore

public enum SilentState {
    case none
    case date(date: Date)
    case permanent
}

public enum SetSilentHelperChatType {
    case group
    case single
}

public class SetSilentHelper: NSObject {
    public var chatType: SetSilentHelperChatType
    @objc public dynamic var silentStateChange = NSObject()

    public var currentSilentState: SilentState = .none {
        didSet {
            self.silentStateChange = NSObject()
        }
    }

    public var chatIdentifier: String?

    public init(chatType: SetSilentHelperChatType) {
        self.chatType = chatType
    }

    public static func silentStateFor(silentDate date: Date?) -> SilentState {
        if date == self.dateForPermanentSilentState() {
            return .permanent
        } else if let date = date {
            return .date(date: date)
        } else {
            return .none
        }
    }

    private static func dateForPermanentSilentState() -> Date? {
        DPAGFormatter.dateServer.date(from: "2100-01-01 00:00:00+0200")
    }

    // MARK: - DPAGSetSilentViewDelegate

    public func setSilentTill(_ minutes: Int, response responseBlock: @escaping DPAGServiceResponseBlock) {
        guard let chatIdentifier = self.chatIdentifier else { return }

        let currentSilentState: SilentState!
        let silentTill: Date!

        if minutes == -1 {
            silentTill = SetSilentHelper.dateForPermanentSilentState()
            currentSilentState = .permanent
        } else {
            silentTill = Date().addingMinutes(minutes)
            currentSilentState = .date(date: silentTill)
        }

        let setSilentResponseBlock: DPAGServiceResponseBlock = { [weak self] responseObject, errorCode, errorMessage in
            if errorMessage == nil {
                self?.currentSilentState = currentSilentState
            }
            responseBlock(responseObject, errorCode, errorMessage)
        }

        switch self.chatType {
        case .group:
            DPAGApplicationFacade.requestWorker
                .setSilentGroupChat(groupGuid: chatIdentifier, till: silentTill, withResponse: setSilentResponseBlock)
        case .single:
            DPAGApplicationFacade.requestWorker
                .setSilentSingleChat(accountGuid: chatIdentifier, till: silentTill, withResponse: setSilentResponseBlock)
        }
    }

    public func resetSilentTill(response responseBlock: @escaping DPAGServiceResponseBlock) {
        guard let chatIdentifier = self.chatIdentifier else { return }

        let resetSilentResponseBlock: DPAGServiceResponseBlock = { [weak self] responseObject, errorCode, errorMessage in
            if errorMessage == nil {
                self?.currentSilentState = .none
            }
            responseBlock(responseObject, errorCode, errorMessage)
        }

        switch self.chatType {
        case .group:
            DPAGApplicationFacade.requestWorker
                .setSilentGroupChat(groupGuid: chatIdentifier, till: nil, withResponse: resetSilentResponseBlock)
        case .single:
            DPAGApplicationFacade.requestWorker
                .setSilentSingleChat(accountGuid: chatIdentifier, till: nil, withResponse: resetSilentResponseBlock)
        }
    }

    public var hasOptionInfinite: Bool {
        true
    }
}
