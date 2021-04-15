//
//  DPAGChatOverviewConfirmedBaseCell.swift
//  SIMSme
//
//  Created by RBU on 25/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGChatOverviewConfirmedBaseCellProtocol: DPAGChatOverviewBaseCellProtocol {
    func setLabelNameHighlight(_ text: String?)
}

class DPAGChatOverviewConfirmedBaseCell: DPAGChatOverviewBaseCell, DPAGChatOverviewConfirmedBaseCellProtocol {
    @IBOutlet var labelUnreadMessages: DPAGLabelBadge! {
        didSet {
            self.labelUnreadMessages.backgroundColor = DPAGColorProvider.shared[.conversationOverviewUnreadMessages]
            self.labelUnreadMessages.textColor = DPAGColorProvider.shared[.conversationOverviewUnreadMessagesTint]
        }
    }

    @IBOutlet var labelPreview: UILabel! {
        didSet {
            self.labelPreview.textColor = self.labelPreviewTextColor
            self.labelPreview.numberOfLines = 2
        }
    }

    var labelPreviewTextColor: UIColor {
        DPAGColorProvider.shared[.labelText]
    }

    var lastMessageSendingState: DPAGMessageState = .undefined

    private var colorLabelUnreadMessagesBackground: UIColor?

    var labelNameHighlightText: String?

    override func layoutSubviews() {
        super.layoutSubviews()
        self.labelPreview.preferredMaxLayoutWidth = self.labelPreview.frame.width
        self.labelUnreadMessages.preferredMaxLayoutWidth = self.labelUnreadMessages.frame.width
    }

    override var isSelected: Bool {
        willSet {
            self.colorLabelUnreadMessagesBackground = self.labelUnreadMessages.backgroundColor
        }
        didSet {
            if self.isSelected {
                self.labelUnreadMessages.backgroundColor = self.colorLabelUnreadMessagesBackground
            }
        }
    }

