//
//  DPAGChatConfirmContactCell.swift
// ginlo
//
//  Created by RBU on 24/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

public protocol DPAGChatContactConfirmCellProtocol: DPAGChatOverviewNotConfirmedBaseCellProtocol {}

class DPAGChatContactConfirmCell: DPAGChatOverviewNotConfirmedBaseCell, DPAGChatContactConfirmCellProtocol {
    override var buttonDeny: DPAGButtonSegmentedControlLeft! {
        didSet {
            self.buttonDeny.setTitle(DPAGLocalizedString("chat.stream.blockContact"), for: .normal)
        }
    }

    override var buttonConfirm: DPAGButtonSegmentedControlRight! {
        didSet {
            self.buttonConfirm.setTitle(DPAGLocalizedString("chat.stream.confirmContact"), for: .normal)
        }
    }

    override var inviteMessageLabel: UILabel! {
        didSet {
            self.inviteMessageLabel.text = DPAGLocalizedString("chat.stream.contactRequest")
        }
    }
}
