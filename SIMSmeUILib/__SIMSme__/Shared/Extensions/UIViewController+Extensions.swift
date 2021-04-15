//
//  UIViewController+Extensions.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import Foundation

public extension UIViewController {
    // Called from ChatList
    func configureActivityIndicatorNavigationBarView(navBarView viewTitle: UIView, subLabel labelDesc: UILabel, subActivityIndicator activityIndicator: UIActivityIndicatorView) -> UIView {
        let viewDescCentered = UIView()

        labelDesc.accessibilityIdentifier = "navigationProcessDescription"
        activityIndicator.accessibilityIdentifier = "navigationProcessActivityIndicator"

        labelDesc.textColor = self.navigationController?.navigationBar.tintColor ?? DPAGColorProvider.shared[.navigationBarTint]
        labelDesc.adjustsFontSizeToFitWidth = true
        labelDesc.font = UIFont.kFontHeadline

        viewTitle.addSubview(viewDescCentered)

        viewDescCentered.addSubview(activityIndicator)
        viewDescCentered.addSubview(labelDesc)

        activityIndicator.color = labelDesc.textColor
        activityIndicator.tintColor = labelDesc.textColor

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        labelDesc.translatesAutoresizingMaskIntoConstraints = false
        viewDescCentered.translatesAutoresizingMaskIntoConstraints = false

        viewTitle.autoresizingMask = [.flexibleHeight, .flexibleWidth]

        NSLayoutConstraint.activate([
            viewDescCentered.constraintLeading(subview: activityIndicator),
            viewDescCentered.constraintTop(subview: activityIndicator),
            viewDescCentered.constraintBottom(subview: activityIndicator),

            viewDescCentered.constraintTrailingLeading(trailingView: activityIndicator, leadingView: labelDesc, padding: 8),

            viewDescCentered.constraintTop(subview: labelDesc),
            viewDescCentered.constraintTrailing(subview: labelDesc),
            viewDescCentered.constraintBottom(subview: labelDesc),

            viewTitle.constraintCenterX(subview: viewDescCentered),
            viewTitle.constraintCenterY(subview: viewDescCentered),
            viewDescCentered.leadingAnchor.constraint(greaterThanOrEqualTo: viewTitle.leadingAnchor),
            viewDescCentered.trailingAnchor.constraint(lessThanOrEqualTo: viewTitle.trailingAnchor)
        ])

        return viewTitle
    }

    // Called From ChatStream
    func configureActivityIndicatorNavigationBarViewWithTitleLabel(_ labelTitle: UILabel, descLabel labelDesc: UILabel, activityIndicator: UIActivityIndicatorView) -> UIView {
        let viewTitle = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        let viewDescCentered = UIView()

        labelTitle.accessibilityIdentifier = "navigationTitle"
        labelDesc.accessibilityIdentifier = "navigationProcessDescription"
        activityIndicator.accessibilityIdentifier = "navigationProcessActivityIndicator"

        labelTitle.textAlignment = .left
        labelTitle.lineBreakMode = .byTruncatingMiddle
        labelTitle.textColor = self.navigationController?.navigationBar.tintColor ?? DPAGColorProvider.shared[.navigationBarTint]
        labelTitle.font = UIFont(descriptor: labelTitle.font.fontDescriptor.withSymbolicTraits(.traitBold) ?? labelTitle.font.fontDescriptor, size: labelTitle.font.pointSize)

        labelDesc.textColor = labelTitle.textColor
        labelDesc.adjustsFontSizeToFitWidth = true
        labelDesc.font = labelTitle.font

        viewTitle.addSubview(labelTitle)
        viewTitle.addSubview(viewDescCentered)

        viewDescCentered.addSubview(activityIndicator)
        viewDescCentered.addSubview(labelDesc)

        activityIndicator.color = labelTitle.textColor
        activityIndicator.tintColor = labelTitle.textColor

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        labelTitle.translatesAutoresizingMaskIntoConstraints = false
        labelDesc.translatesAutoresizingMaskIntoConstraints = false
        viewDescCentered.translatesAutoresizingMaskIntoConstraints = false

        viewTitle.autoresizingMask = [.flexibleHeight, .flexibleWidth]

        labelTitle.text = self.title
        // [labelTitle setContentCompressionResistancePriority:UILayoutPriorityDefaultLow + 2 forAxis:UILayoutConstraintAxisVertical]
        // labelDesc.setContentCompressionResistancePriority(UILayoutPriorityDefaultLow, for:UILayoutConstraintAxis.horizontal)
        // [actInd setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical]
        // [labelDesc setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical]
        NSLayoutConstraint.activate(
            viewTitle.constraintsFill(subview: labelTitle) +
                [
                    viewDescCentered.constraintLeading(subview: activityIndicator),
                    viewDescCentered.constraintTop(subview: activityIndicator),
                    viewDescCentered.constraintBottom(subview: activityIndicator),

                    viewDescCentered.constraintTrailingLeading(trailingView: activityIndicator, leadingView: labelDesc, padding: 8),

                    viewDescCentered.constraintTop(subview: labelDesc),
                    viewDescCentered.constraintTrailing(subview: labelDesc),
                    viewDescCentered.constraintBottom(subview: labelDesc),

                    viewTitle.constraintCenterX(subview: viewDescCentered),
                    viewTitle.constraintCenterY(subview: viewDescCentered),
                    viewDescCentered.leadingAnchor.constraint(greaterThanOrEqualTo: viewTitle.leadingAnchor),
                    viewDescCentered.trailingAnchor.constraint(lessThanOrEqualTo: viewTitle.trailingAnchor)
                ])

        return viewTitle
    }
    
