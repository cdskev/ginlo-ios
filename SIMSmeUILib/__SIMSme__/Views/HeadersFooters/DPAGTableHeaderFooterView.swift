//
//  DPAGTableHeaderFooterView.swift
// ginlo
//
//  Created by RBU on 25.11.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGTableHeaderViewPlainProtocol: AnyObject {
    var label: UILabel! { get }
    var labelDetail: UILabel! { get }
}

class DPAGTableHeaderViewPlain: UITableViewHeaderFooterView, DPAGTableHeaderViewPlainProtocol {
    @IBOutlet var label: UILabel! {
        didSet {
            self.label.font = UIFont.kFontFootnote
            self.label.textColor = DPAGColorProvider.shared[.labelText]
            self.label.text = nil
        }
    }

    @IBOutlet var labelDetail: UILabel! {
        didSet {
            self.labelDetail.font = UIFont.kFontFootnote
            self.labelDetail.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDetail.text = nil
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        self.textLabel?.isHidden = true
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.label.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDetail.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}

public protocol DPAGTableHeaderViewGroupedProtocol: AnyObject {
    var label: UILabel! { get }
    var labelDetail: UILabel! { get }
}

class DPAGTableHeaderViewGrouped: UITableViewHeaderFooterView, DPAGTableHeaderViewGroupedProtocol {
    @IBOutlet var label: UILabel! {
        didSet {
            self.label.font = UIFont.kFontFootnote
            self.label.textColor = DPAGColorProvider.shared[.labelText]
            self.label.text = nil
        }
    }

    @IBOutlet var labelDetail: UILabel! {
        didSet {
            self.labelDetail.font = UIFont.kFontFootnote
            self.labelDetail.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDetail.text = nil
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        self.textLabel?.isHidden = true
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.label.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDetail.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
