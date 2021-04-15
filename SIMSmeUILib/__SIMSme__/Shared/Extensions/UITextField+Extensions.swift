//
//  UITextField+Extensions.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore

public extension UITextField {
    func configureDefault() {
        self.layer.cornerRadius = 3.0
        self.clipsToBounds = true
        self.borderStyle = .none
        self.setPaddingLeftTo(0)
        self.textAlignment = .left
        self.isAccessibilityElement = true
        self.font = UIFont.kFontCallout
        self.backgroundColor = DPAGColorProvider.shared[.backgroundInput]
        self.textColor = DPAGColorProvider.shared[.backgroundInputText]

        if AppConfig.isShareExtension {
            let preferences = DPAGApplicationFacadeShareExt.preferences
            self.keyboardAppearance = preferences.isWhiteLabelBuild ? .dark : .light
        } else {
            let preferences = DPAGApplicationFacade.preferences
            self.keyboardAppearance = preferences.isWhiteLabelBuild ? .dark : .light
        }
    }

    func configureAsTitle() {
        self.layer.cornerRadius = 3.0
        self.clipsToBounds = true
        self.borderStyle = .none
        self.setPaddingLeftTo(0)
        self.textAlignment = .center
        self.isAccessibilityElement = true

        self.font = UIFont.kFontTitle2
        self.backgroundColor = DPAGColorProvider.shared[.backgroundInput]
        self.textColor = DPAGColorProvider.shared[.backgroundInputText]

        if AppConfig.isShareExtension {
            let preferences = DPAGApplicationFacadeShareExt.preferences
            self.keyboardAppearance = preferences.isWhiteLabelBuild ? .dark : .light
        } else {
            let preferences = DPAGApplicationFacade.preferences
            self.keyboardAppearance = preferences.isWhiteLabelBuild ? .dark : .light
        }
    }

    func setPaddingLeftTo(_ paddingValue: CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: paddingValue, height: self.frame.size.height))
        self.leftView = paddingView
        self.leftViewMode = .always
    }

    func setPaddingRightTo(_ paddingValue: CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: paddingValue, height: self.frame.size.height))
        self.rightView = paddingView
        self.rightViewMode = .always
    }
}
