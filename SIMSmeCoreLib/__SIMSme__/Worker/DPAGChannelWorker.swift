//
//  DPAGFeedWorker.swift
//  SIMSme
//
//  Created by RBU on 25/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

public protocol DPAGFeedWorkerProtocol: AnyObject {
    func subscribeFeed(feedGuid: String, filter: String, feedType: DPAGChannelType, responseBlock: @escaping DPAGServiceResponseBlock)
    func unsubscribeFeed(feedGuid: String, feedType: DPAGChannelType, responseBlock: @escaping DPAGServiceResponseBlock)

    func assetsPromoted(feedGuid: String) -> [DPAGChannel.AssetType: Any]
    func assetsList(feedGuid: String) -> [DPAGChannel.AssetType: Any]
    func assetsChat(feedGuid: String) -> [DPAGChannel.AssetType: Any]
    func assetsMessage(feedGuid: String) -> [DPAGChannel.AssetType: Any]
    func loadChannelCategories(completion: @escaping (_ categories: [DPAGChannelCategory]) -> Void)
    func setFeedNotification(enabled: Bool, feedGuid: String, feedType: DPAGChannelType, withResponse responseBlock: @escaping DPAGServiceResponseBlock)
    func updateFeeds(feedGuids: [String], feedType: DPAGChannelType, feedUpdatedBlock: (([String], String?, String?) -> Void)?)
    func updatedFeedListWithFeedsToUpdate(forFeedType feedType: DPAGChannelType, block: (([String], [String], String?) -> Void)?)
    func updateAssets(feedGuids: [String], feedType: DPAGChannelType, completion: @escaping DPAGCompletion)
    func updateFeedAssets(feedGuids: [String], feedAssetIdentifier: [String], feedType: DPAGChannelType, completion: @escaping DPAGCompletion)
    func updateChannelAssets(models: [ChannelGetAssetModel], feedType: DPAGChannelType, completion: ChannelGetAssetsCompletion?)
    func checkServiceAvailability(serviceID: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock)
    func checkServiceAvailability(serviceID: String, zipCode: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock)

    func checkFeedbackContactPhoneNumber(feedbackContactPhoneNumber: String, feedbackContactNickname: String?)
}

public struct ChannelLinkReplaceInfo {
    public let content: String
    public let urlContentLink: URL?
    public let rangeLink: NSRange?
}

public struct ServiceLinkReplaceInfo {
    public let content: String
    public let urlContentLinks: [(urlContentLink: URL, rangeLink: NSRange)]
}

public struct ChannelGetAssetModel {
    public let channelId: String
    public let assetTypes: [DPAGChannel.AssetType]
    public init(channelId: String, assetTypes: [DPAGChannel.AssetType]) {
        self.channelId = channelId
        self.assetTypes = assetTypes
    }
}

public struct ChannelGetAssetResult {
    public let channelId: String
    public let assets: [DPAGChannel.AssetType: Data?]
}

public typealias ChannelGetAssetsCompletion = (([ChannelGetAssetResult]?) -> Void)

public protocol DPAGFeedWorkerProtocolSwift: AnyObject {
    func replaceChannelLink(_ content: String, contentLinkReplacer: String?) -> ChannelLinkReplaceInfo
    func replaceServiceLinks(_ content: String, contentLinkReplacerRegex: [DPAGContentLinkReplacerRegex]) -> ServiceLinkReplaceInfo
}

class DPAGFeedWorker: DPAGFeedWorkerProtocol, DPAGFeedWorkerProtocolSwift {
    private let feedDAO: FeedDAOProtocol = FeedDAO()

    func checkFeedbackContactPhoneNumber(feedbackContactPhoneNumber: String, feedbackContactNickname: String?) {
        guard feedbackContactPhoneNumber.isEmpty == false else { return }

        var phoneNumberNormalized = ""

        if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) {
            phoneNumberNormalized = DPAGCountryCodes.sharedInstance.normalizePhoneNumber(feedbackContactPhoneNumber, countryCodeAccount: DPAGCountryCodes.sharedInstance.countryCodeByPhone(contact.phoneNumber))
        }

        let nickName = feedbackContactNickname

        guard DPAGApplicationFacade.contactsWorker.findContactStream(forPhoneNumbers: [phoneNumberNormalized]) == nil else { return }

        var phoneHashes = [String]()

        let mandanten = DPAGApplicationFacade.preferences.mandanten

        for mandant in mandanten {
            phoneHashes.append(DPAGApplicationFacade.cache.hash(accountSearchAttribute: phoneNumberNormalized, withSalt: mandant.salt))
        }

