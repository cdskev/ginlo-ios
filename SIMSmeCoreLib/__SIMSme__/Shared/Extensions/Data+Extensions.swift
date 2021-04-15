//
//  Data+Extensions.swift
//  SIMSme
//
//  Created by RBU on 15/01/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import ImageIO
import UIKit

extension Data {
    func contactImageDataEncoded() -> String? {
        self.resizedImage(size: DPAGConstantsGlobal.kProfileImageSize, crop: true)?.jpegData(compressionQuality: UIImage.compressionQualityContactImage)?.base64EncodedString()
    }

    func resizedForSending() -> Data {
        let imageOptionsForSending: DPAGImageOptions

        if AppConfig.isShareExtension {
            let preferences = DPAGApplicationFacadeShareExt.preferences

            imageOptionsForSending = preferences.imageOptionsForSending
        } else {
            let preferences = DPAGApplicationFacade.preferences

            imageOptionsForSending = preferences.imageOptionsForSending
        }

        return self.resizedImage(size: imageOptionsForSending.size, crop: false)?.dataForSending() ?? self
    }

    func resized(size: CGSize) -> UIImage? {
        self.resizedImage(size: size, crop: false)
    }

    func previewImageDataEncoded() -> String {
        self.previewImageData().base64EncodedString(options: .lineLength64Characters)
    }

    private func previewImageData() -> Data {
        self.previewImage()?.jpegData(compressionQuality: UIImage.compressionQualityPreviewImage) ?? self
    }

    private func previewImage() -> UIImage? {
        self.resizedImage(size: CGSize(width: DPAGConstantsGlobal.kChatMaxWidthObjects, height: DPAGConstantsGlobal.kChatMaxWidthObjects), crop: false)
    }

    private func resizedImage(size: CGSize, crop: Bool) -> UIImage? {
        guard let imageSource = CGImageSourceCreateWithData(self as CFData, nil) else {
            return nil
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: AnyObject] else {
            return nil
        }

        guard let width = properties[kCGImagePropertyPixelWidth as String] as? CGFloat, let height = properties[kCGImagePropertyPixelHeight as String] as? CGFloat else {
            return nil
        }

        if width <= size.width, height <= size.height, let imageCG = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
            return UIImage(cgImage: imageCG)
        }

        if crop {
            return self.resizeCGImageSourceWithCrop(imageSource, sizeCurrent: CGSize(width: width, height: height), sizeNew: size)
        }

        return self.resizeCGImageSource(imageSource, size: size)
    }

    private func resizeCGImageSource(_ cgImageSource: CGImageSource, size: CGSize) -> UIImage? {
        let maxSize = NSNumber(value: Float(size.width))

        let resizeOptions: [CFString: AnyObject] = [
            kCGImageSourceCreateThumbnailWithTransform: kCFBooleanTrue,
            kCGImageSourceCreateThumbnailFromImageAlways: kCFBooleanTrue,
            kCGImageSourceThumbnailMaxPixelSize: maxSize as NSNumber
        ]

        // Create the thumbnail image using the specified options.
        guard let myThumbnailImage = CGImageSourceCreateThumbnailAtIndex(cgImageSource, 0, resizeOptions as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: myThumbnailImage)
    }

    private func resizeCGImageSourceWithCrop(_ cgImageSource: CGImageSource, sizeCurrent: CGSize, sizeNew: CGSize) -> UIImage? {
        let maxSize: NSNumber
        let cropRect = CGRect(origin: self.cropOrigin(sizeCurrent: sizeCurrent, sizeNew: sizeNew), size: sizeNew)

        if sizeCurrent.width < sizeCurrent.height {
            maxSize = NSNumber(value: Float((sizeCurrent.height / sizeCurrent.width) * fmax(sizeNew.width, sizeNew.height)))
        } else {
            maxSize = NSNumber(value: Float((sizeCurrent.width / sizeCurrent.height) * fmax(sizeNew.width, sizeNew.height)))
        }

        let resizeOptions: [CFString: AnyObject] = [
            kCGImageSourceCreateThumbnailWithTransform: kCFBooleanTrue,
            kCGImageSourceCreateThumbnailFromImageAlways: kCFBooleanTrue,
            kCGImageSourceThumbnailMaxPixelSize: maxSize as NSNumber
        ]

        // Create the thumbnail image using the specified options.
        guard let myThumbnailImage = CGImageSourceCreateThumbnailAtIndex(cgImageSource, 0, resizeOptions as CFDictionary) else {
            return nil
        }

        guard let croppedImage = myThumbnailImage.cropping(to: cropRect) else {
            return nil
        }

        return UIImage(cgImage: croppedImage)
    }

    private func cropOrigin(sizeCurrent: CGSize, sizeNew: CGSize) -> CGPoint {
        if sizeCurrent.width < sizeCurrent.height {
            let maxSize = (sizeCurrent.height / sizeCurrent.width) * fmax(sizeNew.width, sizeNew.height)

            let x: CGFloat = 0
            let y = round((maxSize - sizeNew.height) / 2)

            return CGPoint(x: x, y: y)
        } else {
            let maxSize = (sizeCurrent.width / sizeCurrent.height) * fmax(sizeNew.width, sizeNew.height)

            let x = round((maxSize - sizeNew.width) / 2)
            let y: CGFloat = 0

            return CGPoint(x: x, y: y)
        }
    }

    private static let hexAlphabet = Array("0123456789abcdef".unicodeScalars)

    public func hexEncodedString() -> String {
        String(self.reduce(into: "".unicodeScalars, { result, value in
            result.append(Data.hexAlphabet[Int(value / 16)])
            result.append(Data.hexAlphabet[Int(value % 16)])
        }))
    }
}
