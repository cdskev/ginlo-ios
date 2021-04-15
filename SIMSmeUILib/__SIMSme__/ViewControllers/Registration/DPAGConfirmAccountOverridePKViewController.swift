//
//  DPAGConfirmAccountOverridePKViewController.swift
//  SIMSme
//
//  Created by RBU on 30.01.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGConfirmAccountOverridePKViewController: DPAGViewControllerBackground {
    @IBOutlet private var scrollView: UIScrollView!

    @IBOutlet private var viewInfo: UIView! {
        didSet {
            self.viewInfo.backgroundColor = UIColor.clear
        }
    }

    @IBOutlet private var imageViewInfo: UIImageView! {
        didSet {
            self.imageViewInfo.image = DPAGImageProvider.shared[.kImageAlertLarge]
        }
    }

    @IBOutlet private var labelHeadline: UILabel! {
        didSet {
            self.labelHeadline.text = DPAGLocalizedString("registration.confirm_override.headlinePK")
            self.labelHeadline.font = UIFont.kFontHeadline
            self.labelHeadline.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelDescription: UILabel! {
        didSet {
            self.labelDescription.text = DPAGLocalizedString("registration.confirm_override.descriptionPK")
            self.labelDescription.font = UIFont.kFontSubheadline
            self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDescription.numberOfLines = 0
        }
    }

    @IBOutlet private var labelConfirmation: UILabel! {
        didSet {
            self.labelConfirmation.text = DPAGLocalizedString("registration.confirm_override.confirmationPK")
            self.labelConfirmation.font = UIFont.kFontHeadline
            self.labelConfirmation.textColor = DPAGColorProvider.shared[.labelText]
            self.labelConfirmation.numberOfLines = 0
        }
    }

    @IBOutlet private var btnConfirmOverride: UIButton! {
        didSet {
            self.btnConfirmOverride.accessibilityIdentifier = "btnConfirmOverride"
            self.btnConfirmOverride.configureButtonDestructive()
            self.btnConfirmOverride.addTarget(self, action: #selector(handleOverride), for: .touchUpInside)
            self.btnConfirmOverride.setTitle(DPAGLocalizedString("registration.confirm_override.btnConfirmOverridePK"), for: .normal)
        }
    }

    @IBOutlet private var viewBtnCancel: UIView! {
        didSet {
            self.viewBtnCancel.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelHeadline.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.labelConfirmation.textColor = DPAGColorProvider.shared[.labelText]
                self.viewBtnCancel.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var btnCancel: UIButton! {
        didSet {
            self.btnCancel.accessibilityIdentifier = "btnCancel"
            self.btnCancel.configurePrimaryButton()
            self.btnCancel.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
            self.btnCancel.setTitle(DPAGLocalizedString("res.cancel"), for: .normal)
        }
    }

    private let backupEntry: DPAGBackupFileInfo

    private weak var delegate: DPAGBackupRecoverViewControllerPKDelegate?

    init(backupEntry: DPAGBackupFileInfo, delegate: DPAGBackupRecoverViewControllerPKDelegate?) {
        self.backupEntry = backupEntry
        self.delegate = delegate

        super.init(nibName: "DPAGConfirmAccountOverrideViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.navigationItem.title = DPAGLocalizedString("registration.confirm_override.titlePK")
    }

    @objc
    private func handleCancel() {
        self.dismiss(animated: true, completion: nil)
    }

    @objc
    private func handleOverride() {
        self.dismiss(animated: true) { [weak self] in

            if let backupEntry = self?.backupEntry {
                self?.delegate?.handleProceedWithBackupOverride(backupEntry: backupEntry)
            }
        }
    }
}
