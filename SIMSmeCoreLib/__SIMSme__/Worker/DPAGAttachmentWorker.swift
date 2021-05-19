//
//  DPAGAttachmentWorker.swift
//  SIMSme
//
//  Created by RBU on 19/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import NSHash
import Photos

public protocol DPAGMediaAttachmentDelegate: AnyObject {
    func pickingMediaFinished(mediaResource: DPAGMediaResource?, errorMessage: String?)
}

public class DPAGAttachmentWorker: NSObject {
    static var shareTempUrl: URL?
    static var openInController: UIDocumentInteractionController?
    
    public class func getGroupEncData(attachment: DPAGDecryptedAttachment) -> Data? {
        if let attachmentData = DPAGAttachmentWorker.encryptedAttachmentData(guid: attachment.attachmentGuid) {
//            if attachment.isOwnMessage || attachment.messageType == .channel || (attachment.messageType == .group && attachment.attachmentHash == nil) {
//                if attachment.isOwnMessage || attachment.messageType == .channel || (attachmentData.sha1() == attachment.attachmentHash || attachmentData.sha256() == attachment.attachmentHash) || (attachment.messageType == .group && attachment.attachmentHash == nil) {
                return Data(base64Encoded: attachmentData, options: .ignoreUnknownCharacters)
//            }
        }
        return nil
    }
    
    public class func getGroupAttachmentData(attachment: DPAGDecryptedAttachment) -> Data? {
        var encMessageData: Data? = DPAGAttachmentWorker.getGroupEncData(attachment: attachment)
        var attachmentData: Data?

        // swiftlint:disable force_unwrapping
        if let decAesKey = attachment.encAesKey, encMessageData != nil, encMessageData!.count >= 16 {
            // swiftlint:disable force_unwrapping
            let iv = encMessageData!.subdata(in: 0 ..< 16).base64EncodedString()
            var attachmentDataEncrypted: Data?
            autoreleasepool {
                // swiftlint:disable force_unwrapping
                attachmentDataEncrypted = encMessageData!.subdata(in: 16 ..< encMessageData!.count)
                encMessageData = nil
            }
            if attachmentDataEncrypted != nil {
                let aesKeyDict = DPAGAesKeyDecrypted(aesKey: decAesKey, iv: iv)
                autoreleasepool {
                    // swiftlint:disable force_unwrapping
                    attachmentData = DPAGApplicationFacade.messageCryptoWorker.decryptAttachment(attachmentDataEncrypted!.base64EncodedString(), decAesKeyDict: aesKeyDict)
                    attachmentDataEncrypted = nil
                }
            }
        }
        return attachmentData
    }
    
    public class func getPrivateAttachmentData(attachment: DPAGDecryptedAttachment) -> Data? {
        if let attachmentString = DPAGAttachmentWorker.encryptedAttachment(guid: attachment.attachmentGuid) {
            if attachment.isOwnMessage || attachment.messageType == .channel || (attachmentString.sha1() == attachment.attachmentHash || attachmentString.sha256() == attachment.attachmentHash) || (attachment.messageType == .group && attachment.attachmentHash == nil) {
                return DPAGApplicationFacade.messageCryptoWorker.decryptAttachment(attachmentString as String, encAesKey: attachment.encAesKey)
            }
        }
        return nil
    }
    
    public class func getChannelAttachmentData(attachment: DPAGDecryptedAttachment) -> Data? {
        if let attachmentString = DPAGAttachmentWorker.encryptedAttachment(guid: attachment.attachmentGuid), let iv = attachment.encIv, let decAesKey = attachment.encAesKey {
            let aesKeyDict = DPAGAesKeyDecrypted(aesKey: decAesKey, iv: iv)
            if attachment.isOwnMessage || attachment.messageType == .channel || (attachmentString.sha1() == attachment.attachmentHash || attachmentString.sha256() == attachment.attachmentHash) || (attachment.messageType == .group && attachment.attachmentHash == nil) {
                return DPAGApplicationFacade.messageCryptoWorker.decryptAttachment(attachmentString as String, decAesKeyDict: aesKeyDict)
            }
        }
        return nil
    }
    
    public class func decryptMessageAttachment(attachment: DPAGDecryptedAttachment, completion: (Data?, String?) -> Void) {
        let encodingVersion = attachment.additionalData?.encodingVersion
        let encodingVersionNum = attachment.additionalData?.encodingVersionNum
        var attachmentData: Data?

