//
//  DPAGBackupCloudInfoViewController.swift
// ginlo
//
//  Created by RBU on 06/06/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGBackupCloudInfoViewController: DPAGViewControllerBackground {
    @IBOutlet private var labelHeadline: UILabel! {
        didSet {
            self.labelHeadline.font = UIFont.kFontTitle1
            self.labelHeadline.textColor = DPAGColorProvider.shared[.labelText]
            self.labelHeadline.text = DPAGLocalizedString("registration.backup.cloud_info.headline")
        }
    }

    @IBOutlet private var labelDescription: UILabel! {
        didSet {
            self.labelDescription.font = UIFont.kFontSubheadline
            self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]

            let bundleIdentifier = DPAGMandant.default.name

            self.labelDescription.text = String(format: DPAGLocalizedString("registration.backup.cloud_info.description"), bundleIdentifier)
        }
    }

    @IBOutlet var labelActivate: UILabel! {
        didSet {
            self.labelActivate.font = UIFont.kFontHeadline
            self.labelActivate.textColor = DPAGColorProvider.shared[.labelText]
            self.labelActivate.text = DPAGLocalizedString("registration.backup.not_found.info_no_cloud")
        }
    }

    @IBOutlet private var labelStep1: UILabel! {
        didSet {
            self.labelStep1.text = "1"
            self.configureLabelStep(self.labelStep1)
        }
    }

    @IBOutlet private var labelStep2: UILabel! {
        didSet {
            self.labelStep2.text = "2"
            self.configureLabelStep(self.labelStep2)
        }
    }

    @IBOutlet private var labelStep3: UILabel! {
        didSet {
            self.labelStep3.text = "3"
            self.configureLabelStep(self.labelStep3)
        }
    }

    @IBOutlet private var label0: UILabel! {
        didSet {
            self.label0.font = UIFont.kFontSubheadline
            self.label0.textColor = DPAGColorProvider.shared[.labelText]
            self.label0.text = DPAGLocalizedString("registration.backup.cloud_info.open_settings")
        }
    }

    @IBOutlet private var label1: UILabel! {
        didSet {
            self.label1.font = UIFont.kFontSubheadline
            self.label1.textColor = DPAGColorProvider.shared[.labelText]
            self.label1.text = DPAGLocalizedString("registration.backup.cloud_info.enable_icloud")
        }
    }

    @IBOutlet private var label2: UILabel! {
        didSet {
            self.label2.font = UIFont.kFontSubheadline
            self.label2.textColor = DPAGColorProvider.shared[.labelText]
            let bundleIdentifier = DPAGMandant.default.name

            self.label2.text = String(format: DPAGLocalizedString("registration.backup.cloud_info.enable_icloud_simsme"), bundleIdentifier)
        }
    }

    @IBOutlet private var viewNoCloud: UIView! {
        didSet {
            self.viewNoCloud.backgroundColor = .clear
            self.viewNoCloud.layer.cornerRadius = 3
            self.viewNoCloud.layer.masksToBounds = true
        }
    }

    @IBOutlet private var labelNoCloud: UILabel! {
        didSet {
            self.labelNoCloud.font = UIFont.kFontHeadline
            self.labelNoCloud.textColor = DPAGColorProvider.shared[.labelText]

            let bundleIdentifier = DPAGMandant.default.name

            self.labelNoCloud.text = bundleIdentifier
        }
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelHeadline.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.labelActivate.textColor = DPAGColorProvider.shared[.labelText]
                self.label0.textColor = DPAGColorProvider.shared[.labelText]
                self.label1.textColor = DPAGColorProvider.shared[.labelText]
                self.label2.textColor = DPAGColorProvider.shared[.labelText]
                self.labelNoCloud.textColor = DPAGColorProvider.shared[.labelText]
                self.configureLabelStep(self.labelStep1)
                self.configureLabelStep(self.labelStep2)
                self.configureLabelStep(self.labelStep3)
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var switchNoCloud: UISwitch! {
        didSet {
            self.switchNoCloud.isOn = true
            self.switchNoCloud.isUserInteractionEnabled = false
        }
    }

    init() {
        super.init(nibName: "DPAGBackupCloudInfoViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.navigationItem.title = DPAGLocalizedString("registration.backup.cloud_info.title")
    }

    private func configureLabelStep(_ label: UILabel) {
        label.font = UIFont.kFontCounter
        label.textAlignment = .center
        label.textColor = DPAGColorProvider.shared[.labelTextForBackgroundInverted]
        label.backgroundColor = DPAGColorProvider.shared[.defaultViewBackgroundInverted]
        label.layer.cornerRadius = 15
        label.layer.masksToBounds = true
    }
}
