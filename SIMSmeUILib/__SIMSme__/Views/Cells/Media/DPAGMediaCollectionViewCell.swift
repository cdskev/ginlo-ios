//
//  DPAGMediaCollectionViewCell.swift
//  SIMSme
//
//  Created by RBU on 02/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGMediaCollectionViewCellProtocol: AnyObject {
    var imageView: UIImageView! { get }
    var isMediaSelected: Bool { get set }

    func setupWithAttachment(_ attachment: DPAGDecryptedAttachment)
}

class DPAGMediaCollectionViewCell: UICollectionViewCell, DPAGMediaCollectionViewCellProtocol {
    @IBOutlet private var activityIndicator: UIActivityIndicatorView! {
        didSet {
            self.activityIndicator.color = DPAGColorProvider.shared[.labelText]
            self.activityIndicator.tintColor = DPAGColorProvider.shared[.labelText]
            self.activityIndicator.hidesWhenStopped = true
        }
    }

    @IBOutlet public private(set) var imageView: UIImageView! {
        didSet {
            self.imageView.contentMode = .scaleAspectFill
        }
    }

    @IBOutlet private var imageViewSelection: UIImageView! {
        didSet {
            self.imageViewSelection.configureCheck()
            self.imageViewSelection.isHidden = true
        }
    }

    @IBOutlet private var imageViewSelectionBackground: UIView! {
        didSet {
            self.imageViewSelectionBackground.backgroundColor = DPAGColorProvider.shared[.selectionOverlay]
            self.imageViewSelectionBackground.isHidden = true
        }
    }

    @IBOutlet private var imageViewType: UIImageView! {
        didSet {
            self.imageViewType.tintColor = DPAGColorProvider.shared[.buttonOverlayTint]
            self.imageViewType.backgroundColor = DPAGColorProvider.shared[.buttonOverlayBackground]
            self.imageViewType.layer.cornerRadius = self.imageViewType.bounds.width / 2
            self.imageViewType.isHidden = true
        }
    }

    @IBOutlet private var viewLabels: UIView!
    @IBOutlet private var labelName: UILabel! {
        didSet {
            self.labelName.textColor = DPAGColorProvider.shared[.labelText]
            self.labelName.font = UIFont.boldSystemFont(ofSize: 13)
            self.labelName.textAlignment = .center
            self.labelName.text = nil
        }
    }

    @IBOutlet private var labelDate: UILabel! {
        didSet {
            self.labelDate.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDate.font = UIFont.italicSystemFont(ofSize: 11)
            self.labelDate.numberOfLines = 0
            self.labelDate.textAlignment = .center
            self.labelDate.text = nil
        }
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.activityIndicator.color = DPAGColorProvider.shared[.labelText]
                self.activityIndicator.tintColor = DPAGColorProvider.shared[.labelText]
                self.imageViewSelectionBackground.backgroundColor = DPAGColorProvider.shared[.selectionOverlay]
                self.imageViewType.tintColor = DPAGColorProvider.shared[.buttonOverlayTint]
                self.imageViewType.backgroundColor = DPAGColorProvider.shared[.buttonOverlayBackground]
                self.labelName.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDate.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var constraintContentWidth: NSLayoutConstraint!

    private static let CELL_GAP: CGFloat = 1
    private static let CELL_LABEL_GAP: CGFloat = 44
    private static let ITEMS_PER_ROW: CGFloat = 4

    override func awakeFromNib() {
        super.awakeFromNib()

        self.constraintContentWidth.constant = floor((min(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height) - (DPAGMediaCollectionViewCell.ITEMS_PER_ROW - 1) * DPAGMediaCollectionViewCell.CELL_GAP) / DPAGMediaCollectionViewCell.ITEMS_PER_ROW)
    }

    private var hasSpinner = false

    var isMediaSelected: Bool = false {
        didSet {
            guard self.hasSpinner == false, self.isMediaSelected != oldValue else { return }

            self.imageViewSelection.isHidden = (self.isMediaSelected == false)
            self.imageViewSelectionBackground.isHidden = self.imageViewSelection.isHidden
        }
    }

    private func setupWithSpinner() -> Bool {
        if self.hasSpinner {
            return false
        }

        self.hasSpinner = true
        self.activityIndicator.startAnimating()

        return true
    }

    private func setupWithImage(_ image: UIImage?, mediaType: DPAGAttachmentType) {
        self.imageView.image = image

        switch mediaType {
        case .video:

            self.imageViewType.image = DPAGImageProvider.shared[.kImageChatCellOverlayVideoPlay]
            self.imageViewType.isHidden = false
            self.imageView.isAccessibilityElement = true
            self.imageView.accessibilityTraits = UIAccessibilityTraits.selected
            self.imageView.accessibilityLabel = DPAGLocalizedString("chats.destructionMessageCell.videoType")

        case .voiceRec:

            self.imageViewType.image = DPAGImageProvider.shared[.kImageChatCellOverlayAudioPlay]
            self.imageViewType.isHidden = false
            self.imageView.image = DPAGImageProvider.shared[.kImageChatCellUnderlayAudio]
            self.imageView.isAccessibilityElement = true
            self.imageView.accessibilityTraits = UIAccessibilityTraits.selected
            self.imageView.accessibilityLabel = DPAGLocalizedString("chats.voiceMessage.title")

        case .file:

            self.imageViewType.image = nil
            self.imageViewType.isHidden = true
            self.imageView.isAccessibilityElement = true
            self.imageView.accessibilityTraits = UIAccessibilityTraits.selected
            self.imageView.accessibilityLabel = DPAGLocalizedString("chats.fileMessageCell.title")

        case .image:

            self.imageViewType.image = nil
            self.imageViewType.isHidden = true
            self.imageView.isAccessibilityElement = true
            self.imageView.accessibilityTraits = UIAccessibilityTraits.selected
            self.imageView.accessibilityLabel = DPAGLocalizedString("chats.destructionMessageCell.imageType")

        case .unknown:

            self.imageViewType.image = nil
            self.imageViewType.isHidden = true
            self.imageView.isAccessibilityElement = false
        }
    }

    func setupWithAttachment(_ attachment: DPAGDecryptedAttachment) {
        self.hasSpinner = false
        self.activityIndicator.stopAnimating()

        self.setupWithImage(attachment.thumb, mediaType: attachment.attachmentType)

        if let name = attachment.contactName {
            self.addMetadataWithName(name, date: attachment.messageDate)
        }
    }

    private func addMetadataWithName(_ name: String, date: Date?) {
        self.labelName?.text = name
        self.labelDate?.text = date?.timeLabelMedia
    }
}
