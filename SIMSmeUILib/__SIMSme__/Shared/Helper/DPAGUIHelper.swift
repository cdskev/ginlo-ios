//
//  DPAGUIHelper.swift
//  SIMSme
//
//  Created by RBU on 27/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import MobileCoreServices
import SIMSmeCore
import StoreKit
import UIKit

public protocol DPAGLockViewProtocol {
    var lockViewLabel: UILabel? { get }
}

private class DPAGLockViewBase: UIView, DPAGLockViewProtocol {
    var lockViewLabel: UILabel?

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        self.accessibilityIdentifier = "LockView"
        self.isOpaque = true

        if AppConfig.buildConfigurationMode == .TEST { // UI-Automation, for detection of removed lock view
            let lockViewLabel = UILabel()
            lockViewLabel.text = " "
            lockViewLabel.sizeToFit()
            self.addSubview(lockViewLabel)
            self.lockViewLabel = lockViewLabel
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class DPAGLockView: DPAGLockViewBase {
    override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        let logoView = LogoView()
        self.addSubview(logoView)
        logoView.setDefaultPositionToSuperView()
    }
}

public extension DPAGUIHelper {
    static func setupLockView(frame: CGRect) -> (UIView & DPAGLockViewProtocol) {
        DPAGLockView(frame: frame)
    }

    static func setupLockViewLogin(frame: CGRect) -> (UIView & DPAGLockViewProtocol) {
        DPAGLockView(frame: frame)
    }
}
