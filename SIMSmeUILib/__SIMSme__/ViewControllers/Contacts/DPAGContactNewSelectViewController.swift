//
//  DPAGContactNewSelectViewController.swift
// ginlo
//
//  Created by RBU on 18.12.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGContactNewSelectViewController: DPAGTableViewControllerBackground, DPAGContactNewSelectViewControllerProtocol {
    private static let cellContactIdentifier = "cellContactIdentifier"
    private var contacts: [DPAGContact] = []

    init(contactGuids: [String]) {
        for contactGuid in contactGuids {
            if let contact = DPAGApplicationFacade.cache.contact(for: contactGuid) {
                self.contacts.append(contact)
            }
        }
        super.init(style: UITableView.Style.plain)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = DPAGLocalizedString("contacts.search.title")
    }

    override func configureTableView() {
        super.configureTableView()
        self.tableView.register(DPAGApplicationFacadeUIViews.cellContactNib(), forCellReuseIdentifier: DPAGContactNewSelectViewController.cellContactIdentifier)
    }
}

extension DPAGContactNewSelectViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        self.contacts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellDequeued = tableView.dequeueReusableCell(withIdentifier: DPAGContactNewSelectViewController.cellContactIdentifier, for: indexPath)
        guard let cell = cellDequeued as? (UITableViewCell & DPAGContactCellProtocol) else { return cellDequeued }
        let contact = self.contacts[indexPath.row]
        cell.update(contact: contact)
        cell.accessoryView = nil
        cell.selectionStyle = .default
        cell.accessibilityIdentifier = "contact-" + contact.guid
        return cell
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        DPAGConstantsGlobal.kContactCellHeight
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        1
    }
}

extension DPAGContactNewSelectViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let account = DPAGApplicationFacade.cache.account, let contactSelf = DPAGApplicationFacade.cache.contact(for: account.guid) else { return }
        let contactCache = self.contacts[indexPath.row]
        switch contactCache.entryTypeServer {
            case .company:
                let nextVC = DPAGApplicationFacadeUIContacts.contactDetailsVC(contact: contactCache)
                self.navigationController?.pushViewController(nextVC, animated: true)
            case .email:
                if contactCache.eMailDomain == contactSelf.eMailDomain {
                    let nextVC = DPAGApplicationFacadeUIContacts.contactDetailsVC(contact: contactCache)
                    self.navigationController?.pushViewController(nextVC, animated: true)
                } else {
                    let nextVC = DPAGApplicationFacadeUIContacts.contactNewCreateVC(contact: contactCache)
                    self.navigationController?.pushViewController(nextVC, animated: true)
                }
            case .meMyselfAndI:
                break
            case .privat:
                let nextVC = DPAGApplicationFacadeUIContacts.contactNewCreateVC(contact: contactCache)
                self.navigationController?.pushViewController(nextVC, animated: true)
        }
    }
}
