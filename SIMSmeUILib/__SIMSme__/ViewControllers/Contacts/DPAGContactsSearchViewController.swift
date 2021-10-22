//
//  DPAGContactsSearchViewController.swift
// ginlo
//
//  Created by RBU on 14.12.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGContactsPagesSearchResultsViewController: DPAGContactsSearchResultsViewController {}

class DPAGContactsSearchResultsViewController: DPAGSearchResultsViewController, DPAGContactsSearchResultsViewControllerProtocol {
    static let CellContactIdentifier = "cellContactIdentifier"
    static let CellContactEmptyIdentifier = "cellContactEmptyIdentifier"

    var contactsSearched: [DPAGContact] = []
    var contactsSelected: Set<DPAGContact>?

    weak var searchDelegate: DPAGContactsSearchViewControllerDelegate?

    weak var emptyViewDelegate: DPAGContactsSearchEmptyViewDelegate?

    init(delegate: DPAGContactsSearchViewControllerDelegate, emptyViewDelegate: DPAGContactsSearchEmptyViewDelegate?) {
        self.searchDelegate = delegate
        self.emptyViewDelegate = emptyViewDelegate

        super.init(style: .plain)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.tableView.estimatedRowHeight = DPAGConstantsGlobal.kContactCellHeight
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.register(DPAGApplicationFacadeUIViews.cellContactNib(), forCellReuseIdentifier: DPAGContactsSearchResultsViewController.CellContactIdentifier)
        self.tableView.sectionHeaderHeight = 0

        if AppConfig.isShareExtension == false { self.tableView.register(DPAGApplicationFacadeUIContacts.viewContactsSearchEmptyNib(), forCellReuseIdentifier: DPAGContactsSearchResultsViewController.CellContactEmptyIdentifier)
        }
    }
}

extension DPAGContactsSearchResultsViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        if AppConfig.isShareExtension {
            return self.contactsSearched.count
        } else {
            return max(1, self.contactsSearched.count)
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if self.contactsSearched.isEmpty == false {
            let cellDequeued = tableView.dequeueReusableCell(withIdentifier: DPAGContactsSearchResultsViewController.CellContactIdentifier, for: indexPath)

            cellDequeued.accessibilityIdentifier = "cell_\(indexPath.section)_\(indexPath.row)"

            guard let cell = cellDequeued as? (UITableViewCell & DPAGContactCellProtocol) else { return cellDequeued }

            let contact = self.contactsSearched[indexPath.row]

            cell.update(contact: contact)

            cell.imageViewCheck.isHidden = (self.contactsSelected?.contains(contact) ?? false) == false

            cell.labelText.updateWithSearchBarText(self.searchBarText)
            cell.labelTextDetail.updateWithSearchBarText(self.searchBarText)
            cell.labelTextExtended.updateWithSearchBarText(self.searchBarText)

            return cell
        } else {
            if AppConfig.isShareExtension {
                return UITableViewCell(style: .default, reuseIdentifier: "noIdent")
            } else {
                let cellDequeued = tableView.dequeueReusableCell(withIdentifier: DPAGContactsSearchResultsViewController.CellContactEmptyIdentifier, for: indexPath)

                cellDequeued.accessibilityIdentifier = "cell_-1_-1"

                guard let cell = cellDequeued as? (UITableViewCell & DPAGContactsSearchEmptyViewProtocol) else { return cellDequeued }

                cell.buttonDelegate = self

                return cell
            }
        }
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        1
    }
}

extension DPAGContactsSearchResultsViewController: DPAGContactsSearchEmptyViewDelegate {
    func handleSearch() {
        self.emptyViewDelegate?.handleSearch()
    }

    func handleInvite() {
        self.emptyViewDelegate?.handleInvite()
    }
}

extension DPAGContactsSearchResultsViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.contactsSearched.count <= indexPath.row {
            return
        }
        var contact = self.contactsSearched[indexPath.row]

        if AppConfig.isShareExtension {
            let cache = DPAGApplicationFacadeShareExt.cache

            // get real cached object (not a full text instance)
            if let contactCache = cache.contact(for: contact.guid) {
                contact = contactCache
            }
        } else {
            let cache = DPAGApplicationFacade.cache

            // get real cached object (not a full text instance)
            if let contactCache = cache.contact(for: contact.guid) {
                contact = contactCache
            }
        }

        self.contactsSelected?.insert(contact)

        self.tableView.deselectRow(at: indexPath, animated: false)

        self.tableView.reloadRows(at: [indexPath], with: .automatic)

        self.performBlockInBackground { [weak self] in
            Thread.sleep(forTimeInterval: TimeInterval(UINavigationController.hideShowBarDuration))

            self?.performBlockOnMainThread { [weak self] in
                self?.searchDelegate?.didSelectContact(contact: contact)
            }
        }
    }
}
