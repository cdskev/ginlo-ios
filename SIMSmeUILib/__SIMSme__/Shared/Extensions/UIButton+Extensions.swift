//
//  UIButton+Extensions.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore

public extension UIButton {
    func configureButtonTableCell() {
        self.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonTintNoBackground])

        self.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        self.contentHorizontalAlignment = .left
    }

    func configureButtonTableCellDestructive() {
        self.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonDestructiveTintNoBackground])

        self.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        self.contentHorizontalAlignment = .left
    }

    func configureButton() {
        self.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonTintNoBackground])
    }

    func configureButtonDestructive() {
        self.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonDestructiveTintNoBackground])
    }

    func configureButton(backgroundColor: UIColor, textColor: UIColor) {
        self.titleLabel?.font = UIFont.kFontBody
        self.titleLabel?.adjustsFontSizeToFitWidth = true

        self.setTitleColor(textColor, for: .normal)
        self.backgroundColor = backgroundColor

        self.adjustsImageWhenHighlighted = false
        self.adjustsImageWhenDisabled = false
    }

    func configurePrimaryButton() {
        self.configurePrimaryButton(backgroundColor: DPAGColorProvider.shared[.buttonBackground], textColor: DPAGColorProvider.shared[.buttonTint])
    }

    func configurePrimaryButton(backgroundColor: UIColor, textColor: UIColor) {
        self.titleLabel?.font = UIFont.kFontBody
        self.titleLabel?.adjustsFontSizeToFitWidth = true

        self.setTitleColor(textColor, for: .normal)
        self.backgroundColor = backgroundColor

        self.adjustsImageWhenHighlighted = false
        self.adjustsImageWhenDisabled = false
    }
}
