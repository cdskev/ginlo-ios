//
//  DPAGSelectGroupChatMembersViewController.swift
// ginlo
//
//  Created by RBU on 29/01/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGContactsSelectionGroupMembersAddViewController: DPAGContactsSelectionViewController, DPAGContactsSelectionGroupMembersDelegateConsumer, DPAGContactsSelectionGroupMembersAddViewControllerProtocol {
    weak var memberSelectionDelegate: DPAGContactsSelectionGroupMembersDelegate?

    init(contactsSelected: DPAGSearchListSelection<DPAGContact>) {
        super.init(contactsSelected: contactsSelected, showInviteAction: false)
        self.options = [.EnableEmptySelection, .EnableMultiSelection, .EnableGroupedStyle]
        switch self.selectionType {
            case .privat:
                NotificationCenter.default.addObserver(self, selector: #selector(lruChanged), name: DPAGStrings.Notification.Contact.LRU_ADDED_PRIVATE, object: nil)
            case .company:
                NotificationCenter.default.addObserver(self, selector: #selector(lruChanged), name: DPAGStrings.Notification.Contact.LRU_ADDED_COMPANY, object: nil)
            case .domain:
                NotificationCenter.default.addObserver(self, selector: #selector(lruChanged), name: DPAGStrings.Notification.Contact.LRU_ADDED_DOMAIN, object: nil)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = DPAGLocalizedString("contacts.overViewViewControllerTitle")
    }

    override func configureSearchBar() {
        self.configureSearchBarWithResultsController(DPAGApplicationFacadeUIContacts.contactsSearchResultsVC(delegate: self, emptyViewDelegate: self), placeholder: "android.serach.placeholder")
    }

    override func didSelect(objects: Set<DPAGContact>) {
        self.memberSelectionDelegate?.addMembers(objects)
    }

    @objc
    private func lruChanged() {
        if self.showsLRUContacts {
            self.createModel()
        }
    }
}

extension DPAGContactsSelectionGroupMembersAddViewController: DPAGContactsSearchViewControllerDelegate {
    func didSelectContact(contact: DPAGContact) {
        if let searchController = self.searchController, searchController.isActive {
            searchController.dismiss(animated: true) { [weak self] in
                self?.tableViewDidSelect(object: contact, at: nil)
            }
        } else {
            self.tableViewDidSelect(object: contact, at: nil)
        }
    }
}

class DPAGContactsSelectionGroupMembersAddPageViewController: DPAGContactsSelectionGroupMembersAddViewController {
    weak var selectionMultiDelegate: DPAGContactsSelectionPagesViewControllerDelegate?

    override func didSelectMulti(object: DPAGContact) {
        self.selectionMultiDelegate?.didSelectMultiPerson(object)
    }

    override func didUnselectMulti(object: DPAGContact) {
        self.selectionMultiDelegate?.didSelectMultiPerson(object)
    }
}

class DPAGContactsSelectionGroupMembersAddCompanyViewController: DPAGContactsSelectionGroupMembersAddViewController {
    override var selectionType: DPAGContactsSelectionType {
        .company
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = DPAGLocalizedString("contacts.overViewViewControllerTitle")
    }
}

class DPAGContactsSelectionGroupMembersAddDomainViewController: DPAGContactsSelectionGroupMembersAddViewController, DPAGContactsDomainEmptyViewControllerProtocol {
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

        self.title = DPAGLocalizedString("contacts.overViewViewControllerTitle")

        self.configureEmptyDomainGui()

        if let emptyView = self.tableViewEmpty as? DPAGContactsDomainEmptyViewProtocol {
            emptyView.btnStartEMail.addTarget(self, action: #selector(self.handleAuthenticateMailButtonTapped(_:)),
                                              for: .touchUpInside)
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

class DPAGContactsSelectionGroupMembersAddCompanyPageViewController: DPAGContactsSelectionGroupMembersAddCompanyViewController {
    weak var selectionMultiDelegate: DPAGContactsSelectionPagesViewControllerDelegate?

    override func didSelectMulti(object: DPAGContact) {
        self.selectionMultiDelegate?.didSelectMultiPerson(object)
    }

    override func didUnselectMulti(object: DPAGContact) {
        self.selectionMultiDelegate?.didSelectMultiPerson(object)
    }
}

class DPAGContactsSelectionGroupMembersAddDomainPageViewController: DPAGContactsSelectionGroupMembersAddDomainViewController {
    weak var selectionMultiDelegate: DPAGContactsSelectionPagesViewControllerDelegate?

    override func didSelectMulti(object: DPAGContact) {
        self.selectionMultiDelegate?.didSelectMultiPerson(object)
    }

    override func didUnselectMulti(object: DPAGContact) {
        self.selectionMultiDelegate?.didSelectMultiPerson(object)
    }
}

class DPAGContactsSelectionGroupMembersAddCompanyPagesViewController: DPAGContactsPagesBaseViewController, DPAGContactsPagesViewControllerProtocol, DPAGContactsSelectionGroupMembersDelegateConsumer {
    weak var memberSelectionDelegate: DPAGContactsSelectionGroupMembersDelegate?

    func createPage0() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionGroupMembersAddPageVC(contactsSelected: self.contactsSelected)

        return retVal
    }

    func createPage2() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionGroupMembersAddCompanyPageVC(contactsSelected: self.contactsSelected)

        return retVal
    }

    override func configureNavigationBar() {
        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavCheck], action: #selector(handleSelectionDone), accessibilityLabelIdentifier: "navigation.done")
    }

    @objc
    func handleSelectionDone() {
        self.memberSelectionDelegate?.addMembers(self.contactsSelected.objectsSelected)
    }
}

class DPAGContactsSelectionGroupMembersAddDomainPagesViewController: DPAGContactsPagesBaseViewController, DPAGContactsPagesViewControllerProtocol, DPAGContactsSelectionGroupMembersDelegateConsumer {
    weak var memberSelectionDelegate: DPAGContactsSelectionGroupMembersDelegate?

    func createPage0() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionGroupMembersAddPageVC(contactsSelected: self.contactsSelected)

        return retVal
    }

    func createPage1() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionGroupMembersAddDomainPageVC(contactsSelected: self.contactsSelected)

        return retVal
    }

    override func configureNavigationBar() {
        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavCheck], action: #selector(handleSelectionDone), accessibilityLabelIdentifier: "navigation.done")
    }

    @objc
    func handleSelectionDone() {
        self.memberSelectionDelegate?.addMembers(self.contactsSelected.objectsSelected)
    }
}

