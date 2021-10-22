//
//  DPAGSettingsTableViewController.swift
// ginlo
//
//  Created by RBU on 27/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGSettingsTableViewControllerBase: DPAGTableViewControllerBackground {
    private var areSettingsEnabled: Bool = false

    func checkSettingsEnabledWithCompletion(_ completion: DPAGCompletion?) -> Bool {
        guard self.areSettingsEnabled == false else { return true }
        let block = { [weak self] (success: Bool) in
            if let strongSelf = self, success {
                strongSelf.areSettingsEnabled = true
                completion?()
            }
        }
        DPAGApplicationFacadeUIBase.loginVC.requestPassword(withTouchID: false, completion: block)
        return false
    }

    private static let SettingsCellSwitchIdentifier = "SettingsCellSwitch"
    private static let SettingsCellDisclosureIdentifier = "SettingsCellDisclosure"
    private static let SettingsCellDisclosureSubtitleIdentifier = "SettingsCellDisclosureSubtitle"
    private static let SettingsCellSubtitleIdentifier = "SettingsCellSubtitle"
    private static let SettingsCellDefaultIdentifier = "SettingsCellDefault"
    private static let SettingsCellHiddenIdentifier = "SettingsCellHidden"
    private static let SettingsCellProfileIdentifier = "SettingsProfile"

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.register(DPAGApplicationFacadeUIViews.cellTableViewSwitchNib(), forCellReuseIdentifier: DPAGSettingsTableViewController.SettingsCellSwitchIdentifier)
        self.tableView.register(DPAGApplicationFacadeUIViews.cellTableViewDisclosureNib(), forCellReuseIdentifier: DPAGSettingsTableViewController.SettingsCellDisclosureIdentifier)
        self.tableView.register(DPAGApplicationFacadeUIViews.cellTableViewDisclosureSubtitleNib(), forCellReuseIdentifier: DPAGSettingsTableViewController.SettingsCellDisclosureSubtitleIdentifier)
        self.tableView.register(DPAGApplicationFacadeUIViews.cellTableViewSubtitleNib(), forCellReuseIdentifier: DPAGSettingsTableViewController.SettingsCellSubtitleIdentifier)
        self.tableView.register(DPAGApplicationFacadeUIViews.cellTableViewBaseNib(), forCellReuseIdentifier: DPAGSettingsTableViewController.SettingsCellDefaultIdentifier)
        self.tableView.register(DPAGApplicationFacadeUIViews.cellHiddenNib(), forCellReuseIdentifier: DPAGSettingsTableViewController.SettingsCellHiddenIdentifier)
        self.tableView.register(DPAGApplicationFacadeUIViews.cellProfileNib(), forCellReuseIdentifier: DPAGSettingsTableViewController.SettingsCellProfileIdentifier)
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 44
        self.tableView.separatorStyle = .singleLine
        self.tableView.sectionFooterHeight = 0
        self.tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0.1))
        self.tableView.backgroundColor = DPAGColorProvider.shared[.settingsViewBackground]
        self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
    }

    func cellForProfile(name: String?, image: UIImage?) -> (UITableViewCell & SettingsProfileCellProtocol)? {
        let cell = tableView.dequeueReusableCell(withIdentifier: DPAGSettingsTableViewController.SettingsCellProfileIdentifier) as? (UITableViewCell & SettingsProfileCellProtocol)
        cell?.profileImageView?.image = image
        cell?.profileImageView?.layer.cornerRadius = 32
        cell?.profileImageView?.layer.masksToBounds = true
        cell?.nameLabel.text = name
        cell?.nameLabel.font = .kFontHeadline
        cell?.nameLabel.textColor = DPAGColorProvider.shared[.labelText]
        cell?.accountDetailsLabel.font = .kFontSubheadline
        cell?.accountDetailsLabel.textColor = DPAGColorProvider.shared[.labelText]
        cell?.accountDetailsLabel.text = DPAGLocalizedString("settings.accountDetails")
        return cell
    }
    
    func cellForSwitchRow(_: IndexPath) -> (UITableViewCell & DPAGSwitchTableViewCellProtocol)? {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: DPAGSettingsTableViewController.SettingsCellSwitchIdentifier) as? (UITableViewCell & DPAGSwitchTableViewCellProtocol)
        cell?.selectionStyle = .none
        cell?.aSwitch?.removeTarget(self, action: nil, for: .valueChanged)
        cell?.enabled = true
        cell?.aSwitch?.isEnabled = true
        return cell
    }

    func cellForDisclosureRow(_: IndexPath) -> (UITableViewCell & DPAGDisclosureTableViewCellProtocol)? {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: DPAGSettingsTableViewController.SettingsCellDisclosureIdentifier) as? (UITableViewCell & DPAGDisclosureTableViewCellProtocol)
        cell?.enabled = true
        cell?.selectionStyle = .default
        return cell
    }

    func cellForDisclosureSubtitleRow(_: IndexPath) -> (UITableViewCell & DPAGDisclosureSubtitleTableViewCellProtocol)? {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: DPAGSettingsTableViewController.SettingsCellDisclosureSubtitleIdentifier) as? (UITableViewCell & DPAGDisclosureSubtitleTableViewCellProtocol)
        cell?.enabled = true
        cell?.detailTextLabel?.accessibilityIdentifier = nil
        cell?.selectionStyle = .default
        return cell
    }

    func cellForSubtitleRow(_: IndexPath) -> (UITableViewCell & DPAGSubtitleTableViewCellProtocol)? {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: DPAGSettingsTableViewController.SettingsCellSubtitleIdentifier) as? (UITableViewCell & DPAGSubtitleTableViewCellProtocol)
        cell?.enabled = true
        cell?.selectionStyle = .none
        return cell
    }

    func cellForDefaultRow(_: IndexPath) -> (UITableViewCell & DPAGBaseTableViewCellProtocol)? {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: DPAGSettingsTableViewController.SettingsCellDefaultIdentifier) as? (UITableViewCell & DPAGBaseTableViewCellProtocol)
        cell?.enabled = true
        cell?.selectionStyle = .none
        return cell
    }

    func cellForHiddenRow(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: DPAGSettingsTableViewController.SettingsCellHiddenIdentifier, for: indexPath)
        return cell
    }

    @objc
    func tableView(_: UITableView, willDisplayFooterView view: UIView, forSection _: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = DPAGColorProvider.shared[.settingsHeader]
    }

    @objc
    func tableView(_: UITableView, willDisplayHeaderView view: UIView, forSection _: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = DPAGColorProvider.shared[.settingsHeader]
    }
    
    override func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.tableView.backgroundColor = DPAGColorProvider.shared[.settingsViewBackground]
        self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.tableView.reloadData()
    }
}

