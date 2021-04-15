//
//  DPAGChannelDetailsDesciptionTableViewCell.swift
//  SIMSme
//
//  Created by RBU on 24/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGChannelDetailsDesciptionTableViewCellProtocol: DPAGDefaultTableViewCellProtocol {
    var isShowingAllContent: Bool { get set }
    var tintColorContrast: UIColor { get set }
}

class DPAGChannelDetailsDesciptionTableViewCell: DPAGDefaultTableViewCell, DPAGChannelDetailsDesciptionTableViewCellProtocol {
    @IBOutlet private var imageViewBack: UIImageView? {
        didSet {
            self.imageViewBack?.image = DPAGImageProvider.shared[.kImageChannelDetailsBackground]
        }
    }

    @IBOutlet private var imageViewFront: UIImageView? {
        didSet {
            self.imageViewFront?.tintColor = self.tintColorContrast
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func configContentViews() {
        super.configContentViews()

        self.imageViewBack?.contentMode = .scaleToFill
        self.imageViewFront?.contentMode = .center
    }

    var tintColorContrast: UIColor = .clear {
        didSet {
            self.imageViewFront?.tintColor = self.tintColorContrast
        }
    }

    var isShowingAllContent: Bool = false {
        didSet {
            self.imageViewFront?.image = self.isShowingAllContent ? DPAGImageProvider.shared[.kImageChannelDescriptionHide] : DPAGImageProvider.shared[.kImageChannelDescriptionShow]
        }
    }
}
