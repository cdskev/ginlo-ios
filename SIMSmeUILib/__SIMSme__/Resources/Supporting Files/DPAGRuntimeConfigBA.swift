//
//  DPAGRuntimeConfigBA.swift
//  SIMSme
//
//  Created by RBU on 10/01/2017.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import SIMSmeUILib
import UIKit

class DPAGRuntimeConfigBA: DPAGRuntimeConfigWhiteLabel {
    override var sharedContainerConfig: DPAGSharedContainerConfig {
        DPAGSharedContainerConfig(keychainAccessGroupName: AppConfig.keychainAccessGroupName, groupID: AppConfig.groupId, urlHttpService: AppConfig.urlHttpService)
    }

    override var fulltextSize: Int {
        100
    }

    override var maxFileSize: UInt64 {
        0x6400000
    }

    override var isBaMandant: Bool {
        true
    }

    override var configChecksum: String? {
        DPAGRuntimeConfigWhiteLabel.CONFIG_CHECKSUM_BA
    }

    override func viewControllerForIdent(_ nextViewIdent: DPAGWhiteLabelNextView) -> UIViewController? {
        var rc: UIViewController?

        switch nextViewIdent {
            case .dpagProfileViewController_startCompanyProfilInitEMailController:
                rc = DPAGApplicationFacadeUISettings.companyProfilInitEMailVC()
            case .dpagProfileViewController_startCompanyProfilConfirmEMailController:
                rc = DPAGApplicationFacadeUISettings.companyProfilConfirmEMailVC()
            case .dpagProfileViewController_startCompanyProfilInitPhoneNumberController:
                rc = DPAGApplicationFacadeUISettings.companyProfilInitPhoneNumberVC()
            case .dpagProfileViewController_startCompanyProfilConfirmPhoneNumberController:
                rc = DPAGApplicationFacadeUISettings.companyProfilConfirmPhoneNumberVC()
            case .dpagPasswordForgotViewController:
                rc = DPAGApplicationFacadeUIRegistration.companyPasswordForgotVC()
            case .dpagTestLicenseViewController:
                rc = DPAGApplicationFacadeUIRegistration.testLicense()
            case .dpagLicenseInitViewController:
                rc = DPAGApplicationFacadeUIRegistration.licencesInitVC()
            default:
                rc = super.viewControllerForIdent(nextViewIdent)
        }
        return rc ?? super.viewControllerForIdent(nextViewIdent)
    }

