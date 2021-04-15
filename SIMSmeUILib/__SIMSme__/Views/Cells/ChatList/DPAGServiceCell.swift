//
//  DPAGServiceCell.swift
//  SIMSme
//
//  Created by RBU on 16/02/2017.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGServiceCellProtocol: DPAGChatOverviewConfirmedBaseCellProtocol {}

class DPAGServiceCell: DPAGChatOverviewConfirmedBaseCell, DPAGServiceCellProtocol {
    override func configContentViews() {
        super.configContentViews()

        self.viewProfileImage.layer.borderWidth = 0
        self.viewProfileImage.layer.cornerRadius = 0
        self.viewProfileImage.layer.masksToBounds = false
        self.viewProfileImage.backgroundColor = UIColor.clear

        self.backgroundView = UIImageView()
        self.backgroundView?.contentMode = .scaleAspectFill
        self.backgroundView?.clipsToBounds = true
    }

    override func configureCellWithStream(_ decryptedStream: DPAGDecryptedStream) {
        super.configureCellWithStream(decryptedStream)

        self.convertPreviewText(decryptedStream, textColor: (decryptedStream as? DPAGDecryptedStreamChannel)?.colorPreview ?? self.labelPreviewTextColor)

        if let decryptedStreamChannel = decryptedStream as? DPAGDecryptedStreamChannel {
            self.viewProfileImage.image = decryptedStreamChannel.imageForeground

            self.contentView.backgroundColor = decryptedStreamChannel.colorBackground

//            self.labelPreview.textColor = decryptedStreamChannel.colorPreview ?? self.labelPreview.textColor
            self.labelName.textColor = decryptedStreamChannel.colorName ?? self.labelName.textColor
            self.labelDate.textColor = decryptedStreamChannel.colorDate ?? self.labelDate.textColor

            (self.backgroundView as? UIImageView)?.image = decryptedStreamChannel.imageBackground
        }
    }
}
