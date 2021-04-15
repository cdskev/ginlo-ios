//
//  UIAlert+Extensions.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore

public extension UIAlertController {
    fileprivate enum AssociatedKeys {
        static var AccessibilityIdentifier = "DPAGAccessibilityIdentifier"
        static var AppInBackgroundCompletion = "DPAGAppInBackgroundCompletion"
    }

    var accessibilityIdentifier: String? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.AccessibilityIdentifier) as? String
        }
        set {
            if let accessibilityIdentifier = newValue {
                objc_setAssociatedObject(self, &AssociatedKeys.AccessibilityIdentifier, accessibilityIdentifier, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
            }
        }
    }

    var appInBackgroundCompletion: DPAGCompletion? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.AppInBackgroundCompletion) as? DPAGCompletion
        }
        set {
            guard let completion = newValue else { return }
            objc_setAssociatedObject(self, &AssociatedKeys.AppInBackgroundCompletion, completion, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }

    convenience init(titleIdentifier: String?, messageIdentifier: String?, preferredStyle: UIAlertController.Style, accessibilityIdentifier: String? = nil) {
        var title: String?
        var message: String?
        if let titleIdentifier = titleIdentifier {
            title = DPAGLocalizedString(titleIdentifier)
        }
        if let messageIdentifier = messageIdentifier {
            message = DPAGLocalizedString(messageIdentifier)
        }
        self.init(title: title, message: message, preferredStyle: preferredStyle)
        self.accessibilityIdentifier = accessibilityIdentifier ?? titleIdentifier ?? messageIdentifier
        view.tintColor = UIColor.yellow
    }

    convenience init(titleIdentifier: String?, message: String, preferredStyle: UIAlertController.Style, accessibilityIdentifier: String? = nil) {
        var title: String?
        if let titleIdentifier = titleIdentifier {
            title = DPAGLocalizedString(titleIdentifier)
        }
        self.init(title: title, message: message, preferredStyle: preferredStyle)
        self.accessibilityIdentifier = accessibilityIdentifier ?? titleIdentifier
        view.tintColor = UIColor.yellow
    }

    func activateAccessibility() {
        self.view.accessibilityIdentifier = self.accessibilityIdentifier
        for action in self.actions {
            let label = action.value(forKey: "__representer")
            let view = label as? UIView
            view?.accessibilityIdentifier = action.accessibilityIdentifier()
        }
    }
}

public extension UIAlertAction {
    fileprivate enum AssociatedKeys {
        static var AccessibilityIdentifier = "DPAGAccessibilityIdentifier"
    }

    func setAccessibilityIdentifier(_ accessibilityIdentifier: String?) {
        if let accessibilityIdentifier = accessibilityIdentifier {
            objc_setAssociatedObject(self, &AssociatedKeys.AccessibilityIdentifier, accessibilityIdentifier, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }

    func accessibilityIdentifier() -> String? {
        objc_getAssociatedObject(self, &AssociatedKeys.AccessibilityIdentifier) as? String
    }

    convenience init(titleIdentifier: String?, style: UIAlertAction.Style, handler: ((UIAlertAction) -> Void)?, accessibilityIdentifier: String? = nil) {
        var title: String?
        if let titleIdentifier = titleIdentifier {
            title = DPAGLocalizedString(titleIdentifier)
        }
        self.init(title: title, style: style, handler: handler)
        self.setAccessibilityIdentifier(accessibilityIdentifier ?? titleIdentifier)
        self.setValue(DPAGColorProvider.shared[.actionSheetLabel], forKey: "titleTextColor")
    }

    static let cancelDefault = UIAlertAction(titleIdentifier: "res.cancel", style: .cancel, handler: nil)
}
