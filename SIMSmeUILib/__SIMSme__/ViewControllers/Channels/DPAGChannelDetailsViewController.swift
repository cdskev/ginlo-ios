//
//  DPAGChannelDetailsViewController.swift
//  SIMSme
//
//  Created by RBU on 24/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import SIMSmeCore
import UIKit

extension DPAGChannelDetailsViewController: DPAGNavigationViewControllerStyler {
    func configureNavigationWithStyle() {
        self.navigationController?.navigationBar.barTintColor = self.channel.colorNavigationbar ?? DPAGColorProvider.shared[.navigationBar]
        self.navigationController?.navigationBar.tintColor = self.channel.colorNavigationbarAction ?? DPAGColorProvider.shared[.navigationBarTint]
        self.navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: self.channel.colorNavigationbarText ?? DPAGColorProvider.shared[.navigationBarTint]]
        self.navigationController?.navigationBar.largeTitleTextAttributes = [.foregroundColor: self.channel.colorNavigationbarText ?? DPAGColorProvider.shared[.navigationBarTint]]
    }
}

class DPAGChannelDetailsViewController: DPAGViewControllerBackground {
    static let headerIdentifier = "headerIdentifier"
    static let cellIdentifierChannelDescription = "cellIdentifierChannelDescription"
    static let cellIdentifierChannelDisclaimer = "cellIdentifierChannelDisclaimer"
    static let cellIdentifierChannelToggle = "cellIdentifierChannelToggle"
    static let cellIdentifierChannelNoOption = "cellIdentifierChannelNoOption"
    static let cellIdentifierChannelMedia = "cellIdentifierChannelMedia"

    fileprivate(set) var channel: DPAGChannel
    fileprivate(set) var channelGuid: String

