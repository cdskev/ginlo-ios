//
//  UIImageView+Extensions.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore

public extension UIImageView {
    func configureCheck() {
        self.image = DPAGImageProvider.shared[.kImageChatCellOverlayCheck]
        self.tintColor = DPAGColorProvider.shared[.imageCheckTint]
        self.backgroundColor = DPAGColorProvider.shared[.imageCheck]
        self.layer.cornerRadius = self.bounds.width / 2
    }

    func configureUncheck() {
        self.image = DPAGImageProvider.shared[.kImageClose]
        self.tintColor = DPAGColorProvider.shared[.imageUncheckTint]
        self.backgroundColor = DPAGColorProvider.shared[.imageUncheck]
        self.layer.cornerRadius = self.bounds.width / 2
    }
}
