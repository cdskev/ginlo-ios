//
//  DPAGCitationCellView.swift
//  SIMSmeUILib
//
//  Created by RBU on 25.05.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Contacts
import SIMSmeCore
import UIKit

@IBDesignable
class DPAGCitationCellView: DPAGStackViewContentView, NibFileOwnerLoadable {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadNibContent()
        self.subviews.last?.backgroundColor = DPAGColorProvider.shared[.chatDetailsBackgroundCitation]
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @IBOutlet private var constraintBorderHeight: NSLayoutConstraint? {
        didSet {
            self.constraintBorderHeight?.constant = 0.5
        }
    }

    @IBOutlet private var viewBorder: UIView? {
        didSet {
            self.viewBorder?.backgroundColor = DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
        }
    }

    @IBOutlet private var labelCitationFrom: UILabel? {
        didSet {
            self.labelCitationFrom?.textColor = DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
            self.labelCitationFrom?.text = nil
            self.labelCitationFrom?.attributedText = nil
            self.labelCitationFrom?.font = UIFont.kFontCaption1
        }
    }

    @IBOutlet private var labelCitationInfo: UILabel? {
        didSet {
            self.labelCitationInfo?.textColor = DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
            self.labelCitationInfo?.text = nil
            self.labelCitationInfo?.attributedText = nil
            self.labelCitationInfo?.isHidden = true
            self.labelCitationInfo?.font = UIFont.kFontCaption1
        }
    }

    @IBOutlet private var labelCitationContent: UILabel? {
        didSet {
            self.labelCitationContent?.textColor = DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
            self.labelCitationContent?.text = nil
            self.labelCitationContent?.attributedText = nil
            self.labelCitationContent?.font = UIFont.kFontFootnote
        }
    }

