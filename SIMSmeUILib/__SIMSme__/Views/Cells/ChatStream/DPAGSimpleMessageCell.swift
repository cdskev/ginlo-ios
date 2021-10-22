//
//  DPAGSimpleMessageCell.swift
// ginlo
//
//  Created by RBU on 06/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGSimpleMessageServiceLeftCell: DPAGSimpleMessageCell, DPAGChatStreamCellLeft {
    override func layoutSubviews() {
        super.layoutSubviews()

        if let labelText = self.labelText {
            labelText.preferredMaxLayoutWidth = self.contentView.frame.width - 128
        }
    }

    override func chatTextColor() -> UIColor {
        DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
    }
}

class DPAGSimpleMessageChannelLeftCell: DPAGSimpleMessageCell, DPAGChatStreamCellLeft {
    override func layoutSubviews() {
        super.layoutSubviews()

        if let labelText = self.labelText {
            labelText.preferredMaxLayoutWidth = self.contentView.frame.width - 128
        }
    }

    override func chatTextColor() -> UIColor {
        DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
    }
}

class DPAGSimpleMessageLeftCell: DPAGSimpleMessageCell, DPAGChatStreamCellLeft {
    override func layoutSubviews() {
        super.layoutSubviews()

        if let labelText = self.labelText {
            labelText.preferredMaxLayoutWidth = self.contentView.frame.width - 128
        }
    }

    override func chatTextColor() -> UIColor {
        DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
    }
}

class DPAGSimpleMessageRightCell: DPAGSimpleMessageCell, DPAGChatStreamCellRight {
    override func layoutSubviews() {
        super.layoutSubviews()

        if let labelText = self.labelText {
            labelText.preferredMaxLayoutWidth = self.contentView.frame.width - 128
        }
    }
}

public protocol DPAGSimpleMessageCellProtocol: DPAGMessageCellProtocol, DPAGChatLabelDelegate {
    var labelText: DPAGChatLabel? { get }

    func openLinkInSelectedCell()
    func copyLinkInSelectedCell()

    func setLinkSelectedAction(_ block: @escaping DPAGChatMessageLinkSelectedBlock)
}

class DPAGSimpleMessageCell: DPAGMessageCell, DPAGSimpleMessageCellProtocol {
    @IBOutlet var labelText: DPAGChatLabel? {
        didSet {
            self.labelText?.delegate = self

            self.labelText?.backgroundColor = .clear
            self.labelText?.numberOfLines = 0
            self.labelText?.lineBreakMode = .byWordWrapping
            self.labelText?.translatesAutoresizingMaskIntoConstraints = false
            self.labelText?.textAlignment = .natural
            self.labelText?.textColor = chatTextColor()
        }
    }

    var linkSelectedBlock: DPAGChatMessageLinkSelectedBlock?

    override func updateFonts() {
        super.updateFonts()

        self.labelText?.font = UIFont.kFontCallout
    }

