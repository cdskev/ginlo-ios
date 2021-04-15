//
//  DPAGSubscribeChannelViewController.swift
//  SIMSme
//
//  Created by RBU on 18/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGSubscribeChannelViewControllerProtocol: DPAGTableViewControllerWithSearchProtocol {}

struct ChannelSection: Equatable {
    let letter: String
    let guid: [String]

    static func == (l: ChannelSection, r: ChannelSection) -> Bool {
        l.letter == r.letter
    }
}

class DPAGSubscribeChannelViewController: DPAGTableViewControllerWithSearch, DPAGChannelCategorySelectionDelegate, DPAGChannelSearchResultsViewControllerDelegate, DPAGSubscribeChannelViewControllerProtocol, DPAGViewControllerNavigationTitleBig, DPAGNavigationViewControllerStyler {
    static let kHeightChannel: CGFloat = 90

    static let cellIdentifierChannel = "cellIdentifierChannel"
    static let cellIdentifierChannelHeaderSection = "cellIdentifierChannelHeaderSection"

    var channelGuidsDefault: [ChannelSection] = []
    var channelGuidsDefaultCategory: [ChannelSection]?
    var channelCategory: DPAGChannelCategory?

    fileprivate var searchText: String?

    init() {
        super.init(style: .plain)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = DPAGLocalizedString("channel.list.title")
        self.configureSearchBar()
    }

    override func configureTableView() {
        super.configureTableView()
        self.extendedLayoutIncludesOpaqueBars = true
        self.tableView.register(DPAGApplicationFacadeUI.subscribeChannelCellNib(), forCellReuseIdentifier: DPAGSubscribeChannelViewController.cellIdentifierChannel)
        self.tableView.register(ChannelSectionHeaderView.self, forHeaderFooterViewReuseIdentifier: ChannelSectionHeaderView.reuseIdentifer)
        self.tableView.separatorInset = .zero
        self.tableView.layoutMargins = .zero
    }

    private lazy var categoriesViewController: UIViewController & DPAGChannelCategoriesViewControllerProtocol = {
        let vc = DPAGApplicationFacadeUI.channelCategoryVC()
        return vc
    }()

    private func loadCategories() {
        DPAGApplicationFacade.feedWorker.loadChannelCategories { [weak self] categories in
            self?.updateModel()
            if categories.count == 0 {
                return
            }
            self?.performBlockOnMainThread { [weak self] in
                guard let strongSelf = self else { return }
                let button = UIButton(type: .custom)
                button.setImage(nil, for: .normal)
                button.setTitle(DPAGLocalizedString("channel.categories.title.categories"), for: .normal)
                button.setTitleColor(DPAGColorProvider.shared[.navigationBarTint], for: .normal)
                button.accessibilityLabel = DPAGLocalizedString("channel.categories.title.show_categories")
                button.accessibilityIdentifier = "channel.categories.title.show_categories"
                button.sizeToFit()
                button.addTargetClosure { [weak self] _ in
                    guard let strongSelf = self else { return }
                    strongSelf.navigationController?.pushViewController(strongSelf.categoriesViewController, animated: true)
                }
                strongSelf.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
                strongSelf.categoriesViewController.channelCategories = categories
                strongSelf.categoriesViewController.selectionDelegate = strongSelf
            }
        }
    }

    func handleListNeedsUpdate() {
        if self.channelGuidsDisplayDefault().isEmpty {
            if self.channelCategory?.channelGuids == nil {
                self.tableView.setEmptyMessage(DPAGLocalizedString("channel.list.no_channels_found"))
            } else {
                self.tableView.setEmptyMessage(DPAGLocalizedString("channel.list.no_channels_for_category_found"))
            }
        } else {
            self.tableView.removeEmptyMessage()
        }
        self.tableView.reloadData()
        self.searchResultsController?.tableView?.reloadData()
    }

    func configureSearchBar() {
        self.configureSearchBarWithResultsController(DPAGApplicationFacadeUI.channelSearchResultsVC(delegate: self), placeholder: "android.serach.placeholder")
    }

