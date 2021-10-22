//
//  DPAGRuntimeConfigUI.swift
// ginlo
//
//  Created by RBU on 10/01/2017.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import SIMSmeUILib
import UIKit

class DPAGRuntimeConfigUI: DPAGRuntimeConfigUIBase {
    override func viewControllerForIdent(_ nextViewIdent: DPAGWhiteLabelNextView) -> UIViewController? {
        var rc: UIViewController?

        switch nextViewIdent {
            case .dpagIntroViewController_handleFinishIntroTapped:
                if let automaticMdmRegistrationValues = DPAGApplicationFacade.preferences.automaticMdmRegistrationValues {
                    rc = DPAGApplicationFacadeUIRegistration.requestAutomaticRegistrationVC(registrationValues: automaticMdmRegistrationValues)
                } else {
                    rc = DPAGApplicationFacadeUIRegistration.initialPasswordVC(initialPasswordJob: .createAccount)
                }
            case .dpagIntroViewController_handleScanInvitationTapped:
                rc = DPAGApplicationFacadeUIRegistration.initialPasswordVC(initialPasswordJob: .scanInvitation)
            case .dpagIntroViewController_haveAutomaticInvitation:
                rc = DPAGApplicationFacadeUIRegistration.initialPasswordVC(initialPasswordJob: .executeInvitation)
            case .dpagPasswordForgotViewController:
                rc = DPAGApplicationFacadeUIBase.initialPasswordForgotVC()
            case .dpagTestLicenseViewController:
                rc = nil
            case .dpagLicenseInitViewController:
                rc = nil
            case .dpagProfileViewController_startCompanyProfilInitPhoneNumberController:
                rc = DPAGApplicationFacadeUISettings.companyProfilInitPhoneNumberVC()
            case .dpagProfileViewController_startCompanyProfilConfirmPhoneNumberController:
                rc = DPAGApplicationFacadeUISettings.companyProfilConfirmPhoneNumberVC()
            default:
                rc = super.viewControllerForIdent(nextViewIdent)
        }

        return rc
    }

    override func viewControllerContactSelectionForIdent(_ nextViewIdent: DPAGWhiteLabelContactSelectionNextView, contactsSelected: DPAGSearchListSelection<DPAGContact>) -> UIViewController? {
        var rc: UIViewController?

        switch nextViewIdent {
            case .dpagNavigationDrawerViewController_startContactController:
                rc = DPAGApplicationFacadeUIContacts.contactsVC(contactsSelected: contactsSelected)
            case .dpagSelectDistributionListMembersViewController:
                rc = DPAGApplicationFacadeUIContacts.contactsSelectionDistributionListMembersVC(contactsSelected: contactsSelected)
            case .dpagSelectGroupChatMembersAddViewController:
                rc = DPAGApplicationFacadeUIContacts.contactsSelectionGroupMembersAddVC(contactsSelected: contactsSelected)
            case .dpagNewChatViewController:
                rc = DPAGApplicationFacadeUIContacts.contactsSelectionNewChatVC(contactsSelected: contactsSelected)
            case .dpagSelectReceiverViewController:
                rc = DPAGApplicationFacadeUIContacts.contactsSelectionReceiverVC(contactsSelected: contactsSelected)
            case .dpagSelectContactSendingViewController:
                rc = DPAGApplicationFacadeUIContacts.contactsSelectionSendingVC(contactsSelected: contactsSelected)
        }

        return rc
    }
}