        switch attachment.messageType {
            case .private:
                attachmentData = DPAGAttachmentWorker.getPrivateAttachmentData(attachment: attachment)
            case .group:
                attachmentData = DPAGAttachmentWorker.getGroupAttachmentData(attachment: attachment)
            case .channel:
                attachmentData = DPAGAttachmentWorker.getChannelAttachmentData(attachment: attachment)
            case .unknown:
                break
        }
        if attachmentData == nil {
            completion(nil, nil)
            return
        }
        if attachmentData?.count ?? 0 <= 0 {
            completion(nil, nil)
            return
        }
        if (encodingVersion ?? "0") == "1" || (encodingVersionNum ?? 0) == 1 {
            completion(attachmentData, nil)
            return
        }
        if attachmentData != nil {
            var attachmentStringDecrypted: String?
            autoreleasepool {
                // swiftlint:disable force_unwrapping
                attachmentStringDecrypted = String(data: attachmentData!, encoding: .utf8)
                attachmentData = nil
            }
            if attachmentStringDecrypted != nil  {
                // swiftlint:disable force_unwrapping
                completion(Data(base64Encoded: attachmentStringDecrypted!, options: .ignoreUnknownCharacters), nil)
                return
            }
        }
        completion(nil, "chat.encryption.hashInvalid")
    }

    public class func resourceFromAttachment(_ attachment: DPAGDecryptedAttachment) -> (mediaResource: DPAGMediaResource?, errorMessage: String?) {
        var mediaResource: DPAGMediaResource?
        var errorMessage: String?
        self.decryptMessageAttachment(attachment: attachment) { data, errorMessageBlock in
            errorMessage = errorMessageBlock
            if let data = data {
                let resource = DPAGMediaResource(type: attachment.attachmentType)
                resource.mediaContent = data
                resource.additionalData = attachment.additionalData
                resource.preview = attachment.thumb
                resource.attachment = attachment
                attachment.markAttachmentAsRead()
                mediaResource = resource
            }
        }
        return (mediaResource, errorMessage)
    }

    public class func loadAttachmentResponseBlockWithAttachmentLoader(_ loader: DPAGMediaAttachmentDelegate, attachment: DPAGDecryptedAttachment, loadingFinishedCompletion: @escaping (DPAGMediaResource?) -> Void) -> DPAGServiceResponseBlock {
        { [weak loader] responseObject, _, errorMessage in
            if let strongLoader = loader {
                if let errorMessage = errorMessage {
                    strongLoader.pickingMediaFinished(mediaResource: nil, errorMessage: errorMessage)
                } else if responseObject as? String != nil {
                    let erg = self.resourceFromAttachment(attachment)
                    if erg.errorMessage != nil {
                        strongLoader.pickingMediaFinished(mediaResource: nil, errorMessage: "chat.encryption.hashInvalid")
                    } else {
                        loadingFinishedCompletion(erg.mediaResource)
                    }
                }
            }
        }
    }

