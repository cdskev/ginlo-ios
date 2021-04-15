//
//  SessionManagerHelper.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 08.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

protocol SessionManagerHelperProtocol {
    func createSessionManager(forConfigurationType configurationType: RequestConfigurationType, serializationType: ResponseSerializationType) -> DPAGHTTPSessionManager?
}

extension SessionManagerHelperProtocol {
    func createSessionManager(forConfigurationType configurationType: RequestConfigurationType, serializationType: ResponseSerializationType = .defaultType) -> DPAGHTTPSessionManager? {
        self.createSessionManager(forConfigurationType: configurationType, serializationType: serializationType)
    }
}

class SessionManagerHelper: SessionManagerHelperProtocol {
    var sessionConfigurationHelper: URLSessionConfigurationHelperProtocol = URLSessionConfigurationHelper()
    var cache: SessionManagerCacheProtocol = SessionManagerCache()

    // MARK: - SessionManagerHelperProtocol

    func createSessionManager(forConfigurationType configurationType: RequestConfigurationType, serializationType: ResponseSerializationType = .defaultType) -> DPAGHTTPSessionManager? {
        let sessionConfiguration = self.sessionConfigurationHelper.getConfiguration(type: configurationType)
        let baseURL = URL(string: AppConfig.urlHttpService)
        let manager = DPAGHTTPSessionManager(baseURL: baseURL, sessionConfiguration: sessionConfiguration)
        let qos = self.getQos(forConfigurationType: configurationType)

        DPAGFunctionsGlobal.synchronized(self) {
            DPAGExtensionHelper.initHttpSessionManager(manager: manager, qos: qos, serializationType: serializationType)
        }
        return manager
    }

    // MARK: - Private

    private func getQos(forConfigurationType configurationType: RequestConfigurationType) -> DispatchQoS {
        switch configurationType {
        case let .attachments(options):
            return options.autodownload ? .default : .userInitiated
        case .sendMessages:
            return .userInitiated
        case .getMessages:
            return .userInitiated
        case .service:
            return .default
        }
    }
}
