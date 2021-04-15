//
//  DPAGChatStreamCitationView.swift
//  SIMSmeUILib
//
//  Created by RBU on 25.05.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Contacts
import SIMSmeCore
import UIKit

class DPAGChatStreamCitationView: DPAGStackViewContentView, DPAGChatStreamCitationViewProtocol {
    weak var delegate: DPAGChatStreamCitationViewDelegate?

    @IBOutlet private var labelCitationFrom: UILabel? {
        didSet {
            self.labelCitationFrom?.textColor = DPAGColorProvider.shared[.labelText]
            self.labelCitationFrom?.text = nil
            self.labelCitationFrom?.font = UIFont.kFontCellNick
        }
    }

    @IBOutlet private var labelCitationInfo: UILabel? {
        didSet {
            self.labelCitationInfo?.textColor = DPAGColorProvider.shared[.labelText]
            self.labelCitationInfo?.text = nil
            self.labelCitationInfo?.font = UIFont.kFontCellNick
            self.labelCitationInfo?.isHidden = true
        }
    }

    @IBOutlet private var labelCitationContent: UILabel? {
        didSet {
            self.labelCitationContent?.textColor = DPAGColorProvider.shared[.labelText]
            self.labelCitationContent?.text = nil
            self.labelCitationContent?.font = UIFont.kFontFootnote
        }
    }

    @IBOutlet private var imageViewCitation: UIImageView? {
        didSet {
            self.imageViewCitation?.image = nil
        }
    }

    @IBOutlet private var btnCitationCancel: UIButton? {
        didSet {
            self.btnCitationCancel?.setImage(DPAGImageProvider.shared[.kImageClose], for: .normal)
            self.btnCitationCancel?.tintColor = DPAGColorProvider.shared[.buttonTintNoBackground]
            self.btnCitationCancel?.addTargetClosure(closure: { [weak self] _ in
                self?.delegate?.handleCitationCancel()
            })
        }
    }

