//
//  DPAGContactsOverviewViewController.swift
// ginlo
//
//  Created by RBU on 28/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Contacts
import SIMSmeCore
import UIKit

extension DPAGContactsBaseViewController: DPAGContactsOptionsProtocol, DPAGContactsOptionsViewControllerProtocol {}

class DPAGContactsBaseViewController: DPAGContactsSelectionViewController, DPAGNavigationViewControllerStyler {
    var updateSelectedPerson = false
    var reloadOnAppear = false

    init(contactsSelected: DPAGSearchListSelection<DPAGContact>) {
        super.init(contactsSelected: contactsSelected, showInviteAction: false)
        self.options = [.EnableGroupedStyle]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if self.reloadOnAppear {
            self.reloadOnAppear = false

            self.performBlockInBackground { [weak self] in
                self?.createModel()
                self?.performBlockOnMainThread { [weak self] in
                    self?.tableView.reloadData()
                }
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if self.updateSelectedPerson {
            self.updateSelectedPerson = false
            self.performBlockInBackground { [weak self] in
                self?.createModel()
                self?.performBlockOnMainThread { [weak self] in
                    self?.tableView.reloadData()
                }
            }
        }
    }

    override func configureSearchBar() {
        if AppConfig.isShareExtension == false { self.configureSearchBarWithResultsController(DPAGApplicationFacadeUIContacts.contactsSearchResultsVC(delegate: self, emptyViewDelegate: self), placeholder: "android.serach.placeholder")
        }
    }

    override func configureNavigationBar() {
        super.configureNavigationBar()
        if AppConfig.isShareExtension == false {
            if let account = DPAGApplicationFacade.cache.account, account.isCompanyUserRestricted {} else {
                self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kEllipsisCircle]?.imageWithTintColor(DPAGColorProvider.shared[.labelText]), action: #selector(handleOptions), accessibilityLabelIdentifier: "navigation.options")
            }
        }
    }

    override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kEllipsisCircle]?.imageWithTintColor(DPAGColorProvider.shared[.labelText]), action: #selector(handleOptions), accessibilityLabelIdentifier: "navigation.options")
    }
    
    @objc
    func handleOptions() {
        self.handleOptions(presentingVC: self, modelVC: self, barButtonItem: self.navigationItem.rightBarButtonItem)
    }

    override func didSelect(objects: Set<DPAGContact>) {
        if let contact = objects.first {
            self.didSelectContact(contact: contact)
        }
    }
}

extension DPAGContactsBaseViewController: DPAGContactsSearchViewControllerDelegate {
    func didSelectContact(contact: DPAGContact) {
        let blockSelect = { [weak self] in
            let contactDetailsViewController = DPAGApplicationFacadeUIContacts.contactDetailsVC(contact: contact)

            contactDetailsViewController.delegate = self
            contactDetailsViewController.enableRemove = true

            self?.navigationController?.pushViewController(contactDetailsViewController, animated: true)
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

extension DPAGContactsBaseViewController: DPAGContactDetailDelegate {
    func contactDidUpdate(_: DPAGContact) {
        self.updateSelectedPerson = true
    }
}

class DPAGContactsViewController: DPAGContactsBaseViewController {
    override func configureNavigationBar() {
        super.configureNavigationBar()
        if AppConfig.isShareExtension == false {
            self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kEllipsisCircle]?.imageWithTintColor(DPAGColorProvider.shared[.labelText]), action: #selector(handleOptions), accessibilityLabelIdentifier: "navigation.options")
        }
    }
    
    override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kEllipsisCircle]?.imageWithTintColor(DPAGColorProvider.shared[.labelText]), action: #selector(handleOptions), accessibilityLabelIdentifier: "navigation.options")
    }
}

protocol DPAGContactsPageViewControllerProtocol: AnyObject {
    func handleOptions()
}

class DPAGContactsPageViewController: DPAGContactsBaseViewController {}

