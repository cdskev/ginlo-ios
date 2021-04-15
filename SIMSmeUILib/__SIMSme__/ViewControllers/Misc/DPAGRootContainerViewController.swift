//
//  DPAGRootContainerViewController.swift
//  SIMSme
//
//  Created by RBU on 22/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGRootContainerViewController: UIViewController, DPAGRootContainerViewControllerProtocol {
    static let sharedInstance = DPAGRootContainerViewController()

    var rootViewController: UIViewController? {
        didSet {
            if let rootViewControllerOld = oldValue {
                rootViewControllerOld.willMove(toParent: nil)
                rootViewControllerOld.view.removeFromSuperview()
                rootViewControllerOld.removeFromParent()
                rootViewControllerOld.didMove(toParent: nil)
            }

            if let rootViewController = self.rootViewController {
                rootViewController.view.translatesAutoresizingMaskIntoConstraints = false

                self.addChild(rootViewController)
                self.view.addSubview(rootViewController.view)
                self.view.addConstraintsFill(subview: rootViewController.view)

                rootViewController.didMove(toParent: self)

                self.setNeedsStatusBarAppearanceUpdate()
            }
        }
    }

    private init() {
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var childForStatusBarStyle: UIViewController? {
        if let rootViewController = self.rootViewController {
            return rootViewController
        }
        return nil
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
        if let rootViewController = self.rootViewController {
            return rootViewController.preferredInterfaceOrientationForPresentation
        }

        return super.preferredInterfaceOrientationForPresentation
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if let rootViewController = self.rootViewController {
            return rootViewController.supportedInterfaceOrientations
        }

        return super.supportedInterfaceOrientations
    }
}
