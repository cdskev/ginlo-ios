//
//  CommonErrorHandler.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 29.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

protocol CommonErrorHandlerProtocol {
    func handleAPIError(error: APIError)
}

class CommonErrorHandler: CommonErrorHandlerProtocol {
    func handleAPIError(error: APIError) {
        if case let APIError.accountWasDeleted(code) = error, code == 499 {
            NotificationCenter.default.post(name: DPAGStrings.Notification.Account.WAS_DELETED, object: self, userInfo: ["error": "service.error499"])
        }
    }
}
