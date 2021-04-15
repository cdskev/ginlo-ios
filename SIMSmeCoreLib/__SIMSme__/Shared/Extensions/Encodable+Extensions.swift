//
//  Encodable+Extensions.swift
//  SIMSmeCore
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

extension Encodable {
    var JSONString: String? {
        do {
            let stringData = try JSONEncoder().encode(self)

            if let string = String(data: stringData, encoding: .utf8) {
                return string
            } else {
                DPAGLog("JSON array.data -> string failed")
            }
        } catch {
            DPAGLog(error, message: "JSON array.data -> string failed")
        }

        return nil
    }
}
