//
//  ResponseValidator.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 12.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

protocol ResponseValidatorProtocol {
    func validateResponse(urlResponse: URLResponse?, error: Error?) -> APIError?
}

class ResponseValidator: ResponseValidatorProtocol {
    // MARK: - ResponseValidatorProtocol

    func validateResponse(urlResponse: URLResponse?, error: Error?) -> APIError? {
        if let response = urlResponse as? HTTPURLResponse, let statusCodeError = self.checkStatusCodeError(statusCode: response.statusCode) {
            return statusCodeError
        }

        if let error = error, let apiError = self.getAPIError(error: error) {
            return apiError
        }

        return nil
    }

    // MARK: - Private

    func checkStatusCodeError(statusCode: Int) -> APIError? {
        switch statusCode {
        case 200 ..< 300:
            return nil

        case 403, 499:
            return APIError.accountWasDeleted(code: statusCode)

        default:
            return APIError.statusCodeError(statusCode: statusCode)
        }
    }

    func getAPIError(error: Error) -> APIError? {
        if let apiError = error as? APIError {
            return apiError
        }

        if let urlError = error as? URLError {
            return self.getAPIError(urlError: urlError)
        }

        return self.getAPIError(nsError: error as NSError)
    }

    func getAPIError(urlError: URLError) -> APIError? {
        switch urlError.code {
        case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted, .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid, .clientCertificateRejected, .clientCertificateRequired:
            return APIError.sslError
        default:
            let errorCode = urlError.errorCode
            let errorMessage = urlError.localizedDescription
            return APIError.serviceError(code: errorCode, message: errorMessage)
        }
    }

    func getAPIError(nsError: NSError) -> APIError? {
        let errorCode = nsError.code
        let errorMessage = nsError.localizedDescription
        return APIError.serviceError(code: errorCode, message: errorMessage)
    }
}
