//
//  UIImage+Extensions.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore

public extension UIImage {
    static let imageSegmentedControlRight: UIImage? = {
        UIImage.imageSegmentedControl(colorSegControl: DPAGColorProvider.shared[.segmentedControlRight])
    }()

    static let imageSegmentedControlLeft: UIImage? = {
        UIImage.imageSegmentedControl(colorSegControl: DPAGColorProvider.shared[.segmentedControlLeft])
    }()

    private class func imageSegmentedControl(colorSegControl: UIColor) -> UIImage? {
        self.roundedCornerResizableImage(size: CGSize(width: 30, height: 35), color: colorSegControl)
    }

    class func roundedCornerResizableImage(size: CGSize, color: UIColor) -> UIImage {
        let img = UIGraphicsImageRenderer(size: size).image { context in

            color.setFill()

            context.fill(CGRect(origin: .zero, size: size))
        }

        return img.resizableImage(withCapInsets: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10), resizingMode: .stretch)
    }

    class func getGifArrayFromData(_ gifData: Data) -> [UIImage] {
        var frames = [UIImage]()
        if let src = CGImageSourceCreateWithData(gifData as CFData, nil) {
            for i in 0 ..< CGImageSourceGetCount(src) {
                if let imageRef = CGImageSourceCreateImageAtIndex(src, i, nil) {
                    frames.append(UIImage(cgImage: imageRef, scale: 0, orientation: .up))
                }
            }
        }

        return frames
    }

    // TODO: check for backgroundcolor + layer.cornerradius
    class func circleImage(size: CGSize, colorFill: UIColor, colorBorder: UIColor?) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)

        let retVal = UIGraphicsImageRenderer(size: size).image { context in

            if let colorBorder = colorBorder {
                let rectFill = rect.insetBy(dx: 2, dy: 2)

                context.cgContext.setLineWidth(2.0)
                colorBorder.setStroke()
                colorFill.setFill()

                context.cgContext.beginPath()
                context.cgContext.addEllipse(in: rectFill)
                context.cgContext.drawPath(using: .fillStroke)
            } else {
                UIBezierPath(roundedRect: rect, cornerRadius: rect.size.width / 2.0).addClip()

                // Use existing opacity as is
                colorFill.setFill()

                context.fill(rect)
            }
        }

        return retVal
    }

    func rectForImageFullscreenInView(_ view: UIView, interfaceOrientationRect: CGRect) -> CGRect {
        var rect = view.bounds
        var rectNew = view.bounds
        let sizeImage = self.size
        let isLandscape = interfaceOrientationRect.width > interfaceOrientationRect.height

        if (isLandscape && (rect.size.width < rect.size.height)) || ((isLandscape == false) && (rect.size.height < rect.size.width)) {
            let width = rect.size.width
            rect.size.width = rect.size.height
            rectNew.size.width = rect.size.width
            rect.size.height = width
            rectNew.size.height = rect.size.height
        }

        if (sizeImage.width / sizeImage.height) > (rect.size.width / rect.size.height) {
            rectNew.size.height = rect.size.width * sizeImage.height / sizeImage.width
        } else {
            rectNew.size.width = rect.size.height * sizeImage.width / sizeImage.height
        }
        rectNew.origin.x = (rect.size.width - rectNew.size.width) / 2.0
        rectNew.origin.y = (rect.size.height - rectNew.size.height) / 2.0

        return rectNew
    }

    static let kImageBackgroundFormatLS = "backgroundart_%@__ls.jpg"
    static let kImageBackgroundFormatPT = "backgroundart_%@__pt.jpg"

    static let drillDownImage: UIImage = {
        let retVal = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 13)).image { context in

            let cgContext = context.cgContext

            cgContext.beginPath()
            cgContext.setLineWidth(2.0)

            DPAGColorProvider.shared[.buttonTintNoBackground].setStroke()

            UIColor.clear.setFill()

            cgContext.move(to: CGPoint(x: 0, y: 0))
            cgContext.addLine(to: CGPoint(x: 7, y: 6))
            cgContext.addLine(to: CGPoint(x: 0, y: 13))
            cgContext.drawPath(using: .stroke)
        }

        return retVal
    }()

    class func tabControlImageSelected(height: CGFloat) -> UIImage {
        let size = CGSize(width: 20, height: height)
        let rectNormal = CGRect(origin: CGPoint(x: 0, y: size.height - 3), size: CGSize(width: size.width, height: 3))

        let retValNormal = UIGraphicsImageRenderer(size: size).image { context in

            UIBezierPath(rect: rectNormal).addClip()
            DPAGColorProvider.shared[.buttonBackground].setFill()

            context.fill(rectNormal)
        }

        let retValResizable = retValNormal.resizableImage(withCapInsets: .zero, resizingMode: .stretch)

        return retValResizable
    }

    class func gradientImage(size imageSize: CGSize, scale: CGFloat, locations: [CGFloat], numLocations: Int, components: [CGFloat]) -> UIImage? {
        let rgbColorspace = CGColorSpaceCreateDeviceRGB()
        guard let glossGradient = CGGradient(colorSpace: rgbColorspace, colorComponents: components, locations: locations, count: numLocations) else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale

        let gradientImage = UIGraphicsImageRenderer(size: imageSize, format: format).image { context in

            let topCenter = CGPoint(x: 0, y: 0)
            let bottomCenter = CGPoint(x: 0, y: imageSize.height)

            context.cgContext.drawLinearGradient(glossGradient, start: topCenter, end: bottomCenter, options: CGGradientDrawingOptions())
        }

        return gradientImage
    }

    class func imageEdge(type: DPAGImageEdge, size: CGSize, scale: CGFloat, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale

        let retVal = UIGraphicsImageRenderer(size: size, format: format).image { context in

            let cgContext = context.cgContext

            switch type {
            case .topLeft:

                cgContext.move(to: CGPoint(x: 1, y: size.height - 1))
                cgContext.addLine(to: CGPoint(x: 1, y: 1))
                cgContext.addLine(to: CGPoint(x: size.width - 1, y: 1))

            case .topRight:

                cgContext.move(to: CGPoint(x: 1, y: 1))
                cgContext.addLine(to: CGPoint(x: size.width - 1, y: 1))
                cgContext.addLine(to: CGPoint(x: size.width - 1, y: size.height - 1))

            case .bottomLeft:

                cgContext.move(to: CGPoint(x: 1, y: 1))
                cgContext.addLine(to: CGPoint(x: 1, y: size.height - 1))
                cgContext.addLine(to: CGPoint(x: size.width - 1, y: size.height - 1))

            case .bottomRight:

                cgContext.move(to: CGPoint(x: 1, y: size.height - 1))
                cgContext.addLine(to: CGPoint(x: size.width - 1, y: size.height - 1))
                cgContext.addLine(to: CGPoint(x: size.width - 1, y: 1))
            }

            color.setStroke()
            cgContext.setLineWidth(2)

            cgContext.strokePath()
        }

        return retVal
    }
}

public enum DPAGImageEdge {
    case topLeft,
        topRight,
        bottomLeft,
        bottomRight
}
