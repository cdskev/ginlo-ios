//
//  DPAGUIImageHelper.swift
//  SIMSme
//
//  Created by RBU on 10/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import ImageIO
import UIKit

public class DPAGUIImageHelper: NSObject {
    private static var guidToImage: [String: UIImage] = [:]
    private static var nameToImages: [String: [Int: UIImage]] = [:]

    private static let queueImages: DispatchQueue = DispatchQueue(label: "de.dpag.simsme.DPAGUIImageHelper.queueImages", qos: .background, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)

    public class func lettersForPlaceholder(name: String) -> String {
        var letters = ""

        var nameUpperCase = name.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if let rangeSpace = nameUpperCase.range(of: " ", options: .backwards) {
            let lastName = nameUpperCase[rangeSpace.upperBound...]

            nameUpperCase = String(nameUpperCase[..<rangeSpace.lowerBound])

            if let rangeSecondLetter = lastName.rangeOfCharacter(from: .alphanumerics, options: .caseInsensitive) {
                letters += String(lastName[rangeSecondLetter])
            }
        }

        if let rangeFirstLetter = nameUpperCase.rangeOfCharacter(from: .alphanumerics) {
            letters = String(nameUpperCase[rangeFirstLetter]) + letters
        }

        return letters
    }

    public class func imageForPlaceholder(color: UIColor, letters lettersIn: String?, imageType: DPAGContactImageType) -> UIImage? {
        let size = imageType.size
        var font: UIFont
        let textColor: UIColor = .white
        var withPlaceholder = false

        let kFontChatContactInfoLinkPlatzhalter: UIFont = UIFont.systemFont(ofSize: 14)
        let kFontChatContactInfoPlatzhalter: UIFont = UIFont.systemFont(ofSize: 20)
        let kFontChatListContactInfoPlatzhalter: UIFont = UIFont.systemFont(ofSize: 36)
        let kFontWelcomeNick: UIFont = UIFont.systemFont(ofSize: 64)

        switch imageType {
        case .barButtonSettings:
            font = kFontChatContactInfoLinkPlatzhalter
            withPlaceholder = true

        case .barButton:
            font = kFontChatContactInfoLinkPlatzhalter

        case .chat:
            font = kFontChatContactInfoPlatzhalter

        case .contactList:
            font = kFontChatContactInfoPlatzhalter

        case .chatList:
            font = kFontChatListContactInfoPlatzhalter

        case .profile:
            font = kFontWelcomeNick
            withPlaceholder = true
        }

        let imgColor = UIImage.image(size: size, color: color)

        guard let letters = lettersIn, letters.isEmpty == false else {
            return imgColor
        }

        let rect = CGRect(x: 0, y: 0, width: imgColor.size.width, height: imgColor.size.height)

        let format = UIGraphicsImageRendererFormat()
        format.scale = imgColor.scale

        let newImage = UIGraphicsImageRenderer(size: imgColor.size, format: format).image { _ in

            UIBezierPath(roundedRect: rect, cornerRadius: size.width / 2.0).addClip()

            if withPlaceholder {
                if let image = DPAGImageProvider.shared[.kImagePlaceholderSingle] {
                    image.draw(in: rect)
                    imgColor.draw(in: rect, blendMode: .normal, alpha: 0.5)
                } else {
                    imgColor.draw(in: rect)
                }
            } else {
                imgColor.draw(in: rect)
            }

            let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
            let textSize = letters.size(withAttributes: attr)

            letters.draw(in: CGRect(x: (rect.size.width - textSize.width) / 2, y: (rect.size.height - textSize.height) / 2, width: textSize.width, height: textSize.height), withAttributes: attr)
        }

        return newImage
    }

    public class func image(forGroupGuid groupGuidIn: String?, imageType _: DPAGContactImageType) -> UIImage? {
        guard let groupGuid = groupGuidIn else {
            return DPAGImageProvider.shared[.kImagePlaceholderGroup]
        }

        var retVal: UIImage?

        self.queueImages.sync(flags: .barrier) {
            if let image = self.guidToImage[groupGuid] {
                retVal = image
            } else if let image = DPAGHelperEx.image(forGroupGuid: groupGuid) {
                self.guidToImage[groupGuid] = image
                retVal = image
            }
        }

        return retVal ?? DPAGImageProvider.shared[.kImagePlaceholderGroup]
    }

    public class func removeCachedGroupImage(guid: String) {
        self.queueImages.sync(flags: .barrier) {
            _ = self.guidToImage.removeValue(forKey: guid)
        }
    }
}
