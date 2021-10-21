//
//  DPAGChannelSearchViewController.swift
// ginlo
//
//  Created by RBU on 13/01/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGChannelSearchResultsViewControllerDelegate: AnyObject {
    func didSelectChannel(_ channelGuid: String)
}

protocol DPAGChannelSearchResultsViewControllerProtocol: DPAGSearchResultsViewControllerProtocol {
    var channelsSearched: [String] { get set }
}

class DPAGChannelSearchResultsViewController: DPAGSearchResultsViewController, DPAGChannelSearchResultsViewControllerProtocol {
    private static let CellChannelIdentifier = "cellChannelIdentifier"

    var channelsSearched = [String]()

    private weak var searchDelegate: DPAGChannelSearchResultsViewControllerDelegate?

    init(delegate: DPAGChannelSearchResultsViewControllerDelegate) {
        self.searchDelegate = delegate

        super.init(style: .plain)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func configureTableView() {
        super.configureTableView()
        self.tableView.register(DPAGApplicationFacadeUI.subscribeChannelCellNib(), forCellReuseIdentifier: DPAGChannelSearchResultsViewController.CellChannelIdentifier)
        self.tableView.separatorInset = .zero
        self.tableView.layoutMargins = .zero
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
        guard let indexOfChannel = self.channelsSearched.firstIndex(of: result.channelId) else { return }
        guard let iconImageData = result.assets[.profile] as? Data, let iconImage = UIImage(data: iconImageData, scale: UIScreen.main.scale) else { return }
        self.performBlockOnMainThread {
            let indexPath = IndexPath(row: indexOfChannel, section: self.tableView.numberOfSections - 1)
            guard let cell = self.tableView.cellForRow(at: indexPath) as? SubscribeChannelCell, var viewModel = cell.viewModel else { return }
            viewModel.image = iconImage
            cell.setupWithViewModel(viewModel: viewModel)
        }
    }
}

extension DPAGChannelSearchResultsViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        self.channelsSearched.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: DPAGChannelSearchResultsViewController.CellChannelIdentifier, for: indexPath) as? SubscribeChannelCell else { fatalError("Can not dequeue SubscribeChannelCell") }
        let channelGuid = self.channelsSearched[indexPath.row]
        guard let cellViewModel = SubscribeChannelCellViewModelMapper.cellViewModelFor(channelGuid: channelGuid) else { fatalError("No channel for guid") }
        if cellViewModel.image == nil {
            self.updateMissingAssets([.profile], channelGuid: channelGuid)
        }
        cell.setupWithViewModel(viewModel: cellViewModel)
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        DPAGSubscribeChannelViewController.kHeightChannel
    }
}

extension DPAGChannelSearchResultsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let channelGuid = self.channelsSearched[indexPath.row]
        self.searchDelegate?.didSelectChannel(channelGuid)
    }
}
