//
//  DPAGShowLocationViewController.swift
// ginlo
//
//  Created by RBU on 13/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreLocation
import MapKit
import UIKit

class DPAGLocationMapAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate

        super.init()
    }
}

class DPAGShowLocationViewController: UIViewController, UINavigationControllerDelegate, DPAGShowLocationViewControllerProtocol {
    private static let LocationDegreeInMeters: CLLocationDegrees = 222_240

    var lastValidLocation: CLLocation?
    var pinLocation: CLLocation?
    var automaticallyZoom = false {
        didSet {
            if self.automaticallyZoom, self.lastValidLocation != nil {
                self.zoomAutomatically()
            }
        }
    }

    @IBOutlet private var mapView: MKMapView!
    private lazy var locationManager: CLLocationManager = CLLocationManager()

    weak var locationDelegate: DPAGShowLocationViewControllerDelegate?

    deinit {
        self.stopObservingUserLocationUpdates()
        self.stopLocationLookup()
    }

    init() {
        super.init(nibName: "DPAGShowLocationViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.title = DPAGLocalizedString("chat-location-selection.navigation-item.title", comment: "text inside navigation bar when displaying location picker")

        self.configureMapView()
        self.configurePinAnnotation()
        self.startObservingUserLocationUpdates()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.locationManager.requestWhenInUseAuthorization()
        self.startLocationLookup()
    }

    private func configureMapView() {
        self.mapView.showsPointsOfInterest = true
    }

    private func configurePinAnnotation() {
        guard let pinLocation = self.pinLocation else {
            return
        }

        let annotation = DPAGLocationMapAnnotation(coordinate: pinLocation.coordinate)

        self.mapView.addAnnotation(annotation)
    }

    func mapCamera() -> MKMapCamera {
        self.mapView.camera
    }

    private func mapRegion() -> MKCoordinateRegion {
        self.mapView.region
    }

    func zoomMapToLocation(_ location: CLLocation) {
        let region = self.regionForLocation(location)

        self.mapView.setRegion(region, animated: true)
    }

    private func zoomMapToLocation(_ location: CLLocation, pinLocation: CLLocation) {
        let region = self.regionForLocations([location, pinLocation])

        self.mapView.setRegion(region, animated: true)
    }

    func refreshLocationLookup() {
        self.lastValidLocation = nil
        self.stopLocationLookup()
        self.startLocationLookup()
    }

    // MARK: - User Location Logic

    private func stopLocationLookup() {
        self.locationManager.stopUpdatingLocation()
        self.mapView.userTrackingMode = MKUserTrackingMode.none
        //    [self.loctseationInfoViewController setRefreshButtonEnabled:YES]
    }

    private func startLocationLookup() {
        self.locationManager.startUpdatingLocation()
        self.mapView.userTrackingMode = MKUserTrackingMode.follow
        //    [self.locationInfoViewController setRefreshButtonEnabled:NO]
    }

    private func userLocationDidUpdate(_ location: CLLocation) {
        self.lastValidLocation = location

        if self.automaticallyZoom {
            self.zoomAutomatically()
        }

        self.locationDelegate?.userLocationDidUpdate(location)
    }

    private func zoomAutomatically() {
        if self.automaticallyZoom {
            if let location = self.lastValidLocation {
                if let pinLocation = self.pinLocation {
                    self.zoomMapToLocation(location, pinLocation: pinLocation)
                } else {
                    self.zoomMapToLocation(location)
                }
            }

            self.automaticallyZoom = false
        }
    }

    private func regionForLocations(_ locations: [CLLocation]) -> MKCoordinateRegion {
        assert(locations.count == 2, "locations parameter need to contain exactly two CLLocation instances")

        var region = MKCoordinateRegion()

        if let location1 = locations.first, let location2 = locations.last {
            let meters: CLLocationDistance = location1.distance(from: location2)

            region.center.latitude = (location1.coordinate.latitude + location2.coordinate.latitude) / 2.0
            region.center.longitude = (location1.coordinate.longitude + location2.coordinate.longitude) / 2.0
            region.span.latitudeDelta = meters / DPAGShowLocationViewController.LocationDegreeInMeters * 4
            region.span.longitudeDelta = 0.0
        }
        return region
    }

    private func regionForLocation(_ location: CLLocation) -> MKCoordinateRegion {
        let spanInDegrees: CLLocationDegrees = (location.horizontalAccuracy / DPAGShowLocationViewController.LocationDegreeInMeters)

        let span = MKCoordinateSpan(latitudeDelta: spanInDegrees, longitudeDelta: spanInDegrees)
        let coordinate = location.coordinate

        return MKCoordinateRegion(center: coordinate, span: span)
    }

    private func isValidLocation(_ location: CLLocation?) -> Bool {
        if let loc = location {
            return self.isLocationUpToDate(loc) && self.isLocationAccuracyIncreased(loc)
        }
        return false
    }

    private func isLocationUpToDate(_ location: CLLocation) -> Bool {
        let locationAge = location.timestamp.timeIntervalSinceNow
        let TenMinutesInSeconds = TimeInterval(60 * 10)

        return locationAge < TenMinutesInSeconds
    }

    private func isLocationAccuracyIncreased(_ location: CLLocation) -> Bool {
        guard let lastValidLocation = self.lastValidLocation else {
            return true
        }
        return location.horizontalAccuracy <= lastValidLocation.horizontalAccuracy
    }

    // MARK: - KVO

    private var observerLocation: NSKeyValueObservation?

    private func startObservingUserLocationUpdates() {
        self.observerLocation = self.mapView.userLocation.observe(\.location, changeHandler: { [weak self] locationUser, _ in

            if let location = locationUser.location, self?.isValidLocation(location) ?? false {
                self?.userLocationDidUpdate(location)
            }
        })
    }

    private func stopObservingUserLocationUpdates() {
        self.observerLocation?.invalidate()
    }
}
