//
//  DPAGMediaResource.swift
// ginlo
//
//  Created by RBU on 30/01/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import CoreLocation
import Photos
import UIKit

public class DPAGMediaResource {
    public private(set) var mediaType: DPAGMediaResourceType
    public var mediaContent: Data?
    public var mediaUrl: URL? {
        didSet {
            if self.mediaType == .video, let mediaUrl = self.mediaUrl, self.preview == nil {
                let asset = AVURLAsset(url: mediaUrl)
                let generate1 = AVAssetImageGenerator(asset: asset)

                generate1.appliesPreferredTrackTransform = true

                do {
                    let time = CMTimeMake(value: 1, timescale: 2)
                    let oneRef = try generate1.copyCGImage(at: time, actualTime: nil) // error:&err]
                    self.preview = UIImage(cgImage: oneRef)
                } catch {
                    DPAGLog("error creating mediaUrl preview: \(error)")
                }
            }
        }
    }

    public var mediaAsset: PHAsset? {
        didSet {
            guard self.mediaType != .video,
                self.preview != nil,
                let imageAsset = self.mediaAsset else { return }

            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.resizeMode = .fast

            PHImageManager.default().requestImage(for: imageAsset, targetSize: CGSize(width: DPAGConstantsGlobal.kChatMaxWidthObjects, height: DPAGConstantsGlobal.kChatMaxWidthObjects), contentMode: .aspectFill, options: options) { [weak self] image, _ in

                self?.preview = image
            }
        }
    }

    public var preview: UIImage?
    public var text: String?
    public var attachment: DPAGDecryptedAttachment?
    public var additionalData: DPAGMessageDictionaryAdditionalData?

    public init(type mediaType: DPAGMediaResourceType) {
        self.mediaType = mediaType
    }

    private func updatePreview(asset _: AVURLAsset) {}
}

public class DPAGLocationResource {
    var preview: UIImage
    var location: CLLocation
    var address: String

    init(preview: UIImage, location: CLLocation, address: String) {
        self.preview = preview
        self.location = location
        self.address = address
    }
}

public class DPAGVoiceRecResource {
    var voiceRecData: Data
    var duration: TimeInterval

    init(voiceRecData: Data, duration: TimeInterval) {
        self.voiceRecData = voiceRecData
        self.duration = duration
    }
}
