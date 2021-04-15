//
//  DPAGApplicationFacadeUI.swift
//  SIMSmeUILib
//
//  Created by RBU on 26.05.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public struct DPAGApplicationFacadeUIViews {
    private init() {}

    public static func cellHiddenNib() -> UINib { UINib(nibName: "DPAGHiddenTableViewCell", bundle: Bundle(for: DPAGHiddenTableViewCell.self)) }
    public static func cellTextFieldNib() -> UINib { UINib(nibName: "DPAGTableViewCellTextField", bundle: Bundle(for: DPAGTableViewCellTextField.self)) }
    public static func cellContactNib() -> UINib { UINib(nibName: "DPAGContactCell", bundle: Bundle(for: DPAGContactCell.self)) }
    public static func tableHeaderPlainNib() -> UINib { UINib(nibName: "DPAGTableHeaderViewPlain", bundle: Bundle(for: DPAGTableHeaderViewPlain.self)) }
    public static func tableHeaderGroupedNib() -> UINib { UINib(nibName: "DPAGTableHeaderViewGrouped", bundle: Bundle(for: DPAGTableHeaderViewGrouped.self)) }
    public static func cellTableViewBaseNib() -> UINib { UINib(nibName: "DPAGBaseTableViewCell", bundle: Bundle(for: DPAGBaseTableViewCell.self)) }
    public static func cellTableViewDisclosureSubtitleNib() -> UINib { UINib(nibName: "DPAGDisclosureSubtitleTableViewCell", bundle: Bundle(for: DPAGDisclosureSubtitleTableViewCell.self)) }
    public static func cellTableViewDisclosureNib() -> UINib { UINib(nibName: "DPAGDisclosureTableViewCell", bundle: Bundle(for: DPAGDisclosureTableViewCell.self)) }
    public static func cellTableViewSubtitleNib() -> UINib { UINib(nibName: "DPAGSubtitleTableViewCell", bundle: Bundle(for: DPAGSubtitleTableViewCell.self)) }
    public static func cellTableViewSwitchNib() -> UINib { UINib(nibName: "DPAGSwitchTableViewCell", bundle: Bundle(for: DPAGSwitchTableViewCell.self)) }
    public static func cellProfileNib() -> UINib { UINib(nibName: "SettingsProfileCell", bundle: Bundle(for: SettingsProfileCell.self)) }
}
