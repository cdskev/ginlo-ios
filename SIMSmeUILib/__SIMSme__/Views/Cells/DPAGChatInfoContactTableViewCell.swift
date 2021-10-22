//
//  DPAGChatInfoContactTableViewCell.swift
// ginlo
//
//  Created by RBU on 12/09/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGChatInfoContactTableViewCellProtocol: AnyObject {
    func configureCell(withReceiver receiver: DPAGMessageRecipient, date: Date?)
}

class DPAGChatInfoContactTableViewCell: UITableViewCell, DPAGChatInfoContactTableViewCellProtocol {
    @IBOutlet private var imageViewProfile: UIImageView! {
        didSet {
            self.imageViewProfile.layer.cornerRadius = self.imageViewProfile.frame.size.height / 2
            self.imageViewProfile.layer.masksToBounds = true
        }
    }

    @IBOutlet private var labelName: UILabel! {
        didSet {
            self.labelName.backgroundColor = UIColor.clear
            self.labelName.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelDate: UILabel! {
        didSet {
            self.labelDate.backgroundColor = .clear
            self.labelDate.textColor = DPAGColorProvider.shared[.labelText]
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

        self.labelName.preferredMaxLayoutWidth = self.labelName.frame.width
        self.labelDate.preferredMaxLayoutWidth = self.labelDate.frame.width
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configCell() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateFonts), name: UIContentSizeCategory.didChangeNotification, object: nil)

        self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.contentView.backgroundColor = UIColor.clear

        self.updateFonts()
    }

    @objc
    private func updateFonts() {
        self.labelName.font = UIFont.kFontHeadline
        self.labelDate.font = UIFont.kFontFootnote
    }

    func configureCell(withReceiver receiver: DPAGMessageRecipient, date: Date?) {
        self.labelName.attributedText = receiver.contact?.attributedDisplayName

        if receiver.contact?.attributedDisplayName == nil {
            self.labelName.text = receiver.contact?.displayName
        }

        self.imageViewProfile.image = receiver.contact?.image(for: .chat)

        if let date = date {
            let dateInfo = NSMutableAttributedString()

            dateInfo.append(NSAttributedString(string: DPAGFormatter.messageSectionDateRelativ.string(from: date), attributes: [.foregroundColor: DPAGColorProvider.shared[.labelText]]))
            dateInfo.append(NSAttributedString(string: " "))

            dateInfo.append(NSAttributedString(string: date.timeLabel, attributes: [.foregroundColor: DPAGColorProvider.shared[.labelText]]))

            self.labelDate.attributedText = dateInfo
        }

        self.selectionStyle = .none
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelName.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDate.textColor = DPAGColorProvider.shared[.labelText]
                self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
