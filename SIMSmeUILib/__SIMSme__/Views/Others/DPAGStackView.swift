//
//  DPAGStackView.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore

public class DPAGStackView: UIStackView {
    override public var isHidden: Bool {
        get {
            super.isHidden
        }
        set {
            if newValue != self.isHidden {
                super.isHidden = newValue
            }
        }
    }
}

open class DPAGStackViewContentView: UIView {
    override open var isHidden: Bool {
        get {
            super.isHidden
        }
        set {
            if newValue != self.isHidden {
                super.isHidden = newValue
            }
        }
    }
    
    open
    func handleDesignColorsUpdated() {
    }
    
    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = self.traitCollection.userInterfaceStyle == .dark
                handleDesignColorsUpdated()
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
