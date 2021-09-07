//
//  DPAGIntroPage1ViewController.swift
//  SIMSme
//
//  Created by RBU on 01/06/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGIntroPage1ViewController: DPAGIntroPageViewController {
    @IBOutlet private var imageViewCheck0: UIImageView! {
        didSet {
            self.imageViewCheck0.image = DPAGImageProvider.shared[.kImageStar]
        }
    }

    @IBOutlet private var imageViewCheck1: UIImageView! {
        didSet {
            self.imageViewCheck1.image = DPAGImageProvider.shared[.kImageStar]
        }
    }

    @IBOutlet private var imageViewCheck2: UIImageView! {
        didSet {
            DPAGLog("didSet imageViewCheck2")
            self.imageViewCheck2.image = DPAGImageProvider.shared[.kImageStar]
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
            DPAGLog("didSet label1")
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

    @IBOutlet private var labelTitle: UILabel! {
        didSet {
            self.labelTitle.font = UIFont.kFontTitle3
            self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
            self.labelTitle.text = DPAGLocalizedString("intro.screen1.description")
        }
    }

    @IBOutlet private var scanInvitationButton: UIButton! {
        didSet {
            if DPAGApplicationFacade.preferences.isBaMandant {
                self.scanInvitationButton.isHidden = true
            } else {
                self.scanInvitationButton.accessibilityIdentifier = "btnContinue"
                self.scanInvitationButton.setTitle(DPAGLocalizedString("intro.screen1.invitationButtonTitle"), for: .normal)
                self.scanInvitationButton.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonTintNoBackground])
                self.scanInvitationButton.addTargetClosure { [weak self] _ in
                    if let nextVC = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagIntroViewController_handleScanInvitationTapped) {
                        self?.navigationController?.pushViewController(nextVC, animated: true)
                    }
                }
            }
        }
    }
    
    @IBOutlet private var btnAutomaticallyCreateDevice: UIButton! {
        didSet {
            self.btnAutomaticallyCreateDevice.accessibilityIdentifier = "btnAutomaticallyCreateDevice"
            self.btnAutomaticallyCreateDevice.setTitle("AutoCreate", for: .normal)
            self.btnAutomaticallyCreateDevice.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonDestructiveTintNoBackground])
            self.btnAutomaticallyCreateDevice.addTargetClosure { [weak self] _ in
                if AppConfig.buildConfigurationMode == .TEST {
                    self?.navigationController?.pushViewController(DPAGApplicationFacadeUIRegistration.requestAutomaticTestRegistrationVC(), animated: true)
                }
            }
            self.btnAutomaticallyCreateDevice.isHidden = true
        }
    }

    @IBOutlet private var btnCreateDevice: UIButton! {
        didSet {
            self.btnCreateDevice.accessibilityIdentifier = "btnCreateDevice"
            self.btnCreateDevice.setTitle(DPAGLocalizedString("intro.screen1.buttonCreateDeviceTitle"), for: .normal)
            self.btnCreateDevice.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonTintNoBackground])
            self.btnCreateDevice.addTargetClosure { [weak self] _ in
                self?.navigationController?.pushViewController(DPAGApplicationFacadeUIRegistration.createDeviceWelcomeVC(), animated: true)
            }
        }
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.accessibilityIdentifier = "btnContinue"
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("intro.screen1.nextButtonTitle"), for: .normal)
            self.viewButtonNext.button.addTargetClosure { [weak self] _ in
                if let nextVC = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagIntroViewController_handleFinishIntroTapped) {
                    self?.navigationController?.pushViewController(nextVC, animated: true)
                }
            }
        }
    }

    @IBOutlet private var btnCancel: UIButton! {
        didSet {
            self.btnCancel.accessibilityIdentifier = "btnCancel"
            self.btnCancel.setImage(DPAGImageProvider.shared[.kImageBarButtonNavBack]?.imageWithTintColor(DPAGColorProvider.shared[.labelText]), for: .normal)
            self.btnCancel.tintColor = DPAGColorProvider.shared[.buttonTintNoBackground]
            self.btnCancel.addTargetClosure { [weak self] _ in
                if let delegatePages = self?.delegatePages {
                    delegatePages.pageBackwards()
                } else {
                    self?.navigationController?.popViewController(animated: true)
                }
            }
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
                self.btnAutomaticallyCreateDevice.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonDestructiveTintNoBackground])
                self.btnCreateDevice.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonTintNoBackground])
                self.btnCancel.tintColor = DPAGColorProvider.shared[.buttonTintNoBackground]
                self.scanInvitationButton.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonTintNoBackground])
                self.configureLabel(self.label0)
                self.configureLabel(self.label1)
                self.configureLabel(self.label2)
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    private weak var delegatePages: DPAGPageViewControllerProtocol?

    init(delegatePages: DPAGPageViewControllerProtocol?) {
        self.delegatePages = delegatePages

        super.init(nibName: "DPAGIntroPage1ViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if AppConfig.buildConfigurationMode == .TEST {
            self.btnAutomaticallyCreateDevice.isHidden = false
        }
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        self.navigationController?.setToolbarHidden(true, animated: false)
        self.navigationItem.hidesBackButton = false
    }

    private func configureLabel(_ label: UILabel) {
        label.font = UIFont.kFontTitle3
        label.textColor = DPAGColorProvider.shared[.labelText]
        label.textAlignment = .center
    }
}
