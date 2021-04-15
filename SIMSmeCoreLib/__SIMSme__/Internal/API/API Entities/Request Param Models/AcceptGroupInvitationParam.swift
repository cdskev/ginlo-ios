//
//  AcceptGroupInvitationParam.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 16.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

extension API.Request {
    struct AcceptGroupInvitationParam: Codable {
        var cmd: String = "acceptRoomInvitation"
        let guid: String
        let returnComplexResult: String
        let nickName: String?
    }
}
