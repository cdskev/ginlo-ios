//
//  DPAGUIHelper.swift
// ginlo
//
//  Created by RBU on 27/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import MobileCoreServices
import Photos
import SIMSmeCore
import StoreKit
import UIKit

public struct DPAGUIHelper {
    private init() {}

    public static func customizeSearchBar(_ searchBar: UISearchBar) {
        // Removed von apperance, wegen der Dateiauswahl
        searchBar.backgroundColor = DPAGColorProvider.shared[.searchBar]
        searchBar.barTintColor = DPAGColorProvider.shared[.searchBar]
        searchBar.tintColor = DPAGColorProvider.shared[.searchBarTint]
        searchBar.backgroundImage = UIImage()
        let searchFieldBackgroundImage = UIImage.image(size: CGSize(width: 36, height: 28), color: DPAGColorProvider.shared[.searchBarTextFieldBackground], cornerRadius: 10)
        searchBar.setSearchFieldBackgroundImage(searchFieldBackgroundImage, for: .normal)
        searchBar.searchFieldBackgroundPositionAdjustment = UIOffset(horizontal: 0, vertical: 0)
        searchBar.searchTextPositionAdjustment = UIOffset(horizontal: 5, vertical: 0)
        if let searchText = searchBar.value(forKey: "searchField") as? UITextField {
            let tintColor = DPAGColorProvider.shared[.searchBarTint]
            searchText.tintColor = tintColor
            searchText.textColor = tintColor
            searchText.defaultTextAttributes = [NSAttributedString.Key.foregroundColor: tintColor]
            let glassIconView = searchText.leftView as? UIImageView
            glassIconView?.image = glassIconView?.image?.withRenderingMode(.alwaysTemplate)
            glassIconView?.tintColor = tintColor
            let crossIconView = searchText.value(forKey: "clearButton") as? UIButton
            crossIconView?.setImage(crossIconView?.currentImage?.withRenderingMode(.alwaysTemplate), for: .normal)
            crossIconView?.tintColor = tintColor
        }
    }

    public static func viewCameraOverlay() -> UIView {
        let cameraOverlayView = UIImageView(image: DPAGImageProvider.shared[.kImageOverlayCamera])

        cameraOverlayView.contentMode = .scaleAspectFill
        cameraOverlayView.autoresizingMask = [.flexibleHeight, .flexibleWidth]

        return cameraOverlayView
    }

    public static func startImagePickerWithDelegate(_ delegate: UINavigationControllerDelegate & UIImagePickerControllerDelegate, controller: UIViewController) {
        switch PHPhotoLibrary.authorizationStatus() {
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization({ status in
                    if status == .authorized {
                        DispatchQueue.main.async {
                            DPAGUIHelper.startLibraryControl(delegate, controller: controller)
                        }
                    }
                })
            case .authorized:
                DPAGUIHelper.startLibraryControl(delegate, controller: controller)
            case .denied, .restricted, .limited:
                break
            @unknown default:
                DPAGLog("Switch with unknown value: \(PHPhotoLibrary.authorizationStatus().rawValue)", level: .warning)
        }
    }

    private static func startLibraryControl(_ delegate: UINavigationControllerDelegate & UIImagePickerControllerDelegate, controller: UIViewController) {
        let libraryUI = DPAGImagePickerController()

        libraryUI.setup()
        libraryUI.sourceType = .photoLibrary
        libraryUI.delegate = delegate

        controller.present(libraryUI, animated: true, completion: nil)
    }

