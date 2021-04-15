//
//  SilentTimeFormatter.swift
//  SIMSmeUILib
//
//  Created by Evgenii Kononenko on 29.04.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

public struct SilentTimeFormatter {
    public init() {}

    public func format(date: Date, shortUnitStyle: Bool = false, includeRemainingPhrase: Bool = false) -> String? {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .hour]
        formatter.unitsStyle = shortUnitStyle ? .short : .full
        formatter.includesTimeRemainingPhrase = includeRemainingPhrase
        let seconds = date.timeIntervalSinceNow
        return formatter.string(from: seconds)
    }
}