class DPAGContactsSelectionGroupMembersAddCompanyDomainPagesViewController: DPAGContactsPagesBaseViewController, DPAGContactsPagesViewControllerProtocol, DPAGContactsSelectionGroupMembersDelegateConsumer {
    weak var memberSelectionDelegate: DPAGContactsSelectionGroupMembersDelegate?

    func createPage0() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionGroupMembersAddPageVC(contactsSelected: self.contactsSelected)

        return retVal
    }

    func createPage2() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionGroupMembersAddCompanyPageVC(contactsSelected: self.contactsSelected)

        return retVal
    }

    func createPage1() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        let retVal = DPAGApplicationFacadeUIContacts.contactsSelectionGroupMembersAddDomainPageVC(contactsSelected: self.contactsSelected)

        return retVal
    }

    override func configureNavigationBar() {
        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavCheck], action: #selector(handleSelectionDone), accessibilityLabelIdentifier: "navigation.done")
    }

    @objc
    func handleSelectionDone() {
        self.memberSelectionDelegate?.addMembers(self.contactsSelected.objectsSelected)
    }
}

class DPAGContactsSelectionGroupMembersRemoveViewController: DPAGContactsSelectionViewController, DPAGContactsSelectionGroupMembersDelegateConsumer, DPAGContactsSelectionGroupMembersRemoveViewControllerProtocol {
    weak var memberSelectionDelegate: DPAGContactsSelectionGroupMembersDelegate?

    init(contactsSelected: DPAGSearchListSelection<DPAGContact>) {
        super.init(contactsSelected: contactsSelected, showInviteAction: false)

        self.options = [.EnableMultiSelection, .InvertedSelection, .EnableEmptySelection]
    }

    override func configureSearchBar() {}

    override func didSelect(objects: Set<DPAGContact>) {
        self.memberSelectionDelegate?.addMembers(objects)
    }

    override func createModel() {
        let personArray = self.contactsSelected.objectsSelected

        self.model = DPAGSearchListModel(objects: personArray)
    }

    override func updateTableHeader() {}
}
