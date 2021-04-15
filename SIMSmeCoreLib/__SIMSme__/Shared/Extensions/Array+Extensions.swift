//
//  Array+Extensions.swift
//  SIMSmeCore
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

extension Array { // where Key: Any
    var JSONString: String? {
        do {
            let stringData = try JSONSerialization.data(withJSONObject: self, options: [])

            if let string = String(data: stringData, encoding: .utf8) {
                return string
            } else {
                DPAGLog("JSON dictionary.data -> string failed")
            }
        } catch {
            DPAGLog("JSON dictionary.data -> string failed: \(error)")
        }

        return nil
    }

    func jsonString() throws -> String {
        let stringData = try JSONSerialization.data(withJSONObject: self, options: [])

        if let string = String(data: stringData, encoding: .utf8) {
            return string
        } else {
            throw DPAGErrorCrypto.errEncoding("JSON dictionary.data -> string failed")
        }
    }
}
