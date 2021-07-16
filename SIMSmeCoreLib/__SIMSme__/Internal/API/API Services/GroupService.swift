//
//  GroupService.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 15.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

typealias AcceptInvitationToGroupResult = Result<API.Response.AcceptGroupInvitationResponse, APIError>
typealias AcceptInvitationToGroupCompletion = (AcceptInvitationToGroupResult) -> Void

protocol GroupServiceProtocol {
    func acceptInvitationToRoom(groupId: String, nickNameEncoded: String?, completion: @escaping AcceptInvitationToGroupCompletion)
}

class GroupService: GroupServiceProtocol {
    private let kReturnComplexResult = "1"
    var apiService: APIServiceProtocol = APIService()

    func acceptInvitationToRoom(groupId: String, nickNameEncoded: String?, completion: @escaping AcceptInvitationToGroupCompletion) {
        let parameters = API.Request.AcceptGroupInvitationParam(guid: groupId, returnComplexResult: kReturnComplexResult, nickName: nickNameEncoded)
        let request = APIRequest()
        request.setEncodableParameters(object: parameters)
        self.apiService.performRequest(request: request, resultObjectType: API.Response.AcceptGroupInvitationResponse.self, completion: completion)
    }
}
