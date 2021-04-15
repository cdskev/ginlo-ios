//
//  DPAGInitialPasswordForgotViewController.swift
//  SIMSme
//
//  Created by RBU on 23/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGInitialPasswordForgotViewController: DPAGViewControllerBackground {
    @IBOutlet private var scrollView: UIScrollView!

    @IBOutlet private var labelTitle: UILabel! {
        didSet {
            self.labelTitle.text = DPAGLocalizedString("registration.labelTitle.forgotPassword")
            self.labelTitle.numberOfLines = 0
            self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
            self.labelTitle.font = UIFont.kFontTitle1
        }
    }

    @IBOutlet private var labelDescription1: UILabel! {
        didSet {
            self.labelDescription1.text = DPAGLocalizedString("registration.labelDescription1.forgotPassword")
            self.labelDescription1.numberOfLines = 0
            self.labelDescription1.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDescription1.font = UIFont.kFontSubheadline
        }
    }

    @IBOutlet private var labelDescription2: UILabel! {
        didSet {
            self.labelDescription2.text = DPAGLocalizedString("registration.labelDescription2.forgotPassword")
            self.labelDescription2.numberOfLines = 0
            self.labelDescription2.textColor = DPAGColorProvider.shared[.labelDestructive]
            self.labelDescription2.font = UIFont.kFontFootnote
        }
    }

    @IBOutlet private var viewImageAlert: UIImageView! {
        didSet {
            self.viewImageAlert.image = DPAGImageProvider.shared[.kImageAlertLarge]
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDescription1.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDescription2.textColor = DPAGColorProvider.shared[.labelDestructive]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("registration.buttonNextLabel.forgotPassword"), for: .normal)
            self.viewButtonNext.button.addTarget(self, action: #selector(buttonNextAction), for: .touchUpInside)
        }
    }

    init() {
        super.init(nibName: "DPAGInitialPasswordForgotViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.configureGui()
    }

    private func configureGui() {
        self.title = DPAGLocalizedString("registration.title.forgotPassword")

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(buttonCancelAction))
    }

    @objc
    private func buttonNextAction() {
        let alertOptionForgot = AlertOption(titleKey: "registration.buttonNextLabel.forgotPassword", style: .destructive, image: nil, textAlignment: nil, accesibilityIdentifier: "registration.buttonNextLabel.forgotPassword") {
            NotificationCenter.default.post(name: DPAGStrings.Notification.Application.SECURITY_RESET_APP, object: nil)
        }
        let alert = UIAlertController.controller(options: [alertOptionForgot, AlertOption.cancelOption()], titleKey: "registration.alert.forgotPassword.title", withStyle: .actionSheet, sourceView: viewButtonNext)
        self.presentAlertController(alert)
    }

    @objc
    private func buttonCancelAction() {
        self.dismiss(animated: true, completion: nil)
    }
}
