//
//  LogoView.swift
//  SIMSmeUIViewsLib
//
//  Created by Evgenii Kononenko on 20.05.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

private let kLogoViewRatioWidthToScreenWidth: CGFloat = 854.0 / 1_242.0
private let kLogoViewTop: CGFloat = 88.0

public class LogoViewConstantTopConstraint: NSLayoutConstraint {
    override public var constant: CGFloat {
        get {
            kLogoViewTop
        }
        set {
            super.constant = newValue
        }
    }

    static func topConstraint(forSuperView superView: UIView, subView: UIView) -> LogoViewConstantTopConstraint {
        LogoViewConstantTopConstraint(item: subView, attribute: .top, relatedBy: .equal, toItem: superView, attribute: .top, multiplier: 1, constant: 0)
    }
}

public class LogoView: UIView, NibFileOwnerLoadable {
    @IBOutlet var imageView: UIImageView!
    private var ratioHeightToWidth: CGFloat = 0.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }

    // MARK: - Private

    private func setup() {
        self.loadNibContent()
        self.translatesAutoresizingMaskIntoConstraints = false
        self.imageView.image = DPAGImageProvider.shared[.kImageLaunchLogo]
        if let imageSize = self.imageView.image?.size {
            self.ratioHeightToWidth = imageSize.height / imageSize.width
        }
    }

    // MARK: - Override

    override public var intrinsicContentSize: CGSize {
        let width = UIScreen.main.bounds.size.width * kLogoViewRatioWidthToScreenWidth
        let height = width * self.ratioHeightToWidth
        return CGSize(width: width, height: height)
    }

    // MARK: - Public

    public func setDefaultPositionToSuperView() {
        guard let superView = self.superview else {
            return
        }

        let constraints = LogoView.logoViewConstraints(superView: superView, logoView: self)
        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Static

    static func logoViewConstraints(superView: UIView, logoView: UIView) -> [NSLayoutConstraint] {
        [
            LogoViewConstantTopConstraint.topConstraint(forSuperView: superView, subView: logoView),
            superView.constraintCenterX(subview: logoView)
        ]
    }
}
