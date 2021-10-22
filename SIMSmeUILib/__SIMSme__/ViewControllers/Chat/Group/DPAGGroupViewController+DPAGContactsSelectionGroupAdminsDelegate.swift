//
//  DPAGGroupViewController+DPAGContactsSelectionGroupAdminsDelegate.swift
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

extension DPAGGroupViewController: DPAGContactsSelectionGroupAdminsDelegate {
    func addAdmins(_ admins: Set<DPAGContact>) {
        self.members = self.members.union(self.admins).subtracting(admins)
        self.admins = admins
        self.adminsSorted = self.admins.sorted { (c1, c2) -> Bool in
            c1.isBeforeInSearch(c2)
        }
        self.membersSorted = self.members.sorted { (c1, c2) -> Bool in
            c1.isBeforeInSearch(c2)
        }
        self.navigationController?.popToViewController(self, animated: true)
        self.tableViewMember.reloadData()
        self.tableViewAdmins.reloadData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let strongSelf = self, let superview = strongSelf.tableViewAdmins.superview else { return }
            strongSelf.scrollView.scrollRectToVisible(superview.frame, animated: true)
        }
        self.performBlockInBackground { [weak self] in
            Thread.sleep(forTimeInterval: 0.5)
            self?.performBlockOnMainThread { [weak self] in
                self?.highlightRightButton(true)
            }
        }
    }
}
