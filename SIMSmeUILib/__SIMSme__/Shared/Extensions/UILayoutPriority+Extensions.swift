//
//  UILayoutPriority+Extensions.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

public extension UILayoutPriority {
    static func + (lhs: UILayoutPriority, rhs: Float) -> UILayoutPriority {
        UILayoutPriority(lhs.rawValue + rhs)
    }

    static func - (lhs: UILayoutPriority, rhs: Float) -> UILayoutPriority {
        UILayoutPriority(lhs.rawValue - rhs)
    }
}
