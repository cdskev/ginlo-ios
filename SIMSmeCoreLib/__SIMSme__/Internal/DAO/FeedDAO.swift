//
//  FeedDAO.swift
//  SIMSmeCore
//
//  Created by Robert Burchert on 28.08.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import Foundation

protocol FeedDAOProtocol {
    func saveAccountInfoDictionary(dictAccountInfo: [AnyHashable: Any], nickName: String?)
    func setFeedSubscribed(feedGuid: String)
    func setFeedUnsubscribed(feedGuid: String, feedType: DPAGChannelType)
    func assetsWithType(feedGuid: String, assetTypes: [DPAGChannel.AssetType]) -> [DPAGChannel.AssetType: Any]
    func updateFeeds(feedsWithDetails: [[String: Any]]) -> [String]
    func getFeedOptions(forFeedGuids feedGuids: [String]) -> (feedGuidsMandantory: [String], feedGuidsRecommended: [String: String])
    func saveServerFeeds(feedsWithChecksum: [[String: Any]], feedType: DPAGChannelType) -> (feedGuids: [String], feedGuidsToUpdate: [String])
    func getNeededAssetsIdentifier(feedGuids: [String]) -> [String]
    func updateFeedAssets(feedAssetDictionary: [String: Any]) -> [String: [DPAGChannel.AssetType]]
    func processGetChannelsAssetsResponse(responseDict: [String: Any]) -> [ChannelGetAssetResult]
}

