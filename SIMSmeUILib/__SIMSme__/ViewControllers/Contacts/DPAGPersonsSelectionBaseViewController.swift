//
//  DPAGPersonsSelectionBaseViewController.swift
//  SIMSme
//
//  Created by RBU on 16.12.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGPersonsSelectionBaseViewController: DPAGObjectsSelectionBaseViewController<DPAGPerson>, UITableViewDataSource, UITableViewDelegate {
    private static let cellPersonIdentifier = "cellPersonIdentifier"

    let personsSelected: DPAGSearchListSelection<DPAGPerson> = DPAGSearchListSelection<DPAGPerson>()

    init() {
        super.init(objectsSelected: self.personsSelected)
    }

    override func configureTableView() {
        super.configureTableView()

        self.tableView.register(DPAGApplicationFacadeUIContacts.cellPersonNib(), forCellReuseIdentifier: DPAGPersonsSelectionBaseViewController.cellPersonIdentifier)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellDequeued = tableView.dequeueReusableCell(withIdentifier: DPAGPersonsSelectionBaseViewController.cellPersonIdentifier, for: indexPath)

        guard let cell = cellDequeued as? (UITableViewCell & DPAGPersonCellProtocol) else { return cellDequeued }

        let person = self.objectForTableView(tableView, indexPath: indexPath)

        self.configureCell(cell, withPerson: person)

        cell.accessibilityIdentifier = "person-\(indexPath.section)-\(indexPath.row)"

        return cell
    }

    func configureCell(_ cell: UITableViewCell & DPAGPersonCellProtocol, withPerson person: DPAGPerson?) {
        cell.update(person: person)

        if let person = person, self.personsSelected.contains(person) {
            let imageView = UIImageView(frame: CGRect(origin: .zero, size: CGSize(width: 20, height: 20)))

            imageView.configureCheck()

            cell.accessoryView = imageView
            cell.selectionStyle = self.personsSelected.containsFixed(person) ? .none : .default
        } else {
            cell.accessoryView = nil
            cell.selectionStyle = .default
        }
    }

    override func filterContent(searchText: String, completion: @escaping DPAGCompletion) {
        _ = self.model?.filter(by: searchText)

        self.performBlockOnMainThread { [weak self] in
            (self?.searchResultsController as? DPAGPersonsSearchResultsViewControllerProtocol)?.personsSearched = self?.model?.objectsFiltered ?? []
            completion()
        }
    }
}
