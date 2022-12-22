//
//  DPAGPersonSelectionViewController.swift
// ginlo
//
//  Created by RBU on 05/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGPersonsSelectionViewController: DPAGPersonsSelectionBaseViewController, DPAGPersonsSearchViewControllerDelegate {
    weak var delegateSelection: DPAGPersonsSelectionDelegate?

    override init() {
        super.init()

        self.options = [.EnableGroupedStyle]
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func createModel() {
        let personArray = DPAGApplicationFacade.contactsWorker.allAddressBookPersons()

        self.model = DPAGSearchListModel(objects: personArray)
    }

    override func configureSearchBar() {
        self.configureSearchBarWithResultsController(DPAGApplicationFacadeUIContacts.personSearchResultsVC(delegate: self), placeholder: "android.serach.placeholder")
    }

    override func didSelect(objects: Set<DPAGPerson>) {
        if let searchController = self.searchController, searchController.isActive {
            searchController.dismiss(animated: true) { [weak self] in
                self?.delegateSelection?.didSelect(persons: objects)
            }
        } else {
            self.delegateSelection?.didSelect(persons: objects)
        }
    }

    func didSelect(person: DPAGPerson) {
        self.didSelect(objects: Set([person]))
    }
}
