//
//  SubscribeChannelCellViewModelMapper.swift
//  SIMSmeUILib
//
//  Created by Maxime Bentin on 07.05.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation
import SIMSmeCore

struct SubscribeChannelCellViewModelMapper {
    private init() {}

    static func cellViewModelFor(channelGuid: String) -> SubscribeChannelCellViewModel? {
        guard let channel = DPAGApplicationFacade.cache.channel(for: channelGuid) else {
            return nil
        }

        let name = channel.name_short
        let description = channel.name_long
        let isSubscribed = channel.isSubscribed

        let assets = DPAGApplicationFacade.feedWorker.assetsList(feedGuid: channelGuid)
        let imageIcon = assets[.profile] as? UIImage

        let cellViewModel = SubscribeChannelCellViewModel(name: name, description: description, image: imageIcon, showCheckMark: isSubscribed)
        return cellViewModel
    }
}
