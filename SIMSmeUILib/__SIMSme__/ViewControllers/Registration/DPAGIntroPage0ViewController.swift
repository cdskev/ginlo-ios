//
//  DPAGIntroPage0ViewController.swift
//  SIMSme
//
//  Created by RBU on 01/06/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGIntroPage0ViewController: DPAGIntroPageViewController {
    @IBOutlet var imageViewDPAG: UIImageView! {
        didSet {
            self.imageViewDPAG.image = DPAGImageProvider.shared[.kImageLogoDPAG]
        }
    }

    @IBOutlet private var imageViewCheck0: UIImageView! {
        didSet {
            self.configureItemImageView(imageViewCheck0)
        }
    }

    @IBOutlet private var imageViewCheck1: UIImageView! {
        didSet {
            self.configureItemImageView(imageViewCheck1)
        }
    }

    @IBOutlet private var imageViewCheck2: UIImageView! {
        didSet {
            self.configureItemImageView(imageViewCheck2)
        }
    }

    @IBOutlet private var label0: UILabel! {
        didSet {
            self.configureLabel(self.label0)
            self.label0.text = DPAGLocalizedString("intro.screen0.description0")
        }
    }

    @IBOutlet private var label1: UILabel! {
        didSet {
            self.configureLabel(self.label1)
            self.label1.text = DPAGLocalizedString("intro.screen0.description1")
        }
    }

    @IBOutlet private var label2: UILabel! {
        didSet {
            self.configureLabel(self.label2)
            self.label2.text = DPAGLocalizedString("intro.screen0.description2")
        }
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.accessibilityIdentifier = "btnContinue"
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("intro.screen0.nextButtonTitle"), for: .normal)

            if DPAGApplicationFacade.preferences.isWhiteLabelBuild || AppConfig.multiDeviceAllowed == true {
                self.viewButtonNext.button.addTargetClosure { [weak self] _ in
                    if let delegatePages = self?.delegatePages {
                        delegatePages.pageForwards()
                    } else {
                        self?.navigationController?.pushViewController(DPAGIntroPage1ViewController(delegatePages: self?.delegatePages), animated: true)
                    }
                }
            } else {
                self.viewButtonNext.button.addTargetClosure { [weak self] _ in
                    if let nextVC = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagIntroViewController_handleFinishIntroTapped) {
                        self?.navigationController?.pushViewController(nextVC, animated: true)
                    }
                }
            }
        }
    }

    private weak var delegatePages: DPAGPageViewControllerProtocol?

    init(delegatePages: DPAGPageViewControllerProtocol?) {
        self.delegatePages = delegatePages

        super.init(nibName: "DPAGIntroPage0ViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.isNavigationBarHidden = true
    }

    private func configureLabel(_ label: UILabel) {
        label.font = UIFont.kFontTitle3
        label.textColor = DPAGColorProvider.shared[.labelText]
        label.textAlignment = .center
    }

    private func configureItemImageView(_ imageView: UIImageView) {
        imageView.image = DPAGImageProvider.shared[.kImageStar]
        imageView.tintColor = DPAGColorProvider.shared[.introBulletItem]
    }
    
    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.configureLabel(self.label0)
                self.configureLabel(self.label1)
                self.configureLabel(self.label2)
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
