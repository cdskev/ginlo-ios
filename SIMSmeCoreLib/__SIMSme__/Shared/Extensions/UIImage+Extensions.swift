//
//  UIImage+Extensions.swift
//  SIMSmeCore
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

extension UIImage {
    public func thumbnailImage(size: CGSize, interpolationQuality quality: CGInterpolationQuality) -> UIImage? {
        if let resizedImage = self.resizedImage(newSize: size, interpolationQuality: quality, contentMode: .scaleAspectFill) {
            let cropRect = CGRect(origin: CGPoint(x: round((resizedImage.size.width - size.width) / 2), y: round((resizedImage.size.height - size.height) / 2)), size: size)
            return resizedImage.croppedImage(cropRect)
        }
        return nil
    }

    public func croppedImage(_ bounds: CGRect) -> UIImage? {
        let rectScaled = CGRect(x: bounds.origin.x * self.scale, y: bounds.origin.y * self.scale, width: bounds.size.width * self.scale, height: bounds.size.height * self.scale)

        if let CGImage = self.cgImage, let imageRef = CGImage.cropping(to: rectScaled) {
            let croppedImage = UIImage(cgImage: imageRef, scale: self.scale, orientation: self.imageOrientation)

            return croppedImage
        }
        return nil
    }

    public func resizedForSending() -> UIImage? {
        let imageOptionsForSending: DPAGImageOptions
        if AppConfig.isShareExtension {
            let preferences = DPAGApplicationFacadeShareExt.preferences
            imageOptionsForSending = preferences.imageOptionsForSending
        } else {
            let preferences = DPAGApplicationFacade.preferences
            imageOptionsForSending = preferences.imageOptionsForSending
        }
        if imageOptionsForSending.size.width < self.size.width || imageOptionsForSending.size.height < self.size.height, let imageToSendResized = self.resizedImage(newSize: imageOptionsForSending.size, interpolationQuality: CGInterpolationQuality(rawValue: imageOptionsForSending.interpolationQuality) ?? .default, contentMode: .scaleAspectFit) {
            return imageToSendResized
        }
        return nil
    }

    public func dataForSending() -> Data? {
        if AppConfig.isShareExtension {
            let preferences = DPAGApplicationFacadeShareExt.preferences
            let imageOptionsForSending = preferences.imageOptionsForSending
            return self.jpegData(compressionQuality: imageOptionsForSending.quality)
        } else {
            let preferences = DPAGApplicationFacade.preferences
            let imageOptionsForSending = preferences.imageOptionsForSending
            return self.jpegData(compressionQuality: imageOptionsForSending.quality)
        }
    }

    public func resizedImage(newSize: CGSize, interpolationQuality quality: CGInterpolationQuality, contentMode: UIView.ContentMode) -> UIImage? {
        var drawTransposed = false
        switch self.imageOrientation {
            case .left, .leftMirrored, .right, .rightMirrored:
                drawTransposed = true
            default:
                drawTransposed = false
        }
        let horizontalRatio = newSize.width / (drawTransposed ? self.size.height : self.size.width)
        let verticalRatio = newSize.height / (drawTransposed ? self.size.width : self.size.height)
        let ratio: CGFloat
        switch contentMode {
            case .scaleAspectFill:
                ratio = max(horizontalRatio, verticalRatio)
            case .scaleAspectFit:
                ratio = min(horizontalRatio, verticalRatio)
            default:
                ratio = 0
                NSException(name: NSExceptionName.invalidArgumentException, reason: "Unsupported content mode: \(contentMode)", userInfo: nil).raise()
        }
        let newSize = CGSize(width: self.size.width * ratio, height: self.size.height * ratio)
        return self.resizedImage(newSize: newSize, interpolationQuality: quality)
    }

