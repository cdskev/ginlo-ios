//
//  DPAGAddDeviceViewController.swift
//  SIMSme
//
//  Created by RBU on 25.11.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit
import ZXingObjC

class DPAGAddDeviceViewController: DPAGViewControllerWithKeyboard {
    private static let nf: NumberFormatter = {
        let nf = NumberFormatter()

        nf.numberStyle = .decimal
        nf.minimumIntegerDigits = 2

        return nf
    }()

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var stackViewAll: UIStackView!

    @IBOutlet private var viewCode: UIView!
    @IBOutlet private var viewCodeCountDown: UIView! {
        didSet {
            self.viewCodeCountDown.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
        }
    }

    @IBOutlet private var labelCodeCountDown: UILabel! {
        didSet {
            self.labelCodeCountDown.text = DPAGLocalizedString("registration.addDevice.labelCodeCountDown")
            self.labelCodeCountDown.font = UIFont.kFontSubheadline
            self.labelCodeCountDown.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
            self.labelCodeCountDown.textAlignment = .center
            self.labelCodeCountDown.numberOfLines = 0
        }
    }

    @IBOutlet private var stackViewCode: UIStackView!
    @IBOutlet private var labelCodeDescription: UILabel! {
        didSet {
            self.labelCodeDescription.text = DPAGLocalizedString("registration.addDevice.labelCodeDescription")
            self.labelCodeDescription.font = UIFont.kFontSubheadline
            self.labelCodeDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.labelCodeDescription.numberOfLines = 0
        }
    }

    @IBOutlet private var imageViewCode: UIImageView!
    @IBOutlet private var viewCodeExpired: UIView! {
        didSet {
            self.viewCodeExpired.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
            self.viewCodeExpired.isHidden = true
        }
    }

    @IBOutlet private var labelCodeExpired: UILabel! {
        didSet {
            self.labelCodeExpired.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
            self.labelCodeExpired.font = UIFont.kFontTitle3
            self.labelCodeExpired.text = DPAGLocalizedString("registration.addDevice.labelCodeExpired")
            self.labelCodeExpired.textAlignment = .center
            self.labelCodeExpired.adjustsFontSizeToFitWidth = true
            self.labelCodeExpired.numberOfLines = 0
        }
    }
    
    @IBOutlet private var textFieldCode0: UITextField! {
        didSet {
            self.textFieldCode0.accessibilityIdentifier = "textFieldCode0"
            self.configureTextField(self.textFieldCode0)
        }
    }

    @IBOutlet private var textFieldCode1: UITextField! {
        didSet {
            self.textFieldCode1.accessibilityIdentifier = "textFieldCode1"
            self.configureTextField(self.textFieldCode1)
        }
    }

    @IBOutlet private var textFieldCode2: UITextField! {
        didSet {
            self.textFieldCode2.accessibilityIdentifier = "textFieldCode2"
            self.configureTextField(self.textFieldCode2)
        }
    }

