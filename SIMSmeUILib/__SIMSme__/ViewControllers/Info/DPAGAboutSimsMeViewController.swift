//
//  DPAGAboutSimsMeViewController.swift
// ginlo
//
//  Created by RBU on 26/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGAboutSimsMeViewController: DPAGViewControllerBackground {
    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var appLabel: InfoLabel!
    @IBOutlet private var appTextLabel: InfoSubLabel!
    @IBOutlet private var secureLabel: InfoLabel!
    @IBOutlet private var secureTextLabel: InfoSubLabel!
    @IBOutlet private var highLabel: InfoLabel!
    @IBOutlet private var highTextLabel: InfoSubLabel!
    @IBOutlet private var middleLabel: InfoLabel!
    @IBOutlet private var middleTextLabel: InfoSubLabel!
    @IBOutlet private var lowLabel: InfoLabel!
    @IBOutlet private var lowTextLabel: InfoSubLabel!
    @IBOutlet private var statusLabel: InfoLabel!
    @IBOutlet private var statusTextLabel: InfoSubLabel!
    @IBOutlet private var viewConfidenceStateHigh: UIView!
    @IBOutlet private var viewConfidenceStateMiddle: UIView!
    @IBOutlet private var viewConfidenceStateLow: UIView!
    @IBOutlet private var readImageView: UIImageView!
    @IBOutlet private var receivedImageView: UIImageView!
    @IBOutlet private var sentImageView: UIImageView!
    @IBOutlet private var readLabel: InfoSubLabel!
    @IBOutlet private var receivedLabel: InfoSubLabel!
    @IBOutlet private var sentLabel: InfoSubLabel!
    @IBOutlet private var sentStatusView: UIView!

    init() {
        super.init(nibName: "DPAGAboutSimsMeViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.view.accessibilityIdentifier = "\(type(of: self))".components(separatedBy: ".").last

        self.navigationItem.title = DPAGLocalizedString("settings.aboutSimsme")

        setupViews()
    }

    private func setupViews() {
        self.appLabel.text = DPAGLocalizedString("settings.aboutSimsme.appLabel")
        self.appTextLabel.text = DPAGLocalizedString("settings.aboutSimsme.appTextLabel")

        self.secureLabel.text = DPAGLocalizedString("settings.aboutSimsme.secureLabel")
        self.secureTextLabel.text = DPAGLocalizedString("settings.aboutSimsme.secureTextLabel")

        self.highLabel.text = DPAGLocalizedString("settings.aboutSimsme.highLabel")
        self.highTextLabel.text = DPAGLocalizedString("settings.aboutSimsme.highTextLabel")

        self.middleLabel.text = DPAGLocalizedString("settings.aboutSimsme.middleLabel")
        self.middleTextLabel.text = DPAGLocalizedString("settings.aboutSimsme.middleTextLabel")

        self.lowLabel.text = DPAGLocalizedString("settings.aboutSimsme.lowLabel")
        self.lowTextLabel.text = DPAGLocalizedString("settings.aboutSimsme.lowTextLabel")

        self.statusLabel.text = DPAGLocalizedString("settings.aboutSimsme.statusLabel")
        self.statusTextLabel.text = DPAGLocalizedString("settings.aboutSimsme.statusTextLabel")

        self.viewConfidenceStateHigh.backgroundColor = DPAGColorProvider.shared[.trustLevelHigh]
        self.viewConfidenceStateMiddle.backgroundColor = DPAGColorProvider.shared[.trustLevelMedium]
        self.viewConfidenceStateLow.backgroundColor = DPAGColorProvider.shared[.trustLevelLow]

        self.readImageView.image = DPAGImageProvider.shared[.kImageSendStateRead]
        self.readImageView.tintColor = DPAGColorProvider.shared[.imageSendStateReadTint]

        self.receivedImageView.image = DPAGImageProvider.shared[.kImageSendStateReceived]

        self.sentImageView.image = DPAGImageProvider.shared[.kImageSendStateSent]

        self.readLabel.text = DPAGLocalizedString("settings.aboutSimsme.readLabel")
        self.receivedLabel.text = DPAGLocalizedString("settings.aboutSimsme.receivedLabel")
        self.sentLabel.text = DPAGLocalizedString("settings.aboutSimsme.sentLabel")
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.viewConfidenceStateHigh.backgroundColor = DPAGColorProvider.shared[.trustLevelHigh]
                self.viewConfidenceStateMiddle.backgroundColor = DPAGColorProvider.shared[.trustLevelMedium]
                self.viewConfidenceStateLow.backgroundColor = DPAGColorProvider.shared[.trustLevelLow]
                self.readImageView.tintColor = DPAGColorProvider.shared[.imageSendStateReadTint]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

}