    @IBOutlet private var imageViewCitation: UIImageView? {
        didSet {
            self.imageViewCitation?.image = nil
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        self.backgroundColor = DPAGColorProvider.shared[.chatDetailsBackground]
    }

    override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.subviews.last?.backgroundColor = DPAGColorProvider.shared[.chatDetailsBackgroundCitation]
        self.viewBorder?.backgroundColor = DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
        self.labelCitationFrom?.textColor = DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
        self.labelCitationInfo?.textColor = DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
        self.labelCitationContent?.textColor = DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
        self.backgroundColor = DPAGColorProvider.shared[.chatDetailsBackground]
        self.imageViewCitation?.image = DPAGImageProvider.shared[.kImageChatSoundRecord]?.imageWithTintColor(DPAGColorProvider.shared[.labelText])
        self.imageViewCitation?.tintColor = DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        self.loadNibContent()

        self.labelCitationFrom?.text = "from"
        self.labelCitationContent?.text = "Content"
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 0, height: 50)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let label = self.labelCitationFrom, label.bounds.height > 0 {
            label.preferredMaxLayoutWidth = label.frame.width
        }
        if let label = self.labelCitationInfo, label.bounds.height > 0 {
            label.preferredMaxLayoutWidth = 0 // label.frame.width
        }
        if let label = self.labelCitationContent, label.bounds.height > 0 {
            label.preferredMaxLayoutWidth = label.frame.width
        }
    }

    func updateFonts() {
        self.labelCitationFrom?.font = UIFont.kFontCaption1
        self.labelCitationInfo?.font = UIFont.kFontCaption1
        self.labelCitationContent?.font = UIFont.kFontFootnote
    }

    private func configureCitationImageVideo(citationContent: DPAGCitationContent) {
        self.labelCitationContent?.text = citationContent.contentType == .image ? DPAGLocalizedString("chats.destructionMessageCell.imageType") : DPAGLocalizedString("chats.destructionMessageCell.videoType")
        if let description = citationContent.contentDesc {
            if description.isEmpty == false {
                self.labelCitationContent?.text = description
            }
        }
        if let content = citationContent.content, let imageData = Data(base64Encoded: content, options: .ignoreUnknownCharacters), let previewImage = UIImage(data: imageData) {
            self.imageViewCitation?.isHidden = false
            if previewImage.size.width > DPAGConstantsGlobal.kChatMaxWidthObjects {
                self.imageViewCitation?.image = UIImage(data: imageData, scale: UIScreen.main.scale)
            } else {
                self.imageViewCitation?.image = previewImage
            }
            self.labelCitationContent?.numberOfLines = 2
        } else {
            self.imageViewCitation?.isHidden = true
            self.labelCitationContent?.numberOfLines = 3
        }
    }

    private func configureCitationVoiceRec(citationContent _: DPAGCitationContent) {
        self.labelCitationContent?.text = DPAGLocalizedString("chats.voiceMessage.title")
        self.imageViewCitation?.isHidden = false
        self.imageViewCitation?.image = DPAGImageProvider.shared[.kImageChatSoundRecord]?.imageWithTintColor(DPAGColorProvider.shared[.labelText])
        self.imageViewCitation?.tintColor = DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
        self.labelCitationContent?.numberOfLines = 2
    }

    private func configureCitationContact(citationContent: DPAGCitationContent) {
        let vCard = citationContent.content ?? "???"
        if let contact = DPAGApplicationFacade.contactsWorker.contact(fromVCard: vCard) {
            let labelContact = DPAGLocalizedString("chat.list.cell.labelLarge.newcontact")
            if let contactDisplayName = CNContactFormatter().attributedString(from: contact, defaultAttributes: nil)?.string {
                let contactDisplayNameFixed = contactDisplayName.replacingOccurrences(of: " ", with: "\u{00a0}").replacingOccurrences(of: "-", with: "\u{2011}")

                self.labelCitationContent?.text = String(format: "%@ \"%@\"", labelContact, contactDisplayNameFixed)
            } else {
                self.labelCitationContent?.text = labelContact
            }
            self.imageViewCitation?.isHidden = false
            if contact.imageDataAvailable, let imageData = contact.imageData {
                self.imageViewCitation?.image = UIImage(data: imageData) ?? DPAGImageProvider.shared[.kImageChatCellPlaceholderContact]
            } else {
                self.imageViewCitation?.image = DPAGImageProvider.shared[.kImageChatCellPlaceholderContact]
            }
            self.labelCitationContent?.numberOfLines = 2
        }
    }

    private func configureCitationLocation(citationContent: DPAGCitationContent) {
        self.labelCitationContent?.text = DPAGLocalizedString("chat.location-cell.info-text", comment: "text displayed on location cells within chat stream")
        if let content = citationContent.content, let data = content.data(using: .utf8) {
            do {
                if let locationDict = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any], let imageDataString = locationDict[DPAGStrings.JSON.Location.PREVIEW] as? String, let imageData = Data(base64Encoded: imageDataString, options: .ignoreUnknownCharacters), let previewImage = UIImage(data: imageData) {
                    self.imageViewCitation?.isHidden = false
                    if previewImage.size.width > DPAGConstantsGlobal.kChatMaxWidthObjects {
                        self.imageViewCitation?.image = UIImage(data: imageData, scale: UIScreen.main.scale)
                    } else {
                        self.imageViewCitation?.image = previewImage
                    }
                    self.labelCitationContent?.numberOfLines = 2
                }
            } catch {
                DPAGLog(error)
            }
        }
    }

    private func configureCitationFile(citationContent: DPAGCitationContent) {
        let fileName = citationContent.content ?? "???"
        self.labelCitationContent?.text = fileName
        var fileExt = ""
        if let rangeExtension = fileName.range(of: ".", options: .backwards) {
            fileExt = String(fileName[rangeExtension.upperBound...])
        }
        let imageType = DPAGImageProvider.shared.imageForFileExtension(fileExt)
        self.imageViewCitation?.isHidden = false
        self.imageViewCitation?.image = imageType
        self.labelCitationContent?.numberOfLines = 2
    }

    private func configureCitationText(citationContent: DPAGCitationContent) {
        self.labelCitationContent?.text = citationContent.content
        self.imageViewCitation?.isHidden = true
        self.labelCitationContent?.numberOfLines = 3
    }

    func configureCitation(citationContent: DPAGCitationContent?) {
        guard let citationContent = citationContent else {
            self.labelCitationFrom?.text = nil
            self.labelCitationInfo?.text = nil
            self.labelCitationContent?.text = nil
            if (self.imageViewCitation?.isHidden ?? false) == false {
                self.imageViewCitation?.isHidden = true
            }

            return
        }

        if citationContent.contentType == .textRSS {
            self.labelCitationFrom?.text = nil
        } else {
            if let contact = DPAGApplicationFacade.cache.contact(for: citationContent.fromGuid) {
                self.labelCitationFrom?.text = contact.displayName
                let nickLetters = DPAGUIImageHelper.lettersForPlaceholder(name: contact.displayName)
                let textColorNick = DPAGHelperEx.color(forPlaceholderLetters: nickLetters)
                self.labelCitationFrom?.textColor = textColorNick
            } else {
                self.labelCitationFrom?.text = citationContent.nickName
                let nickLetters = DPAGUIImageHelper.lettersForPlaceholder(name: citationContent.nickName ?? "UN")
                let textColorNick = DPAGHelperEx.color(forPlaceholderLetters: nickLetters)
                self.labelCitationFrom?.textColor = textColorNick
            }
        }
        switch citationContent.contentType {
            case .image, .video:
                self.configureCitationImageVideo(citationContent: citationContent)
            case .voiceRec:
                self.configureCitationVoiceRec(citationContent: citationContent)
            case .contact:
                self.configureCitationContact(citationContent: citationContent)
            case .location:
                self.configureCitationLocation(citationContent: citationContent)
            case .file:
                self.configureCitationFile(citationContent: citationContent)
            default:
                self.configureCitationText(citationContent: citationContent)
        }
    }
}
