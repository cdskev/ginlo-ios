//
//  DPAGRuntimeConfigUI.swift
// ginlo
//
//  Created by RBU on 10/01/2017.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGRuntimeConfigUIProtocol: AnyObject {
    var splashDuration: TimeInterval { get }
    var showsDPAGApps: Bool { get }
    var showsInviteFriends: Bool { get }
    var canAskForRating: Bool { get }
    var ratingURL: String { get }

    func viewControllerForIdent(_ nextViewIdent: DPAGWhiteLabelNextView) -> UIViewController?
    func viewControllerContactSelectionForIdent(_ nextViewIdent: DPAGWhiteLabelContactSelectionNextView, contactsSelected: DPAGSearchListSelection<DPAGContact>) -> UIViewController?
}

open class DPAGRuntimeConfigUIBase: DPAGRuntimeConfig, DPAGRuntimeConfigUIProtocol {
    open var splashDuration: TimeInterval {
        0.5
    }

    open var showsDPAGApps: Bool {
        true
    }

    open var showsInviteFriends: Bool {
        true
    }

    open func viewControllerForIdent(_: DPAGWhiteLabelNextView) -> UIViewController? {
        nil
    }

    open func viewControllerContactSelectionForIdent(_: DPAGWhiteLabelContactSelectionNextView, contactsSelected _: DPAGSearchListSelection<DPAGContact>) -> UIViewController? {
        nil
    }

    open var ratingURL: String {
        "itms-apps://itunes.apple.com/app/id1498035143"
    }
}
