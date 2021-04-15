//
//  UITableViewCell+Extensions.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore

extension UITableViewCell {
    func calculateHeightForConfiguredSizingCellWidth(_ width: CGFloat) -> CGFloat {
        self.bounds = CGRect(origin: .zero, size: CGSize(width: width, height: self.bounds.height))
        self.setNeedsLayout()
        self.layoutIfNeeded()

        let size = self.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)

        return size.height + 1.0
    }

    func setSelectionColor(color: UIColor? = DPAGColorProvider.shared[.cellSelection]) {
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = color
        self.selectedBackgroundView = selectedBackgroundView
    }
}
