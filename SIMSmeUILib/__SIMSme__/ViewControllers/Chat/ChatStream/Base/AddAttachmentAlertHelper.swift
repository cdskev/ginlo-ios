//
//  AddAttachmentAlertHelper.swift
//  SIMSmeUILib
//
//  Created by Evgenii Kononenko on 05.04.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Contacts
import MobileCoreServices
import Photos
import SIMSmeCore
import UIKit

enum PermissionState {
    case permitted
    case notPermitted
    case notPermittedWithReason
}

class AddAttachmentAlertHelper {
    weak var viewController: UIViewController?
    weak var documentPickerDelegate: UIDocumentPickerDelegate?
    weak var contactSendingDelegate: DPAGContactSendingDelegate?
    weak var personSendingDelegate: DPAGPersonSendingDelegate?
    weak var locationSendingDelegate: DPAGSendLocationViewControllerDelegate?
    weak var imagePickerDelegate: (UIImagePickerControllerDelegate & UINavigationControllerDelegate)?
    weak var mediaPickerDelegate: DPAGMediaPickerDelegate?

    // MARK: - Internal

    func addAttachmentOptions(completion: @escaping ([AlertOption]) -> Void, cancelHandler: (() -> Void)?) {
        let options = [self.optionCamera(),
                       self.optionPhotoLibrary(),
                       self.optionLocation(),
                       self.optionSendContact(),
                       self.optionSendFile(),
                       self.optionSendFromMedia(),
                       self.optionCancel(handler: cancelHandler)]
            .compactMap { $0 }
        completion(options)
    }

    // MARK: - Private

