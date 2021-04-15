//
//  DPAGSettingsBaseTableViewCell.swift
//  SIMSme
//
//  Created by RBU on 26/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGBaseTableViewCellProtocol: DPAGDefaultTableViewCellProtocol {
    var enabled: Bool { get set }
}

class DPAGBaseTableViewCell: DPAGDefaultTableViewCell, DPAGBaseTableViewCellProtocol {
    var enabled = true {
        didSet {
            self.isUserInteractionEnabled = self.enabled
            self.updateColors()
        }
    }

    override func configContentViews() {
        super.configContentViews()

        self.textLabel?.numberOfLines = 0
        self.detailTextLabel?.numberOfLines = 1
    }

    override func updateFonts() {
        super.updateFonts()

        self.textLabel?.font = UIFont.kFontBody
        self.detailTextLabel?.font = UIFont.kFontBody
    }

    override func updateColors() {
        super.updateColors()

        self.textLabel?.textColor = self.enabled ? DPAGColorProvider.shared[.labelText] : DPAGColorProvider.shared[.labelDisabled]
        self.detailTextLabel?.textColor = self.enabled ? DPAGColorProvider.shared[.labelText] : DPAGColorProvider.shared[.labelDisabled]
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                updateColors()
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
