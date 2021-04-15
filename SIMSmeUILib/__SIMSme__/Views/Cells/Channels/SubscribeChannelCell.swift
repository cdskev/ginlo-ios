//
//  SubscribeChannelCell.swift
//  SIMSmeUILib
//
//  Created by Evgenii Kononenko on 02.05.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

struct SubscribeChannelCellViewModel {
    var name: String?
    var description: String?
    var image: UIImage?
    var showCheckMark: Bool
}

class SubscribeChannelCell: DPAGDefaultTableViewCell {
    @IBOutlet var labelName: UILabel!
    @IBOutlet var labelDescription: UILabel!
    @IBOutlet var imageViewCheckMark: UIImageView!

    @IBOutlet var buttonIcon: UIButton!
    var viewModel: SubscribeChannelCellViewModel?
    let iconOverlayView = UIView()

    // MARK: - UIView

    override func awakeFromNib() {
        super.awakeFromNib()
        self.buttonIcon.contentVerticalAlignment = .fill
        self.buttonIcon.contentHorizontalAlignment = .fill
        self.buttonIcon.isUserInteractionEnabled = false

        self.buttonIcon.addSubview(self.iconOverlayView)

        self.imageViewCheckMark.image = DPAGImageProvider.shared[.KImageChannelSubscribedCheckmark]

        self.labelName?.adjustsFontForContentSizeCategory = true
        self.labelDescription?.adjustsFontForContentSizeCategory = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.buttonIcon.layer.cornerRadius = 0.5 * self.buttonIcon.frame.width

        self.iconOverlayView.frame = self.buttonIcon.bounds
    }

    // MARK: - Internal

    func setupWithViewModel(viewModel: SubscribeChannelCellViewModel) {
        self.viewModel = viewModel
        self.accessibilityIdentifier = (viewModel.name ?? "") + "-search"
        self.labelName.text = viewModel.name
        self.labelDescription.text = viewModel.description
        self.labelDescription.isHidden = viewModel.description == nil
        self.imageViewCheckMark.isHidden = viewModel.showCheckMark == false
        self.buttonIcon.setImage(viewModel.image?.withRenderingMode(.alwaysOriginal), for: .normal)
    }

    // MARK: - Override

    override func updateFonts() {
        self.labelName.font = UIFont.kFontHeadline
        self.labelDescription.font = UIFont.kFontBody
    }

    override func updateColors() {
        self.labelName.textColor = DPAGColorProvider.shared[.labelText]
        self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
        self.buttonIcon.backgroundColor = DPAGColorProvider.shared[.channelIconBackground]
        self.iconOverlayView.backgroundColor = DPAGColorProvider.shared[.channelIconOverlay]
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                updateColors()
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
