//
//  DPAGPreferences.swift
//  SIMSme
//
//  Created by RBU on 20/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

class DPAGMandantOptions: NSObject, NSCoding {
    fileprivate static let KEY_COLOR_BADGE_BACKGROUND = "colorBadgeBackground"
    fileprivate static let KEY_COLOR_BADGE_TEXT = "colorBadgeText"
    fileprivate static let KEY_COLOR_LABEL = "colorLabel"

    /* var colorBadgeBackground: UIColor = UIColor.kColorMain
     var colorBadgeText: UIColor = UIColor.kColorMainContrast
     var colorLabel: UIColor = UIColor.kColorMain */

    init(dict _: [AnyHashable: Any]) {
        super.init()

        /* if let color = self.scanDict(dict, forColorKey: DPAGMandantOptions.KEY_COLOR_BADGE_BACKGROUND)
         {
         self.colorBadgeBackground = color
         }
         if let color = self.scanDict(dict, forColorKey: DPAGMandantOptions.KEY_COLOR_BADGE_TEXT)
         {
         self.colorBadgeText = color
         }
         if let color = self.scanDict(dict, forColorKey: DPAGMandantOptions.KEY_COLOR_LABEL)
         {
         self.colorLabel = color
         } */
    }

    required init?(coder _: NSCoder) {
        /* if let color = aDecoder.decodeObjectForKey(DPAGMandantOptions.KEY_COLOR_BADGE_BACKGROUND) as? UIColor
         {
         self.colorBadgeText = color
         }
         if let color = aDecoder.decodeObjectForKey(DPAGMandantOptions.KEY_COLOR_BADGE_TEXT) as? UIColor
         {
         self.colorBadgeText = color
         }
         if let color = aDecoder.decodeObjectForKey(DPAGMandantOptions.KEY_COLOR_LABEL) as? UIColor
         {
         self.colorLabel = color
         } */

        super.init()
    }

    func encode(with _: NSCoder) {
        // aCoder.encodeObject(self.colorBadgeBackground, forKey: DPAGMandantOptions.KEY_COLOR_BADGE_BACKGROUND)
        // aCoder.encodeObject(self.colorBadgeText, forKey: DPAGMandantOptions.KEY_COLOR_BADGE_TEXT)
        // aCoder.encodeObject(self.colorLabel, forKey: DPAGMandantOptions.KEY_COLOR_LABEL)
    }

    /* func scanDict(dictLayout: [String: AnyObject], forColorKey dictKey: String) -> UIColor?
     {
     if let colorToParseDict = dictLayout[dictKey] as? String
     {
     var colorToParse = colorToParseDict

     if (colorToParseDict.hasPrefix("#"))
     {
     colorToParse = colorToParseDict.substringFromIndex(colorToParseDict.startIndex.advancedBy(1))
     }

     var temp: UInt32 = 0

     if (NSScanner(string:colorToParse).scanHexInt(&temp))
     {
     let color = UIColor(hex:Int(temp))

     return color
     }
     }
     return nil
     } */
}

public class DPAGMandant: NSObject, NSCoding {
    public static let IDENT_DEFAULT = "default"

    fileprivate static let KEY_IDENT = "ident"
    fileprivate static let KEY_LABEL = "label"
    fileprivate static let KEY_SALT = "salt"
    fileprivate static let KEY_OPTIONS = "options"

    @objc public let ident: String
    @objc public let label: String
    @objc public let salt: String

    public var hashedPhoneNumbers: [String: String] = [:]
    public var hashedEmailAddresses: [String: String] = [:]

    public var name: String {
        getName()
    }

    var layout: DPAGMandantOptions?

    @objc public static let `default` = DPAGMandant()

    override private init() {
        if AppConfig.isShareExtension {
            let preferences = DPAGApplicationFacadeShareExt.preferences

            self.ident = preferences.mandantIdent ?? DPAGMandant.IDENT_DEFAULT
            self.label = preferences.mandantLabel ?? DPAGFunctionsGlobal.DPAGLocalizedString("contacts.mandant.private")
            self.salt = preferences.saltClient ?? "$2a$04$Dsvymn7LlP1bMlTCuNpd/O"
        } else {
            let preferences = DPAGApplicationFacade.preferences

            self.ident = preferences.mandantIdent ?? DPAGMandant.IDENT_DEFAULT
            self.label = preferences.mandantLabel ?? DPAGFunctionsGlobal.DPAGLocalizedString("contacts.mandant.private")
            self.salt = preferences.saltClient ?? "$2a$04$Dsvymn7LlP1bMlTCuNpd/O"
        }

        super.init()
    }

    public init?(dict: [AnyHashable: Any]) {
        guard let ident = dict[DPAGMandant.KEY_IDENT] as? String, let label = dict[DPAGMandant.KEY_LABEL] as? String, let salt = dict[DPAGMandant.KEY_SALT] as? String else {
            return nil
        }

        self.ident = ident
        self.label = label
        self.salt = salt

        super.init()

        if let dictLayout = dict["options"] as? [AnyHashable: Any] {
            self.layout = DPAGMandantOptions(dict: dictLayout)
        }
    }

    init(mandant: DPAGSharedContainerExtensionSending.Mandant) {
        self.ident = mandant.ident
        self.label = mandant.label
        self.salt = mandant.salt

        super.init()
    }

    public required init?(coder aDecoder: NSCoder) {
        guard let ident = aDecoder.decodeObject(forKey: DPAGMandant.KEY_IDENT) as? String, let label = aDecoder.decodeObject(forKey: DPAGMandant.KEY_LABEL) as? String, let salt = aDecoder.decodeObject(forKey: DPAGMandant.KEY_SALT) as? String else {
            return nil
        }

        self.ident = ident
        self.label = label
        self.salt = salt

        super.init()

        self.layout = aDecoder.decodeObject(forKey: DPAGMandant.KEY_OPTIONS) as? DPAGMandantOptions
    }

    public func addPhoneNumberHash(_ hash: String, phoneNumber: String) {
        self.hashedPhoneNumbers[hash] = phoneNumber
    }

    public func addEmailAddressHash(_ hash: String, emailAddress: String) {
        self.hashedEmailAddresses[hash] = emailAddress
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.ident, forKey: DPAGMandant.KEY_IDENT)
        aCoder.encode(self.label, forKey: DPAGMandant.KEY_LABEL)
        aCoder.encode(self.salt, forKey: DPAGMandant.KEY_SALT)

        if let layout = self.layout {
            aCoder.encode(layout, forKey: DPAGMandant.KEY_OPTIONS)
        }
    }

    private func getName() -> String {
        if self.ident == DPAGMandant.IDENT_DEFAULT {
            return "ginlo"
        }
        return "ginlo Business"
    }
}
