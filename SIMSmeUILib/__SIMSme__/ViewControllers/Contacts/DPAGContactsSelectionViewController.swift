//
//  DPAGContactsSelectionViewController.swift
// ginlo
//
//  Created by RBU on 05/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGContactsSelectionBaseViewController: DPAGObjectsSelectionBaseViewController<DPAGContact>, UITableViewDataSource, UITableViewDelegate, DPAGContactsSelectionBaseViewControllerProtocol {
    weak var progressHUDSyncInfo: DPAGProgressHUDWithLabelProtocol?

    private static let cellContactIdentifier = "cellContactIdentifier"

    var selectionType: DPAGContactsSelectionType { .privat }

    let contactsSelected: DPAGSearchListSelection<DPAGContact>

    init(contactsSelected: DPAGSearchListSelection<DPAGContact>) {
        self.contactsSelected = contactsSelected

        super.init(objectsSelected: contactsSelected)
    }

    var showsLRUContacts: Bool {
        if AppConfig.isShareExtension {
            let preferences = DPAGApplicationFacadeShareExt.preferences
            switch self.selectionType {
                case .privat:
                    return preferences.contactsPrivateFullTextSearchEnabled
                case .company:
                    return preferences.contactsCompanyFullTextSearchEnabled
                case .domain:
                    return preferences.contactsDomainFullTextSearchEnabled
            }
        } else {
            let preferences = DPAGApplicationFacade.preferences
            switch self.selectionType {
                case .privat:
                    return preferences.contactsPrivateFullTextSearchEnabled
                case .company:
                    return preferences.contactsCompanyFullTextSearchEnabled
                case .domain:
                    return preferences.contactsDomainFullTextSearchEnabled
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let headerView = self.tableView.tableHeaderView as? (UIView & DPAGContactsListHeaderViewProtocol) {
            let headerViewHeight = headerView.frame.height
            headerView.setPreferredMaxLayoutWidth(self.view.bounds.width)
            if headerView.frame.height != headerViewHeight {
                self.tableView.tableHeaderView = headerView
            }
        }
    }

    override func configureTableView() {
        super.configureTableView()
        self.tableView.register(DPAGApplicationFacadeUIViews.cellContactNib(), forCellReuseIdentifier: DPAGContactsSelectionBaseViewController.cellContactIdentifier)
    }

    // MARK: table view data source

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellDequeued = tableView.dequeueReusableCell(withIdentifier: DPAGContactsSelectionBaseViewController.cellContactIdentifier, for: indexPath)

        guard let cell = cellDequeued as? (UITableViewCell & DPAGContactCellProtocol) else { return cellDequeued }

        guard let contact = self.objectForTableView(tableView, indexPath: indexPath) else {
            cell.labelText?.text = ""
            cell.labelTextDetail?.text = ""
            cell.imageViewProfile?.image = nil
            cell.labelMandant.text = ""
            cell.viewMandant.backgroundColor = UIColor.clear
            cell.accessoryView = nil

            return cell
        }

        self.configureCell(cell, withContact: contact)

        cell.accessibilityIdentifier = "contact-" + contact.guid

        return cell
    }

    func configureCell(_ cell: UITableViewCell & DPAGContactCellProtocol, withContact contact: DPAGContact) {
        cell.update(contact: contact)

        if self.contactsSelected.contains(contact) {
            if self.invertedSelection {
                cell.imageViewProfile.isHidden = false
                cell.imageViewCheck.isHidden = true
                cell.imageViewUncheck.isHidden = true
                cell.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]

                if self.contactsSelected.containsFixed(contact) {
                    cell.selectionStyle = .none
                } else {
                    cell.selectionStyle = .default
                }
            } else {
                cell.imageViewProfile.isHidden = true
                cell.imageViewCheck.isHidden = false
                cell.imageViewUncheck.isHidden = true

                if self.contactsSelected.containsFixed(contact) {
                    cell.imageViewCheck?.alpha = 0.5
                    cell.backgroundColor = DPAGColorProvider.shared[.contactSelectionSelectedBackgroundFixed]
                    cell.selectionStyle = .none
                } else {
                    cell.backgroundColor = DPAGColorProvider.shared[.contactSelectionSelectedBackground]
                    cell.imageViewCheck?.alpha = 1.0
                    cell.selectionStyle = .default
                }
            }
        } else {
            if self.invertedSelection {
                cell.imageViewProfile.isHidden = true
                cell.imageViewCheck.isHidden = true
                cell.imageViewUncheck.isHidden = false
                cell.backgroundColor = DPAGColorProvider.shared[.contactSelectionNotSelectedBackground]
            } else {
                cell.imageViewProfile.isHidden = false
                cell.imageViewCheck.isHidden = true
                cell.imageViewUncheck.isHidden = true
                cell.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            }
            cell.selectionStyle = .default
        }
    }

    func tableView(_: UITableView, estimatedHeightForRowAt _: IndexPath) -> CGFloat {
        DPAGConstantsGlobal.kContactCellHeight
    }

    override func filterContent(searchText: String, completion: @escaping DPAGCompletion) {
        _ = self.model?.filter(by: searchText)

        self.performBlockOnMainThread { [weak self] in
            (self?.searchResultsController as? DPAGContactsSearchResultsViewControllerProtocol)?.contactsSearched = self?.model?.objectsFiltered ?? []
            (self?.searchResultsController as? DPAGContactsSearchResultsViewControllerProtocol)?.contactsSelected = self?.contactsSelected.objectsSelected
            completion()
        }
    }

    override func willPresentSearchController(_ searchController: UISearchController) {
        super.willPresentSearchController(searchController)

        (self.searchResultsController as? DPAGContactsSearchResultsViewControllerProtocol)?.contactsSelected = self.contactsSelected.objectsSelected
    }

    func updateTitle() {
        if AppConfig.isShareExtension {
            let cache = DPAGApplicationFacadeShareExt.cache
            let preferences = DPAGApplicationFacadeShareExt.preferences

            if cache.account?.isCompanyUserRestricted ?? false, let title = preferences.companyIndexName {
                self.title = title
            } else {
                self.title = DPAGLocalizedString("contacts.overViewViewControllerTitle")
            }
        } else {
            let cache = DPAGApplicationFacade.cache
            let preferences = DPAGApplicationFacade.preferences

            if cache.account?.isCompanyUserRestricted ?? false, let title = preferences.companyIndexName {
                self.title = title
            } else {
                self.title = DPAGLocalizedString("contacts.overViewViewControllerTitle")
            }
        }

        (self.parent?.parent as? DPAGContactsPagesBaseViewControllerProtocol)?.updateTitle()
    }
}

