//
//  DPAGPasswordForgotViewController.swift
// ginlo
//
//  Created by RBU on 15.01.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGPasswordForgotViewController: DPAGViewControllerBackground {
    @IBOutlet private var labelTitle: UILabel! {
        didSet {
            self.labelTitle.text = DPAGLocalizedString("forgotPassword.labelTitle")
            self.labelTitle.numberOfLines = 0
            self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
            self.labelTitle.font = UIFont.kFontTitle1
        }
    }

    @IBOutlet private var labelDescription: UILabel! {
        didSet {
            self.labelDescription.text = DPAGLocalizedString("forgotPassword.labelDescription")
            self.labelDescription.numberOfLines = 0
            self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDescription.font = UIFont.kFontSubheadline
        }
    }

    @IBOutlet private var viewRecoveryMail: UIView!
    @IBOutlet private var buttonRecoveryMail: UIButton! {
        didSet {
            self.buttonRecoveryMail.setImage(DPAGImageProvider.shared[.kImageRecoveryMail], for: .normal)
        }
    }

    @IBOutlet private var imageViewCheckMail: UIImageView! {
        didSet {
            self.imageViewCheckMail.configureCheck()
            self.imageViewCheckMail.isHidden = true
        }
    }

    @IBOutlet private var labelRecoveryMail: UILabel! {
        didSet {
            self.labelRecoveryMail.text = DPAGLocalizedString("forgotPassword.labelEMail")
            self.labelRecoveryMail.textAlignment = .center
            self.labelRecoveryMail.textColor = DPAGColorProvider.shared[.labelText]
            self.labelRecoveryMail.font = UIFont.kFontFootnote
        }
    }

    @IBOutlet private var viewRecoverySMS: UIView!
    @IBOutlet private var buttonRecoverySMS: UIButton! {
        didSet {
            self.buttonRecoverySMS.setImage(DPAGImageProvider.shared[.kImageRecoverySMS], for: .normal)
        }
    }

    @IBOutlet private var imageViewCheckSMS: UIImageView! {
        didSet {
            self.imageViewCheckSMS.configureCheck()
            self.imageViewCheckSMS.isHidden = true
        }
    }

    @IBOutlet private var labelRecoverySMS: UILabel! {
        didSet {
            self.labelRecoverySMS.text = DPAGLocalizedString("forgotPassword.labelSMS")
            self.labelRecoverySMS.textAlignment = .center
            self.labelRecoverySMS.textColor = DPAGColorProvider.shared[.labelText]
            self.labelRecoverySMS.font = UIFont.kFontFootnote
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.labelRecoveryMail.textColor = DPAGColorProvider.shared[.labelText]
                self.labelRecoverySMS.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("forgotPassword.buttonRequestRecoveryCode"), for: .normal)
            self.viewButtonNext.button.addTarget(self, action: #selector(handleRequestRecoveryCode(_:)), for: .touchUpInside)
        }
    }

    init() {
        super.init(nibName: "DPAGPasswordForgotViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.title = DPAGLocalizedString("forgotPassword.title")

        if DPAGApplicationFacade.preferences.hasSimsmeRecoveryEnabledMail == false {
            self.viewRecoveryMail.isHidden = true
            self.labelRecoveryMail.isHidden = true
            self.imageViewCheckSMS.isHidden = false
            self.labelRecoverySMS.isHidden = false
        }
        if DPAGApplicationFacade.preferences.hasSimsmeRecoveryEnabledSMS == false {
            self.viewRecoverySMS.isHidden = true
            self.labelRecoverySMS.isHidden = true
            self.imageViewCheckMail.isHidden = false
            self.labelRecoveryMail.isHidden = false
        }

        self.checkButtonState()

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(handleCancel))
    }

    private func checkButtonState() {
        self.viewButtonNext.isEnabled = (self.imageViewCheckSMS.isHidden == false || self.imageViewCheckMail.isHidden == false)
    }

    @IBAction private func handleCheckMail(_: Any) {
        self.imageViewCheckMail.isHidden = false
        self.imageViewCheckSMS.isHidden = true
        self.checkButtonState()
    }

    @IBAction private func handleCheckSMS(_: Any) {
        self.imageViewCheckMail.isHidden = true
        self.imageViewCheckSMS.isHidden = false
        self.checkButtonState()
    }

    @objc
    private func handleCancel() {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction private func handleRequestRecoveryCode(_: Any) {
        let requestMail = self.imageViewCheckMail.isHidden == false

        guard let parameter = DPAGApplicationFacade.preferences.getSimsmeRecoveryData(email: requestMail) else {
            return
        }

        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in

            DPAGApplicationFacade.requestWorker.requestSimsmeRecoveryKey(parameter: parameter) { _, _, _ in
                // TODO: check error
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    let nextVC = DPAGApplicationFacadeUIBase.passwordForgotRecoveryVC()

                    self?.navigationController?.pushViewController(nextVC, animated: true)
                }
            }
        }
    }
}
