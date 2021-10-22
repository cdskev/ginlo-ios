//
//  DPAGPersonCell.swift
// ginlo
//
//  Created by RBU on 16.12.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGPersonCellProtocol: AnyObject {
    func update(person: DPAGPerson?)
    func update(searchBarText: String?)
}

class DPAGPersonCell: UITableViewCell, DPAGPersonCellProtocol {
    @IBOutlet private var imageViewProfile: UIImageView! {
        didSet {
            self.imageViewProfile.layer.cornerRadius = self.imageViewProfile.frame.size.height / 2
            self.imageViewProfile.layer.masksToBounds = true
            // self.imageViewProfile.layer.borderWidth = 2
        }
    }

    @IBOutlet private var labelText: UILabel! {
        didSet {
            self.labelText.backgroundColor = UIColor.clear
            self.labelText.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelTextDetail: UILabel! {
        didSet {
            self.labelTextDetail.backgroundColor = UIColor.clear
            self.labelTextDetail.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code

        self.configCell()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.contentView.setNeedsLayout()
        self.contentView.layoutIfNeeded()

        self.labelText.preferredMaxLayoutWidth = self.labelText.frame.width
        self.labelTextDetail.preferredMaxLayoutWidth = self.labelTextDetail.frame.width
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configCell() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateFonts), name: UIContentSizeCategory.didChangeNotification, object: nil)

        self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.contentView.backgroundColor = UIColor.clear
        self.setSelectionColor()

        self.updateFonts()
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                self.labelText.textColor = DPAGColorProvider.shared[.labelText]
                self.labelTextDetail.textColor = DPAGColorProvider.shared[.labelText]
                self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    func update(person: DPAGPerson?) {
        guard let person = person else {
            self.labelText?.text = ""
            self.labelTextDetail?.text = ""
            self.imageViewProfile?.image = nil
            self.accessoryView = nil

            return
        }

        self.labelText?.text = person.displayName

        self.imageViewProfile?.image = person.image
        self.labelTextDetail.text = person.phoneNumbers.first?.value ?? person.eMailAddresses.first?.value
    }

    func update(searchBarText: String?) {
        self.labelText.updateWithSearchBarText(searchBarText)
    }

    @objc
    private func updateFonts() {
        self.labelText.font = UIFont.kFontHeadline
        self.labelTextDetail.font = UIFont.kFontFootnote
    }
}