    open override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.labelCitationFrom?.textColor = DPAGColorProvider.shared[.labelText]
        self.labelCitationInfo?.textColor = DPAGColorProvider.shared[.labelText]
        self.labelCitationContent?.textColor = DPAGColorProvider.shared[.labelText]
        self.btnCitationCancel?.tintColor = DPAGColorProvider.shared[.buttonTintNoBackground]
        self.backgroundColor = DPAGColorProvider.shared[.chatDetailsBackgroundCitation]
        self.imageViewCitation?.tintColor = DPAGColorProvider.shared[.labelText]
        self.imageViewCitation?.image = DPAGImageProvider.shared[.kImageChatSoundRecord]?.imageWithTintColor(DPAGColorProvider.shared[.labelText])
    }

    private var layerWidth: CGFloat = 0
    private var layerHeight: CGFloat = 0

    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundColor = DPAGColorProvider.shared[.chatDetailsBackgroundCitation]
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if self.layerWidth != self.bounds.width || self.layerHeight != self.bounds.height {
            let maskLayer = CAShapeLayer()
            maskLayer.frame = self.bounds
            maskLayer.path = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 8, height: 8)).cgPath
            self.layer.mask = maskLayer
            self.layerWidth = self.bounds.width
            self.layerHeight = self.bounds.height
        }
    }

    func configureCitation(for decryptedMessage: DPAGDecryptedMessage) {
        DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation = decryptedMessage.messageGuid
        if decryptedMessage.messageType == .private, let decryptedMessagePrivate = decryptedMessage as? DPAGDecryptedMessagePrivate {
            self.labelCitationFrom?.text = decryptedMessagePrivate.contactName
            self.labelCitationFrom?.textColor = decryptedMessagePrivate.textColorNick ?? DPAGColorProvider.shared[.labelText]
        } else if decryptedMessage.messageType == .group, let decryptedMessageGroup = decryptedMessage as? DPAGDecryptedMessageGroup {
            self.labelCitationFrom?.text = decryptedMessageGroup.contactName
            self.labelCitationFrom?.textColor = decryptedMessageGroup.textColorNick ?? DPAGColorProvider.shared[.labelText]
        }
        self.labelCitationInfo?.text = DPAGFormatter.dateTimeCitationFormatter.string(from: decryptedMessage.messageDate ?? Date())
        switch decryptedMessage.contentType {
            case .image, .video:
                self.configureCitationImageVideo(for: decryptedMessage)
            case .voiceRec:
                self.configureCitationVoiceRec(for: decryptedMessage)
            case .contact:
                self.configureCitationContact(for: decryptedMessage)
            case .location:
                self.configureCitationLocation(for: decryptedMessage)
            case .file:
                self.configureCitationFile(for: decryptedMessage)
            case .plain, .oooStatusMessage, .textRSS, .avCallInvitation, .controlMsgNG:
                self.configureCitationText(for: decryptedMessage)
        }
    }

    private func configureCitationText(for decryptedMessage: DPAGDecryptedMessage) {
        self.labelCitationContent?.text = decryptedMessage.content
        self.configureCitationImageConstraints(false)
        self.labelCitationContent?.numberOfLines = 3
    }

    private func configureCitationImageVideo(for decryptedMessage: DPAGDecryptedMessage) {
        self.labelCitationContent?.text = decryptedMessage.contentDesc ?? (decryptedMessage.contentType == .image ? DPAGLocalizedString("chats.destructionMessageCell.imageType") : DPAGLocalizedString("chats.destructionMessageCell.videoType"))
        self.labelCitationContent?.numberOfLines = 2
        if let description = decryptedMessage.contentDesc {
            if description.isEmpty == false {
                self.labelCitationContent?.text = description
            }
        }
        if let content = decryptedMessage.content, let imageData = Data(base64Encoded: content, options: .ignoreUnknownCharacters), let previewImage = UIImage(data: imageData) {
            self.configureCitationImageConstraints(true)
            if previewImage.size.width > DPAGConstantsGlobal.kChatMaxWidthObjects {
                self.imageViewCitation?.image = UIImage(data: imageData, scale: UIScreen.main.scale)
            } else {
                self.imageViewCitation?.image = previewImage
            }
            self.imageViewCitation?.tintColor = nil
        }
    }

    private func configureCitationVoiceRec(for _: DPAGDecryptedMessage) {
        self.labelCitationContent?.text = DPAGLocalizedString("chats.voiceMessage.title")
        self.configureCitationImageConstraints(true)
        self.imageViewCitation?.image = DPAGImageProvider.shared[.kImageChatSoundRecord]?.imageWithTintColor(DPAGColorProvider.shared[.labelText])
        self.imageViewCitation?.tintColor = DPAGColorProvider.shared[.labelText]
        self.labelCitationContent?.numberOfLines = 2
    }

    private func configureCitationContact(for decryptedMessage: DPAGDecryptedMessage) {
        guard let vCard = decryptedMessage.content else { return }
        if let contact = DPAGApplicationFacade.contactsWorker.contact(fromVCard: vCard) {
            let labelContact = DPAGLocalizedString("chat.list.cell.labelLarge.newcontact")
            let contactDisplayName = CNContactFormatter().attributedString(from: contact, defaultAttributes: nil)?.string
            self.labelCitationContent?.text = String(format: "%@ \"%@\"", labelContact, contactDisplayName?.replacingOccurrences(of: " ", with: "\u{00a0}").replacingOccurrences(of: "-", with: "\u{2011}") ?? "")
            if contact.imageDataAvailable, let imageData = contact.imageData {
                self.imageViewCitation?.image = UIImage(data: imageData) ?? DPAGImageProvider.shared[.kImageChatCellPlaceholderContact]
            } else {
                self.imageViewCitation?.image = DPAGImageProvider.shared[.kImageChatCellPlaceholderContact]
            }
            self.imageViewCitation?.tintColor = nil
        }
        self.configureCitationImageConstraints(true)
        self.labelCitationContent?.numberOfLines = 2
    }

    private func configureCitationLocation(for decryptedMessage: DPAGDecryptedMessage) {
        self.labelCitationContent?.text = DPAGLocalizedString("chat.location-cell.info-text", comment: "text displayed on location cells within chat stream")
        if let data = decryptedMessage.content?.data(using: .utf8) {
            do {
                if let locationDict = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any], let imageDataString = locationDict[DPAGStrings.JSON.Location.PREVIEW] as? String, let imageData = Data(base64Encoded: imageDataString, options: .ignoreUnknownCharacters), let previewImage = UIImage(data: imageData) {
                    self.configureCitationImageConstraints(true)
                    if previewImage.size.width > DPAGConstantsGlobal.kChatMaxWidthObjects {
                        self.imageViewCitation?.image = UIImage(data: imageData, scale: UIScreen.main.scale)
                    } else {
                        self.imageViewCitation?.image = previewImage
                    }
                    self.imageViewCitation?.tintColor = nil
                }
            } catch {
                DPAGLog(error)
            }
        }
        self.configureCitationImageConstraints(true)
        self.labelCitationContent?.numberOfLines = 2
    }

    private func configureCitationFile(for decryptedMessage: DPAGDecryptedMessage) {
        if let fileName = decryptedMessage.additionalData?.fileName {
            self.labelCitationContent?.text = fileName
            var fileExt = ""
            if let rangeExtension = fileName.range(of: ".", options: .backwards) {
                fileExt = String(fileName[rangeExtension.upperBound...])
            }
            let imageType = DPAGImageProvider.shared.imageForFileExtension(fileExt)
            self.configureCitationImageConstraints(true)
            self.imageViewCitation?.image = imageType
            self.imageViewCitation?.tintColor = nil
            self.labelCitationContent?.numberOfLines = 2
        }
    }

    private func configureCitationImageConstraints(_ forImage: Bool) {
        self.imageViewCitation?.isHidden = forImage == false
    }
}
