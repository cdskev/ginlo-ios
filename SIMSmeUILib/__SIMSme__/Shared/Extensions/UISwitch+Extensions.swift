//
//  UISwitch+Extensions.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

public extension UISwitch {
    func toggle() {
        self.setOn(self.isOn == false, animated: true)
    }
}
