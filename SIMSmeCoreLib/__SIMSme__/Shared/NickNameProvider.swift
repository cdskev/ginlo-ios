//
//  NickNameProvider.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 15.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

protocol NickNameProviderProtocol {
    func getEncodedSendNickName() -> String?
}

class NickNameProvider: NickNameProviderProtocol {
    func getEncodedSendNickName() -> String? {
        guard DPAGApplicationFacade.preferences.sendNickname, let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let nickname = contact.nickName else {
            return nil
        }

        return nickname.data(using: .utf8)?.base64EncodedString(options: .lineLength76Characters)
    }
}