    public class func loadAttachment(_ guid: String?, forMessageGuid messageGuid: String?, progress downloadProgressBlock: DPAGProgressBlock?, withResponse response: DPAGServiceResponseBlock?) {
        guard let attachmentGuid = guid else {
            response?(nil, "ERR-0057", DPAGLocalizedString("service.ERR-0057"))
            return
        }
        if let attachment = self.encryptedAttachment(guid: attachmentGuid) {
            response?(attachment, nil, nil)
        } else if let attachmentPath = AttachmentHelper.attachmentFilePath(guid: attachmentGuid) {
            let responseBlock: DPAGServiceResponseBlock = { responseObject, errorCode, errorMessage in
                if errorMessage != nil {
                    response?(nil, errorCode, errorMessage)
                } else if responseObject is URL || responseObject is [String] {
                    if let responseURL = responseObject as? URL, let data = try? Data(contentsOf: responseURL) {
                        do {
                            self.removeEncryptedAttachment(guid: attachmentGuid)
                            let object = try JSONSerialization.jsonObject(with: data, options: [])
                            if let objectData = (object as? [String])?.first {
                                if let messageGuid = messageGuid {
                                    DPAGApplicationFacade.server.confirmAttachmentDownload(guids: [messageGuid], withResponse: nil)
                                }
                                self.saveEncryptedAttachment(objectData, forGuid: attachmentGuid)
                                response?(objectData, nil, nil)
                            } else if let responseDict = object as? [String: Any] {
                                if let errorObject = responseDict["MsgException"] as? [String: Any] {
                                    let errorCode = DPAGHelperEx.getErrorCode(errorObject: errorObject)
                                    let errorMessage = DPAGHelperEx.getErrorMessageIdentifier(errorObject: errorObject)
                                    response?(nil, errorCode, DPAGLocalizedString(errorMessage ?? "Invalid response"))
                                } else {
                                    response?(nil, "Invalid response", "Invalid response")
                                }
                            } else {
                                response?(nil, "Invalid response", "Invalid response")
                            }
                        } catch {
                            response?(nil, "Invalid response", "Invalid response")
                        }
                    } else if let object = (responseObject as? [String])?.first {
                        if let messageGuid = messageGuid {
                            DPAGApplicationFacade.server.confirmAttachmentDownload(guids: [messageGuid], withResponse: nil)
                        }
                        self.saveEncryptedAttachment(object, forGuid: attachmentGuid)
                        response?(object, nil, nil)
                    } else {
                        response?(nil, "Invalid response", "Invalid response")
                    }
                } else {
                    response?(nil, "Invalid response", "Invalid response")
                }
            }
            DPAGApplicationFacade.server.getAttachment(guid: attachmentGuid, progress: downloadProgressBlock, destination: { (_, _) -> URL in
                attachmentPath
            }, withResponse: responseBlock)
        }
    }

    @discardableResult
    public class func saveEncryptedAttachment(_ dataString: String, forGuid guid: String?) -> Bool {
        var success = false
        if let path = AttachmentHelper.attachmentFilePath(guid: guid) {
            DPAGLog("path \(path)")
            do {
                try dataString.write(to: path, atomically: true, encoding: .utf8)
                try (path as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
                success = true
            } catch {
                DPAGLog(error)
            }
        }
        return success
    }

    @discardableResult
    class func moveEncryptedAttachment(guidOld: String, guidNew: String) -> Bool {
        var success = false
        if let pathOld = AttachmentHelper.attachmentFilePath(guid: guidOld), let pathNew = AttachmentHelper.attachmentFilePath(guid: guidNew) {
            DPAGLog("pathOld \(pathOld) - pathNew \(pathNew)")
            do {
                try FileManager.default.copyItem(at: pathOld, to: pathNew)
                try (pathNew as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
                success = true
            } catch {
                DPAGLog(error)
            }
        }
        return success
    }

    @discardableResult
    public class func removeEncryptedAttachment(guid: String?) -> Bool {
        var success = false
        if let path = AttachmentHelper.attachmentFilePath(guid: guid) {
            DPAGLog("path \(path)")
            do {
                if FileManager.default.fileExists(atPath: path.path) {
                    try FileManager.default.removeItem(at: path)
                }
                success = true
            } catch let error as NSError {
                DPAGLog(error, message: "removeEncryptedAttachmentForGUID failed with error")
            }
        }
        return success
    }

    class func encryptedAttachment(guid: String?) -> String? {
        var attachment: String?
        if let path = AttachmentHelper.attachmentFilePath(guid: guid)?.path {
            do {
                attachment = try String(contentsOfFile: path, encoding: .utf8)
            } catch let error as NSError {
                DPAGLog(error)
            } catch {
                DPAGLog(error)
            }
        }
        return attachment
    }

    class func encryptedAttachmentData(guid: String?) -> Data? {
        var attachment: Data?
        if let url = AttachmentHelper.attachmentFilePath(guid: guid) {
            do {
                attachment = try Data(contentsOf: url)
            } catch let error as NSError {
                DPAGLog(error)
            } catch {
                DPAGLog(error)
            }
        }
        return attachment
    }

