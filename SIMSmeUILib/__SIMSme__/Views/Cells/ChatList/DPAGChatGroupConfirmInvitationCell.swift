//
//  DPAGGroupConfirmInvitationCell.swift
// ginlo
//
//  Created by RBU on 24/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGChatGroupConfirmInvitationCellProtocol: DPAGChatOverviewNotConfirmedBaseCellProtocol {}

class DPAGChatGroupConfirmInvitationCell: DPAGChatOverviewNotConfirmedBaseCell, DPAGChatGroupConfirmInvitationCellProtocol {
    override var buttonDeny: DPAGButtonSegmentedControlLeft! {
        didSet {
            self.buttonDeny.setTitle(DPAGLocalizedString("chat.stream.blockGroup"), for: .normal)
        }
    }

    override var buttonConfirm: DPAGButtonSegmentedControlRight! {
        didSet {
            self.buttonConfirm.setTitle(DPAGLocalizedString("chat.stream.confirmGroup"), for: .normal)
        }
    }

    override var inviteMessageLabel: UILabel! {
        didSet {
            self.inviteMessageLabel.text = DPAGLocalizedString("chat.stream.groupRequest")
        }
    }

    override func configureCellWithStream(_ decryptedStream: DPAGDecryptedStream) {
        super.configureCellWithStream(decryptedStream)
        if let decryptedStreamGroup = decryptedStream as? DPAGDecryptedStreamGroup, let group = DPAGApplicationFacade.cache.group(for: decryptedStreamGroup.guid) {
            self.buttonDeny.isHidden = (group.groupType != .default && group.groupType != .announcement)
        }
    }
}
