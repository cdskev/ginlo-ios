//
//  DPAGSendMessageWorker.swift
//  SIMSme
//
//  Created by RBU on 20/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import CoreLocation
import Photos
import UIKit

enum DPAGErrorSendMessage: Error {
    case err463
    case errNoDeviceCrypto
}

class DPAGSendMessageWorkerInstance {
    var responseBlock: DPAGServiceResponseBlock?

    var receiver: DPAGSendMessageRecipient

    var messageText: String
    var messageDesc: String?

    var messageJson: String?

    var guidOutgoingMessage: String?
    var guidStream: String?

    var contentType: String
    var featureSet: String?

    var sendMessageOptions: DPAGSendMessageSendOptions?

    var additionalContentData: [String: Any]?

    var messageType: DPAGMessageType

    var sendConcurrent: Bool

    init(receiver: DPAGSendMessageRecipient, text: String, contentType: String, messageType: DPAGMessageType, streamGuid: String?) {
        self.messageText = text
        self.contentType = contentType
        self.messageType = messageType
        self.sendConcurrent = false
        self.receiver = receiver
        self.guidStream = streamGuid
    }
    
    public func clearMessageJson() {
        messageJson = nil
    }
}

class DPAGSendMessageInfo {
    var content: String
    var contentDesc: String?
    var contentType: String
    var attachment: Data?
    var additionalContentData: [String: Any]?

    fileprivate init(content: String, contentDesc: String?, contentType: String, attachment: Data?, additionalContentData: [String: Any]?) {
        self.content = content
        self.contentDesc = contentDesc
        self.contentType = contentType
        self.attachment = attachment
        self.additionalContentData = additionalContentData
    }

