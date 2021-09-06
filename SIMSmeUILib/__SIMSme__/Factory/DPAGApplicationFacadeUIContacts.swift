//
//  DPAGApplicationFacadeUI.swift
//  SIMSmeUILib
//
//  Created by RBU on 26.05.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Contacts
import SIMSmeCore
import AVFoundation
import UIKit

protocol DPAGContactsOptionsViewControllerProtocol: DPAGTableViewControllerWithReloadProtocol {
    func createModel()
}

protocol DPAGContactsOptionsProtocol: AnyObject {
    var progressHUDSyncInfo: DPAGProgressHUDWithLabelProtocol? { get set }
    func handleOptions(presentingVC: UIViewController, modelVC: DPAGContactsOptionsViewControllerProtocol, barButtonItem: UIBarButtonItem?)
    func updateWithAddressbook(presentingVC: UIViewController, modelVC: DPAGContactsOptionsViewControllerProtocol)
}

extension DPAGContactsOptionsProtocol {
    func handleOptions(presentingVC: UIViewController, modelVC: DPAGContactsOptionsViewControllerProtocol, barButtonItem: UIBarButtonItem? = nil) {
        let optionInvite = AlertOption(title: DPAGLocalizedString("contacts.options.invite"), style: .default, image: DPAGImageProvider.shared[.kImageMenuNewInviteFriends], accesibilityIdentifier: "contacts.options.invite", handler: { [weak presentingVC] in
            SharingHelper().showSharingForInvitation(fromViewController: presentingVC, sourceView: nil, sourceRect: nil, barButtonItem: barButtonItem)
        })
        let optionScanContact = AlertOption(title: DPAGLocalizedString("chat.list.action.scanContact"), style: .default, image: DPAGImageProvider.shared[.kScan], accesibilityIdentifier: "chat.list.action.scanContact", handler: { [weak self, weak presentingVC, weak modelVC] in
            modelVC?.reloadOnAppear = true
            if let presentingVC = presentingVC, let modelVC = modelVC {
                self?.scanContact(presentingVC: presentingVC, modelVC: modelVC)
            }
        })
        let optionAddContact = AlertOption(title: DPAGLocalizedString("contacts.options.addContact"), style: .default, image: DPAGImageProvider.shared[.kMagnifyingGlassCircle], accesibilityIdentifier: "contacts.options.addContact", handler: { [weak presentingVC, weak modelVC] in
            let nextVC = DPAGApplicationFacadeUIContacts.contactNewSearchVC()
            presentingVC?.navigationController?.pushViewController(nextVC, animated: true)
            modelVC?.reloadOnAppear = true
        })
        let optionUpdateWithAddressBook = AlertOption(title: DPAGLocalizedString("contacts.options.updateContactsWithAddressBook"), style: .default, image: DPAGImageProvider.shared[.kImageReload], accesibilityIdentifier: "contacts.options.updateContactsWithAddressBook", handler: { [weak self, weak presentingVC, weak modelVC] in
            if let presentingVC = presentingVC, let modelVC = modelVC {
                self?.updateWithAddressbook(presentingVC: presentingVC, modelVC: modelVC)
            }
        })
        let optionCancel = AlertOption(title: DPAGLocalizedString("res.cancel"), style: .cancel)
        let options = [optionInvite, optionScanContact, optionAddContact, optionUpdateWithAddressBook, optionCancel]
        let alertController: UIAlertController
        if let barButtonItem = barButtonItem {
            alertController = UIAlertController.controller(options: options, titleString: nil, withStyle: .actionSheet, accessibilityIdentifier: "contacts.options", sourceView: nil, sourceRect: nil, barButtonItem: barButtonItem)
        } else {
            alertController = UIAlertController.controller(options: options, withStyle: .alert, accessibilityIdentifier: "contacts.options")
        }
        presentingVC.presentAlertController(alertController)
            
    }

