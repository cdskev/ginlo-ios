//
//  DPAGChatStreamBaseViewController+Attachment+AttachmentViewController.swift
// ginlo
//
//  Created by RBU on 09/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Contacts
import MobileCoreServices
import Photos
import SIMSmeCore
import UIKit

extension DPAGChatBaseViewController {
    @objc
    func handleAddAttachment() {
        let isTextViewFirstResponder = self.inputController?.textView?.isFirstResponder() ?? false
        let cancelHandler = {
            if isTextViewFirstResponder {
                self.performBlockOnMainThread { [weak self] in
                    self?.inputController?.textView?.becomeFirstResponder()
                }
            }
        }
        let showActionSheet = { [weak self] (options: [AlertOption]) in
            let alertController = UIAlertController.controller(options: options, sourceView: self?.inputController?.btnAdd)
            self?.presentAlertController(alertController)
        }
        let completion = {
            self.addAttachmentAlertHelper.addAttachmentOptions(completion: showActionSheet, cancelHandler: cancelHandler)
        }
        if isTextViewFirstResponder {
            self.inputController?.textView?.resignFirstResponder()
            self.inputController?.keyboardDidHideCompletion = completion
        } else {
            self.inputSendOptionsView?.close()
            self.inputController?.dismissSendOptionsView(animated: true, completion: completion)
        }
    }
}

extension DPAGChatBaseViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let fromAlbum = (picker.sourceType == .photoLibrary)
        guard let mediaType = info[.mediaType] as? String else { return }
        if mediaType == String(kUTTypeImage) {
            if let mediaAsset = info[.phAsset] as? PHAsset {
                let imageResource = DPAGMediaResource(type: .image)
                imageResource.mediaAsset = mediaAsset
                self.pushToSendImageViewController(imageResource: imageResource, mediaSourceType: fromAlbum ? .album : .camera, navigationController: picker, enableMultiSelection: DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation == nil)
            } else if let imageToSend = info[.originalImage] as? UIImage {
                let imageResource = DPAGMediaResource(type: .image)
                imageResource.mediaContent = (imageToSend.resizedForSending() ?? imageToSend).dataForSending()
                imageResource.preview = imageToSend.previewImage()
                self.pushToSendImageViewController(imageResource: imageResource, mediaSourceType: fromAlbum ? .album : .camera, navigationController: picker, enableMultiSelection: DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation == nil)
            } else {
                picker.dismiss(animated: false, completion: nil)
            }
        } else if mediaType == String(kUTTypeMovie) {
            guard let mediaURL = info[.mediaURL] as? URL else {
                picker.dismiss(animated: false, completion: nil)
                return
            }
            let asset = AVURLAsset(url: mediaURL)
            if CMTimeGetSeconds(asset.duration) > DPAGApplicationFacade.preferences.maxLengthForSentVideos + 1 {
                picker.dismiss(animated: false) { [weak self] in
                    self?.editVideo(mediaURL: mediaURL)
                }
                return
            }
            if DPAGApplicationFacade.preferences.alreadyAskedForMic == false {
                DPAGApplicationFacade.preferences.alreadyAskedForMic = true
            }
            var mediaSourceType: DPAGSendObjectMediaSourceType = fromAlbum ? .album : .camera
            if self.originalmediaSourceType != .none {
                mediaSourceType = self.originalmediaSourceType
            }
            guard let outputUrl = DPAGFunctionsGlobal.pathForCustomTMPDirectory()?.appendingPathComponent("sendingVideo" + DPAGFunctionsGlobal.uuid(), isDirectory: false).appendingPathExtension(mediaURL.pathExtension) else {
                picker.dismiss(animated: false, completion: nil)
                return
            }
            do {
                try FileManager.default.copyItem(at: mediaURL, to: outputUrl)
            } catch {
                DPAGLog(error, message: "error copying movie")
                picker.dismiss(animated: false, completion: nil)
                return
            }
            let mediaResource = DPAGMediaResource(type: .video)
            mediaResource.mediaUrl = outputUrl
            self.pushToSendVideoViewController(videoResource: mediaResource, mediaSourceType: mediaSourceType, navigationController: picker, enableMultiSelection: DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation == nil)
        }
    }
}

