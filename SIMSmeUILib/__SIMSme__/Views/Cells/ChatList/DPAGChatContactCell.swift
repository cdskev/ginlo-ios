//
//  DPAGChatContactCell.swift
//  SIMSme
//
//  Created by RBU on 24/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGChatContactCellProtocol: DPAGChatOverviewConfirmedBaseCellProtocol {
    func configure(with contact: DPAGContact)
}

class DPAGChatContactCell: DPAGChatOverviewConfirmedBaseCell, DPAGChatContactCellProtocol {
    // MARK: - Override

    override func configureCellWithStream(_ decryptedStream: DPAGDecryptedStream) {
        super.configureCellWithStream(decryptedStream)

        self.convertPreviewText(decryptedStream, textColor: self.labelPreviewTextColor)

        guard let privateStream = decryptedStream as? DPAGDecryptedStreamPrivate else {
            return
        }

        if privateStream.isSystemChat {
            self.configureForSystemChat()
        }
    }

    // MARK: - DPAGChatContactCellProtocol

    func configure(with contact: DPAGContact) {
        self.labelName.text = contact.displayName
        self.labelPreview.text = contact.statusMessageFallback
        self.viewProfileImage.image = contact.image(for: .chatList)

        if let lastMessageDate = contact.lastMessageDate {
            self.labelDate.text = DateFormatter.localizedString(from: lastMessageDate, dateStyle: .short, timeStyle: .short)
        } else {
            self.labelDate.text = ""
        }
        self.setUnreadMessagesCount(0)
    }

    // MARK: - Private

    private func configureForSystemChat() {
        self.viewProfileImage.image = DPAGImageProvider.shared[.kImageChatSystemLogo]
    }
}
