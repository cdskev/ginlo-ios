//
//  UIWindow+Extensions.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore

public extension UIWindow {
    func configureUI() {
        self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
    }
}
