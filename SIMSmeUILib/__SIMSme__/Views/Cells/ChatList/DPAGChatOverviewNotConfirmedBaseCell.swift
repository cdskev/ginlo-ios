//
//  DPAGChatOverviewNotConfirmedBaseCell.swift
//  SIMSme
//
//  Created by RBU on 25/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGChatCellConfirmDelegate: AnyObject {
    func handleDenyWithCell(_ cell: UITableViewCell & DPAGChatOverviewNotConfirmedBaseCellProtocol)
    func handleConfirmWithCell(_ cell: UITableViewCell & DPAGChatOverviewNotConfirmedBaseCellProtocol)
}

public protocol DPAGChatOverviewNotConfirmedBaseCellProtocol: DPAGChatOverviewBaseCellProtocol {
    var delegateConfirm: DPAGChatCellConfirmDelegate? { get set }
}

class DPAGChatOverviewNotConfirmedBaseCell: DPAGChatOverviewBaseCell, DPAGChatOverviewNotConfirmedBaseCellProtocol {
    @IBOutlet var buttonDeny: DPAGButtonSegmentedControlLeft! {
        didSet {
            self.buttonDeny.configureSegControlButtonLeft()
            self.buttonDeny.addTarget(self, action: #selector(handleDeny), for: .touchUpInside)
            self.buttonDeny.isEnabled = true
        }
    }

    @IBOutlet var buttonConfirm: DPAGButtonSegmentedControlRight! {
        didSet {
            self.buttonConfirm.configureSegControlButtonRight()
            self.buttonConfirm.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)
            self.buttonConfirm.isEnabled = true
        }
    }

    @IBOutlet var inviteMessageLabel: UILabel!

    weak var delegateConfirm: DPAGChatCellConfirmDelegate?

    override func configureCellWithStream(_ decryptedStream: DPAGDecryptedStream) {
        super.configureCellWithStream(decryptedStream)
        self.buttonDeny.updateSegControlButtonLeft()
        self.buttonConfirm.updateSegControlButtonRight()
        self.inviteMessageLabel.textColor = DPAGColorProvider.shared[.labelText]
        self.labelName.text = decryptedStream.name
    }

    @objc
    private func handleDeny() {
        self.delegateConfirm?.handleDenyWithCell(self)
    }

    @objc
    private func handleConfirm() {
        self.delegateConfirm?.handleConfirmWithCell(self)
    }
    
    override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.inviteMessageLabel.textColor = DPAGColorProvider.shared[.labelText]
    }
}