    public class func allAttachmentGuidsWithInternalCopies(_ withInternalCopies: Bool) -> [String] {
        do {
            if let documentsDirectory = DPAGConstantsGlobal.documentsDirectory {
                let documentsDirectoryContents = try FileManager.default.contentsOfDirectory(atPath: documentsDirectory)
                let attachmentPrefix = "att_"
                let attachmentPrefixInternalCopies = "att_" + DPAGGuidPrefix.temp.rawValue
                var allAttachments = [String]()
                for docDirContent in documentsDirectoryContents {
                    if docDirContent.hasPrefix(attachmentPrefix) {
                        if withInternalCopies == false {
                            if docDirContent.hasPrefix(attachmentPrefixInternalCopies) {
                                continue
                            }
                        }
                        let attachmentGuid = docDirContent.replacingOccurrences(of: attachmentPrefix, with: "")
                        allAttachments.append(attachmentGuid)
                    }
                }
                return allAttachments
            }
        } catch {
            DPAGLog(error)
        }
        return []
    }

    public class func cleanUpPrimaryData() {
        do {
            if let documentsDirectoryURL = DPAGConstantsGlobal.documentsDirectoryURL {
                let attachmentsDAO: AttachmentsDAOProtocol = AttachmentsDAO()
                let allAttachmentsCache: [String: String] = try attachmentsDAO.allAttachments()
                let documentsDirectoryURLContents = try FileManager.default.contentsOfDirectory(at: documentsDirectoryURL, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions())
                let attachmentPrefix = "att_"
                let now = Date()
                for docDirURLContent in documentsDirectoryURLContents {
                    let docDirURLContentPath = docDirURLContent.path
                    if let lastComponent = docDirURLContent.pathComponents.last, lastComponent.hasPrefix(attachmentPrefix) {
                        do {
                            let fileAttrs = try FileManager.default.attributesOfItem(atPath: docDirURLContentPath)
                            guard let creationDate = fileAttrs[.creationDate] as? Date else {
                                continue
                            }
                            if creationDate.days(before: now) > 7 {
                                let attachmentGuid = lastComponent.replacingOccurrences(of: attachmentPrefix, with: "")
                                if allAttachmentsCache[attachmentGuid] == nil {
                                    DPAGLog("remove attachment file for guid %@ with creation date \(creationDate)", attachmentGuid)
                                    do {
                                        try FileManager.default.removeItem(at: docDirURLContent)
                                    } catch let error as NSError {
                                        DPAGLog(error, message: "Remove for guid \(attachmentGuid) failed")
                                    }
                                }
                            }
                        } catch {
                            DPAGLog(error)
                        }
                    }
                }
            }
        } catch {
            DPAGLog(error)
        }
    }

    class func messageForAttachmentGuid(_ attachmentGuid: String) -> SIMSMessage? {
        let predicate = NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSMessage.attachment), rightExpression: NSExpression(forConstantValue: attachmentGuid), modifier: .direct, type: .equalTo, options: .caseInsensitive)
        return SIMSMessage.mr_findFirst(with: predicate)
    }

    public class func autoSave(attachment: DPAGDecryptedAttachment, force: Bool = false, buttonPressed: UIBarButtonItem? = nil) {
        guard attachment.attachmentType == .image || attachment.attachmentType == .video else { return }

        if force, DPAGApplicationFacade.preferences.canExportMedia {
            self.saveAttachmentToLibrary(attachment: attachment)
        } else if force == false, DPAGApplicationFacade.preferences.autoSaveMedia, DPAGApplicationFacade.preferences.canExportMedia, DPAGApplicationFacade.preferences.saveImagesToCameraRoll {
            DPAGApplicationFacade.persistance.saveWithBlock { localContext in
                guard let msg = SIMSMessage.findFirst(byGuid: attachment.messageGuid, in: localContext) else { return }
                guard (msg is SIMSChannelMessage) == false else { return }
                guard msg.fromAccountGuid != DPAGApplicationFacade.cache.account?.guid else { return }
                guard msg.getAdditionalData(key: "savedToCameraRoll") == nil else { return }
                self.saveAttachmentToLibrary(attachment: attachment)
                msg.setAdditionalData(key: "savedToCameraRoll", value: "true")
            }
        }
    }

    public class func shareAttachment(attachment: DPAGDecryptedAttachment, buttonPressed: UIBarButtonItem) {
        guard attachment.attachmentType == .image || attachment.attachmentType == .video else { return }
        if DPAGApplicationFacade.preferences.canExportMedia {
            self.shareAttachmentExternally(attachment: attachment, buttonPressed: buttonPressed)
        }
    }

