//
//  GNSplitContainerViewController.swift
//  Ginlo
//
//  Created by Imdat Solak (iso), 2021-01-30
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class GNSplitContainerViewController: UISplitViewController, DPAGContainerViewControllerProtocol {
    static let sharedInstance = GNSplitContainerViewController()
    private var navigationControllerCompletion: DPAGCompletion?
    private var navigationMainController: UINavigationController
    private var navigationSecondaryController: UINavigationController

    private init() {
        self.navigationMainController = DPAGApplicationFacadeUIBase.navVC(rootViewController: nil)
        self.navigationSecondaryController = DPAGApplicationFacadeUIBase.navVC(rootViewController: nil)
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
        self.preferredDisplayMode = .allVisible
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var childForStatusBarStyle: UIViewController? {
        if let topmostLocalNotification = DPAGLocalNotificationViewController.topmostLocalNotification {
            return topmostLocalNotification
        }
        return self.mainNavigationController
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if let vc = self.childForStatusBarStyle {
            return vc.preferredStatusBarStyle
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
        if let vc = self.childForStatusBarStyle {
            return vc.shouldAutorotate
        }
        return true
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        self.mainNavigationController.preferredInterfaceOrientationForPresentation
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        self.mainNavigationController.supportedInterfaceOrientations
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.viewControllers = [self.navigationMainController, self.navigationSecondaryController]
        self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground2]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    var mainNavigationController: UINavigationController {
        navigationMainController
    }
    
    var secondaryNavigationController: UINavigationController {
        navigationSecondaryController
    }

    // THE ONE THAT DOES THE WORK ("HERMANN")
    private func showViewController(inPrimaryController: Bool, topViewController: UIViewController, addViewController: UIViewController?, animated: Bool, completion: DPAGCompletion?) {
        self.navigationControllerCompletion?()
        self.navigationControllerCompletion = nil
        var addVCadded = true

        if let addViewController = addViewController {
            if inPrimaryController {
                if completion != nil {
                    self.navigationControllerCompletion = completion
                    self.mainNavigationController.delegate = self
                }
                self.pushMainViewController(addViewController, animated: animated)
            } else {
                if completion != nil {
                    self.navigationControllerCompletion = completion
                    self.secondaryNavigationController.delegate = self
                }
                self.pushSecondaryViewController(addViewController, animated: animated)
            }
        } else {
            if (self.mainNavigationController.topViewController?.isKind(of: topViewController.classForCoder)) == false {
                if inPrimaryController {
                    if completion != nil {
                        self.navigationControllerCompletion = completion
                        self.mainNavigationController.delegate = self
                    }
                    self.pushMainViewController(topViewController, animated: animated)
                } else {
                    if completion != nil {
                        self.navigationControllerCompletion = completion
                        self.secondaryNavigationController.delegate = self
                    }
                    self.pushSecondaryViewController(topViewController, animated: animated)
                }
            } else {
                addVCadded = false
            }
        }
        if addVCadded == false {
            topViewController.viewDidAppear(true)
            completion?()
        }
    }
    
    // MAIN View Controller Functions

    func showTopMainViewController(_ topMainViewController: UIViewController, completion: DPAGCompletion?) {
        self.showTopMainViewController(topMainViewController, addViewController: nil, completion: completion)
    }

    func showTopMainViewController(_ topMainViewController: UIViewController, animated: Bool, completion: DPAGCompletion?) {
        self.showTopMainViewController(topMainViewController, addViewController: nil, animated: animated, completion: completion)
    }

    func showTopMainViewController(_ topMainViewController: UIViewController, addViewController: UIViewController?, completion: DPAGCompletion?) {
        self.showTopMainViewController(topMainViewController, addViewController: addViewController, animated: true, completion: completion)
    }

    func showTopMainViewController(_ topMainViewController: UIViewController, addViewControllers: [UIViewController], animated: Bool, completion: DPAGCompletion?) {
        if addViewControllers.isEmpty {
            self.showTopMainViewController(topMainViewController, addViewController: nil, animated: animated, completion: completion)
        } else {
            self.showTopMainViewController(topMainViewController, addViewController: addViewControllers.last, animated: animated, completion: completion)
        }
    }
    
    func showTopMainViewController(_ topMainViewController: UIViewController, addViewController: UIViewController?, animated: Bool, completion: DPAGCompletion?) {
        self.showViewController(inPrimaryController: true, topViewController: topMainViewController, addViewController: addViewController, animated: animated, completion: completion)
    }

    func pushMainViewController(_ mainViewController: UIViewController, animated: Bool) {
        self.navigationMainController.pushViewController(mainViewController, animated: animated)
    }

    // SECONDARY VIEW CONTROLLER FUNCTIONS
    func showSecondaryViewController(_ topSecondaryViewController: UIViewController, completion: DPAGCompletion?) {
        self.showSecondaryViewController(topSecondaryViewController, addViewController: nil, completion: completion)
    }

    func showSecondaryViewController(_ topSecondaryViewController: UIViewController, animated: Bool, completion: DPAGCompletion?) {
        self.showSecondaryViewController(topSecondaryViewController, addViewController: nil, animated: animated, completion: completion)
    }

    func showSecondaryViewController(_ topSecondaryViewController: UIViewController, addViewController: UIViewController?, completion: DPAGCompletion?) {
        self.showSecondaryViewController(topSecondaryViewController, addViewController: addViewController, animated: true, completion: completion)
    }

    func showSecondaryViewController(_ topSecondaryViewController: UIViewController, addViewControllers: [UIViewController], animated: Bool, completion: DPAGCompletion?) {
        if addViewControllers.isEmpty {
            self.showSecondaryViewController(topSecondaryViewController, addViewController: nil, animated: animated, completion: completion)
        } else {
            self.showSecondaryViewController(topSecondaryViewController, addViewController: addViewControllers.last, animated: animated, completion: completion)
        }
    }

    func showSecondaryViewController(_ topSecondaryViewController: UIViewController, addViewController: UIViewController?, animated: Bool, completion: DPAGCompletion?) {
        self.showViewController(inPrimaryController: false, topViewController: topSecondaryViewController, addViewController: addViewController, animated: animated, completion: completion)
    }
    
    func pushSecondaryViewController(_ secondaryViewController: UIViewController, animated: Bool) {
        self.navigationSecondaryController.setViewControllers([secondaryViewController], animated: false)
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

extension GNSplitContainerViewController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, didShow _: UIViewController, animated _: Bool) {
        self.navigationControllerCompletion?()
        self.navigationControllerCompletion = nil
        navigationController.delegate = nil
    }
}
