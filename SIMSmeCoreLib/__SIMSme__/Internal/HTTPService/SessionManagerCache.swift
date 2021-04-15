//
//  SessionManagerCache.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 08.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

protocol SessionManagerCacheProtocol {
    func getCachedSessionManager(forConfigurationType configurationType: RequestConfigurationType) -> DPAGHTTPSessionManager?
    func cacheSessionManager(manager: DPAGHTTPSessionManager, configurationType: RequestConfigurationType)
    func removeCachedSessionManager(configurationType: RequestConfigurationType)
    func getCachedSessionManager(identifier: String) -> DPAGHTTPSessionManager?
    func autoDownloadManagersCount() -> Int
    func removeCachedSessionManager(identifier: String)
    func getAllCachedSessionManagers() -> [String: DPAGHTTPSessionManager]
    func getCachedSessionManagers(forContentType contentType: RequestConfigurationAttachmentContentType) -> [String: DPAGHTTPSessionManager]
    func removeCachedSessionManagers(managersDict: [String: DPAGHTTPSessionManager])
}

private let kSessionManagerCacheGetMessagesKey = "getMessages"
private let kSessionManagerCacheSendMessagesKey = "sendMessages"
private let kSessionManagerCacheServiceKey = "service"
private let kSessionManagerCacheAttachmentKey = "attachment"
private let kSessionManagerCacheAutodownloadKey = "autodownload"
private let kSessionManagerCacheFileKey = "file"
private let kSessionManagerCacheImageKey = "image"
private let kSessionManagerCacheVideoKey = "video"
private let kSessionManagerCacheVoiceRecKey = "voiceRec"
private let kSessionManagerCacheDefaultKey = "default"

class SessionManagerCache: SessionManagerCacheProtocol {
    private var sessionManagersDict = [String: DPAGHTTPSessionManager]()

    // MARK: - SessionManagerCacheProtocol

    func getCachedSessionManager(forConfigurationType configurationType: RequestConfigurationType) -> DPAGHTTPSessionManager? {
        let key = self.getManagerCacheKey(forConfigurationType: configurationType)
        return self.getManager(forKey: key)
    }

    func cacheSessionManager(manager: DPAGHTTPSessionManager, configurationType: RequestConfigurationType) {
        let key = self.getManagerCacheKey(forConfigurationType: configurationType)
        self.setManager(manager: manager, forKey: key)
    }

    func removeCachedSessionManager(configurationType: RequestConfigurationType) {
        let key = self.getManagerCacheKey(forConfigurationType: configurationType)
        self.removeManagers(forKeys: [key])
    }

    func removeCachedSessionManager(identifier: String) {
        let keys = self.getAllManagerDictKeys().filter {
            $0.contains(identifier)
        }

        self.removeManagers(forKeys: keys)
    }

    func getCachedSessionManager(identifier: String) -> DPAGHTTPSessionManager? {
        let keys = self.getAllManagerDictKeys().filter {
            $0.contains(identifier)
        }

        guard let key = keys.first else {
            return nil
        }

        return self.getManager(forKey: key)
    }

    func autoDownloadManagersCount() -> Int {
        let keys = self.getAllManagerDictKeys().filter {
            $0.contains(kSessionManagerCacheAutodownloadKey)
        }

        return keys.count
    }

    func removeCachedSessionManagers(managersDict: [String: DPAGHTTPSessionManager]) {
        let allKeys = Array(managersDict.keys)
        self.removeManagers(forKeys: allKeys)
    }

    func getAllCachedSessionManagers() -> [String: DPAGHTTPSessionManager] {
        self.getManagersDict()
    }

    func getCachedSessionManagers(forContentType contentType: RequestConfigurationAttachmentContentType) -> [String: DPAGHTTPSessionManager] {
        let contentTypeKey = self.getKey(forContentType: contentType)

        return self.getManagersDict().filter({ key, _ in
            key.contains(contentTypeKey)
        })
    }

    // MARK: - Private

    private func getManagerCacheKey(forConfigurationType configurationType: RequestConfigurationType) -> String {
        switch configurationType {
        case let .attachments(options):
            return self.getAttachmentsCacheKey(options: options)
        case .getMessages:
            return kSessionManagerCacheGetMessagesKey
        case let .sendMessages(identifier):
            return self.getSendMessagesCacheKey(identifier: identifier)
        case .service:
            return kSessionManagerCacheServiceKey
        }
    }

    private func getSendMessagesCacheKey(identifier: String?) -> String {
        kSessionManagerCacheSendMessagesKey + (identifier ?? "")
    }

    private func getAttachmentsCacheKey(options: RequestConfigurationAttachmentOptions) -> String {
        var key = kSessionManagerCacheAttachmentKey
        if options.autodownload {
            key.append("_\(kSessionManagerCacheAutodownloadKey)")
        }
        if let requestInBackgroundId = options.requestInBackgroundId {
            key.append("_\(requestInBackgroundId)")
        }

        let keyForContentType = self.getKey(forContentType: options.contentType)
        key.append("_\(keyForContentType)")

        return key
    }

    private func getKey(forContentType contentType: RequestConfigurationAttachmentContentType) -> String {
        switch contentType {
        case .file:
            return kSessionManagerCacheFileKey
        case .image:
            return kSessionManagerCacheImageKey
        case .video:
            return kSessionManagerCacheVideoKey
        case .voiceRec:
            return kSessionManagerCacheVoiceRecKey
        case .defaultType:
            return kSessionManagerCacheDefaultKey
        }
    }
}

// MARK: - Synchronized dictionary methods

extension SessionManagerCache {
    private func setManager(manager: DPAGHTTPSessionManager, forKey key: String) {
        DPAGFunctionsGlobal.synchronized(self) {
            self.sessionManagersDict[key] = manager
        }
    }

    private func getManager(forKey key: String) -> DPAGHTTPSessionManager? {
        var result: DPAGHTTPSessionManager?
        DPAGFunctionsGlobal.synchronized(self) {
            result = self.sessionManagersDict[key]
        }
        return result
    }

    private func removeManagers(forKeys keys: [String]) {
        DPAGFunctionsGlobal.synchronized(self) {
            keys.forEach {
                self.sessionManagersDict.removeValue(forKey: $0)
            }
        }
    }

    private func getAllManagerDictKeys() -> [String] {
        var result = [String]()
        DPAGFunctionsGlobal.synchronized(self) {
            result = Array(self.sessionManagersDict.keys)
        }
        return result
    }

    private func getManagersDict() -> [String: DPAGHTTPSessionManager] {
        var result = [String: DPAGHTTPSessionManager]()
        DPAGFunctionsGlobal.synchronized(self) {
            result = self.sessionManagersDict
        }
        return result
    }
}
