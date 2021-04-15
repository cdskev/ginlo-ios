//
//  DPAGGroupChatCell.swift
//  SIMSme
//
//  Created by RBU on 24/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGGroupCellProtocol: AnyObject {
    func configure(with group: DPAGGroup)
}

class DPAGGroupCell: UITableViewCell, DPAGGroupCellProtocol {
    @IBOutlet var viewProfileImage: UIImageView! {
        didSet {
            // self.viewProfileImage.layer.borderWidth = 2
            self.viewProfileImage.layer.cornerRadius = self.viewProfileImage.frame.size.height / 2.0
            self.viewProfileImage.layer.masksToBounds = true
            self.viewProfileImage.backgroundColor = UIColor.clear
        }
    }

    @IBOutlet var labelName: UILabel! {
        didSet {
            self.labelName.adjustsFontForContentSizeCategory = true
            self.labelName.textColor = DPAGColorProvider.shared[.labelText]
            self.labelName.numberOfLines = 1
        }
    }

    @IBOutlet var labelPreview: UILabel! {
        didSet {
            self.labelPreview.textColor = DPAGColorProvider.shared[.labelText]
            self.labelPreview.numberOfLines = 2
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code

        self.configContentViews()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Make sure the contentView does a layout pass here so that its subviews have their frames set, which we
        // need to use to set the preferredMaxLayoutWidth below.
        self.contentView.setNeedsLayout()
        self.contentView.layoutIfNeeded()

        self.labelName.preferredMaxLayoutWidth = self.labelName.frame.width
        self.labelPreview.preferredMaxLayoutWidth = self.labelPreview.frame.width
    }

    override var accessibilityLabel: String? {
        get {
            self.labelName.text
        }
        set {
            super.accessibilityLabel = newValue
        }
    }

    func configContentViews() {
        self.labelPreview.adjustsFontForContentSizeCategory = true
        self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.setSelectionColor()
        self.separatorInset = .zero
        self.layoutMargins = .zero
        self.selectionStyle = .none
        self.updateFonts()
        self.selectionStyle = .none
        self.contentView.backgroundColor = .clear
    }

    @objc
    func updateFonts() {
        self.labelName.font = UIFont.kFontHeadline
        self.labelPreview.font = .kFontSubheadline
    }

    func configure(with group: DPAGGroup) {
        self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.labelName.textColor = DPAGColorProvider.shared[.labelText]
        if let encodedImage = group.imageData, let imageData = Data(base64Encoded: encodedImage, options: .ignoreUnknownCharacters) {
            self.viewProfileImage.image = UIImage(data: imageData)
        } else {
            self.viewProfileImage.image = DPAGUIImageHelper.image(forGroupGuid: group.guid, imageType: .chatList)
        }
        self.labelPreview.textColor = DPAGColorProvider.shared[.labelText]
        self.labelName.text = group.name
        self.labelPreview.text = group.memberNames
    }
    
    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                self.labelPreview.textColor = DPAGColorProvider.shared[.labelText]
                self.labelName.textColor = DPAGColorProvider.shared[.labelText]
                self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
