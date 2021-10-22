//
//  DPAGGroupChatCell.swift
// ginlo
//
//  Created by RBU on 24/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGChatGroupCellProtocol: DPAGChatOverviewConfirmedBaseCellProtocol {}

class DPAGChatGroupCell: DPAGChatOverviewConfirmedBaseCell, DPAGChatGroupCellProtocol {
    override func configureCellWithStream(_ decryptedStream: DPAGDecryptedStream) {
        self.convertPreviewText(decryptedStream, textColor: self.labelPreviewTextColor)
        super.configureCellWithStream(decryptedStream)
    }
}
