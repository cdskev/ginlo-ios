//
//  DPAGContactsSelectionSendingViewController.swift
// ginlo
//
//  Created by RBU on 31.01.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGContactsSelectionSendingBaseViewController: DPAGContactsSelectionViewController, DPAGContactsSelectionSendingDelegateConsumer, DPAGContactsSelectionSendingBaseViewControllerProtocol, DPAGViewControllerOrientationFlexibleIfPresented {
    weak var delegate: DPAGContactSendingDelegate?

    typealias T = DPAGContact

    init(contactsSelected: DPAGSearchListSelection<DPAGContact>) {
        super.init(contactsSelected: contactsSelected, showInviteAction: false)

        self.options = [.EnableGroupedStyle]
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = DPAGLocalizedString("contacts.selection.sending.title")
        self.tableView.accessibilityLabel = DPAGLocalizedString("contacts.selection.sending.title")
    }

    override func configureSearchBar() {
        if AppConfig.isShareExtension == false { self.configureSearchBarWithResultsController(DPAGApplicationFacadeUIContacts.contactsSearchResultsVC(delegate: self, emptyViewDelegate: self), placeholder: "android.serach.placeholder")
        }
    }

    override func didSelect(objects: Set<DPAGContact>) {
        let blockSelect = {
            guard let contact = objects.first else {
                return
            }

            self.delegate?.send(contact: contact, asLocalVCard: false)
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

extension DPAGContactsSelectionSendingBaseViewController: DPAGContactsSearchViewControllerDelegate {
    func didSelectContact(contact: DPAGContact) {
        self.didSelect(objects: Set([contact]))
    }
}

class DPAGContactsSelectionSendingViewController: DPAGContactsSelectionSendingBaseViewController {
    override func configureNavigationBar() {
        super.configureNavigationBar()

        if self.presentingViewController != nil {
            self.setLeftBackBarButtonItem(action: #selector(cancel))
        }
    }

    @objc
    private func cancel() {
        self.dismiss(animated: true, completion: nil)
    }
}

class DPAGContactsSelectionSendingPageViewController: DPAGContactsSelectionSendingBaseViewController {}

class DPAGContactsSelectionSendingCompanyViewController: DPAGContactsSelectionSendingBaseViewController {
    override var selectionType: DPAGContactsSelectionType {
        .company
    }

    override func configureNavigationBar() {
        super.configureNavigationBar()

        if self.presentingViewController != nil {
            self.setLeftBackBarButtonItem(action: #selector(cancel))
        }
    }

    @objc
    private func cancel() {
        self.dismiss(animated: true, completion: nil)
    }
}

class DPAGContactsSelectionSendingDomainViewController: DPAGContactsSelectionSendingBaseViewController, DPAGContactsDomainEmptyViewControllerProtocol {
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

    override func configureNavigationBar() {
        super.configureNavigationBar()

        if self.presentingViewController != nil {
            self.setLeftBackBarButtonItem(action: #selector(cancel))
        }
    }

    @objc
    private func cancel() {
        self.dismiss(animated: true, completion: nil)
    }
}

class DPAGContactsSelectionSendingCompanyPageViewController: DPAGContactsSelectionSendingCompanyViewController {}

class DPAGContactsSelectionSendingDomainPageViewController: DPAGContactsSelectionSendingDomainViewController {}

class DPAGContactsSelectionSendingCompanyPagesViewController: DPAGContactsPagesBaseViewController, DPAGContactsPagesViewControllerProtocol, DPAGContactsSelectionSendingDelegateConsumer, DPAGViewControllerOrientationFlexibleIfPresented {
    weak var delegate: DPAGContactSendingDelegate?

    func createPage0() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionSendingPageVC(contactsSelected: self.contactsSelected)

        retVal.delegate = self.delegate

        return retVal
    }

    func createPage2() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionSendingCompanyPageVC(contactsSelected: self.contactsSelected)

        retVal.delegate = self.delegate

        return retVal
    }

    override func configureNavigationBar() {
        if self.presentingViewController != nil {
            self.setLeftBackBarButtonItem(action: #selector(cancel))
        }
    }

    @objc
    private func cancel() {
        self.dismiss(animated: true, completion: nil)
    }
}

class DPAGContactsSelectionSendingDomainPagesViewController: DPAGContactsPagesBaseViewController, DPAGContactsPagesViewControllerProtocol, DPAGContactsSelectionSendingDelegateConsumer, DPAGViewControllerOrientationFlexibleIfPresented {
    weak var delegate: DPAGContactSendingDelegate?

    func createPage0() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionSendingPageVC(contactsSelected: self.contactsSelected)

        retVal.delegate = self.delegate

        return retVal
    }

    func createPage1() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionSendingDomainPageVC(contactsSelected: self.contactsSelected)

        retVal.delegate = self.delegate

        return retVal
    }

    override func configureNavigationBar() {
        if self.presentingViewController != nil {
            self.setLeftBackBarButtonItem(action: #selector(cancel))
        }
    }

    @objc
    private func cancel() {
        self.dismiss(animated: true, completion: nil)
    }
}

class DPAGContactsSelectionSendingCompanyDomainPagesViewController: DPAGContactsPagesBaseViewController, DPAGContactsPagesViewControllerProtocol, DPAGContactsSelectionSendingDelegateConsumer, DPAGViewControllerOrientationFlexibleIfPresented {
    weak var delegate: DPAGContactSendingDelegate?

    func createPage0() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionSendingPageVC(contactsSelected: self.contactsSelected)

        retVal.delegate = self.delegate

        return retVal
    }

    func createPage2() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionSendingCompanyPageVC(contactsSelected: self.contactsSelected)

        retVal.delegate = self.delegate

        return retVal
    }

    func createPage1() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionSendingDomainPageVC(contactsSelected: self.contactsSelected)

        retVal.delegate = self.delegate

        return retVal
    }

    override func configureNavigationBar() {
        if self.presentingViewController != nil {
            self.setLeftBackBarButtonItem(action: #selector(cancel))
        }
    }

    @objc
    private func cancel() {
        self.dismiss(animated: true, completion: nil)
    }
}
