//
//  UIScrollView+Extensions.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore

public extension UIScrollView {
    func centerScrollViewContents(_ contentView: UIView?) {
        if var contentsFrame = contentView?.frame {
            let boundsSize = self.bounds.size

            if contentsFrame.size.width < boundsSize.width {
                contentsFrame.origin.x = floor((boundsSize.width - contentsFrame.size.width) / 2.0)
            } else {
                contentsFrame.origin.x = 0.0
            }

            if contentsFrame.size.height < boundsSize.height {
                contentsFrame.origin.y = floor((boundsSize.height - contentsFrame.size.height) / 2.0)
            } else {
                contentsFrame.origin.y = 0.0
            }

            contentView?.frame = contentsFrame
        }
    }

    func updateScales() {
        let scrollViewFrame = self.frame
        let scaleWidth = scrollViewFrame.size.width / (self.contentSize.width / self.zoomScale)
        let scaleHeight = scrollViewFrame.size.height / (self.contentSize.height / self.zoomScale)

        var minScale = scaleWidth

        if scaleHeight < minScale {
            minScale = scaleHeight
        }
        if !minScale.isNaN, minScale > 0.01 {
            self.minimumZoomScale = minScale
            self.zoomScale = minScale
        }
    }
}
