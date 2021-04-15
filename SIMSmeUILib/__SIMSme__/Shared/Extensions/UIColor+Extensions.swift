//
//  UIColor+Extensions.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore

public extension UIColor {
    class func confidenceStatusToColor(_ status: DPAGConfidenceState, isActive: Bool = false) -> UIColor {
        switch status {
            case .none:
                return .clear
            case .low where isActive:
                return DPAGColorProvider.shared[.trustLevelLow]
            case .middle where isActive:
                return DPAGColorProvider.shared[.trustLevelMedium]
            case .high where isActive:
                return DPAGColorProvider.shared[.trustLevelHigh]
            case .low, .middle, .high:
                return DPAGColorProvider.shared[.tableSeparator]
        }
    }
}