        let responseBlock: DPAGServiceResponseBlock = { responseObject, _, errorMessage in

            guard errorMessage == nil,
                let responseArray = responseObject as? [[String: Any]],
                let responseDict = responseArray.first,
                let dictAccountInfo = responseDict[DPAGStrings.JSON.Account.OBJECT_KEY] as? [String: Any],
                let accountGuid = dictAccountInfo["guid"] as? String else {
                return
            }

            let contact = DPAGApplicationFacade.cache.contact(for: accountGuid)
            let isPublicKeyEmpty = (contact?.publicKey?.isEmpty ?? true) == false
            let isPhoneNumberEmpty = (contact?.phoneNumber?.isEmpty ?? true) == false

            guard isPublicKeyEmpty == false || isPhoneNumberEmpty == false else {
                return
            }

            var dictAccountInfoMutable = dictAccountInfo

            // set phone if an incomplete contact was found
            dictAccountInfoMutable[SIMS_PHONE] = phoneNumberNormalized

            self.feedDAO.saveAccountInfoDictionary(dictAccountInfo: dictAccountInfoMutable, nickName: nickName)
        }
        DPAGApplicationFacade.contactsWorker.getKnownAccounts(hashedPhoneNumbers: phoneHashes, response: responseBlock)
    }

    func subscribeFeed(feedGuid: String, filter: String, feedType: DPAGChannelType, responseBlock: @escaping DPAGServiceResponseBlock) {
        let block: DPAGServiceResponseBlock = { responseObject, errorCode, errorMessage in

            if errorMessage != nil {
                responseBlock(nil, errorCode, errorMessage)
            } else if feedGuid == (responseObject as? [String])?.first {
                _ = DPAGApplicationFacade.cache.channel(for: feedGuid)?.isSubscribed ?? true
                self.feedDAO.setFeedSubscribed(feedGuid: feedGuid)
                DPAGApplicationFacade.preferences.rememberChannelSubscribed(feedGuid)
                responseBlock(responseObject, errorCode, errorMessage)
            } else {
                responseBlock(responseObject, "Invalid response", "Invalid response")
            }
        }

        switch feedType {
        case .channel:
            DPAGApplicationFacade.server.subscribeChannel(channelGuid: feedGuid, filter: filter, withResponse: block)
        case .service:
            DPAGApplicationFacade.server.subscribeService(serviceGuid: feedGuid, filter: filter, withResponse: block)
        }
    }

    public func unsubscribeFeed(feedGuid: String, feedType: DPAGChannelType, responseBlock: @escaping DPAGServiceResponseBlock) {
        let block: DPAGServiceResponseBlock = { responseObject, errorCode, errorMessage in

            if errorMessage != nil {
                responseBlock(nil, errorCode, errorMessage)
            } else {
                self.feedDAO.setFeedUnsubscribed(feedGuid: feedGuid, feedType: feedType)
                responseBlock(responseObject, errorCode, errorMessage)
            }
        }

        switch feedType {
        case .channel:
            DPAGApplicationFacade.server.unsubscribeChannel(channelGuid: feedGuid, withResponse: block)
        case .service:
            DPAGApplicationFacade.server.unsubscribeService(serviceGuid: feedGuid, withResponse: block)
        }
    }

    public func assetsPromoted(feedGuid: String) -> [DPAGChannel.AssetType: Any] {
        self.assetsWithType(feedGuid: feedGuid, assetTypes: [.itemPromotedBackground, .itemPromotedBackground], cacheImage: true)
    }

    public func assetsList(feedGuid: String) -> [DPAGChannel.AssetType: Any] {
        self.assetsWithType(feedGuid: feedGuid, assetTypes: [.itemForeground, .itemBackground, .profile], cacheImage: true)
    }

    public func assetsChat(feedGuid: String) -> [DPAGChannel.AssetType: Any] {
        self.assetsWithType(feedGuid: feedGuid, assetTypes: [.chatBackground, .profile], cacheImage: true)
    }

    public func assetsMessage(feedGuid: String) -> [DPAGChannel.AssetType: Any] {
        self.assetsWithType(feedGuid: feedGuid, assetTypes: [.profile], cacheImage: true)
    }

    public func assetsWithType(feedGuid: String, assetTypes: [DPAGChannel.AssetType], cacheImage: Bool) -> [DPAGChannel.AssetType: Any] {
        var retVal: [DPAGChannel.AssetType: Any] = [:]
        var assetTypesMissing: [DPAGChannel.AssetType] = []

        for assetType in assetTypes {
            if let image = DPAGApplicationFacade.cache.cachedImage(streamGuid: feedGuid, type: assetType, scale: UIScreen.main.scale) {
                retVal[assetType] = image
            } else {
                assetTypesMissing.append(assetType)
            }
        }

        if assetTypesMissing.count > 0 {
            let assetsMissing = self.feedDAO.assetsWithType(feedGuid: feedGuid, assetTypes: assetTypesMissing)

            if cacheImage {
                for (assetType, value) in assetsMissing {
                    if let image = value as? UIImage {
                        DPAGApplicationFacade.cache.setCachedImage(image, streamGuid: feedGuid, type: assetType, scale: UIScreen.main.scale)
                    }
                }
            }

            retVal.merge(assetsMissing, uniquingKeysWith: { _, v2 in v2 })
        }

        return retVal
    }

    public func replaceChannelLink(_ content: String, contentLinkReplacer: String?) -> ChannelLinkReplaceInfo {
        if let replacer = contentLinkReplacer, replacer.isEmpty == false {
            if let regex = try? NSRegularExpression(pattern: "https?://[^\\s]+", options: .caseInsensitive) {
                let contentAsNSString = (content as NSString)
                let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: contentAsNSString.length))

                if let match = matches.last {
                    let rangeLink = match.range
                    let urlContentLink = URL(string: contentAsNSString.substring(with: match.range))

                    let retVal = contentAsNSString.replacingCharacters(in: rangeLink, with: replacer)

                    let rangeLinkRetVal = NSRange(location: rangeLink.location, length: (replacer as NSString).length)

                    return ChannelLinkReplaceInfo(content: retVal, urlContentLink: urlContentLink, rangeLink: rangeLinkRetVal)
                }
            }
        }

        return ChannelLinkReplaceInfo(content: content, urlContentLink: nil, rangeLink: nil)
    }

    public func replaceServiceLinks(_ content: String, contentLinkReplacerRegex: [DPAGContentLinkReplacerRegex]) -> ServiceLinkReplaceInfo {
        var retValContent = content
        if content.last == " " {} else {
            retValContent.append(" ")
        }
        var retValMatches: [(urlContentLink: URL, rangeLink: NSRange)] = []

        guard let regexHTTP = try? NSRegularExpression(pattern: "https?://[^\\s]+", options: .caseInsensitive) else {
            return ServiceLinkReplaceInfo(content: retValContent, urlContentLinks: retValMatches)
        }

        var matchesAll: [(match: NSTextCheckingResult, replacer: DPAGContentLinkReplacerRegex)] = []

        let matchesHTTP = regexHTTP.matches(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count))

        for matchHTTP in matchesHTTP {
            guard let rangeMatch = Range(matchHTTP.range, in: content) else {
                continue
            }

            let matchContent = String(retValContent[rangeMatch])

            for replacer in contentLinkReplacerRegex {
                if replacer.regEx.firstMatch(in: matchContent, options: [], range: NSRange(location: 0, length: matchContent.utf16.count)) != nil {
                    if matchesAll.contains(where: { (result) -> Bool in
                        if matchHTTP.range.location < result.match.range.location {
                            if matchHTTP.range.location + matchHTTP.range.length >= result.match.range.location {
                                return true
                            }
                        } else if result.match.range.location + result.match.range.length >= matchHTTP.range.location {
                            return true
                        }
                        return false
                    }) == false {
                        matchesAll.append((matchHTTP, replacer))
                    }
                }
            }
        }

        matchesAll.sort { (result1, result2) -> Bool in
            result1.match.range.location < result2.match.range.location
        }
        matchesAll.reverse()

        for match in matchesAll {
            guard let rangeLink = Range(match.match.range, in: retValContent) else {
                continue
            }

            let urlString = String(retValContent[rangeLink])

            guard let urlContentLink = URL(string: urlString) else { continue }

            // retValContent = retValContent.replacingCharacters(in: rangeLink, with: match.replacer.replacer)

            retValContent.replaceSubrange(rangeLink, with: match.replacer.replacer)

            let rangeLinkRetVal = NSRange(location: match.match.range.location, length: match.replacer.replacer.utf16.count)
            let offset = urlString.utf16.count - match.replacer.replacer.utf16.count

            var retValMatchesWithOffset: [(urlContentLink: URL, rangeLink: NSRange)] = []

            for retValMatch in retValMatches {
                var retValMatchOffset = retValMatch

                retValMatchOffset.rangeLink = NSRange(location: retValMatch.rangeLink.location - offset, length: retValMatch.rangeLink.length)

                retValMatchesWithOffset.append(retValMatchOffset)
            }

            retValMatches = retValMatchesWithOffset

            retValMatches.append((urlContentLink: urlContentLink, rangeLink: rangeLinkRetVal))
        }

        return ServiceLinkReplaceInfo(content: retValContent, urlContentLinks: retValMatches)
    }

    public func loadChannelCategories(completion: @escaping (_ categories: [DPAGChannelCategory]) -> Void) {
        DPAGApplicationFacade.server.getChannelCategories { responseObject, _, errorMessage in

            if let responseDict = responseObject as? [[String: Any]], responseDict.count > 0, errorMessage == nil {
                var categories: [DPAGChannelCategory] = []

                for dictCat in responseDict {
                    if let dictCategory = dictCat["Category"] as? [String: Any] {
                        let category = DPAGChannelCategory(dictCategory: dictCategory)

                        if (category.channelGuids?.count ?? 0) > 0 {
                            categories.append(category)
                        }
                    }
                }

                completion(categories)
            } else {
                completion([])
            }
        }
    }

    public func setFeedNotification(enabled: Bool, feedGuid: String, feedType: DPAGChannelType, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.setChannelNotification(enable: enabled, forChannel: feedGuid) { responseObject, errorCode, errorMessage in
            if errorMessage == nil {
                switch feedType {
                case .channel:
                    DPAGApplicationFacade.preferences[String(format: "%@-%@", feedGuid, DPAGPreferences.PropString.kNotificationChannelChatEnabled.rawValue)] = (enabled ? DPAGPreferences.kValueNotificationEnabled : DPAGPreferences.kValueNotificationDisabled)
                case .service:
                    DPAGApplicationFacade.preferences[String(format: "%@-%@", feedGuid, DPAGPreferences.PropString.kNotificationServiceChatEnabled.rawValue)] = (enabled ? DPAGPreferences.kValueNotificationEnabled : DPAGPreferences.kValueNotificationDisabled)
                }
            }
            responseBlock(responseObject, errorCode, errorMessage)
        }
    }

    public func updateFeeds(feedGuids: [String], feedType: DPAGChannelType, feedUpdatedBlock: (([String], String?, String?) -> Void)?) {
        guard feedGuids.count > 0 else {
            feedUpdatedBlock?([], nil, nil)
            return
        }

        let responseBlock: DPAGServiceResponseBlock = { responseObject, errorCode, errorMessage in

            guard let feedsWithDetails = responseObject as? [[String: Any]] else {
                feedUpdatedBlock?(feedGuids, errorCode, errorMessage)
                return
            }

            let feedGuidsUpdated = self.feedDAO.updateFeeds(feedsWithDetails: feedsWithDetails)

            feedGuidsUpdated.forEach { feedGuid in
                for assetType in DPAGChannel.AssetType.allCases {
                    DPAGApplicationFacade.cache.setCachedImage(nil, streamGuid: feedGuid, type: assetType, scale: UIScreen.main.scale)
                }
            }

            self.updateAssets(feedGuids: feedGuidsUpdated, feedType: feedType) {
                let result = self.feedDAO.getFeedOptions(forFeedGuids: feedGuidsUpdated)

                for feedGuid in feedGuidsUpdated {
                    if let filter = result.feedGuidsRecommended[feedGuid] {
                        // Wurde der Kanal schonmal automatisch subscribed
                        if DPAGApplicationFacade.preferences.wasChannelSubscribed(feedGuid) {
                            continue
                        }

                        // Channel subscriben
                        self.subscribeFeed(feedGuid: feedGuid, filter: filter, feedType: feedType) { _, _, _ in
                        }
                    } else if result.feedGuidsMandantory.contains(feedGuid) {
                        self.subscribeFeed(feedGuid: feedGuid, filter: "", feedType: feedType) { _, _, _ in
                        }
                    }
                }
            }

            feedUpdatedBlock?(feedGuids, errorCode, errorMessage)
        }

        switch feedType {
        case .channel:
            DPAGApplicationFacade.server.getChannelDetails(channelGuids: feedGuids, withResponse: responseBlock)
        case .service:
            DPAGApplicationFacade.server.getServiceDetails(serviceGuids: feedGuids, withResponse: responseBlock)
        }
    }

    public func updatedFeedListWithFeedsToUpdate(forFeedType feedType: DPAGChannelType, block: (([String], [String], String?) -> Void)?) {
        let responseBlock: DPAGServiceResponseBlock = { responseObject, _, errorMessage in

            if Thread.isMainThread {
                assert(false)
            }

            var feedGuids: [String] = []
            var feedGuidsToUpdate: [String] = []

            if errorMessage == nil, let feedsWithChecksum = responseObject as? [[String: Any]] {
                let result = self.feedDAO.saveServerFeeds(feedsWithChecksum: feedsWithChecksum, feedType: feedType)

                feedGuids = result.feedGuids
                feedGuidsToUpdate = result.feedGuidsToUpdate
            }

            block?(feedGuids, feedGuidsToUpdate, errorMessage)
        }

        switch feedType {
        case .channel:
            DPAGApplicationFacade.server.getChannels(withResponse: responseBlock)
        case .service:
            DPAGApplicationFacade.server.getServices(withResponse: responseBlock)
        }
    }

    public func updateAssets(feedGuids: [String], feedType: DPAGChannelType, completion: @escaping DPAGCompletion) {
        let feedAssetIdentifier = self.feedDAO.getNeededAssetsIdentifier(feedGuids: feedGuids)

        self.updateFeedAssets(feedGuids: feedGuids, feedAssetIdentifier: feedAssetIdentifier, feedType: feedType, completion: completion)
    }

    public func updateFeedAssets(feedGuids _: [String], feedAssetIdentifier: [String], feedType: DPAGChannelType, completion: @escaping DPAGCompletion) {
        if feedAssetIdentifier.count == 0 {
            completion()
            return
        }

        let responseBlockAsset: DPAGServiceResponseBlock = { responseObject, _, _ in

            if let feedAssetDictionary = responseObject as? [String: Any] {
                let newAssetsforFeeds = self.feedDAO.updateFeedAssets(feedAssetDictionary: feedAssetDictionary)

                for (feedGuid, feedAssetTypesUpdated) in newAssetsforFeeds {
                    feedAssetTypesUpdated.forEach { assetType in
                        DPAGApplicationFacade.cache.setCachedImage(nil, streamGuid: feedGuid, type: assetType, scale: UIScreen.main.scale)
                    }
                }
            }
            completion()
        }

        switch feedType {
        case .channel:
            DPAGApplicationFacade.server.getChannelAssets(channelAssets: feedAssetIdentifier, withResponse: responseBlockAsset)
        case .service:
            DPAGApplicationFacade.server.getServiceAssets(serviceAssetIdents: feedAssetIdentifier, withResponse: responseBlockAsset)
        }
    }

    func updateChannelAssets(models: [ChannelGetAssetModel], feedType: DPAGChannelType, completion: ChannelGetAssetsCompletion?) {
        if models.count == 0 {
            completion?(nil)
            return
        }

        let responseBlockAsset: DPAGServiceResponseBlock = { responseObject, _, errorMessage in
            self.processGetChannelsAssetsResponse(responseObject: responseObject, errorMessage: errorMessage, models: models, completion: completion)
        }

        var assetRequestIdents = [String]()
        models.forEach {
            assetRequestIdents.append(contentsOf: self.mapGetAssetModelToRequestIdent(model: $0))
        }

        switch feedType {
        case .channel:
            DPAGApplicationFacade.server.getChannelAssets(channelAssets: assetRequestIdents, withResponse: responseBlockAsset)
        case .service:
            DPAGApplicationFacade.server.getServiceAssets(serviceAssetIdents: assetRequestIdents, withResponse: responseBlockAsset)
        }
    }

    public func checkServiceAvailability(serviceID: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.checkServiceAvailability(serviceID: serviceID, withResponse: responseBlock)
    }

    public func checkServiceAvailability(serviceID: String, zipCode: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.checkServiceAvailability(serviceID: serviceID, zipCode: zipCode, withResponse: responseBlock)
    }
}

// MARK: - Private

extension DPAGFeedWorker {
    private func processGetChannelsAssetsResponse(responseObject: Any?, errorMessage: String?, models _: [ChannelGetAssetModel], completion: ChannelGetAssetsCompletion?) {
        guard errorMessage == nil,
            let responseDict = responseObject as? [String: Any] else {
            completion?(nil)
            return
        }

        let resultArray = self.feedDAO.processGetChannelsAssetsResponse(responseDict: responseDict)

        completion?(resultArray)
    }

    private func mapGetAssetModelToRequestIdent(model: ChannelGetAssetModel) -> [String] {
        let channelId = model.channelId
        return model.assetTypes.map { "\(channelId);\($0.rawValue)" }
    }
}
