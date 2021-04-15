//
//  DPAGChatCell.swift
//  SIMSme
//
//  Created by RBU on 24/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGChatCellProtocol: AnyObject {
    func configure(with contact: DPAGContact)
}

class DPAGChatCell: UITableViewCell, DPAGChatCellProtocol {
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

    @IBOutlet var labelDate: UILabel! {
        didSet {
            self.labelDate.adjustsFontForContentSizeCategory = true
            self.labelDate.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet var labelPreview: UILabel! {
        didSet {
            self.labelPreview.textColor = DPAGColorProvider.shared[.labelText]
            self.labelPreview.numberOfLines = 2
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code

        self.configContentViews()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Make sure the contentView does a layout pass here so that its subviews have their frames set, which we
        // need to use to set the preferredMaxLayoutWidth below.
        self.contentView.setNeedsLayout()
        self.contentView.layoutIfNeeded()

        // Set the preferredMaxLayoutWidth of the mutli-line bodyLabel based on the evaluated width of the label's frame,
        // as this will allow the text to wrap correctly, and as a result allow the label to take on the correct height.
        self.labelDate.preferredMaxLayoutWidth = self.labelDate.frame.width
        self.labelName.preferredMaxLayoutWidth = self.labelName.frame.width

        self.labelPreview.preferredMaxLayoutWidth = self.labelPreview.frame.width
    }

    func configContentViews() {
        self.labelName.adjustsFontForContentSizeCategory = true
        self.labelDate.adjustsFontForContentSizeCategory = true
        self.labelPreview.adjustsFontForContentSizeCategory = true

        self.labelPreview.textColor = DPAGColorProvider.shared[.labelText]

        self.selectionStyle = .none
        self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.contentView.backgroundColor = .clear

        self.updateFonts()
    }

    @objc
    func updateFonts() {
        self.labelDate.font = UIFont.kFontFootnote
        self.labelName.font = UIFont.kFontHeadline
        self.labelPreview.font = .kFontSubheadline
    }

    func configure(with contact: DPAGContact) {
        self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.labelName.textColor = DPAGColorProvider.shared[.labelText]
        self.labelDate.textColor = DPAGColorProvider.shared[.labelText]

        self.labelName.text = contact.displayName
        self.labelPreview.text = contact.statusMessageFallback
        self.viewProfileImage.image = contact.image(for: .chatList)

        if let lastMessageDate = contact.lastMessageDate {
            self.labelDate.text = DateFormatter.localizedString(from: lastMessageDate, dateStyle: .short, timeStyle: .short)
        } else {
            self.labelDate.text = ""
        }
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
                self.labelName.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDate.textColor = DPAGColorProvider.shared[.labelText]
                self.labelPreview.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    override var accessibilityLabel: String? {
        get {
            self.labelName.text
        }
        set {
            super.accessibilityLabel = newValue
        }
    }
}
