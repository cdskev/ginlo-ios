//
//  DPAGSelectGroupChatAdminsViewController.swift
//  SIMSme
//
//  Created by RBU on 26/10/2016.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGContactsSelectionGroupAdminsViewControllerProtocol: DPAGContactsSelectionBaseViewControllerProtocol {
    var adminSelectionDelegate: DPAGContactsSelectionGroupAdminsDelegate? { get set }
}

class DPAGContactsSelectionGroupAdminsViewController: DPAGContactsSelectionViewController, DPAGContactsSelectionGroupAdminsViewControllerProtocol {
    weak var adminSelectionDelegate: DPAGContactsSelectionGroupAdminsDelegate?
    private var members: Set<DPAGContact>
    private var admins: Set<DPAGContact>
    private var adminsFixed: Set<DPAGContact>

    init(members: Set<DPAGContact>, admins: Set<DPAGContact>, adminsFixed: Set<DPAGContact>, delegate selectionDelegate: DPAGContactsSelectionGroupAdminsDelegate) {
        self.members = members
        self.admins = admins
        self.adminsFixed = adminsFixed
        self.adminSelectionDelegate = selectionDelegate

        let contactsSelected = DPAGSearchListSelection<DPAGContact>()

        contactsSelected.appendSelected(contentsOf: admins)
        contactsSelected.appendSelectedFixed(contentsOf: adminsFixed)

        super.init(contactsSelected: contactsSelected, showInviteAction: false)

        self.options = [.EnableEmptySelection, .EnableMultiSelection]
    }

    override func configureSearchBar() {}

    override func didSelect(objects: Set<DPAGContact>) {
        self.adminSelectionDelegate?.addAdmins(objects)
    }

    override func createModel() {
        let personArray = self.members

        self.model = DPAGSearchListModel(objects: personArray)
    }

    override func updateTableHeader() {}
}
