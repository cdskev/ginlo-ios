//
//  DPAGChannelCell.swift
//  SIMSme
//
//  Created by RBU on 24/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGChannelCellProtocol: DPAGChatOverviewConfirmedBaseCellProtocol {}

class DPAGChannelCell: DPAGChatOverviewConfirmedBaseCell, DPAGChannelCellProtocol {
    @IBOutlet var buttonIcon: UIButton!
    let iconOverlayView = UIView()

    override func awakeFromNib() {
        super.awakeFromNib()
        self.buttonIcon.contentVerticalAlignment = .fill
        self.buttonIcon.contentHorizontalAlignment = .fill
        self.buttonIcon.isUserInteractionEnabled = false

        self.buttonIcon.addSubview(self.iconOverlayView)
    }

    // MARK: - UIView

    override func layoutSubviews() {
        super.layoutSubviews()
        self.buttonIcon.layer.cornerRadius = 0.5 * self.buttonIcon.frame.width
        self.iconOverlayView.frame = self.buttonIcon.bounds
    }

    override func configContentViews() {
        super.configContentViews()
    }

    override func configureCellWithStream(_ decryptedStream: DPAGDecryptedStream) {
        super.configureCellWithStream(decryptedStream)

        self.convertPreviewText(decryptedStream, textColor: self.labelPreviewTextColor)
        self.setUnreadMessagesCount(decryptedStream.newMessagesCount)

        guard let decryptedStreamChannel = decryptedStream as? DPAGDecryptedStreamChannel else { return }

        self.labelDate.textColor = DPAGColorProvider.shared[.labelText]
        self.labelName.text = decryptedStreamChannel.streamName
        self.buttonIcon.setImage(decryptedStreamChannel.imageIcon?.withRenderingMode(.alwaysOriginal), for: .normal)
        self.buttonIcon.backgroundColor = DPAGColorProvider.shared[.channelIconBackground]
        self.iconOverlayView.backgroundColor = DPAGColorProvider.shared[.channelIconOverlay]
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelDate.textColor = DPAGColorProvider.shared[.labelText]
                self.buttonIcon.backgroundColor = DPAGColorProvider.shared[.channelIconBackground]
                self.iconOverlayView.backgroundColor = DPAGColorProvider.shared[.channelIconOverlay]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
