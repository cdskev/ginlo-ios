//
//  DPAGShowIdentityViewController.swift
//  SIMSme
//
//  Created by RBU on 28.11.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGShowIdentityViewController: DPAGViewControllerBackground {
    @IBOutlet private var labelDescription: UILabel! {
        didSet {
            self.labelDescription.font = UIFont.kFontTitle1
            self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDescription.numberOfLines = 0
            self.labelDescription.text = DPAGLocalizedString("registration.identity.label.description")
        }
    }

    @IBOutlet private var imageViewFingerprint: UIImageView! {
        didSet {
            self.imageViewFingerprint.image = DPAGImageProvider.shared[.kImageFingerprint]
            self.imageViewFingerprint.tintColor = DPAGColorProvider.shared[.accountID]
        }
    }

    @IBOutlet private var labelAccountID: UILabel! {
        didSet {
            self.labelAccountID.font = UIFont.kFontShowIdentityAccountID
            self.labelAccountID.textColor = DPAGColorProvider.shared[.accountID]
            self.labelAccountID.textAlignment = .center
            self.labelAccountID.adjustsFontSizeToFitWidth = true
        }
    }

    @IBOutlet private var labelInfo: UILabel! {
        didSet {
            self.labelInfo.font = UIFont.kFontSubheadline
            self.labelInfo.textColor = DPAGColorProvider.shared[.labelText]
            self.labelInfo.numberOfLines = 0
            self.labelInfo.text = DPAGLocalizedString("registration.identity.label.info")
        }
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.accessibilityIdentifier = "buttonContinue"
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("registration.identity.button.continue.title"), for: .normal)
            self.viewButtonNext.button.addTarget(self, action: #selector(handleContinue), for: .touchUpInside)
        }
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.imageViewFingerprint.tintColor = DPAGColorProvider.shared[.accountID]
                self.labelAccountID.textColor = DPAGColorProvider.shared[.accountID]
                self.labelInfo.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    private let accountID: String

    init(accountID: String) {
        self.accountID = accountID
        super.init(nibName: "DPAGShowIdentityViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        let bundleIdentifier = DPAGMandant.default.name

        self.title = String(format: DPAGLocalizedString("registration.identity.title"), bundleIdentifier)

        self.labelAccountID.text = self.accountID
    }

    override func viewFirstAppear(_ animated: Bool) {
        super.viewFirstAppear(animated)

        DPAGApplicationFacade.preferences.didShowProfileInfo = true
    }

    @objc
    private func handleContinue() {
        self.dismiss(animated: true, completion: nil)
    }
}
