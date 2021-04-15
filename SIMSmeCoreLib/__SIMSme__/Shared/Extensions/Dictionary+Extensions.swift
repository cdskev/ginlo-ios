//
//  Dictionary+Extensions.swift
//  SIMSmeCore
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

extension Dictionary { // where Key: String, Value:Any
    var JSONString: String? {
        do {
            let stringData = try JSONSerialization.data(withJSONObject: self, options: [])

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

    func jsonString() throws -> String {
        let stringData = try JSONSerialization.data(withJSONObject: self, options: [])

        if let string = String(data: stringData, encoding: .utf8) {
            return string
        } else {
            throw DPAGErrorCrypto.errEncoding("JSON array.data -> string failed")
        }
    }

    subscript(jsonDict key: Key) -> [String: Any]? {
        get {
            self[key] as? [String: Any]
        }
        set {
            self[key] = newValue as? Value
        }
    }

    subscript(string key: Key) -> String? {
        get {
            self[key] as? String
        }
        set {
            self[key] = newValue as? Value
        }
    }

    subscript(array key: Key) -> NSArray? {
        get {
            self[key] as? NSArray
        }
        set {
            self[key] = newValue as? Value
        }
    }
}
