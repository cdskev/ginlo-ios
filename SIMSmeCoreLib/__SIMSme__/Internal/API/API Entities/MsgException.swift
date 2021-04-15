//
//  MsgException.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 12.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

extension API {
    struct MessageExceptionResponse: Codable {
        var messageException: MessageException

        enum CodingKeys: String, CodingKey {
            case messageException = "MsgException"
        }
    }

    struct MessageException: Codable {
        var ident: String
    }
}
