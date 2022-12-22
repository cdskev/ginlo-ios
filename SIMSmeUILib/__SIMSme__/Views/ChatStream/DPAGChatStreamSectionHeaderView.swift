//
//  DPAGChatStreamSectionHeader.swift
//  SIMSmeUILib
//
//  Created by RBU on 09.05.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGChatStreamSectionHeaderViewProtocol: AnyObject {
    var sectionTitle: String? { get set }
}

class DPAGChatStreamSectionHeaderView: UITableViewHeaderFooterView, DPAGChatStreamSectionHeaderViewProtocol {
    var sectionTitle: String? {
        get {
            self.label.text
        }
        set {
            self.label.text = newValue
        }
    }

    @IBOutlet private var label: UILabel! {
        didSet {
            self.label.font = .kFontFootnote
            self.label.textAlignment = .center
            self.label.textColor = DPAGColorProvider.shared[.labelTextForBackgroundInverted]
        }
    }

    @IBOutlet private var viewBackground: UIView! {
      didSet {
        self.viewBackground.backgroundColor = DPAGColorProvider.shared[.defaultViewBackgroundInverted]
        self.viewBackground.layer.cornerRadius = 12
        self.viewBackground.layer.masksToBounds = true
        if #available(iOS 14.0, *) {
          self.backgroundConfiguration = UIBackgroundConfiguration.clear()
        } else {
          self.backgroundView?.backgroundColor = .clear
        }
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
                self.viewBackground.backgroundColor = DPAGColorProvider.shared[.defaultViewBackgroundInverted]
                self.label.textColor = DPAGColorProvider.shared[.labelTextForBackgroundInverted]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
