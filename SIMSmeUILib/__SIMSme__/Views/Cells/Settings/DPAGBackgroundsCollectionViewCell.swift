//
//  DPAGBackgroundsCollectionViewCell.swift
// ginlo
//
//  Created by RBU on 26/10/15.
//  Copyright © 2019 Deutsche Post AG. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGBackgroundsCollectionViewCellProtocol: AnyObject {
    func configure(with image: UIImage?, animate: Bool)
}

public class DPAGBackgroundsCollectionViewCell: UICollectionViewCell, DPAGBackgroundsCollectionViewCellProtocol {
    @IBOutlet private var imageViewBackground: UIImageView!
    @IBOutlet private var imageViewSelection: UIImageView! {
        didSet {
            self.imageViewSelection.isHidden = true
            self.imageViewSelection.configureCheck()
        }
    }

    @IBOutlet private var activityIndicator: UIActivityIndicatorView! {
        didSet {
            self.activityIndicator.color = DPAGColorProvider.shared[.labelText]
            self.activityIndicator.tintColor = DPAGColorProvider.shared[.labelText]
            self.activityIndicator.hidesWhenStopped = true
        }
    }
    
    override public var isSelected: Bool {
        didSet {
            self.imageViewSelection?.isHidden = (self.isSelected == false)
        }
    }

    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if self.traitCollection.horizontalSizeClass == .compact {
            if self.traitCollection.verticalSizeClass == .regular {
                self.imageViewBackground?.alpha = 1
            } else {
                self.imageViewBackground?.alpha = 0
            }
        } else {
            self.imageViewBackground?.alpha = 1
        }
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.activityIndicator.color = DPAGColorProvider.shared[.labelText]
                self.activityIndicator.tintColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    public func configure(with image: UIImage?, animate: Bool) {
        self.imageViewBackground?.image = image

        if animate {
            self.activityIndicator?.startAnimating()
        } else {
            self.activityIndicator?.stopAnimating()
        }
    }
}
