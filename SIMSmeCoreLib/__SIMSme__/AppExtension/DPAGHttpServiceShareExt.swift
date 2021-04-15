//
//  DPAGHttpServiceShareExt.swift
//  SIMSmeShareExtensionBase
//
//  Created by RBU on 07.08.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AFNetworking
import UIKit

class DPAGHttpServiceRequestShareExt {
    var appGroupId: String = ""
    var urlHttpService: String = ""
    var httpUsername: String = ""
    var httpPassword: String = ""
    var path: String?
    var parameters: [AnyHashable: Any] = [:]
    var backgroundId: String = ""
    var timeout: TimeInterval?
    var responseBlock: DPAGServiceResponseBlock?

    init() {}

    init(parameters: [AnyHashable: Any]) {
        self.parameters = parameters
    }
}

protocol DPAGHttpServiceShareExtProtocol: AnyObject {
    func perform(request: DPAGHttpServiceRequestShareExt)
}

class DPAGHttpServiceShareExt: DPAGHttpServiceShareExtProtocol {
    private struct ManagerRequestFile {
        let manager: AFHTTPSessionManager
        let request: NSMutableURLRequest
        let parametersFileUrl: URL
    }

    func perform(request: DPAGHttpServiceRequestShareExt) {
        guard let requestAndManager = self.requestAndManager(request: request) else {
            return
        }

        let manager = requestAndManager.manager

        let urlRequest = requestAndManager.request
        let parametersFileUrl = requestAndManager.parametersFileUrl

        urlRequest.httpBody = nil

        if let responseBlock = request.responseBlock {
            let success = DPAGHttpServiceShareExt.taskSuccessBlock(withResponseBlock: responseBlock)
            let failure = DPAGHttpServiceShareExt.taskFailureBlock(withResponseBlock: responseBlock)

            var dataTask: URLSessionTask?

            dataTask = manager.uploadTask(with: urlRequest as URLRequest, fromFile: parametersFileUrl, progress: nil, completionHandler: { _, responseObject, error in
                DPAGLog("finished sending")
                try? FileManager.default.removeItem(at: parametersFileUrl)

                if let error = error {
                    failure(dataTask, error as NSError)
                } else {
                    success(dataTask, responseObject)
                }
            })

            dataTask?.resume()
        } else {
            let dataTask = manager.uploadTask(with: urlRequest as URLRequest, fromFile: parametersFileUrl, progress: nil, completionHandler: { _, _, _ in
                DPAGLog("finished sending")
                try? FileManager.default.removeItem(at: parametersFileUrl)
            })

            dataTask.resume()
        }
    }

    private func requestAndManager(request: DPAGHttpServiceRequestShareExt) -> ManagerRequestFile? {
        let urlString = request.urlHttpService

        let manager = self.httpSessionManager(urlHttpService: urlString, appGroupId: request.appGroupId, backgroundId: request.backgroundId)
        let requestSerializer = manager.requestSerializer

        do {
            let urlRequest = try requestSerializer.request(withMethod: "POST", urlString: urlString, parameters: nil)

            let urlParameterRoot = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: request.appGroupId) ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let urlParameters = urlParameterRoot.appendingPathComponent(request.backgroundId).appendingPathExtension("postparams")

            do {
                let parameterData = AFQueryStringFromParameters(request.parameters).data(using: .utf8)

                try parameterData?.write(to: urlParameters)

                urlRequest.addValue(String(parameterData?.count ?? 0), forHTTPHeaderField: "Content-Length")
            } catch {
                return nil
            }

            if let timeout = request.timeout, timeout > 0 {
                urlRequest.timeoutInterval = timeout
            }
            if let cmd = request.parameters["cmd"] as? String {
                DPAGLog("executing: %@", cmd)
                urlRequest.addValue(cmd, forHTTPHeaderField: "X-Client-Command")
            }

            urlRequest.setValue("application/x-www-form-urlencoded ; charset=UTF-8", forHTTPHeaderField: "Content-Type")

            if let urlRequestUrl = urlRequest.url {
                let authorizationMessageRef = CFHTTPMessageCreateRequest(kCFAllocatorDefault, urlRequest.httpMethod as CFString, urlRequestUrl as CFURL, kCFHTTPVersion1_1).takeRetainedValue()

                // Encodes usernameRef and passwordRef in Base64
                CFHTTPMessageAddAuthentication(authorizationMessageRef, nil, request.httpUsername as CFString, request.httpPassword as CFString, kCFHTTPAuthenticationSchemeBasic, false)

                // Creates the 'Basic - <encoded_username_and_password>' string for the HTTP header
                if let authorizationStringRef = CFHTTPMessageCopyHeaderFieldValue(authorizationMessageRef, "Authorization" as CFString)?.takeRetainedValue() {
                    // Add authorizationStringRef as value for 'Authorization' HTTP header
                    urlRequest.setValue(authorizationStringRef as String, forHTTPHeaderField: "Authorization")
                }
            }

            let bundle = Bundle.main

            if let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                urlRequest.addValue(appVersion, forHTTPHeaderField: "X-Client-Version")
            }

