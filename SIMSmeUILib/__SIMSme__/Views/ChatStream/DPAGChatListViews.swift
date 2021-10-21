//
//  DPAGChatListViews.swift
// ginlo
//
//  Created by RBU on 16/03/2017.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGChatListBannerViewDelegate: AnyObject {
    func bannerSelected()
    func bannerCancelled(animated: Bool)
}

public protocol DPAGChatListBannerViewProtocol: AnyObject {
    var delegate: DPAGChatListBannerViewDelegate? { get set }
    var bannerType: DPAGBannerType { get }
}

class DPAGChatListBannerView: UIView, DPAGChatListBannerViewProtocol {
    fileprivate let stackView = UIStackView()
    fileprivate let buttonCancel = UIButton()
    fileprivate(set) var bannerType: DPAGBannerType = .unknown
    fileprivate var identifierBanner = "noIdent"
    weak var delegate: DPAGChatListBannerViewDelegate?

    init() {
        super.init(frame: .zero)
        self.configure()
        self.configureLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func configure() {
        self.buttonCancel.setTitle(nil, for: .normal)
        self.buttonCancel.setImage(DPAGImageProvider.shared[.kImageClose], for: .normal)
        self.buttonCancel.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        self.buttonCancel.accessibilityIdentifier = "Service.Banner.Cancel"
        self.accessibilityIdentifier = "Service.Banner.View"
        self.backgroundColor = .clear
        let tapGr = UITapGestureRecognizer(target: self, action: #selector(handleSelected))
        self.addGestureRecognizer(tapGr)
    }

    fileprivate func configureLayout() {
        self.stackView.translatesAutoresizingMaskIntoConstraints = false
        self.stackView.alignment = .fill
        self.stackView.axis = .horizontal
        self.stackView.distribution = .fill
        self.stackView.spacing = 26
        self.addSubview(self.stackView)
        self.stackView.addArrangedSubview(self.buttonCancel)
        NSLayoutConstraint.activate([
            self.constraintLeading(subview: self.stackView, padding: 26),
            self.constraintTrailing(subview: self.stackView, padding: 15),
            self.constraintTop(subview: self.stackView, padding: 8),
            self.constraintBottom(subview: self.stackView, padding: 8),
            self.buttonCancel.constraintWidth(28)
        ])
    }

    @objc
    private func handleSelected() {
        self.delegate?.bannerSelected()
    }

    @objc
    private func handleCancel() {
        self.delegate?.bannerCancelled(animated: true)
    }
}

public protocol DPAGChatListTestVoucherInfoViewProtocol: DPAGChatListBannerViewProtocol {
    func updateText(daysLeft: Int)
}

class DPAGChatListTestVoucherInfoView: DPAGChatListBannerView, DPAGChatListTestVoucherInfoViewProtocol {
    private var labelDays = UILabel()
    private var labelCode = UILabel()
    private var stackViewLabels = UIStackView()

    override func configure() {
        super.configure()
        self.bannerType = .business
        self.labelDays.font = UIFont.kFontSubheadline
        self.labelCode.font = UIFont.kFontHeadline
        self.labelDays.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
        self.labelCode.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
        self.labelDays.numberOfLines = 0
        self.labelCode.numberOfLines = 0
        self.labelDays.text = String(format: DPAGLocalizedString("batestlicense.testvoucherinfo.label"), "30")
        self.labelCode.text = DPAGLocalizedString("batestlicense.testvoucherinfo.labelCode")
        self.identifierBanner = "testVoucher"
        self.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
        self.buttonCancel.tintColor = DPAGColorProvider.shared[.alertDestructiveTint]
    }

    override func configureLayout() {
        super.configureLayout()
        self.stackViewLabels.alignment = .fill
        self.stackViewLabels.axis = .vertical
        self.stackViewLabels.distribution = .fill
        self.stackViewLabels.spacing = 0
        self.stackViewLabels.addArrangedSubview(self.labelDays)
        self.stackViewLabels.addArrangedSubview(self.labelCode)
        self.stackView.addArrangedSubview(self.stackViewLabels)
    }

    func updateText(daysLeft: Int) {
        self.labelDays.text = String(format: DPAGLocalizedString("batestlicense.testvoucherinfo.label"), String(daysLeft))
    }
    
    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                self.labelDays.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
                self.labelCode.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
                self.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
                self.buttonCancel.tintColor = DPAGColorProvider.shared[.alertDestructiveTint]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