class FeedDAO: FeedDAOProtocol {
    func saveAccountInfoDictionary(dictAccountInfo: [AnyHashable: Any], nickName: String?) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            DPAGApplicationFacade.updateKnownContactsWorker.handleAccountDict(dictAccountInfo: dictAccountInfo, nickNameNew: nickName, in: localContext)
        }
    }

    func setFeedSubscribed(feedGuid: String) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            guard let feed = SIMSChannel.findFirst(byGuid: feedGuid, in: localContext) else { return }
            if feed.stream == nil, let stream = SIMSChannelStream.mr_createEntity(in: localContext) {
                stream.guid = feed.guid
                stream.isConfirmed = true
                stream.typeStream = .channel
                stream.optionsStream = DPAGApplicationFacade.preferences.streamVisibilityChannel ? [] : [.filtered]
                feed.stream = stream
            }
            guard (feed.subscribed?.boolValue ?? false) == false else { return }
            feed.subscribed = true
            var content = feed.welcomeText
            if content?.isEmpty ?? true, let name_short = feed.name_short {
                let format = DPAGLocalizedString("channel.welcome.format")
                content = String(format: format, name_short)
            }
            if let content = content {
                DPAGApplicationFacade.messageFactory.newSystemMessage(content: content, forChannel: feed, in: localContext)
            }
        }
    }

    func setFeedUnsubscribed(feedGuid: String, feedType: DPAGChannelType) {
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            guard let feed = SIMSChannel.findFirst(byGuid: feedGuid, in: localContext) else { return }
            if let stream = feed.stream, let streamGuid = stream.guid {
                DPAGApplicationFacade.cache.removeStream(guid: streamGuid)
                stream.messages?.enumerateObjects { msgObj, _, _ in
                    if let msg = msgObj as? SIMSMessage {
                        DPAGApplicationFacade.persistance.deleteMessage(msg, in: localContext)
                    }
                }
                stream.mr_deleteEntity()
            }
            feed.subscribed = NSNumber(value: false)
        }
    }

    func assetsWithType(feedGuid: String, assetTypes: [DPAGChannel.AssetType]) -> [DPAGChannel.AssetType: Any] {
        var retVal: [DPAGChannel.AssetType: Any] = [:]
        DPAGApplicationFacade.persistance.loadWithBlock { localContext in
            guard let channelAssets = SIMSChannel.findFirst(byGuid: feedGuid, in: localContext)?.assets else { return }
            for asset in channelAssets {
                guard let assetTypeRaw = asset.type, let assetType = DPAGChannel.AssetType(rawValue: assetTypeRaw), let assetData = asset.data, assetTypes.contains(assetType) else { continue }
                if let data = Data(base64Encoded: assetData, options: .ignoreUnknownCharacters), let image = UIImage(data: data, scale: UIScreen.main.scale) {
                    retVal[assetType] = image
                } else {
                    // set but not existing
                    retVal[assetType] = ""
                }
            }
        }
        return retVal
    }

    func updateFeeds(feedsWithDetails: [[String: Any]]) -> [String] {
        var feedGuidsUpdated: [String] = []
        var feedCount = 6
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            for feedDetailsDict in feedsWithDetails {
                guard let feedDetails = feedDetailsDict[DPAGStrings.JSON.Channel.OBJECT_KEY_CHANNEL] as? [String: Any] ?? feedDetailsDict[DPAGStrings.JSON.Channel.OBJECT_KEY_SERVICE] as? [String: Any], let channelGuid = feedDetails[DPAGStrings.JSON.Channel.GUID] as? String else {
                    continue
                }
                if let channel = SIMSChannel.findFirst(byGuid: channelGuid, in: localContext) {
                    channel.updateWithDictionary(feedDetails)
                    // remove all assets
                    for asset in channel.assets ?? Set() {
                        asset.channel = nil
                        asset.mr_deleteEntity(in: localContext)
                    }
                    let subscribed = channel.subscribed?.boolValue ?? false
                    if channel.isPromoted || channel.isMandatory || channel.isRecommended || subscribed {
                        feedGuidsUpdated.append(channelGuid)
                    } else if feedCount > 0 {
                        feedGuidsUpdated.append(channelGuid)
                        feedCount -= 1
                    }
                } else if let channel = SIMSChannel.mr_createEntity(in: localContext) {
                    let channelDescShort = feedDetails[DPAGStrings.JSON.Channel.DESC_SHORT] as? String
                    channel.guid = channelGuid
                    channel.name_short = channelDescShort
                    channel.updateWithDictionary(feedDetails)
                    if channel.isPromoted || channel.isMandatory || channel.isRecommended {
                        feedGuidsUpdated.append(channelGuid)
                    } else if feedCount > 0 {
                        feedGuidsUpdated.append(channelGuid)
                        feedCount -= 1
                    }
                }
            }
        }
        return feedGuidsUpdated
    }

    func getFeedOptions(forFeedGuids feedGuids: [String]) -> (feedGuidsMandantory: [String], feedGuidsRecommended: [String: String]) {
        var feedGuidsMandantory: [String] = []
        var feedGuidsRecommended: [String: String] = [:]
        DPAGApplicationFacade.persistance.loadWithBlock { localContext in
            for feedGuid in feedGuids {
                guard let channel = SIMSChannel.findFirst(byGuid: feedGuid, in: localContext) else { continue }
                if channel.isMandatory {
                    feedGuidsMandantory.append(feedGuid)
                }
                if channel.isRecommended {
                    feedGuidsRecommended[feedGuid] = channel.currentFilter()
                }
            }
        }
        return (feedGuidsMandantory, feedGuidsRecommended)
    }

    func saveServerFeeds(feedsWithChecksum: [[String: Any]], feedType: DPAGChannelType) -> (feedGuids: [String], feedGuidsToUpdate: [String]) {
        var feedGuids: [String] = []
        var feedGuidsToUpdate: [String] = []
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            var feedGuidsExisting: [String] = []
            for feedWithChecksumDict in feedsWithChecksum {
                guard let feedWithCheckSum = feedWithChecksumDict[DPAGStrings.JSON.Channel.OBJECT_KEY_CHANNEL] as? [String: Any] ?? feedWithChecksumDict[DPAGStrings.JSON.Channel.OBJECT_KEY_SERVICE] as? [String: Any],
                    let channelGuid = feedWithCheckSum[DPAGStrings.JSON.Channel.GUID] as? String,
                    let channelDescShort = feedWithCheckSum[DPAGStrings.JSON.Channel.DESC_SHORT] as? String,
                    let channelChecksum = feedWithCheckSum[DPAGStrings.JSON.Channel.CHECKSUM] as? String else {
                    continue
                }
                feedGuidsExisting.append(channelGuid)
                guard let channel = SIMSChannel.findFirst(byGuid: channelGuid, in: localContext) ?? SIMSChannel.mr_createEntity(in: localContext) else { continue }
                channel.guid = channelGuid
                channel.name_short = channelDescShort
                channel.feedType = NSNumber(value: feedType.rawValue)
                feedGuids.append(channelGuid)
                if channel.checksum != channelChecksum
                    || channel.aes_key == nil
                    || (channel.contentLinkReplacer?.isEmpty ?? true) {
                    feedGuidsToUpdate.append(channelGuid)
                    channel.checksum = channelChecksum
                }
            }
            self.markDeletedChannels(feedGuidsExisting: feedGuidsExisting, feedType: feedType, in: localContext)
        }
        return (feedGuids, feedGuidsToUpdate)
    }

    private func markDeletedChannels(feedGuidsExisting: [String], feedType: DPAGChannelType, in localContext: NSManagedObjectContext) {
        let predicateFeedsForFeedType = NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSChannel.feedType), rightExpression: NSExpression(forConstantValue: feedType.rawValue))

        guard let feedsForFeedType = SIMSChannel.mr_findAll(with: predicateFeedsForFeedType, in: localContext) else { return }
        for channelObj in feedsForFeedType {
            guard let channel = channelObj as? SIMSChannel,
                let channelGuid = channel.guid,
                feedGuidsExisting.contains(channelGuid) == false,
                channel.stream != nil else {
                continue
            }
            DPAGApplicationFacade.messageFactory.newSystemMessage(content: DPAGLocalizedString("chat.channel.wasDeleted"), forChannel: channel, in: localContext)
            channel.stream?.wasDeleted = true
        }
    }

    func getNeededAssetsIdentifier(feedGuids: [String]) -> [String] {
        var feedAssetIdentifier: [String] = []
        DPAGApplicationFacade.persistance.loadWithBlock { localContext in
            for feedGuid in feedGuids {
                guard let channel = SIMSChannel.findFirst(byGuid: feedGuid, in: localContext) else { continue }
                var needsListBackground = true
                var needsListForeground = true
                var needsPromoBackground = true
                var needsPromoForeground = true
                if channel.isPromoted == false {
                    needsPromoBackground = false
                    needsPromoForeground = false
                }
                var needsProfileIcon = (channel.subscribed?.boolValue ?? false)
                for channelAsset in channel.assets ?? Set() {
                    guard let assetTypeRaw = channelAsset.type, let assetType = DPAGChannel.AssetType(rawValue: assetTypeRaw) else { continue }
                    switch assetType {
                        case .itemBackground:
                            needsListBackground = false
                        case .itemForeground:
                            needsListForeground = false
                        case .itemPromotedBackground:
                            needsPromoBackground = false
                        case .itemPromotedForeground:
                            needsPromoForeground = false
                        case .profile:
                            needsProfileIcon = false
                        default:
                            break
                    }
                }
                if channel.colorChatListBackground != nil {
                    needsListBackground = false
                }
                if needsListBackground {
                    feedAssetIdentifier.append("\(feedGuid);\(DPAGChannel.AssetType.itemBackground.rawValue)")
                }
                if needsListForeground {
                    feedAssetIdentifier.append("\(feedGuid);\(DPAGChannel.AssetType.itemForeground.rawValue)")
                }
                if needsPromoBackground {
                    feedAssetIdentifier.append("\(feedGuid);\(DPAGChannel.AssetType.itemPromotedBackground.rawValue)")
                }
                if needsPromoForeground {
                    feedAssetIdentifier.append("\(feedGuid);\(DPAGChannel.AssetType.itemPromotedForeground.rawValue)")
                }
                if needsProfileIcon {
                    feedAssetIdentifier.append("\(feedGuid);\(DPAGChannel.AssetType.profile.rawValue)")
                }
            }
        }
        return feedAssetIdentifier
    }

    func updateFeedAssets(feedAssetDictionary: [String: Any]) -> [String: [DPAGChannel.AssetType]] {
        var newAssetsforFeeds: [String: [DPAGChannel.AssetType]] = [:]
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            var feedGuidsAndStreams: [String: SIMSMessageStream] = [:]
            for (feedAssetIdent, feedAssetDataObj) in feedAssetDictionary {
                let feedAssetIdents = feedAssetIdent.components(separatedBy: ";")
                guard feedAssetIdents.count == 2 else { continue }
                let channelGuid = feedAssetIdents[0]
                guard let channel = SIMSChannel.findFirst(byGuid: channelGuid, in: localContext), let feedAssetData = feedAssetDataObj as? String else { continue }
                feedGuidsAndStreams[channelGuid] = channel.stream
                let assetTypeRaw = feedAssetIdents[1]
                var asset = channel.assets?.first { (assetExisting) -> Bool in
                    assetTypeRaw == assetExisting.type
                }
                if asset == nil {
                    asset = SIMSChannelAsset.mr_createEntity(in: localContext)
                    asset?.type = assetTypeRaw
                    asset?.channel = channel
                }
                asset?.data = feedAssetData.isEmpty ? nil : feedAssetData
                if let assetType = DPAGChannel.AssetType(rawValue: assetTypeRaw) {
                    var updatedAssetTypes = newAssetsforFeeds[channelGuid] ?? []
                    updatedAssetTypes.append(assetType)
                    newAssetsforFeeds[channelGuid] = updatedAssetTypes
                }
            }
            for (feedGuid, feedStream) in feedGuidsAndStreams {
                DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: feedGuid, stream: feedStream, in: localContext)
            }
        }
        return newAssetsforFeeds
    }

    func processGetChannelsAssetsResponse(responseDict: [String: Any]) -> [ChannelGetAssetResult] {
        var resultArray: [ChannelGetAssetResult] = []
        DPAGApplicationFacade.persistance.saveWithBlock { localContext in
            var updatedStreams: [String: SIMSMessageStream] = [:]
            for (assetResponseIdent, assetData) in responseDict {
                guard let assetData = assetData as? String,
                    let assetParameters = self.mapAssetResponseIdentToAssetParameters(assetResponseIdent:
                        assetResponseIdent),
                    let asset = self.extractChannelAsset(channelGuid: assetParameters.channelId, assetType: assetParameters.assetType, localContext: localContext) else {
                    continue
                }
                asset.data = assetData.isEmpty ? nil : assetData
                let result = self.createGetAssetResult(assetData: asset.data, channelId: assetParameters.channelId, assetType: assetParameters.assetType)
                resultArray.append(result)
                updatedStreams[assetParameters.channelId] = asset.channel?.stream
            }
            // have no idea why we do it, but it was like this in the old method
            for (feedGuid, feedStream) in updatedStreams {
                DPAGApplicationFacade.cache.updateDecryptedStream(streamGuid: feedGuid, stream: feedStream, in: localContext)
            }
        }
        return resultArray
    }

    private func createGetAssetResult(assetData: String?, channelId: String, assetType: DPAGChannel.AssetType) -> ChannelGetAssetResult {
        let image = self.getImageDataFromAssetData(assetData: assetData)
        return ChannelGetAssetResult(channelId: channelId, assets: [assetType: image])
    }

    private func mapAssetResponseIdentToAssetParameters(assetResponseIdent: String) -> (channelId: String, assetType: DPAGChannel.AssetType)? {
        let components = assetResponseIdent.components(separatedBy: ";")
        guard components.count == 2 else { return nil }
        let channelId = components[0]
        guard let assetType = DPAGChannel.AssetType(rawValue: components[1]) else { return nil }
        return (channelId, assetType)
    }

    private func getImageDataFromAssetData(assetData: String?) -> Data? {
        guard let assetData = assetData else { return nil }
        let data = Data(base64Encoded: assetData, options: .ignoreUnknownCharacters)
        return data
    }

    private func extractChannelAsset(channelGuid: String, assetType: DPAGChannel.AssetType, localContext: Any?) -> SIMSChannelAsset? {
        guard let localContext = localContext as? NSManagedObjectContext, let channel = SIMSChannel.findFirst(byGuid: channelGuid, in: localContext) else { return nil }
        let existingAsset = channel.assets?.first {
            $0.type == assetType.rawValue
        }
        let assetResult = existingAsset ?? self.createNewAsset(localContext: localContext, assetType: assetType, channel: channel)
        return assetResult
    }

    private func createNewAsset(localContext: NSManagedObjectContext, assetType: DPAGChannel.AssetType, channel: SIMSChannel) -> SIMSChannelAsset? {
        let asset = SIMSChannelAsset.mr_createEntity(in: localContext)
        asset?.type = assetType.rawValue
        asset?.channel = channel
        return asset
    }
}
