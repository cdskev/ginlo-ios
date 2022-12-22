//
//  DPAGCompanyContactsOverviewEmpty.swift
// ginlo
//
//  Created by Yves Hetzer on 27.10.16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGContactsDomainEmptyViewProtocol: AnyObject {
    var viewBtnStartEMail: UIView! { get }
    var btnStartEMail: UIButton! { get }
    var labelHeader: UILabel! { get }
    var labelDescription: UILabel! { get }
    var labelHint: UILabel! { get }
}

class DPAGContactsDomainEmpty: DPAGView, DPAGContactsDomainEmptyViewProtocol {
    override var isHidden: Bool {
        get {
            super.isHidden
        }
        set {
            if newValue != self.isHidden {
                super.isHidden = newValue
            }
        }
    }

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private(set) var labelHeader: UILabel! {
        didSet {
            self.labelHeader.font = UIFont.kFontTitle1
            self.labelHeader.numberOfLines = 0
            self.labelHeader.textColor = DPAGColorProvider.shared[.labelText]
            self.labelHeader.textAlignment = .left
        }
    }

    @IBOutlet private var imageView: UIImageView! {
        didSet {
            self.imageView.image = DPAGImageProvider.shared[.kImageContactsMail]
        }
    }

    @IBOutlet private(set) var labelDescription: UILabel! {
        didSet {
            self.labelDescription.font = UIFont.kFontBody
            self.labelDescription.numberOfLines = 0
            self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private(set) var labelHint: UILabel! {
        didSet {
            self.labelHint.font = UIFont.kFontFootnote
            self.labelHint.numberOfLines = 0
            self.labelHint.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private(set) var viewBtnStartEMail: UIView! {
        didSet {
            self.viewBtnStartEMail.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
        }
    }

    @IBOutlet private(set) var btnStartEMail: UIButton! {
        didSet {
            self.btnStartEMail.configurePrimaryButton()
            self.btnStartEMail.setTitle(DPAGLocalizedString("settings.profile.button.authenticateMail"), for: .normal)
        }
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelHeader.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.labelHint.textColor = DPAGColorProvider.shared[.labelText]
                self.viewBtnStartEMail.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