extension DPAGChatBaseViewController: UIDocumentPickerDelegate {
    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        let fileName = url.lastPathComponent
        let fileURLTemp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(fileName)
        _ = url.startAccessingSecurityScopedResource()
        let coordinator = NSFileCoordinator()
        let error: NSErrorPointer = nil
        coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: error, byAccessor: { _ in
            do {
                try FileManager.default.copyItem(at: url, to: fileURLTemp)
            } catch {
                DPAGLog(error, message: "error importing file")
                return
            }
        })
        url.stopAccessingSecurityScopedResource()
        if let fileSize = DPAGSendAVViewController.checkFileSize(fileURLTemp, showAlertVC: self, cleanUpFile: true) {
            var message = DPAGLocalizedString("chat.message.fileOpen.willSendTo.message")
            let persons = self.nameForFileOpen()
            message = String(format: message, fileURLTemp.lastPathComponent, DPAGFormatter.fileSize.string(fromByteCount: fileSize.int64Value), persons)
            let actionCancel = UIAlertAction(titleIdentifier: "res.cancel", style: .cancel, handler: { _ in
                do {
                    try FileManager.default.removeItem(at: fileURLTemp)
                } catch {
                    DPAGLog(error)
                }
            })
            let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in
                let sendOptions = DPAGSendMessageSendOptions(countDownSelfDestruction: nil, dateSelfDestruction: nil, dateToBeSend: nil, messagePriorityHigh: false)
                sendOptions.attachmentIsInternalCopy = false
                self?.sendFileWithWorker(fileURLTemp, sendMessageOptions: sendOptions)
            })
            self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "chat.message.fileOpen.willSendTo.title", message: message, cancelButtonAction: actionCancel, otherButtonActions: [actionOK]))
        }
    }
}

extension DPAGChatBaseViewController: DPAGMediaPickerDelegate {
    func pickingMediaFailedWithError(_ errorMessage: String) {
        self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
    }

    func didFinishedPickingMediaResource(_ mediaResource: DPAGMediaResource) {
        let type = mediaResource.mediaType
        if type == .image || type == .video {
            if type == .image {
                self.pushToSendImageViewController(imageResource: mediaResource, mediaSourceType: .simsme, navigationController: self.navigationController, enableMultiSelection: DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation == nil)
            } else {
                self.pushToSendVideoViewController(videoResource: mediaResource, mediaSourceType: .simsme, navigationController: self.navigationController, enableMultiSelection: DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation == nil)
            }
        } else if type == .voiceRec, let mediaContent = mediaResource.mediaContent {
            self.inputVoiceController?.updateVoiceRecData(mediaContent)
        } else if type == .file, mediaResource.attachment != nil {
            var message = DPAGLocalizedString("chat.message.fileOpen.willSendTo.message")
            let persons = self.nameForFileOpen()
            var fileSize = ""
            if let fileSizeStr = mediaResource.attachment?.additionalData?.fileSize, let fileSizeNum = Int64(fileSizeStr) {
                fileSize = DPAGFormatter.fileSize.string(fromByteCount: fileSizeNum)
            } else if let fileSizeNum = mediaResource.attachment?.additionalData?.fileSizeNum {
                fileSize = DPAGFormatter.fileSize.string(fromByteCount: fileSizeNum.int64Value)
            }
            message = String(format: message, mediaResource.attachment?.additionalData?.fileName ?? "noname", fileSize, persons)
            let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: { [weak self] _ in
                let sendOptions = DPAGSendMessageSendOptions(countDownSelfDestruction: nil, dateSelfDestruction: nil, dateToBeSend: nil, messagePriorityHigh: false)
                sendOptions.attachmentIsInternalCopy = true
                self?.sendMediaWithWorker(mediaResource, sendMessageOptions: sendOptions)
            })
            self.presentAlert(alertConfig: AlertConfig(titleIdentifier: "chat.message.fileOpen.willSendTo.title", messageIdentifier: message, cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
        }
    }
}

extension DPAGChatBaseViewController: UIVideoEditorControllerDelegate {
    func editVideo(mediaURL: URL) {
        guard UIVideoEditorController.canEditVideo(atPath: mediaURL.path) else {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "err_cannot_edit_video"))
            return
        }
        let videoEditor = UIVideoEditorController()
        videoEditor.isEditing = true
        videoEditor.videoMaximumDuration = DPAGApplicationFacade.preferences.maxLengthForSentVideos
        videoEditor.videoQuality = DPAGApplicationFacade.preferences.videoQualityForSentVideos
        videoEditor.delegate = self
        videoEditor.videoPath = mediaURL.path
        self.originalmediaSourceType = .file
        self.present(videoEditor, animated: false, completion: nil)
    }

    func videoEditorController(_ editor: UIVideoEditorController, didSaveEditedVideoToPath editedVideoPath: String) {
        editor.dismiss(animated: true) { [weak self] in
            let mediaURL = URL(fileURLWithPath: editedVideoPath)
            guard let outputUrl = DPAGFunctionsGlobal.pathForCustomTMPDirectory()?.appendingPathComponent("sendingVideo" + DPAGFunctionsGlobal.uuid(), isDirectory: false).appendingPathExtension(mediaURL.pathExtension) else { return }
            do {
                try FileManager.default.copyItem(at: mediaURL, to: outputUrl)
            } catch {
                DPAGLog(error, message: "error copying movie")
                return
            }
            guard let strongSelf = self else { return }
            let mediaResource = DPAGMediaResource(type: .video)
            mediaResource.mediaUrl = outputUrl
            strongSelf.pushToSendVideoViewController(videoResource: mediaResource, mediaSourceType: strongSelf.originalmediaSourceType, navigationController: strongSelf.navigationController, enableMultiSelection: DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation == nil)
            strongSelf.originalmediaSourceType = .none
        }
    }

    func videoEditorController(_ editor: UIVideoEditorController, didFailWithError _: Error) {
        // TODO: handle error
        editor.dismiss(animated: true, completion: nil)
        self.originalmediaSourceType = .none
    }

    func videoEditorControllerDidCancel(_ editor: UIVideoEditorController) {
        editor.dismiss(animated: true, completion: nil)
        self.originalmediaSourceType = .none
    }
}

