//
//  DPAGLocationInfoViewController.swift
// ginlo
//
//  Created by RBU on 07/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreLocation
import SIMSmeCore
import UIKit

protocol DPAGLocationInfoViewControllerProtocol: AnyObject {
    var placemark: CLPlacemark? { get set }
    var locationAccuracy: CLLocationAccuracy { get set }

    var isSelectLocationButtonEnabled: Bool { get set }

    var refreshButton: UIButton! { get }
    var hiddenAddressAreaButton: UIButton! { get }
}

class DPAGLocationInfoViewController: UIViewController, DPAGLocationInfoViewControllerProtocol, DPAGViewControllerOrientationFlexible {
    var placemark: CLPlacemark? {
        didSet {
            self.refreshButton.isEnabled = self.placemark != nil
            self.updateLabels()
        }
    }

    var locationAccuracy: CLLocationAccuracy = -1 {
        didSet {
            self.updateLabels()
        }
    }

    @IBOutlet private var pressForActionLabel: UILabel! {
        didSet {
            self.pressForActionLabel.text = DPAGLocalizedString("chat-location-selection.position-info.info-text", comment: "Eigenen Standort senden info text")
            self.pressForActionLabel.font = UIFont.boldSystemFont(ofSize: 18)
            self.pressForActionLabel.textColor = UIColor.darkText
        }
    }

    @IBOutlet private var addressLabel1: UILabel! {
        didSet {
            self.addressLabel1.textColor = UIColor.darkText
            self.addressLabel1.font = UIFont.systemFont(ofSize: 16)
        }
    }

    @IBOutlet private var addressLabel2: UILabel! {
        didSet {
            self.addressLabel2.textColor = UIColor.darkText
            self.addressLabel2.font = UIFont.systemFont(ofSize: 16)
        }
    }

    @IBOutlet private var accuracyLabel: UILabel! {
        didSet {
            self.accuracyLabel.textColor = UIColor.darkGray
            self.accuracyLabel.font = UIFont.systemFont(ofSize: 13)
        }
    }

    @IBOutlet private(set) var refreshButton: UIButton! {
        didSet {
            self.refreshButton.accessibilityIdentifier = "refreshButton"
            self.refreshButton.setImage(DPAGImageProvider.shared[.kImageReload], for: .normal)
            self.refreshButton.tintColor = UIColor.darkText
        }
    }

    @IBOutlet private(set) var hiddenAddressAreaButton: UIButton! {
        didSet {}
    }

    private var accuracyFormatText: String = ""

    init() {
        super.init(nibName: "DPAGLocationInfoViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = DPAGColorProvider.shared[.backgroundLocationInfo]

        self.setupLabels()
        self.updateLabels()

        self.refreshButton.isEnabled = false
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.view.backgroundColor = DPAGColorProvider.shared[.backgroundLocationInfo]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    private func setupLabels() {
        self.accuracyFormatText = DPAGLocalizedString("chat-location-selection.precision-info-text", comment: "auf %im meter genau - %i wird als Platzhalter  benutzt und zur Laufzeit durch die Präzisionsangabe ersetzt")
    }

    private func updateLabels() {
        if self.locationAccuracy > 0 {
            self.accuracyLabel.text = self.humanReadableAccuracyInfoByMeter(self.locationAccuracy)
        } else {
            self.accuracyLabel.text = ""
        }

        if let placemark = self.placemark {
            self.addressLabel1.text = self.addressPartOfPlacemark(placemark)
            self.addressLabel2.text = self.postalPartOfPlacemark(placemark)
        } else {
            self.addressLabel1.text = "-"
            self.addressLabel2.text = ""
        }
    }

    private func addressPartOfPlacemark(_ placemark: CLPlacemark) -> String? {
        if let thoroughfare = placemark.thoroughfare {
            var address = thoroughfare

            if let subThoroughfare = placemark.subThoroughfare {
                address += " \(subThoroughfare)"
            }

            return address
        }
        return placemark.subThoroughfare
    }

    private func postalPartOfPlacemark(_ placemark: CLPlacemark) -> String? {
        if let postalCode = placemark.postalCode {
            var postal = postalCode

            if let locality = placemark.locality {
                postal += " \(locality)"
            }

            return postal
        }
        return placemark.locality
    }

    private func humanReadableAccuracyInfoByMeter(_ locationAccuracy: CLLocationAccuracy) -> String {
        String(format: self.accuracyFormatText, Int32(locationAccuracy))
    }

    // MARK: - @protocol DPAGLocationInfoViewController <NSObject>

    var isSelectLocationButtonEnabled: Bool {
        get {
            self.hiddenAddressAreaButton.isEnabled
        }
        set {
            self.hiddenAddressAreaButton.isEnabled = newValue
        }
    }

    private var isRefreshButtonEnabled: Bool {
        get {
            self.refreshButton.isEnabled
        }
        set {
            self.refreshButton.isEnabled = newValue
        }
    }
}
