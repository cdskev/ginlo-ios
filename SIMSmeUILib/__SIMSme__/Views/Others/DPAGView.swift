//
//  DPAGView.swift
// ginlo
//
//  Created by RBU on 01/06/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

open class DPAGView: UIView {
    init() {
        super.init(frame: .zero)

        self.configure()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.configure()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override open func awakeFromNib() {
        super.awakeFromNib()

        self.configure()
    }

    open func configure() {}
    
    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.configure()
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}

public protocol DPAGButtonPrimaryViewProtocol: AnyObject {
    func prepareKeyboardShow(animationInfo: UIKeyboardAnimationInfo)
    func animateKeyboardShow(animationInfo: UIKeyboardAnimationInfo)
    func completeKeyboardShow(animationInfo: UIKeyboardAnimationInfo)
    func prepareKeyboardHide(animationInfo: UIKeyboardAnimationInfo)
    func animateKeyboardHide(animationInfo: UIKeyboardAnimationInfo)
    func completeKeyboardHide(animationInfo: UIKeyboardAnimationInfo)
}

@IBDesignable
public class DPAGButtonPrimaryView: DPAGView, DPAGButtonPrimaryViewProtocol {
    public let button: UIButton = {
        let button = UIButton(type: .custom)

        button.setTitle("BUTTON", for: .normal)
        button.isAccessibilityElement = true

        return button
    }()

    public let viewKeyboard = UIView(frame: .zero)

    public var colorAction: UIColor = DPAGColorProvider.shared[.buttonBackground]
    public var colorActionContrast: UIColor = DPAGColorProvider.shared[.buttonTint]
    public var colorActionDisabled: UIColor = DPAGColorProvider.shared[.buttonTintDisabled]
    
    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                colorAction = DPAGColorProvider.shared[.buttonBackground]
                colorActionContrast = DPAGColorProvider.shared[.buttonTint]
                colorActionDisabled = DPAGColorProvider.shared[.buttonTintDisabled]
                self.viewKeyboard.backgroundColor = DPAGColorProvider.shared[.keyboard]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    private var constraintButtonBottom: NSLayoutConstraint?

    override public var intrinsicContentSize: CGSize {
        CGSize(width: 99, height: 56 + self.safeAreaInsets.bottom)
    }

    override public func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        self.configure()
    }

    public func refresh() {
        self.button.configurePrimaryButton(backgroundColor: self.colorAction, textColor: self.colorActionContrast)
        self.button.backgroundColor = self.button.isEnabled ? self.colorAction : self.colorActionDisabled
        self.viewKeyboard.backgroundColor = self.button.backgroundColor
    }

    override public func configure() {
        self.backgroundColor = .clear
        if self.button.superview == nil {
            self.button.configurePrimaryButton(backgroundColor: self.colorAction, textColor: self.colorActionContrast)
            self.button.backgroundColor = self.button.isEnabled ? self.colorAction : self.colorActionDisabled
            self.viewKeyboard.backgroundColor = self.button.backgroundColor
            self.addSubview(self.button)
            self.addSubview(self.viewKeyboard)
            self.button.translatesAutoresizingMaskIntoConstraints = false
            self.viewKeyboard.translatesAutoresizingMaskIntoConstraints = false
            let constraintButtonBottom: NSLayoutConstraint
            constraintButtonBottom = self.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: self.button.bottomAnchor)
            NSLayoutConstraint.activate([
                constraintButtonBottom,
                self.topAnchor.constraint(equalTo: self.button.topAnchor),
                self.trailingAnchor.constraint(equalTo: self.button.trailingAnchor),
                self.leadingAnchor.constraint(equalTo: self.button.leadingAnchor),
                self.bottomAnchor.constraint(equalTo: self.viewKeyboard.bottomAnchor),
                self.leadingAnchor.constraint(equalTo: self.viewKeyboard.leadingAnchor),
                self.trailingAnchor.constraint(equalTo: self.viewKeyboard.trailingAnchor),
                self.viewKeyboard.topAnchor.constraint(equalTo: self.button.bottomAnchor),
                self.button.heightAnchor.constraint(equalToConstant: 56)
            ])

            self.constraintButtonBottom = constraintButtonBottom
        }
    }

    private var isKeyboardShown: Bool = false

    public func prepareKeyboardShow(animationInfo _: UIKeyboardAnimationInfo) {}

    public func animateKeyboardShow(animationInfo: UIKeyboardAnimationInfo) {
        if self.viewKeyboard.frame.size.height < animationInfo.keyboardRectEnd.height {
            self.button.frame.origin.y -= animationInfo.keyboardRectEnd.height - self.safeAreaInsets.bottom
            self.viewKeyboard.frame.origin.y -= animationInfo.keyboardRectEnd.height - self.safeAreaInsets.bottom
            self.viewKeyboard.frame.size.height += animationInfo.keyboardRectEnd.height - self.safeAreaInsets.bottom
        }
        self.viewKeyboard.backgroundColor = DPAGColorProvider.shared[.keyboard]
        self.constraintButtonBottom?.constant = animationInfo.keyboardRectEnd.height - self.safeAreaInsets.bottom
    }

    public func completeKeyboardShow(animationInfo _: UIKeyboardAnimationInfo) {
        self.layoutIfNeeded()
        self.isKeyboardShown = true
    }

    public func prepareKeyboardHide(animationInfo _: UIKeyboardAnimationInfo) {}

    public func animateKeyboardHide(animationInfo: UIKeyboardAnimationInfo) {
        if self.viewKeyboard.frame.size.height > animationInfo.keyboardRectEnd.height {
            self.button.frame.origin.y += animationInfo.keyboardRectEnd.height - self.safeAreaInsets.bottom
            self.viewKeyboard.frame.origin.y += animationInfo.keyboardRectEnd.height - self.safeAreaInsets.bottom
            self.viewKeyboard.frame.size.height -= animationInfo.keyboardRectEnd.height - self.safeAreaInsets.bottom
        }
        self.viewKeyboard.backgroundColor = self.button.backgroundColor
        self.constraintButtonBottom?.constant = 0
    }

    public func completeKeyboardHide(animationInfo _: UIKeyboardAnimationInfo) {
        self.layoutIfNeeded()
        self.isKeyboardShown = false
    }

    public var isEnabled: Bool {
        get {
            self.button.isEnabled
        }
        set {
            self.button.isEnabled = newValue
            self.button.backgroundColor = newValue ? self.colorAction : self.colorActionDisabled

            if self.isKeyboardShown == false {
                self.viewKeyboard.backgroundColor = self.button.backgroundColor
            }
        }
    }

    override public var isHidden: Bool {
        get {
            super.isHidden
        }
        set {
            if newValue != self.isHidden {
                super.isHidden = newValue
                // self.constraintButtonNextHeight.constant = self.isHidden ? 0 : 56
            }
        }
    }
}
