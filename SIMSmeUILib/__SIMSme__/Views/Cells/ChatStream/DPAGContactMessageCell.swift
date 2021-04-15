//
//  DPAGContactMessageCell.swift
//  SIMSme
//
//  Created by RBU on 06/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Contacts
import SIMSmeCore
import UIKit

class DPAGContactMessageLeftCell: DPAGContactMessageCell, DPAGChatStreamCellLeft {
    override var accessibilityLabel: String? {
        get {
            String(format: "%@ %@", self.labelInfo?.text ?? "", DPAGLocalizedString("chat.overview.preview.contactReceived"))
        }
        set {
            super.accessibilityLabel = newValue
        }
    }

    override func chatTextColor() -> UIColor {
        DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
    }
}

class DPAGContactMessageRightCell: DPAGContactMessageCell, DPAGChatStreamCellRight {
    override var accessibilityLabel: String? {
        get {
            String(format: "%@ %@", self.labelInfo?.text ?? "", DPAGLocalizedString("chat.overview.preview.contactSent"))
        }
        set {
            super.accessibilityLabel = newValue
        }
    }
}

public protocol DPAGContactMessageCellProtocol: DPAGMessageCellProtocol {}

class DPAGContactMessageCell: DPAGMessageCell, DPAGContactMessageCellProtocol {
    @IBOutlet private var labelContactName: UILabel? {
        didSet {
            self.labelContactName?.textColor = chatTextColor()
            self.labelContactName?.numberOfLines = 0
            self.labelContactName?.text = nil
        }
    }

    @IBOutlet private var viewContactImage: UIImageView? {
        didSet {
            if let viewContactImage = self.viewContactImage {
                viewContactImage.layer.cornerRadius = viewContactImage.frame.size.width / 2
                viewContactImage.layer.masksToBounds = true
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if let labelContactName = self.labelContactName {
            labelContactName.preferredMaxLayoutWidth = labelContactName.frame.width
        }
    }

    override func updateFonts() {
        super.updateFonts()

        self.labelContactName?.font = UIFont.kFontCalloutBold
    }

    override func configureCellWithMessage(_ decryptedMessage: DPAGDecryptedMessage, forHeightMeasurement: Bool) {
        super.configureCellWithMessage(decryptedMessage, forHeightMeasurement: forHeightMeasurement)

        if let vCard = decryptedMessage.content, let contact = DPAGApplicationFacade.contactsWorker.contact(fromVCard: vCard) {
            let labelContact = DPAGLocalizedString("chat.list.cell.labelLarge.newcontact")
            let contactDisplayName = CNContactFormatter().string(from: contact)

            var contactDisplayNameNonWrapping = contactDisplayName?.replacingOccurrences(of: " ", with: "\u{00a0}").replacingOccurrences(of: "-", with: "\u{2011}") ?? ""

            if contactDisplayNameNonWrapping.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if contact.nickname.isEmpty == false {
                    contactDisplayNameNonWrapping = contact.nickname
                } else if contact.note.hasPrefix("SIMSme-ID:") {
                    contactDisplayNameNonWrapping = contact.note
                } else if let note = vCard.components(separatedBy: .newlines).first(where: { $0.hasPrefix("NOTE:SIMSme-ID\\:") }) {
                    contactDisplayNameNonWrapping = String(note[note.index(note.startIndex, offsetBy: 5)...])
                } else if let phoneNumber = contact.phoneNumbers.first {
                    contactDisplayNameNonWrapping = phoneNumber.value.stringValue
                } else if let emailAddress = contact.emailAddresses.first {
                    contactDisplayNameNonWrapping = emailAddress.value as String
                }
            }

            self.labelContactName?.text = String(format: "%@ \"%@\"", labelContact, contactDisplayNameNonWrapping)

            if forHeightMeasurement == false {
                if contact.imageDataAvailable, let imageData = contact.imageData {
                    self.viewContactImage?.image = UIImage(data: imageData) ?? DPAGImageProvider.shared[.kImageChatCellPlaceholderContact]
                } else {
                    self.viewContactImage?.image = DPAGImageProvider.shared[.kImageChatCellPlaceholderContact]
                }
            }
        }

        if forHeightMeasurement == false {
            self.setLongPressGestureRecognizerForView(self.viewBubble)

            self.viewBubble?.accessibilityLabel = self.labelContactName?.text

            self.setCellContentSelectedAction { [weak self] in
                self?.didSelectMessageWithValidBlock({ [weak self] in
                    self?.didSelectValidContact()
                })
            }
        }
    }

    override func canPerformForward() -> Bool {
        false
    }
}
