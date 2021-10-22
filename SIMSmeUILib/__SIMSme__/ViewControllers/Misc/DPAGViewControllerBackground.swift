//
//  DPAGViewControllerBackground.swift
// ginlo
//
//  Created by RBU on 25/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGViewControllerOrientationFlexible: AnyObject {}

public protocol DPAGViewControllerOrientationFlexibleIfPresented: AnyObject {}

public protocol DPAGViewControllerNavigationTitleBig: AnyObject {}

public protocol DPAGNavigationViewControllerStyler: AnyObject {
    var navigationController: UINavigationController? { get }
    func configureNavigationWithStyle()
}

public extension DPAGNavigationViewControllerStyler {
    func configureNavigationWithStyle() {
        if let navigationController = self.navigationController as? DPAGNavigationControllerProtocol {
            navigationController.resetNavigationBarStyle()
        }
    }
}

// MARK: SupportedInterfaceOrientations - IMDAT
open class DPAGViewController: UIViewController, DPAGNavigationControllerStatusBarStyleSetter {
    private var backgroundObserverAlert: NSObjectProtocol?

    public var backgroundObserver: NSObjectProtocol?
    public var foregroundObserver: NSObjectProtocol?

    override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if self is DPAGViewControllerOrientationFlexible || UI_USER_INTERFACE_IDIOM() != .phone {
            return UI_USER_INTERFACE_IDIOM() == .phone ? .allButUpsideDown : .all
        }
        if self.navigationController?.viewControllers.contains(where: { $0 is DPAGViewControllerOrientationFlexible }) ?? false {
            return .allButUpsideDown
        }
        if self is DPAGViewControllerOrientationFlexibleIfPresented, self.presentingViewController != nil {
            return .allButUpsideDown
        }
        return UI_USER_INTERFACE_IDIOM() == .phone ? .allButUpsideDown : .all
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
        self.view.accessibilityIdentifier = "\(type(of: self))".components(separatedBy: ".").last
        self.setBackBarButtonItem(image: nil, action: nil)
        if AppConfig.isShareExtension == false {
            NotificationCenter.default.addObserver(self, selector: #selector(handleDesignColorsUpdatedNotificationReceived), name: DPAGStrings.Notification.Application.DESIGN_COLORS_UPDATED, object: nil)
        }
        self.navigationItem.largeTitleDisplayMode = self is DPAGViewControllerNavigationTitleBig ? .always : .never
        if self is DPAGViewControllerNavigationTitleBig {
            self.navigationController?.navigationBar.prefersLargeTitles = true
        }
        self.navigationController?.navigationBar.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
    }

    override open func willMove(toParent parent: UIViewController?) {
        if parent == nil, let navVC = self.parent as? UINavigationController, let nextVC = navVC.viewControllers.dropLast().last {
            (nextVC as? DPAGNavigationViewControllerStyler)?.configureNavigationWithStyle()
        }
        super.willMove(toParent: parent)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override open var preferredStatusBarStyle: UIStatusBarStyle {
        if let presentedViewController = self.presentedViewController, presentedViewController.isBeingDismissed == false {
            return presentedViewController.preferredStatusBarStyle
        }
        return DPAGColorProvider.shared.preferredStatusBarStyle
    }

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(preferredContentSizeChanged(_:)), name: UIContentSizeCategory.didChangeNotification, object: nil)
        if AppConfig.isShareExtension == false {
            NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: DPAGStrings.Notification.Application.WILL_ENTER_FOREGROUND, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: DPAGStrings.Notification.Application.WILL_RESIGN_ACTIVE, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: DPAGStrings.Notification.Application.DID_BECOME_ACTIVE, object: nil)
            if (self is DPAGMediaContentViewControllerProtocol || self is DPAGMediaViewControllerProtocol || self is DPAGMediaFilesViewControllerProtocol || self is DPAGMediaOverviewViewControllerBaseProtocol) == false {
                self.navigationController?.setToolbarHidden(true, animated: animated)
            }
            self.backgroundObserverAlert = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil, queue: .main, using: { [weak self] _ in
                guard let strongSelf = self, let presentedAlertViewController = strongSelf.presentedViewController as? UIAlertController else { return }
                presentedAlertViewController.dismiss(animated: false, completion: {
                    presentedAlertViewController.appInBackgroundCompletion?()
                })
            })
        }
        self.transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
            (self as? DPAGNavigationViewControllerStyler)?.configureNavigationWithStyle()
            self?.setNeedsStatusBarAppearanceUpdate()
        }, completion: nil)
    }

    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        (self as? DPAGNavigationViewControllerStyler)?.configureNavigationWithStyle()
    }

    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIContentSizeCategory.didChangeNotification, object: nil)
        if AppConfig.isShareExtension == false {
            NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil)
            NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.Application.WILL_ENTER_FOREGROUND, object: nil)
            NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.Application.WILL_RESIGN_ACTIVE, object: nil)
            NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.Application.DID_BECOME_ACTIVE, object: nil)
            if let backgroundObserver = self.backgroundObserverAlert {
                NotificationCenter.default.removeObserver(backgroundObserver, name: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil)
            }
            if let backgroundObserver = self.backgroundObserver {
                NotificationCenter.default.removeObserver(backgroundObserver, name: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil)
            }
            if let foregroundObserver = self.foregroundObserver {
                NotificationCenter.default.removeObserver(foregroundObserver, name: DPAGStrings.Notification.Application.WILL_ENTER_FOREGROUND, object: nil)
            }
        }
    }

    @objc
    open func appDidEnterBackground() {}

    @objc
    open func appWillEnterForeground() {}

    @objc
    open func appWillResignActive() {}

    @objc
    open func appDidBecomeActive() {}

    @objc
    open func handleDesignColorsUpdatedNotificationReceived() {
        self.performBlockOnMainThread { [weak self] in
            if let strongSelf = self {
                strongSelf.handleDesignColorsUpdated()
            }
        }
        (self.navigationController as? DPAGNavigationViewControllerStyler)?.configureNavigationWithStyle()
    }
    
    open func handleDesignColorsUpdated() {
        self.navigationController?.navigationBar.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.setNeedsStatusBarAppearanceUpdate()
    }

    @objc
    open func preferredContentSizeChanged(_ aNotification: Notification?) {
        if aNotification == nil {
            return
        }
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
    }
    
    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.handleDesignColorsUpdated()
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}