class DPAGContactsSelectionViewController: DPAGContactsSelectionBaseViewController {
    private var showInviteAction: Bool = false

    override var groupStyle: Bool {
        if AppConfig.isShareExtension {
            let preferences = DPAGApplicationFacadeShareExt.preferences
            switch self.selectionType {
                case .privat:
                    if preferences.contactsPrivateFullTextSearchEnabled {
                        return false
                    }
                case .company:
                    if preferences.contactsCompanyFullTextSearchEnabled {
                        return false
                    }
                case .domain:
                    if preferences.contactsDomainFullTextSearchEnabled {
                        return false
                    }
            }
        } else {
            let preferences = DPAGApplicationFacade.preferences
            switch self.selectionType {
                case .privat:
                    if preferences.contactsPrivateFullTextSearchEnabled {
                        return false
                    }
                case .company:
                    if preferences.contactsCompanyFullTextSearchEnabled {
                        return false
                    }
                case .domain:
                    if preferences.contactsDomainFullTextSearchEnabled {
                        return false
                    }
            }
        }
        return self.options.contains(.EnableGroupedStyle)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if AppConfig.isShareExtension {
            let preferences = DPAGApplicationFacadeShareExt.preferences
            switch self.selectionType {
                case .privat:
                    if preferences.contactsPrivateFullTextSearchEnabled {
                        return DPAGLocalizedString("contacts.lastRecentlyUsed.title")
                    }
                case .company:
                    if preferences.contactsCompanyFullTextSearchEnabled {
                        return DPAGLocalizedString("contacts.lastRecentlyUsed.title")
                    }
                case .domain:
                    if preferences.contactsDomainFullTextSearchEnabled {
                        return DPAGLocalizedString("contacts.lastRecentlyUsed.title")
                    }
            }
        } else {
            let preferences = DPAGApplicationFacade.preferences
            switch self.selectionType {
                case .privat:
                    if preferences.contactsPrivateFullTextSearchEnabled {
                        return DPAGLocalizedString("contacts.lastRecentlyUsed.title")
                    }
                case .company:
                    if preferences.contactsCompanyFullTextSearchEnabled {
                        return DPAGLocalizedString("contacts.lastRecentlyUsed.title")
                    }
                case .domain:
                    if preferences.contactsDomainFullTextSearchEnabled {
                        return DPAGLocalizedString("contacts.lastRecentlyUsed.title")
                    }
            }
        }
        return super.tableView(tableView, titleForHeaderInSection: section)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if AppConfig.isShareExtension {
            let preferences = DPAGApplicationFacadeShareExt.preferences
            switch self.selectionType {
                case .privat:
                    if preferences.contactsPrivateFullTextSearchEnabled {
                        return UITableView.automaticDimension
                    }
                case .company:
                    if preferences.contactsCompanyFullTextSearchEnabled {
                        return UITableView.automaticDimension
                    }
                case .domain:
                    if preferences.contactsDomainFullTextSearchEnabled {
                        return UITableView.automaticDimension
                    }
            }
        } else {
            let preferences = DPAGApplicationFacade.preferences
            switch self.selectionType {
                case .privat:
                    if preferences.contactsPrivateFullTextSearchEnabled {
                        return UITableView.automaticDimension
                    }
                case .company:
                    if preferences.contactsCompanyFullTextSearchEnabled {
                        return UITableView.automaticDimension
                    }
                case .domain:
                    if preferences.contactsDomainFullTextSearchEnabled {
                        return UITableView.automaticDimension
                    }
            }
        }
        return super.tableView(tableView, heightForHeaderInSection: section)
    }