    fileprivate var feedType: DPAGChannelType = .channel
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.navigationController?.navigationBar.barTintColor = self.channel.colorNavigationbar ?? DPAGColorProvider.shared[.navigationBar]
                self.navigationController?.navigationBar.tintColor = self.channel.colorNavigationbarAction ?? DPAGColorProvider.shared[.navigationBarTint]
                self.navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: self.channel.colorNavigationbarText ?? DPAGColorProvider.shared[.navigationBarTint]]
                self.navigationController?.navigationBar.largeTitleTextAttributes = [.foregroundColor: self.channel.colorNavigationbarText ?? DPAGColorProvider.shared[.navigationBarTint]]
                self.viewButtonAction.colorAction = self.channel.colorDetailsButtonFollow ?? (self.channel.colorNavigationbar ?? DPAGColorProvider.shared[.channelDetailsButtonFollow])
                self.viewButtonAction.colorActionContrast = self.channel.colorDetailsButtonFollowText ?? (self.channel.colorNavigationbarAction ?? DPAGColorProvider.shared[.channelDetailsButtonFollowText])
                self.viewButtonAction.colorActionDisabled = self.channel.colorDetailsButtonFollowDisabled ?? (self.channel.colorNavigationbar?.withAlphaComponent(0.3) ?? DPAGColorProvider.shared[.channelDetailsButtonFollowDisabled])
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet fileprivate var tableView: UITableView! {
        didSet {
            self.tableView.delegate = self
            self.tableView.dataSource = self

            self.tableView.separatorStyle = .none

            self.tableView.register(DPAGApplicationFacadeUIViews.cellTableViewSwitchNib(), forCellReuseIdentifier: DPAGChannelDetailsViewController.cellIdentifierChannelToggle)
            self.tableView?.register(DPAGApplicationFacadeUI.cellChannelDetailsDesciptionNib(), forCellReuseIdentifier: DPAGChannelDetailsViewController.cellIdentifierChannelDescription)
            self.tableView.register(DPAGApplicationFacadeUIViews.cellTableViewSubtitleNib(), forCellReuseIdentifier: DPAGChannelDetailsViewController.cellIdentifierChannelDisclaimer)
        }
    }

    @IBOutlet private var imageViewChannelProviderBack: UIImageView!
    @IBOutlet private var imageViewChannelProviderFront: UIImageView!
    @IBOutlet private var imageViewChannelBackground: UIImageView!
    @IBOutlet fileprivate var viewButtonAction: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonAction.button.addTarget(self, action: #selector(handleButtonAction(_:)), for: .touchUpInside)
            self.viewButtonAction.button.setTitle(DPAGLocalizedString("channel_details.button.subscribe.title"), for: .normal)
            self.viewButtonAction.button.accessibilityIdentifier = "buttonAction"

            self.viewButtonAction.colorAction = self.channel.colorDetailsButtonFollow ?? (self.channel.colorNavigationbar ?? DPAGColorProvider.shared[.channelDetailsButtonFollow])
            self.viewButtonAction.colorActionContrast = self.channel.colorDetailsButtonFollowText ?? (self.channel.colorNavigationbarAction ?? DPAGColorProvider.shared[.channelDetailsButtonFollowText])
            self.viewButtonAction.colorActionDisabled = self.channel.colorDetailsButtonFollowDisabled ?? (self.channel.colorNavigationbar?.withAlphaComponent(0.3) ?? DPAGColorProvider.shared[.channelDetailsButtonFollowDisabled])
        }
    }

    @IBOutlet fileprivate var imageViewButtonSeparator: UIImageView!

    fileprivate var model: [DPAGChannelOption] = []

    fileprivate var category: DPAGChannelCategory?
    fileprivate var optionsForced: [String: String]?

    fileprivate var showFullDescription: Bool = false
    fileprivate var didSwitchSettings = false

    init?(channelGuid: String, category: DPAGChannelCategory?) {
        self.channelGuid = channelGuid

        guard let channel = DPAGApplicationFacade.cache.channel(for: channelGuid) else {
            return nil
        }

        self.category = category
        self.channel = channel

        if channel.isSubscribed == false {
            if let category = category {
                self.optionsForced = self.channel.optionValuesForCategory(category.ident)
            } else {
                self.optionsForced = self.channel.optionValuesForCategory(nil)
            }
        }

        super.init(nibName: "DPAGChannelDetailsViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.navigationItem.title = self.channel.name_short

        self.imageViewChannelBackground.backgroundColor = self.channel.colorDetailsBackground
        self.imageViewChannelProviderBack.backgroundColor = self.channel.colorDetailsBackgroundLogo

        let channelGuid = self.channel.guid

        let assetsList = DPAGApplicationFacade.feedWorker.assetsList(feedGuid: channelGuid)
        var assetTypesMissing: [String] = []

        self.imageViewChannelProviderFront.image = assetsList[.itemForeground] as? UIImage

        if self.imageViewChannelProviderFront.image == nil && assetsList.keys.contains(.itemForeground) == false {
            assetTypesMissing.append("\(channelGuid);\(DPAGChannel.AssetType.itemForeground.rawValue)")
        }

        if self.imageViewChannelProviderBack.backgroundColor == nil || self.feedType == .service {
            self.imageViewChannelProviderBack.image = assetsList[.itemBackground] as? UIImage

            if self.imageViewChannelProviderBack.image == nil, assetsList.keys.contains(.itemBackground) == false {
                assetTypesMissing.append("\(channelGuid);\(DPAGChannel.AssetType.itemBackground.rawValue)")
            }
        }

        let assetChat = DPAGApplicationFacade.feedWorker.assetsChat(feedGuid: channelGuid)

        if self.imageViewChannelBackground.backgroundColor == nil {
            self.imageViewChannelBackground.image = assetChat[.chatBackground] as? UIImage

            if self.imageViewChannelBackground.image == nil, assetChat.keys.contains(.chatBackground) == false {
                assetTypesMissing.append("\(channelGuid);\(DPAGChannel.AssetType.chatBackground.rawValue)")
            }
        }

        let providerImage = assetChat[.profile] as? UIImage

        if providerImage == nil {
            assetTypesMissing.append("\(channelGuid);\(DPAGChannel.AssetType.profile.rawValue)")
        }

        if assetTypesMissing.count > 0 {
            let feedType = self.feedType

            self.performBlockInBackground {
                DPAGApplicationFacade.feedWorker.updateFeedAssets(feedGuids: [channelGuid], feedAssetIdentifier: assetTypesMissing, feedType: feedType) { [weak self] in

                    self?.performBlockOnMainThread { [weak self] in

                        if let strongSelf = self {
                            let assetsList = DPAGApplicationFacade.feedWorker.assetsList(feedGuid: channelGuid)

                            strongSelf.imageViewChannelProviderFront.image = assetsList[.itemForeground] as? UIImage

                            if strongSelf.imageViewChannelProviderBack.backgroundColor == nil || feedType == .service {
                                strongSelf.imageViewChannelProviderBack.image = assetsList[.itemBackground] as? UIImage
                            }

                            if strongSelf.imageViewChannelBackground.backgroundColor == nil {
                                let assetChat = DPAGApplicationFacade.feedWorker.assetsChat(feedGuid: channelGuid)

                                strongSelf.imageViewChannelBackground.image = assetChat[.chatBackground] as? UIImage
                            }
                        }
                    }
                }
            }
        }

        self.createModel()

        self.imageViewButtonSeparator.isHidden = false
        self.imageViewButtonSeparator.image = DPAGImageProvider.shared[.kImageChannelDetailsBackground]

        // self.tableView.contentInset.bottom = self.imageViewButtonSeparator.frame.size.height

        if self.channel.isSubscribed {
            self.viewButtonAction.isHidden = true
        } else {
            self.viewButtonAction.isHidden = false

            if self.channel.rootOptions.isEmpty == false {
                self.viewButtonAction.isEnabled = (self.currentFilter().isEmpty == false)
            }
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if let color = self.channel.colorNavigationbarText, let backgroundColor = self.channel.colorNavigationbar {
            return color.statusBarStyle(backgroundColor: backgroundColor)
        }
        return super.preferredStatusBarStyle
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if self.channel.isSubscribed, self.viewButtonAction.isHidden, self.didSwitchSettings {
            self.saveChannelConfig()
        } else {
            self.channel.rollback()
        }
    }

    fileprivate func createModel() {
        self.model.removeAll()

        for rootOption in self.channel.rootOptions {
            if self.channel.isSubscribed == false {
                if let defaultValue = self.optionsForced?[rootOption.ident] {
                    rootOption.setDefaultValue(defaultValue)
                }
            }

            self.model.append(rootOption)

            self.model += self.allChildOptionsForOption(rootOption)
        }
    }

    fileprivate func allChildOptionsForOption(_ option: DPAGChannelOption) -> [DPAGChannelOption] {
        var retVal: [DPAGChannelOption] = []

        if let children = option.childrenForCurrentValue() {
            for childOption in children {
                if self.channel.isSubscribed == false {
                    if let defaultValue = self.optionsForced?[childOption.ident] {
                        childOption.setDefaultValue(defaultValue)
                    }
                }

                retVal.append(childOption)

                retVal += self.allChildOptionsForOption(childOption)
            }
        }

        return retVal
    }

    fileprivate func saveChannelConfig() {
        let currentFilter = self.currentFilter()
        let channelGuid = self.channelGuid
        let feedType = self.feedType

        self.performBlockInBackground {
            DPAGApplicationFacade.feedWorker.subscribeFeed(feedGuid: channelGuid, filter: currentFilter, feedType: feedType) { _, _, errorMessage in

                if errorMessage != nil {
                    DPAGApplicationFacade.cache.rollbackChannel(channelGuid: channelGuid)
                } else {
                    DPAGApplicationFacade.cache.channel(for: channelGuid)?.save()
                }
            }
        }
    }

    fileprivate func currentFilter() -> String {
        self.channel.currentFilter()
    }

    @objc
    fileprivate func handleButtonAction(_: Any?) {
        // save changed switches
        self.channel.save()

        let currentFilter = self.currentFilter()
        let channelGuid = self.channelGuid
        let feedType = self.feedType

        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            DPAGApplicationFacade.feedWorker.subscribeFeed(feedGuid: channelGuid, filter: currentFilter, feedType: feedType) { [weak self] _, _, errorMessage in
                guard let strongSelf = self else { return }
                if let errorMessage = errorMessage {
                    DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                    }
                } else {
                    NotificationCenter.default.post(name: DPAGStrings.Notification.Menu.MENU_NEW_REINIT, object: nil)
                    if let channel = DPAGApplicationFacade.cache.channel(for: channelGuid), let channelStreamGuid = channel.stream {
                        if let navigationController = strongSelf.navigationController, navigationController.viewControllers.count > 1, navigationController.viewControllers[navigationController.viewControllers.count - 2] is DPAGSubscribeChannelViewControllerProtocol {
                            var viewControllers = navigationController.viewControllers
                            _ = viewControllers.popLast()
                            self?.performBlockOnMainThread {
                                (viewControllers.last as? DPAGSubscribeChannelViewControllerProtocol)?.tableView.reloadData()
                            }
                            let chatStreamViewController: (UIViewController & DPAGChatStreamBaseViewControllerProtocol)?
                            if feedType == .channel {
                                chatStreamViewController = DPAGApplicationFacadeUI.channelStreamVC(stream: channelStreamGuid, streamState: .readOnly)
                                if let chatStreamViewController = chatStreamViewController {
                                    viewControllers.append(chatStreamViewController)
                                    chatStreamViewController.createModel()
                                }
                            }
                            DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                                self?.navigationController?.setViewControllers(viewControllers, animated: true)
                            }
                        } else {
                            DPAGChatHelper.openChatStreamView(channelStreamGuid, navigationController: strongSelf.navigationController) { _ in
                                DPAGProgressHUD.sharedInstance.hide(true)
                            }
                        }
                    }
                }
            }
        }
    }

    fileprivate func lighterColor(_ color: UIColor) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if color.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return UIColor(hue: h, saturation: s, brightness: min(b * 1.3, 1.0), alpha: a)
        }
        return color
    }

    fileprivate func darkerColor(_ color: UIColor) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0

        if color.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return UIColor(hue: h, saturation: s, brightness: b * 0.85, alpha: a)
        }
        return color
    }

    fileprivate func updateColorsForCell(_ cell: UITableViewCell & DPAGSwitchTableViewCellProtocol, isOn: Bool, level: Int) {
        if isOn {
            cell.textLabel?.textColor = self.channel.colorDetailsLabelEnabled ?? DPAGColorProvider.shared[.channelDetailsLabelEnabled]
            cell.detailTextLabel?.textColor = self.channel.colorDetailsLabelEnabled ?? DPAGColorProvider.shared[.channelDetailsLabelEnabled]
        } else {
            var colorText: UIColor? = self.channel.colorDetailsLabelDisabled ?? DPAGColorProvider.shared[.channelDetailsLabelDisabled]

            if var colorTextLevel = colorText {
                var whiteComponent: CGFloat = 0
                colorTextLevel.getWhite(&whiteComponent, alpha: nil)
                let lightenUp = whiteComponent > 0.7
                for _ in 0 ..< level {
                    colorTextLevel = lightenUp ? self.lighterColor(colorTextLevel) : self.darkerColor(colorTextLevel)
                }
                colorText = colorTextLevel
            }
            cell.textLabel?.textColor = colorText
            cell.detailTextLabel?.textColor = colorText
        }
    }

    @objc
    fileprivate func handleSwitchToggled(_ aSwitch: UISwitch) {
        let buttonPosition = aSwitch.convert(CGPoint.zero, to: self.tableView)
        guard let indexPath = self.tableView?.indexPathForRow(at: buttonPosition), let cell = (self.tableView?.cellForRow(at: indexPath) as? (UITableViewCell & DPAGSwitchTableViewCellProtocol)), let cellIdent = cell.ident, let option = self.channel.option(forIdent: cellIdent) else { return }

        if let optionToggle = option as? DPAGChannelToggle {
            let childrenBefore = self.allChildOptionsForOption(option)
            optionToggle.setOn(aSwitch.isOn)
            _ = self.optionsForced?.removeValue(forKey: option.ident)
            var level = 0
            var optionParent = option.parent?.option
            while optionParent != nil {
                level += 1
                optionParent = optionParent?.parent?.option
            }
            self.updateColorsForCell(cell, isOn: aSwitch.isOn, level: level)
            let childrenAfter = self.allChildOptionsForOption(option)
            self.tableView?.beginUpdates()
            if childrenBefore.count > 0 {
                self.model.removeSubrange(indexPath.row + 1 ..< indexPath.row + 1 + childrenBefore.count)
                var arrIdxPaths: [IndexPath] = []
                for idx in 0 ..< childrenBefore.count {
                    arrIdxPaths.append(IndexPath(row: idx + 1 + indexPath.row, section: 1))
                }
                self.tableView?.deleteRows(at: arrIdxPaths, with: .automatic)
            }
            if childrenAfter.count > 0 {
                self.model.insert(contentsOf: childrenAfter, at: indexPath.row + 1)
                var arrIdxPaths: [IndexPath] = []
                for idx in 0 ..< childrenAfter.count {
                    arrIdxPaths.append(IndexPath(row: idx + 1 + indexPath.row, section: 1))
                }
                self.tableView?.insertRows(at: arrIdxPaths, with: .automatic)
            }
            self.tableView?.endUpdates()
        }
        if self.channel.isSubscribed == false {
            self.viewButtonAction.isEnabled = (self.currentFilter().isEmpty == false)
        } else if self.currentFilter().isEmpty && feedType == .channel {
            self.presentErrorAlert(alertConfig: AlertConfigError(titleIdentifier: "channel.details.alert.title.filter_is_empty", messageIdentifier: "channel.details.alert.message.filter_is_empty"))
        }

        self.didSwitchSettings = true
    }
}

