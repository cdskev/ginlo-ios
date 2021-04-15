//
//  DPAGSettingsSwitchTableViewCell.swift
//  SIMSme
//
//  Created by RBU on 26/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGSwitchTableViewCellProtocol: DPAGBaseTableViewCellProtocol {
    var ident: String? { get set }

    var aSwitch: UISwitch! { get }
}

class DPAGSwitchTableViewCell: DPAGBaseTableViewCell, DPAGSwitchTableViewCellProtocol {
    @IBOutlet var aSwitch: UISwitch!

    var ident: String?

    override func updateColors() {
        super.updateColors()
        self.performBlockOnMainThread { [weak self] in
            if let strongSelf = self {
                strongSelf.aSwitch?.onTintColor = strongSelf.enabled ? DPAGColorProvider.shared[.switchOnTint] : DPAGColorProvider.shared[.switchOnTintDisabled]
            }
        }
    }
    
    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                updateColors()
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
