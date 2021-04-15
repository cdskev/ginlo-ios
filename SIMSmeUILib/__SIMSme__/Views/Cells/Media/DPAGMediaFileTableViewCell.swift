//
//  DPAGMediaFileTableViewCell.swift
//  SIMSme
//
//  Created by RBU on 02/03/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGMediaFileTableViewCell: UITableViewCell, DPAGMediaFileTableViewCellProtocol {
    @IBOutlet private var activityIndicator: UIActivityIndicatorView! {
        didSet {
            self.activityIndicator.color = DPAGColorProvider.shared[.labelText]
            self.activityIndicator.tintColor = DPAGColorProvider.shared[.labelText]
            self.activityIndicator.hidesWhenStopped = true
        }
    }

    @IBOutlet private var imageViewFileType: UIImageView!

    @IBOutlet private var labelFileName: UILabel! {
        didSet {
            self.labelFileName.textColor = DPAGColorProvider.shared[.labelText]
            self.labelFileName.font = UIFont.kFontHeadline
            self.labelFileName.lineBreakMode = .byTruncatingMiddle
            self.labelFileName.text = nil
        }
    }

    @IBOutlet private var labelStreamName: UILabel! {
        didSet {
            self.labelStreamName.textColor = DPAGColorProvider.shared[.labelText]
            self.labelStreamName.font = UIFont.kFontFootnote
            self.labelStreamName.text = nil
        }
    }

    @IBOutlet private var labelMessageDate: UILabel! {
        didSet {
            self.labelMessageDate.textColor = DPAGColorProvider.shared[.labelText]
            self.labelMessageDate.font = UIFont.kFontFootnote
            self.labelMessageDate.text = nil
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
                self.labelFileName.textColor = DPAGColorProvider.shared[.labelText]
                self.labelStreamName.textColor = DPAGColorProvider.shared[.labelText]
                self.labelMessageDate.textColor = DPAGColorProvider.shared[.labelText]
                self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    private var hasSpinner = false

    var isMediaSelected: Bool = false {
        didSet {
            guard self.hasSpinner == false, self.isMediaSelected != oldValue else { return }
            if self.isMediaSelected {
                let imageView = UIImageView(frame: CGRect(origin: .zero, size: CGSize(width: 20, height: 20)))

                imageView.configureCheck()

                self.accessoryView = imageView
            } else {
                self.accessoryView = nil
            }
        }
    }

    func setupWithAttachment(_ attachment: DPAGDecryptedAttachment) {
        self.activityIndicator.stopAnimating()
        self.hasSpinner = false
        switch attachment.attachmentType {
            case .file:
                let fileName = attachment.additionalData?.fileName ?? ""
                self.labelFileName.text = fileName
                var fileExt = ""
                if let rangeExtension = fileName.range(of: ".", options: .backwards) {
                    fileExt = String(fileName[rangeExtension.upperBound...])
                }
                self.imageViewFileType.image = DPAGImageProvider.shared.imageForFileExtension(fileExt)
            case .image:
                self.imageViewFileType.image = attachment.thumb
                self.labelFileName.text = nil
            case .video:
                self.imageViewFileType.image = attachment.thumb
                self.labelFileName.text = nil
            case .voiceRec:
                self.imageViewFileType.image = DPAGImageProvider.shared[.kImageChatCellUnderlayAudio]
                self.labelFileName.text = nil
            case .unknown:
                self.imageViewFileType.image = nil
                self.labelFileName.text = nil
        }
        self.labelStreamName.text = attachment.contactName
        self.labelMessageDate.text = attachment.messageDate?.timeLabelMediaFile
        self.selectionStyle = .none
    }

    private func setupWithSpinner() -> Bool {
        if self.hasSpinner {
            return false
        }

        self.hasSpinner = true
        self.activityIndicator.startAnimating()

        return true
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.contentView.backgroundColor = .clear
    }

    func update(withSearchBarText searchBarText: String?) {
        self.labelStreamName.updateWithSearchBarText(searchBarText)
        self.labelFileName.updateWithSearchBarText(searchBarText)
    }
}
