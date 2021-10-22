//
//  DPAGChannelCategoryViewController.swift
// ginlo
//
//  Created by RBU on 18/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGChannelCategorySelectionDelegate: AnyObject {
    func didSelectChannelCategory(_ channelCategory: DPAGChannelCategory?)
}

protocol DPAGChannelCategoriesViewControllerProtocol: AnyObject {
    var channelCategories: [DPAGChannelCategory] { get set }
    var selectionDelegate: DPAGChannelCategorySelectionDelegate? { get set }
    var indexPathSelectedRow: IndexPath { get set }
}

class DPAGChannelCategoryViewController: DPAGTableViewControllerBackground, DPAGChannelCategoriesViewControllerProtocol {
    private static let NavigationDrawerCellIdentifier = "NavigationDrawerCellIdentifier"

    override func configureTableView() {
        super.configureTableView()
        self.tableView.sectionHeaderHeight = 0.0
        self.tableView.sectionFooterHeight = 0.0
        self.tableView.separatorStyle = .none
        self.tableView.allowsSelection = true
        self.tableView?.register(UITableViewCell.self, forCellReuseIdentifier: DPAGChannelCategoryViewController.NavigationDrawerCellIdentifier)
    }

    var channelCategories: [DPAGChannelCategory] = []
    weak var selectionDelegate: DPAGChannelCategorySelectionDelegate?
    var indexPathSelectedRow: IndexPath = IndexPath(row: 0, section: 0)

    init() {
        super.init(style: .grouped)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = DPAGLocalizedString("channel.categories.title.categories")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
}

extension DPAGChannelCategoryViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        self.channelCategories.count + 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DPAGChannelCategoryViewController.NavigationDrawerCellIdentifier, for: indexPath)
        if indexPath.row == 0 {
            cell.accessibilityIdentifier = "channel.categories.menu.title.all"
            cell.textLabel?.text = DPAGLocalizedString("channel.categories.menu.title.all")
            cell.imageView?.image = DPAGImageProvider.shared[.kImageChannelCategoriesAll]
        } else {
            let category = self.channelCategories[indexPath.row - 1]
            let titleKey = "channel.categories.menu.title." + (category.titleKey ?? "")
            cell.accessibilityIdentifier = titleKey
            cell.textLabel?.text = DPAGLocalizedString(titleKey)
            let imageKey = "channel.categories.menu.image." + (category.imageKey ?? "")
            cell.imageView?.image = DPAGImageProvider.shared[DPAGLocalizedString(imageKey)]
        }
        cell.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        cell.imageView?.tintColor = DPAGColorProvider.shared[.labelText]
        cell.textLabel?.textColor = DPAGColorProvider.shared[.labelText]
        if indexPath.row == self.indexPathSelectedRow.row {
            let imageView = UIImageView(frame: CGRect(origin: .zero, size: CGSize(width: 20, height: 20)))
            imageView.configureCheck()
            cell.accessoryView = imageView
        } else {
            cell.accessoryView = nil
        }
        cell.selectionStyle = .none
        return cell
    }
}

extension DPAGChannelCategoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
            case 0:
                self.selectionDelegate?.didSelectChannelCategory(nil)
            default:
                let category = self.channelCategories[indexPath.row - 1]
                self.selectionDelegate?.didSelectChannelCategory(category)
        }
        let idxOldSelectedRow = self.indexPathSelectedRow
        self.indexPathSelectedRow = indexPath
        if idxOldSelectedRow.row != indexPath.row {
            tableView.beginUpdates()
            tableView.reloadRows(at: [idxOldSelectedRow, indexPath], with: .automatic)
            tableView.endUpdates()
        } else {
            tableView.beginUpdates()
            tableView.reloadRows(at: [indexPath], with: .automatic)
            tableView.endUpdates()
        }
        self.navigationController?.popViewController(animated: true)
    }
}
