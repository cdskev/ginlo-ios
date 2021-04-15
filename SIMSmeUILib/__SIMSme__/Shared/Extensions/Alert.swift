//
//  Alert.swift
//  SIMSmeUIBaseLib
//
//  Created by Evgenii Kononenko on 01.04.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public struct AlertOption {
    var title: String
    var image: UIImage?
    var style: UIAlertAction.Style
    var handler: (() -> Void)?
    var textAlignment: CATextLayerAlignmentMode?
    var accesibilityIdentifier: String?

    public init(titleKey: String, style: UIAlertAction.Style, image: UIImage? = nil, textAlignment: CATextLayerAlignmentMode? = .left, accesibilityIdentifier: String? = nil, handler: (() -> Void)? = nil) {
        let identifier = accesibilityIdentifier ?? titleKey
        self.init(title: DPAGLocalizedString(titleKey), style: style, image: image, textAlignment: textAlignment, accesibilityIdentifier: identifier, handler: handler)
    }

    public init(title: String, style: UIAlertAction.Style, image: UIImage? = nil, textAlignment: CATextLayerAlignmentMode? = .left, accesibilityIdentifier: String? = nil, handler: (() -> Void)? = nil) {
        self.title = title
        self.style = style
        self.image = image
        self.handler = handler
        if self.style != .cancel {
            self.textAlignment = textAlignment
        } else {
            self.textAlignment = nil
        }
        self.accesibilityIdentifier = accesibilityIdentifier
    }

    fileprivate func getAlertAction(withStyle style: UIAlertController.Style = .actionSheet) -> UIAlertAction {
        let action = UIAlertAction(title: self.title, style: self.style, handler: { _ in
            self.handler?()
        })
        if style == .actionSheet {
            if let image = self.image {
                action.setValue(image, forKey: "image")
            }
            if let textAlignment = self.textAlignment {
                action.setValue(textAlignment, forKey: "titleTextAlignment")
            }
        }
        action.setValue(DPAGColorProvider.shared[.actionSheetLabel], forKey: "titleTextColor")
        action.setAccessibilityIdentifier(self.accesibilityIdentifier)
        return action
    }

    public static func cancelOption() -> AlertOption {
        AlertOption(title: DPAGLocalizedString("res.cancel"), style: .cancel, textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "res.cancel", handler: nil)
    }

    public static func okOption() -> AlertOption {
        AlertOption(title: DPAGLocalizedString("res.ok"), style: .default, textAlignment: CATextLayerAlignmentMode.center, accesibilityIdentifier: "res.ok", handler: nil)
    }
}

extension UIAlertController {
    public func addOptions(options: [AlertOption], withStyle style: UIAlertController.Style = .actionSheet) {
        for option in options {
            self.addAction(option.getAlertAction(withStyle: style))
        }
    }

    public func addOption(option: AlertOption, withStyle style: UIAlertController.Style = .actionSheet) {
        self.addAction(option.getAlertAction(withStyle: style))
    }

    public static func controller(options: [AlertOption], titleKey: String? = nil, withStyle style: UIAlertController.Style = .actionSheet, accessibilityIdentifier: String? = nil) -> UIAlertController {
        var titleString: String?
        if let titleKey = titleKey {
            titleString = DPAGLocalizedString(titleKey)
        }
        let identifier = accessibilityIdentifier ?? titleKey
        return UIAlertController.controller(options: options, titleString: titleString, withStyle: style, accessibilityIdentifier: identifier)
    }

    public static func controller(options: [AlertOption], titleKey: String? = nil, withStyle style: UIAlertController.Style = .actionSheet, accessibilityIdentifier: String? = nil, sourceView: UIView? = nil) -> UIAlertController {
        var titleString: String?
        if let titleKey = titleKey {
            titleString = DPAGLocalizedString(titleKey)
        }
        let identifier = accessibilityIdentifier ?? titleKey
        return UIAlertController.controller(options: options, titleString: titleString, withStyle: style, accessibilityIdentifier: identifier, sourceView: sourceView)
    }

