//
//  SystemMessageContentFactory.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 05.09.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

protocol SystemMessageContentFactoryProtocol {
    func createMessageContactDeleted(contactGuid: String?) -> String
}

struct SystemMessageContentFactory: SystemMessageContentFactoryProtocol {
    func createMessageContactDeleted(contactGuid: String?) -> String {
        String(format: DPAGLocalizedString("chat.single.alert.message.contact_deleted"), contactGuid ?? "", DPAGMandant.default.name)
    }
}
