//
//  AcceptGroupInvitationResponse.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 15.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

extension API.Response {
    struct AcceptGroupInvitationResponse: Codable {
        let result: API.Response.GroupAddMembersResult?
        let group: API.Response.Group?
        let managedGroup: API.Response.Group?
        let restrictedGroup: API.Response.Group?
        let announcementGroup: API.Response.Group?

        enum CodingKeys: String, CodingKey {
            case result = "AddMembersResult"
            case group = "ChatRoom"
            case managedGroup = "ManagedRoom"
            case restrictedGroup = "RestrictedRoom"
            case announcementGroup = "AnnouncementRoom"
        }

        func getGroup() -> API.Response.Group? {
            self.group ?? self.managedGroup ?? self.restrictedGroup ?? self.announcementGroup
        }
    }

    struct GroupAddMembersResult: Codable {
        let notSendUserIds: [String]?
        let sendUserIds: [String]?

        enum CodingKeys: String, CodingKey {
            case notSendUserIds = "not-send"
            case sendUserIds = "send"
        }
    }
}