    func presentAlertController(_ alertController: UIAlertController) {
        if Thread.isMainThread {
            alertController.view.tintColor = DPAGColorProvider.shared[.actionSheetLabel]
            alertController.activateAccessibility()
            self.present(alertController, animated: true, completion: nil)
        } else {
            self.performBlockOnMainThread { [weak self] () in
                self?.presentAlertController(alertController)
            }
        }
    }

    struct AlertConfigError {
        let titleIdentifier: String?
        let messageIdentifier: String?
        let accessibilityIdentifier: String?
        let okActionHandler: ((UIAlertAction) -> Void)?

        public init(messageIdentifier: String) {
            self.init(titleIdentifier: nil, messageIdentifier: messageIdentifier, accessibilityIdentifier: messageIdentifier, okActionHandler: nil)
        }

        public init(messageIdentifier: String, accessibilityIdentifier: String) {
            self.init(titleIdentifier: nil, messageIdentifier: messageIdentifier, accessibilityIdentifier: accessibilityIdentifier, okActionHandler: nil)
        }

        public init(messageIdentifier: String, okActionHandler: @escaping ((UIAlertAction) -> Void)) {
            self.init(titleIdentifier: nil, messageIdentifier: messageIdentifier, accessibilityIdentifier: messageIdentifier, okActionHandler: okActionHandler)
        }

        public init(titleIdentifier: String, messageIdentifier: String) {
            self.init(titleIdentifier: titleIdentifier, messageIdentifier: messageIdentifier, accessibilityIdentifier: titleIdentifier, okActionHandler: nil)
        }

        public init(messageIdentifier: String, accessibilityIdentifier: String, okActionHandler: @escaping ((UIAlertAction) -> Void)) {
            self.init(titleIdentifier: nil, messageIdentifier: messageIdentifier, accessibilityIdentifier: accessibilityIdentifier, okActionHandler: okActionHandler)
        }

        private init(titleIdentifier: String?, messageIdentifier: String?, accessibilityIdentifier: String?, okActionHandler: ((UIAlertAction) -> Void)?) {
            self.titleIdentifier = titleIdentifier
            self.messageIdentifier = messageIdentifier
            self.accessibilityIdentifier = accessibilityIdentifier
            self.okActionHandler = okActionHandler
        }
    }

    struct AlertConfig {
        let titleIdentifier: String?
        let messageIdentifier: String?
        let message: String?
        let messageAttributed: NSAttributedString?
        let accessibilityIdentifier: String?
        let cancelButtonAction: UIAlertAction?
        let otherButtonActions: [UIAlertAction]

        public init(titleIdentifier: String, otherButtonActions: [UIAlertAction]) {
            self.titleIdentifier = titleIdentifier
            self.messageIdentifier = nil
            self.message = nil
            self.messageAttributed = nil
            self.accessibilityIdentifier = titleIdentifier
            self.cancelButtonAction = nil
            self.otherButtonActions = otherButtonActions
        }

