//
//  DPAGBackupViewController.swift
// ginlo
//
//  Created by RBU on 20/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGBackupViewControllerProtocol: AnyObject {
    var automaticStartBackup: Bool { get set }
}

class DPAGBackupViewController: DPAGSettingsTableViewControllerBase, DPAGBackupViewControllerProtocol {
    private enum Rows: Int, CaseCountable {
        case create,
            password,
            interval,
            media
    }

    var automaticStartBackup = false

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = DPAGLocalizedString("settings.backup")

        self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
    }

    override func configureTableView() {
        super.configureTableView()

        self.tableView.sectionHeaderHeight = UITableView.automaticDimension
        self.tableView.sectionFooterHeight = UITableView.automaticDimension

        self.tableView.register(DPAGApplicationFacadeUISettings.cellBackupCreateNib(), forCellReuseIdentifier: "header")
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.tableView.reloadData()

        self.foregroundObserver = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Application.WILL_ENTER_FOREGROUND, object: nil, queue: .main, using: { [weak self] _ in

            self?.tableView.reloadData()
        })

        self.performBlockInBackground {
            do {
                try DPAGApplicationFacade.backupWorker.ensureBackupToken()
            } catch {
                DPAGLog(error)
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if self.automaticStartBackup {
            self.automaticStartBackup = false
            self.handleCreateBackup()
        }
    }

    private weak var sharedInstanceProgress: DPAGProgressHUDWithProgressProtocol?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        self.sharedInstanceProgress?.statusBarStyle ?? super.preferredStatusBarStyle
    }

    @objc
    private func handleToggleMedia() {
        let isSaveMedia = DPAGApplicationFacade.preferences.backupSaveMedia()
        DPAGApplicationFacade.preferences.setBackupSaveMedia(!isSaveMedia)
    }
}

extension DPAGBackupViewController: DPAGBackupCreateTableViewCellDelegate {
    func handleCloudEnableInfo() {
        let nextVC = DPAGApplicationFacadeUISettings.backupCloudInfoVC()

        self.navigationController?.pushViewController(nextVC, animated: true)
    }

    func handleCreateBackup() {
        if ((try? DPAGApplicationFacade.backupWorker.isICloudEnabled()) ?? false) == false {
            return
        }
        if !DPAGApplicationFacade.backupWorker.loadKeyConfig() {
            let nextVC = DPAGApplicationFacadeUISettings.backupPasswordVC()

            self.navigationController?.pushViewController(nextVC, animated: true)

            return
        }

        self.sharedInstanceProgress = DPAGProgressHUDWithProgress.sharedInstanceProgress.showForBackgroundProcess(true, completion: { [weak self] alertInstance in

            self?.performBlockOnMainThread { [weak self] in
                self?.setNeedsStatusBarAppearanceUpdate()
            }

            let rc = DPAGApplicationFacade.backupWorker.makeBackup(hudWithLabels: alertInstance as? DPAGProgressHUDWithProgressDelegate)

            self?.performBlockOnMainThread { [weak self] in
                self?.tableView.reloadData()
            }

            if rc {
                DPAGProgressHUDWithProgress.sharedInstanceProgress.hide(true) { [weak self] in
                    self?.sharedInstanceProgress = nil
                    self?.setNeedsStatusBarAppearanceUpdate()
                }
            } else {
                DPAGProgressHUDWithProgress.sharedInstanceProgress.hide(true, completion: { [weak self] in
                    self?.sharedInstanceProgress = nil
                    self?.setNeedsStatusBarAppearanceUpdate()
                    self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "backup.backup.exportfailed"))
                })
            }
        }, delegate: self) as? DPAGProgressHUDWithProgressProtocol
    }
}

extension DPAGBackupViewController: DPAGProgressHUDDelegate {
    func setupHUD(_ hud: DPAGProgressHUDProtocol) {
        if let hudWithLabels = hud as? DPAGProgressHUDWithProgressProtocol {
            hudWithLabels.labelTitle.text = DPAGLocalizedString("backup.backup.title")
            hudWithLabels.labelDescription.text = ""
            hudWithLabels.viewProgress.progress = 0
        }
    }
}

extension DPAGBackupViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        Rows.caseCount
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell?
        switch Rows.forIndex(indexPath.row) {
            case .create:
                cell = tableView.dequeueReusableCell(withIdentifier: "header", for: indexPath)
                if let cellCreate = cell as? DPAGBackupCreateTableViewCellProtocol {
                    cellCreate.delegate = self
                    cellCreate.configure()
                }
            case .password:
                cell = self.cellForDisclosureRow(indexPath)
                cell?.textLabel?.text = DPAGLocalizedString("settings.backup.passwordCell.label")
            case .interval:
                cell = self.cellForDisclosureRow(indexPath)
                cell?.textLabel?.text = DPAGLocalizedString("settings.backup.intervallCell.label")
                switch DPAGBackupIntervalViewController.Rows.forIndex((DPAGApplicationFacade.preferences.backupInterval ?? .disabled).rawValue) {
                    case .daily:
                        cell?.detailTextLabel?.text = DPAGLocalizedString("settings.backup.interval.daily.label")
                    case .weekly:
                        cell?.detailTextLabel?.text = DPAGLocalizedString("settings.backup.interval.weekly.label")
                    case .monthly:
                        cell?.detailTextLabel?.text = DPAGLocalizedString("settings.backup.interval.monthly.label")
                    case .disabled:
                        cell?.detailTextLabel?.text = DPAGLocalizedString("settings.backup.interval.disabled.label")
                }
            case .media:
                cell = self.cellForSwitchRow(indexPath)
                cell?.textLabel?.text = DPAGLocalizedString("settings.backup.mediaCell.label")
                if let cellSwitch = cell as? (UITableViewCell & DPAGSwitchTableViewCellProtocol) {
                    cellSwitch.aSwitch?.addTarget(self, action: #selector(handleToggleMedia), for: .valueChanged)
                    let isSaveMedia = DPAGApplicationFacade.preferences.backupSaveMedia()
                    cellSwitch.aSwitch?.setOn(isSaveMedia, animated: false)
                    cellSwitch.aSwitch?.isEnabled = true
                    cellSwitch.aSwitch?.accessibilityIdentifier = "settings.backup.mediaSwitch"
                }
        }
        cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)"
        return cell ?? self.cellForHiddenRow(indexPath)
    }

    func tableView(_: UITableView, titleForFooterInSection _: Int) -> String? {
        DPAGLocalizedString("settings.backup.footer.label")
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        UITableView.automaticDimension
    }
}

extension DPAGBackupViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch Rows.forIndex(indexPath.row) {
        case .create:
            break

        case .password:
            let nextVC = DPAGApplicationFacadeUISettings.backupPasswordVC()

            self.navigationController?.pushViewController(nextVC, animated: true)

        case .interval:
            let nextVC = DPAGApplicationFacadeUISettings.backupIntervalVC()

            self.navigationController?.pushViewController(nextVC, animated: true)

        case .media:
            break
        }
    }
}
