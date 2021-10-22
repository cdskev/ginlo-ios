//
//  DPAGDefaultTableViewCell.swift
// ginlo
//
//  Created by RBU on 02/11/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGDefaultTableViewCellProtocol: AnyObject {
    var labelText: UILabel? { get }
    var labelDetailtext: UILabel? { get }
}

open class DPAGDefaultTableViewCell: UITableViewCell, DPAGDefaultTableViewCellProtocol {
    @IBOutlet public private(set) var labelText: UILabel?
    @IBOutlet public private(set) var labelDetailtext: UILabel?

    override open func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code

        self.configContentViews()
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        // Make sure the contentView does a layout pass here so that its subviews have their frames set, which we
        // need to use to set the preferredMaxLayoutWidth below.
        self.contentView.setNeedsLayout()
        self.contentView.layoutIfNeeded()

        // Set the preferredMaxLayoutWidth of the mutli-line bodyLabel based on the evaluated width of the label's frame,
        // as this will allow the text to wrap correctly, and as a result allow the label to take on the correct height.
        if let textLabel = self.labelText {
            textLabel.preferredMaxLayoutWidth = textLabel.frame.width
        }
        if let labelDetailtext = self.labelDetailtext {
            labelDetailtext.preferredMaxLayoutWidth = labelDetailtext.frame.width
        }
    }

    override open var textLabel: UILabel? {
        self.labelText
    }

    override open var detailTextLabel: UILabel? {
        self.labelDetailtext
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    open func configContentViews() {
        self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.contentView.backgroundColor = .clear

        self.setSelectionColor()

        self.textLabel?.text = ""
        self.detailTextLabel?.text = ""

        self.updateColors()

        self.textLabel?.adjustsFontForContentSizeCategory = true
        self.detailTextLabel?.adjustsFontForContentSizeCategory = true
        self.textLabel?.numberOfLines = 0

        self.updateFonts()
    }

    open func updateColors() {
        self.textLabel?.textColor = DPAGColorProvider.shared[.labelText]
        self.detailTextLabel?.textColor = DPAGColorProvider.shared[.labelText]
    }

    @objc
    open func updateFonts() {
        self.textLabel?.font = UIFont.kFontHeadline
        self.detailTextLabel?.font = UIFont.kFontHeadline
    }
    
    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
                updateColors()
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