class DPAGSettingsTableViewController: DPAGSettingsTableViewControllerBase, DPAGViewControllerNavigationTitleBig, DPAGNavigationViewControllerStyler {
    var presenter: SettingsPresenterProtocol?

    private var contentBuilder = SettingsContentBuilder()
    private var sections = [SettingsSection]()
    private var labelVersion: UILabel?
    private var closeButton: UIButton?

    init() {
        super.init(style: .grouped)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        sections = contentBuilder.settingsSections()
        self.navigationItem.title = DPAGLocalizedString("settings.settingsTitle")
        self.navigationItem.hidesBackButton = false
        let labelVersion = UILabel()
        labelVersion.translatesAutoresizingMaskIntoConstraints = false
        labelVersion.textAlignment = .center
        labelVersion.textColor = DPAGColorProvider.shared[.labelText]
        labelVersion.font = .kFontFootnote
        if let dictionary = Bundle.main.infoDictionary, let shortVersion = dictionary["CFBundleShortVersionString"] as? String, let version = dictionary["CFBundleVersion"] as? String {
            let versionText = String(format: "%@ %@ (%@)", DPAGLocalizedString("settings.version"), shortVersion, version)
            if DPAGConstantsGlobal.isTestFlight {
                labelVersion.text = versionText + "(t)"
            } else {
                labelVersion.text = versionText
            }
        } else {
            labelVersion.text = nil
        }
        let viewLabel = UIView()
        viewLabel.backgroundColor = .clear
        viewLabel.addSubview(labelVersion)
        viewLabel.addConstraintsFillSafeArea(subview: labelVersion, padding: 20)
        self.labelVersion = labelVersion
        self.addBottomView(viewLabel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter?.viewWillAppear()
        tableView.reloadData()
    }

    @objc
    private func closeButtonTapped() {
        DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.popViewController(animated: true)
    }
    
    override func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.labelVersion?.textColor = DPAGColorProvider.shared[.labelText]
        self.closeButton?.setImage(DPAGImageProvider.shared[.kImageClose]?.imageWithTintColor(DPAGColorProvider.shared[.labelText]), for: .normal)
    }
}

// MARK: - UITableViewDataSource

extension DPAGSettingsTableViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func numberOfSections(in _: UITableView) -> Int {
        sections.count
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].items[indexPath.row]
        var cell: UITableViewCell?
        if row.selection == .profileSettings {
            cell = cellForProfile(name: presenter?.viewModel.profileName, image: presenter?.viewModel.profilePicture)
            cell?.backgroundColor = DPAGColorProvider.shared[.settingsBackground]
        } else {
            cell = self.cellForDisclosureRow(indexPath)
            cell?.textLabel?.text = row.name
            cell?.accessibilityIdentifier = row.accessibilityId
            cell?.detailTextLabel?.text = nil
            cell?.backgroundColor = DPAGColorProvider.shared[.settingsBackground]
        }
        return cell ?? self.cellForDefaultRow(indexPath) ?? UITableViewCell(style: .default, reuseIdentifier: "???")
    }
}

extension DPAGSettingsTableViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].items[indexPath.row]
        presenter?.show(selection: row.selection)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let row = sections[indexPath.section].items[indexPath.row]
        if row.selection == .profileSettings { return 80 }
        return tableView.estimatedRowHeight
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        tableView.estimatedRowHeight
    }

    func tableView(_: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        nil
    }
}
