//
//  DPAGAutomaticRegistrationStepView.swift
//  SIMSmeUIViewsLib
//
//  Created by Yves Hetzer on 31.07.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public enum DPAGAutomaticRegistrationStepState {
    case waiting, processing, done, error
}

public protocol DPAGAutomaticRegistrationStepViewProtocol: AnyObject {
    func setDescription(_ desc: String)
    func setProgress(_ progress: String)
    func setState(_ newState: DPAGAutomaticRegistrationStepState)
}

class DPAGAutomaticRegistrationStepView: UIView, DPAGAutomaticRegistrationStepViewProtocol {
    @IBOutlet private(set) var lblDescription: UILabel! {
        didSet {
            self.lblDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.lblDescription.font = UIFont.kFontBody
        }
    }

    @IBOutlet private(set) var lblProgress: UILabel! {
        didSet {
            self.lblProgress.textColor = DPAGColorProvider.shared[.labelText]
            self.lblProgress.font = UIFont.kFontFootnote
        }
    }

    @IBOutlet private(set) var imgProcessUpcoming: UIImageView! {
        didSet {
            self.isHidden = false
            self.imgProcessUpcoming.image = DPAGImageProvider.shared[.kImageProcessUpcoming]
            self.imgProcessUpcoming.tintColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private(set) var actProcessing: UIActivityIndicatorView!

    @IBOutlet private(set) var imgProcessCheck: UIImageView! {
        didSet {
            self.isHidden = true
            self.imgProcessCheck.image = DPAGImageProvider.shared[.kImageChatCellOverlayCheck]
            self.imgProcessCheck.tintColor = DPAGColorProvider.shared[.imageCheck]
        }
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.lblProgress.textColor = DPAGColorProvider.shared[.labelText]
                self.imgProcessUpcoming.tintColor = DPAGColorProvider.shared[.labelText]
                self.imgProcessCheck.tintColor = DPAGColorProvider.shared[.imageCheck]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    func setDescription(_ desc: String) {
        self.performBlockOnMainThread {
            self.lblDescription.text = desc
            self.lblProgress.isHidden = true
            self.lblProgress.superview?.layoutIfNeeded()
        }
    }

    func setProgress(_ progress: String) {
        self.performBlockOnMainThread {
            self.lblProgress.text = progress
            self.lblProgress.isHidden = false
            self.lblProgress.superview?.layoutIfNeeded()
        }
    }

    func setState(_ newState: DPAGAutomaticRegistrationStepState) {
        switch newState {
            case .waiting:
                self.imgProcessUpcoming.isHidden = false
                self.imgProcessCheck.isHidden = true
                self.actProcessing.stopAnimating()
                self.lblDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.lblProgress.isHidden = true
            case .processing:
                self.imgProcessUpcoming.isHidden = true
                self.imgProcessCheck.isHidden = true
                self.actProcessing.startAnimating()
                self.lblDescription.textColor = DPAGColorProvider.shared[.labelText]
            case .done:
                self.imgProcessUpcoming.isHidden = true
                self.imgProcessCheck.isHidden = false
                self.actProcessing.stopAnimating()
                self.lblDescription.textColor = DPAGColorProvider.shared[.imageCheck]
                self.lblProgress.isHidden = true
            case .error:
                self.imgProcessUpcoming.isHidden = true
                self.imgProcessCheck.isHidden = true
                self.actProcessing.stopAnimating()
                self.lblDescription.textColor = DPAGColorProvider.shared[.labelDestructive]
                self.lblProgress.isHidden = true
        }
    }
}
