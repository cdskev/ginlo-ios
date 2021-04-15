//
//  NSLayoutConstraint+Extensions.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

public extension NSLayoutConstraint {
    func activate() {
        self.isActive = true
    }
}

public extension Array where Element: NSLayoutConstraint {
    func activate() {
        NSLayoutConstraint.activate(self)
    }
}