    private class func shareAttachmentExternally(attachment: DPAGDecryptedAttachment, buttonPressed: UIBarButtonItem) {
        guard let outputUrl = self.prepareAttachment(attachment: attachment) else { return }
        let uti: String

        switch attachment.attachmentType {
            case .image:
                uti = "public.image"
            case .video:
                uti = "public.movie"
            case .file, .voiceRec, .unknown:
                uti = "public.data"
        }
        self.shareTempUrl = outputUrl
        if let outputUrl = self.shareTempUrl {
            self.openInController = UIDocumentInteractionController(url: outputUrl)
            self.openInController?.uti = uti
            self.openInController?.presentOptionsMenu(from: buttonPressed, animated: true)
        }
    }

    private class func saveAttachmentToLibrary(attachment: DPAGDecryptedAttachment) {
        guard let outputUrl = self.prepareAttachment(attachment: attachment) else { return }
        PHPhotoLibrary.shared().performChanges({
            switch attachment.attachmentType {
                case .image:
                    PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: outputUrl)
                case .video:
                    PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: outputUrl)
                case .file, .voiceRec, .unknown:
                    break
            }
        }, completionHandler: { _, error in
            try? FileManager.default.removeItem(at: outputUrl)
            if let error = error {
                DPAGLog(error, message: "Error saving to library")
            }
        })
    }
    
    private class func prepareAttachment(attachment: DPAGDecryptedAttachment) -> URL? {
        let pathExtension: String
        switch attachment.attachmentType {
            case .image:
                pathExtension = "jpeg"
            case .video:
                pathExtension = "mov"
            case .file, .voiceRec, .unknown:
                pathExtension = "tmp"
        }
        if let sTempUrl = self.shareTempUrl, FileManager.default.fileExists(atPath: sTempUrl.path) {
            do {
                try FileManager.default.removeItem(at: sTempUrl)
            } catch {
                DPAGLog(error)
            }
            self.shareTempUrl = nil
        }
        guard let outputUrl = DPAGFunctionsGlobal.pathForCustomTMPDirectory()?.appendingPathComponent("savedToCameraRoll", isDirectory: true).appendingPathComponent(attachment.attachmentGuid).appendingPathExtension(pathExtension) else { return nil }
        if FileManager.default.fileExists(atPath: outputUrl.path) == false {
            guard let attachmentString = self.encryptedAttachment(guid: attachment.attachmentGuid) else { return nil }
            let encodingVersion = attachment.additionalData?.encodingVersion
            let encodingVersionNum = attachment.additionalData?.encodingVersionNum
            var attachmentData: Data?
            let messageWorker = DPAGApplicationFacade.messageCryptoWorker
            if attachment.messageType == .private {
                attachmentData = messageWorker.decryptAttachment(attachmentString, encAesKey: attachment.encAesKey)
            } else if attachment.messageType == .group {
                if let encMessageData = Data(base64Encoded: attachmentString, options: .ignoreUnknownCharacters), let decAesKey = attachment.encAesKey {
                    if encMessageData.count >= 16 {
                        let iv = encMessageData.subdata(in: 0 ..< 16).base64EncodedString()
                        let attachmentStringEncrypted = encMessageData.subdata(in: 16 ..< encMessageData.count).base64EncodedString()
                        let aesKeyDict = DPAGAesKeyDecrypted(aesKey: decAesKey, iv: iv)
                        attachmentData = messageWorker.decryptAttachment(attachmentStringEncrypted, decAesKeyDict: aesKeyDict)
                    }
                }
            }
            guard let attachmentDataFound = attachmentData else { return nil }
            if (encodingVersion ?? "0") != "1", (encodingVersionNum ?? 0) != 1 {
                if let attachmentStringDecrypted = String(data: attachmentDataFound, encoding: .utf8) {
                    attachmentData = Data(base64Encoded: attachmentStringDecrypted, options: .ignoreUnknownCharacters)
                }
            }
            guard let attachmentDataToWrite = attachmentData else { return nil }
            do {
                try FileManager.default.createDirectory(at: outputUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                try attachmentDataToWrite.write(to: outputUrl)
            } catch {
                DPAGLog(error, message: "Error writing media for saving to library")
                return nil
            }
        }
        return outputUrl
    }

}
