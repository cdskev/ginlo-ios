//
//  DPAGInitialPasswordBaseViewController.swift
//  SIMSme
//
//  Created by RBU on 22/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

open class DPAGInitialPasswordBaseViewController: DPAGPasswordViewControllerBase {
    @IBOutlet public private(set) var switchInputType: UISwitch? {
        didSet {
            self.switchInputType?.isOn = false
            self.switchInputType?.accessibilityIdentifier = "switchInputType"
            self.switchInputType?.isEnabled = DPAGApplicationFacade.preferences.canUseSimplePin
            self.switchInputType?.addTarget(self, action: #selector(handleInputTypeSwitched(_:)), for: .valueChanged)
            self.switchInputType?.isHidden = !DPAGApplicationFacade.preferences.canUseSimplePin
        }
    }

    @IBOutlet public private(set) var labelInputType: UILabel? {
        didSet {
            self.labelInputType?.text = DPAGLocalizedString("registration.inputType.initialPassword")
            self.labelInputType?.font = UIFont.kFontBody
            self.labelInputType?.textColor = DPAGColorProvider.shared[.labelText]
            self.labelInputType?.numberOfLines = 0
            self.labelInputType?.accessibilityIdentifier = "switchLabel"
            self.labelInputType?.isHidden = !DPAGApplicationFacade.preferences.canUseSimplePin
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelInputType?.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        self.configureView()
    }

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    @objc
    open func handleInputTypeSwitched(_: Any?) {
        self.doesNotRecognizeSelector(#selector(handleInputTypeSwitched(_:)))
    }

    public func setupInputTypeAnimated(_ animated: Bool, secLevelView: Bool, withCompletion completion: DPAGCompletion?) {
        var vcPasswort: (UIViewController & DPAGPasswordViewControllerProtocol)?
        var vcPasswortPrev: (UIViewController & DPAGPasswordViewControllerProtocol)?

        if self.switchInputType?.isOn ?? false, self.passwordViewControllerPIN == nil {
            self.passwordViewControllerPIN = DPAGApplicationFacadeUIBase.passwordPINVC(secLevelView: true)
            vcPasswort = self.passwordViewControllerPIN
            vcPasswortPrev = self.passwordViewControllerComplex
        } else if (self.switchInputType?.isOn ?? false) == false, self.passwordViewControllerComplex == nil {
            self.passwordViewControllerComplex = DPAGApplicationFacadeUIBase.passwordComplexVC(secLevelView: secLevelView, isNewPassword: self.isNewPassword)
            vcPasswort = self.passwordViewControllerComplex
            vcPasswortPrev = self.passwordViewControllerPIN
        }

        if let vcPasswortNext = vcPasswort {
            vcPasswortNext.state = .registration
            vcPasswortPrev?.willMove(toParent: nil)
            vcPasswortPrev?.view.removeFromSuperview()
            vcPasswortPrev?.removeFromParent()
            vcPasswortNext.willMove(toParent: self)
            self.addChild(vcPasswortNext)
            self.viewPasswordInput.addSubview(vcPasswortNext.view)
            vcPasswortNext.didMove(toParent: self)
            vcPasswortNext.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate(self.viewPasswordInput.constraintsFill(subview: vcPasswortNext.view))
            if vcPasswortPrev === self.passwordViewControllerPIN {
                self.passwordViewControllerPIN = nil
            }
            if vcPasswortPrev === self.passwordViewControllerComplex {
                self.passwordViewControllerComplex = nil
            }
            let blockAnimation = { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.view.layoutIfNeeded()
            }
            let blockCompletion = { [weak self] (_: Bool) in
                guard let strongSelf = self else { return }
                vcPasswortPrev?.didMove(toParent: nil)
                vcPasswortNext.delegate = strongSelf
                strongSelf.viewButtonNext.isEnabled = vcPasswortNext.passwordEnteredCanBeValidated(vcPasswortNext.getEnteredPassword())
                completion?()
            }
            if animated {
                UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: blockAnimation, completion: blockCompletion)
            } else {
                blockAnimation()
                blockCompletion(false)
            }
        }
    }

    override open func enteredPassword() -> String? {
        let isPINInput = (self.switchInputType?.isOn ?? false)
        if isPINInput {
            return self.passwordViewControllerPIN?.getEnteredPassword()
        } else {
            return self.passwordViewControllerComplex?.getEnteredPassword()
        }
    }
}
