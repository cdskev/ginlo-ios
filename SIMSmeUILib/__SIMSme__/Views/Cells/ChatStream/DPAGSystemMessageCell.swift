//
//  DPAGSystemMessageCell.swift
// ginlo
//
//  Created by RBU on 06/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGSystemMessageCellProtocol: DPAGMessageCellProtocol {}

class DPAGSystemMessageCell: DPAGMessageCell, DPAGSystemMessageCellProtocol {
    @IBOutlet var viewBackground: UIImageView?
    @IBOutlet var labelMessage: UILabel!

    override func layoutSubviews() {
        super.layoutSubviews()

        if let labelMessage = self.labelMessage {
            self.labelMessage?.preferredMaxLayoutWidth = labelMessage.frame.width
        }
    }

    override func configContentViews() {
        super.configContentViews()

        self.labelMessage?.textAlignment = .center
        self.labelMessage?.numberOfLines = 0
        self.labelMessage?.textColor = DPAGColorProvider.shared[.systemMessageText]
        self.viewBackground?.backgroundColor = DPAGColorProvider.shared[.systemMessageBackground]

        if let backgroundViewLayer = self.viewBackground?.layer {
            backgroundViewLayer.cornerRadius = 10.0
            backgroundViewLayer.masksToBounds = true
        }

        self.selectionStyle = .none
    }

    override func updateFonts() {
        super.updateFonts()

        self.labelMessage?.font = UIFont.kFontSubheadline
    }

    override func configureCellWithMessage(_ decryptedMessage: DPAGDecryptedMessage, forHeightMeasurement: Bool) {
        super.configureCellWithMessage(decryptedMessage, forHeightMeasurement: forHeightMeasurement)

        self.labelMessage?.attributedText = decryptedMessage.contentParsed

        if forHeightMeasurement == false {
            self.setCellContentSelectedAction { [weak self] in
                self?.didSelectMessageWithValidBlock { [weak self] in

                    guard let strongSelf = self else { return }

                    self?.streamDelegate?.didSelectValidSystemMessage(strongSelf.decryptedMessage)
                }
            }
        }
    }
        
    @objc
    override func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.labelMessage?.textColor = DPAGColorProvider.shared[.systemMessageText]
        self.viewBackground?.backgroundColor = DPAGColorProvider.shared[.systemMessageBackground]
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
}
