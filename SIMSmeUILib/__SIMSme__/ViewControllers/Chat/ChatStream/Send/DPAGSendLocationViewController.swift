//
//  DPAGSendLocationViewController.swift
//  SIMSme
//
//  Created by RBU on 06/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Contacts
import CoreLocation
import MapKit
import SIMSmeCore
import UIKit

protocol DPAGSendLocationViewControllerProtocol: DPAGShowLocationViewControllerDelegate {
    var delegate: DPAGSendLocationViewControllerDelegate? { get set }
}

class DPAGSendLocationViewController: DPAGViewController, DPAGSendLocationViewControllerProtocol {
    static let LocationDegreeInMeters: CLLocationDegrees = 222_240

    fileprivate var myObservationContext: UInt8 = 0

    weak var delegate: DPAGSendLocationViewControllerDelegate?

    @IBOutlet var viewShowLocation: UIView!
    @IBOutlet var viewSend: UIView!
    @IBOutlet var viewLocationInfo: UIView!

    @IBOutlet var sendButton: UIButton! {
        didSet {
            self.sendButton.accessibilityIdentifier = "sendButton"
            self.sendButton.setImage(DPAGImageProvider.shared[.kImageChatSend], for: .normal)
            self.sendButton.tintColor = DPAGColorProvider.shared[.buttonBackground]
            self.sendButton.backgroundColor = DPAGColorProvider.shared[.buttonTint]
            self.sendButton.layer.cornerRadius = 10
            self.sendButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        }
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.sendButton.setImage(DPAGImageProvider.shared[.kImageChatSend], for: .normal)
                self.sendButton.tintColor = DPAGColorProvider.shared[.buttonBackground]
                self.sendButton.backgroundColor = DPAGColorProvider.shared[.buttonTint]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    let locationInfoViewController = DPAGApplicationFacadeUI.locationInfoVC()
    let locationViewController = DPAGApplicationFacadeUI.locationShowVC()

    private var lastLocation: CLLocation?

    var placemark: CLPlacemark? {
        didSet {
            self.locationInfoViewController.placemark = self.placemark

            self.setSendFunctionEnabled(self.placemark != nil)
        }
    }

    lazy var geocoder = CLGeocoder()

    init() {
        super.init(nibName: "DPAGSendLocationViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.title = DPAGLocalizedString("chat-location-selection.navigation-item.title", comment: "text inside navigation bar when displaying location picker")

        self.locationInfoViewController.willMove(toParent: self)
        self.addChild(self.locationInfoViewController)
        self.viewLocationInfo.addSubview(self.locationInfoViewController.view)
        self.locationInfoViewController.didMove(toParent: self)

        self.locationInfoViewController.view.translatesAutoresizingMaskIntoConstraints = false
        self.viewLocationInfo.addConstraintsFill(subview: self.locationInfoViewController.view)

        self.locationViewController.willMove(toParent: self)
        self.addChild(self.locationViewController)
        self.viewShowLocation.addSubview(self.locationViewController.view)
        self.locationViewController.didMove(toParent: self)

        self.locationViewController.view.translatesAutoresizingMaskIntoConstraints = false
        self.viewShowLocation.addConstraintsFill(subview: self.locationViewController.view)

        self.locationInfoViewController.refreshButton.addTargetClosure { [weak self] _ in

            self?.lastLocation = nil
            self?.locationViewController.refreshLocationLookup()
        }

        self.locationInfoViewController.hiddenAddressAreaButton.addTargetClosure { [weak self] _ in

            self?.selectCurrentLocation()
        }

        self.setSendFunctionEnabled(false)

        self.locationViewController.locationDelegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.checkLocationServiceAuthorizationStatus()
    }

    // MARK: -

    /// Returns whether the user denied access for this app to location services. If the user has not been asked yet,
    /// the method will return NO.
    func isLocationServicesAuthorizationDenied() -> Bool {
        let status = CLLocationManager.authorizationStatus()

        return status == .restricted || status == .denied
    }

    func checkLocationServiceAuthorizationStatus() {
        if self.isLocationServicesAuthorizationDenied() {
            let actionOK = UIAlertAction(titleIdentifier: "noContactsView.alert.settings", style: .default, handler: { _ in

                if let url = URL(string: UIApplication.openSettingsURLString) {
                    AppConfig.openURL(url)
                }
            })

            self.presentAlert(alertConfig: AlertConfig(messageIdentifier: "chat-location-selection.location-service-authorization-denied", cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
        }
    }

    func setSendFunctionEnabled(_ enabled: Bool) {
        self.sendButton.isEnabled = enabled
        self.locationInfoViewController.isSelectLocationButtonEnabled = enabled
    }

    // MARK: - User Location Logic

    func stopGeocoding() {
        if self.geocoder.isGeocoding {
            self.geocoder.cancelGeocode()
        }
    }

    func selectCurrentLocation() {
        DPAGProgressHUD.sharedInstance.show(true) { [weak self] _ in

            self?.createMapSnapshotUsingCurrentLocationAndMapsCurrentZoom()
        }
    }

    func createMapSnapshotUsingCurrentLocationAndMapsCurrentZoom() {
        if let currentLocation = self.locationViewController.lastValidLocation {
            let mapCamera = self.locationViewController.mapCamera()
            let currentMapAltitude = mapCamera.altitude

            self.createMapSnapshotWithLocation(currentLocation, altitude: currentMapAltitude)
        }
    }

    func createMapSnapshotUsingCurrentLocationCoordinateAndPrecision() {
        if let currentLocation = self.locationViewController.lastValidLocation {
            let zoomOutFactor: CLLocationAccuracy = 20
            let altitude = currentLocation.horizontalAccuracy * zoomOutFactor

            self.createMapSnapshotWithLocation(currentLocation, altitude: altitude)
        }
    }

    func didReceivePlacemark(_ placemark: CLPlacemark?) {
        self.placemark = placemark
    }

    func lookupAddressOfLocation(_ location: CLLocation) -> CLPlacemark? {
        if self.geocoder.isGeocoding {
            self.geocoder.cancelGeocode()
        }

        self.geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in

            self?.didReceivePlacemark(placemarks?.first)
        }

        return self.placemark
    }

    func userLocationDidUpdate(_ location: CLLocation) {
        var doUpdate = true

        if let lastLocation = self.lastLocation, lastLocation.coordinate.latitude == location.coordinate.latitude, lastLocation.coordinate.longitude == location.coordinate.longitude {
            doUpdate = false
        }

        self.lastLocation = location

        if doUpdate {
            self.locationInfoViewController.locationAccuracy = location.horizontalAccuracy
            self.locationViewController.zoomMapToLocation(location)
            _ = self.lookupAddressOfLocation(location)
        }
    }

    // MARK: - Map Snapshot Logic

    func mapSnapshotCompletedWithImage(_ image: UIImage?) {
        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

            guard let strongSelf = self else { return }

            if let mapImage = image, let lastValidLocation = strongSelf.locationViewController.lastValidLocation {
                var formattedAddress: String = ""

                if let postalAddress = strongSelf.placemark?.postalAddress {
                    formattedAddress = CNPostalAddressFormatter().string(from: postalAddress)
                }

                strongSelf.delegate?.sendLocationViewController(strongSelf, selectedLocation: lastValidLocation, mapSnapshot: mapImage, address: formattedAddress)
            } else {
                let snapshotCreationFailedMessage = "chat-location-selection.snapshot-creation-failed"

                strongSelf.presentErrorAlert(alertConfig: AlertConfigError(messageIdentifier: snapshotCreationFailedMessage, accessibilityIdentifier: snapshotCreationFailedMessage))
            }
        }
    }

    func regionForLocation(_ location: CLLocation) -> MKCoordinateRegion {
        let spanInDegrees: CLLocationDegrees = (location.horizontalAccuracy / DPAGSendLocationViewController.LocationDegreeInMeters)

        let span = MKCoordinateSpan(latitudeDelta: spanInDegrees, longitudeDelta: spanInDegrees)

        let coordinate = location.coordinate

        return MKCoordinateRegion(center: coordinate, span: span)
    }

    func createMapSnapshotWithLocation(_ location: CLLocation, altitude altitudeInMeters: CLLocationDistance) {
        let camera = MKMapCamera(lookingAtCenter: location.coordinate, fromEyeCoordinate: location.coordinate, eyeAltitude: altitudeInMeters)

        let DPAGSendLocationViewControllerSnapshotSize = CGSize(width: DPAGConstantsGlobal.kChatMaxWidthObjects, height: 100)

        let options = MKMapSnapshotter.Options()

        options.camera = camera
        options.scale = UIScreen.main.scale
        options.size = DPAGSendLocationViewControllerSnapshotSize

        self.createMapSnapshotWithOptions(options)
    }

    func createMapSnapshotWithOptions(_ options: MKMapSnapshotter.Options) {
        let snapshotter = MKMapSnapshotter(options: options)

        snapshotter.start { [weak self] snapshot, error in

            if let strongSelf = self {
                if error != nil {
                    strongSelf.mapSnapshotCompletedWithImage(nil)
                } else {
                    strongSelf.annotateUserLocation(strongSelf.locationViewController.lastValidLocation, mapSnapshot: snapshot)
                }
            }
        }
    }

    func createMapSnapshotWithRegion(_ region: MKCoordinateRegion) {
        let DPAGSendLocationViewControllerSnapshotSize = CGSize(width: DPAGConstantsGlobal.kChatMaxWidthObjects, height: 100)
        let options = MKMapSnapshotter.Options()

        options.scale = UIScreen.main.scale
        options.size = DPAGSendLocationViewControllerSnapshotSize
        options.region = region

        self.createMapSnapshotWithOptions(options)
    }

    func annotateUserLocation(_ userLocation: CLLocation?, mapSnapshot: MKMapSnapshotter.Snapshot?) {
        guard let image = mapSnapshot?.image, let location = userLocation else {
            return
        }
        let finalImageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        let pin = MKPinAnnotationView(annotation: nil, reuseIdentifier: "MKPinAnnotationView")

        guard let pinImage = pin.image else { return }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale

        let finalImage = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in

            image.draw(at: .zero)

            if let pointForCoordinate = mapSnapshot?.point(for: location.coordinate), finalImageRect.contains(pointForCoordinate) {
                var point = pointForCoordinate
                let pinCenterOffset = pin.centerOffset

                point.x -= pin.bounds.size.width / 2.0
                point.y -= pin.bounds.size.height / 2.0
                point.x += pinCenterOffset.x
                point.y += pinCenterOffset.y

                pinImage.draw(at: point)
            }
        }

        self.mapSnapshotCompletedWithImage(finalImage)
    }

    // MARK: - IBAction

    @IBAction private func sendButtonPressed(_: Any?) {
        self.selectCurrentLocation()
    }

    func backBarButtonItemPressed(_: Any?) {
        self.stopGeocoding()
        _ = self.navigationController?.popViewController(animated: true)
    }
}
