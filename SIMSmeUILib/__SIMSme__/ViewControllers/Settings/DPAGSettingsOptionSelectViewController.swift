//
//  DPAGSettingsOptionSelectViewController.swift
//  SIMSme
//
//  Created by RBU on 17.04.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

struct DPAGSettingsOptionSelectOption: Equatable {
    static func == (lhs: DPAGSettingsOptionSelectOption, rhs: DPAGSettingsOptionSelectOption) -> Bool {
        lhs.titleIdentifier == rhs.titleIdentifier
    }

    var titleIdentifier: String
    var action: () -> Void
    var accessibilityIdentifier: String?

    init(titleIdentifier: String, action: @escaping () -> Void, accessibilityIdentifier: String? = nil) {
        self.titleIdentifier = titleIdentifier
        self.action = action
        self.accessibilityIdentifier = accessibilityIdentifier
    }
}

class DPAGSettingsOptionSelectViewController: DPAGTableViewControllerBackground {
    private static let CellIdentifier = "CellIdentifier"

    var options: [DPAGSettingsOptionSelectOption] = []
    var headerText: String = ""
    private var selectedIndex = -1
    var optionPreSelected: DPAGSettingsOptionSelectOption?
    var optionDefault: DPAGSettingsOptionSelectOption?
    var accessibilityIdentifier: String?

    var optionReset: DPAGSettingsOptionSelectOption?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: DPAGSettingsOptionSelectViewController.CellIdentifier)
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.separatorColor = .clear
        self.tableView.separatorStyle = .singleLine
        self.tableView.sectionFooterHeight = 0
        self.tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0.1))
        self.view.accessibilityIdentifier = self.accessibilityIdentifier
        if let optionReset = self.optionReset {
            let buttonDefaults = DPAGButtonPrimaryView()
            buttonDefaults.translatesAutoresizingMaskIntoConstraints = false
            self.addBottomView(buttonDefaults)
            buttonDefaults.button.setTitle(DPAGLocalizedString(optionReset.titleIdentifier), for: .normal)
            buttonDefaults.button.addTarget(self, action: #selector(handleSetDefaultSetting), for: .touchUpInside)
        }

        if let optionPreSelected = self.optionPreSelected, let idx = self.options.firstIndex(of: optionPreSelected) {
            self.selectedIndex = idx
        }
    }

    @objc
    private func handleSetDefaultSetting() {
        self.optionReset?.action()
        if let optionDefault = self.optionDefault {
            self.optionPreSelected = optionDefault
        }
        if let optionPreSelected = self.optionPreSelected, let idx = self.options.firstIndex(of: optionPreSelected) {
            self.selectedIndex = idx
        }
        self.tableView.reloadData()
    }
}

extension DPAGSettingsOptionSelectViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        self.options.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DPAGSettingsOptionSelectViewController.CellIdentifier, for: indexPath)
        let option = self.options[indexPath.row]
        cell.textLabel?.text = DPAGLocalizedString(option.titleIdentifier)
        cell.contentView.backgroundColor = .clear
        if indexPath.row == self.selectedIndex {
            let imageView = UIImageView(frame: CGRect(origin: .zero, size: CGSize(width: 20, height: 20)))
            imageView.configureCheck()
            cell.accessoryView = imageView
        } else {
            cell.accessoryView = nil
        }
        cell.selectionStyle = .none
        cell.accessibilityIdentifier = option.accessibilityIdentifier ?? option.titleIdentifier
        cell.backgroundColor = DPAGColorProvider.shared[.settingsBackground]
        return cell
    }

    func tableView(_: UITableView, titleForHeaderInSection _: Int) -> String? {
        self.headerText
    }
}

extension DPAGSettingsOptionSelectViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        self.headerText.isEmpty ? 0 : UITableView.automaticDimension
    }

    func tableView(_: UITableView, willDisplayHeaderView view: UIView, forSection _: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = DPAGColorProvider.shared[.labelText]
        view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
    }

    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt _: IndexPath) {
        cell.textLabel?.font = UIFont.kFontCallout
        cell.textLabel?.textColor = DPAGColorProvider.shared[.labelText]
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let option = self.options[indexPath.row]
        if self.selectedIndex >= 0 {
            self.tableView.cellForRow(at: IndexPath(row: self.selectedIndex, section: 0))?.accessoryView = nil
        }
        self.selectedIndex = indexPath.row
        let imageView = UIImageView(frame: CGRect(origin: .zero, size: CGSize(width: 20, height: 20)))
        imageView.configureCheck()
        self.tableView.cellForRow(at: IndexPath(row: self.selectedIndex, section: 0))?.accessoryView = imageView
        option.action()
    }
}