    override func configureCellWithMessage(_ decryptedMessage: DPAGDecryptedMessage, forHeightMeasurement: Bool) {
        super.configureCellWithMessage(decryptedMessage, forHeightMeasurement: forHeightMeasurement)
        let attributedText = NSMutableAttributedString(string: decryptedMessage.attributedText ?? DPAGLocalizedString("migration.info.init"), attributes: [.font: UIFont.kFontCallout, .kern: -0.2])
        self.labelText?.resetLinks()
        if let location = decryptedMessage.rangeLineBreak?.location, location != NSNotFound {
            attributedText.setAttributes([.font: UIFont.kFontCalloutBold], range: NSRange(location: 0, length: location))
        }
        if decryptedMessage is DPAGDecryptedMessageChannel {
            self.labelText?.attributedText = attributedText
            guard forHeightMeasurement == false else { return }
            self.setLongPressGestureRecognizerForView(self.viewBubble)
            if let rangesWithLink = decryptedMessage.rangesWithLink {
                for result in rangesWithLink {
                    attributedText.addAttributes([.foregroundColor: chatTextColor(),
                                                  .underlineStyle: NSUnderlineStyle.single.rawValue], range: result.range)
                }
                self.labelText?.attributedText = attributedText
                self.labelText?.applyLinks(rangesWithLink)
                self.setLinkSelectedAction({ selectedURL in
                    if let url = selectedURL {
                        AppConfig.openURL(url as URL)
                    }
                })
            }

            self.setCellContentSelectedAction { [weak self] in
                self?.didSelectMessageWithValidBlock { [weak self] in
                    guard let strongSelf = self else { return }
                    self?.streamDelegate?.didSelectValidText(strongSelf.decryptedMessage)
                }
            }
        } else {
            self.labelText?.attributedText = attributedText
            guard forHeightMeasurement == false else { return }
            self.setLongPressGestureRecognizerForView(self.viewBubble)
            if let rangesWithLink = decryptedMessage.rangesWithLink {
                for result in rangesWithLink {
                    attributedText.addAttributes([.foregroundColor: chatTextColor(),
                                                  .underlineStyle: NSUnderlineStyle.single.rawValue], range: result.range)
                }
                self.labelText?.attributedText = attributedText
                self.labelText?.applyLinks(rangesWithLink)
            }
            if let labelInfoText = self.labelInfo?.text, let labelTextText = self.labelText?.text {
                if let labelSenderText = self.labelSender?.text {
                    self.accessibilityLabel = "\(labelSenderText) \(labelInfoText) \(labelTextText)"
                } else {
                    self.accessibilityLabel = "\(labelInfoText) \(labelTextText)"
                }
            } else {
                self.accessibilityLabel = self.labelText?.text
            }
            self.setCellContentSelectedAction { [weak self] in
                self?.didSelectMessageWithValidBlock { [weak self] in
                    guard let strongSelf = self else { return }
                    self?.streamDelegate?.didSelectValidText(strongSelf.decryptedMessage)
                }
            }
        }
    }

    func setLinkSelectedAction(_ block: @escaping DPAGChatMessageLinkSelectedBlock) {
        self.linkSelectedBlock = block
    }

    func didSelectLinkWithURL(_ url: URL) {
        if self.linkSelectedBlock != nil {
            self.linkSelectedBlock?(url)
            return
        }
        self.askToForwardURL(url)
    }

    func askToForwardURL(_ url: URL) {
        self.streamDelegate?.askToForwardURL(url, message: self.decryptedMessage)
    }

    func contentOfCell() -> String? {
        self.decryptedMessage.content
    }

    override func menuItems() -> [UIMenuItem] {
        var retVal = super.menuItems()

        if (self.labelText?.links.count ?? 0) > 0 {
            retVal.append(UIMenuItem(title: DPAGLocalizedString("chat.message.action.openLink"), action: #selector(openLinkInSelectedCell)))
            retVal.append(UIMenuItem(title: DPAGLocalizedString("chat.message.action.copyLink"), action: #selector(copyLinkInSelectedCell)))
        }

        return retVal
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if sender is UIMenuController {
            if action == #selector(openLinkInSelectedCell) || action == #selector(copyLinkInSelectedCell) {
                return true
            }
        }
        return super.canPerformAction(action, withSender: sender)
    }

    override func copySelectedCell() {
        if let clipboardString = self.contentOfCell() {
            UIPasteboard.general.string = clipboardString
        }
    }

    override func canPerformForward() -> Bool {
        self.decryptedMessage.contentType != .avCallInvitation
    }

    override func canPerformCopy() -> Bool {
        self.decryptedMessage.contentType != .avCallInvitation
    }

    override func forwardSelectedCell() {
        if let forwardingText = self.contentOfCell(), forwardingText.isEmpty == false {
            self.streamDelegate?.forwardText(forwardingText, message: self.decryptedMessage)
        }
    }

    override func rejoinAVCall() {
        if self.decryptedMessage.contentType == .avCallInvitation {
            self.streamDelegate?.requestRejoinAVCall(self.decryptedMessage)
        }
    }

    @objc
    func openLinkInSelectedCell() {
        guard let labelText = self.labelText else {
            return
        }

        self.streamDelegate?.openLink(for: labelText)
    }

    @objc
    func copyLinkInSelectedCell() {
        guard let labelText = self.labelText else {
            return
        }

        self.streamDelegate?.copyLink(for: labelText)
    }
    
    override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.labelText?.textColor = chatTextColor()
    }
}