    public class func image(size: CGSize, color: UIColor, cornerRadius: CGFloat = 0) -> UIImage {
        let rect = CGRect(origin: .zero, size: size)
        let retVal = UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            if cornerRadius > 0 {
                UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).addClip()
            }
            context.fill(rect)
        }
        return retVal
    }

    public func circleImage() -> UIImage {
        UIGraphicsImageRenderer(size: self.size).image { _ in
            let rect = CGRect(origin: .zero, size: self.size)
            UIBezierPath(roundedRect: rect, cornerRadius: self.size.width / 2.0).addClip()
            self.draw(in: rect)
        }
    }

    public func circleImageUsingConfidenceColor(_ color: UIColor, thickness: CGFloat? = 6) -> UIImage {
        UIGraphicsImageRenderer(size: self.size).image { _ in
            let rect = CGRect(origin: .zero, size: self.size)
            color.setStroke()
            let uibp = UIBezierPath(roundedRect: rect, cornerRadius: self.size.width / 2.0)
            // swiftlint:disable force_unwrapping
            uibp.lineWidth = thickness!
            self.draw(in: rect)
            uibp.addClip()
            uibp.stroke(with: CGBlendMode.normal, alpha: 0.9)
        }
    }

    public func imageWithTintColor(_ tintColor: UIColor?) -> UIImage? {
        guard let CGImage = self.cgImage else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = self.scale
        let imageCopy = UIGraphicsImageRenderer(size: self.size, format: format).image { context in
            tintColor?.setFill()
            context.cgContext.translateBy(x: 0, y: self.size.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            context.cgContext.clip(to: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height), mask: CGImage)
            context.fill(CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        }
        return imageCopy
    }

    public static let compressionQualityDefault: CGFloat = 0.7
    public static let compressionQualityPreviewImage: CGFloat = 0.5
    public static let compressionQualityContactImage: CGFloat = 0.7
    public static let compressionQualityGroupImage: CGFloat = 0.7

    public func contactImageDataEncoded() -> String? {
        var imageToEncode: UIImage? = self
        if self.size.equalTo(DPAGConstantsGlobal.kProfileImageSize) == false {
            imageToEncode = imageToEncode?.thumbnailImage(size: DPAGConstantsGlobal.kProfileImageSize, interpolationQuality: .high)
        }
        return imageToEncode?.jpegData(compressionQuality: UIImage.compressionQualityContactImage)?.base64EncodedString()
    }

    public func groupImageDataEncoded() -> String? {
        var imageToEncode: UIImage? = self
        if self.size.equalTo(DPAGConstantsGlobal.kProfileImageSize) == false {
            imageToEncode = imageToEncode?.thumbnailImage(size: DPAGConstantsGlobal.kProfileImageSize, interpolationQuality: .high)
        }
        return imageToEncode?.jpegData(compressionQuality: UIImage.compressionQualityGroupImage)?.base64EncodedString()
    }

    public func previewImage() -> UIImage {
        var previewImage: UIImage? = self
        if (previewImage?.size.width ?? 0) > DPAGConstantsGlobal.kChatMaxWidthObjects {
            previewImage = previewImage?.resizeImageToWidth(DPAGConstantsGlobal.kChatMaxWidthObjects)
        }
        return previewImage ?? self
    }

    public func previewImageData() -> Data? {
        self.previewImage().jpegData(compressionQuality: UIImage.compressionQualityPreviewImage)
    }

    public func previewImageDataEncoded() -> String? {
        self.previewImageData()?.base64EncodedString(options: .lineLength64Characters)
    }

    func resizeImageToWidth(_ width: CGFloat) -> UIImage? {
        let newImageSize = self.getScaleRatioForImageToWidth(width)

        return self.resizedImage(newSize: newImageSize)
    }

    func getScaleRatioForImageToHeight(_ height: CGFloat) -> CGSize {
        let ratio = height / self.size.height
        return CGSize(width: self.size.width * ratio, height: height)
    }

    func getScaleRatioForImageToWidth(_ width: CGFloat) -> CGSize {
        let ratio = width / self.size.width
        return CGSize(width: width, height: self.size.height * ratio)
    }

    func resizedImage(newSize size: CGSize) -> UIImage {
        let newImageSize = size
        let format = UIGraphicsImageRendererFormat()
        format.scale = self.scale
        let resizedImage = UIGraphicsImageRenderer(size: newImageSize, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: newImageSize))
        }
        return resizedImage
    }

    public func resizedImage(newSize: CGSize, interpolationQuality quality: CGInterpolationQuality) -> UIImage? {
        var drawTransposed = false
        switch self.imageOrientation {
            case .left, .leftMirrored, .right, .rightMirrored:
                drawTransposed = true
            default:
                drawTransposed = false
        }
        return self.resizedImage(newSize: newSize, transform: self.transformForOrientation(newSize), drawTransposed: drawTransposed, interpolationQuality: quality)
    }

    fileprivate func resizedImage(newSize: CGSize, transform: CGAffineTransform, drawTransposed transpose: Bool, interpolationQuality quality: CGInterpolationQuality) -> UIImage? {
        let newRect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height).integral
        let transposedRect = CGRect(x: 0, y: 0, width: newRect.size.height, height: newRect.size.width)
        guard let imageRef = self.cgImage, let cgImageGetColorSpace = imageRef.colorSpace else { return nil }
        guard let bitmap = CGContext(data: nil, width: Int(newRect.size.width), height: Int(newRect.size.height), bitsPerComponent: imageRef.bitsPerComponent, bytesPerRow: 0, space: cgImageGetColorSpace, bitmapInfo: imageRef.bitmapInfo.rawValue) else { return nil }
        bitmap.concatenate(transform)
        bitmap.interpolationQuality = quality
        bitmap.draw(imageRef, in: transpose ? transposedRect : newRect)
        if let newImageRef = bitmap.makeImage() {
            let newImage = UIImage(cgImage: newImageRef)
            return newImage
        }
        return nil
    }

    fileprivate func transformForOrientation(_ newSize: CGSize) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        switch self.imageOrientation {
            case .down, // EXIF = 3
                 .downMirrored: // EXIF = 4
                transform = transform.translatedBy(x: newSize.width, y: newSize.height)
                transform = transform.rotated(by: CGFloat(Double.pi))
            case .left, // EXIF = 6
                 .leftMirrored: // EXIF = 5
                transform = transform.translatedBy(x: newSize.width, y: 0)
                transform = transform.rotated(by: CGFloat(Double.pi / 2))
            case .right, // EXIF = 8
                 .rightMirrored: // EXIF = 7
                transform = transform.translatedBy(x: 0, y: newSize.height)
                transform = transform.rotated(by: -CGFloat(Double.pi / 2))
            case .up,
                 .upMirrored:
                break
            @unknown default:
                DPAGLog("Switch with unknown value: \(self.imageOrientation.rawValue)", level: .warning)
        }
        switch self.imageOrientation {
            case .upMirrored, // EXIF = 2
                 .downMirrored: // EXIF = 4
                transform = transform.translatedBy(x: newSize.width, y: 0)
                transform = transform.scaledBy(x: -1, y: 1)
            case .leftMirrored, // EXIF = 5
                 .rightMirrored: // EXIF = 7
                transform = transform.translatedBy(x: newSize.height, y: 0)
                transform = transform.scaledBy(x: -1, y: 1)
            case .up,
                 .down,
                 .left,
                 .right:
                break
            @unknown default:
                DPAGLog("Switch with unknown value: \(self.imageOrientation.rawValue)", level: .warning)
        }
        return transform
    }
}
