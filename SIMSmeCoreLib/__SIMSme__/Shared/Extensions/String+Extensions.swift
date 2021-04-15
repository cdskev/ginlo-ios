//
//  String+Extensions.swift
//  SIMSmeCore
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

public extension String {
    func components(withLength length: Int) -> [String] {
        stride(from: 0, to: self.count, by: length).map {
            let start = self.index(self.startIndex, offsetBy: $0)
            let end = self.index(start, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex

            return String(self[start ..< end])
        }
    }

    var isSystemChatGuid: Bool {
        self == "0:{00000000-0000-0000-0000-000000000000}"
    }

    func stripUnrecognizedPhoneNumberCharacters() -> String {
        var replaced = self.replacingOccurrences(of: "\\U00a0", with: "").replacingOccurrences(of: "(0)", with: "").components(separatedBy: CharacterSet(charactersIn: "+0123456789").inverted).joined()

        if replaced.isEmpty == false {
            // replace all '+' except the first one
            if replaced.hasPrefix("+") {
                replaced = replaced.replacingOccurrences(of: "+", with: "")
                replaced = "+" + replaced
            } else {
                replaced = replaced.replacingOccurrences(of: "+", with: "")
            }
        }

        return replaced
    }
}
