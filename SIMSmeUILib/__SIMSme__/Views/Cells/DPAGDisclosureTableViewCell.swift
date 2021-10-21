//
//  DPAGSettingsDisclosureTableViewCell.swift
// ginlo
//
//  Created by RBU on 26/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

public protocol DPAGDisclosureTableViewCellProtocol: DPAGBaseTableViewCellProtocol {}

class DPAGDisclosureTableViewCell: DPAGBaseTableViewCell, DPAGDisclosureTableViewCellProtocol {
    @IBOutlet var constraintDetailLabelTrailing: NSLayoutConstraint!

    override var enabled: Bool {
        didSet {
            self.accessoryType = self.enabled ? .disclosureIndicator : .none
            self.constraintDetailLabelTrailing.constant = self.enabled ? 0 : 16
        }
    }
}