        public init(titleIdentifier: String, messageIdentifier: String, accessibilityIdentifier: String, otherButtonActions: [UIAlertAction]) {
            self.titleIdentifier = titleIdentifier
            self.messageIdentifier = messageIdentifier
            self.message = nil
            self.messageAttributed = nil
            self.accessibilityIdentifier = accessibilityIdentifier
            self.cancelButtonAction = nil
            self.otherButtonActions = otherButtonActions
        }

        public init(titleIdentifier: String, messageIdentifier: String, otherButtonActions: [UIAlertAction]) {
            self.titleIdentifier = titleIdentifier
            self.messageIdentifier = messageIdentifier
            self.message = nil
            self.messageAttributed = nil
            self.accessibilityIdentifier = titleIdentifier
            self.cancelButtonAction = nil
            self.otherButtonActions = otherButtonActions
        }

        public init(titleIdentifier: String, messageIdentifier: String, cancelButtonAction: UIAlertAction, otherButtonActions: [UIAlertAction]) {
            self.titleIdentifier = titleIdentifier
            self.messageIdentifier = messageIdentifier
            self.message = nil
            self.messageAttributed = nil
            self.accessibilityIdentifier = titleIdentifier
            self.cancelButtonAction = cancelButtonAction
            self.otherButtonActions = otherButtonActions
        }

        public init(titleIdentifier: String, message: String, cancelButtonAction: UIAlertAction?, otherButtonActions: [UIAlertAction]) {
            self.titleIdentifier = titleIdentifier
            self.messageIdentifier = nil
            self.message = message
            self.messageAttributed = nil
            self.accessibilityIdentifier = titleIdentifier
            self.cancelButtonAction = cancelButtonAction
            self.otherButtonActions = otherButtonActions
        }

        public init(messageIdentifier: String, cancelButtonAction: UIAlertAction, otherButtonActions: [UIAlertAction]) {
            self.titleIdentifier = nil
            self.messageIdentifier = messageIdentifier
            self.message = nil
            self.messageAttributed = nil
            self.accessibilityIdentifier = messageIdentifier
            self.cancelButtonAction = cancelButtonAction
            self.otherButtonActions = otherButtonActions
        }

        public init(titleIdentifier: String, cancelButtonAction: UIAlertAction, otherButtonActions: [UIAlertAction]) {
            self.titleIdentifier = titleIdentifier
            self.messageIdentifier = nil
            self.message = nil
            self.messageAttributed = nil
            self.accessibilityIdentifier = titleIdentifier
            self.cancelButtonAction = cancelButtonAction
            self.otherButtonActions = otherButtonActions
        }

        public init(messageIdentifier: String, otherButtonActions: [UIAlertAction]) {
            self.titleIdentifier = nil
            self.messageIdentifier = messageIdentifier
            self.message = nil
            self.messageAttributed = nil
            self.accessibilityIdentifier = messageIdentifier
            self.cancelButtonAction = nil
            self.otherButtonActions = otherButtonActions
        }

        public init(titleIdentifier: String, messageAttributed: NSAttributedString, otherButtonActions: [UIAlertAction]) {
            self.titleIdentifier = titleIdentifier
            self.messageIdentifier = nil
            self.message = nil
            self.messageAttributed = messageAttributed
            self.accessibilityIdentifier = titleIdentifier
            self.cancelButtonAction = nil
            self.otherButtonActions = otherButtonActions
        }

        public init(titleIdentifier: String, messageAttributed: NSAttributedString, cancelButtonAction: UIAlertAction, otherButtonActions: [UIAlertAction]) {
            self.titleIdentifier = titleIdentifier
            self.messageIdentifier = nil
            self.message = nil
            self.messageAttributed = messageAttributed
            self.accessibilityIdentifier = titleIdentifier
            self.cancelButtonAction = cancelButtonAction
            self.otherButtonActions = otherButtonActions
        }
    }

