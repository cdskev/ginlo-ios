//
//  DPAGApplicationFacadeUI.swift
//  SIMSmeUILib
//
//  Created by RBU on 26.05.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public struct DPAGApplicationFacadeUIBase {
    private init() {}

    public static let loginVC: (UIViewController & DPAGLoginViewControllerProtocol) = DPAGLoginViewController.sharedInstance
    public static let audioHelper: DPAGAudioHelperProtocol = DPAGAudioHelper()
    public static let proximityHelper: DPAGProximityHelperProtocol = DPAGProximityHelper()
    
    public static var containerVC: UIViewController & DPAGContainerViewControllerProtocol {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return GNSplitContainerViewController.sharedInstance
        } else {
            return DPAGContainerViewController.sharedInstance
        }
    }
    
    public static var rootContainerVC: UIViewController & DPAGRootContainerViewControllerProtocol { DPAGRootContainerViewController.sharedInstance }

    public static func defaultTransparentTransitioningDelegate() -> UIViewControllerTransitioningDelegate { DPAGDefaultTransparentTransitioningDelegate() }
    public static func defaultAnimatedTransitioningDelegate() -> UIViewControllerTransitioningDelegate { DPAGDefaultAnimatedTransitioningDelegate() }
    public static func passwordComplexVC(secLevelView showSecLevel: Bool, isNewPassword: Bool) -> (UIViewController & DPAGComplexPasswordViewControllerProtocol) { DPAGComplexPasswordViewController(secLevelView: showSecLevel, isNewPassword: isNewPassword) }
    public static func passwordPINVC(secLevelView showSecLevel: Bool) -> (UIViewController & DPAGPINPasswordViewControllerProtocol) { DPAGPINPasswordViewController(secLevelView: showSecLevel) }
    public static func passwordTouchIDVC() -> (UIViewController & DPAGTouchIDPasswordViewControllerProtocol) { DPAGTouchIDPasswordViewController() }
    public static func passwordForgotVC() -> (UIViewController) { DPAGPasswordForgotViewController() }
    public static func initialPasswordForgotVC() -> (UIViewController) { DPAGInitialPasswordForgotViewController() }
    public static func passwordForgotRecoveryVC() -> (UIViewController) { DPAGPasswordForgotRecoveryViewController() }
    public static var sharedApplication: UIApplication?

    public static func navVC(rootViewController: UIViewController?) -> (UINavigationController & DPAGNavigationControllerProtocol) {
        let retVal = DPAGNavigationController(navigationBarClass: DPAGNavigationBar.self, toolbarClass: nil)
        retVal.modalPresentationStyle = .fullScreen
        if let rootViewController = rootViewController {
            retVal.viewControllers = [rootViewController]
        }
        return retVal
    }
}