    override func viewControllerContactSelectionForIdent(_ nextViewIdent: DPAGWhiteLabelContactSelectionNextView, contactsSelected: DPAGSearchListSelection<DPAGContact>) -> UIViewController? {
        var rc: UIViewController?
        switch nextViewIdent {
            case .dpagNavigationDrawerViewController_startContactController:
                if let account = DPAGApplicationFacade.cache.account, DPAGApplicationFacade.preferences.isCompanyManagedState, account.isCompanyUserRestricted {
                    rc = DPAGApplicationFacadeUIContacts.contactsCompanyVC(contactsSelected: contactsSelected)
                } else if DPAGApplicationFacade.preferences.isCompanyManagedState {
                    if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), contact.eMailDomain != nil {
                        rc = DPAGApplicationFacadeUIContacts.contactsCompanyDomainPagesVC(contactsSelected: contactsSelected)
                    } else {
                        rc = DPAGApplicationFacadeUIContacts.contactsCompanyPagesVC(contactsSelected: contactsSelected)
                    }
                } else {
                    rc = DPAGApplicationFacadeUIContacts.contactsDomainPagesVC(contactsSelected: contactsSelected)
                }
            case .dpagNewChatViewController:
                if let account = DPAGApplicationFacade.cache.account, DPAGApplicationFacade.preferences.isCompanyManagedState, account.isCompanyUserRestricted {
                    rc = DPAGApplicationFacadeUIContacts.contactsSelectionNewChatCompanyVC(contactsSelected: contactsSelected)
                } else if DPAGApplicationFacade.preferences.isCompanyManagedState {
                    if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), contact.eMailDomain != nil {
                        rc = DPAGApplicationFacadeUIContacts.contactsSelectionNewChatCompanyDomainPagesVC(contactsSelected: contactsSelected)
                    } else {
                        rc = DPAGApplicationFacadeUIContacts.contactsSelectionNewChatCompanyPagesVC(contactsSelected: contactsSelected)
                    }
                } else {
                    rc = DPAGApplicationFacadeUIContacts.contactsSelectionNewChatDomainPagesVC(contactsSelected: contactsSelected)
                }
            case .dpagSelectGroupChatMembersAddViewController:
                if let account = DPAGApplicationFacade.cache.account, DPAGApplicationFacade.preferences.isCompanyManagedState, account.isCompanyUserRestricted {
                    rc = DPAGApplicationFacadeUIContacts.contactsSelectionGroupMembersAddCompanyVC(contactsSelected: contactsSelected)
                } else if DPAGApplicationFacade.preferences.isCompanyManagedState {
                    if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), contact.eMailDomain != nil {
                        rc = DPAGApplicationFacadeUIContacts.contactsSelectionGroupMembersAddCompanyDomainPagesVC(contactsSelected: contactsSelected)
                    } else {
                        rc = DPAGApplicationFacadeUIContacts.contactsSelectionGroupMembersAddCompanyPagesVC(contactsSelected: contactsSelected)
                    }
                } else {
                    rc = DPAGApplicationFacadeUIContacts.contactsSelectionGroupMembersAddDomainPagesVC(contactsSelected: contactsSelected)
                }
            case .dpagSelectDistributionListMembersViewController:
                if let account = DPAGApplicationFacade.cache.account, DPAGApplicationFacade.preferences.isCompanyManagedState, account.isCompanyUserRestricted {
                    rc = DPAGApplicationFacadeUIContacts.contactsSelectionDistributionListMembersCompanyVC(contactsSelected: contactsSelected)
                } else if DPAGApplicationFacade.preferences.isCompanyManagedState {
                    if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), contact.eMailDomain != nil {
                        rc = DPAGApplicationFacadeUIContacts.contactsSelectionDistributionListMembersCompanyDomainPagesVC(contactsSelected: contactsSelected)
                    } else {
                        rc = DPAGApplicationFacadeUIContacts.contactsSelectionDistributionListMembersCompanyPagesVC(contactsSelected: contactsSelected)
                    }
                } else {
                    rc = DPAGApplicationFacadeUIContacts.contactsSelectionDistributionListMembersDomainPagesVC(contactsSelected: contactsSelected)
                }
            case .dpagSelectReceiverViewController:
                if let account = DPAGApplicationFacade.cache.account, DPAGApplicationFacade.preferences.isCompanyManagedState, account.isCompanyUserRestricted {
                    rc = DPAGApplicationFacadeUIContacts.contactsSelectionReceiverCompanyVC(contactsSelected: contactsSelected)
                } else if DPAGApplicationFacade.preferences.isCompanyManagedState {
                    if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), contact.eMailDomain != nil {
                        rc = DPAGApplicationFacadeUIContacts.contactsSelectionReceiverCompanyDomainPagesVC(contactsSelected: contactsSelected)
                    } else {
                        rc = DPAGApplicationFacadeUIContacts.contactsSelectionReceiverCompanyPagesVC(contactsSelected: contactsSelected)
                    }
                } else {
                    rc = DPAGApplicationFacadeUIContacts.contactsSelectionReceiverDomainPagesVC(contactsSelected: contactsSelected)
                }
            case .dpagSelectContactSendingViewController:
                if let account = DPAGApplicationFacade.cache.account, DPAGApplicationFacade.preferences.isCompanyManagedState, account.isCompanyUserRestricted {
                    rc = DPAGApplicationFacadeUIContacts.contactsSelectionSendingCompanyVC(contactsSelected: contactsSelected)
                } else if DPAGApplicationFacade.preferences.isCompanyManagedState {
                    if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), contact.eMailDomain != nil {
                        rc = DPAGApplicationFacadeUIContacts.contactsSelectionSendingCompanyDomainPagesVC(contactsSelected: contactsSelected)
                    } else {
                        rc = DPAGApplicationFacadeUIContacts.contactsSelectionSendingCompanyPagesVC(contactsSelected: contactsSelected)
                    }
                } else {
                    rc = DPAGApplicationFacadeUIContacts.contactsSelectionSendingDomainPagesVC(contactsSelected: contactsSelected)
                }
        }
        return rc ?? super.viewControllerContactSelectionForIdent(nextViewIdent, contactsSelected: contactsSelected)
    }
}