    func updateWithAddressbook(presentingVC: UIViewController, modelVC: DPAGContactsOptionsViewControllerProtocol) {
        switch CNContactStore.authorizationStatus(for: .contacts) {
            case .authorized:
                self.progressHUDSyncInfo = DPAGProgressHUDWithLabel.sharedInstanceLabel.showForBackgroundProcess(true, completion: { [weak modelVC] _ in
                    let observer = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfo, object: nil, queue: .main, using: { [weak self] aNotification in
                        self?.handleKnownContactsSyncInfo(aNotification)
                    })
                    DPAGApplicationFacade.updateKnownContactsWorker.updateWithAddressbook()
                    NotificationCenter.default.removeObserver(observer)
                    modelVC?.createModel()
                    DPAGProgressHUDWithLabel.sharedInstanceLabel.hide(true) { [weak modelVC] in
                        modelVC?.tableView.reloadData()
                    }
                }) as? DPAGProgressHUDWithLabelProtocol
            case .denied, .restricted:
                let actionOK = UIAlertAction(titleIdentifier: "noContactsView.alert.settings", style: .default, handler: { _ in
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        AppConfig.openURL(url)
                    }
                })
                presentingVC.presentAlert(alertConfig: UIViewController.AlertConfig(messageIdentifier: "noContactsView.title.titleTextView", cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
            case .notDetermined:
                CNContactStore().requestAccess(for: .contacts, completionHandler: { [weak self, weak presentingVC, weak modelVC] granted, error in
                    if granted, error == nil, let presentingVC = presentingVC, let modelVC = modelVC {
                        self?.updateWithAddressbook(presentingVC: presentingVC, modelVC: modelVC)
                    }
                })
            @unknown default:
                DPAGLog("Switch with unknown value: \(CNContactStore.authorizationStatus(for: .contacts).rawValue)", level: .warning)
        }
    }
    
    private func scanContact(presentingVC: UIViewController?, modelVC: DPAGContactsOptionsViewControllerProtocol?) {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authStatus {
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video, completionHandler: { [weak self] _ in
                    DispatchQueue.main.async { [weak self] in
                        self?.scanContact(presentingVC: presentingVC, modelVC: modelVC)
                    }
                })
            case .authorized:
                let nextVC = DPAGApplicationFacadeUIRegistration.scanInvitationVC(blockSuccess: { [weak presentingVC, weak self] (text: String) in
                    if let strongVC = presentingVC, let strongSelf = self {
                        if let invitationData = DPAGApplicationFacade.contactsWorker.parseInvitationQRCode(invitationContent: text), let accountID = invitationData["i"] as? String, let signature = invitationData["s"] as? Data {
                            strongSelf.searchAccount(accountID: accountID, signature: signature, presentingVC: strongVC)
                        }
                    }
                }, blockFailed: { [weak presentingVC] in
                    presentingVC?.presentErrorAlert(alertConfig: UIViewController.AlertConfigError(messageIdentifier: "registration.createDeviceConfirm.verifyingQRCodeFailed", okActionHandler: { [weak presentingVC] _ in
                        if let strongVC = presentingVC {
                            strongVC.navigationController?.popToViewController(strongVC, animated: true)
                        }
                    }))
                }, blockCancelled: { [weak presentingVC] in
                    if let strongVC = presentingVC {
                        strongVC.navigationController?.popToViewController(strongVC, animated: true)
                    }
                })
                presentingVC?.navigationController?.pushViewController(nextVC, animated: true)
            default:
                break
        }
    }
    
    private func searchAccount(accountID: String, signature: Data?, presentingVC: UIViewController) {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
            DPAGApplicationFacade.contactsWorker.searchAccount(searchData: accountID, searchMode: .accountID) { responseObject, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak presentingVC] in
                    if let errorMessage = errorMessage {
                        presentingVC?.presentErrorAlert(alertConfig: UIViewController.AlertConfigError(titleIdentifier: "attention", messageIdentifier: errorMessage))
                    } else if let guids = responseObject as? [String] {
                        if let account = DPAGApplicationFacade.cache.account, let contactSelf = DPAGApplicationFacade.cache.contact(for: account.guid) {
                           if let guid = guids.first, let contactCache = DPAGApplicationFacade.cache.contact(for: guid) {
                                switch contactCache.entryTypeServer {
                                    case .company:
                                        let nextVC = DPAGApplicationFacadeUIContacts.contactDetailsVC(contact: contactCache)
                                        presentingVC?.navigationController?.pushViewController(nextVC, animated: true)
                                    case .email:
                                        if contactCache.eMailDomain == contactSelf.eMailDomain {
                                            let nextVC = DPAGApplicationFacadeUIContacts.contactDetailsVC(contact: contactCache)
                                            presentingVC?.navigationController?.pushViewController(nextVC, animated: true)
                                        } else {
                                            let nextVC = DPAGApplicationFacadeUIContacts.contactNewCreateVC(contact: contactCache)
                                            presentingVC?.navigationController?.pushViewController(nextVC, animated: true)
                                        }
                                    case .meMyselfAndI:
                                        break
                                    case .privat:
                                        let nextVC = DPAGApplicationFacadeUIContacts.contactNewCreateVC(contact: contactCache)
                                        if let signature = signature, let publicKey = contactCache.publicKey, DPAGApplicationFacade.contactsWorker.validateSignature(signature: signature, publicKey: publicKey) {
                                            nextVC.confirmConfidence = true
                                        }
                                        presentingVC?.navigationController?.pushViewController(nextVC, animated: true)
                                }
                            } else {
                                let nextVC = DPAGApplicationFacadeUIContacts.contactNotFoundVC(searchData: accountID, searchMode: .accountID)
                                presentingVC?.navigationController?.pushViewController(nextVC, animated: true)
                            }
                        } else {
                            let nextVC = DPAGApplicationFacadeUIContacts.contactNotFoundVC(searchData: accountID, searchMode: .accountID)
                            presentingVC?.navigationController?.pushViewController(nextVC, animated: true)
                        }
                    }
                }
            }
        }
    }

    private func handleKnownContactsSyncInfo(_ aNotification: Notification) {
        if let syncInfoState = aNotification.userInfo?[DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyState] as? DPAGUpdateKnownContactsWorkerSyncInfoState {
            if let step = aNotification.userInfo?[DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyProgressStep] as? Int {
                if let stepMax = aNotification.userInfo?[DPAGStrings.Notification.UpdateKnownContactsWorker.SyncInfoKeyProgressMax] as? Int {
                    self.progressHUDSyncInfo?.labelTitle.text = DPAGLocalizedString("updateKnownContacts.syncInfo." + syncInfoState.rawValue) + "\n \(step)/\(stepMax)"
                } else {
                    self.progressHUDSyncInfo?.labelTitle.text = DPAGLocalizedString("updateKnownContacts.syncInfo." + syncInfoState.rawValue) + "\n \(step)"
                }
            } else {
                self.progressHUDSyncInfo?.labelTitle.text = DPAGLocalizedString("updateKnownContacts.syncInfo." + syncInfoState.rawValue)
            }
        }
    }
}

