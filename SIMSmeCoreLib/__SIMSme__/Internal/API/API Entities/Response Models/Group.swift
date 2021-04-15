//
//  Group.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 16.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

extension API.Response {
    struct Group: Codable {
        let ownerId: String?
        let memberIds: [String]?
        let adminIds: [String]?
        let writerIds: [String]?

        let data: String?
        let keyIv: String

        let groupId: String
        let maxMembers: String

        enum CodingKeys: String, CodingKey {
            case ownerId = "owner"
            case memberIds = "member"
            case adminIds = "admins"
            case writerIds = "writers"
            case data
            case keyIv = "key-iv"
            case groupId = "guid"
            case maxMembers = "maxmember"
        }
    }
}
