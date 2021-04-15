//
//  Bool+Extensions.swift
//  SIMSmeCore
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

public extension Bool {
    init(_ str: String?) {
        guard let str = str else {
            self = false
            return
        }

        switch str.lowercased() {
        case "true", "t", "yes", "y", "1":
            self = true
        default:
            self = false
        }
    }
}