    public static func startCameraControlWithDelegate(_ delegate: UINavigationControllerDelegate & UIImagePickerControllerDelegate, controller: UIViewController) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { isAccepted in
                if isAccepted {
                    DispatchQueue.main.async {
                        DPAGUIHelper.startCameraControl(delegate, controller: controller)
                    }
                }
            })
        case .authorized:
            DPAGUIHelper.startCameraControl(delegate, controller: controller)
        case .denied, .restricted:
            break
        @unknown default:
            DPAGLog("Switch with unknown value: \(AVCaptureDevice.authorizationStatus(for: .video).rawValue)", level: .warning)
        }
    }

    private static func startCameraControl(_ delegate: UINavigationControllerDelegate & UIImagePickerControllerDelegate, controller: UIViewController) {
        let cameraUI = DPAGImagePickerController()
        cameraUI.setup()
        cameraUI.sourceType = .camera
        cameraUI.mediaTypes = [kUTTypeImage as String]
        let cameraOverlayView = DPAGUIHelper.viewCameraOverlay()
        cameraOverlayView.frame = cameraUI.view.frame
        cameraUI.cameraViewTransform = cameraUI.cameraViewTransform.translatedBy(x: 0, y: 44)
        cameraUI.cameraOverlayView = cameraOverlayView
        cameraUI.cameraDevice = .front
        cameraUI.allowsEditing = false
        cameraUI.delegate = delegate

        controller.present(cameraUI, animated: true, completion: nil)
    }

    public static func setupAppAppearance() {
        let imgUnselectedSep = UIImage.image(size: CGSize(width: 1, height: 29), color: DPAGColorProvider.shared[.segmentedControlUnselected])
        let imgSelectedSep = UIImage.image(size: CGSize(width: 1, height: 29), color: DPAGColorProvider.shared[.segmentedControlSelected])
        UISegmentedControl.appearance().setDividerImage(imgSelectedSep, forLeftSegmentState: .normal, rightSegmentState: .selected, barMetrics: .default)
        UISegmentedControl.appearance().setDividerImage(imgUnselectedSep, forLeftSegmentState: .selected, rightSegmentState: .normal, barMetrics: .default)
        let imgUnselected = UIImage.image(size: CGSize(width: 30, height: 29), color: DPAGColorProvider.shared[.segmentedControlUnselected], cornerRadius: 3)
        let imgSelected = UIImage.image(size: CGSize(width: 30, height: 29), color: DPAGColorProvider.shared[.segmentedControlSelected], cornerRadius: 3)
        let imgSegContrUnselected = imgUnselected.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10), resizingMode: .stretch)
        let imgSegContrSelected = imgSelected.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10), resizingMode: .stretch)
        UISegmentedControl.appearance().setBackgroundImage(imgSegContrUnselected, for: .normal, barMetrics: .default)
        UISegmentedControl.appearance().setBackgroundImage(imgSegContrSelected, for: .selected, barMetrics: .default)
        UISegmentedControl.appearance().setBackgroundImage(imgSegContrSelected, for: .highlighted, barMetrics: .default)
        let shadowSelected = NSShadow()
        let shadowUnselected = NSShadow()
        UISegmentedControl.appearance().setTitleTextAttributes([.font: UIFont.kFontHeadline, .foregroundColor: DPAGColorProvider.shared[.segmentedControlUnselectedContrast], .shadow: shadowSelected], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: UIFont.kFontHeadline, .foregroundColor: DPAGColorProvider.shared[.segmentedControlSelectedContrast], .shadow: shadowUnselected], for: .normal)
        UITableView.appearance(whenContainedInInstancesOf: [UIDatePicker.self]).backgroundColor = .clear
        UITableView.appearance().sectionIndexBackgroundColor = .clear
        UITableView.appearance().sectionIndexColor = DPAGColorProvider.shared[.tableSectionIndex]
        UISwitch.appearance().onTintColor = DPAGColorProvider.shared[.switchOnTint]
        UINavigationBar.appearance().barTintColor = DPAGColorProvider.shared[.navigationBar]
        UINavigationBar.appearance().tintColor = DPAGColorProvider.shared[.navigationBarTint]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: DPAGColorProvider.shared[.navigationBarTint]]
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: DPAGColorProvider.shared[.navigationBarTint]]
        UIToolbar.appearance().barTintColor = DPAGColorProvider.shared[.navigationBar]
        UIToolbar.appearance().tintColor = DPAGColorProvider.shared[.navigationBarTint]
        if AppConfig.isShareExtension == false {
            UILabel.appearance(whenContainedInInstancesOf: [UIDatePicker.self]).textColorWorkaround = DPAGColorProvider.shared[.datePickerText]
            UILabel.appearance(whenContainedInInstancesOf: [UIAlertController.self]).textColorWorkaround = DPAGColorProvider.shared[.alertTint]
        }
        UINavigationBar.appearance().isTranslucent = false
        UINavigationBar.appearance().shadowImage = UIImage()
        let cancelButtonAttributes: [NSAttributedString.Key: UIColor] = [.foregroundColor: DPAGColorProvider.shared[.searchBarTint]]
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self]).setTitleTextAttributes(cancelButtonAttributes, for: .normal)
    }

    public static func backgroundImage(imagePath: String) -> UIImage? {
        if FileManager.default.fileExists(atPath: imagePath) {
            return UIImage(contentsOfFile: imagePath)
        } else if let backgroundImageURL = DPAGConstantsGlobal.documentsDirectoryURL?.appendingPathComponent(imagePath), let backgroundImageData = try? Data(contentsOf: backgroundImageURL) {
            return UIImage(data: backgroundImageData)
        } else if let backgroundImageURL = DPAGConstantsGlobal.documentsDirectoryURL?.appendingPathComponent(imagePath).appendingPathExtension("png"), let backgroundImageData = try? Data(contentsOf: backgroundImageURL) {
            return UIImage(data: backgroundImageData)
        }

        return nil
    }
}