extension DPAGChatBaseViewController: DPAGContactSendingDelegate {
    func send(contact: DPAGContact, asLocalVCard: Bool) {
        let contactCard = CNMutableContact()
        if let value = contact.nickName {
            contactCard.nickname = value
        }
        if let value = contact.firstName {
            contactCard.givenName = value
        }
        if let value = contact.lastName {
            contactCard.familyName = value
        }
        if let value = contact.department {
            contactCard.departmentName = value
        }
        if let value = contact.eMailAddress {
            contactCard.emailAddresses = [
                CNLabeledValue(label: CNLabelOther, value: value as NSString)
            ]
        }
        if let value = contact.phoneNumber {
            contactCard.phoneNumbers = [
                CNLabeledValue(label: CNLabelOther, value: CNPhoneNumber(stringValue: value))
            ]
        }
        if let value = contact.imageDataStr, let imageData = Data(base64Encoded: value, options: Data.Base64DecodingOptions.ignoreUnknownCharacters) {
            contactCard.imageData = imageData
        }
        if let accountID = contact.accountID {
            contactCard.note = "SIMSme-ID:" + accountID
        }
        do {
            var vCardData = try CNContactVCardSerialization.data(with: [contactCard])
            if let vCardString = String(data: vCardData, encoding: .utf8) {
                var vCardSplitted = vCardString.components(separatedBy: .newlines).filter { $0.isEmpty == false }
                if vCardSplitted.count > 2 {
                    let countOld = vCardSplitted.count
                    if vCardSplitted.contains(where: { (splitString) -> Bool in
                        splitString.starts(with: "NOTE:")
                    }) == false {
                        if let accountID = contact.accountID {
                            vCardSplitted.insert("NOTE:SIMSme-ID\\: " + accountID, at: vCardSplitted.count - 1)
                        }
                    }
                    if vCardSplitted.contains(where: { (splitString) -> Bool in
                        splitString.starts(with: "PHOTO;")
                    }) == false {
                        if let value = contact.imageDataStr {
                            vCardSplitted.insert("PHOTO;JPEG;ENCODING=BASE64:" + value, at: vCardSplitted.count - 1)
                        }
                    }
                    if countOld != vCardSplitted.count, let vCardDataNew = (vCardSplitted.joined(separator: "\r\n") + "\r\n").data(using: .utf8) {
                        vCardData = vCardDataNew
                    }
                }
            }
            if asLocalVCard {
                self.sendVCardWithData(vCardData, accountGuid: nil, accountID: nil)
            } else {
                self.sendVCardWithData(vCardData, accountGuid: contact.guid, accountID: contact.accountID)
            }
        } catch {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: error.localizedDescription))
        }
    }
}

extension DPAGChatBaseViewController: DPAGPersonSendingDelegate {
    func send(person: DPAGPerson) {
        let contactCard = CNMutableContact()

        if let value = person.firstName {
            contactCard.givenName = value
        }
        if let value = person.lastName {
            contactCard.familyName = value
        }
        for eMailAddress in person.eMailAddresses {
            contactCard.emailAddresses = [
                CNLabeledValue(label: eMailAddress.label, value: eMailAddress.value as NSString)
            ]
        }
        for phoneNumber in person.phoneNumbers {
            contactCard.phoneNumbers = [
                CNLabeledValue(label: phoneNumber.label, value: CNPhoneNumber(stringValue: phoneNumber.value))
            ]
        }
        if let value = person.image, let imageData = value.jpegData(compressionQuality: UIImage.compressionQualityDefault) {
            contactCard.imageData = imageData
        }
        do {
            var vCardData = try CNContactVCardSerialization.data(with: [contactCard])
            if let vCardString = String(data: vCardData, encoding: .utf8) {
                var vCardSplitted = vCardString.components(separatedBy: .newlines).filter { $0.isEmpty == false }
                if vCardSplitted.count > 2 {
                    let countOld = vCardSplitted.count
                    if vCardSplitted.contains(where: { (splitString) -> Bool in
                        splitString.starts(with: "PHOTO;")
                    }) == false {
                        if let value = person.image, let imageData = value.jpegData(compressionQuality: UIImage.compressionQualityDefault)?.base64EncodedString(options: .endLineWithCarriageReturn) {
                            vCardSplitted.insert("PHOTO;JPEG;ENCODING=BASE64:" + imageData, at: vCardSplitted.count - 1)
                        }
                    }
                    if countOld != vCardSplitted.count, let vCardDataNew = (vCardSplitted.joined(separator: "\r\n") + "\r\n").data(using: .utf8) {
                        vCardData = vCardDataNew
                    }
                }
            }

            self.sendVCardWithData(vCardData, accountGuid: nil, accountID: nil)
        } catch {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: error.localizedDescription))
        }
    }
}