    func presentErrorAlert(alertConfig: AlertConfigError) {
        if Thread.isMainThread == false {
            self.performBlockOnMainThread { [weak self] () in
                self?.presentErrorAlert(alertConfig: alertConfig)
            }
            return
        }
        if !(self is DPAGLoginViewControllerProtocol), !(self is DPAGLoginViewControllerLocalProtocol) {
            if let navigationController = self.navigationController {
                if let visibleViewController = navigationController.visibleViewController, navigationController.visibleViewController != self, navigationController.visibleViewController != self.parent, visibleViewController.isBeingDismissed == false {
                    return
                }
            } else {
                if let vcRoot = AppConfig.appWindow(), let containerVC = vcRoot?.rootViewController as? (UIViewController & DPAGContainerViewControllerProtocol) {
                    if let navVC = containerVC.children.first as? UINavigationController, let topVC = navVC.topViewController {
                        topVC.presentErrorAlert(alertConfig: alertConfig)
                        return
                    }
                }
                if let vcRoot = AppConfig.appWindow(), let containerVC = vcRoot?.rootViewController as? (UIViewController & DPAGRootContainerViewControllerProtocol) {
                    if let navVC = containerVC.rootViewController?.children.first as? UINavigationController, let topVC = navVC.topViewController {
                        topVC.presentErrorAlert(alertConfig: alertConfig)
                        return
                    }
                }
            }
        }
        let alertController = UIAlertController(titleIdentifier: alertConfig.titleIdentifier ?? "attention", messageIdentifier: alertConfig.messageIdentifier, preferredStyle: .alert, accessibilityIdentifier: alertConfig.accessibilityIdentifier)
        alertController.addAction(UIAlertAction(titleIdentifier: "res.ok", style: .default, handler: alertConfig.okActionHandler))
        self.presentAlertController(alertController)
    }

    @discardableResult
    func presentAlert(alertConfig: AlertConfig) -> UIAlertController {
        let alertController: UIAlertController
        if Thread.isMainThread {
            if let messageAttributed = alertConfig.messageAttributed {
                alertController = UIAlertController(titleIdentifier: alertConfig.titleIdentifier, message: messageAttributed.string, preferredStyle: .alert, accessibilityIdentifier: alertConfig.accessibilityIdentifier)
            } else if let message = alertConfig.message {
                alertController = UIAlertController(titleIdentifier: alertConfig.titleIdentifier, message: message, preferredStyle: .alert, accessibilityIdentifier: alertConfig.accessibilityIdentifier)
            } else {
                alertController = UIAlertController(titleIdentifier: alertConfig.titleIdentifier, messageIdentifier: alertConfig.messageIdentifier, preferredStyle: .alert, accessibilityIdentifier: alertConfig.accessibilityIdentifier)
            }
            if let messageAttributed = alertConfig.messageAttributed {
                alertController.setValue(messageAttributed, forKey: "attributedMessage")
            }
            if let cancelButtonAction = alertConfig.cancelButtonAction {
                alertController.addAction(cancelButtonAction)
            }
            for otherButtonAction in alertConfig.otherButtonActions {
                alertController.addAction(otherButtonAction)
            }
            self.presentAlertController(alertController)
            return alertController
        } else {
            var result: UIAlertController = UIAlertController(titleIdentifier: alertConfig.titleIdentifier, messageIdentifier: alertConfig.messageIdentifier, preferredStyle: .alert, accessibilityIdentifier: alertConfig.accessibilityIdentifier)
            OperationQueue.main.addOperation {
                result = self.presentAlert(alertConfig: alertConfig)
            }
            return result
        }
    }

    func showErrorAlertCheck(alertConfig: AlertConfigError) {
        if AppConfig.isShareExtension == false {
            if (CryptoHelper.sharedInstance?.isPrivateKeyDecrypted() ?? false) || DPAGApplicationFacade.cache.account == nil {
                self.presentErrorAlert(alertConfig: alertConfig)
            }
        }
    }

    // MARK: - Presented Viewcontrollers