            let appName = String(format: "%@", (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? "SIMSme")

            urlRequest.addValue(appName, forHTTPHeaderField: "X-Client-App")

            urlRequest.addValue("gzip", forHTTPHeaderField: "Accept-Encoding")
            urlRequest.addValue("keep-alive", forHTTPHeaderField: "Connection")

            return ManagerRequestFile(manager: manager, request: urlRequest, parametersFileUrl: urlParameters)
        } catch {
            return nil
        }
    }

    private var _httpSessionManager: AFHTTPSessionManager?

    private func httpSessionManager(urlHttpService: String, appGroupId: String, backgroundId _: String) -> AFHTTPSessionManager {
        if let _httpSessionManager = self._httpSessionManager {
            return _httpSessionManager
        }

        // background config

//        let config = URLSessionConfiguration.background(withIdentifier: appGroupId + "-shareExt")
//
//        config.allowsCellularAccess = true
//        config.isDiscretionary = false
//        config.networkServiceType = .responsiveData
//        config.sharedContainerIdentifier = appGroupId

        // foreground config

        let config = URLSessionConfiguration.default

        config.allowsCellularAccess = true
        config.isDiscretionary = false
        config.networkServiceType = .responsiveData
        config.sharedContainerIdentifier = appGroupId
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.urlCredentialStorage = nil

        let manager = AFHTTPSessionManager(baseURL: URL(string: urlHttpService), sessionConfiguration: config)

        DPAGExtensionHelper.initHttpSessionManager(manager: manager, qos: .userInitiated)

//        manager.setTaskNeedNewBodyStreamBlock { [weak self] (session, task) -> InputStream in
//            var retVal: InputStream?
//
//            if let fileUrl = self?.taskFileUrls[task.taskIdentifier]
//            {
//                DPAGLog("needed body \(task.taskIdentifier) in \(fileUrl)")
//                retVal = InputStream(url: fileUrl)
//
//                self?.taskFileUrls.removeValue(forKey: task.taskIdentifier)
//            }
//            return retVal ?? InputStream(data: Data())
//        }

        self._httpSessionManager = manager

        return manager
    }

    private class func taskSuccessBlock(withResponseBlock responseBlock: DPAGServiceResponseBlock?) -> ((URLSessionTask?, Any?) -> Void) {
        let success: ((URLSessionTask?, Any?) -> Void) = { _, responseObject in

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

    private class func taskFailureBlock(withResponseBlock responseBlock: DPAGServiceResponseBlock?) -> ((URLSessionTask?, NSError) -> Void) {
        let failure: ((URLSessionTask?, NSError) -> Void) = { operation, error in
            var errorMessage: String?
            var errorCode: String?

            if error.code == 310 || error.code == -1_012 {
                errorMessage = error.localizedDescription
                errorCode = "\(error.code)"
            } else if let responseHTTP = operation?.response as? HTTPURLResponse, responseHTTP.statusCode == 499 {
                errorMessage = "service.error499"
                errorCode = "service.error499"

                // NotificationCenter.default.post(name: DPAGStrings.Notification.Account.WAS_DELETED, object: self, userInfo: ["error": "service.error499"])
            } else if let responseHTTP = operation?.response as? HTTPURLResponse, responseHTTP.statusCode == 403 {
                errorMessage = "service.error403"
                errorCode = "service.error403"
            } else if error.code == -1_200 || error.code == -999 {
                errorMessage = "service.sslError"
                errorCode = "service.sslError"
            } else {
                errorMessage = "service.error\(error.code)"
                errorCode = "service.error\(error.code)"
            }

            responseBlock?(nil, errorCode, errorMessage)

            DPAGLog("Error: %@", error)
        }

        return failure
    }
}