    var hasEmailDomainContacts: Bool {
        if AppConfig.isShareExtension {
            let preferences = DPAGApplicationFacadeShareExt.preferences

            return preferences.contactsDomainCount > 0
        } else {
            let preferences = DPAGApplicationFacade.preferences

            return preferences.contactsDomainCount > 0
        }
    }

    @objc
    func contactCountChanged() {
        self.performBlockOnMainThread {
            self.updateTableHeader()
        }
    }

    // TODO: Remove duplicated code
    func updateTableHeader() {
        guard (self.tableView.tableHeaderView is UISearchBar) == false else { return }
        guard let headerView = (self.tableView.tableHeaderView as? (UIView & DPAGContactsListHeaderViewProtocol)) ?? DPAGApplicationFacadeUIContacts.viewContactsListHeader() else { return }
        if AppConfig.isShareExtension {
            let cache = DPAGApplicationFacadeShareExt.cache
            let preferences = DPAGApplicationFacadeShareExt.preferences

            switch self.selectionType {
                case .company:
                    let count = preferences.contactsCompanyCount
                    headerView.searchController = self.searchController ?? (self.parent?.parent as? DPAGContactsPagesBaseViewControllerProtocol)?.searchController
                    headerView.setCount(count, source: preferences.companyIndexName ?? (cache.account?.companyName ?? DPAGLocalizedString("contacts.companyContacts.list.title")), showSearch: preferences.contactsCompanyFullTextSearchEnabled)
                    headerView.setPreferredMaxLayoutWidth(self.view.bounds.width)
                    self.tableView.tableHeaderView = headerView
                case .domain:
                    guard (self.tableView.tableHeaderView is UISearchBar) == false, let account = cache.account, let contact = cache.contact(for: account.guid) else { return }
                    guard contact.eMailDomain != nil, contact.eMailAddress != nil else { return }
                    guard self.hasEmailDomainContacts else { return }
                    guard let headerView = (self.tableView.tableHeaderView as? (UIView & DPAGContactsListHeaderViewProtocol)) ?? DPAGApplicationFacadeUIContacts.viewContactsListHeader() else { return }
                    let count = preferences.contactsDomainCount
                    var title = "???"
                    if let account = cache.account, let contact = cache.contact(for: account.guid), let emailDomain = contact.eMailDomain {
                        title = emailDomain
                    }
                    headerView.searchController = self.searchController ?? (self.parent?.parent as? DPAGContactsPagesBaseViewControllerProtocol)?.searchController
                    headerView.setCount(count, source: title, showSearch: preferences.contactsDomainFullTextSearchEnabled)
                    headerView.setPreferredMaxLayoutWidth(self.view.bounds.width)
                    self.tableView.tableHeaderView = headerView
                case .privat:
                    let count = preferences.contactsPrivateCount
                    headerView.searchController = self.searchController ?? (self.parent?.parent as? DPAGContactsPagesBaseViewControllerProtocol)?.searchController
                    headerView.setCount(count, source: DPAGLocalizedString("settings.companyprofile.contactsoverview.button1"), showSearch: preferences.contactsPrivateFullTextSearchEnabled)
                    headerView.setPreferredMaxLayoutWidth(self.view.bounds.width)
                    self.tableView.tableHeaderView = headerView
            }
        } else {
            let cache = DPAGApplicationFacade.cache
            let preferences = DPAGApplicationFacade.preferences

            switch self.selectionType {
                case .company:
                    let count = preferences.contactsCompanyCount
                    headerView.searchController = self.searchController ?? (self.parent?.parent as? DPAGContactsPagesBaseViewControllerProtocol)?.searchController
                    headerView.setCount(count, source: preferences.companyIndexName ?? (cache.account?.companyName ?? DPAGLocalizedString("contacts.companyContacts.list.title")), showSearch: preferences.contactsCompanyFullTextSearchEnabled)
                    headerView.setPreferredMaxLayoutWidth(self.view.bounds.width)
                    self.tableView.tableHeaderView = headerView
                case .domain:
                    guard (self.tableView.tableHeaderView is UISearchBar) == false, let account = cache.account, let contact = cache.contact(for: account.guid) else { return }
                    guard contact.eMailDomain != nil, contact.eMailAddress != nil else { return }
                    guard self.hasEmailDomainContacts else { return }
                    guard let headerView = (self.tableView.tableHeaderView as? (UIView & DPAGContactsListHeaderViewProtocol)) ?? DPAGApplicationFacadeUIContacts.viewContactsListHeader() else { return }
                    let count = preferences.contactsDomainCount
                    var title = "???"
                    if let account = cache.account, let contact = cache.contact(for: account.guid), let emailDomain = contact.eMailDomain {
                        title = emailDomain
                    }
                    headerView.searchController = self.searchController ?? (self.parent?.parent as? DPAGContactsPagesBaseViewControllerProtocol)?.searchController
                    headerView.setCount(count, source: title, showSearch: preferences.contactsDomainFullTextSearchEnabled)
                    headerView.setPreferredMaxLayoutWidth(self.view.bounds.width)
                    self.tableView.tableHeaderView = headerView
                case .privat:
                    let count = preferences.contactsPrivateCount
                    headerView.searchController = self.searchController ?? (self.parent?.parent as? DPAGContactsPagesBaseViewControllerProtocol)?.searchController
                    headerView.setCount(count, source: DPAGLocalizedString("settings.companyprofile.contactsoverview.button1"), showSearch: preferences.contactsPrivateFullTextSearchEnabled)
                    headerView.setPreferredMaxLayoutWidth(self.view.bounds.width)
                    self.tableView.tableHeaderView = headerView
            }
        }
    }

