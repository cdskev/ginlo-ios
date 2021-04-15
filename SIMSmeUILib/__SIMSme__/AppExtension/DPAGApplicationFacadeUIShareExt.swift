//
//  DPAGApplicationFacadeUIShareExt.swift
//  shareExtensionTest
//
//  Created by Robert Burchert on 01.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

extension DPAGApplicationFacadeShareExt {
    static func viewControllerContactSelectionForIdent(_ nextViewIdent: DPAGWhiteLabelContactSelectionNextView, contactsSelected: DPAGSearchListSelection<DPAGContact>) -> UIViewController? {
        var rc: UIViewController?

        if nextViewIdent == .dpagSelectReceiverViewController {
            if let account = DPAGApplicationFacadeShareExt.cache.account, DPAGApplicationFacadeShareExt.preferences.isCompanyManagedState, account.isCompanyUserRestricted {
                rc = DPAGApplicationFacadeUIContacts.contactsSelectionReceiverCompanyVC(contactsSelected: contactsSelected)
            } else if DPAGApplicationFacade.preferences.isCompanyManagedState {
                if let account = DPAGApplicationFacadeShareExt.cache.account, let contact = DPAGApplicationFacadeShareExt.cache.contact(for: account.guid), contact.eMailDomain != nil {
                    rc = DPAGApplicationFacadeUIContacts.contactsSelectionReceiverCompanyDomainPagesVC(contactsSelected: contactsSelected)
                } else {
                    rc = DPAGApplicationFacadeUIContacts.contactsSelectionReceiverCompanyPagesVC(contactsSelected: contactsSelected)
                }
            } else {
                if let account = DPAGApplicationFacadeShareExt.cache.account, let contact = DPAGApplicationFacadeShareExt.cache.contact(for: account.guid), contact.eMailDomain != nil {
                    rc = DPAGApplicationFacadeUIContacts.contactsSelectionReceiverDomainPagesVC(contactsSelected: contactsSelected)
                } else {
                    rc = DPAGApplicationFacadeUIContacts.contactsSelectionReceiverVC(contactsSelected: contactsSelected)
                }
            }
        }

        return rc
    }
}