extension DPAGContactsPageViewController: DPAGContactsPageViewControllerProtocol {}

class DPAGContactsCompanyViewController: DPAGContactsBaseViewController, DPAGViewControllerNavigationTitleBig {
    override var selectionType: DPAGContactsSelectionType {
        .company
    }
}

protocol DPAGContactsDomainEmptyViewControllerProtocol: AnyObject {
    var tableViewEmpty: UIView? { get }
    var navigationController: UINavigationController? { get }

    var hasEmailDomainContacts: Bool { get }

    func configureEmptyDomainGui()
    func updateEmptyDomainGui()

    func hideEmptyView()
    func showEmptyView()
}

extension DPAGContactsDomainEmptyViewControllerProtocol {
    func configureEmptyDomainGui() {
        if AppConfig.isShareExtension {
            let cache = DPAGApplicationFacadeShareExt.cache

            guard let emptyView = self.tableViewEmpty as? DPAGContactsDomainEmptyViewProtocol, let account = cache.account, let contact = cache.contact(for: account.guid) else {
                return
            }

            if let domain = contact.eMailDomain {
                emptyView.labelHeader.text = DPAGLocalizedString("settings.companyprofile.contactsoverview.empty.title")
                emptyView.labelDescription.text = String(format: DPAGLocalizedString("settings.companyprofile.contactsoverview.empty.text2"), domain)
                emptyView.labelHint.isHidden = true
                emptyView.viewBtnStartEMail.isHidden = true
            }
        } else {
            let cache = DPAGApplicationFacade.cache

            guard let emptyView = self.tableViewEmpty as? DPAGContactsDomainEmptyViewProtocol, let account = cache.account, let contact = cache.contact(for: account.guid) else {
                return
            }

            if let domain = contact.eMailDomain, contact.eMailAddress != nil, self.hasEmailDomainContacts == false {
                emptyView.labelHeader.text = DPAGLocalizedString("settings.companyprofile.contactsoverview.empty.title")
                emptyView.labelDescription.text = String(format: DPAGLocalizedString("settings.companyprofile.contactsoverview.empty.text2"), domain)
                emptyView.labelHint.isHidden = true
                emptyView.viewBtnStartEMail.isHidden = true
            } else {
                emptyView.labelHeader.text = DPAGLocalizedString("settings.companyprofile.contactsoverview.empty.title")
                emptyView.labelDescription.text = DPAGLocalizedString("settings.companyprofile.contactsoverview.empty.text1")
                emptyView.labelHint.text = DPAGLocalizedString("settings.profile.email_hint")
            }
        }
    }

    func updateEmptyDomainGui() {
        if AppConfig.isShareExtension == false {
            let cache = DPAGApplicationFacade.cache

            guard self.tableViewEmpty as? DPAGContactsDomainEmptyViewProtocol != nil, let account = cache.account, let contact = cache.contact(for: account.guid) else {
                return
            }

            if contact.eMailDomain != nil, contact.eMailAddress != nil, self.hasEmailDomainContacts {
                self.hideEmptyView()
            } else {
                self.showEmptyView()
            }
        }
    }
}

class DPAGContactsDomainViewController: DPAGContactsBaseViewController, DPAGContactsDomainEmptyViewControllerProtocol {
    override var selectionType: DPAGContactsSelectionType {
        .domain
    }

    private var _tableViewEmpty: UIView?

    override var tableViewEmpty: UIView? {
        get {
            if AppConfig.isShareExtension == false {
                if _tableViewEmpty == nil {
                    _tableViewEmpty = DPAGApplicationFacadeUIContacts.viewContactsDomainEmpty()
                }
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
                emptyView.btnStartEMail.addTarget(self, action: #selector(handleAuthenticateMailButtonTapped(_:)), for: .touchUpInside)
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

class DPAGContactsCompanyPageViewController: DPAGContactsCompanyViewController {}

class DPAGContactsDomainPageViewController: DPAGContactsDomainViewController {}
