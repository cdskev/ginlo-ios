//
//  DPAGLicenceItemView.swift
//  SIMSmeUILib
//
//  Created by RBU on 23.05.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import StoreKit
import UIKit

public class DPAGLicence {
    public init() {}

    // Die Guid in der Datenbank
    public var guid: String?

    // die Apple Product ID
    public var productId: String?

    // das Feature
    public var feature: String?

    // Die Dauer
    public var duration: NSNumber?

    // Das Apple Product
    public var appleProduct: SKProduct?

    public var label: String?
    public var description: String?
}

public protocol DPAGLicenceItemViewDelegate: AnyObject {
    func handlePurchase(licence: DPAGLicence?)
}

public protocol DPAGLicenceItemViewProtocol: AnyObject {
    var purchaseDelegate: DPAGLicenceItemViewDelegate? { get set }

    var licence: DPAGLicence? { get set }
}

class DPAGLicenceItemView: UIView, DPAGLicenceItemViewProtocol {
    @IBOutlet private var label: UILabel! {
        didSet {
            self.label.textColor = DPAGColorProvider.shared[.buttonTint]
            self.label.font = UIFont.kFontHeadline
            self.label.adjustsFontSizeToFitWidth = true
        }
    }

    @IBOutlet private var labelValue: UILabel! {
        didSet {
            self.labelValue.textColor = DPAGColorProvider.shared[.buttonTint]
            self.labelValue.font = UIFont.kFontBody
        }
    }

    @IBOutlet private var labelValueInfo: UILabel! {
        didSet {
            self.labelValueInfo.textColor = DPAGColorProvider.shared[.buttonTint]
            self.labelValueInfo.font = UIFont.kFontFootnote
            self.labelValueInfo.adjustsFontSizeToFitWidth = true
        }
    }

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter
    }()

    weak var purchaseDelegate: DPAGLicenceItemViewDelegate?

    var licence: DPAGLicence? {
        didSet {
            guard let licence = self.licence else {
                return
            }
            self.label.text = licence.label
            if licence.appleProduct != nil {
                DPAGLicenceItemView.currencyFormatter.locale = licence.appleProduct?.priceLocale
                self.labelValue.text = DPAGLicenceItemView.currencyFormatter.string(from: licence.appleProduct?.price ?? NSNumber(value: 0))
                self.labelValueInfo.text = licence.description
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
        self.layer.cornerRadius = 5
        self.layer.masksToBounds = true
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handlePurchase)))
    }

    @objc
    private func handlePurchase() {
        self.purchaseDelegate?.handlePurchase(licence: self.licence)
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.label.textColor = DPAGColorProvider.shared[.buttonTint]
                self.labelValue.textColor = DPAGColorProvider.shared[.buttonTint]
                self.labelValueInfo.textColor = DPAGColorProvider.shared[.buttonTint]
                self.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
