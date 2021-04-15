//
//  APIError.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 19.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

enum APIError: Error {
    case noConnection
    case badResponse(reason: APIErrorBadResponseReason)
    case badRequest
    case serviceError(code: Int, message: String)
    case messageExceptionError(exception: API.MessageExceptionResponse)
    case accountWasDeleted(code: Int)
    case sslError
    case statusCodeError(statusCode: Int)

    func getPublicInfo() -> APIErrorPublicInfo {
        let code = self.getCode()
        let message: String = self.getMessage(code: code)
        return APIErrorPublicInfo(errorCode: code, errorMessage: message)
    }

    private func getCode() -> String {
        switch self {
        case let .serviceError(code, _):
            return "service.error\(code)"
        case .noConnection:
            return "backendservice.internet.connectionFailed"
        case let .messageExceptionError(exception):
            return "service.\(exception.messageException.ident)"
        case .sslError:
            return "service.sslError"
        case let .accountWasDeleted(code):
            return "service.error\(code)"
        case .badRequest, .badResponse, .statusCodeError:
            return "service.tryAgainLater"
        }
    }

    private func getMessage(code: String) -> String {
        if case let APIError.serviceError(_, message) = self {
            return message
        } else {
            return DPAGLocalizedString(code)
        }
    }
}

struct APIErrorPublicInfo {
    let errorCode: String
    let errorMessage: String
}

enum APIErrorBadResponseReason {
    case parsingError
    case missingData
}
