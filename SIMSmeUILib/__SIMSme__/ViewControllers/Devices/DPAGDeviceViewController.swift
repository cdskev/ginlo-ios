//
//  DPAGDeviceViewController.swift
//  SIMSme
//
//  Created by RBU on 15.01.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGDeviceViewController: DPAGViewControllerWithKeyboard {
    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var stackViewAll: UIStackView!

    @IBOutlet private var stackViewDeviceType: UIStackView!
    @IBOutlet private var labelDeviceType: UILabel! {
        didSet {
            self.labelDeviceType.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDeviceType.font = UIFont.kFontSubheadline
            self.labelDeviceType.textAlignment = .center
        }
    }

    @IBOutlet private var labelDeviceTypeDescription: UILabel! {
        didSet {
            self.labelDeviceTypeDescription.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDeviceTypeDescription.font = UIFont.kFontSubheadline
            self.labelDeviceTypeDescription.textAlignment = .center
        }
    }

    @IBOutlet private var stackViewDeviceInfo: UIStackView!
    @IBOutlet private var imageViewDeviceType: UIImageView! {
        didSet {
            self.imageViewDeviceType.contentMode = .scaleAspectFit
            self.imageViewDeviceType.tintColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelDeviceInfo: UILabel! {
        didSet {
            self.labelDeviceInfo.font = UIFont.kFontFootnote
            self.labelDeviceInfo.textColor = DPAGColorProvider.shared[.labelText]
            self.labelDeviceInfo.textAlignment = .center
        }
    }

    @IBOutlet private var labelDeviceActivity: UILabel! {
        didSet {
            self.labelDeviceActivity.font = UIFont.kFontFootnoteBold
            self.labelDeviceActivity.textColor = DPAGColorProvider.shared[.labelDeviceActivity]
            self.labelDeviceActivity.textAlignment = .center
        }
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelDeviceType.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDeviceTypeDescription.textColor = DPAGColorProvider.shared[.labelText]
                self.imageViewDeviceType.tintColor = DPAGColorProvider.shared[.labelText]
                self.labelDeviceInfo.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDeviceActivity.textColor = DPAGColorProvider.shared[.labelDeviceActivity]
                self.textFieldDeviceName.attributedPlaceholder = NSAttributedString(string: UIDevice.current.name, attributes: [.foregroundColor: DPAGColorProvider.shared[.textFieldText]])
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var buttonDeviceDelete: UIButton! {
        didSet {
            self.buttonDeviceDelete.configureButtonDestructive()
            self.buttonDeviceDelete.setTitle(DPAGLocalizedString("devices.list.message.confirm.delete.device"), for: .normal)
        }
    }

    @IBOutlet private var stackViewDeviceName: UIStackView!
    @IBOutlet private var labelDeviceName: UILabel! {
        didSet {
            self.labelDeviceName.text = DPAGLocalizedString("registration.createDevice.labelDeviceName")
            self.labelDeviceName.configureLabelForTextField()
        }
    }

    @IBOutlet private var textFieldDeviceName: UITextField! {
        didSet {
            self.textFieldDeviceName.accessibilityIdentifier = "textFieldDeviceName"
            self.textFieldDeviceName.configureDefault()
        }
    }

    @IBOutlet private var viewButtonNext: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonNext.button.accessibilityIdentifier = "buttonSave"
            self.viewButtonNext.button.setTitle(DPAGLocalizedString("settings.profile.button.saveChanges"), for: .normal)
            self.viewButtonNext.button.addTarget(self, action: #selector(handleDeviceSave(_:)), for: .touchUpInside)
        }
    }

    private let device: DPAGDevice

    init(device: DPAGDevice) {
        self.device = device

        super.init(nibName: "DPAGDeviceViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.title = self.device.deviceName ?? DPAGLocalizedString("settings.devices.nodevicename") // ?? UIDevice.current.name

        self.configureGui()
    }

    private func configureGui() {
        self.textFieldDeviceName.text = self.device.deviceName

        var deviceInfo = ""

        if device.guid == DPAGApplicationFacade.model.ownDeviceGuid {
            deviceInfo = DPAGLocalizedString("settings.devices.owndevice")

            self.textFieldDeviceName.attributedPlaceholder = NSAttributedString(string: UIDevice.current.name, attributes: [.foregroundColor: DPAGColorProvider.shared[.textFieldText]])
            self.buttonDeviceDelete.isHidden = true
        } else if let lastOnlineStr = device.deviceLastOnline, let online = DPAGFormatter.dateServer.date(from: lastOnlineStr) {
            deviceInfo = String(format: DPAGLocalizedString("settings.devices.onlineinfo"), online.dateLabel, online.timeLabel)
        }

        self.labelDeviceInfo.text = "\(device.appName ?? "SIMSme") \(device.appVersion ?? "2.5") | \(device.os ?? "-")"
        self.labelDeviceActivity.text = deviceInfo

        if self.device.isTempDevice() {
            self.labelDeviceType.text = DPAGLocalizedString("registration.addDevice.deviceTypTemp")
            self.labelDeviceTypeDescription.text = DPAGLocalizedString("registration.addDevice.deviceTypTemp.description")
        } else {
            self.labelDeviceType.text = DPAGLocalizedString("registration.addDevice.deviceTypPerm")
            self.labelDeviceTypeDescription.text = DPAGLocalizedString("registration.addDevice.deviceTypPerm.description")
        }

        var image = DPAGImageProvider.shared[.kImageDeviceComputer]

        if let deviceOS = device.os {
            if deviceOS.hasPrefix("iOS") || deviceOS.hasPrefix("iPhone") {
                image = DPAGImageProvider.shared[.kImageDeviceIPhone]
            } else if deviceOS.hasPrefix("aOS") {
                image = DPAGImageProvider.shared[.kImageDeviceAndroid]
            }
        }

        self.imageViewDeviceType.image = image
    }

    override func handleViewTapped(_: Any?) {
        self.textFieldDeviceName.resignFirstResponder()
    }

    override func handleKeyboardWillShow(_ aNotification: Notification) {
        super.handleKeyboardWillShow(aNotification, scrollView: self.scrollView, viewVisible: self.textFieldDeviceName, viewButtonPrimary: self.viewButtonNext)
    }

    override func handleKeyboardWillHide(_ aNotification: Notification) {
        super.handleKeyboardWillHide(aNotification, scrollView: self.scrollView, viewButtonPrimary: self.viewButtonNext)
    }

    @IBAction private func handleDeviceDelete(_: Any) {
        let block = { [weak self] (success: Bool) in
            if success {
                DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in

                    if let deviceGuid = self?.device.guid {
                        DPAGApplicationFacade.devicesWorker.deleteDevice(deviceGuid) { _, _, errorMessage in

                            DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                                if let errorMessage = errorMessage {
                                    self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                                } else {
                                    self?.navigationController?.popViewController(animated: true)
                                }
                            }
                        }
                    } else {
                        DPAGProgressHUD.sharedInstance.hide(true)
                    }
                }
            }
        }
        DPAGApplicationFacadeUIBase.loginVC.requestPassword(withTouchID: false, completion: block)
    }

    @IBAction private func handleDeviceSave(_: Any) {
        let newDeviceName = (self.textFieldDeviceName.text ?? self.textFieldDeviceName.placeholder)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard newDeviceName.isEmpty == false, let deviceGuid = self.device.guid else {
            return
        }

        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            DPAGApplicationFacade.devicesWorker.renameDevice(deviceGuid, newName: newDeviceName, withResponse: { [weak self] _, _, errorMessage in

                if let errorMessage = errorMessage {
                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                    }
                } else {
                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                        self?.device.deviceName = newDeviceName

                        self?.navigationController?.popViewController(animated: true)
                    }
                }
            })
        }
    }
}
