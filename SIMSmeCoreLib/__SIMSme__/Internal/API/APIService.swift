//
//  APIService.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 12.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

protocol APIServiceProtocol {
    func performRequest<T>(request: APIRequest, resultObjectType: T.Type, progress: APIServiceProgressBlock?, completion: @escaping APIServiceCompletion<T>) where T: Decodable
}

extension APIServiceProtocol {
    func performRequest<T>(request: APIRequest, resultObjectType: T.Type, progress: APIServiceProgressBlock? = nil, completion: @escaping APIServiceCompletion<T>) where T: Decodable {
        self.performRequest(request: request, resultObjectType: resultObjectType, progress: progress, completion: completion)
    }
}

typealias APIServiceCompletion<T> = (APIServiceResult<T>) -> Void where T: Decodable
typealias APIServiceResult<T> = Result<T, APIError> where T: Decodable

typealias APIServiceProgressBlock = HTTPServiceProgressBlock

class APIService: APIServiceProtocol {
    var httpService: HTTPServiceProtocol = DPAGHttpService()
    var responseValidator: ResponseValidatorProtocol = ResponseValidator()
    var commonErrorHandler: CommonErrorHandlerProtocol = CommonErrorHandler()

    var apiParser = APIParser()

    // MARK: - APIServiceProtocol

    func performRequest<T>(request: APIRequest, resultObjectType: T.Type, progress: APIServiceProgressBlock? = nil, completion: @escaping APIServiceCompletion<T>) where T: Decodable {
        self.httpService.performRequest(apiRequest: request, progress: progress) { [weak self] data, urlResponse, error in
            if let responseError = self?.responseValidator.validateResponse(urlResponse: urlResponse, error: error) {
                self?.handleAPIError(apiError: responseError, completion: completion)
            } else {
                self?.handleAPISuccess(data: data, resultObjectType: resultObjectType, completion: completion)
            }
        }
    }

    // MARK: - Private

    private func handleAPIError<T>(apiError: APIError, completion: @escaping APIServiceCompletion<T>) {
        DPAGLog(apiError)

        self.commonErrorHandler.handleAPIError(error: apiError)
        completion(APIServiceResult<T>.failure(apiError))
    }

    private func handleAPISuccess<T>(data: Data?, resultObjectType: T.Type, completion: @escaping APIServiceCompletion<T>) where T: Decodable {
        guard let data = data else {
            DPAGLog("APIService - no data error")
            self.handleAPIError(apiError: APIError.badResponse(reason: .missingData), completion: completion)
            return
        }

        // at first we check if there is an exception in json
        if let msgException = try? self.apiParser.parseToObject(ofType: API.MessageExceptionResponse.self, data: data) {
            DPAGLog("APIService - messageExceptionError, ident:  \(msgException.messageException.ident)")
            self.handleAPIError(apiError: APIError.messageExceptionError(exception: msgException), completion: completion)
            return
        }

        do {
            let object = try self.apiParser.parseToObject(ofType: resultObjectType, data: data)
            let result = APIServiceResult<T>.success(object)
            completion(result)
        } catch {
            DPAGLog("APIService - parsing error: \(error)")
            self.handleAPIError(apiError: APIError.badResponse(reason: .parsingError), completion: completion)
        }
    }
}
