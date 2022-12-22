//
//  UIColor+Extensions.swift
// ginlo
//
//  Created by RBU on 14/01/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

extension UIColor {
    public convenience init(hex: Int) {
        let components = (
            R: CGFloat((hex >> 16) & 0xFF) / 255,
            G: CGFloat((hex >> 08) & 0xFF) / 255,
            B: CGFloat((hex >> 00) & 0xFF) / 255
        )

        self.init(red: components.R, green: components.G, blue: components.B, alpha: 1)
    }

    public convenience init(hex: Int, alpha: CGFloat) {
        let components = (
            R: CGFloat((hex >> 16) & 0xFF) / 255,
            G: CGFloat((hex >> 08) & 0xFF) / 255,
            B: CGFloat((hex >> 00) & 0xFF) / 255
        )

        self.init(red: components.R, green: components.G, blue: components.B, alpha: alpha)
    }

    var rgb: Int {
        var fRed: CGFloat = 0
        var fGreen: CGFloat = 0
        var fBlue: CGFloat = 0
        var fAlpha: CGFloat = 0

        if self.getRed(&fRed, green: &fGreen, blue: &fBlue, alpha: &fAlpha) {
            let iAlpha = Int(fAlpha * 255.0) << 24
            let iRed = Int(fRed * 255.0) << 16
            let iGreen = Int(fGreen * 255.0) << 8
            let iBlue = Int(fBlue * 255.0)

            //  (Bits 24-31 are alpha, 16-23 are red, 8-15 are green, 0-7 are blue).
            let rgb = iAlpha + iRed + iGreen + iBlue

            return rgb
        } else {
            // Could not extract RGBA components:
            return 0
        }
    }

    class func scanColor(_ colorToParseIn: String) -> UIColor? {
        var colorToParse = colorToParseIn

        if colorToParseIn.hasPrefix("#") {
            colorToParse = String(colorToParseIn[colorToParseIn.index(colorToParseIn.startIndex, offsetBy: 1)...])
        }

        var temp: UInt32 = 0

        if Scanner(string: colorToParse).scanHexInt32(&temp) {
            let color = UIColor(hex: Int(temp))

            return color
        }

        return nil
    }

    var brightness: CGFloat {
        guard let componentColors = self.cgColor.components else {
            return 0
        }

        if componentColors.count >= 3 {
            let rCompo: CGFloat = (componentColors[0] * 299)
            let gCompo: CGFloat = (componentColors[1] * 587)
            let bCompo: CGFloat = (componentColors[2] * 114)

            let colorBrightness: CGFloat = (rCompo + gCompo + bCompo) / 1_000

            return colorBrightness
        } else if componentColors.count == 2 {
            return (((componentColors[0] * 255) * 299) + ((componentColors[0] * 255) * 587) + ((componentColors[0] * 255) * 114)) / 1_000
        }
        return 0
    }

    public func statusBarStyle(backgroundColor: UIColor) -> UIStatusBarStyle {
        if self.brightness > backgroundColor.brightness {
            return .lightContent
        }

        return .default
    }

    public func blurEffectStyle() -> UIBlurEffect.Style {
        self.brightness < DPAGColorProvider.thresholdBetweenTheDarkAndTheLight.brightness ? .extraLight : .dark
    }
    
    func lighter(by percentage: CGFloat = 30.0) -> UIColor? {
        self.adjust(by: abs(percentage) )
    }

    func darker(by percentage: CGFloat = 30.0) -> UIColor? {
        self.adjust(by: -1 * abs(percentage) )
    }

    func adjust(by percentage: CGFloat = 30.0) -> UIColor? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return UIColor(red: min(red + percentage / 100, 1.0),
                           green: min(green + percentage / 100, 1.0),
                           blue: min(blue + percentage / 100, 1.0),
                           alpha: alpha)
        } else {
            return nil
        }
    }

}
