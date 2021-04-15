//
//  DPAGBackupCreateTableViewCell.swift
//  SIMSmeUIViewsLib
//
//  Created by RBU on 25.07.18.
//  Copyright © 2019 Deutsche Post AG. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGBackupCreateTableViewCellProtocol: AnyObject {
    var delegate: DPAGBackupCreateTableViewCellDelegate? { get set }

    func configure()
}

public protocol DPAGBackupCreateTableViewCellDelegate: AnyObject {
    func handleCloudEnableInfo()
    func handleCreateBackup()
}

public class DPAGBackupCreateTableViewCell: UITableViewCell, DPAGBackupCreateTableViewCellProtocol {
    @IBOutlet private var stackViewHeader: UIStackView!

    @IBOutlet private var imageViewCloud: UIImageView! {
        didSet {
            self.imageViewCloud.image = DPAGImageProvider.shared[.kImageCloud]
            self.imageViewCloud.backgroundColor = UIColor.clear
        }
    }

    @IBOutlet private var viewCloudSettingsEnable: DPAGStackViewContentView! {
        didSet {
            self.viewCloudSettingsEnable.isUserInteractionEnabled = true
            self.viewCloudSettingsEnable.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleCloudEnableInfo))
            self.viewCloudSettingsEnable.addGestureRecognizer(tapGesture)
        }
    }

    @IBOutlet private var imageViewCloudSettingsEnable: UIImageView! {
        didSet {
            self.imageViewCloudSettingsEnable.image = DPAGImageProvider.shared[.kImageCloudWhite]
            self.imageViewCloudSettingsEnable.contentMode = .scaleAspectFit
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleCloudEnableInfo))
            self.imageViewCloudSettingsEnable.addGestureRecognizer(tapGesture)
        }
    }

    @IBOutlet private var labelCloudSettingsEnable: UILabel! {
        didSet {
            self.labelCloudSettingsEnable.text = DPAGLocalizedString("settings.backup.cloudInfo.label")
            self.labelCloudSettingsEnable.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
            self.labelCloudSettingsEnable.font = UIFont.kFontFootnote
            self.labelCloudSettingsEnable.numberOfLines = 0
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleCloudEnableInfo))
            self.labelCloudSettingsEnable.addGestureRecognizer(tapGesture)
        }
    }

    @IBOutlet private var labelLastBackup: UILabel! {
        didSet {
            self.labelLastBackup.font = UIFont.kFontHeadline
            self.labelLastBackup.textColor = DPAGColorProvider.shared[.labelText]
            self.labelLastBackup.text = DPAGLocalizedString("settings.backup.lastBackup.label")
        }
    }

    @IBOutlet private var labelLastBackupDetails: UILabel! {
        didSet {
            self.labelLastBackupDetails.font = UIFont.kFontHeadline
            self.labelLastBackupDetails.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelBackupInfo: UILabel! {
        didSet {
            self.labelBackupInfo.font = UIFont.kFontSubheadline
            self.labelBackupInfo.textColor = DPAGColorProvider.shared[.labelText]
            self.labelBackupInfo.numberOfLines = 0

            let btnTitle = DPAGLocalizedString("settings.backup.btnCreateBackup.label")

            self.labelBackupInfo.text = String(format: DPAGLocalizedString("settings.backup.backupInfoInit.label"), btnTitle)
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.viewCloudSettingsEnable.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
                self.labelCloudSettingsEnable.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
                self.labelLastBackup.textColor = DPAGColorProvider.shared[.labelText]
                self.labelLastBackupDetails.textColor = DPAGColorProvider.shared[.labelText]
                self.labelBackupInfo.textColor = DPAGColorProvider.shared[.labelText]
                self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var btnCreateBackup: UIButton! {
        didSet {
            self.btnCreateBackup.accessibilityIdentifier = "btnCreateBackup"
            self.btnCreateBackup.setTitle(DPAGLocalizedString("settings.backup.btnCreateBackup.label"), for: .normal)
            self.btnCreateBackup.addTarget(self, action: #selector(handleCreateBackup), for: .touchUpInside)
            self.btnCreateBackup.configureButton()
        }
    }

    public weak var delegate: DPAGBackupCreateTableViewCellDelegate?

    override public func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.selectionStyle = .none
    }

    @objc
    private func handleCloudEnableInfo() {
        self.delegate?.handleCloudEnableInfo()
    }

    @objc
    private func handleCreateBackup() {
        self.delegate?.handleCreateBackup()
    }

    private func addCloudConstraints() {
        // Check iCloud settings
        if (try? DPAGApplicationFacade.backupWorker.isICloudEnabled()) ?? false {
            self.viewCloudSettingsEnable.isHidden = true
            self.btnCreateBackup.isEnabled = true
        } else {
            self.viewCloudSettingsEnable.isHidden = false
            self.btnCreateBackup.isEnabled = false
        }
    }

    private func updateBackupDate() {
        if let lastBackup = DPAGApplicationFacade.preferences.backupLastDate {
            self.labelLastBackupDetails.text = DateFormatter.localizedString(from: lastBackup, dateStyle: .short, timeStyle: .short)
            self.labelLastBackupDetails.accessibilityIdentifier = "LastBackupDetails-HaveDateTime"
        } else {
            self.labelLastBackupDetails.text = DPAGLocalizedString("settings.backup.lastBackupDetails.label")
            self.labelLastBackupDetails.accessibilityIdentifier = "LastBackupDetails-NoBackup"
        }
    }

    public func configure() {
        self.addCloudConstraints()
        self.updateBackupDate()
    }
}
