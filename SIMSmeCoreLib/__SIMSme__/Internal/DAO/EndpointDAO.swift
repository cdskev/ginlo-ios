//
//  EndpointDAO.swift
//  SIMSmeCore
//
//  Created by Maxime Bentin on 29.08.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

protocol EndpointDAOProtocol {
    static func save(endpoint: String)
    static func fetch() -> String?
}

public struct EndpointDAO: EndpointDAOProtocol {
    public static func save(endpoint: String) {
        UserDefaults.standard.set(endpoint, forKey: "ENDPOINT_PICKED")
    }

    public static func fetch() -> String? {
        UserDefaults.standard.string(forKey: "ENDPOINT_PICKED")
    }
}
