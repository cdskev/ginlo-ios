//
//  Alert+PictureButtonHandler.swift
//  SIMSmeUIBaseLib
//
//  Created by Maxime Bentin on 14.05.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation
import Photos

public struct PictureButtonHandler {
    private init() {}

    public static func handlePickPictureButtonTapped(viewControllerWithImagePicker: DPAGViewControllerWithKeyboard & UIImagePickerControllerDelegate & UINavigationControllerDelegate) {
        var buttons = [AlertOption]()
        let pickAlbumButton = AlertOption(title: DPAGLocalizedString("registration.button.pickFromAlbum"), style: .default, accesibilityIdentifier: "registration.button.pickFromAlbum") {
            DPAGUIHelper.startImagePickerWithDelegate(viewControllerWithImagePicker, controller: viewControllerWithImagePicker)
        }
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let pickCameraButton = AlertOption(title: DPAGLocalizedString("registration.button.pickFromCamera"), style: .default, accesibilityIdentifier: "registration.button.pickFromCamera") {
                DPAGUIHelper.startCameraControlWithDelegate(viewControllerWithImagePicker, controller: viewControllerWithImagePicker)
            }
            buttons.append(pickCameraButton)
        }
        let buttonCancel = AlertOption.cancelOption()
        buttons.append(pickAlbumButton)
        buttons.append(buttonCancel)
        let alertController = UIAlertController.controller(options: buttons, titleKey: "registration.headline.choosePictureSource", withStyle: .alert)
        viewControllerWithImagePicker.presentAlertController(alertController)
    }
}
