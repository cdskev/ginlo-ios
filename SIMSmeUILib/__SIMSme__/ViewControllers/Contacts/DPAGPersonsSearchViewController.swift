//
//  DPAGPersonSearchViewController.swift
// ginlo
//
//  Created by RBU on 06/01/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGPersonsSearchResultsViewController: DPAGSearchResultsViewController, DPAGPersonsSearchResultsViewControllerProtocol {
    private static let CellContactIdentifier = "cellContactIdentifier"

    var personsSearched: [DPAGPerson] = []

    private weak var searchDelegate: DPAGPersonsSearchViewControllerDelegate?

    init(delegate: DPAGPersonsSearchViewControllerDelegate) {
        self.searchDelegate = delegate

        super.init(style: .plain)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.tableView.register(DPAGApplicationFacadeUIContacts.cellPersonNib(), forCellReuseIdentifier: DPAGPersonsSearchResultsViewController.CellContactIdentifier)
    }
}

extension DPAGPersonsSearchResultsViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        self.personsSearched.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellDequeued = tableView.dequeueReusableCell(withIdentifier: DPAGPersonsSearchResultsViewController.CellContactIdentifier, for: indexPath)
        cellDequeued.accessibilityIdentifier = "cell_\(indexPath.section)_\(indexPath.row)"
        guard let cell = cellDequeued as? (UITableViewCell & DPAGPersonCellProtocol) else { return cellDequeued }
        let person = self.personsSearched[indexPath.row]
        cell.update(person: person)
        cell.update(searchBarText: self.searchBarText)
        return cell
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        1
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
}

extension DPAGPersonsSearchResultsViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let person = self.personsSearched[indexPath.row]

        self.searchDelegate?.didSelect(person: person)
    }
}