    class func loadMedia(_ contentObject: Any) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) {
        guard let media = contentObject as? DPAGMediaResource else { return (nil, nil) }
        switch media.mediaType {
        case .image:
            if let attachment = media.attachment {
                if var mediaContent = media.mediaContent ?? DPAGAttachmentWorker.resourceFromAttachment(attachment).mediaResource?.mediaContent {
                    var previewImageData = media.preview?.previewImageDataEncoded()
                    if previewImageData == nil, let decryptedMessage = DPAGApplicationFacade.cache.decryptedMessageFast(messageGuid: attachment.messageGuid) {
                        previewImageData = decryptedMessage.content
                    }
                    mediaContent = mediaContent.resizedForSending()
                    if previewImageData == nil {
                        previewImageData = mediaContent.previewImageDataEncoded()
                    }
                    if let encodedPreview = previewImageData {
                        let dataLength: String = "\(mediaContent.count)"
                        let additionalContentData: [String: Any] = [DPAGStrings.JSON.Message.AdditionalData.FILE_SIZE: dataLength]
                        return (DPAGSendMessageInfo(content: encodedPreview, contentDesc: media.text, contentType: DPAGStrings.JSON.Message.ContentType.IMAGE, attachment: mediaContent, additionalContentData: additionalContentData), nil)
                    }
                }
            } else if let imageAsset = media.mediaAsset {
                let options = PHImageRequestOptions()
                options.isSynchronous = true
                options.resizeMode = .fast
                var retVal: (DPAGSendMessageInfo?, String?)?
                let imageOptionsForSending = DPAGApplicationFacade.preferences.imageOptionsForSending
                PHImageManager.default().requestImage(for: imageAsset, targetSize: imageOptionsForSending.size, contentMode: .aspectFit, options: options) { image, _ in
                    if let image = image, let convertedImage = image.dataForSending(), let previewImageDataEncoded = image.previewImageDataEncoded() {
                        let dataLength: String = "\(convertedImage.count)"
                        let additionalContentData: [String: Any] = [DPAGStrings.JSON.Message.AdditionalData.FILE_SIZE: dataLength]
                        retVal = (DPAGSendMessageInfo(content: previewImageDataEncoded, contentDesc: media.text, contentType: DPAGStrings.JSON.Message.ContentType.IMAGE, attachment: convertedImage, additionalContentData: additionalContentData), nil)
                    }
                }
                if let retVal = retVal {
                    return retVal
                }
            } else if let mediaContent = media.mediaContent {
                if let encodedPreview = media.preview?.previewImageDataEncoded() ?? UIImage(data: mediaContent)?.previewImageDataEncoded() {
                    let dataLength: String = "\(mediaContent.count)"
                    let additionalContentData: [String: Any] = [DPAGStrings.JSON.Message.AdditionalData.FILE_SIZE: dataLength]
                    return (DPAGSendMessageInfo(content: encodedPreview, contentDesc: media.text, contentType: DPAGStrings.JSON.Message.ContentType.IMAGE, attachment: mediaContent, additionalContentData: additionalContentData), nil)
                }
            } else if let mediaUrl = media.mediaUrl, var data = try? Data(contentsOf: mediaUrl) {
                // Image from app's Inbox
                data = data.resizedForSending()
                let previewImage = data.previewImageDataEncoded()
                let dataLength: String = "\(data.count)"
                let additionalContentData: [String: Any] = [DPAGStrings.JSON.Message.AdditionalData.FILE_SIZE: dataLength]
                return (DPAGSendMessageInfo(content: previewImage, contentDesc: media.text, contentType: DPAGStrings.JSON.Message.ContentType.IMAGE, attachment: data, additionalContentData: additionalContentData), nil)
            }
        case .video:
            if let image = media.preview {
                let previewImage = image.previewImage()
                guard let encodedPreview = previewImage.previewImageDataEncoded() else { break }
                var mediaContent = media.mediaContent
                if mediaContent == nil, let videoUrl = media.mediaUrl {
                    mediaContent = self.convertVideo(videoUrl)
                }
                if mediaContent == nil, let attachment = media.attachment, let resource = DPAGAttachmentWorker.resourceFromAttachment(attachment).mediaResource {
                    mediaContent = resource.mediaContent
                }
                if let mediaContent = mediaContent {
                    let dataLength: String = "\(mediaContent.count)"
                    let additionalContentData: [String: Any] = [DPAGStrings.JSON.Message.AdditionalData.FILE_SIZE: dataLength]
                    return (DPAGSendMessageInfo(content: encodedPreview, contentDesc: media.text, contentType: DPAGStrings.JSON.Message.ContentType.VIDEO, attachment: mediaContent, additionalContentData: additionalContentData), nil)
                }
            }
        case .voiceRec:
            break
        case .file:
            if let data = media.mediaContent, let fileName = media.additionalData?.fileName {
                let fileSize = media.additionalData?.fileSize ?? ""
                let fileType = media.additionalData?.fileType ?? "application/octet-stream"
                let additionalContentData = [
                    DPAGStrings.JSON.Message.AdditionalData.FILE_NAME: fileName,
                    DPAGStrings.JSON.Message.AdditionalData.FILE_SIZE: fileSize,
                    DPAGStrings.JSON.Message.AdditionalData.FILE_TYPE: fileType
                ]
                return (DPAGSendMessageInfo(content: fileName, contentDesc: media.text, contentType: DPAGStrings.JSON.Message.ContentType.FILE, attachment: data, additionalContentData: additionalContentData), nil)
            } else if let attachment = media.attachment, let fileName = media.attachment?.additionalData?.fileName {
                let fileSize = media.attachment?.additionalData?.fileSize ?? ""
                let fileType = media.attachment?.additionalData?.fileType ?? "application/octet-stream"
                let additionalContentData = [
                    DPAGStrings.JSON.Message.AdditionalData.FILE_NAME: fileName,
                    DPAGStrings.JSON.Message.AdditionalData.FILE_SIZE: fileSize,
                    DPAGStrings.JSON.Message.AdditionalData.FILE_TYPE: fileType
                ]
                var attachmentData: Data?
                var errorMessage: String?
                DPAGAttachmentWorker.decryptMessageAttachment(attachment: attachment) { data, error in
                    errorMessage = error
                    attachmentData = data
                }
                if let errorMessage = errorMessage {
                    return (nil, errorMessage)
                }
                return (DPAGSendMessageInfo(content: fileName, contentDesc: media.text, contentType: DPAGStrings.JSON.Message.ContentType.FILE, attachment: attachmentData, additionalContentData: additionalContentData), nil)
            }
        default:
            break
        }
        return (nil, nil)
    }

    private class func convertVideo(_ videoURL: URL) -> Data? {
        let asset = AVURLAsset(url: videoURL)
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)
        guard compatiblePresets.contains(AVAssetExportPresetLowQuality) else { return nil }
        let exportSession = DPAGAVAssetExportSession(asset: asset)
        guard let outputUrl = DPAGFunctionsGlobal.pathForCustomTMPDirectory()?.appendingPathComponent("tempVideo", isDirectory: false).appendingPathExtension("mpeg4") else { return nil }
        if FileManager.default.fileExists(atPath: outputUrl.path) {
            do {
                try FileManager.default.removeItem(at: outputUrl)
            } catch {
                DPAGLog(error)
            }
        }
        defer {
            do {
                try FileManager.default.removeItem(at: outputUrl)
            } catch {
                DPAGLog(error)
            }
        }
        exportSession.outputURL = outputUrl
        exportSession.outputFileType = .mp4
        var videoOptionsForSending = DPAGApplicationFacade.preferences.videoOptionsForSending
        if let videoTrack = asset.tracks(withMediaType: .video).first {
            var naturalSize = videoTrack.naturalSize
            let transform = videoTrack.preferredTransform
            let videoAngleInDegree = abs(round(Double(atan2(transform.b, transform.a) * 180) / Double.pi))
            if videoAngleInDegree == 90 {
                let width = naturalSize.width
                naturalSize.width = naturalSize.height
                naturalSize.height = width
            }
            if (videoOptionsForSending.size.width * videoOptionsForSending.size.height) < (naturalSize.width * naturalSize.height) {
                let part = (videoOptionsForSending.size.width * videoOptionsForSending.size.height) / (naturalSize.width / naturalSize.height)
                let height = sqrt(part)
                let width = height * (naturalSize.width / naturalSize.height)
                videoOptionsForSending.size.width = width
                videoOptionsForSending.size.height = height
            } else {
                videoOptionsForSending.size = naturalSize
            }
            if naturalSize.width <= videoOptionsForSending.size.width, naturalSize.height <= videoOptionsForSending.size.height, floor(videoTrack.nominalFrameRate) <= videoOptionsForSending.fps, videoTrack.estimatedDataRate <= videoOptionsForSending.bitrate {
                return (try? Data(contentsOf: videoURL))
            }
        }
        videoOptionsForSending.size.width = floor(videoOptionsForSending.size.width / 16.0) * 16
        videoOptionsForSending.size.height = floor(videoOptionsForSending.size.height / 16.0) * 16
        exportSession.videoSettings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoOptionsForSending.size.width,
            AVVideoHeightKey: videoOptionsForSending.size.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: NSNumber(value: videoOptionsForSending.bitrate),
                AVVideoProfileLevelKey: videoOptionsForSending.profileLevel,
                AVVideoMaxKeyFrameIntervalKey: NSNumber(value: videoOptionsForSending.fps)
            ]
        ]
        exportSession.audioSettings = [
            AVFormatIDKey: NSNumber(value: kAudioFormatMPEG4AAC as UInt32),
            AVNumberOfChannelsKey: NSNumber(value: 1), // Mono
            AVSampleRateKey: NSNumber(value: 44_100),
            AVEncoderBitRateKey: NSNumber(value: 64_000)
        ]
        exportSession.shouldOptimizeForNetworkUse = true
        let sema = DispatchSemaphore(value: 0)
        exportSession.exportAsynchronouslyWithCompletionHandler {
            sema.signal()
        }
        _ = sema.wait(timeout: DispatchTime.distantFuture)
        if exportSession.sessionStatus() == .completed {
            return (try? Data(contentsOf: outputUrl))
        } else if exportSession.sessionStatus() == .failed {
            if let error = exportSession.sessionError() {
                DPAGLog("error convertVideo: \(error)")
            }
        }
        return nil
    }

    class func loadText(_ contentObject: Any) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) {
        guard let text = contentObject as? String else { return (nil, nil) }
        return (DPAGSendMessageInfo(content: text, contentDesc: nil, contentType: DPAGStrings.JSON.Message.ContentType.PLAIN, attachment: nil, additionalContentData: nil), nil)
    }

    class func loadCallInvitation(_ contentObject: Any) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) {
        guard let text = contentObject as? String else { return (nil, nil) }
        return (DPAGSendMessageInfo(content: text, contentDesc: nil, contentType: DPAGStrings.JSON.Message.ContentType.AV_CALL_INVITATION, attachment: nil, additionalContentData: nil), nil)
    }

    class func loadControlMsgNG(_ contentObject: Any) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) {
        guard let text = contentObject as? String else { return (nil, nil) }
        return (DPAGSendMessageInfo(content: text, contentDesc: nil, contentType: DPAGStrings.JSON.Message.ContentType.CONTROL_MSG_NG, attachment: nil, additionalContentData: nil), nil)
    }

    class func loadLocation(_ contentObject: Any) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) {
        guard let location = contentObject as? DPAGLocationResource else { return (nil, nil) }
        if let encodedPreview = location.preview.jpegData(compressionQuality: 0.8)?.base64EncodedString(options: .lineLength64Characters) {
            let locationDict: [String: Any] = [
                DPAGStrings.JSON.Location.PREVIEW: encodedPreview,
                DPAGStrings.JSON.Location.LATITUDE: NSNumber(value: location.location.coordinate.latitude),
                DPAGStrings.JSON.Location.LONGITUDE: NSNumber(value: location.location.coordinate.longitude),
                DPAGStrings.JSON.Location.ADDRESS: location.address
            ]
            if let json = locationDict.JSONString {
                return (DPAGSendMessageInfo(content: json, contentDesc: nil, contentType: DPAGStrings.JSON.Message.ContentType.LOCATION, attachment: nil, additionalContentData: nil), nil)
            } else {
                return (nil, "internal.error.466")
            }
        }
        return (nil, nil)
    }

    class func loadVCard(_ contentObject: Any, accountGuid: String?, accountID: String?) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) {
        guard let vCardData = contentObject as? Data else { return (nil, nil) }
        guard let text = String(data: vCardData, encoding: .utf8) else { return (nil, nil) }
        var additionalContentData: [String: Any]?
        if let accountGuid = accountGuid, let accountID = accountID {
            additionalContentData = ["accountGuid": accountGuid, "accountID": accountID]
        }
        return (DPAGSendMessageInfo(content: text, contentDesc: nil, contentType: DPAGStrings.JSON.Message.ContentType.CONTACT, attachment: nil, additionalContentData: additionalContentData), nil)
    }

    class func loadVoiceRec(_ contentObject: Any) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) {
        guard let voiceRec = contentObject as? DPAGVoiceRecResource else { return (nil, nil) }
        let encodedPreview = "{\"duration\": \(voiceRec.duration), \"waveform\": []}"
        let dataLength: String = "\(voiceRec.voiceRecData.count)"
        let additionalContentData: [String: Any] = [DPAGStrings.JSON.Message.AdditionalData.FILE_SIZE: dataLength]
        return (DPAGSendMessageInfo(content: encodedPreview, contentDesc: nil, contentType: DPAGStrings.JSON.Message.ContentType.VOICEREC, attachment: voiceRec.voiceRecData, additionalContentData: additionalContentData), nil)
    }

    class func loadFile(_ contentObject: Any) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) {
        guard let fileURL = contentObject as? URL else { return (nil, nil) }
        let fileName = fileURL.lastPathComponent
        guard let fileData = try? Data(contentsOf: fileURL) else { return (nil, nil) }
        if fileData.count <= 0 || UInt64(fileData.count) > DPAGApplicationFacade.preferences.maxFileSize || (AppConfig.isShareExtension && !DPAGHelper.canPerformRAMBasedJSON(ofSize: UInt(fileData.count))) {
            return (nil, "chat.message.fileOpen.error.fileSize.message")
        }
        let contentMimeType = DPAGHelper.mimeType(forExtension: fileURL.pathExtension)
        let dataLength: String = "\(fileData.count)"
        let additionalContentData: [String: Any] = [
            DPAGStrings.JSON.Message.AdditionalData.FILE_NAME: fileURL.lastPathComponent,
            DPAGStrings.JSON.Message.AdditionalData.FILE_SIZE: dataLength,
            DPAGStrings.JSON.Message.AdditionalData.FILE_TYPE: contentMimeType ?? "application/octet-stream"
        ]
        return (DPAGSendMessageInfo(content: fileName, contentDesc: nil, contentType: DPAGStrings.JSON.Message.ContentType.FILE, attachment: fileData, additionalContentData: additionalContentData), nil)
    }
}

