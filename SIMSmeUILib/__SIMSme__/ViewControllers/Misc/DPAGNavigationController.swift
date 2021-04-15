//
//  DPAGNavigationController.swift
//  SIMSme
//
//  Created by RBU on 26/01/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGNavigationBar: UINavigationBar {
    fileprivate func resetNavigationBarStyle() {
        self.barTintColor = DPAGColorProvider.shared[.navigationBar]
        self.tintColor = DPAGColorProvider.shared[.navigationBarTint]
        self.titleTextAttributes = [.foregroundColor: DPAGColorProvider.shared[.navigationBarTint]]
        self.shadowImage = UIImage()
        self.largeTitleTextAttributes = [.foregroundColor: DPAGColorProvider.shared[.navigationBarTint]]
    }

    fileprivate func copyNavigationBarStyle(navBarSrc: UINavigationBar) {
        self.barTintColor = navBarSrc.barTintColor
        self.tintColor = navBarSrc.tintColor
        self.titleTextAttributes = navBarSrc.titleTextAttributes
        self.shadowImage = navBarSrc.shadowImage
        self.largeTitleTextAttributes = navBarSrc.largeTitleTextAttributes
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let itemsLeft = self.topItem?.leftBarButtonItems {
            for item in itemsLeft {
                if let viewCustom = item.customView, let viewHit = viewCustom.hitTest(self.convert(point, to: viewCustom), with: event) {
                    return viewHit
                }
            }
        }
        if let itemsRight = self.topItem?.rightBarButtonItems {
            for item in itemsRight {
                if let viewCustom = item.customView, let viewHit = viewCustom.hitTest(self.convert(point, to: viewCustom), with: event) {
                    return viewHit
                }
            }
        }
        return super.hitTest(point, with: event)
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if let itemsLeft = self.topItem?.leftBarButtonItems {
            for item in itemsLeft {
                if let viewCustom = item.customView, viewCustom.point(inside: self.convert(point, to: viewCustom), with: event) {
                    return true
                }
            }
        }
        if let itemsRight = self.topItem?.rightBarButtonItems {
            for item in itemsRight {
                if let viewCustom = item.customView, viewCustom.point(inside: self.convert(point, to: viewCustom), with: event) {
                    return true
                }
            }
        }
        return super.point(inside: point, with: event)
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.barTintColor = DPAGColorProvider.shared[.navigationBar]
                self.tintColor = DPAGColorProvider.shared[.navigationBarTint]
                self.titleTextAttributes = [.foregroundColor: DPAGColorProvider.shared[.navigationBarTint]]
                self.largeTitleTextAttributes = [.foregroundColor: DPAGColorProvider.shared[.navigationBarTint]]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}

class DPAGToolbar: UIToolbar {
    fileprivate func copyToolBarStyle(navBarSrc: UINavigationBar) {
        self.barTintColor = navBarSrc.barTintColor
        self.tintColor = navBarSrc.tintColor
    }
}

class DPAGNavigationController: UINavigationController, UINavigationControllerDelegate, DPAGNavigationControllerProtocol {
    // needs to be strong reference
    var transitioningDelegateZooming: UIViewControllerTransitioningDelegate?

    convenience init() {
        self.init(nibName: nil, bundle: Bundle(for: type(of: self)))
    }

    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    override init(navigationBarClass: AnyClass?, toolbarClass: AnyClass?) {
        super.init(navigationBarClass: navigationBarClass, toolbarClass: toolbarClass)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationBar.setValue(true, forKey: "hidesShadow")
    }

    override var childForStatusBarStyle: UIViewController? {
        if let presentedViewController = self.presentedViewController, presentedViewController.isBeingDismissed == false {
            return presentedViewController.childForStatusBarStyle
        }

        if self.viewControllers.count > 0 {
            if let vc = self.topViewController {
                if vc is DPAGNavigationControllerStatusBarStyleSetter {
                    return vc
                }
            }
        }

        return super.childForStatusBarStyle
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if let vc = self.childForStatusBarStyle {
            if vc != self {
                return vc.preferredStatusBarStyle
            }
        }
        return DPAGColorProvider.shared.preferredStatusBarStyle
    }

    override var prefersStatusBarHidden: Bool {
        if let vc = self.childForStatusBarStyle {
            if vc != self {
                return vc.prefersStatusBarHidden
            }
        }

        return false
    }

    override var shouldAutorotate: Bool {
        if self.viewControllers.count > 0 {
            if let vc = self.topViewController {
                return vc.shouldAutorotate
            }
        }

        return super.shouldAutorotate
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        self.visibleViewController?.preferredInterfaceOrientationForPresentation ?? super.preferredInterfaceOrientationForPresentation
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if let visibleViewController = self.visibleViewController {
            if AppConfig.isShareExtension == false {
                if visibleViewController is UIAlertController {
                    if let topViewController = self.topViewController {
                        if let presentedViewController = topViewController.presentedViewController, presentedViewController != visibleViewController {
                            return presentedViewController.supportedInterfaceOrientations
                        }
                        return topViewController.supportedInterfaceOrientations
                    }
                    return super.supportedInterfaceOrientations
                }
            }

            return visibleViewController.supportedInterfaceOrientations
        }
        return super.supportedInterfaceOrientations
    }

    func resetNavigationBarStyle() {
        (self.navigationBar as? DPAGNavigationBar)?.resetNavigationBarStyle()
    }

    func copyNavigationBarStyle(navVCSrc: UINavigationController?) {
        if let navVCSrc = navVCSrc {
            (self.navigationBar as? DPAGNavigationBar)?.copyNavigationBarStyle(navBarSrc: navVCSrc.navigationBar)
        }
    }

    func copyToolBarStyle(navVCSrc: UINavigationController?) {
        if let navVCSrc = navVCSrc {
            (self.toolbar as? DPAGToolbar)?.copyToolBarStyle(navBarSrc: navVCSrc.navigationBar)
        }
    }
}
