//
//  DPAGHttpService.swift
//  SIMSmeCore
//
//  Created by RBU on 26.02.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AFNetworking

protocol DPAGHttpServiceProtocol {
    @discardableResult
    func perform(request: DPAGHttpServiceRequestBase) -> URLSessionTask?

    @discardableResult
    func performDownload(request: DPAGHttpServiceRequestAttachments) -> URLSessionTask?

    func handleEvents(forBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void)

    func checkAutoDownloads()
}

class DPAGHttpService: NSObject, DPAGHttpServiceProtocol {
    var sessionManagerHelper: SessionManagerHelperProtocol = SessionManagerHelper()
    var requestSerializer: RequestSerializerProtocol = RequestSerializer()
    var sessionManagerCache: SessionManagerCacheProtocol = SessionManagerCache()
    var requestConfigurationTypeMapper: RequestConfigurationTypeMapperProtocol = RequestConfigurationTypeMapper()

    override init() {
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(networkReachabilityStatusChanged(_:)), name: NSNotification.Name.AFNetworkingReachabilityDidChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @discardableResult
    func perform(request: DPAGHttpServiceRequestBase) -> URLSessionTask? {
        if AppConfig.buildConfigurationMode == .DEBUG {
            if Thread.isMainThread {
                DPAGLog("performRequest should be called in a background thread")
                DPAGFunctionsGlobal.printBacktrace()
            }
        }

        if DPAGHelperEx.isNetworkReachable() == false {
            request.responseBlock?(nil, "backendservice.internet.connectionFailed", DPAGLocalizedString("backendservice.internet.connectionFailed"))
            return nil
        }

        let configurationType = self.requestConfigurationTypeMapper.configurationType(forServiceRequest: request)
        guard let manager = self.getSessionManager(configurationType: configurationType), let urlRequest = try? self.requestSerializer.serializeHttpServiceRequest(request: request, manager: manager) else {
            return nil
        }

        let success = DPAGHttpService.taskSuccessBlock(withResponseBlock: request.responseBlock)
        let failure = DPAGHttpService.taskFailureBlock(withResponseBlock: request.responseBlock)

        let cmd = request.parameters["cmd"] as? String

        var dataTask: URLSessionDataTask?
        let startTime = Date()
        var waitTime: Date?

        dataTask = manager.uploadTask(with: urlRequest as URLRequest, from: nil, progress: { _ in
        }, completionHandler: { _, responseObject, error in
            let endTime = Date()
            let timeElapsed = endTime.timeIntervalSince(startTime)
            let waitElapsed = waitTime?.timeIntervalSince(startTime)

            if let cmd = cmd {
                DPAGLog("received server command: %@ Wait: %.2f Elapsed: %.2f", cmd, waitElapsed ?? TimeInterval(0), timeElapsed)
            }

            if let error = error {
                failure(dataTask, error)
            } else {
                success(dataTask, responseObject)
            }
        })

        if let cmd = cmd {
            DPAGLog("requested server command: %@", cmd)
        }

        waitTime = Date()
        dataTask?.resume()

        return dataTask
    }

    @discardableResult
    func performDownload(request: DPAGHttpServiceRequestAttachments) -> URLSessionTask? {
        if AppConfig.buildConfigurationMode == .DEBUG {
            if Thread.isMainThread {
                DPAGLog("performDownloadRequest should be called in a background thread")
                DPAGFunctionsGlobal.printBacktrace()
            }
        }

        if DPAGHelperEx.isNetworkReachable() == false {
            request.responseBlock?(nil, "backendservice.internet.connectionFailed", DPAGLocalizedString("backendservice.internet.connectionFailed"))
            return nil
        }

        let configurationType = self.requestConfigurationTypeMapper.configurationType(forServiceRequest: request)
        guard let manager = self.getSessionManager(configurationType: configurationType), let urlRequest = try? self.requestSerializer.serializeHttpServiceRequest(request: request, manager: manager) else {
            return nil
        }

        let success = DPAGHttpService.taskSuccessBlock(withResponseBlock: request.responseBlock)
        let failure = DPAGHttpService.taskFailureBlock(withResponseBlock: request.responseBlock)

        var dataTask: URLSessionDownloadTask?

        dataTask = manager.downloadTask(with: urlRequest as URLRequest, progress: { progress in
            request.downloadProgressBlock?(progress, request.isAutoAttachmentDownload)
        }, destination: request.destination, completionHandler: { _, responseObject, error in

            if let error = error {
                failure(dataTask, error as NSError)
            } else {
                success(dataTask, responseObject)
            }
        })

        dataTask?.resume()

        return dataTask
    }

    func handleEvents(forBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        DPAGLog("— handleEventsForBackgroundURLSession —")

        if let manager = self.sessionManagerCache.getCachedSessionManager(identifier: identifier) {
            manager.session.getTasksWithCompletionHandler { _, uploadTasks, _ in
                if uploadTasks.count > 0 {
                    uploadTasks.first?.resume()
                }
            }
            manager.completionHandlers.append(completionHandler)

            DPAGLog("Rejoining session %@", manager.session)
        } else {
            completionHandler()
        }
    }

    @objc
    private func networkReachabilityStatusChanged(_: Notification) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(cancelAllTasks), object: nil)