    var presentedZIndex: NSNumber? {
        get {
            objc_getAssociatedObject(self, "presentedZIndex") as? NSNumber
        }
        set {
            objc_setAssociatedObject(self, "presentedZIndex", newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func allPresentedViewControllers() -> [UIViewController] {
        var arr: [UIViewController] = []

        let currentZIndex = self.presentedZIndex ?? NSNumber(value: 0 as Int)

        if let presentedViewController = self.presentedViewController, presentedViewController.isBeingDismissed == false {
            presentedViewController.presentedZIndex = NSNumber(value: currentZIndex.intValue + 1 as Int)

            if arr.contains(presentedViewController) == false {
                arr.append(presentedViewController)
            }
        }

        if let navigationController = self as? UINavigationController {
            if let presentedViewController = navigationController.topViewController?.presentedViewController, presentedViewController.isBeingDismissed == false {
                presentedViewController.presentedZIndex = NSNumber(value: currentZIndex.intValue + 1 as Int)

                if arr.contains(presentedViewController) == false {
                    arr.append(presentedViewController)
                }
            }
        }

        let presentedViewControllers = [] + arr

        for viewController in presentedViewControllers {
            arr += viewController.allPresentedViewControllers()
        }

        return arr
    }

    private func buttonWithImage(_ image: UIImage?, action: Selector?) -> UIButton {
        let button = DPAGButtonExtendedHitArea(type: .custom)

        button.setImage(image, for: .normal)
        button.sizeToFit()
        if let action = action {
            button.addTarget(self, action: action, for: .touchUpInside)
        }

        return button
    }
    // TODO: ISO - right bar button
    func setRightBarButtonItem(image: UIImage?, action: Selector, accessibilityLabelIdentifier: String) {
        let a = UIBarButtonItem(customView: self.buttonWithImage(image, action: action))
        self.navigationItem.rightBarButtonItem = a

        self.navigationItem.rightBarButtonItem?.accessibilityLabel = DPAGLocalizedString(accessibilityLabelIdentifier)
        self.navigationItem.rightBarButtonItem?.accessibilityIdentifier = accessibilityLabelIdentifier
        self.navigationItem.rightBarButtonItem?.isAccessibilityElement = true
    }

    func setRightBarButtonItemWithText(_ text: String?, action: Selector, accessibilityLabelIdentifier: String?) {
        let rightBarButtonItem = UIBarButtonItem(title: text, style: .plain, target: self, action: action)

        if let accessibilityLabelIdentifier = accessibilityLabelIdentifier {
            rightBarButtonItem.accessibilityLabel = DPAGLocalizedString(accessibilityLabelIdentifier)
            rightBarButtonItem.accessibilityIdentifier = accessibilityLabelIdentifier
            rightBarButtonItem.isAccessibilityElement = true
        }
        self.navigationItem.rightBarButtonItem = rightBarButtonItem
    }

    func setBackBarButtonItem(image: UIImage?, action: Selector?) {
        if image != nil {
            self.navigationItem.backBarButtonItem = UIBarButtonItem(customView: self.buttonWithImage(image, action: action))
        } else {
            self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: self, action: action)
        }

        self.navigationItem.backBarButtonItem?.accessibilityIdentifier = "action_back"
        self.navigationItem.backBarButtonItem?.isAccessibilityElement = true
    }

    func setLeftBarButtonItem(image: UIImage?, action: Selector, accessibilityLabelIdentifier: String) {
        if image != nil {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: self.buttonWithImage(image, action: action))
        } else {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: self, action: action)
        }

        self.navigationItem.leftBarButtonItem?.accessibilityLabel = DPAGLocalizedString(accessibilityLabelIdentifier)
        self.navigationItem.leftBarButtonItem?.accessibilityIdentifier = accessibilityLabelIdentifier
        self.navigationItem.leftBarButtonItem?.isAccessibilityElement = true
    }

    func setLeftBarButtonItem(title: String, action: Selector) {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: DPAGLocalizedString(title), style: .plain, target: self, action: action)

        self.navigationItem.leftBarButtonItem?.accessibilityLabel = DPAGLocalizedString(title)
        self.navigationItem.leftBarButtonItem?.accessibilityIdentifier = title
        self.navigationItem.leftBarButtonItem?.isAccessibilityElement = true
    }

    func setLeftBackBarButtonItem(action: Selector) {
        let image = DPAGImageProvider.shared[.kImageBarButtonNavBack]?.imageWithTintColor(DPAGColorProvider.shared[.labelText])
        let backItem = UIBarButtonItem(customView: self.buttonWithImage(image, action: action))
        backItem.accessibilityLabel = DPAGLocalizedString("navigation.back")
        backItem.accessibilityIdentifier = "action_back"
        backItem.isAccessibilityElement = true
        self.navigationItem.leftBarButtonItem = backItem
    }

    var topModalViewController: UIViewController {
        var topController: UIViewController = self
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }

        return topController
    }
}