    override var isHighlighted: Bool {
        willSet {
            self.colorLabelUnreadMessagesBackground = self.labelUnreadMessages.backgroundColor
        }
        didSet {
            if self.isHighlighted {
                self.labelUnreadMessages.backgroundColor = self.colorLabelUnreadMessagesBackground
            }
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        if selected {
            let colorLabelUnreadMessagesBackground = self.labelUnreadMessages.backgroundColor
            super.setSelected(selected, animated: animated)
            self.labelUnreadMessages.backgroundColor = colorLabelUnreadMessagesBackground
        } else {
            super.setSelected(selected, animated: animated)
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        if highlighted {
            let colorLabelUnreadMessagesBackground = self.labelUnreadMessages.backgroundColor
            super.setHighlighted(highlighted, animated: animated)
            self.labelUnreadMessages.backgroundColor = colorLabelUnreadMessagesBackground
        } else {
            super.setHighlighted(highlighted, animated: animated)
        }
    }

    override func configContentViews() {
        super.configContentViews()
        self.labelUnreadMessages.adjustsFontForContentSizeCategory = true
        self.labelPreview.adjustsFontForContentSizeCategory = true
        self.contentView.backgroundColor = .clear // DPAGColorProvider.shared[.defaultViewBackground]
    }

    override func updateFonts() {
        super.updateFonts()
        self.labelPreview.font = .kFontSubheadline
    }

    func convertPreviewText(_ decryptedStream: DPAGDecryptedStream, textColor: UIColor) {
        let previewText = NSMutableAttributedString()
        var prependSpacer = false
        for previewTextItem in decryptedStream.previewText {
            let textColor: UIColor = previewTextItem.tintColor ?? textColor
            prependSpacer = (prependSpacer || previewTextItem.spacerPre)
            if previewTextItem.attributedString.length > 0, previewTextItem.attributedString.containsAttachments(in: NSRange(location: 0, length: 1)) {
                let location = previewText.length
                previewText.append(NSAttributedString(string: " "))
                previewText.append(previewTextItem.attributedString)
                previewText.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: location, length: previewTextItem.attributedString.length + 1))
                prependSpacer = previewTextItem.spacerPost
            } else {
                if prependSpacer {
                    previewText.append(NSAttributedString(string: " "))
                }
                let location = previewText.length
                previewText.append(previewTextItem.attributedString)
                previewText.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: location, length: previewTextItem.attributedString.length))
                prependSpacer = previewTextItem.spacerPost
            }
        }
        if prependSpacer {
            previewText.append(NSAttributedString(string: " "))
            prependSpacer = false
        }
        self.labelPreview.attributedText = previewText
    }

    func setUnreadMessagesCount(_ count: Int) {
        if count > 0 {
            self.labelUnreadMessages.text = "\(count)"
            if let superview = self.labelUnreadMessages.superview, superview.subviews.count == 1, superview.isHidden {
                superview.isHidden = false
            }
        } else {
            self.labelUnreadMessages.text = ""
            if let superview = self.labelUnreadMessages.superview, superview.subviews.count == 1, superview.isHidden == false {
                superview.isHidden = true
            }
        }
    }

    func setLabelNameHighlight(_ text: String?) {
        self.labelNameHighlightText = text
    }

    override func configureCellWithStream(_ decryptedStream: DPAGDecryptedStream) {
        super.configureCellWithStream(decryptedStream)
        self.contentView.backgroundColor = .clear // DPAGColorProvider.shared[.defaultViewBackground]
        self.setUnreadMessagesCount(decryptedStream.newMessagesCount)
        if self.labelPreview.attributedText == nil {
            self.labelPreview.textColor = DPAGColorProvider.shared[.labelText]
        }
        self.labelUnreadMessages.backgroundColor = DPAGColorProvider.shared[.conversationOverviewUnreadMessages]
        self.labelUnreadMessages.textColor = DPAGColorProvider.shared[.conversationOverviewUnreadMessagesTint]
        var text = ""
        if AppConfig.isShareExtension {
            let cache = DPAGApplicationFacadeShareExt.cache
            if let privateStream = decryptedStream as? DPAGDecryptedStreamPrivate, let contactGuid = privateStream.contactGuid, let contact = cache.contact(for: contactGuid) {
                text = contact.displayName
            } else {
                text = decryptedStream.name ?? ""
            }
        } else {
            let cache = DPAGApplicationFacade.cache
            if let privateStream = decryptedStream as? DPAGDecryptedStreamPrivate, let contactGuid = privateStream.contactGuid, let contact = cache.contact(for: contactGuid) {
                text = contact.displayName
            } else {
                text = decryptedStream.name ?? ""
            }
        }
        if let labelNameHighlightText = self.labelNameHighlightText {
            let highLight = (text as NSString).range(of: labelNameHighlightText, options: .caseInsensitive)
            if highLight.length > 0 {
                let mas = NSMutableAttributedString(string: text)
                mas.addAttributes([.foregroundColor: DPAGColorProvider.shared[.conversationOverviewHighlight]], range: highLight)
                self.labelName.attributedText = mas
            } else {
                self.labelName.text = text
            }
        } else {
            self.labelName.text = text
        }
    }
    
    override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.labelUnreadMessages.backgroundColor = DPAGColorProvider.shared[.conversationOverviewUnreadMessages]
        self.labelUnreadMessages.textColor = DPAGColorProvider.shared[.conversationOverviewUnreadMessagesTint]
        if self.labelPreview.attributedText == nil {
            self.labelPreview.textColor = DPAGColorProvider.shared[.labelText]
        }
        self.labelUnreadMessages.backgroundColor = DPAGColorProvider.shared[.conversationOverviewUnreadMessages]
        self.labelUnreadMessages.textColor = DPAGColorProvider.shared[.conversationOverviewUnreadMessagesTint]

    }
}