    @IBOutlet private var buttonCodeCancel: UIButton! {
        didSet {
            self.buttonCodeCancel.accessibilityIdentifier = "buttonConfirmCancel"
            self.buttonCodeCancel.configureButton()
            self.buttonCodeCancel.setTitle(DPAGLocalizedString("res.cancel"), for: .normal)
            self.buttonCodeCancel.addTarget(self, action: #selector(handleCodeCancel), for: .touchUpInside)
        }
    }

    @IBOutlet private var viewConfirm: UIView!
    @IBOutlet private var stackViewConfirm: UIStackView!
    @IBOutlet private var labelConfirmDescription: UILabel! {
        didSet {
            self.labelConfirmDescription.text = DPAGLocalizedString("registration.addDevice.labelConfirmDescription")
            self.labelConfirmDescription.font = UIFont.kFontSubheadline
            self.labelConfirmDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.labelConfirmDescription.numberOfLines = 0
        }
    }

    @IBOutlet private var imageViewConfirmNewDevice: UIImageView! {
        didSet {
            self.imageViewConfirmNewDevice.tintColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelConfirmNewDevice: UILabel! {
        didSet {
            self.labelConfirmNewDevice.text = ""
            self.labelConfirmNewDevice.font = UIFont.kFontCalloutBold
            self.labelConfirmNewDevice.textColor = DPAGColorProvider.shared[.labelText]
            self.labelConfirmNewDevice.textAlignment = .center
            self.labelConfirmNewDevice.numberOfLines = 0
        }
    }

    @IBOutlet private var labelConfirmNewDeviceType: UILabel! {
        didSet {
            self.labelConfirmNewDeviceType.text = ""
            self.labelConfirmNewDeviceType.font = UIFont.kFontSubheadline
            self.labelConfirmNewDeviceType.textColor = DPAGColorProvider.shared[.labelText]
            self.labelConfirmNewDeviceType.textAlignment = .center
            self.labelConfirmNewDeviceType.numberOfLines = 0
        }
    }

    @IBOutlet private var labelConfirmNewDeviceTypeDescription: UILabel! {
        didSet {
            self.labelConfirmNewDeviceTypeDescription.text = ""
            self.labelConfirmNewDeviceTypeDescription.font = UIFont.kFontSubheadline
            self.labelConfirmNewDeviceTypeDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.labelConfirmNewDeviceTypeDescription.textAlignment = .center
            self.labelConfirmNewDeviceTypeDescription.numberOfLines = 0
        }
    }

    @IBOutlet private var stackViewConfirmCodes: UIStackView!
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

    @IBOutlet private var stackViewButtons: UIStackView!
    @IBOutlet private var buttonConfirmCancel: UIButton! {
        didSet {
            self.buttonConfirmCancel.accessibilityIdentifier = "buttonConfirmCancel"
            self.buttonConfirmCancel.configureButton()
            self.buttonConfirmCancel.setTitle(DPAGLocalizedString("res.cancel"), for: .normal)
            self.buttonConfirmCancel.addTarget(self, action: #selector(handleConfirmCancel), for: .touchUpInside)
        }
    }

    @IBOutlet private var buttonConfirmContinue: UIButton! {
        didSet {
            self.buttonConfirmContinue.accessibilityIdentifier = "buttonConfirmContinue"
            self.buttonConfirmContinue.configurePrimaryButton()
            self.buttonConfirmContinue.setTitle(DPAGLocalizedString("registration.addDevice.buttonConfirmContinue.title"), for: .normal)
            self.buttonConfirmContinue.addTarget(self, action: #selector(handleConfirmContinue), for: .touchUpInside)
        }
    }

    @IBOutlet private var viewSync: UIView!
    @IBOutlet private var stackViewSync: UIStackView!
    @IBOutlet private var labelSyncDescription: UILabel! {
        didSet {
            self.labelSyncDescription.text = DPAGLocalizedString("registration.addDevice.labelSyncDescription")
            self.labelSyncDescription.font = UIFont.kFontHeadline
            self.labelSyncDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.labelSyncDescription.numberOfLines = 0
        }
    }

    @IBOutlet private var imageViewSyncNewDevice: UIImageView! {
        didSet {
            self.imageViewSyncNewDevice.tintColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelSyncNewDevice: UILabel! {
        didSet {
            self.labelSyncNewDevice.text = "DeviceName"
            self.labelSyncNewDevice.font = UIFont.kFontHeadline
            self.labelSyncNewDevice.textColor = DPAGColorProvider.shared[.labelText]
            self.labelSyncNewDevice.numberOfLines = 0
            self.labelSyncNewDevice.textAlignment = .center
        }
    }

    @IBOutlet private var labelSyncNewDeviceType: UILabel! {
        didSet {
            self.labelSyncNewDeviceType.text = ""
            self.labelSyncNewDeviceType.font = UIFont.kFontSubheadline
            self.labelSyncNewDeviceType.textColor = DPAGColorProvider.shared[.labelText]
            self.labelSyncNewDeviceType.textAlignment = .center
            self.labelSyncNewDeviceType.numberOfLines = 0
        }
    }

    @IBOutlet private var labelSyncNewDeviceTypeDescription: UILabel! {
        didSet {
            self.labelSyncNewDeviceTypeDescription.text = ""
            self.labelSyncNewDeviceTypeDescription.font = UIFont.kFontSubheadline
            self.labelSyncNewDeviceTypeDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.labelSyncNewDeviceTypeDescription.textAlignment = .center
            self.labelSyncNewDeviceTypeDescription.numberOfLines = 0
        }
    }

    @IBOutlet private var imageViewSync: UIImageView! {
        didSet {
            self.imageViewSync.configureCheck()
        }
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.viewCodeCountDown.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
                self.labelCodeCountDown.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
                self.labelCodeDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.viewCodeExpired.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
                self.labelCodeExpired.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
                self.labelConfirmDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.imageViewConfirmNewDevice.tintColor = DPAGColorProvider.shared[.labelText]
                self.labelConfirmNewDevice.textColor = DPAGColorProvider.shared[.labelText]
                self.labelConfirmNewDeviceTypeDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.labelSyncDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.imageViewSyncNewDevice.tintColor = DPAGColorProvider.shared[.labelText]
                self.labelSyncNewDevice.textColor = DPAGColorProvider.shared[.labelText]
                self.labelSyncNewDeviceType.textColor = DPAGColorProvider.shared[.labelText]
                self.labelSyncNewDeviceTypeDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.viewPrimaryButtonsInverted?.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var buttonSyncClose: UIButton! {
        didSet {
            self.buttonSyncClose.accessibilityIdentifier = "buttonSyncClose"
            self.buttonSyncClose.configurePrimaryButton()
            self.buttonSyncClose.setTitle(DPAGLocalizedString("res.close"), for: .normal)
            self.buttonSyncClose.addTarget(self, action: #selector(handleSyncClose), for: .touchUpInside)
        }
    }

    @IBOutlet private var viewPrimaryButtonsInverted: UIView? {
        didSet {
            self.viewPrimaryButtonsInverted?.backgroundColor = .clear
        }
    }

    private var dateCouplingStarted: Date = Date()
    private var timerTAN: Timer?

    init() {
        super.init(nibName: "DPAGAddDeviceViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.viewConfirm.isHidden = true
        self.viewSync.isHidden = true

        self.buttonConfirmCancel.isHidden = true
        self.buttonConfirmContinue.isHidden = true
        self.buttonSyncClose.isHidden = true

        self.title = DPAGLocalizedString("registration.addDevice.titleCode")

        let sizeQR = self.imageViewCode.frame.size

        self.performBlockInBackground { [weak self] in
            self?.initCoupling(forSizeQR: sizeQR)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.updateTimerLabel()
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)

        self.timerTAN?.invalidate()
        self.timerTAN = nil
    }

    private func configureTextField(_ textField: UITextField) {
        textField.configureDefault()
        textField.backgroundColor = UIColor.clear
        textField.font = UIFont.kFontCodeInputQR
        textField.isEnabled = false
        textField.textAlignment = .center
        textField.setPaddingLeftTo(0)
    }

    @objc
    private func updateTimerLabel() {
        let timeLeft = 300 - Date().timeIntervalSince(self.dateCouplingStarted)

        let secondsLeftAll = Int(round(timeLeft))
        let minutesLeft = max(secondsLeftAll / 60, 0)
        let secondsLeft = max(secondsLeftAll % 60, 0)

        let minutesStr = (DPAGAddDeviceViewController.nf.string(from: NSNumber(value: minutesLeft)) ?? "00")
        let secondsStr = (DPAGAddDeviceViewController.nf.string(from: NSNumber(value: secondsLeft)) ?? "00")

        self.labelCodeCountDown.text = String(format: DPAGLocalizedString("registration.addDevice.labelCodeCountDown"), minutesStr + ":" + secondsStr)

        if secondsLeftAll <= 0 {
            self.timerTAN?.invalidate()
            self.timerTAN = nil

            self.viewCodeExpired.isHidden = false
        }
    }

    private func setupLabelConfirmCode(_ label: UILabel) {
        label.text = "0000"
        label.font = UIFont.kFontCodePublicKey
        label.textColor = DPAGColorProvider.shared[.labelText]
        label.numberOfLines = 1
        label.textAlignment = .center
    }

    private func initTimerTAN() {
        let timerTAN = Timer.scheduledTimer(withTimeInterval: TimeInterval(1), repeats: true) { [weak self] _ in
            self?.updateTimerLabel()
        }

        self.timerTAN = timerTAN
    }

    private func initCoupling(forSizeQR sizeQR: CGSize) {
        do {
            try DPAGApplicationFacade.couplingWorker.initialise()

            if let couplingTan = DPAGApplicationFacade.couplingWorker.couplingTan {
                self.performBlockOnMainThread { [weak self] in

                    self?.initTimerTAN()
                }

                // create new thread for semaphore
                self.performBlockInBackground { [weak self] in

                    self?.checkCouplingRequest()
                }

                if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), let accountID = contact.accountID {
                    let text = accountID + "|" + couplingTan

                    if let imageQRCode = try self.createQrCode(text, size: sizeQR) {
                        self.performBlockOnMainThread { [weak self] in

                            guard let strongSelf = self else { return }

                            let textFields: [UITextField] = [
                                strongSelf.textFieldCode0,
                                strongSelf.textFieldCode1,
                                strongSelf.textFieldCode2
                            ]

                            let tanSplitted = couplingTan.components(withLength: 3)

                            for (idx, splitItem) in tanSplitted.enumerated() {
                                if idx < textFields.count {
                                    textFields[idx].text = splitItem
                                } else {
                                    break
                                }
                            }

                            strongSelf.imageViewCode.image = imageQRCode
                        }
                    }
                }
            }
        } catch {
            self.presentErrorAlert(alertConfig: AlertConfigError(titleIdentifier: "attention", messageIdentifier: error.localizedDescription))
        }
    }

    private func createQrCode(_ tan: String, size: CGSize) throws -> UIImage? {
        let writer: ZXMultiFormatWriter = ZXMultiFormatWriter()
        let hints: ZXEncodeHints = ZXEncodeHints()

        hints.margin = NSNumber(value: 0)

        let result: ZXBitMatrix = try writer.encode(tan, format: kBarcodeFormatQRCode, width: Int32(size.width), height: Int32(size.height), hints: hints)

        if let image = ZXImage(matrix: result).cgimage {
            let retVal = UIImage(cgImage: image)

            return retVal
        }

        return nil
    }

    private func updateCouplingDeviceInfo(deviceName: String?, deviceOS: String?, isTempDevice: Bool) {
        self.labelConfirmNewDevice.text = deviceName
        self.labelSyncNewDevice.text = self.labelConfirmNewDevice.text

        var image = DPAGImageProvider.shared[.kImageDeviceComputer]

        if let deviceOS = deviceOS {
            if deviceOS.hasPrefix("iOS") || deviceOS.hasPrefix("iPhone") {
                image = DPAGImageProvider.shared[.kImageDeviceIPhone]
            } else if deviceOS.hasPrefix("aOS") {
                image = DPAGImageProvider.shared[.kImageDeviceAndroid]
            }
        }

        self.imageViewSyncNewDevice.image = image
        self.imageViewConfirmNewDevice.image = self.imageViewSyncNewDevice.image

        if isTempDevice {
            self.labelConfirmNewDeviceType.text = DPAGLocalizedString("registration.addDevice.deviceTypTemp")
            self.labelConfirmNewDeviceTypeDescription.text = DPAGLocalizedString("registration.addDevice.deviceTypTemp.description")
        } else {
            self.labelConfirmNewDeviceType.text = DPAGLocalizedString("registration.addDevice.deviceTypPerm")
            self.labelConfirmNewDeviceTypeDescription.text = DPAGLocalizedString("registration.addDevice.deviceTypPerm.description")
        }
        self.labelSyncNewDeviceType.text = self.labelConfirmNewDeviceType.text
        self.labelSyncNewDeviceTypeDescription.text = self.labelConfirmNewDeviceTypeDescription.text
    }

    private func checkCouplingRequest() {
        var hasCoupling = false

        repeat {
            do {
                try DPAGApplicationFacade.couplingWorker.getCouplingRequest()

                let deviceName = DPAGApplicationFacade.couplingWorker.getCouplingDeviceName()
                let deviceOS = DPAGApplicationFacade.couplingWorker.getCouplingDeviceOs()
                let isTempDevice = DPAGApplicationFacade.couplingWorker.getCouplingTempDevice()

                self.performBlockOnMainThread { [weak self] in
                    self?.updateCouplingDeviceInfo(deviceName: deviceName, deviceOS: deviceOS, isTempDevice: isTempDevice)
                }
            } catch {
                // 30 Sekunden Timeout. Nochmal versuchen .... ?
                if (error as NSError).domain == "NO_ERROR" || (error as NSError).domain == "NETWORK_ERROR" {
                    // --> Dann keinen Fehler anzeigen
                    DPAGLog(error, message: "Check coupling error")
                    Thread.sleep(forTimeInterval: TimeInterval(5))
                } else {
                    if (error as NSError).code != 0 {
                        self.presentErrorAlert(alertConfig: AlertConfigError(titleIdentifier: "attention", messageIdentifier: error.localizedDescription))
                    }
                }
            }

            hasCoupling = DPAGApplicationFacade.couplingWorker.hasCouplingRequest

            if hasCoupling, self.timerTAN != nil {
                self.timerTAN?.invalidate()
                self.timerTAN = nil

                self.performBlockOnMainThread { [weak self] in
                    self?.handleDeviceAdded()
                }
                break
            }
        } while hasCoupling == false && self.timerTAN != nil
    }

    @objc
    private func handleCodeCancel() {
        self.dismiss(cancelCoupling: true)
    }

    private func handleDeviceAdded() {
        if let publicKey = DPAGApplicationFacade.couplingWorker.couplingRequest?.publicKey.sha256().uppercased() {
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

        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration)) { [weak self] in

            self?.viewCode.isHidden = true
            self?.viewConfirm.isHidden = false
            self?.viewSync.isHidden = true
            self?.stackViewAll.layoutIfNeeded()

            self?.buttonCodeCancel.isHidden = true
            self?.buttonConfirmCancel.isHidden = false
            self?.buttonConfirmContinue.isHidden = false
            self?.viewPrimaryButtonsInverted?.backgroundColor = DPAGColorProvider.shared[.buttonBackground]
            self?.buttonSyncClose.isHidden = true
            self?.stackViewButtons.layoutIfNeeded()
            self?.title = DPAGLocalizedString("registration.addDevice.titleConfirm")
        }
    }

    @objc
    private func handleConfirmCancel() {
        self.dismiss(cancelCoupling: true)
    }

    @objc
    private func handleConfirmContinue() {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in

            do {
                try DPAGApplicationFacade.couplingWorker.confirmCouplingRequest()

                DPAGProgressHUD.sharedInstance.hide(true) {
                    UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration)) { [weak self] in

                        self?.viewCode.isHidden = true
                        self?.viewConfirm.isHidden = true
                        self?.viewSync.isHidden = false
                        self?.stackViewAll.layoutIfNeeded()

                        self?.buttonCodeCancel.isHidden = true
                        self?.buttonConfirmCancel.isHidden = true
                        self?.buttonConfirmContinue.isHidden = true
                        self?.buttonSyncClose.isHidden = false
                        self?.stackViewButtons.layoutIfNeeded()
                        self?.title = DPAGLocalizedString("registration.addDevice.titleSync")
                    }
                }
            } catch {
                DPAGProgressHUD.sharedInstance.hide(true) {
                    self?.presentErrorAlert(alertConfig: AlertConfigError(titleIdentifier: "attention", messageIdentifier: error.localizedDescription))
                }
            }
        }
    }

    @objc
    private func handleSyncClose() {
        self.dismiss(cancelCoupling: false)
    }

    private func dismiss(cancelCoupling: Bool) {
        self.timerTAN?.invalidate()
        self.timerTAN = nil

        if cancelCoupling {
            self.performBlockInBackground { [weak self] in

                do {
                    try DPAGApplicationFacade.couplingWorker.cancelCoupling()
                } catch {
                    self?.presentErrorAlert(alertConfig: AlertConfigError(titleIdentifier: "attention", messageIdentifier: error.localizedDescription))
                }
            }
        }
        self.dismiss(animated: true, completion: nil)
    }
}
