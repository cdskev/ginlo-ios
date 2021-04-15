//
//  DPAGBlockedContactsViewController.swift
//  SIMSme
//
//  Created by RBU on 26/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGBlockedContactsViewController: DPAGTableViewControllerBackground {
    private static let BlockedCellIdentifier = "BlockedContactCell"
    private var blockedContacts: [DPAGContact]

    init(blockedContacts: [DPAGContact]) {
        self.blockedContacts = blockedContacts
        super.init(style: .plain)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = DPAGLocalizedString("settings.chat.blockedContacts")
    }

    override func configureTableView() {
        super.configureTableView()
        self.tableView.sectionHeaderHeight = 0.0
        self.tableView.sectionFooterHeight = 0.0
        self.tableView.sectionIndexBackgroundColor = UIColor.clear
        self.tableView.rowHeight = DPAGConstantsGlobal.kContactCellHeight
        self.tableView.register(DPAGApplicationFacadeUIViews.cellContactNib(), forCellReuseIdentifier: DPAGBlockedContactsViewController.BlockedCellIdentifier)
    }

    @objc
    private func handleUnblockContact(_ sender: Any?) {
        if let button = sender as? UIButton {
            self.unblockContact(self.blockedContacts[button.tag].guid, idx: button.tag)
        }
    }

    private func unblockContact(_ contactGuid: String?, idx: Int) {
        guard let contactAccountGuid = contactGuid else { return }
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            DPAGApplicationFacade.contactsWorker.unblockContact(contactAccountGuid: contactAccountGuid) { [weak self] _, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    if let strongSelf = self {
                        if let errorMessage = errorMessage {
                            if errorMessage == "service.ERR-0007" {
                                strongSelf.performBlockInBackground {
                                    DPAGApplicationFacade.contactsWorker.deleteContact(withContactGuid: contactAccountGuid)
                                }
                                strongSelf.blockedContacts.remove(at: idx)
                                strongSelf.tableView.reloadData()
                            } else {
                                strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                            }
                        } else {
                            strongSelf.blockedContacts.remove(at: idx)
                            strongSelf.tableView.reloadData()
                        }
                    }
                }
            }
        }
    }
}

extension DPAGBlockedContactsViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        self.blockedContacts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellDequeued = tableView.dequeueReusableCell(withIdentifier: DPAGBlockedContactsViewController.BlockedCellIdentifier, for: indexPath)
        guard let cell = cellDequeued as? (UITableViewCell & DPAGContactCellProtocol) else { return cellDequeued }
        let index = indexPath.row
        let contact = self.blockedContacts[index]
        let btn = UIButton(type: .system)
        btn.accessibilityIdentifier = "btn_unblock"
        btn.setTitle(DPAGLocalizedString("contacts.button.unblockContactShort"), for: .normal)
        btn.sizeToFit()
        cell.accessoryView = btn
        cell.accessoryView?.tag = index
        btn.addTarget(self, action: #selector(handleUnblockContact(_:)), for: .touchUpInside)
        cell.update(contact: contact)
        cell.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)"
        return cell
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        1
    }
}

extension DPAGBlockedContactsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
    }
}
