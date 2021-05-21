//
//  DPAGHttpService+NewRequest.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 02.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AFNetworking
import Foundation

protocol HTTPServiceProtocol {
    func performRequest(apiRequest: APIRequest, progress: HTTPServiceProgressBlock?, completion: @escaping HTTPServiceCompletionBlock)
}

typealias HTTPServiceCompletionBlock = (Data?, URLResponse?, Error?) -> Void
typealias HTTPServiceProgressBlock = (Progress) -> Void
typealias HTTPServiceAttachmentDestinationBlock = (URL, URLResponse) -> URL
typealias HTTPServiceManagerCompletionBlock = (URLResponse, Any?, Error?) -> Void

extension DPAGHttpService: HTTPServiceProtocol {
    // MARK: - HTTPServiceProtocol

    func performRequest(apiRequest: APIRequest, progress: HTTPServiceProgressBlock?, completion: @escaping HTTPServiceCompletionBlock) {
        if AppConfig.buildConfigurationMode == .DEBUG, Thread.isMainThread {
            DPAGLog("performRequest should be called in a background thread")
            DPAGFunctionsGlobal.printBacktrace()
        }
        if DPAGHelperEx.isNetworkReachable() == false {
            completion(nil, nil, APIError.noConnection)
            return
        }
        let cmd = apiRequest.parameters["cmd"] as? String
        let dateStart = Date()
        guard let manager = self.getSessionManager(configurationType: apiRequest.configurationType, serializationType: .passThrough),
            let urlRequest = try? self.requestSerializer.serializeApiRequest(apiRequest: apiRequest, manager: manager) else {
            completion(nil, nil, APIError.badRequest)
            return
        }
        let dataTask = self.getURLSessionTask(forURLRequest: urlRequest, configurationType: apiRequest.configurationType, manager: manager, progress: progress) { urlResponse, object, error in
            let timeElapsed = Date().timeIntervalSince(dateStart)
            if let cmd = cmd {
                DPAGLog("received server command: %@ Elapsed: %.2f", cmd, timeElapsed)
            }
            let data = object as? Data
            completion(data, urlResponse, error)
        }
        if let cmd = cmd {
            DPAGLog("requested server command: %@", cmd)
        }
        dataTask.resume()
    }

    // MARK: - Private

    private func getURLSessionTask(forURLRequest urlRequest: URLRequest, configurationType: RequestConfigurationType, manager: DPAGHTTPSessionManager, progress: HTTPServiceProgressBlock?, completion: @escaping HTTPServiceManagerCompletionBlock) -> URLSessionTask {
        if case let RequestConfigurationType.attachments(options) = configurationType {
            let destination = options.destination
            return manager.downloadTask(with: urlRequest, progress: progress, destination: destination, completionHandler: completion)
        } else {
            return manager.uploadTask(with: urlRequest, from: nil, progress: progress, completionHandler: completion)
        }
    }
}
