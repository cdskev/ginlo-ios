//
//  DPAGCreateDeviceWaitForConfirmationViewController.swift
// ginlo
//
//  Created by RBU on 24.11.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGCreateDeviceWaitForConfirmationViewController: DPAGViewControllerBackground {
    private var loadTimer: Date?

    @IBOutlet private var stackViewAll: UIStackView!
    @IBOutlet private var scrollView: UIScrollView!

    @IBOutlet private var stackViewWaiting: UIStackView!
    @IBOutlet private var labelDescription: UILabel! {
        didSet {
            self.labelDescription.text = DPAGLocalizedString("registration.createDeviceWaitForConfirmation.description")
            self.labelDescription.font = UIFont.kFontSubheadline
            self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDescription.numberOfLines = 0
        }
    }

    @IBOutlet private var activityIndicator: UIActivityIndicatorView!

    @IBOutlet private var buttonCancel: UIButton! {
        didSet {
            self.buttonCancel.accessibilityIdentifier = "buttonCancel"
            self.buttonCancel.configureButton()
            self.buttonCancel.setTitle(DPAGLocalizedString("res.cancel"), for: .normal)
            self.buttonCancel.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        }
    }

    @IBOutlet private var labelConfirmCode0: UILabel!
    { didSet { self.setupLabelConfirmCode(self.labelConfirmCode0) } }
    @IBOutlet private var labelConfirmCode1: UILabel!
    { didSet { self.setupLabelConfirmCode(self.labelConfirmCode1) } }
    @IBOutlet private var labelConfirmCode2: UILabel!
    { didSet { self.setupLabelConfirmCode(self.labelConfirmCode2) } }
    @IBOutlet private var labelConfirmCode3: UILabel!
    { didSet { self.setupLabelConfirmCode(self.labelConfirmCode3) } }
    @IBOutlet private var labelConfirmCode4: UILabel!
    { didSet { self.setupLabelConfirmCode(self.labelConfirmCode4) } }
    @IBOutlet private var labelConfirmCode5: UILabel!
    { didSet { self.setupLabelConfirmCode(self.labelConfirmCode5) } }
    @IBOutlet private var labelConfirmCode6: UILabel!
    { didSet { self.setupLabelConfirmCode(self.labelConfirmCode6) } }
    @IBOutlet private var labelConfirmCode7: UILabel!
    { didSet { self.setupLabelConfirmCode(self.labelConfirmCode7) } }
    @IBOutlet private var labelConfirmCode8: UILabel!
    { didSet { self.setupLabelConfirmCode(self.labelConfirmCode8) } }
    @IBOutlet private var labelConfirmCode9: UILabel!
    { didSet { self.setupLabelConfirmCode(self.labelConfirmCode9) } }
    @IBOutlet private var labelConfirmCode10: UILabel!
    { didSet { self.setupLabelConfirmCode(self.labelConfirmCode10) } }
    @IBOutlet private var labelConfirmCode11: UILabel!
    { didSet { self.setupLabelConfirmCode(self.labelConfirmCode11) } }
    @IBOutlet private var labelConfirmCode12: UILabel!
    { didSet { self.setupLabelConfirmCode(self.labelConfirmCode12) } }
    @IBOutlet private var labelConfirmCode13: UILabel!
    { didSet { self.setupLabelConfirmCode(self.labelConfirmCode13) } }
    @IBOutlet private var labelConfirmCode14: UILabel!
    { didSet { self.setupLabelConfirmCode(self.labelConfirmCode14) } }
    @IBOutlet private var labelConfirmCode15: UILabel!
    { didSet { self.setupLabelConfirmCode(self.labelConfirmCode15) } }

    @IBOutlet private var labelWaiting: UILabel! {
        didSet {
            self.labelWaiting.text = DPAGLocalizedString("registration.createDeviceWaitForConfirmation.waiting")
            self.labelWaiting.font = UIFont.kFontHeadline
            self.labelWaiting.textColor = DPAGColorProvider.shared[.labelText]
            self.labelWaiting.numberOfLines = 0
            self.labelWaiting.textAlignment = .center
        }
    }

    init() {
        super.init(nibName: "DPAGCreateDeviceWaitForConfirmationViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.labelWaiting.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.title = DPAGLocalizedString("registration.createDeviceWaitForConfirmation.title")

        self.activityIndicator.startAnimating()

        if let publicKey = CryptoHelper.sharedInstance?.publicKey?.sha256().uppercased() {
            let labels: [UILabel] = [
                self.labelConfirmCode0,
                self.labelConfirmCode1,
                self.labelConfirmCode2,
                self.labelConfirmCode3,
                self.labelConfirmCode4,
                self.labelConfirmCode5,
                self.labelConfirmCode6,
                self.labelConfirmCode7,
                self.labelConfirmCode8,
                self.labelConfirmCode9,
                self.labelConfirmCode10,
                self.labelConfirmCode11,
                self.labelConfirmCode12,
                self.labelConfirmCode13,
                self.labelConfirmCode14,
                self.labelConfirmCode15
            ]

            let publicKeySplitted = publicKey.components(withLength: 4)

            for (idx, splitItem) in publicKeySplitted.enumerated() {
                if idx < labels.count {
                    labels[idx].text = splitItem
                } else {
                    break
                }
            }
        }

        self.getCouplingResponse()

        self.loadTimer = Date()
    }

    private func setupLabelConfirmCode(_ label: UILabel) {
        label.text = "0000"
        label.font = UIFont.kFontCodePublicKey
        label.textColor = DPAGColorProvider.shared[.labelText]
        label.numberOfLines = 1
        label.textAlignment = .center
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
    }

    private func getCouplingResponse() {
        self.performBlockInBackground { [weak self] in
            do {
                _ = try DPAGApplicationFacade.couplingWorker.getCouplingResponse()
            } catch {
                if (error as NSError).domain == "NO_ERROR" || (error as NSError).domain == "NETWORK_ERROR" {
                    // 5 Minuten abgelaufen ?
                    let elapsed = (self?.loadTimer?.timeIntervalSinceNow ?? 0) * -1
                    if elapsed < 5 * 60 {
                        self?.getCouplingResponse()
                        return
                    }
                }
                let errorDesc = error.localizedDescription
                self?.performBlockOnMainThread { [weak self] in
                    self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorDesc))
                }
                return
            }

            defer {
                AppConfig.setIdleTimerDisabled(false)
            }

            do {
                self?.performBlockOnMainThread {
                    self?.labelWaiting.text = DPAGLocalizedString("registration.createDeviceWaitForConfirmation.success")
                    self?.buttonCancel.isEnabled = false
                }
                AppConfig.setIdleTimerDisabled(true)
                DPAGApplicationFacade.preferences.migrationVersion = .versionCurrent
                DPAGApplicationFacade.preferences[.kNotificationNicknameEnabled] = DPAGPreferences.kValueNotificationEnabled
                _ = try DPAGApplicationFacade.couplingWorker.createDevice()
                DPAGApplicationFacade.preferences.didSetDeviceName = true
                DPAGApplicationFacade.preferences.createSimsmeRecoveryInfos()
                self?.performBlockOnMainThread { [weak self] in
                    if let controllers = self?.navigationController?.viewControllers, controllers.count > 1 {
                        for controller in controllers {
                            if let requestAccountViewController = controller as? DPAGRequestAccountViewControllerProtocol {
                                requestAccountViewController.resetPassword()
                                break
                            }
                        }
                    }
                    NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_COMPLETE_LOGIN, object: nil)
                    self?.dismiss(animated: false, completion: nil)
                }
            } catch {
                let errorDesc = error.localizedDescription
                self?.performBlockOnMainThread { [weak self] in
                    self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorDesc))
                }
            }
        }
    }

    @IBAction private func handleCancel(_: Any) {
        self.navigationController?.popViewController(animated: true)
    }
}
