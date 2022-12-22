//
//  DPAGCreateDeviceWelcomeViewController.swift
// ginlo
//
//  Created by RBU on 06.12.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGCreateDeviceWelcomeViewController: DPAGViewControllerBackground, DPAGNavigationViewControllerStyler {
    @IBOutlet var stackViewBackup: UIStackView!
    @IBOutlet var stackViewDeviceCreate: UIStackView!
    @IBOutlet private var labelTitle: UILabel! {
        didSet {
            let bundleIdentifier = DPAGMandant.default.name
            self.labelTitle.text = String(format: DPAGLocalizedString("registration.createDevice.welcome.title"), bundleIdentifier)
            self.labelTitle.font = UIFont.kFontTitle1
            self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
            self.labelTitle.numberOfLines = 0
        }
    }

    @IBOutlet private var labelDescription: UILabel! {
        didSet {
            let bundleIdentifier = DPAGMandant.default.name
            self.labelDescription.text = String(format: DPAGLocalizedString("registration.createDevice.welcome.description"), bundleIdentifier)
            self.labelDescription.font = UIFont.kFontSubheadline
            self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDescription.numberOfLines = 0
        }
    }

    @IBOutlet private var btnBackup: UIButton! {
        didSet {
            self.btnBackup.accessibilityIdentifier = "btnBackup"
            self.btnBackup.setTitle(nil, for: .normal)
            self.btnBackup.setImage(DPAGImageProvider.shared[.kImageDeviceBackupLarge], for: .normal)
            self.btnBackup.addTarget(self, action: #selector(handleBackup), for: .touchUpInside)
        }
    }

    @IBOutlet private var imageViewBackupCheck: UIImageView! {
        didSet {
            self.imageViewBackupCheck.configureCheck()
            self.imageViewBackupCheck.isHidden = true
        }
    }

    @IBOutlet private var labelBackup: UILabel! {
        didSet {
            self.labelBackup.text = DPAGLocalizedString("registration.backup_recover.btnRecover.title").uppercased()
            self.labelBackup.textColor = DPAGColorProvider.shared[.labelText]
            self.labelBackup.font = UIFont.kFontFootnote
            self.labelBackup.numberOfLines = 0
            self.labelBackup.textAlignment = .center
        }
    }

    @IBOutlet private var btnDeviceCreate: UIButton! {
        didSet {
            self.btnDeviceCreate.accessibilityIdentifier = "btnDeviceCreate"
            self.btnDeviceCreate.setTitle(nil, for: .normal)
            self.btnDeviceCreate.setImage(DPAGImageProvider.shared[.kImageDeviceCreateLarge], for: .normal)
            self.btnDeviceCreate.addTarget(self, action: #selector(handleDeviceCreate), for: .touchUpInside)
        }
    }

    @IBOutlet private var imageViewDeviceCreateCheck: UIImageView! {
        didSet {
            self.imageViewDeviceCreateCheck.configureCheck()
            self.imageViewDeviceCreateCheck.isHidden = true
        }
    }

    @IBOutlet private var labelDeviceCreate: UILabel! {
        didSet {
            self.labelDeviceCreate.text = DPAGLocalizedString("registration.backup_recover.footer_info.ba1").uppercased()
            self.labelDeviceCreate.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDeviceCreate.font = UIFont.kFontFootnote
            self.labelDeviceCreate.numberOfLines = 0
            self.labelDeviceCreate.textAlignment = .center
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.labelBackup.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDeviceCreate.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.accessibilityIdentifier = "btnContinue"
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("res.continue"), for: .normal)
            self.viewButtonNext.button.addTarget(self, action: #selector(handleContinue), for: .touchUpInside)
            self.viewButtonNext.isEnabled = false
        }
    }

    init() {
        super.init(nibName: "DPAGCreateDeviceWelcomeViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = DPAGLocalizedString("registration.title.welcome")
        if AppConfig.multiDeviceAllowed == false && DPAGApplicationFacade.preferences.isBaMandant == false {
            self.stackViewDeviceCreate.isHidden = true
            self.handleBackup()
            self.labelBackup.isHidden = true
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        self.setNeedsStatusBarAppearanceUpdate()
    }

    @objc
    private func handleBackup() {
        self.imageViewBackupCheck.isHidden = false
        self.imageViewDeviceCreateCheck.isHidden = true
        self.viewButtonNext.isEnabled = true
    }

    @objc
    private func handleDeviceCreate() {
        self.imageViewBackupCheck.isHidden = true
        self.imageViewDeviceCreateCheck.isHidden = false
        self.viewButtonNext.isEnabled = true
    }

    @objc
    private func handleContinue() {
        if self.imageViewDeviceCreateCheck.isHidden {
            self.navigationController?.pushViewController(DPAGApplicationFacadeUIRegistration.initialPasswordVC(initialPasswordJob: .createAccount), animated: true)
        } else {
            self.navigationController?.pushViewController(DPAGApplicationFacadeUIRegistration.initialPasswordVC(initialPasswordJob: .createDevice), animated: true)
        }
    }
}
