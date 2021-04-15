//
//  DPAGChatOverviewBaseCell.swift
//  SIMSme
//
//  Created by RBU on 24/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGChatOverviewBaseCellProtocol: AnyObject {
    func configureCellWithStream(_ decryptedStream: DPAGDecryptedStream)

    func setAnimating(_ animating: Bool)
}

class DPAGChatOverviewBaseCell: UITableViewCell, DPAGChatOverviewBaseCellProtocol {
    @IBOutlet var viewConfidenceState: UIView? {
        didSet {}
    }

    @IBOutlet var viewProfileImage: UIImageView! {
        didSet {
            // self.viewProfileImage.layer.borderWidth = 2
            self.viewProfileImage.layer.cornerRadius = self.viewProfileImage.frame.size.height / 2.0
            self.viewProfileImage.layer.masksToBounds = true
            self.viewProfileImage.backgroundColor = .clear
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

    @IBOutlet private var activitiyIndicatorSelection: UIActivityIndicatorView!

    override func awakeFromNib() {
        super.awakeFromNib()
        self.configContentViews()
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
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public

    func configContentViews() {
        self.labelName.adjustsFontForContentSizeCategory = true
        self.labelDate.adjustsFontForContentSizeCategory = true
        self.backgroundColor = .clear
        self.setSelectionColor()
        self.contentView.backgroundColor = .clear
        self.separatorInset = .zero
        self.layoutMargins = .zero
        self.activitiyIndicatorSelection.color = DPAGColorProvider.shared[.conversationOverviewSelectionSpinner]
        self.updateFonts()
    }

    @objc
    func updateFonts() {
        self.labelDate.font = UIFont.kFontFootnote
        self.labelName.font = UIFont.kFontHeadline
    }

    override var accessibilityLabel: String? {
        get {
            self.labelName.text
        }
        set {
            super.accessibilityLabel = newValue
        }
    }

    func setAnimating(_ animating: Bool) {
        self.setHighlighted(animating, animated: false)
        if animating {
            self.activitiyIndicatorSelection.startAnimating()
        } else {
            self.activitiyIndicatorSelection.stopAnimating()
        }
    }

    func configureCellWithStream(_ decryptedStream: DPAGDecryptedStream) {
        self.backgroundColor = .clear // DPAGColorProvider.shared[.defaultViewBackground]
        self.labelName.textColor = DPAGColorProvider.shared[.labelText]
        self.labelDate.textColor = DPAGColorProvider.shared[.labelText]
        self.setConfidenceStatusAndProfileImageForDecryptedStream(decryptedStream)
        self.labelDate.text = decryptedStream.lastMessageDateFormatted
    }

    func handleDesignColorsUpdated() {
        self.backgroundColor = .clear // DPAGColorProvider.shared[.defaultViewBackground]
        self.contentView.backgroundColor = .clear // DPAGColorProvider.shared[.defaultViewBackground]
        self.labelName.textColor = DPAGColorProvider.shared[.labelText]
        self.labelDate.textColor = DPAGColorProvider.shared[.labelText]
        self.activitiyIndicatorSelection.color = DPAGColorProvider.shared[.conversationOverviewSelectionSpinner]
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                handleDesignColorsUpdated()
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    func setConfidenceStatusAndProfileImageForDecryptedStream(_ decStream: DPAGDecryptedStream) {
        if AppConfig.isShareExtension {
            let cache = DPAGApplicationFacadeShareExt.cache
            if let decStreamPrivate = decStream as? DPAGDecryptedStreamPrivate, let contactGuid = decStreamPrivate.contactGuid, let contact = cache.contact(for: contactGuid) {
                if let image = contact.image(for: .chatList) {
                    self.viewProfileImage.image = image.circleImageUsingConfidenceColor(UIColor.confidenceStatusToColor(contact.confidence))
                }
            } else if let decStreamGroup = decStream as? DPAGDecryptedStreamGroup, let group = cache.group(for: decStreamGroup.guid) {
                let image: UIImage?
                if let encodedImage = group.imageData, let imageData = Data(base64Encoded: encodedImage, options: .ignoreUnknownCharacters) {
                    image = UIImage(data: imageData)
                } else {
                    image = DPAGUIImageHelper.image(forGroupGuid: group.guid, imageType: .chatList)
                }
                if let image = image {
                    self.viewProfileImage.image = image.circleImageUsingConfidenceColor(UIColor.confidenceStatusToColor(group.confidenceState), thickness: 12)
                }
            }
        } else {
            let cache = DPAGApplicationFacade.cache
            if let decStreamPrivate = decStream as? DPAGDecryptedStreamPrivate, let contactGuid = decStreamPrivate.contactGuid, let contact = cache.contact(for: contactGuid) {
                if let image = contact.image(for: .chatList) {
                    self.viewProfileImage.image = image.circleImageUsingConfidenceColor(UIColor.confidenceStatusToColor(contact.confidence))
                }
            } else if let decStreamGroup = decStream as? DPAGDecryptedStreamGroup, let group = cache.group(for: decStreamGroup.guid) {
                let image: UIImage?
                if let encodedImage = group.imageData, let imageData = Data(base64Encoded: encodedImage, options: .ignoreUnknownCharacters) {
                    image = UIImage(data: imageData)
                } else {
                    image = DPAGUIImageHelper.image(forGroupGuid: group.guid, imageType: .chatList)
                }
                if let image = image {
                    self.viewProfileImage.image = image.circleImageUsingConfidenceColor(UIColor.confidenceStatusToColor(group.confidenceState), thickness: 12)
                }
            }
        }
    }
}
