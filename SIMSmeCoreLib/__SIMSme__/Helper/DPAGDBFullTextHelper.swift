//
//  DPAGDBFullTextHelper.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 26.11.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

extension DPAGDBFullTextHelper {
    struct FtsDatabaseContactAttributes: Codable {
        let accountGuid: String
        let accountID: String?

        let firstName: String?
        let lastName: String?

        let mandant: String?

        let entryTypeServer: Int
        let confidenceState: UInt

        let phoneNumber: String?
        let eMailAddress: String?
        let department: String?

        let nickName: String?
        let status: String?
    }
}
