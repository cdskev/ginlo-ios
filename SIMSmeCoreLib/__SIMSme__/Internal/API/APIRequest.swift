//
//  APIRequest.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 02.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

enum APIRequestMethod: String {
    case POST
}

extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw NSError()
        }
        return dictionary
    }
}

struct APIRequest {
    var host: String
    var parameters = [String: Any]()
    var path: String?
    var scheme: String
    var configurationType: RequestConfigurationType
    var skipCompression: Bool
    var method: APIRequestMethod
    var authentication: DPAGServerAuthentication
    var timeout: TimeInterval?

    init(host: String = AppConfig.hostHttpService,
         path: String? = nil,
         scheme: String = "https",
         configurationType: RequestConfigurationType = .service,
         skipCompression: Bool = false,
         method: APIRequestMethod = .POST,
         authentication: DPAGServerAuthentication = .standard,
         timeout: TimeInterval? = nil) {
        self.host = host

        self.path = path
        self.scheme = scheme
        self.configurationType = configurationType
        self.skipCompression = skipCompression
        self.method = method
        self.authentication = authentication
        self.timeout = timeout
    }

    mutating func setEncodableParameters<P>(object: P) where P: Encodable {
        if let parametersDict = try? object.asDictionary() {
            self.setDictParameters(parametersDict: parametersDict)
        }
    }

    mutating func setDictParameters(parametersDict: [String: Any]) {
        self.parameters.merge(parametersDict, uniquingKeysWith: { $1 })
    }
}
