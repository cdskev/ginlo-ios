//
//  DPAGDeviceTableViewCell.swift
// ginlo
//
//  Created by RBU on 08.01.18.
//  Copyright © 2019 Deutsche Post AG. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGDeviceTableViewCellProtocol: AnyObject {
    func configureCell(withDevice device: DPAGDevice, forHeightMeasurement: Bool)
}

public class DPAGDeviceTableViewCell: UITableViewCell, DPAGDeviceTableViewCellProtocol {
    @IBOutlet private var imageViewDevice: UIImageView! {
        didSet {
            self.imageViewDevice.tintColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelDeviceName: UILabel! {
        didSet {
            self.labelDeviceName.font = UIFont.kFontBody
            self.labelDeviceName.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelDeviceType: UILabel! {
        didSet {
            self.labelDeviceType.font = UIFont.kFontFootnote
            self.labelDeviceType.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelDeviceActivity: UILabel! {
        didSet {
            self.labelDeviceActivity.font = UIFont.kFontFootnoteBold
            self.labelDeviceActivity.textColor = DPAGColorProvider.shared[.labelDeviceActivity]
        }
    }

    override public func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code

        self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.contentView.backgroundColor = .clear
    }

    public func configureCell(withDevice device: DPAGDevice, forHeightMeasurement: Bool) {
        self.labelDeviceName.text = device.deviceName ?? DPAGLocalizedString("settings.devices.nodevicename")

        var deviceInfo = ""

        if device.guid == DPAGApplicationFacade.model.ownDeviceGuid {
            deviceInfo = DPAGLocalizedString("settings.devices.owndevice")
            self.accessibilityIdentifier = "device-own"
        } else if let lastOnlineStr = device.deviceLastOnline, let online = DPAGFormatter.dateServer.date(from: lastOnlineStr) {
            deviceInfo = String(format: DPAGLocalizedString("settings.devices.onlineinfo"), online.dateLabel, online.timeLabel)
            self.accessibilityIdentifier = "device-" + (device.guid ?? "???")
        }

        self.labelDeviceType.text = "\(device.appName ?? "SIMSme") \(device.appVersion ?? "2.5") | \(device.os ?? "-")"
        self.labelDeviceActivity.text = deviceInfo

        if forHeightMeasurement == false {
            self.accessoryType = .disclosureIndicator
            self.selectionStyle = .default

            self.setSelectionColor()

            var image = DPAGImageProvider.shared[.kImageDeviceComputer]

            if let deviceOS = device.os {
                if deviceOS.hasPrefix("iOS") || deviceOS.hasPrefix("iPhone") {
                    image = DPAGImageProvider.shared[.kImageDeviceIPhone]
                } else if deviceOS.hasPrefix("Android") || deviceOS.hasPrefix("aOS") {
                    image = DPAGImageProvider.shared[.kImageDeviceAndroid]
                }
            }

            self.imageViewDevice.image = image
        }
    }
    
    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                self.imageViewDevice.tintColor = DPAGColorProvider.shared[.labelText]
                self.labelDeviceName.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDeviceType.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDeviceActivity.textColor = DPAGColorProvider.shared[.labelDeviceActivity]
                self.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
