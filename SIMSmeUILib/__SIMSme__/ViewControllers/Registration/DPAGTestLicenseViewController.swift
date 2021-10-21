//
//  DPAGTestLicenseViewController.swift
// ginlo
//
//  Created by Yves Hetzer on 19.06.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class RadialGradientLayer: CALayer {
    var center: CGPoint {
        CGPoint(x: bounds.width / 2, y: bounds.height)
    }

    var radius: CGFloat {
        let x = (bounds.width / 2)
        let y = bounds.height

        return sqrt(x * x + y * y)
    }

    var colors: [UIColor] = [UIColor.black, UIColor.lightGray] {
        didSet {
            setNeedsDisplay()
        }
    }

    var cgColors: [CGColor] {
        colors.map({ (color) -> CGColor in
            color.cgColor
        })
    }

    override init(layer _: Any) {
        super.init()
        needsDisplayOnBoundsChange = true
    }

    override init() {
        super.init()
        needsDisplayOnBoundsChange = true
    }

    required init(coder _: NSCoder) {
        super.init()
    }

    override func draw(in ctx: CGContext) {
        ctx.saveGState()
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let locations: [CGFloat] = [0.0, 1.0]
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors as CFArray, locations: locations) else {
            return
        }
        ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0.0, endCenter: center, endRadius: radius, options: CGGradientDrawingOptions(rawValue: 0))
    }
}

class RadialGradientView: UIView {
    private let gradientLayer = RadialGradientLayer()

    var colors: [UIColor] {
        get {
            gradientLayer.colors
        }
        set {
            gradientLayer.colors = newValue
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if gradientLayer.superlayer == nil {
            layer.insertSublayer(gradientLayer, at: 0)
        }
        gradientLayer.frame = bounds
    }
}

class DPAGTestLicenseViewController: DPAGViewController {
    @IBOutlet private var labelTitle: UILabel! {
        didSet {
            self.labelTitle.text = DPAGLocalizedString("batestlicense.labelTitle.test")
            self.labelTitle.numberOfLines = 0
            self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
            self.labelTitle.font = UIFont.kFontTitle1
        }
    }

    @IBOutlet private var labelDescription: UILabel! {
        didSet {
            self.labelDescription.text = DPAGLocalizedString("batestlicense.labelDescription.test")
            self.labelDescription.numberOfLines = 0
            self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDescription.font = UIFont.kFontSubheadline
        }
    }

    @IBOutlet private var labelSubTitle: UILabel! {
        didSet {
            self.labelSubTitle.text = DPAGLocalizedString("batestlicense.labelSubTitle.test")
            self.labelSubTitle.textColor = DPAGColorProvider.TestLicense.labelSubtitle
            self.labelSubTitle.font = UIFont.kFontHeadline
        }
    }

    @IBOutlet private var buttonLoginCode: UIButton! {
        didSet {
            self.buttonLoginCode.setTitle(DPAGLocalizedString("batestlicense.buttonLoginCode.label"), for: .normal)
            self.buttonLoginCode.configureButton()
            self.buttonLoginCode.accessibilityIdentifier = "buttonLoginCode"
            self.buttonLoginCode.addTarget(self, action: #selector(buttonLoginCodeAction), for: .touchUpInside)
        }
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("batestlicense.buttonTryNow.label"), for: .normal)
            self.viewButtonNext.button.accessibilityIdentifier = "buttonTryNow"
            self.viewButtonNext.button.addTarget(self, action: #selector(buttonTryNowAction), for: .touchUpInside)
        }
    }

    @IBOutlet private var imageThirty: UIImageView! {
        didSet {
            self.imageThirty.image = DPAGImageProvider.shared[.kImageThirty]
        }
    }

    @IBOutlet private var viewHeader: RadialGradientView! {
        didSet {
            self.viewHeader.colors = [DPAGColorProvider.TestLicense.gradientStart, DPAGColorProvider.TestLicense.gradientEnd]
            self.viewHeader.backgroundColor = DPAGColorProvider.TestLicense.gradientEnd
        }
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.labelSubTitle.textColor = DPAGColorProvider.TestLicense.labelSubtitle
                self.viewHeader.backgroundColor = DPAGColorProvider.TestLicense.gradientEnd
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    init() {
        super.init(nibName: "DPAGTestLicenseViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.configureGui()
    }

    private func configureGui() {
        self.title = DPAGLocalizedString("batestlicense.title.test")

        self.setRightBarButtonItemWithText(DPAGLocalizedString("navigation.done"), action: #selector(buttonTryNowAction), accessibilityLabelIdentifier: "navigation.done")
    }

    @objc
    private func buttonTryNowAction() {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in

            DPAGApplicationFacade.requestWorker.registerTestVoucher(withResponse: { responseObject, _, errorMessage in

                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

                    if let strongSelf = self {
                        if let errorMessage = errorMessage {
                            strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                        } else if let responseArray = responseObject as? [[String: Any]] {
                            if responseArray.count == 0 {
                                strongSelf.dismiss(animated: true, completion: nil)
                            } else if let responseDict = responseArray.first, let ident = responseDict["ident"] as? String, (responseDict["valid"] as? String) != nil, ident == "usage" {
                                strongSelf.dismiss(animated: true, completion: nil)
                            } else {
                                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                                    self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "Invalid response"))
                                }
                            }
                        }
                    }
                }
            })
        }
    }

    @objc
    private func buttonLoginCodeAction() {
        let vc = DPAGApplicationFacadeUIRegistration.licencesInputVC()

        self.navigationController?.pushViewController(vc, animated: true)
    }
}