open class DPAGViewControllerBackground: DPAGViewController {
    public private(set) var isFirstAppearOfView = false

    override open func viewDidLoad() {
        super.viewDidLoad()
        self.view.accessibilityIdentifier = "\(type(of: self))".components(separatedBy: ".").last
        self.isFirstAppearOfView = true
    }

    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.isFirstAppearOfView {
            self.viewFirstAppear(animated)
            self.isFirstAppearOfView = false
        }
    }

    open func viewFirstAppear(_: Bool) {
    }
}

open class DPAGViewControllerWithKeyboard: DPAGViewControllerBackground {
    var tapGrView: UITapGestureRecognizer?

    override open func viewDidLoad() {
        super.viewDidLoad()
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleViewTapped(_:)))
        tap.numberOfTapsRequired = 1
        tap.cancelsTouchesInView = true
        tap.isEnabled = false
        self.view.addGestureRecognizer(tap)
        self.tapGrView = tap
    }

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.addKeyboardNotificationsObserver()
    }

    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.removeKeyboardNotificationsObserver()
    }

    // MARK: - Keyboard Handling

    @objc
    open func handleViewTapped(_: Any?) {}

    func addKeyboardNotificationsObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    func removeKeyboardNotificationsObserver() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc
    open func handleKeyboardWillShow(_: Notification) {}

    public func handleKeyboardWillShow(_ aNotification: Notification, scrollView: UIScrollView, viewVisible: UIView) {
        let animationInfo = UIKeyboardAnimationInfo(aNotification: aNotification, view: self.view)
        var contentInsets = scrollView.contentInset
        contentInsets.bottom = animationInfo.keyboardRectEnd.size.height - self.view.safeAreaInsets.bottom
        let rectVisible = scrollView.convert(viewVisible.frame, from: viewVisible.superview)
        UIView.animate(withDuration: animationInfo.animationDuration, delay: 0, options: UIView.AnimationOptions(curve: animationInfo.animationCurve), animations: {
            scrollView.contentInset = contentInsets
            scrollView.scrollIndicatorInsets = contentInsets
            scrollView.scrollRectToVisible(rectVisible.offsetBy(dx: 0, dy: 5), animated: false)
        }, completion: nil)
        self.tapGrView?.isEnabled = true
    }

    public func handleKeyboardWillShow(_ aNotification: Notification, scrollView: UIScrollView, viewVisible: UIView, viewButtonPrimary: DPAGButtonPrimaryView) {
        let animationInfo = UIKeyboardAnimationInfo(aNotification: aNotification, view: self.view)
        viewButtonPrimary.prepareKeyboardShow(animationInfo: animationInfo)
        let rectVisible = scrollView.convert(viewVisible.frame, from: viewVisible.superview)
        UIView.animate(withDuration: animationInfo.animationDuration, delay: 0, options: UIView.AnimationOptions(curve: animationInfo.animationCurve), animations: {
            scrollView.scrollRectToVisible(rectVisible.offsetBy(dx: 0, dy: 5), animated: false)
            viewButtonPrimary.animateKeyboardShow(animationInfo: animationInfo)
        }, completion: { _ in
            viewButtonPrimary.completeKeyboardShow(animationInfo: animationInfo)
        })
        self.tapGrView?.isEnabled = true
    }

    @objc
    open func handleKeyboardWillHide(_: Notification) {}

    public func handleKeyboardWillHide(_ aNotification: Notification, scrollView: UIScrollView) {
        var contentInsets = scrollView.contentInset
        contentInsets.bottom = 0
        let animationInfo = UIKeyboardAnimationInfo(aNotification: aNotification, view: self.view)
        UIView.animate(withDuration: animationInfo.animationDuration, delay: 0, options: UIView.AnimationOptions(curve: animationInfo.animationCurve), animations: {
            scrollView.contentInset = contentInsets
            scrollView.scrollIndicatorInsets = contentInsets
        }, completion: nil)
        self.tapGrView?.isEnabled = false
    }

    public func handleKeyboardWillHide(_ aNotification: Notification, scrollView _: UIScrollView, viewButtonPrimary: DPAGButtonPrimaryView) {
        let animationInfo = UIKeyboardAnimationInfo(aNotification: aNotification, view: self.view)
        viewButtonPrimary.prepareKeyboardHide(animationInfo: animationInfo)
        UIView.animate(withDuration: animationInfo.animationDuration, delay: 0, options: UIView.AnimationOptions(curve: animationInfo.animationCurve), animations: {
            viewButtonPrimary.animateKeyboardHide(animationInfo: animationInfo)
        }, completion: { _ in
            viewButtonPrimary.completeKeyboardHide(animationInfo: animationInfo)

        })
        self.tapGrView?.isEnabled = false
    }
}
