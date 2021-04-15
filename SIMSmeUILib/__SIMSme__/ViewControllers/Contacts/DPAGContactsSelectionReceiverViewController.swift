//
//  DPAGContactsSelectionReceiverViewController.swift
//  SIMSme
//
//  Created by RBU on 25.01.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGContactsSelectionReceiverViewController: DPAGContactsSelectionViewController, DPAGContactsSelectionReceiverDelegateConsumer, DPAGContactsSelectionReceiverViewControllerProtocol {
    typealias T = DPAGContact

    weak var delegate: DPAGReceiverDelegate?

    init(contactsSelected: DPAGSearchListSelection<DPAGContact>) {
        super.init(contactsSelected: contactsSelected, showInviteAction: true)

        self.options = [.EnableGroupedStyle]
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = DPAGLocalizedString("chats.title.newChat")
        self.tableView.accessibilityLabel = DPAGLocalizedString("chats.title.newChat")
    }

    override func configureSearchBar() {
        if AppConfig.isShareExtension { self.configureSearchBarWithResultsController(DPAGApplicationFacadeUIContacts.contactsSearchResultsVC(delegate: self, emptyViewDelegate: nil), placeholder: "android.serach.placeholder")
        } else {
            self.configureSearchBarWithResultsController(DPAGApplicationFacadeUIContacts.contactsSearchResultsVC(delegate: self, emptyViewDelegate: self), placeholder: "android.serach.placeholder")
        }
    }

    override func didSelect(objects: Set<DPAGContact>) {
        let blockSelect = { [weak self] in
            guard let contact = objects.first else { return }

            if self?.delegate != nil {
                if AppConfig.isShareExtension {
                    self?.delegate?.didSelectReceiver(contact)
                } else {
                    DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
                        if contact.entryTypeLocal == .hidden {
                            DPAGApplicationFacade.contactsWorker.privatizeContact(contact)
                        }
                        let block = { [weak self] in
                            if let streamGuid = contact.streamGuid, DPAGApplicationFacade.cache.decryptedStream(streamGuid: streamGuid, in: nil) != nil {
                                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                                    self?.delegate?.didSelectReceiver(contact)
                                }
                            } else {
                                DPAGProgressHUD.sharedInstance.hide(true)
                            }
                        }
                        if contact.publicKey == nil {
                            DPAGApplicationFacade.updateKnownContactsWorker.synchronize(accountGuid: contact.guid) { _, _, errorMessage in
                                if let errorMessage = errorMessage {
                                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                                    }
                                } else {
                                    block()
                                }
                            }
                        } else {
                            block()
                        }
                    }
                }
            }
        }

        if let searchController = self.searchController, searchController.isActive {
            searchController.dismiss(animated: true) {
                blockSelect()
            }
        } else {
            blockSelect()
        }
    }
}

extension DPAGContactsSelectionReceiverViewController: DPAGContactsSearchViewControllerDelegate {
    func didSelectContact(contact: DPAGContact) {
        self.didSelect(objects: Set([contact]))
    }
}

class DPAGContactsSelectionReceiverPageViewController: DPAGContactsSelectionReceiverViewController {}

class DPAGContactsSelectionReceiverCompanyViewController: DPAGContactsSelectionReceiverViewController {
    override var selectionType: DPAGContactsSelectionType {
        .company
    }
}

class DPAGContactsSelectionReceiverDomainViewController: DPAGContactsSelectionReceiverViewController, DPAGContactsDomainEmptyViewControllerProtocol {
    override var selectionType: DPAGContactsSelectionType {
        .domain
    }

    private var _tableViewEmpty: UIView?

    override var tableViewEmpty: UIView? {
        get {
            if _tableViewEmpty == nil {
                _tableViewEmpty = DPAGApplicationFacadeUIContacts.viewContactsDomainEmpty()
            }
            return _tableViewEmpty
        }
        set {
            super.tableViewEmpty = newValue
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.configureEmptyDomainGui()

        if AppConfig.isShareExtension == false {
            if let emptyView = self.tableViewEmpty as? DPAGContactsDomainEmptyViewProtocol {
                emptyView.btnStartEMail.addTarget(self, action: #selector(self.handleAuthenticateMailButtonTapped(_:)),
                                                  for: .touchUpInside)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.updateEmptyDomainGui()
    }

    @objc
    func handleAuthenticateMailButtonTapped(_: Any?) {
        if let nextVC = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitEMailController) {
            self.navigationController?.pushViewController(nextVC, animated: true)
        }
    }
}

class DPAGContactsSelectionReceiverCompanyPageViewController: DPAGContactsSelectionReceiverCompanyViewController {}

class DPAGContactsSelectionReceiverDomainPageViewController: DPAGContactsSelectionReceiverDomainViewController {}

class DPAGContactsSelectionReceiverCompanyPagesViewController: DPAGContactsPagesBaseViewController, DPAGContactsPagesViewControllerProtocol, DPAGContactsSelectionReceiverDelegateConsumer {
    weak var delegate: DPAGReceiverDelegate?

    func createPage0() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionReceiverPageVC(contactsSelected: self.contactsSelected)

        retVal.delegate = self.delegate

        return retVal
    }

    func createPage2() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionReceiverCompanyPageVC(contactsSelected: self.contactsSelected)

        retVal.delegate = self.delegate

        return retVal
    }
}

class DPAGContactsSelectionReceiverDomainPagesViewController: DPAGContactsPagesBaseViewController, DPAGContactsPagesViewControllerProtocol, DPAGContactsSelectionReceiverDelegateConsumer {
    weak var delegate: DPAGReceiverDelegate?

    func createPage0() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionReceiverPageVC(contactsSelected: self.contactsSelected)

        retVal.delegate = self.delegate

        return retVal
    }

    func createPage1() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionReceiverDomainPageVC(contactsSelected: self.contactsSelected)

        retVal.delegate = self.delegate

        return retVal
    }
}

class DPAGContactsSelectionReceiverCompanyDomainPagesViewController: DPAGContactsPagesBaseViewController, DPAGContactsPagesViewControllerProtocol, DPAGContactsSelectionReceiverDelegateConsumer {
    weak var delegate: DPAGReceiverDelegate?

    func createPage0() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionReceiverPageVC(contactsSelected: self.contactsSelected)

        retVal.delegate = self.delegate

        return retVal
    }

    func createPage2() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionReceiverCompanyPageVC(contactsSelected: self.contactsSelected)

        retVal.delegate = self.delegate

        return retVal
    }

    func createPage1() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionReceiverDomainPageVC(contactsSelected: self.contactsSelected)

        retVal.delegate = self.delegate

        return retVal
    }
}
