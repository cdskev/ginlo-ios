//
//  UIFonts+Extensions.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

public extension UIFont {
    static let kFontBody: UIFont = UIFont.preferredFont(forTextStyle: .body)
    static let kFontCaption1: UIFont = UIFont.preferredFont(forTextStyle: .caption1)
    static let kFontCaption2: UIFont = UIFont.preferredFont(forTextStyle: .caption2)
    static let kFontFootnote: UIFont = UIFont.preferredFont(forTextStyle: .footnote)
    static let kFontHeadline: UIFont = UIFont.preferredFont(forTextStyle: .headline)
    static let kFontSubheadline: UIFont = UIFont.preferredFont(forTextStyle: .subheadline)
    static let kFontTitle1: UIFont = UIFont.preferredFont(forTextStyle: .title1)
    static let kFontTitle2: UIFont = UIFont.preferredFont(forTextStyle: .title2)
    static let kFontTitle3: UIFont = UIFont.preferredFont(forTextStyle: .title3)
    static let kFontCallout: UIFont = UIFont.preferredFont(forTextStyle: .callout)
    //    static let kFontLargeTitle: UIFont = UIFont.preferredFont(forTextStyle: UIFontTextStyle.largeTitle)

    static let kFontCalloutBold: UIFont = UIFont(descriptor: UIFont.kFontCallout.fontDescriptor.withSymbolicTraits(.traitBold) ?? UIFont.kFontCallout.fontDescriptor, size: 0)
    static let kFontCaption1Bold: UIFont = UIFont(descriptor: UIFont.kFontCaption1.fontDescriptor.withSymbolicTraits(.traitBold) ?? UIFont.kFontCaption1.fontDescriptor, size: 0)
    static let kFontFootnoteBold: UIFont = UIFont(descriptor: UIFont.kFontFootnote.fontDescriptor.withSymbolicTraits(.traitBold) ?? UIFont.kFontFootnote.fontDescriptor, size: 0)

    static let kFontShowIdentityAccountID: UIFont = UIFont.boldSystemFont(ofSize: 42)

    static let kFontShadowOffset: CGSize = CGSize(width: 0, height: 1)

    static let kFontBadge = UIFont(descriptor: UIFont.kFontCaption1Bold.fontDescriptor, size: 12)

    static let kFontCounter = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: UIFont.Weight(rawValue: 0))

    static let kFontCodePublicKey = UIFont.systemFont(ofSize: 24)
    static let kFontCodeInput = UIFont.systemFont(ofSize: 40)
    static let kFontCodeInputQR = UIFont.systemFont(ofSize: 34)

    static let kFontCellNick = UIFont.systemFont(ofSize: 11)

    static let kFontInputAccountID = UIFont.systemFont(ofSize: 36)
}
