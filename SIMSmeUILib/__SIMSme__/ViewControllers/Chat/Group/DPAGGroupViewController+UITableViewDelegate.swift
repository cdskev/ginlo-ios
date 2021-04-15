//
//  DPAGGroupViewController+UITableViewDelegate.swift
//  SIMSme
//
//  Created by iso on 2021-01-19
//  Copyright © 2021 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import MobileCoreServices
import Photos
import SIMSmeCore
import UIKit

extension DPAGGroupViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if self.isAdmin == false, self.isOwner == false {
            return .none
        }
        if self.tableViewMember == tableView {
            return .delete
        }
        if self.tableViewAdmins == tableView {
            if self.adminsSorted[indexPath.row].guid != self.accountGuid, self.adminsSorted[indexPath.row].guid != self.ownerGuid {
                return .delete
            }
        }
        return .none
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if self.isAdmin == false, self.isOwner == false {
            return nil
        }
        if self.tableViewMember == tableView {
            return [self.rowActionDeleteMember, self.rowActionMoreMember]
        }
        if self.tableViewAdmins == tableView {
            if self.adminsSorted[indexPath.row].guid != self.accountGuid, self.adminsSorted[indexPath.row].guid != self.ownerGuid {
                return [self.rowActionDeleteAdmin]
            }
        }
        return nil
    }

    func tableView(_ tableView: UITableView, commit _: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if self.isAdmin == false, self.isOwner == false {
            return
        }
        tableView.setEditing(false, animated: true)
        tableView.beginUpdates()
        if self.tableViewMember == tableView {
            let removedMember = self.membersSorted.remove(at: indexPath.row)
            self.members.remove(removedMember)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            self.tableViewAdmins.reloadData()
        }
        if self.tableViewAdmins == tableView {
            let newMember = self.adminsSorted.remove(at: indexPath.row)
            self.admins.remove(newMember)
            self.members.insert(newMember)
            self.membersSorted = self.members.sorted { (c1, c2) -> Bool in
                c1.isBeforeInSearch(c2)
            }
            tableView.deleteRows(at: [indexPath], with: .automatic)
            self.tableViewMember.reloadData()
        }
        tableView.endUpdates()
        self.highlightRightButton((self.textFieldGroupName?.text?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) == false)
        self.needsUpdateMembers = true
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.tableViewMember == tableView {
            let contact = self.membersSorted[indexPath.row]
            if contact.guid == self.accountGuid {
                let nextVC = DPAGApplicationFacadeUISettings.profileVC()
                self.navigationController?.pushViewController(nextVC, animated: true)
            } else {
                let nextVC = DPAGApplicationFacadeUIContacts.contactDetailsVC(contact: contact)
                self.navigationController?.pushViewController(nextVC, animated: true)
            }
        }
        if self.tableViewAdmins == tableView {
            let contact = self.adminsSorted[indexPath.row]
            if contact.guid == self.accountGuid {
                let nextVC = DPAGApplicationFacadeUISettings.profileVC()
                self.navigationController?.pushViewController(nextVC, animated: true)
            } else {
                let nextVC = DPAGApplicationFacadeUIContacts.contactDetailsVC(contact: contact)
                self.navigationController?.pushViewController(nextVC, animated: true)
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
