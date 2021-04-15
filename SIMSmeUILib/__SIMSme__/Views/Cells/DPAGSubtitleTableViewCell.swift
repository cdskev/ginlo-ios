//
//  DPAGSettingsSubtitleTableViewCell.swift
//  SIMSme
//
//  Created by RBU on 26/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGSubtitleTableViewCellProtocol: DPAGBaseTableViewCellProtocol {}

class DPAGSubtitleTableViewCell: DPAGBaseTableViewCell, DPAGSubtitleTableViewCellProtocol {
    override func configContentViews() {
        super.configContentViews()

        self.textLabel?.numberOfLines = 0
        self.detailTextLabel?.numberOfLines = 0
    }

    override func updateFonts() {
        super.updateFonts()

        self.textLabel?.font = UIFont.kFontBody
        self.detailTextLabel?.font = UIFont.kFontSubheadline
    }
}
