//
//  DPAGButtons.swift
// ginlo
//
//  Created by RBU on 10/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore

class DPAGBarButton: DPAGButtonExtendedHitArea {
    let imageViewCentered = UIImageView()

    init() {
        super.init(frame: .zero)

        self.setupSubviews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupSubviews() {
        self.imageViewCentered.contentMode = .scaleAspectFit
        self.imageViewCentered.frame = self.bounds
        self.imageViewCentered.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        self.addSubview(self.imageViewCentered)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if let superview = self.superview {
            var rect = self.imageViewCentered.frame

            rect.size.height = superview.bounds.size.height
            rect.size.width = self.bounds.size.width

            self.imageViewCentered.frame = rect
            self.imageViewCentered.center = CGPoint(x: self.frame.size.width / 2, y: self.frame.size.height / 2)
        }
    }
}

class DPAGButtonServicesSettings: DPAGButtonSettings {}

class DPAGButtonChannelsSettings: DPAGButtonSettings {}

class DPAGButtonSettings: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()

        let offsetImage: CGFloat = 23
        let offsetText: CGFloat = 3

        if let imageSize = self.imageView?.image?.size {
            self.imageView?.frame = CGRect(x: floor((self.frame.size.width - imageSize.width) / 2), y: offsetImage, width: imageSize.width, height: imageSize.height)

            if let textSize = self.titleLabel?.frame.size {
                self.titleLabel?.frame = CGRect(x: 5, y: offsetImage + imageSize.height + offsetText, width: self.frame.size.width - 10, height: textSize.height)
            }
        }
    }
}

public class DPAGButtonSegmentedControlLeft: UIButton {
    override public func layoutSubviews() {
        super.layoutSubviews()

        let maskPath = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: [.bottomLeft, .topLeft], cornerRadii: CGSize(width: 4, height: 4))

        // Create the shape layer and set its path
        let maskLayer = CAShapeLayer()

        maskLayer.frame = self.bounds
        maskLayer.path = maskPath.cgPath

        // Set the newly created shape layer as the mask for the image view's layer
        self.layer.mask = maskLayer
    }

    public func configureSegControlButtonLeft() {
        self.titleLabel?.font = UIFont.kFontBody
        self.titleLabel?.adjustsFontForContentSizeCategory = true

        self.adjustsImageWhenHighlighted = true
        self.adjustsImageWhenDisabled = false
    }

    public func updateSegControlButtonLeft() {
        self.setBackgroundImage(UIImage.imageSegmentedControlLeft, for: .normal)
        self.setTitleColor(DPAGColorProvider.shared[.segmentedControlLeftContrast], for: .normal)
    }
}

public class DPAGButtonSegmentedControlRight: UIButton {
    override public func layoutSubviews() {
        super.layoutSubviews()

        let maskPath = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: [.bottomRight, .topRight], cornerRadii: CGSize(width: 4, height: 4))

        // Create the shape layer and set its path
        let maskLayer = CAShapeLayer()

        maskLayer.frame = self.bounds
        maskLayer.path = maskPath.cgPath

        // Set the newly created shape layer as the mask for the image view's layer
        self.layer.mask = maskLayer
    }

    public func configureSegControlButtonRight() {
        self.titleLabel?.font = UIFont.kFontBody
        self.titleLabel?.adjustsFontForContentSizeCategory = true

        self.adjustsImageWhenHighlighted = true
        self.adjustsImageWhenDisabled = false
    }

    public func updateSegControlButtonRight() {
        self.setBackgroundImage(UIImage.imageSegmentedControlRight, for: .normal)

        self.setTitleColor(DPAGColorProvider.shared[.segmentedControlRightContrast], for: .normal)
    }
}

open class DPAGButtonExtendedHitArea: UIButton {
    override open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let area = self.bounds.insetBy(dx: -10, dy: 0)

        return area.contains(point) ? self : super.hitTest(point, with: event)
    }

    override open func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        let area = self.bounds.insetBy(dx: -10, dy: 0)

        return area.contains(point)
    }
}
