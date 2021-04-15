//
//  DPAGTableView.swift
//  SIMSmeUILib
//
//  Created by Maxime Bentin on 16.09.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

class DPAGTableView: UITableView {
    var isContentOffsetEnabled: Bool = true
    var isContentOffsetAnimated: Bool = false

    override func setContentOffset(_ offset: CGPoint, animated: Bool) {
        if self.isContentOffsetEnabled {
            super.setContentOffset(offset, animated: self.isContentOffsetAnimated && animated)
        }
    }

    override var contentOffset: CGPoint {
        get {
            super.contentOffset
        }
        set {
            if self.isContentOffsetEnabled {
                super.contentOffset = newValue
            }
        }
    }
}
