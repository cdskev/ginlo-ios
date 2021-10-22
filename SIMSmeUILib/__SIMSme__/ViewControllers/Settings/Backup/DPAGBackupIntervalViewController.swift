//
//  DPAGBackupIntervalViewController.swift
// ginlo
//
//  Created by RBU on 23/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGBackupIntervalViewController: DPAGSettingsTableViewControllerBase {
    enum Rows: Int, CaseCountable {
        case daily,
            weekly,
            monthly,
            disabled
    }

    private var intervalSetting = DPAGApplicationFacade.preferences.backupInterval ?? .daily

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.navigationItem.title = DPAGLocalizedString("settings.backup.interval.title")

        self.tableView.sectionFooterHeight = UITableView.automaticDimension
    }
}

extension DPAGBackupIntervalViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        Rows.caseCount
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.cellForDefaultRow(indexPath)

        switch Rows.forIndex(indexPath.row) {
        case .daily:

            cell?.textLabel?.text = DPAGLocalizedString("settings.backup.interval.daily.label")
            cell?.textLabel?.accessibilityIdentifier = "settings.backup.interval.daily.label"
            cell?.accessoryType = self.intervalSetting == .daily ? .checkmark : .none

        case .weekly:

            cell?.textLabel?.text = DPAGLocalizedString("settings.backup.interval.weekly.label")
            cell?.textLabel?.accessibilityIdentifier = "settings.backup.interval.weekly.label"
            cell?.accessoryType = self.intervalSetting == .weekly ? .checkmark : .none

        case .monthly:

            cell?.textLabel?.text = DPAGLocalizedString("settings.backup.interval.monthly.label")
            cell?.textLabel?.accessibilityIdentifier = "settings.backup.interval.monthly.label"
            cell?.accessoryType = self.intervalSetting == .monthly ? .checkmark : .none

        case .disabled:

            cell?.textLabel?.text = DPAGLocalizedString("settings.backup.interval.disabled.label")
            cell?.textLabel?.accessibilityIdentifier = "settings.backup.interval.disabled.label"
            cell?.accessoryType = self.intervalSetting == .disabled ? .checkmark : .none
        }

        cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)"

        return cell ?? self.cellForHiddenRow(indexPath)
    }

    func tableView(_: UITableView, titleForFooterInSection _: Int) -> String? {
        DPAGLocalizedString("settings.backup.footer.label")
    }
}

extension DPAGBackupIntervalViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 {
            let interval = self.rowToInterval(indexPath.row)

            self.intervalSetting = interval

            DPAGApplicationFacade.preferences.backupInterval = self.intervalSetting

            self.tableView.reloadData()
        }
    }

    private func rowToInterval(_ row: Int) -> DPAGBackupInterval {
        switch Rows.forIndex(row) {
        case .daily:
            return .daily
        case .weekly:
            return .weekly
        case .monthly:
            return .monthly
        case .disabled:
            return .disabled
        }
    }
}
