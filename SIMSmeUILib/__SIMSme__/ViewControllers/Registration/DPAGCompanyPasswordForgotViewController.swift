//
//  DPAGCompanyPasswordForgotViewController.swift
//  SIMSme
//
//  Created by Yves Hetzer on 08.06.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGCompanyPasswordForgotViewController: DPAGViewControllerBackground {
    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("companyregistration.buttonNextLabel.forgotPassword"), for: .normal)
            self.viewButtonNext.button.addTarget(self, action: #selector(buttonNextAction), for: .touchUpInside)
        }
    }

    @IBOutlet private var labelTitle: UILabel! {
        didSet {
            self.labelTitle.text = DPAGLocalizedString("companyregistration.labelTitle.forgotPassword")
            self.labelTitle.numberOfLines = 0
            self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
            self.labelTitle.font = UIFont.kFontTitle1
        }
    }

    @IBOutlet private var labelDescription1: UILabel! {
        didSet {
            self.labelDescription1.text = DPAGLocalizedString("companyregistration.labelDescription1.forgotPassword")
            self.labelDescription1.numberOfLines = 0
            self.labelDescription1.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDescription1.font = UIFont.kFontSubheadline
        }
    }

    @IBOutlet private var labelDescription2: UILabel! {
        didSet {
            self.labelDescription2.text = DPAGLocalizedString("companyregistration.labelDescription2.forgotPassword")
            self.labelDescription2.numberOfLines = 0
            self.labelDescription2.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDescription2.font = UIFont.kFontFootnote
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDescription1.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDescription2.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var imageViewRecovery: UIImageView! {
        didSet {
            self.imageViewRecovery.image = DPAGImageProvider.shared[.kImageRecoveryBusiness]
        }
    }

    init() {
        super.init(nibName: "DPAGCompanyPasswordForgotViewController", bundle: Bundle(for: type(of: self)))
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
        self.title = DPAGLocalizedString("companyregistration.title.forgotPassword")

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(buttonCancelAction))
    }

    @objc
    private func buttonNextAction() {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in

            DPAGApplicationFacade.companyAdressbook.requestCompanyRecoveryKey { [weak self] _, _, errorMessage in

                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

                    if let errorMessage = errorMessage {
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                    } else {
                        let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in

                            let vc = DPAGApplicationFacadeUIRegistration.companyEnterRecoveryKeyVC()

                            self?.navigationController?.pushViewController(vc, animated: true)
                        })

                        self?.presentAlert(alertConfig: AlertConfig(titleIdentifier: "business.alert.accountManagement.companyRecoveryKeyRequested.title", messageIdentifier: "business.alert.accountManagement.companyRecoveryKeyRequested.message", otherButtonActions: [actionOK]))
                    }
                }
            }
        }
    }

    @objc
    private func buttonCancelAction() {
        self.dismiss(animated: true, completion: nil)
    }
}
