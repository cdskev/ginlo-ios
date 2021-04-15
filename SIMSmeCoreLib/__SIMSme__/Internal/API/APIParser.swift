//
//  APIParser.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 12.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

class APIParser {
    func parseToObject<T>(ofType type: T.Type, data: Data) throws -> T where T: Decodable {
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
}