    override func viewFirstAppear(_ animated: Bool) {
        super.viewFirstAppear(animated)
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            self?.loadCategories()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.transitionCoordinator?.animate(alongsideTransition: { _ in
        }, completion: { [weak self] context in
            if context.isCancelled {
                self?.navigationController?.setNavigationBarHidden(false, animated: false)
            } else if self?.searchText != nil {
                self?.searchText = nil
            }
        })
        if self.searchText != nil {
            if self.searchController?.isActive == false {
                self.searchController?.isActive = true
            }
            self.searchResultsController?.tableView?.reloadData()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    fileprivate func updateModel() {
        DPAGApplicationFacade.feedWorker.updatedFeedListWithFeedsToUpdate(forFeedType: .channel) { [weak self] channelGuids, _, errorMessage in
            guard let strongSelf = self else { return }
            if let errorMessage = errorMessage {
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                }
                return
            }
            var channelGuidsDefault: [String] = []
            if channelGuids.count > 0 {
                for channelGuid in channelGuids {
                    guard let channel = DPAGApplicationFacade.cache.channel(for: channelGuid) else { continue }
                    if channel.externalURL == nil {
                        channelGuidsDefault.append(channelGuid)
                    }
                    if let feedbackContactPhoneNumber = channel.feedbackContactPhoneNumber {
                        DPAGApplicationFacade.feedWorker.checkFeedbackContactPhoneNumber(feedbackContactPhoneNumber: feedbackContactPhoneNumber, feedbackContactNickname: channel.feedbackContactNickname)
                    }
                }
            }
            strongSelf.channelGuidsDefault = strongSelf.groupChannelsInSection(channelGuids: channelGuidsDefault)
            DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                self?.handleListNeedsUpdate()
            }
        }
    }

    func groupChannelsInSection(channelGuids: [String]) -> [ChannelSection] {
        let channelGuidsSorted = channelGuids.sorted { [weak self] in
            guard let stronSelf = self else { return false }
            return stronSelf.channelSort(channel1: $0, channel2: $1)
        }
        let groupedDictionary = Dictionary(grouping: channelGuidsSorted, by: { String(self.channelName(channelGuid: $0).prefix(1).uppercased()) })
        let keys = groupedDictionary.keys.sorted()
        return keys.compactMap { letterToChannelSectionMapper(letter: $0, groupedDictionary: groupedDictionary) }
    }

    func letterToChannelSectionMapper(letter: String, groupedDictionary: [String: [String]]) -> ChannelSection? {
        guard let channelsInSection = groupedDictionary[letter] else { return nil }
        return ChannelSection(letter: letter, guid: channelsInSection)
    }

    func channelName(channelGuid: String) -> String {
        DPAGApplicationFacade.cache.channel(for: channelGuid)?.name_short ?? ""
    }

    func channelGuidsDisplayDefault() -> [ChannelSection] {
        self.channelGuidsDefaultCategory ?? self.channelGuidsDefault
    }

    // MARK: - DPAGChannelPromotedDelegate

    func didSelectChannel(_ channelGuid: String) {
        guard let channel = DPAGApplicationFacade.cache.channel(for: channelGuid) else { return }
        if let externalURL = channel.externalURLForPromotedCategory(self.channelCategory?.ident) ?? channel.externalURL {
            if let url = URL(string: externalURL) {
                AppConfig.openURL(url)
            }
        } else {
            if channel.isSubscribed, let streamGuid = channel.stream {
                if let searchController = self.searchController, searchController.isActive {
                    self.searchText = searchController.searchBar.text
                    self.navigationController?.setNavigationBarHidden(false, animated: true)
                }
                DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
                    if let strongSelf = self {
                        DPAGChatHelper.openChatStreamView(streamGuid, navigationController: strongSelf.navigationController) { _ in
                            DPAGProgressHUD.sharedInstance.hide(true)
                        }
                    }
                }
            } else {
                if let nextVC = DPAGApplicationFacadeUI.channelDetailsVC(channelGuid: channelGuid, category: self.channelCategory) {
                    if let searchController = self.searchController, searchController.isActive {
                        self.searchText = searchController.searchBar.text
                        self.navigationController?.setNavigationBarHidden(false, animated: true)
                    }
                    self.navigationController?.pushViewController(nextVC, animated: true)
                }
            }
        }
    }

    // MARK: - filtering

    override func filterContent(searchText: String, completion: @escaping DPAGCompletion) {
        var searchResults: [String] = []
        if searchText.isEmpty == false {
            let channelGuidsDisplayDefault = self.channelGuidsDisplayDefault()
            let searchTextEval = searchText.lowercased()
            for channelSectionList in channelGuidsDisplayDefault {
                for channelGuid in channelSectionList.guid {
                    if self.isSearchResultForChannel(channelGuid, searchText: searchTextEval) {
                        searchResults.append(channelGuid)
                    }
                }
            }
        }

        self.performBlockOnMainThread { [weak self] in
            (self?.searchResultsController as? DPAGChannelSearchResultsViewControllerProtocol)?.channelsSearched = searchResults
            completion()
        }
    }

    func isSearchResultForChannel(_ channelGuid: String, searchText: String) -> Bool {
        guard let channel = DPAGApplicationFacade.cache.channel(for: channelGuid) else { return false }
        let searchComponents = searchText.components(separatedBy: CharacterSet.alphanumerics.inverted)
        if searchComponents.count > 0 {
            for searchComponent in searchComponents {
                if channel.name_long?.lowercased().range(of: searchComponent) != nil {
                    continue
                }
                if channel.name_short?.lowercased().range(of: searchComponent) != nil {
                    continue
                }
                if channel.searchText?.lowercased().range(of: searchComponent) != nil {
                    continue
                }
                return false
            }
            return true
        }
        return false
    }

    // MARK: - UISearchDisplayDelegate

    func didDismissSearchController(_: UISearchController) {
        self.searchText = nil
    }

    // MARK: - category delegate

    func didSelectChannelCategory(_ channelCategory: DPAGChannelCategory?) {
        if let channelCategory = channelCategory {
            self.channelCategory = channelCategory
            var channelGuidsDefaultCategory = [String]()
            if let channelGuids = channelCategory.channelGuids {
                channelGuidsDefaultCategory += channelGuids
            }
            self.channelGuidsDefaultCategory = groupChannelsInSection(channelGuids: channelGuidsDefaultCategory)
            let titleKey = "channel.categories.menu.title." + (channelCategory.titleKey ?? "")
            self.navigationItem.title = DPAGLocalizedString(titleKey)
        } else {
            self.channelCategory = nil
            self.channelGuidsDefaultCategory = nil
            self.navigationItem.title = DPAGLocalizedString("channel.list.title")
        }

        self.handleListNeedsUpdate()
    }

    func channelSort(channel1 c1: String, channel2 c2: String) -> Bool {
        guard let channel1 = DPAGApplicationFacade.cache.channel(for: c1), let channel2 = DPAGApplicationFacade.cache.channel(for: c2) else { return true }
        let result: ComparisonResult? = channel1.name_short?.compare(channel2.name_short ?? "", options: .caseInsensitive)
        return result == .orderedAscending || result == .orderedSame
    }
}

extension DPAGSubscribeChannelViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        channelGuidsDisplayDefault().count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        channelGuidsDisplayDefault()[section].guid.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var rcCell: UITableViewCell?
        let section = channelGuidsDisplayDefault()[indexPath.section]
        let channelGuid = section.guid[indexPath.row]
        if let cell = tableView.dequeueReusableCell(withIdentifier: DPAGSubscribeChannelViewController.cellIdentifierChannel, for: indexPath) as? SubscribeChannelCell {
            DPAGLog("table cell reloading: %@ for guid: %@", cell, channelGuid)
            guard let cellViewModel = SubscribeChannelCellViewModelMapper.cellViewModelFor(channelGuid: channelGuid) else { fatalError("No channel for guid") }
            if cellViewModel.image == nil {
                self.updateMissingAssets([.profile], channelGuid: channelGuid)
            }
            cell.setupWithViewModel(viewModel: cellViewModel)
            cell.selectionStyle = .none
            rcCell = cell
        }
        return rcCell ?? UITableViewCell(style: .default, reuseIdentifier: "???")
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: ChannelSectionHeaderView.reuseIdentifer) as? ChannelSectionHeaderView else { return nil }
        header.customLabel.text = channelGuidsDisplayDefault()[section].letter
        return header
    }

    private func updateMissingAssets(_ assetTypesMissing: [DPAGChannel.AssetType], channelGuid: String) {
        self.performBlockInBackground {
            let model = ChannelGetAssetModel(channelId: channelGuid, assetTypes: assetTypesMissing)
            DPAGApplicationFacade.feedWorker.updateChannelAssets(models: [model], feedType: .channel, completion: { results in
                guard let results = results, results.count > 0 else { return }
                self.updateCellWithNewAssets(result: results[0])
            })
        }
    }

    private func updateCellWithNewAssets(result: ChannelGetAssetResult) {
        guard let iconImageData = result.assets[.profile] as? Data, let iconImage = UIImage(data: iconImageData, scale: UIScreen.main.scale) else { return }
        self.performBlockOnMainThread { [weak self] in
            guard let strongSelf = self else { return }
            var idxChannel: Int?
            var idxSection: Int?
            for section in strongSelf.channelGuidsDisplayDefault() {
                idxChannel = section.guid.firstIndex(of: result.channelId)
                if idxChannel != nil {
                    idxSection = strongSelf.channelGuidsDisplayDefault().firstIndex { $0 == section }
                    break
                }
            }
            guard let indexChannel = idxChannel,
                let indexSection = idxSection else {
                return
            }
            let indexPath = IndexPath(row: indexChannel, section: indexSection)
            guard let cell = strongSelf.tableView.cellForRow(at: indexPath) as? SubscribeChannelCell,
                var viewModel = cell.viewModel else {
                return
            }
            viewModel.image = iconImage
            cell.setupWithViewModel(viewModel: viewModel)
        }
    }
}

extension DPAGSubscribeChannelViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        DPAGSubscribeChannelViewController.kHeightChannel
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = channelGuidsDisplayDefault()[indexPath.section]
        let channelGuid = section.guid[indexPath.row]
        if let nextVC = DPAGApplicationFacadeUI.channelDetailsVC(channelGuid: channelGuid, category: self.channelCategory) {
            self.navigationController?.pushViewController(nextVC, animated: true)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
