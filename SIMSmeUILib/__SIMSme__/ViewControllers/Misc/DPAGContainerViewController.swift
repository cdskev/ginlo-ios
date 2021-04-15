//
//  DPAGContainerViewController.swift
//  SIMSme
//
//  Created by RBU on 19/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGContainerViewController: UIViewController, DPAGContainerViewControllerProtocol {
    static let sharedInstance = DPAGContainerViewController()
    private var navigationMainController: UINavigationController
    private var navigationControllerCompletion: DPAGCompletion?

    private init() {
        self.navigationMainController = DPAGApplicationFacadeUIBase.navVC(rootViewController: nil)
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
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
        self.addChild(self.navigationMainController)
        self.navigationMainController.view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.navigationMainController.view)
        self.view.addConstraintsFill(subview: self.navigationMainController.view)
        self.navigationMainController.didMove(toParent: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    var mainNavigationController: UINavigationController {
        self.navigationMainController
    }

    var secondaryNavigationController: UINavigationController {
        self.navigationMainController
    }

    func showTopMainViewController(_ topMainViewController: UIViewController, completion: DPAGCompletion?) {
        self.showTopMainViewController(topMainViewController, addViewController: nil, completion: completion)
    }

    func showTopMainViewController(_ topMainViewController: UIViewController, animated: Bool, completion: DPAGCompletion?) {
        self.showTopMainViewController(topMainViewController, addViewController: nil, animated: animated, completion: completion)
    }

    func showTopMainViewController(_ topMainViewController: UIViewController, addViewController: UIViewController?, completion: DPAGCompletion?) {
        self.showTopMainViewController(topMainViewController, addViewController: addViewController, animated: true, completion: completion)
    }

    func showTopMainViewController(_ topMainViewController: UIViewController, addViewController: UIViewController?, animated: Bool, completion: DPAGCompletion?) {
        self.navigationControllerCompletion?()
        self.navigationControllerCompletion = nil
        self.navigationMainController.delegate = nil
        var addVCadded = true

        if let addViewController = addViewController {
            if completion != nil {
                self.navigationMainController.delegate = self
                self.navigationControllerCompletion = completion
            }
            if (self.navigationMainController.topViewController?.isKind(of: topMainViewController.classForCoder)) == false {
                if self.navigationMainController.presentedViewController != nil {
                    self.navigationMainController.presentedViewController?.dismiss(animated: true) { [weak self] in
                        self?.navigationMainController.setViewControllers([topMainViewController, addViewController], animated: animated)
                    }
                } else {
                    self.navigationMainController.setViewControllers([topMainViewController, addViewController], animated: animated)
                }
            } else {
                if self.navigationMainController.presentedViewController != nil {
                    self.navigationMainController.presentedViewController?.dismiss(animated: true) { [weak self] in
                        self?.navigationMainController.pushViewController(addViewController, animated: animated)
                    }
                } else {
                    self.navigationMainController.pushViewController(addViewController, animated: animated)
                }
            }
        } else {
            if (self.navigationMainController.topViewController?.isKind(of: topMainViewController.classForCoder)) == false {
                if completion != nil {
                    self.navigationMainController.delegate = self
                    self.navigationControllerCompletion = completion
                }
                if self.navigationMainController.presentedViewController != nil {
                    self.navigationMainController.presentedViewController?.dismiss(animated: true) { [weak self] in
                        self?.navigationMainController.setViewControllers([topMainViewController], animated: animated)
                    }
                } else {
                    self.navigationMainController.setViewControllers([topMainViewController], animated: animated)
                }
            } else {
                addVCadded = false
            }
        }
        if addVCadded == false {
            if self.navigationMainController.presentedViewController != nil {
                self.navigationMainController.presentedViewController?.dismiss(animated: true) {
                    topMainViewController.viewDidAppear(true)
                    completion?()
                }
            } else {
                topMainViewController.viewDidAppear(true)
                completion?()
            }
        }
    }

    func showTopMainViewController(_ topMainViewController: UIViewController, addViewControllers: [UIViewController], animated: Bool, completion: DPAGCompletion?) {
        self.navigationControllerCompletion?()
        self.navigationControllerCompletion = nil
        self.navigationMainController.delegate = nil
        if addViewControllers.isEmpty {
            self.showTopMainViewController(topMainViewController, addViewController: nil, animated: animated, completion: completion)
            return
        } else {
            if completion != nil {
                self.navigationMainController.delegate = self
                self.navigationControllerCompletion = completion
            }
            if (self.navigationMainController.topViewController?.isKind(of: topMainViewController.classForCoder)) == false {
                var viewControllers = [topMainViewController]
                viewControllers.append(contentsOf: addViewControllers)
                self.navigationMainController.setViewControllers(viewControllers, animated: animated)
            } else {
                var vcs = self.navigationMainController.viewControllers
                vcs.append(contentsOf: addViewControllers)
                self.navigationMainController.setViewControllers(vcs, animated: animated)
            }
        }
    }

    func pushMainViewController(_ mainViewController: UIViewController, animated: Bool) {
        self.mainNavigationController.pushViewController(mainViewController, animated: animated)
    }
    
    func showSecondaryViewController(_ topSecondaryViewController: UIViewController, completion: DPAGCompletion?) {
        self.showTopMainViewController(topSecondaryViewController, addViewController: nil, completion: completion)
    }

    func showSecondaryViewController(_ topSecondaryViewController: UIViewController, animated: Bool, completion: DPAGCompletion?) {
        self.showTopMainViewController(topSecondaryViewController, addViewController: nil, animated: animated, completion: completion)
    }

    func showSecondaryViewController(_ topSecondaryViewController: UIViewController, addViewController: UIViewController?, completion: DPAGCompletion?) {
        self.showTopMainViewController(topSecondaryViewController, addViewController: addViewController, animated: true, completion: completion)
    }

    func showSecondaryViewController(_ topSecondaryViewController: UIViewController, addViewControllers: [UIViewController], animated: Bool, completion: DPAGCompletion?) {
        self.showTopMainViewController(topSecondaryViewController, addViewControllers: addViewControllers, animated: animated, completion: completion)
    }

    func showSecondaryViewController(_ topSecondaryViewController: UIViewController, addViewController: UIViewController?, animated: Bool, completion: DPAGCompletion?) {
        self.showTopMainViewController(topSecondaryViewController, addViewController: addViewController, animated: animated, completion: completion)
    }

    func pushSecondaryViewController(_ secondaryViewController: UIViewController, animated: Bool) {
        self.secondaryNavigationController.pushViewController(secondaryViewController, animated: animated)
    }
}

extension DPAGContainerViewController: UINavigationControllerDelegate {
    func navigationController(_: UINavigationController, didShow _: UIViewController, animated _: Bool) {
        self.navigationControllerCompletion?()
        self.navigationControllerCompletion = nil
        self.navigationMainController.delegate = nil
    }
}