    init(contactsSelected: DPAGSearchListSelection<DPAGContact>, showInviteAction: Bool = false) {
        self.showInviteAction = showInviteAction
        super.init(contactsSelected: contactsSelected)
        NotificationCenter.default.addObserver(self, selector: #selector(contactCountChanged), name: DPAGStrings.Notification.Contact.CONTACT_COUNT_CHANGED, object: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        if AppConfig.isShareExtension == false {
            if self.showInviteAction, DPAGApplicationFacade.preferences.showInviteFriends {
                let viewInvite = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: 54))
                let buttonInvite = UIButton(type: .custom)
                buttonInvite.setTitle(DPAGLocalizedString("settings.informFriends"), for: .normal)
                viewInvite.addSubview(buttonInvite)
                buttonInvite.translatesAutoresizingMaskIntoConstraints = false
                buttonInvite.configureButton()
                buttonInvite.addTargetClosure { [weak self] _ in
                    SharingHelper().showSharingForInvitation(fromViewController: self, sourceView: buttonInvite)
                }
                NSLayoutConstraint.activate([
                    viewInvite.constraintHeight(54),
                    buttonInvite.constraintHeight(40),
                    viewInvite.constraintCenterY(subview: buttonInvite),
                    viewInvite.constraintLeadingSafeArea(subview: buttonInvite, padding: 8, priority: UILayoutPriority(rawValue: 999)),
                    viewInvite.constraintTrailingSafeArea(subview: buttonInvite, padding: 8, priority: UILayoutPriority(rawValue: 999))
                ])
                self.tableView.tableHeaderView = viewInvite
            }
        }
    }

    override func createModel() {
        if AppConfig.isShareExtension {
            let cache = DPAGApplicationFacadeShareExt.cache
            let preferences = DPAGApplicationFacadeShareExt.preferences
            switch self.selectionType {
                case .privat:
                    if preferences.contactsPrivateFullTextSearchEnabled {
                        let contacts = preferences.lastRecentlyUsedContactsPrivate.compactMap({ (contactGuid) -> DPAGContact? in
                            if let contact = cache.contact(for: contactGuid), contact.isDeleted == false {
                                return contact
                            }
                            return nil
                        })
                        self.model = DPAGSearchListModel(objects: Set(contacts), objectsSorted: contacts)
                    } else {
                        let contacts = DPAGApplicationFacade.contactsWorker.allContactsServer(entryType: .privat) { (contact) -> Bool in
                            contact.isBlocked == false && contact.isDeleted == false
                        }
                        self.model = DPAGSearchListModel(objects: contacts)
                    }
                case .company:
                    if preferences.contactsCompanyFullTextSearchEnabled {
                        let contacts = preferences.lastRecentlyUsedContactsCompany.compactMap({ (contactGuid) -> DPAGContact? in
                            if let contact = cache.contact(for: contactGuid), contact.isDeleted == false {
                                return contact
                            }
                            return nil
                        })
                        self.model = DPAGSearchListModel(objects: Set(contacts), objectsSorted: contacts)
                    } else {
                        let contacts = DPAGApplicationFacade.contactsWorker.allContactsServer(entryType: .company, filter: nil)
                        self.model = DPAGSearchListModel(objects: contacts)
                    }
                case .domain:
                    if preferences.contactsDomainFullTextSearchEnabled {
                        let contacts = preferences.lastRecentlyUsedContactsDomain.compactMap({ (contactGuid) -> DPAGContact? in
                            if let contact = cache.contact(for: contactGuid), contact.isDeleted == false {
                                return contact
                            }
                            return nil
                        })
                        self.model = DPAGSearchListModel(objects: Set(contacts), objectsSorted: contacts)
                    } else {
                        guard let account = cache.account, let contact = cache.contact(for: account.guid) else {
                            self.model = DPAGSearchListModel(objects: Set())
                            return
                        }
                        let emailDomain = contact.eMailDomain

                        let contacts = DPAGApplicationFacade.contactsWorker.allContactsServer(entryType: [.email, .company]) { (contact) -> Bool in
                            emailDomain == contact.eMailDomain // && contact.isDeleted == false
                        }
                        self.model = DPAGSearchListModel(objects: contacts)
                    }
            }
        } else {
            let cache = DPAGApplicationFacade.cache
            let preferences = DPAGApplicationFacade.preferences
            switch self.selectionType {
                case .privat:
                    if preferences.contactsPrivateFullTextSearchEnabled {
                        let contacts = preferences.lastRecentlyUsedContactsPrivate.compactMap({ (contactGuid) -> DPAGContact? in
                            if let contact = cache.contact(for: contactGuid), contact.isDeleted == false {
                                return contact
                            }
                            return nil
                        })
                        self.model = DPAGSearchListModel(objects: Set(contacts), objectsSorted: contacts)
                    } else {
                        let contacts = DPAGApplicationFacade.contactsWorker.allContactsServer(entryType: .privat) { (contact) -> Bool in
                            contact.isBlocked == false && contact.isDeleted == false
                        }
                        self.model = DPAGSearchListModel(objects: contacts)
                    }
                case .company:
                    if preferences.contactsCompanyFullTextSearchEnabled {
                        let contacts = preferences.lastRecentlyUsedContactsCompany.compactMap({ (contactGuid) -> DPAGContact? in
                            if let contact = cache.contact(for: contactGuid), contact.isDeleted == false {
                                return contact
                            }
                            return nil
                        })
                        self.model = DPAGSearchListModel(objects: Set(contacts), objectsSorted: contacts)
                    } else {
                        let contacts = DPAGApplicationFacade.contactsWorker.allContactsServer(entryType: .company, filter: nil)
                        self.model = DPAGSearchListModel(objects: contacts)
                    }
                case .domain:
                    if preferences.contactsDomainFullTextSearchEnabled {
                        let contacts = preferences.lastRecentlyUsedContactsDomain.compactMap({ (contactGuid) -> DPAGContact? in
                            if let contact = cache.contact(for: contactGuid), contact.isDeleted == false {
                                return contact
                            }
                            return nil
                        })
                        self.model = DPAGSearchListModel(objects: Set(contacts), objectsSorted: contacts)
                    } else {
                        guard let account = cache.account, let contact = cache.contact(for: account.guid) else {
                            self.model = DPAGSearchListModel(objects: Set())
                            return
                        }
                        let emailDomain = contact.eMailDomain
                        let contacts = DPAGApplicationFacade.contactsWorker.allContactsServer(entryType: [.email, .company]) { (contact) -> Bool in
                            emailDomain == contact.eMailDomain // && contact.isDeleted == false
                        }
                        self.model = DPAGSearchListModel(objects: contacts)
                    }
            }
        }
    }

    override func handleModelCreated() {
        super.handleModelCreated()

        self.updateTitle()
        self.updateTableHeader()
    }
}

extension DPAGContactsSelectionViewController: DPAGContactsSearchEmptyViewDelegate {
    func handleSearch() {
        let blockSelect = { [weak self] in
            let nextVC = DPAGApplicationFacadeUIContacts.contactNewSearchVC()

            self?.navigationController?.pushViewController(nextVC, animated: true)

            (self as? DPAGViewControllerWithReloadProtocol)?.reloadOnAppear = true
        }

        if let searchController = self.searchController, searchController.isActive {
            searchController.dismiss(animated: true) {
                blockSelect()
            }
        } else {
            blockSelect()
        }
    }

    func handleInvite() {
        if let searchController = self.searchController, searchController.isActive {
            searchController.dismiss(animated: true) { [weak self] in
                SharingHelper().showSharingForInvitation(fromViewController: self, sourceView: self?.tableView.tableHeaderView)
            }
        } else {
            SharingHelper().showSharingForInvitation(fromViewController: self, sourceView: self.tableView.tableHeaderView)
        }
    }
}