        switch AFNetworkReachabilityManager.shared().networkReachabilityStatus {
        case .notReachable:
            self.perform(#selector(cancelAllTasks), with: nil, afterDelay: 2)
        case .reachableViaWiFi:
            break
        case .reachableViaWWAN, .unknown:
            self.perform(#selector(cancelAllOnlyWifiAttachmentTasks), with: nil, afterDelay: 2)
        @unknown default:
            DPAGLog("Switch with unknown value: \(AFNetworkReachabilityManager.shared().networkReachabilityStatus.rawValue)", level: .warning)
        }
    }

    private func cancelTasks(sessionManager: DPAGHTTPSessionManager?) {
        guard let sessionManager = sessionManager else { return }

        for task in sessionManager.tasks {
            task.cancel()
        }
    }

    @objc
    private func cancelAllTasks() {
        let managersDict = self.sessionManagerCache.getAllCachedSessionManagers()
        self.cancelExistingTasks(managersDict: managersDict)
    }

    @objc
    private func cancelAllOnlyWifiAttachmentTasks() {
        self.performBlockInBackground { [weak self] in
            var managers = [String: DPAGHTTPSessionManager]()
            self?.appendCachedManagersIfAutodownloadSettingWiFi(to: &managers, contentType: .image, autoDownloadSetting: DPAGApplicationFacade.preferences.autoDownloadSettingFoto)
            self?.appendCachedManagersIfAutodownloadSettingWiFi(to: &managers, contentType: .voiceRec, autoDownloadSetting: DPAGApplicationFacade.preferences.autoDownloadSettingAudio)
            self?.appendCachedManagersIfAutodownloadSettingWiFi(to: &managers, contentType: .video, autoDownloadSetting: DPAGApplicationFacade.preferences.autoDownloadSettingVideo)
            self?.appendCachedManagersIfAutodownloadSettingWiFi(to: &managers, contentType: .file, autoDownloadSetting: DPAGApplicationFacade.preferences.autoDownloadSettingFile)
            self?.cancelExistingTasks(managersDict: managers)
        }
    }

    private func appendCachedManagersIfAutodownloadSettingWiFi(to managersDict: inout [String: DPAGHTTPSessionManager], contentType: RequestConfigurationAttachmentContentType, autoDownloadSetting setting: DPAGSettingAutoDownload) {
        let cachedManagers = self.sessionManagerCache.getCachedSessionManagers(forContentType: contentType)
        if setting == .wifi {
            managersDict.merge(cachedManagers, uniquingKeysWith: { $1 })
        }
    }

    private func cancelExistingTasks(managersDict: [String: DPAGHTTPSessionManager]) {
        for manager in managersDict.values {
            manager.invalidateSessionCancelingTasks(true, resetSession: false)
            manager.finalizeAllHandlers()
        }

        self.sessionManagerCache.removeCachedSessionManagers(managersDict: managersDict)
    }

    func getSessionManager(configurationType: RequestConfigurationType, serializationType: ResponseSerializationType = .defaultType) -> DPAGHTTPSessionManager? {
        if let cachedManager = self.sessionManagerCache.getCachedSessionManager(forConfigurationType: configurationType) {
            // This is the hack and it was implemented before like this. We reset the queue for every service request. Otherwise sometimes the app is stuck (synch calls in workers used the same queue as the session manager and block it with semafors). We need to come up with a better solution
            if case RequestConfigurationType.service = configurationType {
                DPAGFunctionsGlobal.synchronized(self) {
                    DPAGExtensionHelper.setCompletionQueue(forManager: cachedManager)
                }
            }
            return cachedManager
        }

        guard let newManager = self.sessionManagerHelper.createSessionManager(forConfigurationType: configurationType, serializationType: serializationType) else {
            return nil
        }

        self.sessionManagerCache.cacheSessionManager(manager: newManager, configurationType: configurationType)

        newManager.setDidFinishEventsForBackgroundURLSessionBlock { [weak self, weak newManager] _ in
            if case RequestConfigurationType.attachments = configurationType {
                self?.sessionManagerCache.removeCachedSessionManager(configurationType: configurationType)
            }

            newManager?.finalizeAllHandlers()
        }
        return newManager
    }

    private class func taskSuccessBlock(withResponseBlock responseBlock: DPAGServiceResponseBlock?) -> ((URLSessionTask?, Any?) -> Void) {
        let success: ((URLSessionTask?, Any?) -> Void) = { _, responseObject in

            //        DPAGLog(@"JSON responseObject: %@", responseObject);
            if responseBlock != nil {
                if responseObject is [Any] {
                    responseBlock?(responseObject, nil, nil)
                } else if let responseDict = responseObject as? [AnyHashable: Any] {
                    // check for error first
                    if let errorObject = responseDict["MsgException"] as? [AnyHashable: Any] {
                        let errorMessage = DPAGHelperEx.getErrorMessageIdentifier(errorObject: errorObject)
                        let errorIdent = DPAGHelperEx.getErrorCode(errorObject: errorObject)

                        responseBlock?(nil, errorIdent, errorMessage)
                    } else {
                        responseBlock?(responseDict, nil, nil)
                    }
                } else {
                    responseBlock?(responseObject, nil, nil)
                }
            } else {
                DPAGLog("no responseBlock set")
            }
        }

        return success
    }

    private class func taskFailureBlock(withResponseBlock responseBlock: DPAGServiceResponseBlock?) -> ((URLSessionTask?, Error) -> Void) {
        let failure: ((URLSessionTask?, Error) -> Void) = { operation, error in

            DPAGLog(error)

            if let responseHTTP = operation?.response as? HTTPURLResponse {
                switch responseHTTP.statusCode {
                case 499:
                    responseBlock?(nil, "service.error499", "service.error499")

                    NotificationCenter.default.post(name: DPAGStrings.Notification.Account.WAS_DELETED, object: self, userInfo: ["error": "service.error499"])
                    return
                case 403:
                    responseBlock?(nil, "service.error403", "service.error403")
                    return
                default:
                    break
                }
            }

            var errorMessage: String?
            var errorCode: String?

            if let urlError = error as? URLError {
                switch urlError.code {
                case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted, .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid, .clientCertificateRejected, .clientCertificateRequired:
                    errorMessage = "service.sslError" // urlError.localizedDescription
                    errorCode = "service.sslError"

                default:

                    errorMessage = urlError.localizedDescription
                    errorCode = "service.error\(urlError.errorCode)"
                }
            } else {
                let nsError = error as NSError

                errorMessage = error.localizedDescription
                errorCode = "service.error\(nsError.code)"
            }

            responseBlock?(nil, errorCode, errorMessage)
        }

        return failure
    }

    func checkAutoDownloads() {
        guard AFNetworkReachabilityManager.shared().isReachable,
            self.sessionManagerCache.autoDownloadManagersCount() == 0 else {
            return
        }

        let messagesDAO: MessagesDAOProtocol = MessagesDAO()

        do {
            let settingValueAutoDownloadFoto = DPAGApplicationFacade.preferences.autoDownloadSettingFoto
            let settingValueAutoDownloadAudio = DPAGApplicationFacade.preferences.autoDownloadSettingAudio
            let settingValueAutoDownloadVideo = DPAGApplicationFacade.preferences.autoDownloadSettingVideo
            let settingValueAutoDownloadFile = DPAGApplicationFacade.preferences.autoDownloadSettingFile

            let autoDownloadAttachments = try messagesDAO.loadAutoDownloadAttachments(contentTypeFilter: { contentType -> Bool in
                switch contentType {
                case .image:
                    return settingValueAutoDownloadFoto != .never

                case .voiceRec:
                    return settingValueAutoDownloadAudio != .never

                case .video:
                    return settingValueAutoDownloadVideo != .never

                case .file:
                    return settingValueAutoDownloadFile != .never

                default:
                    break
                }
                return false
            })

            if AFNetworkReachabilityManager.shared().isReachableViaWiFi || (settingValueAutoDownloadFoto == .wifiAndMobile && AFNetworkReachabilityManager.shared().isReachableViaWWAN) {
                for (messageGuid, attachmentGuid) in autoDownloadAttachments.attachmentGuidsFoto {
                    self.startAutoDownload(messageGuid: messageGuid, attachmentGuid: attachmentGuid, contentType: .image)
                }
            }

            if AFNetworkReachabilityManager.shared().isReachableViaWiFi || (settingValueAutoDownloadAudio == .wifiAndMobile && AFNetworkReachabilityManager.shared().isReachableViaWWAN) {
                for (messageGuid, attachmentGuid) in autoDownloadAttachments.attachmentGuidsAudio {
                    self.startAutoDownload(messageGuid: messageGuid, attachmentGuid: attachmentGuid, contentType: .voiceRec)
                }
            }

            if AFNetworkReachabilityManager.shared().isReachableViaWiFi || (settingValueAutoDownloadVideo == .wifiAndMobile && AFNetworkReachabilityManager.shared().isReachableViaWWAN) {
                for (messageGuid, attachmentGuid) in autoDownloadAttachments.attachmentGuidsVideo {
                    self.startAutoDownload(messageGuid: messageGuid, attachmentGuid: attachmentGuid, contentType: .video)
                }
            }

            if AFNetworkReachabilityManager.shared().isReachableViaWiFi || (settingValueAutoDownloadFile == .wifiAndMobile && AFNetworkReachabilityManager.shared().isReachableViaWWAN) {
                for (messageGuid, attachmentGuid) in autoDownloadAttachments.attachmentGuidsFile {
                    self.startAutoDownload(messageGuid: messageGuid, attachmentGuid: attachmentGuid, contentType: .file)
                }
            }
        } catch {
            DPAGLog(error)
        }
    }

    private func startAutoDownload(messageGuid: String, attachmentGuid: String, contentType: DPAGMessageContentType) {
        guard let attachmentPath = AttachmentHelper.attachmentFilePath(guid: attachmentGuid) else {
            return
        }
        let responseBlock: DPAGServiceResponseBlock = { [weak self] responseObject, errorCode, errorMessage in

            self?.handleAutoDownloadResponse(messageGuid: messageGuid, attachmentGuid: attachmentGuid, contentType: contentType, responseObject: responseObject, errorCode: errorCode, errorMessage: errorMessage)
        }
        DPAGApplicationFacade.server.getAutoAttachment(guid: attachmentGuid, contentType: contentType, progress: DPAGApplicationFacade.cache.decryptedMessage(messageGuid: messageGuid, in: nil)?.updateAttachmentProgress, destination: { (_, _) -> URL in
            attachmentPath
        }, withResponse: responseBlock)
    }

    private func handleAutoDownloadResponse(messageGuid: String, attachmentGuid: String, contentType _: DPAGMessageContentType, responseObject: Any?, errorCode: String?, errorMessage: String?) {
        let messagesDAO: MessagesDAOProtocol = MessagesDAO()

        defer {
            self.sessionManagerCache.removeCachedSessionManager(identifier: attachmentGuid)
        }

        if errorMessage == nil, responseObject is [String] || responseObject is NSURL {
            if let object = (responseObject as? [String])?.first {
                // Attachment als gedownloaded markieren ...
                DPAGApplicationFacade.server.confirmAttachmentDownload(guids: [messageGuid], withResponse: nil)
                DPAGAttachmentWorker.saveEncryptedAttachment(object, forGuid: attachmentGuid)
            } else if let responseURL = responseObject as? URL, let data = try? Data(contentsOf: responseURL) {
                do {
                    DPAGAttachmentWorker.removeEncryptedAttachment(guid: attachmentGuid)

                    let object = try JSONSerialization.jsonObject(with: data, options: [])

                    if let objectData = (object as? [String])?.first {
                        // Attachment als gedownloaded markieren ...
                        DPAGApplicationFacade.server.confirmAttachmentDownload(guids: [messageGuid], withResponse: nil)
                        DPAGAttachmentWorker.saveEncryptedAttachment(objectData, forGuid: attachmentGuid)

                        let block = {
                            messagesDAO.setIsAttachmentAutomaticDownload(messageGuid: messageGuid)
                        }

                        if let cellWithProgress = DPAGApplicationFacade.cache.decryptedMessage(messageGuid: messageGuid, in: nil)?.cellWithProgress {
                            cellWithProgress.downloadCompletionBackground = block
                        } else {
                            block()
                        }
                    } else if let responseDict = object as? [String: Any] {
                        // check for error first
                        if let errorObject = responseDict["MsgException"] as? [String: Any] {
                            let errorCode = DPAGHelperEx.getErrorCode(errorObject: errorObject)
                            let errorMessage = DPAGHelperEx.getErrorMessageIdentifier(errorObject: errorObject)

                            if errorCode == "ERR-0026" || errorCode == "ERR-0088" {
                                messagesDAO.setIsUnableToLoadAttachment(messageGuid: messageGuid)
                            } else {
                                DPAGLog("Invalid response error: " + (errorMessage ?? "??"))
                            }
//                        } else {
//                            DPAGLog("Invalid response")
                        }
//                    } else {
//                        DPAGLog("Invalid response")
                    }
                } catch {
                    DPAGLog(error)
                }
            }
        } else if errorCode == "ERR-0026" || errorCode == "ERR-0088" {
            messagesDAO.setIsUnableToLoadAttachment(messageGuid: messageGuid)
        }
    }
}
