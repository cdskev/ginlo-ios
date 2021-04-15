//
//  DPAGMDMPreferences+Extensions.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore

public extension DPAGMDMPreferences {
    var showDPAGApps: Bool {
        (DPAGApplicationFacade.runtimeConfig as? DPAGRuntimeConfigUIProtocol)?.showsDPAGApps ?? true
    }

    var showInviteFriends: Bool {
        (DPAGApplicationFacade.runtimeConfig as? DPAGRuntimeConfigUIProtocol)?.showsInviteFriends ?? true
    }

    var splashDuration: TimeInterval {
        (DPAGApplicationFacade.runtimeConfig as? DPAGRuntimeConfigUIProtocol)?.splashDuration ?? TimeInterval(0)
    }

    func viewControllerForIdent(_ nextViewIdent: DPAGWhiteLabelNextView) -> UIViewController? {
        (DPAGApplicationFacade.runtimeConfig as? DPAGRuntimeConfigUIProtocol)?.viewControllerForIdent(nextViewIdent)
    }

    func viewControllerContactSelectionForIdent(_ nextViewIdent: DPAGWhiteLabelContactSelectionNextView, contactsSelected: DPAGSearchListSelection<DPAGContact>) -> UIViewController? {
        (DPAGApplicationFacade.runtimeConfig as? DPAGRuntimeConfigUIProtocol)?.viewControllerContactSelectionForIdent(nextViewIdent, contactsSelected: contactsSelected)
    }

    var ratingURL: String {
        (DPAGApplicationFacade.runtimeConfig as? DPAGRuntimeConfigUIProtocol)?.ratingURL ?? "itms-apps://itunes.apple.com/app/id1498033756"
    }
}
