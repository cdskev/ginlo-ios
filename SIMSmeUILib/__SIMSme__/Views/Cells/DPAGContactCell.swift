//
//  DPAGContactCell.swift
//  SIMSme
//
//  Created by RBU on 24/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGContactCellProtocol: AnyObject {
    var labelText: UILabel! { get }
    var labelTextDetail: UILabel! { get }
    var labelTextExtended: UILabel! { get }
    var imageViewProfile: UIImageView! { get }
    var imageViewCheck: UIImageView! { get }
    var imageViewUncheck: UIImageView! { get }
    var viewMandant: UIView! { get }
    var labelMandant: UILabel! { get }

    func update(contact: DPAGContact)
}

class DPAGContactCell: UITableViewCell, DPAGContactCellProtocol {
    private let mandanten = AppConfig.isShareExtension ? DPAGApplicationFacadeShareExt.preferences.mandantenDict : DPAGApplicationFacade.preferences.mandantenDict

    @IBOutlet var imageViewProfile: UIImageView! {
        didSet {
            self.imageViewProfile.layer.cornerRadius = self.imageViewProfile.frame.size.height / 2
            self.imageViewProfile.layer.masksToBounds = true
            // self.imageViewProfile.layer.borderWidth = 2
        }
    }

    @IBOutlet var labelText: UILabel! {
        didSet {
            self.labelText.backgroundColor = UIColor.clear
            self.labelText.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet var labelTextDetail: UILabel! {
        didSet {
            self.labelTextDetail.backgroundColor = UIColor.clear
            self.labelTextDetail.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet var labelTextExtended: UILabel! {
        didSet {
            self.labelTextExtended.backgroundColor = UIColor.clear
            self.labelTextExtended.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet var imageViewCheck: UIImageView! {
        didSet {
            self.imageViewCheck.configureCheck()
            self.imageViewCheck.isHidden = true
        }
    }

    @IBOutlet var imageViewUncheck: UIImageView! {
        didSet {
            self.imageViewUncheck.configureUncheck()
            self.imageViewUncheck.isHidden = true
        }
    }

    @IBOutlet var viewMandant: UIView! {
        didSet {
            self.viewMandant.backgroundColor = DPAGColorProvider.shared[.mandantBackground]
            self.viewMandant.layer.cornerRadius = 2
            self.viewMandant.layer.masksToBounds = true
        }
    }

    @IBOutlet var labelMandant: UILabel! {
        didSet {
            self.labelMandant.font = UIFont.kFontBadge
            self.labelMandant.textColor = DPAGColorProvider.shared[.mandantText]
            self.labelMandant.text = nil
            self.labelMandant.textAlignment = .center
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code

        self.configCell()
    }

    private var colorViewMandantBackground: UIColor?

    override var isSelected: Bool {
        willSet {
            self.colorViewMandantBackground = self.viewMandant.backgroundColor
        }
        didSet {
            if self.isSelected {
                self.resetSelectionColors()
            }
        }
    }

    override var isHighlighted: Bool {
        willSet {
            self.colorViewMandantBackground = self.viewMandant.backgroundColor
        }
        didSet {
            if self.isHighlighted {
                self.resetSelectionColors()
            }
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        self.colorViewMandantBackground = self.viewMandant.backgroundColor
        super.setSelected(selected, animated: animated)
        self.resetSelectionColors()
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        self.colorViewMandantBackground = self.viewMandant.backgroundColor
        super.setHighlighted(highlighted, animated: animated)
        self.resetSelectionColors()
    }

    private func resetSelectionColors() {
        self.viewMandant.backgroundColor = self.colorViewMandantBackground
        self.imageViewCheck.backgroundColor = DPAGColorProvider.shared[.imageCheck]
        self.imageViewUncheck.backgroundColor = DPAGColorProvider.shared[.imageUncheck]
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.contentView.setNeedsLayout()
        self.contentView.layoutIfNeeded()

        self.labelText.preferredMaxLayoutWidth = self.labelText.frame.width
        self.labelTextDetail.preferredMaxLayoutWidth = self.labelTextDetail.frame.width
        self.labelTextExtended.preferredMaxLayoutWidth = self.labelTextExtended.frame.width
        self.labelMandant.preferredMaxLayoutWidth = self.labelMandant.frame.width
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func configCell() {
        self.labelText.adjustsFontForContentSizeCategory = true
        self.labelTextDetail.adjustsFontForContentSizeCategory = true
        self.labelTextExtended.adjustsFontForContentSizeCategory = true
        self.labelMandant.adjustsFontForContentSizeCategory = true

        self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.contentView.backgroundColor = .clear

        self.setSelectionColor()

        self.updateFonts()
    }

    func update(contact: DPAGContact) {
        if contact.attributedDisplayName == nil {
            self.labelText?.attributedText = nil
            self.labelText?.text = contact.displayName
        } else {
            self.labelText?.text = nil
            self.labelText?.attributedText = contact.attributedDisplayName
        }

        self.imageViewProfile?.image = contact.image(for: .contactList)

        self.setMandanten(contact)

        if let department = contact.department, department.isEmpty == false {
            self.labelTextDetail.text = department
        } else if let simsmeID = contact.accountID, simsmeID.isEmpty == false {
            self.labelTextDetail.text = simsmeID
        } else if DPAGApplicationFacade.preferences.isWhiteLabelBuild == false {
            self.labelTextDetail.text = contact.statusMessageFallback
        } else {
            self.labelTextDetail.text = nil
        }

        self.labelTextExtended.text = contact.eMailAddress ?? contact.phoneNumber

        self.labelText.isHidden = (self.labelText.text?.isEmpty ?? true)
        self.labelTextExtended.isHidden = (self.labelTextExtended.text?.isEmpty ?? true)

        self.accessibilityIdentifier = "contact-" + contact.guid
    }

    fileprivate func setMandanten(_ contact: DPAGContact) {
        switch contact.entryTypeServer {
            case .meMyselfAndI:
                self.labelMandant.text = nil
                self.viewMandant.backgroundColor = .clear
                self.labelMandant.textColor = .clear
            case .privat where DPAGMandant.IDENT_DEFAULT == contact.mandantIdent && DPAGApplicationFacade.preferences.isBaMandant:
                let text = DPAGFunctionsGlobal.DPAGLocalizedString("contacts.mandant.private")
                self.labelMandant.text = text.uppercased()
                self.viewMandant.backgroundColor = DPAGColorProvider.shared[.mandantBackground]
                self.labelMandant.textColor = DPAGColorProvider.shared[.mandantText]
            case .privat:
                let text = contact.mandantIdent == DPAGMandant.IDENT_DEFAULT
                    ? DPAGFunctionsGlobal.DPAGLocalizedString("contacts.mandant.private")
                    : (self.mandanten[contact.mandantIdent]?.label ?? contact.mandantIdent)
                self.labelMandant.text = text.uppercased()
                self.viewMandant.backgroundColor = DPAGColorProvider.shared.kColorAccentMandantContrast[contact.mandantIdent] ?? DPAGColorProvider.shared[.mandantBackground]
                self.labelMandant.textColor = DPAGColorProvider.shared.kColorAccentMandant[contact.mandantIdent] ?? DPAGColorProvider.shared[.mandantText]
            default:
                let text = DPAGFunctionsGlobal.DPAGLocalizedString("contacts.mandant.internal")
                self.labelMandant.text = text.uppercased()
                self.viewMandant.backgroundColor = DPAGColorProvider.shared[.contactInternal]
                self.labelMandant.textColor = DPAGColorProvider.shared[.contactInternalContrast]
        }
    }

    @objc
    private func updateFonts() {
        self.labelText.font = UIFont.kFontHeadline
        self.labelTextDetail.font = UIFont.kFontFootnote
        self.labelTextExtended.font = UIFont.kFontFootnote
    }
    
    @objc
    func handleDesignColorsUpdated() {
        self.labelText.textColor = DPAGColorProvider.shared[.labelText]
        self.labelTextDetail.textColor = DPAGColorProvider.shared[.labelText]
        self.labelTextExtended.textColor = DPAGColorProvider.shared[.labelText]
        self.imageViewCheck.backgroundColor = DPAGColorProvider.shared[.imageCheck]
        self.imageViewUncheck.backgroundColor = DPAGColorProvider.shared[.imageUncheck]
        self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
    }
    
    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.handleDesignColorsUpdated()
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
