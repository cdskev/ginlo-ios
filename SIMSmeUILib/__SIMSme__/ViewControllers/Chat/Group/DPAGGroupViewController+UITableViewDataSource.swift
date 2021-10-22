//
//  DPAGGroupViewController+UITableViewDataSource.swift
// ginlo
//
//  Created by iso on 2021-01-19
//  Copyright © 2021 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import MobileCoreServices
import Photos
import SIMSmeCore
import UIKit

extension DPAGGroupViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection _: Int) -> Int {
        if self.tableViewAdmins == tableView {
            self.constraintTableViewAdminsHeight.constant = (CGFloat(self.admins.count) * DPAGConstantsGlobal.kContactCellHeight)
            return self.admins.count
        }
        if self.tableViewMember == tableView {
            self.constraintTableViewMemberHeight.constant = (CGFloat(self.members.count) * DPAGConstantsGlobal.kContactCellHeight)
            return self.members.count
        }
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if self.tableViewMember == tableView {
            if let cell = tableView.dequeueReusableCell(withIdentifier: DPAGGroupViewController.MemberCellIdentifier, for: indexPath) as? (UITableViewCell & DPAGContactCellProtocol) {
                let contact = self.membersSorted[indexPath.row]
                cell.update(contact: contact)
                cell.accessibilityIdentifier = "member-\(contact.phoneNumber ?? "-")"
                return cell
            }
        }
        if self.tableViewAdmins == tableView {
            if let cell = tableView.dequeueReusableCell(withIdentifier: DPAGGroupViewController.AdminCellIdentifier, for: indexPath) as? (UITableViewCell & DPAGContactCellProtocol) {
                let contact = self.adminsSorted[indexPath.row]
                cell.update(contact: contact)
                cell.accessibilityIdentifier = "admin-\(contact.phoneNumber ?? "-")"
                return cell
            }
        }

        let cell = UITableViewCell()
        return cell
    }
}