public protocol DPAGSendMessageWorkerProtocol: AnyObject {
    func sendText(_ text: String, toRecipients recipientGuids: [DPAGSendMessageRecipient], sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, response: DPAGServiceResponseBlock?)

    func sendCallInvite(room: String, password: String, server: String, toRecipients recipientGuids: [DPAGSendMessageRecipient], sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, response: DPAGServiceResponseBlock?)
    func sendAVCallRejected(room: String, password: String, server: String, toRecipients recipientGuids: [DPAGSendMessageRecipient], sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, response: DPAGServiceResponseBlock?)
    func sendAVCallAccepted(room: String, password: String, server: String, toRecipients recipientGuids: [DPAGSendMessageRecipient], sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, response: DPAGServiceResponseBlock?)

    func sendLocation(_ preview: UIImage, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, latitude location: CLLocation, address: String, toRecipients recipientGuids: [DPAGSendMessageRecipient], response: DPAGServiceResponseBlock?)
    func sendVCard(_ data: Data, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, toRecipients recipientGuids: [DPAGSendMessageRecipient], response: DPAGServiceResponseBlock?, accountGuid: String?, accountID: String?)
    func sendVoiceRec(_ data: Data, duration: TimeInterval, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, toRecipients recipientGuids: [DPAGSendMessageRecipient], response: DPAGServiceResponseBlock?)
    func sendFile(_ fileURL: URL, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, toRecipients recipientGuids: [DPAGSendMessageRecipient], response: DPAGServiceResponseBlock?)
    func sendMedias(_ medias: [DPAGMediaResource], sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, toRecipients recipientGuids: [DPAGSendMessageRecipient], response: DPAGServiceResponseBlock?)