    private func checkCameraAccess(completion: @escaping (_ cameraAccessGranted: PermissionState) -> Void) {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authStatus {
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                    DispatchQueue.main.async {
                        completion(granted ? .permitted : .notPermitted)
                    }
                })
                return
            case .authorized:
                completion(.permitted)
            case .denied, .restricted:
                completion(.notPermittedWithReason)
            @unknown default:
                DPAGLog("Switch with unknown value: \(authStatus.rawValue)", level: .warning)
        }
    }

    private func checkPhotoLibraryAccess(completion: @escaping (_ photoLibraryAccessGranted: PermissionState) -> Void) {
        let authStatus = PHPhotoLibrary.authorizationStatus()
        switch authStatus {
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization({ status in
                    DispatchQueue.main.async {
                        completion(status == .authorized ? .permitted : .notPermitted)
                    }
                })
                return
            case .authorized:
                completion(.permitted)
            case .denied, .restricted:
                completion(.notPermittedWithReason)
            case .limited:
                break
            @unknown default:
                DPAGLog("Switch with unknown value: \(authStatus.rawValue)", level: .warning)
        }
    }

    private func checkLocationAccess(completion: @escaping (_ locationAccessGranted: PermissionState) -> Void) {
        switch CLLocationManager.authorizationStatus() {
            case .notDetermined, .authorizedAlways, .authorizedWhenInUse:
                completion(.permitted)
            case .denied, .restricted:
                completion(.notPermittedWithReason)
            @unknown default:
                DPAGLog("Switch with unknown value: \(CLLocationManager.authorizationStatus().rawValue)", level: .warning)
        }
    }

    private func selfDestructEnabled() -> Bool {
        DPAGSendMessageViewOptions.sharedInstance.selfDestructionEnabled ?? false
    }

    private func commentEnabled() -> Bool {
        DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation != nil
    }

    // MARK: - Options

    private func optionCamera() -> AlertOption? {
        if DPAGApplicationFacade.preferences.sendCameraDisabled || UIImagePickerController.isSourceTypeAvailable(.camera) == false {
            return nil
        }

        return AlertOption(title: DPAGLocalizedString("chats.addAttachment.record"), style: .default, image: DPAGImageProvider.shared[.kImageAttachmentRecord], textAlignment: .left, accesibilityIdentifier: "chats.addAttachment.record", handler: self.handleAddAttachmentRecord)
    }

    private func optionPhotoLibrary() -> AlertOption {
        AlertOption(title: DPAGLocalizedString("chats.addAttachment.fromAlbum"), style: .default, image: DPAGImageProvider.shared[.kImageAttachmentAlbum], textAlignment: .left, accesibilityIdentifier: "chats.addAttachment.fromAlbum", handler: self.handleAddAttachmentFromAlbum)
    }

    private func optionLocation() -> AlertOption? {
        if DPAGApplicationFacade.preferences.sendLocationDisabled || self.selfDestructEnabled() || self.commentEnabled() || CLLocationManager.locationServicesEnabled() == false {
            return nil
        }
        return AlertOption(title: DPAGLocalizedString("chats.addAttachment.location"), style: .default, image: DPAGImageProvider.shared[.kImageAttachmentLocation], textAlignment: .left, accesibilityIdentifier: "chats.addAttachment.location", handler: self.handleAddAttachmentLocation)
    }

    private func optionSendContact() -> AlertOption? {
        if DPAGApplicationFacade.preferences.sendVCardDisabled || self.selfDestructEnabled() || self.commentEnabled() {
            return nil
        }
        return AlertOption(title: DPAGLocalizedString("chats.addAttachment.contact"), style: .default, image: DPAGImageProvider.shared[.kImageAttachmentContact], textAlignment: .left, accesibilityIdentifier: "chats.addAttachment.contact", handler: self.handleAddAttachmentContact)
    }

    private func optionSendFile() -> AlertOption? {
        if self.selfDestructEnabled() || self.commentEnabled() {
            return nil
        }
        return AlertOption(title: DPAGLocalizedString("chats.addAttachment.file"), style: .default, image: DPAGImageProvider.shared[.kImageAttachmentFile], textAlignment: .left, accesibilityIdentifier: "chats.addAttachment.file", handler: self.handleAddAttachmentFile)
    }

    private func optionSendFromMedia() -> AlertOption {
        AlertOption(title: DPAGLocalizedString("chats.addAttachment.fromMedia"), style: .default, image: DPAGImageProvider.shared[.kImageAttachmentSIMSmeMedia], textAlignment: .left, accesibilityIdentifier: "chats.addAttachment.fromMedia", handler: self.handleAddAttachmentFromMedia)
    }

    private func optionCancel(handler: (() -> Void)?) -> AlertOption {
        AlertOption(title: DPAGLocalizedString("res.cancel"), style: .cancel, handler: handler)
    }

    // MARK: - Handlers

    private func handleAddAttachmentRecord() {
        self.checkCameraAccess { cameraAccessGranted in
            switch cameraAccessGranted {
                case .permitted:
                    break
                case .notPermitted:
                    return
                case .notPermittedWithReason:
                    self.presentAlert(messageIdentifier: "noCameraView.title.titleTextView")
                    return
            }
            AVAudioSession.sharedInstance().requestRecordPermission {
                if $0 == true {
                    self.openCamera()
                    return
                }
                let takePhotoAction = UIAlertAction(titleIdentifier: "permission.alert.takephoto", style: .default, handler: { [weak self] _ in
                    self?.openCamera(onlyPhoto: true)
                })
                self.presentAlert(messageIdentifier: "noMicrophoneView.title.titleTextView", otherButtonAction: takePhotoAction)
            }
        }
    }

    private func openCamera(onlyPhoto: Bool = false) {
        let cameraUI = DPAGImagePickerController()
        cameraUI.setup()
        cameraUI.sourceType = .camera
        if var mediaTypes = UIImagePickerController.availableMediaTypes(for: .camera) {
            if DPAGApplicationFacade.preferences.sendMicrophoneDisabled || onlyPhoto, let index = mediaTypes.firstIndex(of: "public.movie") {
                mediaTypes.remove(at: index)
            }
            cameraUI.mediaTypes = mediaTypes
        }
        cameraUI.videoMaximumDuration = DPAGApplicationFacade.preferences.maxLengthForSentVideos
        cameraUI.videoQuality = DPAGApplicationFacade.preferences.videoQualityForSentVideos
        cameraUI.allowsEditing = true
        cameraUI.delegate = self.imagePickerDelegate
        self.viewController?.present(cameraUI, animated: true, completion: nil)
    }

    private func handleAddAttachmentFromMedia() {
        if selfDestructEnabled() || commentEnabled() {
            let mediaViewController = DPAGApplicationFacadeUIMedia.mediaSelectSingleNoFilesVC()
            mediaViewController.mediaPickerDelegate = self.mediaPickerDelegate
            self.viewController?.present(DPAGApplicationFacadeUIBase.navVC(rootViewController: mediaViewController), animated: true, completion: nil)
        } else {
            let mediaViewController = DPAGApplicationFacadeUIMedia.mediaSelectSingleVC()
            mediaViewController.mediaPickerDelegate = self.mediaPickerDelegate
            self.viewController?.present(DPAGApplicationFacadeUIBase.navVC(rootViewController: mediaViewController), animated: true, completion: nil)
        }
    }

    private func handleAddAttachmentFromAlbum() {
        self.checkPhotoLibraryAccess { granted in
            switch granted {
                case .permitted:
                    break
                case .notPermitted:
                    return
                case .notPermittedWithReason:
                    self.presentAlert(messageIdentifier: "noPhotoLibraryView.title.titleTextView")
                    return
            }
            let libraryUI = DPAGImagePickerController()
            libraryUI.setup()
            libraryUI.sourceType = .photoLibrary
            libraryUI.mediaTypes = [kUTTypeMovie as String, kUTTypeImage as String]
            libraryUI.delegate = self.imagePickerDelegate
            libraryUI.videoMaximumDuration = DPAGApplicationFacade.preferences.maxLengthForSentVideos
            libraryUI.videoQuality = DPAGApplicationFacade.preferences.videoQualityForSentVideos
            self.viewController?.present(libraryUI, animated: true, completion: nil)
        }
    }

    private func handleAddAttachmentLocation() {
        self.checkLocationAccess { granted in
            switch granted {
                case .permitted:
                    break
                case .notPermitted:
                    return
                case .notPermittedWithReason:
                    self.presentAlert(messageIdentifier: "noLocationView.title.titleTextView")
                    return
            }
            let viewController = DPAGApplicationFacadeUI.locationSendVC()
            viewController.delegate = self.locationSendingDelegate
            self.viewController?.navigationController?.pushViewController(viewController, animated: true)
        }
    }

    private func handleAddAttachmentContact() {
        var otherButtonActions = [UIAlertAction(titleIdentifier: "chats.sendContact.askForType.simsmeVCard", style: .default, handler: { [weak self] _ in
            if let nextVC = DPAGApplicationFacade.preferences.viewControllerContactSelectionForIdent(.dpagSelectContactSendingViewController, contactsSelected: DPAGSearchListSelection<DPAGContact>()), let nextVCConsumer = nextVC as? DPAGContactsSelectionSendingDelegateConsumer {
                nextVCConsumer.delegate = self?.contactSendingDelegate
                self?.viewController?.present(DPAGApplicationFacadeUIBase.navVC(rootViewController: nextVC), animated: true, completion: nil)
            }
        })]

        switch CNContactStore.authorizationStatus(for: .contacts) {
            case .authorized:
                otherButtonActions.append(UIAlertAction(titleIdentifier: "chats.sendContact.askForType.localVCard", style: .default, handler: { [weak self] _ in
                    let nextVC = DPAGApplicationFacadeUIContacts.personToSendSelectVC(delegateSending: self?.personSendingDelegate)
                    self?.viewController?.present(DPAGApplicationFacadeUIBase.navVC(rootViewController: nextVC), animated: true, completion: nil)
                }))
            case .notDetermined:
                CNContactStore().requestAccess(for: .contacts, completionHandler: { [weak self] granted, error in
                    if granted, error == nil {
                        DispatchQueue.main.async { [weak self] in
                            self?.handleAddAttachmentContact()
                        }
                    }
                })
                return
            case .denied, .restricted:
                break
            @unknown default:
                DPAGLog("Switch with unknown value: \(CNContactStore.authorizationStatus(for: .contacts).rawValue)", level: .warning)
        }

        self.viewController?.presentAlert(alertConfig: UIViewController.AlertConfig(titleIdentifier: "chats.sendContact.askForType.title", messageIdentifier: "chats.sendContact.askForType", cancelButtonAction: .cancelDefault, otherButtonActions: otherButtonActions))
    }

    private func handleAddAttachmentFile() {
        guard let view = self.viewController?.view else { return }
        let docPickerVC = DocumentPickerViewController(documentTypes: ["public.data", "public.content"], in: .import)
        UINavigationBar.appearance().tintColor = view.tintColor
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.black]
        docPickerVC.view.frame = view.bounds
        docPickerVC.delegate = self.documentPickerDelegate
        docPickerVC.modalPresentationStyle = .fullScreen
        self.viewController?.navigationController?.present(docPickerVC, animated: true, completion: nil)
    }

    private func presentAlert(messageIdentifier: String, otherButtonAction: UIAlertAction? = nil) {
        let actionOK = UIAlertAction(titleIdentifier: "permission.alert.settings", style: .default, handler: { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                AppConfig.openURL(url)
            }
        })
        if let otherButtonAction = otherButtonAction {
            self.viewController?.presentAlert(alertConfig: UIViewController.AlertConfig(messageIdentifier: messageIdentifier, cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK, otherButtonAction]))
        } else {
            self.viewController?.presentAlert(alertConfig: UIViewController.AlertConfig(messageIdentifier: messageIdentifier, cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))

        }
    }
}
