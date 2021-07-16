//
//  RequestSerializer.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 05.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AFNetworking
import Foundation

enum RequestSerializerError: Error {
    case authenticationPasswordNil
    case authenticationUserNameNil
}

protocol RequestSerializerProtocol {
    func serializeApiRequest(apiRequest: APIRequest, manager: DPAGHTTPSessionManager) throws -> URLRequest
    func serializeHttpServiceRequest(request: DPAGHttpServiceRequestBase, manager: DPAGHTTPSessionManager) throws -> URLRequest
}

struct URLRequestCreationParameters {
    let urlString: String
    let parameters: [AnyHashable: Any]
    let timeout: TimeInterval?
}

class RequestSerializer: RequestSerializerProtocol {
    var requestConfigurationTypeMapper: RequestConfigurationTypeMapperProtocol = RequestConfigurationTypeMapper()
    let syncQueue = DispatchQueue(label: "Serialization Queue")

    // MARK: - RequestSerializerProtocol

    func serializeApiRequest(apiRequest: APIRequest, manager: DPAGHTTPSessionManager) throws -> URLRequest {
        let requestSerializer = manager.requestSerializer
        let urlRequest = try self.createURLRequest(apiRequest: apiRequest, requestSerializer: requestSerializer)
        return urlRequest as URLRequest
    }

    func serializeHttpServiceRequest(request: DPAGHttpServiceRequestBase, manager: DPAGHTTPSessionManager) throws -> URLRequest {
        var apiRequest: APIRequest?
        var result: URLRequest?
        try syncQueue.sync {
            autoreleasepool {
                apiRequest = self.mapHttpServiceRequestToApiRequest(request: request)
                request.clearParameters()
            }
            // swiftlint:disable force_unwrapping
            result = try self.serializeApiRequest(apiRequest: apiRequest!, manager: manager)
        }
        // swiftlint:disable force_unwrapping
        return result!
    }

    // MARK: - Internal

    func createURLRequest(apiRequest: APIRequest, requestSerializer: AFHTTPRequestSerializer) throws -> NSMutableURLRequest {
        let urlString = self.getUrlString(apiRequest: apiRequest)
        var urlRequest: NSMutableURLRequest?
        let cmd: String? = apiRequest.parameters["cmd"] as? String
        try autoreleasepool {
            do {
                urlRequest = try requestSerializer.request(withMethod: apiRequest.method.rawValue, urlString: urlString, parameters: apiRequest.parameters)
                apiRequest.clearParameters()
            } catch {
                DPAGLog("error creating request: \(error)")
                throw error
            }
        }
        do {
            if let urlRequest = urlRequest {
                self.setupCompressionHeaders(forURLRequest: urlRequest, skipCompression: apiRequest.skipCompression)
                let model: DPAGSimsMeModelProtocol = DPAGApplicationFacade.model
                try self.setupAuthentication(authentication: apiRequest.authentication, forURLRequest: urlRequest, model: model)
                self.setupClientAndConnectionHeaders(forURLRequest: urlRequest, model: model)
                if let timeout = apiRequest.timeout {
                    urlRequest.timeoutInterval = timeout
                }
                // this is used by backend for logging
                if let cmd = cmd {
                    urlRequest.addValue(cmd, forHTTPHeaderField: "X-Client-Command")
                }
                return urlRequest
            }
            throw DPAGErrorCreateMessage.err465
        } catch {
            DPAGLog("error creating request: \(error)")
            throw error
        }
    }

    func mapHttpServiceRequestToApiRequest(request: DPAGHttpServiceRequestBase) -> APIRequest {
        let configurationType = self.requestConfigurationTypeMapper.configurationType(forServiceRequest: request)
        var timeout: TimeInterval?
        if let requestTimeout = request.timeout, requestTimeout > 0 {
            timeout = requestTimeout
        }
        let apiRequest = APIRequest(path: request.path, configurationType: configurationType, authentication: request.authenticate, timeout: timeout)
        if let parameters = request.parameters as? [String: Any] {
            apiRequest.setDictParameters(parametersDict: parameters)
        }
        return apiRequest
    }

    func getUrlString(apiRequest: APIRequest) -> String {
        var result = apiRequest.scheme + "://" + apiRequest.host
        if let path = apiRequest.path {
            result += "/\(path)"
        }
        return result
    }

    private func saveDataToBeZipped(data: Data) -> URL? {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(DPAGFunctionsGlobal.uuid())
        do {
            NSLog("IMDAT:: DataSize BEFORE ZIP \(data.count)")
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
    
    func setupCompressionHeaders(forURLRequest urlRequest: NSMutableURLRequest, skipCompression: Bool) {
        var continueCompression: Bool = false
        var dataUrl: URL?
        var length: Int = 0
        autoreleasepool {
            if skipCompression == false, let httpBody = urlRequest.httpBody, httpBody.count > 3_000 {
                length = httpBody.count
                dataUrl = saveDataToBeZipped(data: httpBody)
                urlRequest.httpBody = nil
                continueCompression = true
            }
        }
        if continueCompression {
            if let dataUrl = dataUrl {
                urlRequest.httpBody = DPAGHelper.gzipFile(dataUrl, length: length)
                NSLog("IMDAT:: DataSize AFTER ZIP \(urlRequest.httpBody?.count)")
                urlRequest.addValue("gzip", forHTTPHeaderField: "Content-Encoding")
                urlRequest.setValue("application/x-gzip", forHTTPHeaderField: "Content-Type")
            }
        } else {
            urlRequest.setValue("application/x-www-form-urlencoded ; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        }
        urlRequest.addValue("gzip", forHTTPHeaderField: "Accept-Encoding")
    }

    func setupAuthentication(authentication: DPAGServerAuthentication, forURLRequest urlRequest: NSMutableURLRequest, model: DPAGSimsMeModelProtocol) throws {
        switch authentication {
            case .standard:
                if model.httpPassword == nil {
                    throw RequestSerializerError.authenticationPasswordNil
                }
                NSMutableURLRequest.basicAuth(for: urlRequest, withUsername: model.httpUsername, andPassword: model.httpPassword)
            case .background:
                guard let username = model.httpUsername ?? DPAGApplicationFacade.preferences.backgroundAccessUsername else {
                    DPAGLog("Cannot perform background request because username is nil")
                    throw RequestSerializerError.authenticationUserNameNil
                }
                guard let password = DPAGApplicationFacade.preferences.backgroundAccessToken else {
                    DPAGLog("Cannot perform background request because password is nil")
                    throw RequestSerializerError.authenticationPasswordNil
                }
                NSMutableURLRequest.basicAuth(for: urlRequest, withUsername: username, andPassword: password)
            case .recovery:
                NSMutableURLRequest.basicAuth(for: urlRequest, withUsername: model.recoveryAccountguid, andPassword: model.recoveryPasstoken)
            case .none:
                break
        }
    }

    func setupClientAndConnectionHeaders(forURLRequest urlRequest: NSMutableURLRequest, model: DPAGSimsMeModelProtocol) {
        model.addParams(to: urlRequest)
        urlRequest.addValue("keep-alive", forHTTPHeaderField: "Connection")
    }
}
