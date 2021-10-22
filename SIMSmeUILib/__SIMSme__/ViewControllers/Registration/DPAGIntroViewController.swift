//
//  DPAGIntroViewController.swift
// ginlo
//
//  Created by RBU on 23.01.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGIntroViewController: UIViewController, DPAGIntroViewControllerProtocol {
    private let pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)

    private lazy var page0 = DPAGApplicationFacadeUIRegistration.introPage0VC(delegatePages: self)
    private lazy var page1 = DPAGApplicationFacadeUIRegistration.introPage1VC(delegatePages: self)

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        get {
            if let vc = self.pageViewController.viewControllers?.first {
                return vc.supportedInterfaceOrientations
            }
            return UI_USER_INTERFACE_IDIOM() == .phone ? .allButUpsideDown : .all
        }
        // swiftlint:disable unused_setter_value
        set {}
        // swiftlint:disable nesting
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.accessibilityIdentifier = "\(type(of: self))".components(separatedBy: ".").last
        self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.setBackBarButtonItem(image: nil, action: nil)
        self.pageViewController.willMove(toParent: self)
        self.addChild(self.pageViewController)
        self.view.addSubview(self.pageViewController.view)
        self.pageViewController.didMove(toParent: self)
        self.pageViewController.delegate = self
        self.pageViewController.dataSource = self
        self.pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addConstraintsFill(subview: self.pageViewController.view)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if (self.pageViewController.viewControllers?.count ?? 0) == 0 {
            if DPAGApplicationFacade.preferences.automaticMdmRegistrationValues != nil {
                self.pageViewController.setViewControllers([self.page1], direction: .forward, animated: false, completion: nil)
            } else {
                self.pageViewController.setViewControllers([self.page0], direction: .forward, animated: false, completion: nil)
            }
        }
        if DPAGApplicationFacade.isResetingAccount {
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                while true {
                    if !DPAGApplicationFacade.isResetingAccount {
                        self.performBlockOnMainThread {
                            DPAGProgressHUD.sharedInstance.hide(true)
                        }
                        break
                    }
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
        }
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}

extension DPAGIntroViewController: DPAGPageViewControllerProtocol {
    func pageForwards() {
        self.pageViewController.setViewControllers([self.page1], direction: .forward, animated: true, completion: nil)
    }

    func pageBackwards() {
        self.pageViewController.setViewControllers([self.page0], direction: .reverse, animated: true, completion: nil)
    }
}

extension DPAGIntroViewController: UIPageViewControllerDelegate {
    func pageViewControllerSupportedInterfaceOrientations(_: UIPageViewController) -> UIInterfaceOrientationMask {
        self.supportedInterfaceOrientations
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating _: Bool, previousViewControllers _: [UIViewController], transitionCompleted completed: Bool) {
    }
}

extension DPAGIntroViewController: UIPageViewControllerDataSource {
    func pageViewController(_: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if DPAGApplicationFacade.preferences.isWhiteLabelBuild, viewController == self.page0 {
            return self.page1
        }
        return nil
    }

    func pageViewController(_: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if viewController == self.page1 {
            return self.page0
        }
        return nil
    }
}