    public static func controller(options: [AlertOption], titleKey: String? = nil, withStyle style: UIAlertController.Style = .actionSheet, accessibilityIdentifier: String? = nil, sourceRect: CGRect? = nil) -> UIAlertController {
        var titleString: String?
        if let titleKey = titleKey {
            titleString = DPAGLocalizedString(titleKey)
        }
        let identifier = accessibilityIdentifier ?? titleKey
        return UIAlertController.controller(options: options, titleString: titleString, withStyle: style, accessibilityIdentifier: identifier, sourceView: nil, sourceRect: sourceRect)
    }

    public static func controller(options: [AlertOption], titleKey: String? = nil, withStyle style: UIAlertController.Style = .actionSheet, accessibilityIdentifier: String? = nil, barButtonItem: UIBarButtonItem? = nil) -> UIAlertController {
        var titleString: String?
        if let titleKey = titleKey {
            titleString = DPAGLocalizedString(titleKey)
        }
        let identifier = accessibilityIdentifier ?? titleKey
        return UIAlertController.controller(options: options, titleString: titleString, withStyle: style, accessibilityIdentifier: identifier, sourceView: nil, sourceRect: nil, barButtonItem: barButtonItem)
    }

    public static func controller(options: [AlertOption], titleString: String?, messageString: String? = nil, withStyle style: UIAlertController.Style = .actionSheet, accessibilityIdentifier: String? = nil) -> UIAlertController {
        UIAlertController.controller(options: options, titleString: titleString, withStyle: style, accessibilityIdentifier: accessibilityIdentifier, sourceView: nil, sourceRect: nil, barButtonItem: nil)
    }

    public static func controller(options: [AlertOption], titleString: String?, messageString: String? = nil, withStyle style: UIAlertController.Style = .actionSheet, accessibilityIdentifier: String? = nil, sourceView: UIView? = nil) -> UIAlertController {
        UIAlertController.controller(options: options, titleString: titleString, withStyle: style, accessibilityIdentifier: accessibilityIdentifier, sourceView: sourceView, sourceRect: nil, barButtonItem: nil)
    }

    public static func controller(options: [AlertOption], titleString: String?, messageString: String? = nil, withStyle style: UIAlertController.Style = .actionSheet, accessibilityIdentifier: String? = nil, sourceRect: CGRect? = nil) -> UIAlertController {
        UIAlertController.controller(options: options, titleString: titleString, withStyle: style, accessibilityIdentifier: accessibilityIdentifier, sourceView: nil, sourceRect: sourceRect, barButtonItem: nil)
    }

    public static func controller(options: [AlertOption], titleString: String?, messageString: String? = nil, withStyle style: UIAlertController.Style = .actionSheet, accessibilityIdentifier: String? = nil, barButtonItem: UIBarButtonItem? = nil) -> UIAlertController {
        UIAlertController.controller(options: options, titleString: titleString, withStyle: style, accessibilityIdentifier: accessibilityIdentifier, sourceView: nil, sourceRect: nil, barButtonItem: barButtonItem)
    }

    public static func controller(options: [AlertOption], titleString: String?, messageString: String? = nil, withStyle style: UIAlertController.Style = .actionSheet, accessibilityIdentifier: String? = nil, sourceView: UIView? = nil, sourceRect: CGRect? = nil, barButtonItem: UIBarButtonItem? = nil) -> UIAlertController {
        let theStyle: UIAlertController.Style
        if UIDevice.current.userInterfaceIdiom == .pad && barButtonItem == nil && sourceRect == nil && sourceView == nil {
            theStyle = .alert
        } else {
            theStyle = style
        }
        let alertController = UIAlertController(title: titleString, message: messageString, preferredStyle: theStyle)
        alertController.addOptions(options: options, withStyle: style)
        alertController.accessibilityIdentifier = accessibilityIdentifier
        if barButtonItem != nil || sourceRect != nil || sourceView != nil, let presenter = alertController.popoverPresentationController {
            if let barButtonItem = barButtonItem {
                presenter.barButtonItem = barButtonItem
            } else if let sourceView = sourceView {
                presenter.sourceView = sourceView
            } else if let sourceRect = sourceRect {
                presenter.sourceRect = sourceRect
            }
            presenter.permittedArrowDirections = [UIPopoverArrowDirection.up, UIPopoverArrowDirection.down]
        }
        return alertController
    }
}
