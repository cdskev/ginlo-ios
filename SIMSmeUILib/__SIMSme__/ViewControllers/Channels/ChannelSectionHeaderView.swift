//
//  ChannelSectionHeaderView.swift
//  SIMSmeUILib
//
//  Created by Maxime Bentin on 06.05.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation
import SIMSmeCore

class ChannelSectionHeaderView: UITableViewHeaderFooterView {
    static let reuseIdentifer = "ChannelSectionHeaderViewIdentifier"
    let customLabel = UILabel()

    override public init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        customLabel.translatesAutoresizingMaskIntoConstraints = false
        customLabel.textColor = DPAGColorProvider.shared[.labelText]
        self.contentView.addSubview(customLabel)

        let margins = contentView.layoutMarginsGuide

        NSLayoutConstraint.activate([
            customLabel.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            customLabel.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            customLabel.topAnchor.constraint(equalTo: margins.topAnchor),
            customLabel.bottomAnchor.constraint(equalTo: margins.bottomAnchor)
        ])
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                customLabel.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
