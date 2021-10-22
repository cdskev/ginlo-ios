//
//  DPAGChatReceiverSelectionViewController.swift
// ginlo
//
//  Created by RBU on 05/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGContactsSelectionDistributionListMembersViewController: DPAGContactsSelectionViewController, DPAGContactsSelectionDistributionListMembersDelegateConsumer, DPAGContactsSelectionDistributionListMembersViewControllerProtocol {
    weak var delegate: DPAGContactsSelectionDistributionListMembersViewControllerDelegate?

    init(contactsSelected: DPAGSearchListSelection<DPAGContact>) {
        super.init(contactsSelected: contactsSelected, showInviteAction: true)

        self.options = [.EnableMultiSelection, .EnableGroupedStyle]

        switch self.selectionType {
        case .privat:
            NotificationCenter.default.addObserver(self, selector: #selector(lruChanged), name: DPAGStrings.Notification.Contact.LRU_ADDED_PRIVATE, object: nil)
        case .company:
            NotificationCenter.default.addObserver(self, selector: #selector(lruChanged), name: DPAGStrings.Notification.Contact.LRU_ADDED_COMPANY, object: nil)
        case .domain:
            NotificationCenter.default.addObserver(self, selector: #selector(lruChanged), name: DPAGStrings.Notification.Contact.LRU_ADDED_DOMAIN, object: nil)
        }

        self.title = DPAGLocalizedString("chat.distributionList_selection.title")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func configureSearchBar() {
        self.configureSearchBarWithResultsController(DPAGApplicationFacadeUIContacts.contactsSearchResultsVC(delegate: self, emptyViewDelegate: self), placeholder: "android.serach.placeholder")
    }

    override func didSelect(objects: Set<DPAGContact>) {
        self.delegate?.didSelect(contacts: objects)
    }

    override func updateTitle() {}

    @objc
    private func lruChanged() {
        if self.showsLRUContacts {
            self.createModel()
        }
    }
}

extension DPAGContactsSelectionDistributionListMembersViewController: DPAGContactsSearchViewControllerDelegate {
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

class DPAGContactsSelectionDistributionListMembersPageViewController: DPAGContactsSelectionDistributionListMembersViewController {
    weak var selectionMultiDelegate: DPAGContactsSelectionPagesViewControllerDelegate?

    override func didSelectMulti(object: DPAGContact) {
        self.selectionMultiDelegate?.didSelectMultiPerson(object)
    }

    override func didUnselectMulti(object: DPAGContact) {
        self.selectionMultiDelegate?.didSelectMultiPerson(object)
    }
}

class DPAGContactsSelectionDistributionListMembersCompanyViewController: DPAGContactsSelectionDistributionListMembersViewController {
    override var selectionType: DPAGContactsSelectionType {
        .company
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = DPAGLocalizedString("chat.distributionList_selection.title")
    }
}

class DPAGContactsSelectionDistributionListMembersDomainViewController: DPAGContactsSelectionDistributionListMembersViewController, DPAGContactsDomainEmptyViewControllerProtocol {
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

        self.title = DPAGLocalizedString("chat.distributionList_selection.title")

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

class DPAGContactsSelectionDistributionListMembersCompanyPageViewController: DPAGContactsSelectionDistributionListMembersCompanyViewController {
    weak var selectionMultiDelegate: DPAGContactsSelectionPagesViewControllerDelegate?

    override func didSelectMulti(object: DPAGContact) {
        self.selectionMultiDelegate?.didSelectMultiPerson(object)
    }

    override func didUnselectMulti(object: DPAGContact) {
        self.selectionMultiDelegate?.didSelectMultiPerson(object)
    }
}

class DPAGContactsSelectionDistributionListMembersDomainPageViewController: DPAGContactsSelectionDistributionListMembersDomainViewController {
    weak var selectionMultiDelegate: DPAGContactsSelectionPagesViewControllerDelegate?

    override func didSelectMulti(object: DPAGContact) {
        self.selectionMultiDelegate?.didSelectMultiPerson(object)
    }

    override func didUnselectMulti(object: DPAGContact) {
        self.selectionMultiDelegate?.didSelectMultiPerson(object)
    }
}

class DPAGContactsSelectionDistributionListMembersCompanyPagesViewController: DPAGContactsPagesBaseViewController, DPAGContactsPagesViewControllerProtocol, DPAGContactsSelectionDistributionListMembersDelegateConsumer {
    weak var delegate: DPAGContactsSelectionDistributionListMembersViewControllerDelegate?

    func createPage0() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) {
        DPAGApplicationFacadeUIContacts.contactsSelectionDistributionListMembersPageVC(contactsSelected: self.contactsSelected)
    }

    func createPage2() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        DPAGApplicationFacadeUIContacts.contactsSelectionDistributionListMembersCompanyPageVC(contactsSelected: self.contactsSelected)
    }

    override func configureNavigationBar() {
        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavCheck], action: #selector(handleSelectionDone), accessibilityLabelIdentifier: "navigation.done")
    }

    @objc
    func handleSelectionDone() {
        self.delegate?.didSelect(contacts: self.contactsSelected.objectsSelected)
    }
}

class DPAGContactsSelectionDistributionListMembersDomainPagesViewController: DPAGContactsPagesBaseViewController, DPAGContactsPagesViewControllerProtocol, DPAGContactsSelectionDistributionListMembersDelegateConsumer {
    weak var delegate: DPAGContactsSelectionDistributionListMembersViewControllerDelegate?

    func createPage0() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) {
        DPAGApplicationFacadeUIContacts.contactsSelectionDistributionListMembersPageVC(contactsSelected: self.contactsSelected)
    }

    func createPage1() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        DPAGApplicationFacadeUIContacts.contactsSelectionDistributionListMembersDomainPageVC(contactsSelected: self.contactsSelected)
    }

    override func configureNavigationBar() {
        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavCheck], action: #selector(handleSelectionDone), accessibilityLabelIdentifier: "navigation.done")
    }

    @objc
    func handleSelectionDone() {
        self.delegate?.didSelect(contacts: self.contactsSelected.objectsSelected)
    }
}

class DPAGContactsSelectionDistributionListMembersCompanyDomainPagesViewController: DPAGContactsPagesBaseViewController, DPAGContactsPagesViewControllerProtocol, DPAGContactsSelectionDistributionListMembersDelegateConsumer {
    var selectedContacts: Set<DPAGContact>?

    weak var delegate: DPAGContactsSelectionDistributionListMembersViewControllerDelegate?

    func createPage0() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) {
        DPAGApplicationFacadeUIContacts.contactsSelectionDistributionListMembersPageVC(contactsSelected: self.contactsSelected)
    }

    func createPage2() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        DPAGApplicationFacadeUIContacts.contactsSelectionDistributionListMembersCompanyPageVC(contactsSelected: self.contactsSelected)
    }

    func createPage1() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        DPAGApplicationFacadeUIContacts.contactsSelectionDistributionListMembersDomainPageVC(contactsSelected: self.contactsSelected)
    }

    override func configureNavigationBar() {
        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavCheck], action: #selector(handleSelectionDone), accessibilityLabelIdentifier: "navigation.done")
    }

    @objc
    func handleSelectionDone() {
        self.delegate?.didSelect(contacts: self.contactsSelected.objectsSelected)
    }
}
