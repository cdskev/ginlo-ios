//
//  DPAGMediaSendingCollectionViewCell.swift
//  SIMSmeUILib
//
//  Created by RBU on 09.05.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Photos
import SIMSmeCore
import UIKit

public protocol DPAGMediaSendingCollectionViewCellProtocol: AnyObject {
    func setup(mediaResource: DPAGMediaResource)
    func setupAddImage()
}

class DPAGMediaSendingCollectionViewCell: UICollectionViewCell, DPAGMediaSendingCollectionViewCellProtocol {
    @IBOutlet private var imageView: UIImageView! {
        didSet {
            self.imageView.contentMode = .scaleAspectFill
        }
    }

    override var isSelected: Bool {
        didSet {
            if self.isSelected {
                self.imageView.layer.borderColor = DPAGColorProvider.shared[.selectionBorder].cgColor
                self.imageView.layer.borderWidth = 3
            } else {
                self.imageView.layer.borderColor = DPAGColorProvider.shared[.defaultViewBackground].cgColor
                self.imageView.layer.borderWidth = 1
            }
        }
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                if self.isSelected {
                    self.imageView.layer.borderColor = DPAGColorProvider.shared[.selectionBorder].cgColor
                } else {
                    self.imageView.layer.borderColor = DPAGColorProvider.shared[.defaultViewBackground].cgColor
                }
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    func setupAddImage() {
        self.imageView.image = DPAGImageProvider.shared[.kImageChatAddObject]
        self.imageView.isAccessibilityElement = true
        self.imageView.accessibilityTraits = UIAccessibilityTraits.selected
        self.imageView.accessibilityLabel = DPAGLocalizedString("chats.destructionMessageCell.imageType")
    }

    func setup(mediaResource: DPAGMediaResource) {
        if let preview = mediaResource.preview {
            self.imageView.image = preview
        } else if let image = mediaResource.attachment?.thumb {
            self.imageView.image = image
        } else if let imageAsset = mediaResource.mediaAsset {
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.resizeMode = .fast
            PHImageManager.default().requestImage(for: imageAsset, targetSize: self.bounds.size, contentMode: .aspectFill, options: options) { [weak self] image, _ in
                guard let image = image else { return }
                self?.performBlockOnMainThread { [weak self] in
                    self?.imageView.image = image
                }
            }
        }
        switch mediaResource.mediaType {
            case .video:
                self.imageView.isAccessibilityElement = true
                self.imageView.accessibilityTraits = UIAccessibilityTraits.selected
                self.imageView.accessibilityLabel = DPAGLocalizedString("chats.destructionMessageCell.videoType")

            case .voiceRec:
                self.imageView.image = DPAGImageProvider.shared[.kImageChatCellUnderlayAudio]
                self.imageView.isAccessibilityElement = true
                self.imageView.accessibilityTraits = UIAccessibilityTraits.selected
                self.imageView.accessibilityLabel = DPAGLocalizedString("chats.voiceMessage.title")

            case .file:
                self.imageView.isAccessibilityElement = true
                self.imageView.accessibilityTraits = UIAccessibilityTraits.selected
                self.imageView.accessibilityLabel = DPAGLocalizedString("chats.fileMessageCell.title")

            case .image:
                self.imageView.isAccessibilityElement = true
                self.imageView.accessibilityTraits = UIAccessibilityTraits.selected
                self.imageView.accessibilityLabel = DPAGLocalizedString("chats.destructionMessageCell.imageType")

            case .unknown:
                self.imageView.isAccessibilityElement = false
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
    }
}
