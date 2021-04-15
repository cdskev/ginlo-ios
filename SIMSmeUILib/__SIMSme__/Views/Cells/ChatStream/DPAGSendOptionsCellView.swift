//
//  DPAGSendOptionsCellView.swift
//  SIMSmeUILib
//
//  Created by RBU on 25.05.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

@IBDesignable
class DPAGSendOptionsCellView: DPAGStackViewContentView, NibFileOwnerLoadable {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadNibContent()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @IBOutlet var viewHighPriority: DPAGStackViewContentView!
    @IBOutlet private var imageViewHighPriority: UIImageView? {
        didSet {
            self.imageViewHighPriority?.image = DPAGImageProvider.shared[.kImagePriority]
            self.imageViewHighPriority?.tintColor = DPAGColorProvider.shared[.messageSendOptionsCellBackgroundContrast]
        }
    }

    @IBOutlet private var imageViewSelfDestruct: UIImageView? {
        didSet {
            self.imageViewSelfDestruct?.image = DPAGImageProvider.shared[.kImageChatSelfdestruct]
            self.imageViewSelfDestruct?.tintColor = DPAGColorProvider.shared[.messageSendOptionsCellBackgroundContrast]
            self.imageViewSelfDestruct?.isHidden = true
        }
    }

    @IBOutlet private var labelSelfDestruct: UILabel? {
        didSet {
            self.labelSelfDestruct?.font = UIFont.kFontFootnote
            self.labelSelfDestruct?.textColor = DPAGColorProvider.shared[.messageSendOptionsCellBackgroundContrast]
            self.labelSelfDestruct?.isHidden = true
            self.labelSelfDestruct?.text = nil
        }
    }

    @IBOutlet private var imageViewSendTimed: UIImageView? {
        didSet {
            self.imageViewSendTimed?.image = DPAGImageProvider.shared[.kImageChatSendTimed]
            self.imageViewSendTimed?.tintColor = DPAGColorProvider.shared[.messageSendOptionsCellBackgroundContrast]
            self.imageViewSendTimed?.isHidden = true
        }
    }

    @IBOutlet private var labelSendTimed: UILabel? {
        didSet {
            self.labelSendTimed?.font = UIFont.kFontFootnote
            self.labelSendTimed?.textColor = DPAGColorProvider.shared[.messageSendOptionsCellBackgroundContrast]
            self.labelSendTimed?.isHidden = true
            self.labelSendTimed?.text = nil
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        self.backgroundColor = DPAGColorProvider.shared[.messageSendOptionsCellBackground]
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.imageViewHighPriority?.tintColor = DPAGColorProvider.shared[.messageSendOptionsCellBackgroundContrast]
                self.imageViewSelfDestruct?.tintColor = DPAGColorProvider.shared[.messageSendOptionsCellBackgroundContrast]
                self.labelSelfDestruct?.textColor = DPAGColorProvider.shared[.messageSendOptionsCellBackgroundContrast]
                self.labelSendTimed?.textColor = DPAGColorProvider.shared[.messageSendOptionsCellBackgroundContrast]
                self.backgroundColor = DPAGColorProvider.shared[.messageSendOptionsCellBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        self.loadNibContent()

        self.labelSelfDestruct?.text = "selfDest"
        self.labelSendTimed?.text = "Timed"

        self.labelSelfDestruct?.isHidden = false
        self.labelSendTimed?.isHidden = false

        self.imageViewSelfDestruct?.isHidden = false
        self.imageViewSendTimed?.isHidden = false

        self.backgroundColor = .red
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 0, height: 24)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if let label = self.labelSendTimed, label.bounds.height > 0 {
            label.preferredMaxLayoutWidth = label.frame.width
        }
        if let label = self.labelSelfDestruct, label.bounds.height > 0 {
            label.preferredMaxLayoutWidth = 0 // label.frame.width
        }
    }

    func configureCellWithMessage(_ decryptedMessage: DPAGDecryptedMessage, forHeightMeasurement _: Bool) {
        if decryptedMessage.isHighPriorityMessage {
            self.viewHighPriority?.isHidden = false
        } else {
            self.viewHighPriority?.isHidden = true
        }

        if decryptedMessage.isSelfDestructive, decryptedMessage.isOwnMessage {
            if self.imageViewSelfDestruct?.isHidden ?? false {
                self.imageViewSelfDestruct?.isHidden = false
            }
            if self.labelSelfDestruct?.isHidden ?? false {
                self.labelSelfDestruct?.isHidden = false
            }
            self.labelSelfDestruct?.text = decryptedMessage.sendOptions?.timerLabelDestructionCell
        } else {
            if (self.imageViewSelfDestruct?.isHidden ?? true) == false {
                self.imageViewSelfDestruct?.isHidden = true
            }
            if (self.labelSelfDestruct?.isHidden ?? true) == false {
                self.labelSelfDestruct?.isHidden = true
            }
        }

        if decryptedMessage.sendOptions?.dateToBeSend != nil {
            if self.imageViewSendTimed?.isHidden ?? false {
                self.imageViewSendTimed?.isHidden = false
            }
            if self.labelSendTimed?.isHidden ?? false {
                self.labelSendTimed?.isHidden = false
            }
            self.labelSendTimed?.text = decryptedMessage.sendOptions?.timerLabelSendTimeCell
        } else {
            if (self.imageViewSendTimed?.isHidden ?? true) == false {
                self.imageViewSendTimed?.isHidden = true
            }
            if (self.labelSendTimed?.isHidden ?? true) == false {
                self.labelSendTimed?.isHidden = true
            }
        }
    }
}