// MARK: - table view data source

extension DPAGChannelDetailsViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        3
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section != 1 {
            return 1
        }
        return self.model.count
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section != 1 || self.model.count == 0 {
            return 0
        }
        return DPAGConstantsGlobal.kTableSectionHeaderGroupedHeight
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section != 1 {
            return nil
        }

        let headerView = UITableViewHeaderFooterView(reuseIdentifier: DPAGChannelDetailsViewController.headerIdentifier)

        headerView.accessibilityIdentifier = "channel_details.section_toggles.title"
        headerView.textLabel?.text = DPAGLocalizedString("channel_details.section_toggles.title")

        return headerView
    }

    func tableView(_: UITableView, willDisplayHeaderView view: UIView, forSection _: Int) {
        // Background color
        view.tintColor = UIColor.clear

        // Text Color
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = self.channel.colorDetailsBackground != nil
                ? self.channel.colorDetailsLabelEnabled
                : (self.channel.colorNavigationbarText ?? DPAGColorProvider.shared[.labelText])
            header.textLabel?.font = UIFont.kFontBody

            // Another way to set the background color
            // Note: does not preserve gradient effect of original header
            // header.contentView.backgroundColor = self.channel.colorDetailsBackground ?? self.channel.colorNavigationbar ?? DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = self.cellForChannelDescription()

            cell?.selectionStyle = .none

            return cell ?? UITableViewCell(style: .default, reuseIdentifier: nil)
        }
        /* else if (indexPath.section == 2)
         {
         let cell = self.cellForChannelMedia()

         cell.selectionStyle = UITableViewCellSelectionStyle.Default

         return cell
         } */
        else if indexPath.section == 2 {
            let cell = self.cellForChannelDisclaimer()

            cell?.selectionStyle = .none

            return cell ?? UITableViewCell(style: .default, reuseIdentifier: nil)
        }

        return self.cellForOption(at: indexPath)
    }

    fileprivate func cellForOption(at indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        let option = self.model[indexPath.row]
        var level: CGFloat = 0

        if let optionToggle = option as? DPAGChannelToggle, let cellToggle = tableView.dequeueReusableCell(withIdentifier: DPAGChannelDetailsViewController.cellIdentifierChannelToggle, for: indexPath) as? (UITableViewCell & DPAGSwitchTableViewCellProtocol) {
            cellToggle.aSwitch?.onTintColor = self.channel.colorDetailsToggle ?? DPAGColorProvider.shared[.channelDetailsToggle]
            cellToggle.aSwitch?.tintColor = self.channel.colorDetailsToggleOff ?? DPAGColorProvider.shared[.switchOnTint]

            cellToggle.textLabel?.font = UIFont.kFontHeadline
            cellToggle.textLabel?.numberOfLines = 0

            cellToggle.aSwitch?.isOn = optionToggle.isOn
            cellToggle.aSwitch?.isEnabled = self.channel.isDeleted == false && optionToggle.isEnabled()
            cellToggle.ident = option.ident

            cellToggle.accessibilityIdentifier = option.ident

            cellToggle.aSwitch?.addTarget(self, action: #selector(handleSwitchToggled(_:)), for: .valueChanged)

            cell = cellToggle

            let accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)"

            cell.accessibilityIdentifier = accessibilityIdentifier
            cellToggle.aSwitch?.accessibilityIdentifier = accessibilityIdentifier + "-switch"

            var optionParent = option.parent?.option

            while optionParent != nil {
                level += 1
                optionParent = optionParent?.parent?.option
            }

            self.updateColorsForCell(cellToggle, isOn: optionToggle.isOn, level: Int(level))
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: DPAGChannelDetailsViewController.cellIdentifierChannelNoOption) ?? UITableViewCell(style: .subtitle, reuseIdentifier: DPAGChannelDetailsViewController.cellIdentifierChannelNoOption)

            cell.accessibilityIdentifier = "cellIdentifierChannelNoOption"
            cell.detailTextLabel?.textColor = self.channel.colorDetailsLabelEnabled ?? DPAGColorProvider.shared[.channelDetailsLabelEnabled]
            cell.textLabel?.textColor = self.channel.colorDetailsLabelEnabled ?? DPAGColorProvider.shared[.channelDetailsLabelEnabled]
        }

        cell.backgroundColor = UIColor(white: 0.0, alpha: min(0.6, level * 0.1))
        cell.contentView.backgroundColor = UIColor.clear
        cell.textLabel?.backgroundColor = UIColor.clear
        cell.detailTextLabel?.backgroundColor = UIColor.clear

        cell.textLabel?.text = option.label
        cell.detailTextLabel?.text = option.labelSub

        cell.selectionStyle = .none

        return cell
    }

    fileprivate func cellForChannelDescription() -> UITableViewCell? {
        let cellDequeued = self.tableView.dequeueReusableCell(withIdentifier: DPAGChannelDetailsViewController.cellIdentifierChannelDescription)

        cellDequeued?.accessibilityIdentifier = "cellIdentifierChannelDescription"

        guard let cell = cellDequeued as? (UITableViewCell & DPAGChannelDetailsDesciptionTableViewCellProtocol) else { return cellDequeued }

        cell.backgroundColor = UIColor.clear
        cell.contentView.backgroundColor = UIColor.clear

        cell.labelDetailtext?.text = self.channel.name_long
        cell.labelText?.text = DPAGLocalizedString("channel.details.label.channel_description")

        cell.labelDetailtext?.textColor = self.channel.colorDetailsText ?? DPAGColorProvider.shared[.channelDetailsText]
        cell.labelText?.textColor = self.channel.colorDetailsLabelEnabled ?? DPAGColorProvider.shared[.channelDetailsLabelEnabled]

        cell.labelText?.numberOfLines = 0
        cell.labelDetailtext?.numberOfLines = 0

        cell.labelDetailtext?.font = UIFont.kFontSubheadline
        cell.labelText?.font = UIFont.kFontCaption1

        cell.selectionStyle = .none

        if self.channel.rootOptions.isEmpty == false {
            cell.isShowingAllContent = self.showFullDescription
            cell.tintColorContrast = self.channel.colorDetailsText ?? DPAGColorProvider.shared[.channelDetailsText]
        }

        return cell
    }

    @objc
    fileprivate func cellForChannelDisclaimer() -> UITableViewCell? {
        let cellDequeued = self.tableView.dequeueReusableCell(withIdentifier: DPAGChannelDetailsViewController.cellIdentifierChannelDisclaimer)

        cellDequeued?.accessibilityIdentifier = "cellIdentifierChannelDisclaimer"

        guard let cell = cellDequeued as? (UITableViewCell & DPAGSubtitleTableViewCellProtocol) else { return cellDequeued }

        cell.backgroundColor = UIColor.clear
        cell.contentView.backgroundColor = UIColor.clear

        cell.detailTextLabel?.text = DPAGLocalizedString("channel.details.disclaimer.detail")
        cell.textLabel?.text = DPAGLocalizedString("channel.details.disclaimer.title")

        cell.detailTextLabel?.textColor = self.channel.colorDetailsText ?? DPAGColorProvider.shared[.channelDetailsText]
        cell.textLabel?.textColor = self.channel.colorDetailsLabelEnabled ?? DPAGColorProvider.shared[.channelDetailsLabelEnabled]

        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.numberOfLines = 0

        cell.detailTextLabel?.font = UIFont.kFontCaption2
        cell.textLabel?.font = UIFont.kFontCaption1

        cell.selectionStyle = .none

        return cell
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var cell: UITableViewCell?

        if indexPath.section == 0 {
            cell = self.cellForChannelDescription()

            cell?.detailTextLabel?.numberOfLines = (self.channel.rootOptions.isEmpty || self.showFullDescription) ? 0 : 2
        } else if indexPath.section == 2 {
            cell = self.cellForChannelDisclaimer()
        } else {
            return 60
        }

        if let sizingCell = cell {
            sizingCell.setNeedsUpdateConstraints()
            sizingCell.updateConstraintsIfNeeded()

            return sizingCell.calculateHeightForConfiguredSizingCellWidth(self.tableView.bounds.width) - 1
        }
        return 44
    }
}

extension DPAGChannelDetailsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            self.showFullDescription = !self.showFullDescription
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }
}
