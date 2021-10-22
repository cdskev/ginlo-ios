//
//  DPAGSettingsAutoDownloadTableViewController.swift
// ginlo
//
//  Created by RBU on 11.04.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGSettingsAutoDownloadTableViewController: DPAGSettingsTableViewControllerBase, DPAGViewControllerNavigationTitleBig {
    private enum Rows: Int, CaseCountable {
        case image, audio, video, file
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = DPAGLocalizedString("settings.autoDownload.title")
        let buttonDefaults = DPAGButtonPrimaryView()
        buttonDefaults.translatesAutoresizingMaskIntoConstraints = false
        self.addBottomView(buttonDefaults)
        buttonDefaults.button.setTitle(DPAGLocalizedString("settings.backup.delautDownloadSetting.title"), for: .normal)
        buttonDefaults.button.addTarget(self, action: #selector(setAutoDownloadSettingsToDefault), for: .touchUpInside)
    }

    @objc
    private func setAutoDownloadSettingsToDefault() {
        let wLanMobile: DPAGSettingAutoDownload = .wifiAndMobile
        let wLan: DPAGSettingAutoDownload = .wifi
        DPAGApplicationFacade.preferences.autoDownloadSettingFoto = wLanMobile
        DPAGApplicationFacade.preferences.autoDownloadSettingAudio = wLan
        DPAGApplicationFacade.preferences.autoDownloadSettingVideo = wLan
        DPAGApplicationFacade.preferences.autoDownloadSettingFile = wLan
        self.tableView.reloadData()
    }
}

extension DPAGSettingsAutoDownloadTableViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        Rows.caseCount
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell?
        switch Rows.forIndex(indexPath.row) {
            case .image:
                cell = self.cellForDisclosureRow(indexPath)
                cell?.textLabel?.text = DPAGLocalizedString("settings.backup.foto.title")
                let settingValue = DPAGApplicationFacade.preferences.autoDownloadSettingFoto
                let settingTitle = "settings.backup.title.downloadChoice\(settingValue.rawValue)"
                cell?.detailTextLabel?.text = DPAGLocalizedString(settingTitle) + " "
            case .audio:
                cell = self.cellForDisclosureRow(indexPath)
                cell?.textLabel?.text = DPAGLocalizedString("settings.backup.audio.title")
                let settingValue = DPAGApplicationFacade.preferences.autoDownloadSettingAudio
                let settingTitle = "settings.backup.title.downloadChoice\(settingValue.rawValue)"
                cell?.detailTextLabel?.text = DPAGLocalizedString(settingTitle) + " "
            case .video:
                cell = self.cellForDisclosureRow(indexPath)
                cell?.textLabel?.text = DPAGLocalizedString("settings.backup.video.title")
                let settingValue = DPAGApplicationFacade.preferences.autoDownloadSettingVideo
                let settingTitle = "settings.backup.title.downloadChoice\(settingValue.rawValue)"
                cell?.detailTextLabel?.text = DPAGLocalizedString(settingTitle) + " "
            case .file:
                cell = self.cellForDisclosureRow(indexPath)
                cell?.textLabel?.text = DPAGLocalizedString("settings.backup.file.title")
                let settingValue = DPAGApplicationFacade.preferences.autoDownloadSettingFile
                let settingTitle = "settings.backup.title.downloadChoice\(settingValue.rawValue)"
                cell?.detailTextLabel?.text = DPAGLocalizedString(settingTitle) + " "
        }
        cell?.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)"
        cell?.backgroundColor = DPAGColorProvider.shared[.settingsBackground]
        return cell ?? self.cellForDefaultRow(indexPath) ?? UITableViewCell(style: .default, reuseIdentifier: "???")
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        60
    }
}

extension DPAGSettingsAutoDownloadTableViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Rows.forIndex(indexPath.row) {
            case .image:
                tableViewDidSelectImageRow()
            case .audio:
                tableViewDidSelectAudioRow()
            case .video:
                tableViewDidSelectVideoRow()
            case .file:
                tableViewDidSelectFileRow()
        }
    }
    
    private func tableViewDidSelectImageRow() {
        let actionSheet = DPAGSettingsOptionSelectViewController(style: .grouped)
        actionSheet.title = DPAGLocalizedString("settings.backup.foto.title")
        actionSheet.headerText = DPAGLocalizedString("settings.backup.autodownload.select")
        actionSheet.accessibilityIdentifier = "action_set_AutoDownload_Settings_For_Photo"
        var options: [DPAGSettingsOptionSelectOption] = []
        var optionSelected: DPAGSettingsOptionSelectOption?
        var optionDefault: DPAGSettingsOptionSelectOption?
        for qualityValue in DPAGSettingAutoDownload.allCases {
            let qualityTitle = String(format: "settings.backup.title.downloadChoice%@", String(qualityValue.rawValue))
            let qualityTitleLocalized = DPAGLocalizedString(qualityTitle)
            let option = DPAGSettingsOptionSelectOption(titleIdentifier: qualityTitleLocalized, action: { [weak self] in
                DPAGApplicationFacade.preferences.autoDownloadSettingFoto = qualityValue
                self?.tableView.reloadData()
            })
            options.append(option)
            if qualityValue == DPAGApplicationFacade.preferences.autoDownloadSettingFoto {
                optionSelected = option
            }
            if qualityValue == DPAGApplicationFacade.preferences.defaultAutoDownloadSettingFoto {
                optionDefault = option
            }
        }
        actionSheet.options = options
        actionSheet.optionPreSelected = optionSelected
        actionSheet.optionDefault = optionDefault
        actionSheet.optionReset = DPAGSettingsOptionSelectOption(titleIdentifier: "settings.backup.delautDownloadSetting.title", action: { [weak self] in
            DPAGApplicationFacade.preferences.resetAutoDownloadSettingFoto()
            self?.tableView.reloadData()
        })
        self.navigationController?.pushViewController(actionSheet, animated: true)

    }
    
    private func tableViewDidSelectAudioRow() {
        let actionSheet = DPAGSettingsOptionSelectViewController(style: .grouped)
        actionSheet.title = DPAGLocalizedString("settings.backup.audio.title")
        actionSheet.headerText = DPAGLocalizedString("settings.backup.autodownload.select")
        actionSheet.accessibilityIdentifier = "action_set_AutoDownload_Settings_For_Audio"
        var options: [DPAGSettingsOptionSelectOption] = []
        var optionSelected: DPAGSettingsOptionSelectOption?
        var optionDefault: DPAGSettingsOptionSelectOption?
        for qualityValue in DPAGSettingAutoDownload.allCases {
            let qualityTitle = String(format: "settings.backup.title.downloadChoice%@", String(qualityValue.rawValue))
            let qualityTitleLocalized = DPAGLocalizedString(qualityTitle)
            let option = DPAGSettingsOptionSelectOption(titleIdentifier: qualityTitleLocalized, action: { [weak self] in
                DPAGApplicationFacade.preferences.autoDownloadSettingAudio = qualityValue
                self?.tableView.reloadData()
            })
            options.append(option)
            if qualityValue == DPAGApplicationFacade.preferences.autoDownloadSettingAudio {
                optionSelected = option
            }
            if qualityValue == DPAGApplicationFacade.preferences.defaultAutoDownloadSettingAudio {
                optionDefault = option
            }
        }
        actionSheet.options = options
        actionSheet.optionPreSelected = optionSelected
        actionSheet.optionDefault = optionDefault
        actionSheet.optionReset = DPAGSettingsOptionSelectOption(titleIdentifier: "settings.backup.delautDownloadSetting.title", action: { [weak self] in
            DPAGApplicationFacade.preferences.resetAutoDownloadSettingAudio()
            self?.tableView.reloadData()
        })
        self.navigationController?.pushViewController(actionSheet, animated: true)
    }
    
    private func tableViewDidSelectVideoRow() {
        let actionSheet = DPAGSettingsOptionSelectViewController(style: .grouped)
        actionSheet.title = DPAGLocalizedString("settings.backup.video.title")
        actionSheet.headerText = DPAGLocalizedString("settings.backup.autodownload.select")
        actionSheet.accessibilityIdentifier = "action_set_AutoDownload_Settings_For_Video"
        var options: [DPAGSettingsOptionSelectOption] = []
        var optionSelected: DPAGSettingsOptionSelectOption?
        var optionDefault: DPAGSettingsOptionSelectOption?
        for qualityValue in DPAGSettingAutoDownload.allCases {
            let qualityTitle = String(format: "settings.backup.title.downloadChoice%@", String(qualityValue.rawValue))
            let qualityTitleLocalized = DPAGLocalizedString(qualityTitle)
            let option = DPAGSettingsOptionSelectOption(titleIdentifier: qualityTitleLocalized, action: { [weak self] in
                DPAGApplicationFacade.preferences.autoDownloadSettingVideo = qualityValue
                self?.tableView.reloadData()
            })
            options.append(option)
            if qualityValue == DPAGApplicationFacade.preferences.autoDownloadSettingVideo {
                optionSelected = option
            }
            if qualityValue == DPAGApplicationFacade.preferences.defaultAutoDownloadSettingVideo {
                optionDefault = option
            }
        }
        actionSheet.options = options
        actionSheet.optionPreSelected = optionSelected
        actionSheet.optionDefault = optionDefault
        actionSheet.optionReset = DPAGSettingsOptionSelectOption(titleIdentifier: "settings.backup.delautDownloadSetting.title", action: { [weak self] in
            DPAGApplicationFacade.preferences.resetAutoDownloadSettingVideo()
            self?.tableView.reloadData()
        })
        self.navigationController?.pushViewController(actionSheet, animated: true)
    }
    
    private func tableViewDidSelectFileRow() {
        let actionSheet = DPAGSettingsOptionSelectViewController(style: .grouped)
        actionSheet.title = DPAGLocalizedString("settings.backup.video.title")
        actionSheet.headerText = DPAGLocalizedString("settings.backup.autodownload.select")
        actionSheet.accessibilityIdentifier = "action_set_AutoDownload_Settings_For_File"
        var options: [DPAGSettingsOptionSelectOption] = []
        var optionSelected: DPAGSettingsOptionSelectOption?
        var optionDefault: DPAGSettingsOptionSelectOption?
        for qualityValue in DPAGSettingAutoDownload.allCases {
            let qualityTitle = String(format: "settings.backup.title.downloadChoice%@", String(qualityValue.rawValue))
            let qualityTitleLocalized = DPAGLocalizedString(qualityTitle)
            let option = DPAGSettingsOptionSelectOption(titleIdentifier: qualityTitleLocalized, action: { [weak self] in
                DPAGApplicationFacade.preferences.autoDownloadSettingFile = qualityValue
                self?.tableView.reloadData()
            })
            options.append(option)
            if qualityValue == DPAGApplicationFacade.preferences.autoDownloadSettingFile {
                optionSelected = option
            }
            if qualityValue == DPAGApplicationFacade.preferences.defaultAutoDownloadSettingFile {
                optionDefault = option
            }
        }
        actionSheet.options = options
        actionSheet.optionPreSelected = optionSelected
        actionSheet.optionDefault = optionDefault
        actionSheet.optionReset = DPAGSettingsOptionSelectOption(titleIdentifier: "settings.backup.delautDownloadSetting.title", action: { [weak self] in
            DPAGApplicationFacade.preferences.resetAutoDownloadSettingFile()
            self?.tableView.reloadData()
        })
        self.navigationController?.pushViewController(actionSheet, animated: true)
    }
}
