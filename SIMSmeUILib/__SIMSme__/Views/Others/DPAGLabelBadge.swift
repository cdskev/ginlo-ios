//
//  DPAGLabelBadge.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore

@IBDesignable
public class DPAGLabelBadge: UILabel {
    var constraintWidth: NSLayoutConstraint?

    override public var intrinsicContentSize: CGSize {
        CGSize(width: DPAGConstantsGlobal.kBadgeSize, height: DPAGConstantsGlobal.kBadgeSize)
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }

    override public func awakeFromNib() {
        super.awakeFromNib()
        self.setup()
    }

    override public func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        self.setup()
        self.text = "#"
    }

    private func setup() {
        guard self.constraintWidth == nil else { return }
        self.translatesAutoresizingMaskIntoConstraints = false
        let constraintWidth = self.constraintWidth(0)
        self.constraintWidth = constraintWidth
        NSLayoutConstraint.activate([
            constraintWidth,
            self.constraintHeight(DPAGConstantsGlobal.kBadgeSize)
        ])
        self.layer.cornerRadius = DPAGConstantsGlobal.kBadgeSize / 2
        self.layer.masksToBounds = true
        self.isHidden = true
        self.font = UIFont.kFontBadge
        self.textAlignment = .center
    }

    override public var text: String? {
        didSet {
            if let text = self.text, text.isEmpty == false {
                let labelWidth = max(DPAGConstantsGlobal.kBadgeSize, DPAGConstantsGlobal.kBadgeSize - 5 + (DPAGConstantsGlobal.kBadgeSize / 2 * (CGFloat(text.count) - 1)))
                self.constraintWidth?.constant = labelWidth
                self.setNeedsLayout()
                if self.isHidden {
                    self.isHidden = false
                }
                self.superview?.layoutIfNeeded()
            } else {
                self.constraintWidth?.constant = 0
                self.setNeedsLayout()
                self.isHidden = true
                self.superview?.layoutIfNeeded()
            }
        }
    }
}
