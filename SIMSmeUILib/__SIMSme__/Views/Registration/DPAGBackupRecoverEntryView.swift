//
//  DPAGBackupRecoverEntryView.swift
// ginlo
//
//  Created by RBU on 27.11.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGBackupRecoverEntryViewProtocol: AnyObject {
    var isSelected: Bool { get set }

    func configure(backupEntry: DPAGBackupFileInfo)
}

class DPAGBackupRecoverEntryView: UIView, DPAGBackupRecoverEntryViewProtocol {
    var isSelected: Bool = false {
        didSet {
            if self.isSelected {
                if self.imageViewCheck.isHidden {
                    self.imageViewCheck.isHidden = false
                }
            } else if self.imageViewCheck.isHidden == false {
                self.imageViewCheck.isHidden = true
            }
        }
    }

    @IBOutlet private var labelBackupSize: UILabel! {
        didSet {
            self.labelBackupSize.font = UIFont.kFontHeadline
            self.labelBackupSize.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelBackupTime: UILabel! {
        didSet {
            self.labelBackupTime.font = UIFont.kFontFootnote
            self.labelBackupTime.textColor = DPAGColorProvider.shared[.labelText]
            self.labelBackupTime.numberOfLines = 0
        }
    }

    @IBOutlet private var labelBackupMandant: UILabel! {
        didSet {
            self.labelBackupMandant.font = UIFont.kFontBadge
            self.labelBackupMandant.textColor = DPAGColorProvider.shared[.mandantText]
        }
    }

    @IBOutlet private var imageViewCheck: UIImageView! {
        didSet {
            self.imageViewCheck.configureCheck()
            self.imageViewCheck.isHidden = true
        }
    }

    @IBOutlet private var viewBackupMandant: UIView! {
        didSet {
            self.viewBackupMandant.backgroundColor = DPAGColorProvider.shared[.mandantBackground]
            self.viewBackupMandant.layer.cornerRadius = 10
            self.viewBackupMandant.layer.masksToBounds = true
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code

        self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelBackupSize.textColor = DPAGColorProvider.shared[.labelText]
                self.labelBackupTime.textColor = DPAGColorProvider.shared[.labelText]
                self.labelBackupMandant.textColor = DPAGColorProvider.shared[.mandantText]
                self.viewBackupMandant.backgroundColor = DPAGColorProvider.shared[.mandantBackground]
                self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    func configure(backupEntry: DPAGBackupFileInfo) {
        if let backupDate = backupEntry.backupDate {
            self.labelBackupTime.text = backupDate.timeLabelMedia
        } else {
            self.labelBackupTime.text = ""
        }
        self.labelBackupSize.text = DPAGFormatter.fileSize.string(fromByteCount: backupEntry.fileSize?.int64Value ?? 0)

        self.labelBackupMandant.text = backupEntry.appName

        if let mandant = DPAGApplicationFacade.preferences.mandanten.first(where: { (mandant) -> Bool in
            mandant.ident == backupEntry.mandantIdent || mandant.label == backupEntry.appName || mandant.ident == backupEntry.appName
        }) {
            self.labelBackupMandant.textColor = DPAGColorProvider.shared.kColorAccentMandant[mandant.ident]
            self.viewBackupMandant.backgroundColor = DPAGColorProvider.shared.kColorAccentMandantContrast[mandant.ident]
        } else {
            self.labelBackupMandant.textColor = DPAGColorProvider.shared[.labelTextForBackgroundInverted]
            self.viewBackupMandant.backgroundColor = DPAGColorProvider.shared[.defaultViewBackgroundInverted]
        }
    }
}
