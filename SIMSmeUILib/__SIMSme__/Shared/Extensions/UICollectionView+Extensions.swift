//
//  UICollectionView+Extensions.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore

public extension UICollectionView {
    func setEmptyMessage(_ emptyMessage: String) {
        if (self.backgroundView?.subviews.count ?? 0) == 0 {
            let label = UILabel(frame: self.bounds.insetBy(dx: DPAGConstantsGlobal.kPadding, dy: DPAGConstantsGlobal.kPadding))

            label.textAlignment = .center
            label.textColor = DPAGColorProvider.shared[.labelText]
            label.font = UIFont.boldSystemFont(ofSize: 12)
            label.numberOfLines = 0
            label.text = emptyMessage
            label.translatesAutoresizingMaskIntoConstraints = false
            label.backgroundColor = UIColor.clear

            if self.backgroundView == nil {
                let bckView = UIView(frame: self.bounds)

                self.backgroundView = bckView
                bckView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            }
            self.backgroundView?.addSubview(label)

            if let backgroundView = self.backgroundView {
                NSLayoutConstraint.activate([
                    backgroundView.constraintLeading(subview: label, padding: DPAGConstantsGlobal.kPadding),
                    backgroundView.constraintTrailing(subview: label, padding: DPAGConstantsGlobal.kPadding),
                    backgroundView.constraintTop(subview: label, padding: 5 * DPAGConstantsGlobal.kPadding)
                ])
            }
        } else if let label = self.backgroundView?.subviews.first as? UILabel {
            label.text = emptyMessage
        }
    }

    func removeEmptyMessage() {
        if let backgroundView = self.backgroundView {
            for subview in backgroundView.subviews {
                subview.removeFromSuperview()
            }
        }
    }
}
