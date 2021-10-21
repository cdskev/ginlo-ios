//
//  DPAGFileSearchViewController.swift
// ginlo
//
//  Created by RBU on 03/03/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGMediaOverviewSearchResultsViewController: DPAGSearchResultsViewController, DPAGMediaOverviewSearchResultsViewControllerProtocol {
    private static let CellIdentifier = "CellIdentifier"
    var mediasSearched: [DPAGMediaViewAttachmentProtocol] = []
    private weak var searchDelegate: DPAGMediaOverviewSearchResultsViewControllerDelegate?

    init(delegate: DPAGMediaOverviewSearchResultsViewControllerDelegate) {
        self.searchDelegate = delegate
        super.init(style: .plain)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.estimatedRowHeight = 60
        self.tableView.register(DPAGApplicationFacadeUIMedia.cellMediaFileNib(), forCellReuseIdentifier: DPAGMediaOverviewSearchResultsViewController.CellIdentifier)
    }
}

extension DPAGMediaOverviewSearchResultsViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        self.mediasSearched.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellDequeued = tableView.dequeueReusableCell(withIdentifier: DPAGMediaOverviewSearchResultsViewController.CellIdentifier, for: indexPath)
        cellDequeued.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)"
        guard let cell = cellDequeued as? (UITableViewCell & DPAGMediaFileTableViewCellProtocol) else { return cellDequeued }
        if let decryptedAttachment = self.mediasSearched[indexPath.row].decryptedAttachment {
            self.searchDelegate?.setupCell(cell, with: decryptedAttachment)
        }
        cell.update(withSearchBarText: self.searchBarText)
        return cell
    }
}

extension DPAGMediaOverviewSearchResultsViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        1
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let fileAttachment = self.mediasSearched[indexPath.row]
        self.searchDelegate?.didSelectMedia(fileAttachment)
    }
}