    func resendMessage(msgGuid messageToResend: String, responseBlock: DPAGServiceResponseBlock?)
}

class DPAGSendMessageWorker: NSObject, DPAGSendMessageWorkerProtocol {
    static let limitSendingSemaphore = DispatchSemaphore(value: 4)
    let sendMessageDAO: SendMessageDAOProtocol = SendMessageDAO()
    public func sendText(_ text: String, toRecipients recipientGuids: [DPAGSendMessageRecipient], sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, response: DPAGServiceResponseBlock?) {
        self.sendMessage([text], recipients: recipientGuids, sendMessageOptions: sendOptions, featureSet: nil, sendMessageInfoBlock: { (contentObject, _) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) in
            DPAGSendMessageInfo.loadText(contentObject)
        }, response: response)
    }

    public func sendCallInvite(room: String, password: String, server: String, toRecipients recipientGuids: [DPAGSendMessageRecipient], sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, response: DPAGServiceResponseBlock?) {
        let message = password + "@" + room + "@" + server
        self.sendMessage([message], recipients: recipientGuids, sendMessageOptions: sendOptions, featureSet: nil, sendMessageInfoBlock: { (contentObject, _) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) in
            DPAGSendMessageInfo.loadCallInvitation(contentObject)
        }, response: response)
    }

    public func sendAVCallRejected(room: String, password: String, server: String, toRecipients recipientGuids: [DPAGSendMessageRecipient], sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, response: DPAGServiceResponseBlock?) {
        let message: String = "{ \"message\": \"avCallRejected\", \"orig-message-type\": \"text/x-ginlo-call-invite\", \"orig-message-identifier\":" + "\"" + password + "@" + room + "@" + server + "\"" + "\"additional-payload\": \"me\"}"
        self.sendMessage([message], recipients: recipientGuids, sendMessageOptions: sendOptions, featureSet: nil, sendMessageInfoBlock: { (contentObject, _) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) in
            DPAGSendMessageInfo.loadControlMsgNG(contentObject)
        }, response: response)
    }

    public func sendAVCallAccepted(room: String, password: String, server: String, toRecipients recipientGuids: [DPAGSendMessageRecipient], sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, response: DPAGServiceResponseBlock?) {
        let message: String = "{ \"message\": \"avCallAccepted\", \"orig-message-type\": \"text/x-ginlo-call-invite\", \"orig-message-identifier\":" + "\"" + password + "@" + room + "@" + server + "\"" + "\"additional-payload\": \"me\"}"
        self.sendMessage([message], recipients: recipientGuids, sendMessageOptions: sendOptions, featureSet: nil, sendMessageInfoBlock: { (contentObject, _) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) in
            DPAGSendMessageInfo.loadControlMsgNG(contentObject)
        }, response: response)
    }

    public func sendLocation(_ preview: UIImage, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, latitude location: CLLocation, address: String, toRecipients recipientGuids: [DPAGSendMessageRecipient], response: DPAGServiceResponseBlock?) {
        let resource = DPAGLocationResource(preview: preview, location: location, address: address)
        self.sendMessage([resource], recipients: recipientGuids, sendMessageOptions: sendOptions, featureSet: nil, sendMessageInfoBlock: { (contentObject, _) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) in
            DPAGSendMessageInfo.loadLocation(contentObject)
        }, response: response)
    }

    public func sendVCard(_ data: Data, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, toRecipients recipientGuids: [DPAGSendMessageRecipient], response: DPAGServiceResponseBlock?, accountGuid: String?, accountID: String?) {
        self.sendMessage([data], recipients: recipientGuids, sendMessageOptions: sendOptions, featureSet: nil, sendMessageInfoBlock: { (contentObject, _) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) in
            DPAGSendMessageInfo.loadVCard(contentObject, accountGuid: accountGuid, accountID: accountID)
        }, response: response)
    }

    public func sendVoiceRec(_ data: Data, duration: TimeInterval, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, toRecipients recipientGuids: [DPAGSendMessageRecipient], response: DPAGServiceResponseBlock?) {
        let resource = DPAGVoiceRecResource(voiceRecData: data, duration: duration)
        self.sendMessage([resource], recipients: recipientGuids, sendMessageOptions: sendOptions, featureSet: nil, sendMessageInfoBlock: { (contentObject, _) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) in
            DPAGSendMessageInfo.loadVoiceRec(contentObject)
        }, response: response)
    }

    public func sendFile(_ fileURL: URL, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, toRecipients recipientGuids: [DPAGSendMessageRecipient], response: DPAGServiceResponseBlock?) {
        self.sendMessage([fileURL], recipients: recipientGuids, sendMessageOptions: sendOptions, featureSet: "\(DPAGMessageFeatureVersion.file.rawValue)", sendMessageInfoBlock: { (contentObject, _) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) in
            DPAGSendMessageInfo.loadFile(contentObject)
        }, response: response)
    }

    public func sendMedias(_ medias: [DPAGMediaResource], sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, toRecipients recipientGuids: [DPAGSendMessageRecipient], response: DPAGServiceResponseBlock?) {
        self.sendMessage(medias, recipients: recipientGuids, sendMessageOptions: sendOptions, featureSet: "\(DPAGMessageFeatureVersion.file.rawValue)", sendMessageInfoBlock: { (contentObject, _) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?) in
            DPAGSendMessageInfo.loadMedia(contentObject)
        }, response: response)
    }

    private func createMessageInstance(sendMessageInfo: DPAGSendMessageInfo, isGroup: Bool, recipient: DPAGSendMessageRecipient, sendOptionsRecipients: DPAGSendMessageSendOptions?, featureSet: String?, serviceResponseBlock: DPAGServiceResponseBlock?) -> DPAGSendMessageWorkerInstance {
        let msgInstance = DPAGSendMessageWorkerInstance(receiver: recipient, text: sendMessageInfo.content, contentType: sendMessageInfo.contentType, messageType: isGroup ? .group : .private, streamGuid: isGroup ? recipient.recipientGuid : recipient.contact?.streamGuid)
        msgInstance.messageDesc = sendMessageInfo.contentDesc
        msgInstance.sendMessageOptions = sendOptionsRecipients?.copy() as? DPAGSendMessageSendOptions
        msgInstance.responseBlock = serviceResponseBlock
        msgInstance.featureSet = featureSet
        msgInstance.additionalContentData = sendMessageInfo.additionalContentData
        return msgInstance
    }

    // START HERE...
    private func createOutgoingMessage(msgInstance: DPAGSendMessageWorkerInstance, sendMessageInfo: DPAGSendMessageInfo?, isGroup: Bool) throws {
        if isGroup {
            try self.sendMessageDAO.createOutgoingGroupMessage(msgInstance: msgInstance, sendMessageInfo: sendMessageInfo)
        } else {
            try self.sendMessageDAO.createOutgoingPrivateMessage(msgInstance: msgInstance, sendMessageInfo: sendMessageInfo)
        }
    }

    private func sendMessageInstance(msgInstance: DPAGSendMessageWorkerInstance, isGroup _: Bool, isMultiReceiverMessage: Bool) throws {
        let limit = DPAGSendMessageWorker.limitSendingSemaphore
        let block: DPAGServiceResponseBlock = { responseObject, errorCode, errorMessage in
            DPAGLog("Release Sending Lock")
            limit.signal()
            if let errorMessage = errorMessage {
                self.sendingMessageFailed(msgInstance: msgInstance, errorCode: errorCode, errorMessage: errorMessage)
            } else {
                self.sendingMessageSucceeded(msgInstance: msgInstance, response: responseObject, callResponseBlock: true, isMultiReceiverMessage: isMultiReceiverMessage)
            }
        }
        DPAGLog("Start Sending Lock")
        let timeUp = DispatchTime.now() + Double(Int64(60 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)
        if limit.wait(timeout: timeUp) == DispatchTimeoutResult.timedOut {
            DPAGLog("Timed Out Sending Lock")
        }
        if msgInstance.messageType == .private {
            try self.sendPrivateMessage(msgInstance: msgInstance, serviceResponseBlock: block)
        } else {
            try self.sendGroupMessage(msgInstance: msgInstance, serviceResponseBlock: block)
        }
    }

    // IMDAT: SENDMESSAGE
    private func sendMessage(_ contents: [Any], recipients: [DPAGSendMessageRecipient], sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, featureSet: String?, sendMessageInfoBlock: (_ contentObject: Any, _ recipient: String) -> (sendMessageInfo: DPAGSendMessageInfo?, errorMessage: String?), response serviceResponseBlock: DPAGServiceResponseBlock?) {
        do {
            var msgInstances = [DPAGSendMessageWorkerInstance]()
            var msgInstancesGuids = [String]()
            for contentObject in contents {
                let sendOptionsRecipients = sendOptions?.copy() as? DPAGSendMessageSendOptions
                for recipient in recipients {
                    var sendMessageInfo: DPAGSendMessageInfo?
                    let errorBlock = {
                        let messagesDAO: MessagesDAOProtocol = MessagesDAO()
                        messagesDAO.deleteMessageInstances(msgInstancesGuids: msgInstancesGuids)
                    }
                    let isGroup = recipient.isGroup
                    autoreleasepool {
                        let sendMessageInfoResult = sendMessageInfoBlock(contentObject, recipient.recipientGuid)
                        if let errorMessage = sendMessageInfoResult.errorMessage {
                            errorBlock()
                            serviceResponseBlock?(nil, errorMessage, errorMessage)
                            return
                        }
                        sendMessageInfo = sendMessageInfoResult.sendMessageInfo
                    }
                    if let sendMessageInfo = sendMessageInfo {
                        let msgInstance = self.createMessageInstance(sendMessageInfo: sendMessageInfo, isGroup: isGroup, recipient: recipient, sendOptionsRecipients: sendOptionsRecipients, featureSet: featureSet, serviceResponseBlock: serviceResponseBlock)
                        do {
                            try self.createOutgoingMessage(msgInstance: msgInstance, sendMessageInfo: sendMessageInfo, isGroup: isGroup)
                        } catch DPAGErrorCreateMessage.err465 {
                            errorBlock()
                            serviceResponseBlock?(nil, "internal.error.465", "internal.error.465")
                            return
                        } catch {
                            DPAGLog(error)
                        }
                        if msgInstance.guidOutgoingMessage == nil {
                            errorBlock()
                            serviceResponseBlock?(nil, "service.tryAgainLater", "service.tryAgainLater")
                            return
                        }
                        if recipients.count <= 4 {
                            msgInstances.append(msgInstance)
                        }
                        if let guidOutgoingMessage = msgInstance.guidOutgoingMessage {
                            msgInstancesGuids.append(guidOutgoingMessage)
                        }
                        sendOptionsRecipients?.attachmentIsInternalCopy = true
                    }
                }
            }
            for msgInstance in msgInstances {
                try self.sendMessageInstance(msgInstance: msgInstance, isGroup: msgInstance.messageType != .private, isMultiReceiverMessage: recipients.count > 1)
            }
            if msgInstances.count == 0 {
                for msgGuid in msgInstancesGuids {
                    try autoreleasepool {
                        let msgInstance = DPAGSendMessageWorkerInstance(receiver: DPAGSendMessageRecipient.NULL_RECEIVER, text: "", contentType: "", messageType: .private, streamGuid: nil)
                        msgInstance.responseBlock = serviceResponseBlock
                        msgInstance.guidOutgoingMessage = msgGuid
                        do {
                            try self.sendMessageDAO.updateResendMessage(msgGuid: msgGuid, withMsgInstance: msgInstance, forInitialSending: true)
                        } catch DPAGErrorSendMessage.err463 {
                            // serviceResponseBlock?(nil, "internal.error.463", "internal.error.463")
                        } catch {}
                        if msgInstance.messageJson == nil {
                            return
                        }
                        try self.sendMessageInstance(msgInstance: msgInstance, isGroup: msgInstance.messageType != .private, isMultiReceiverMessage: recipients.count > 1)
                    }
                }
            }
        } catch {
            serviceResponseBlock?(nil, error.localizedDescription, error.localizedDescription)
        }
    }

    private func sendGroupMessage(msgInstance: DPAGSendMessageWorkerInstance, serviceResponseBlock: @escaping DPAGServiceResponseBlock) throws {
        let guidGroupStream = msgInstance.receiver.recipientGuid
        let recipientFound = self.sendMessageDAO.groupExists(groupGuid: guidGroupStream)

        if  !recipientFound || msgInstance.messageJson == nil {
            serviceResponseBlock(nil, nil, nil)
            return
        }
        let sendConcurrent = msgInstance.sendConcurrent

        if let sendDate = msgInstance.sendMessageOptions?.dateToBeSend {
            try DPAGApplicationFacade.server.sendTimedGroupMessage(msgInstance: msgInstance, sendTime: sendDate, concurrent: sendConcurrent, requestInBackgroundId: msgInstance.guidOutgoingMessage, withResponse: serviceResponseBlock)
        } else {
            try DPAGApplicationFacade.server.sendGroupMessage(msgInstance: msgInstance, concurrent: sendConcurrent, requestInBackgroundId: msgInstance.guidOutgoingMessage, withResponse: serviceResponseBlock)
        }
    }

    private func sendPrivateMessage(msgInstance: DPAGSendMessageWorkerInstance, serviceResponseBlock: @escaping DPAGServiceResponseBlock) throws {
        let guidRecipient = msgInstance.receiver.recipientGuid
        let recipientFound = self.sendMessageDAO.recipientExists(recipientGuid: guidRecipient)

        if  !recipientFound || msgInstance.messageJson == nil {
            serviceResponseBlock(nil, nil, nil)
            return
        }
        let sendConcurrent = msgInstance.sendConcurrent
        if let sendDate = msgInstance.sendMessageOptions?.dateToBeSend {
            try DPAGApplicationFacade.server.sendTimedMessage(msgInstance: msgInstance, sendTime: sendDate, concurrent: sendConcurrent, requestInBackgroundId: msgInstance.guidOutgoingMessage, withResponse: serviceResponseBlock)
        } else {
            try DPAGApplicationFacade.server.sendMessage(msgInstance: msgInstance, concurrent: sendConcurrent, requestInBackgroundId: msgInstance.guidOutgoingMessage, withResponse: serviceResponseBlock)
        }
    }

    private func sendingMessageSucceeded(msgInstance: DPAGSendMessageWorkerInstance, response responseObject: Any?, callResponseBlock: Bool, isMultiReceiverMessage: Bool) {
        guard let guidOutgoingMessage = msgInstance.guidOutgoingMessage else {
            if callResponseBlock {
                msgInstance.responseBlock?(nil, nil, nil)
            }
            return
        }
        DPAGApplicationFacade.cache.removeMessage(guid: guidOutgoingMessage)

        guard let responseMessageDict = responseObject as? [[AnyHashable: Any]], let messageConfirmSend = (try? DictionaryArrayDecoder().decode([DPAGMessageReceivedInternal.ConfirmMessageSend].self, from: responseMessageDict))?.first?.item else {
            // Response is nil, there's no need to update the Core Data objects
            if callResponseBlock {
                msgInstance.responseBlock?(guidOutgoingMessage, nil, nil)
            }
            return
        }

        DPAGApplicationFacade.preferences.setChatPrivateCreationAccountSendMessage(msgInstance.receiver.recipientGuid)

        guard msgInstance.guidOutgoingMessage != nil, DPAGFormatter.date.date(from: messageConfirmSend.dateSent) != nil else {
            // The message was probably deleted and this worker was not properly stopped!
            if callResponseBlock {
                msgInstance.responseBlock?(nil, nil, nil)
            }
            return
        }

        var errorCode: String?
        var errorMessage: String?
        _ = msgInstance.contentType
        // We'll save a message only if it is NOT an outgoing CONTROL_MSG_NG
        if msgInstance.contentType == DPAGStrings.JSON.Message.ContentType.CONTROL_MSG_NG {
            if let guidOutgoingMessage = msgInstance.guidOutgoingMessage {
                DPAGApplicationFacade.persistance.deleteMessageForStream(guidOutgoingMessage)
            }
            DPAGApplicationFacade.persistance.deleteMessageForStream(messageConfirmSend.guid)
        } else if let lastMessageDateSystem = self.sendMessageDAO.sendingMessageSucceeded(msgInstance: msgInstance, messageConfirmSend: messageConfirmSend)?.addingTimeInterval(1) {
            if let notSent = messageConfirmSend.notSent, notSent.isEmpty == false {
                if msgInstance.messageType == .group, let guidStream = msgInstance.guidStream {
                    DPAGApplicationFacade.messageFactory.newSystemMessage(content: String(format: DPAGLocalizedString("chat.group.oldversion"), notSent.count, DPAGMandant.default.name), forGroupGuid: guidStream, sendDate: lastMessageDateSystem, guid: nil)
                    DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: guidStream)
                } else if isMultiReceiverMessage, let guidStream = msgInstance.guidStream {
                    DPAGApplicationFacade.messageFactory.newSystemMessage(content: String(format: DPAGLocalizedString("chat.message-failed.update"), DPAGMandant.default.name), forChatGuid: guidStream, sendDate: lastMessageDateSystem, guid: nil)
                    DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: guidStream)
                } else {
                    errorMessage = String(format: DPAGLocalizedString("chat.message-failed.update", comment: ""), DPAGMandant.default.name)
                    errorCode = "chat.message-failed.update"
                }
            }
        }

        if callResponseBlock {
            msgInstance.responseBlock?(guidOutgoingMessage, errorCode, errorMessage)
        }
        // IMDAT: HERE WE SHOULD REMOVE THJE MESSAGE
    }

    private func sendingMessageFailed(msgInstance: DPAGSendMessageWorkerInstance, errorCode: String?, errorMessage: String?) {
        // If an outgoing CONTROL_MSG_NG has failed, we ignore it. These are extremly low-prio
        // messages and if we can't send them at first try, just drop them...
        if msgInstance.contentType == DPAGStrings.JSON.Message.ContentType.CONTROL_MSG_NG {
            DPAGApplicationFacade.cache.removeMessage(guid: msgInstance.guidOutgoingMessage)
            if let guidOutgoingMessage = msgInstance.guidOutgoingMessage {
                DPAGApplicationFacade.persistance.deleteMessageForStream(guidOutgoingMessage)
            }
        } else {
            self.sendMessageDAO.sendingMessageFailed(msgInstance: msgInstance)
        }
        msgInstance.responseBlock?(nil, errorCode, errorMessage)
    }

    private func callResponseBlockWithInstance(_ msgInstance: DPAGSendMessageWorkerInstance, object responseObject: Any?, errorCode: String?, error errorMessage: String?) {
        msgInstance.responseBlock?(responseObject, errorCode, errorMessage)
    }

    public func resendMessage(msgGuid messageToResend: String, responseBlock: DPAGServiceResponseBlock?) {
        let msgInstance = DPAGSendMessageWorkerInstance(receiver: DPAGSendMessageRecipient.NULL_RECEIVER, text: "", contentType: "", messageType: .unknown, streamGuid: nil)
        msgInstance.responseBlock = responseBlock
        msgInstance.guidOutgoingMessage = messageToResend
        
        if let decryptedMessage = DPAGApplicationFacade.cache.decryptedMessage(messageGuid: messageToResend, in: nil) {
            msgInstance.messageType = decryptedMessage.messageType
        }
        let block: DPAGServiceResponseBlock = { responseObject, errorCode, errorMessage in
            if let errorMessage = errorMessage {
                self.sendingMessageFailed(msgInstance: msgInstance, errorCode: errorCode, errorMessage: errorMessage)
            } else {
                self.sendingMessageSucceeded(msgInstance: msgInstance, response: responseObject, callResponseBlock: true, isMultiReceiverMessage: false)
            }
        }
        let blockSend = {
            do {
                try self.sendMessageDAO.updateResendMessage(msgGuid: messageToResend, withMsgInstance: msgInstance, forInitialSending: false)
            } catch DPAGErrorSendMessage.err463 {
                self.sendingMessageFailed(msgInstance: msgInstance, errorCode: nil, errorMessage: DPAGFunctionsGlobal.DPAGLocalizedString("internal.error.463", comment: ""))
            } catch {}

            if msgInstance.messageJson != nil {
                if msgInstance.messageType == .group {
                    try self.sendGroupMessage(msgInstance: msgInstance, serviceResponseBlock: block)
                } else if msgInstance.messageType == .channel {
                    // [self sendChannelMessageWithServiceResponseBlock:block]
                } else if msgInstance.messageType == .private {
                    try self.sendPrivateMessage(msgInstance: msgInstance, serviceResponseBlock: block)
                }
            }
        }
        let responseBlockCheckSent: DPAGServiceResponseBlock = { responseObject, errorCode, errorMessage in
            if errorMessage != nil {
                responseBlock?(nil, errorCode, errorMessage)
            } else if let responseArray = responseObject as? [[String: Any]] {
                if responseArray.count == 0 {
                    do {
                        try blockSend()
                    } catch {
                        responseBlock?(nil, error.localizedDescription, error.localizedDescription)
                    }
                } else {
                    block(responseObject, nil, nil)
                }
            } else {
                do {
                    try blockSend()
                } catch {
                    responseBlock?(nil, error.localizedDescription, error.localizedDescription)
                }
            }
        }
        DPAGApplicationFacade.server.isMessageSent(messageGuid: messageToResend, withResponse: responseBlockCheckSent)
    }
}