public struct DPAGApplicationFacadeUIContacts {
    private init() {}

    static func viewContactsDomainEmptyNib() -> UINib { UINib(nibName: "DPAGContactsDomainEmpty", bundle: Bundle(for: DPAGContactsDomainEmpty.self)) }
    static func viewContactsDomainEmpty() -> (UIView & DPAGContactsDomainEmptyViewProtocol)? { UINib(nibName: "DPAGContactsDomainEmpty", bundle: Bundle(for: DPAGContactsDomainEmpty.self)).instantiate(withOwner: nil, options: nil).first as? (UIView & DPAGContactsDomainEmptyViewProtocol) }
    static func viewContactsSearchEmptyNib() -> UINib { UINib(nibName: "DPAGContactsSearchEmptyView", bundle: Bundle(for: DPAGContactsSearchEmptyView.self)) }
    static func viewContactsListHeader() -> (UIView & DPAGContactsListHeaderViewProtocol)? { UINib(nibName: "DPAGContactsListHeaderView", bundle: Bundle(for: DPAGContactsListHeaderView.self)).instantiate(withOwner: nil, options: nil).first as? (UIView & DPAGContactsListHeaderViewProtocol) }
    static func cellGroupNib() -> UINib { UINib(nibName: "DPAGGroupCell", bundle: Bundle(for: DPAGGroupCell.self)) }
    static func cellChatNib() -> UINib { UINib(nibName: "DPAGChatCell", bundle: Bundle(for: DPAGChatCell.self)) }
    static func cellPersonNib() -> UINib { UINib(nibName: "DPAGPersonCell", bundle: Bundle(for: DPAGPersonCell.self)) }
    public static func personToSendSelectVC(delegateSending: DPAGPersonSendingDelegate?) -> (UIViewController) { DPAGChoosePersonToSendViewController(delegateSending: delegateSending) }
    public static func contactDetailsVC(contact: DPAGContact, contactEdit: DPAGContactEdit? = nil) -> UIViewController & DPAGContactDetailsViewControllerProtocol { DPAGContactDetailsViewController(contact: contact, contactEdit: contactEdit) }
    public static func contactNewCreateVC(contact: DPAGContact, contactEdit: DPAGContactEdit? = nil) -> UIViewController & DPAGContactNewCreateViewControllerProtocol { DPAGContactNewCreateViewController(contact: contact, contactEdit: contactEdit) }
    public static func contactNewSearchVC() -> (UIViewController & DPAGContactNewSearchViewControllerProtocol) { DPAGContactNewSearchViewController() }
    static func contactNewSelectVC(contactGuids: [String]) -> UIViewController & DPAGContactNewSelectViewControllerProtocol { DPAGContactNewSelectViewController(contactGuids: contactGuids) }
    static func contactNotFoundVC(searchData: String, searchMode: DPAGContactSearchMode) -> (UIViewController & DPAGContactNotFoundViewControllerProtocol) { DPAGContactNotFoundViewController(searchData: searchData, searchMode: searchMode) }
    public static func contactSelectionGroupAdminsVC(members: Set<DPAGContact>, admins: Set<DPAGContact>, adminsFixed: Set<DPAGContact>, delegate selectionDelegate: DPAGContactsSelectionGroupAdminsDelegate) -> (UIViewController) { DPAGContactsSelectionGroupAdminsViewController(members: members, admins: admins, adminsFixed: adminsFixed, delegate: selectionDelegate) }
    public static func contactsVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) { DPAGContactsViewController(contactsSelected: contactsSelected) }
    public static func contactsPageVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) { DPAGContactsPageViewController(contactsSelected: contactsSelected) }
    public static func contactsCompanyVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) { DPAGContactsCompanyViewController(contactsSelected: contactsSelected) }
    public static func contactsDomainVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) { DPAGContactsDomainViewController(contactsSelected: contactsSelected) }
    public static func contactsCompanyPageVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) { DPAGContactsCompanyPageViewController(contactsSelected: contactsSelected) }
    public static func contactsDomainPageVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) { DPAGContactsDomainPageViewController(contactsSelected: contactsSelected) }
    public static func contactsCompanyPagesVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsPagesViewControllerProtocol) { DPAGContactsCompanyPagesViewController(contactsSelected: contactsSelected) }
    public static func contactsDomainPagesVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsPagesViewControllerProtocol) { DPAGContactsDomainPagesViewController(contactsSelected: contactsSelected) }
    public static func contactsCompanyDomainPagesVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsPagesViewControllerProtocol) { DPAGContactsCompanyDomainPagesViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionDistributionListMembersVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionDistributionListMembersViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionDistributionListMembersPageVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionDistributionListMembersViewControllerProtocol) { DPAGContactsSelectionDistributionListMembersPageViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionDistributionListMembersCompanyVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionDistributionListMembersViewControllerProtocol) { DPAGContactsSelectionDistributionListMembersCompanyViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionDistributionListMembersDomainVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionDistributionListMembersViewControllerProtocol) { DPAGContactsSelectionDistributionListMembersDomainViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionDistributionListMembersCompanyPageVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionDistributionListMembersViewControllerProtocol) { DPAGContactsSelectionDistributionListMembersCompanyPageViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionDistributionListMembersDomainPageVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionDistributionListMembersViewControllerProtocol) { DPAGContactsSelectionDistributionListMembersDomainPageViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionDistributionListMembersCompanyPagesVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionDistributionListMembersCompanyPagesViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionDistributionListMembersDomainPagesVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionDistributionListMembersDomainPagesViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionDistributionListMembersCompanyDomainPagesVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionDistributionListMembersCompanyDomainPagesViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionGroupMembersRemoveVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionGroupMembersRemoveViewControllerProtocol) { DPAGContactsSelectionGroupMembersRemoveViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionGroupMembersAddVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionGroupMembersAddViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionGroupMembersAddPageVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionGroupMembersAddViewControllerProtocol) { DPAGContactsSelectionGroupMembersAddPageViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionGroupMembersAddCompanyVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionGroupMembersAddViewControllerProtocol) { DPAGContactsSelectionGroupMembersAddCompanyViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionGroupMembersAddDomainVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionGroupMembersAddViewControllerProtocol) { DPAGContactsSelectionGroupMembersAddDomainViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionGroupMembersAddCompanyPageVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionGroupMembersAddViewControllerProtocol) { DPAGContactsSelectionGroupMembersAddCompanyPageViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionGroupMembersAddDomainPageVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionGroupMembersAddViewControllerProtocol) { DPAGContactsSelectionGroupMembersAddDomainPageViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionGroupMembersAddCompanyPagesVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionGroupMembersAddCompanyPagesViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionGroupMembersAddDomainPagesVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionGroupMembersAddDomainPagesViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionGroupMembersAddCompanyDomainPagesVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionGroupMembersAddCompanyDomainPagesViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionNewChatVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionNewChatViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionNewChatPageVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionNewChatBaseViewControllerProtocol) { DPAGContactsSelectionNewChatPageViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionNewChatCompanyVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionNewChatBaseViewControllerProtocol) { DPAGContactsSelectionNewChatCompanyViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionNewChatDomainVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionNewChatBaseViewControllerProtocol) { DPAGContactsSelectionNewChatDomainViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionNewChatCompanyPageVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionNewChatBaseViewControllerProtocol) { DPAGContactsSelectionNewChatCompanyPageViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionNewChatDomainPageVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionNewChatBaseViewControllerProtocol) { DPAGContactsSelectionNewChatDomainPageViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionNewChatCompanyPagesVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionNewChatCompanyPagesViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionNewChatDomainPagesVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionNewChatDomainPagesViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionNewChatCompanyDomainPagesVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionNewChatCompanyDomainPagesViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionReceiverVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionReceiverViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionReceiverPageVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionReceiverViewControllerProtocol) { DPAGContactsSelectionReceiverPageViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionReceiverCompanyVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionReceiverViewControllerProtocol) { DPAGContactsSelectionReceiverCompanyViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionReceiverDomainVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionReceiverViewControllerProtocol) { DPAGContactsSelectionReceiverDomainViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionReceiverCompanyPageVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionReceiverViewControllerProtocol) { DPAGContactsSelectionReceiverCompanyPageViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionReceiverDomainPageVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionReceiverViewControllerProtocol) { DPAGContactsSelectionReceiverDomainPageViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionReceiverCompanyPagesVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionReceiverCompanyPagesViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionReceiverDomainPagesVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionReceiverDomainPagesViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionReceiverCompanyDomainPagesVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionReceiverCompanyDomainPagesViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionSendingVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionSendingViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionSendingPageVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionSendingBaseViewControllerProtocol) { DPAGContactsSelectionSendingPageViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionSendingCompanyVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionSendingBaseViewControllerProtocol) { DPAGContactsSelectionSendingCompanyViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionSendingDomainVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionSendingBaseViewControllerProtocol) { DPAGContactsSelectionSendingDomainViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionSendingCompanyPageVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionSendingBaseViewControllerProtocol) { DPAGContactsSelectionSendingCompanyPageViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionSendingDomainPageVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController & DPAGContactsSelectionSendingBaseViewControllerProtocol) { DPAGContactsSelectionSendingDomainPageViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionSendingCompanyPagesVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionSendingCompanyPagesViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionSendingDomainPagesVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionSendingDomainPagesViewController(contactsSelected: contactsSelected) }
    public static func contactsSelectionSendingCompanyDomainPagesVC(contactsSelected: DPAGSearchListSelection<DPAGContact>) -> (UIViewController) { DPAGContactsSelectionSendingCompanyDomainPagesViewController(contactsSelected: contactsSelected) }
    public static func activeChatsVC() -> (UIViewController & DPAGActiveChatsListViewControllerProtocol) { DPAGActiveChatsListViewController() }
    public static func newFileChatVC(delegate: DPAGNewChatDelegate?, fileURL: URL) -> (UIViewController & DPAGNewFileChatViewControllerProtocol) { DPAGNewFileChatViewController(delegate: delegate, fileURL: fileURL) }
    public static func setSilentVC(setSilentHelper: SetSilentHelper?) -> (UIViewController) { DPAGSetSilentViewController(setSilentHelper: setSilentHelper) }
    static func personSearchResultsVC(delegate: DPAGPersonsSearchViewControllerDelegate) -> UIViewController & DPAGPersonsSearchResultsViewControllerProtocol { DPAGPersonsSearchResultsViewController(delegate: delegate) }
    static func contactsPagesSearchResultsVC(delegate: DPAGContactsSearchViewControllerDelegate, emptyViewDelegate: DPAGContactsSearchEmptyViewDelegate?) -> UIViewController & DPAGContactsSearchResultsViewControllerProtocol { DPAGContactsPagesSearchResultsViewController(delegate: delegate, emptyViewDelegate: emptyViewDelegate) }
    static func contactsSearchResultsVC(delegate: DPAGContactsSearchViewControllerDelegate, emptyViewDelegate: DPAGContactsSearchEmptyViewDelegate?) -> UIViewController & DPAGContactsSearchResultsViewControllerProtocol { DPAGContactsSearchResultsViewController(delegate: delegate, emptyViewDelegate: emptyViewDelegate) }
    public static func scanProfileVC(contactGuid: String, blockSuccess successBlock: @escaping DPAGCompletion, blockFailed failedBlock: @escaping DPAGCompletion, blockCancelled cancelBlock: @escaping DPAGCompletion) -> (UIViewController) { DPAGScanProfileViewController(contactGuid: contactGuid, blockSuccess: successBlock, blockFailed: failedBlock, blockCancelled: cancelBlock) }
}
