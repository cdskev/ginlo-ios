//
//  URLSessionConfigurationHelper.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 04.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

protocol URLSessionConfigurationHelperProtocol {
    func getConfiguration(type: RequestConfigurationType) -> URLSessionConfiguration
}

class URLSessionConfigurationHelper: URLSessionConfigurationHelperProtocol {
    // MARK: - URLSessionConfigurationHelperProtocol

    func getConfiguration(type: RequestConfigurationType) -> URLSessionConfiguration {
        switch type {
            case let .attachments(options):
                return self.createAttachmentsConfiguration(options: options)
            case .getMessages:
                return self.createGetMessagesConfiguration()
            case let .sendMessages(requestInBackgroundId):
                return self.createSendMessagesConfiguration(requestInBackgroundId: requestInBackgroundId)
            case .service:
                return self.createDefaultConfiguration()
        }
    }

    // MARK: -

    func createAttachmentsConfiguration(options: RequestConfigurationAttachmentOptions) -> URLSessionConfiguration {
        guard let requestInBackgroundId = options.requestInBackgroundId else { return self.createDefaultConfiguration() }
        if options.autodownload {
            return self.createAutodownloadAttachmentsConfiguration(requestInBackgroundId: requestInBackgroundId)
        }
        return self.createRegularAttachmentsConfiguration(requestInBackgroundId: requestInBackgroundId)
    }

    func createGetMessagesConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.allowsCellularAccess = true
        configuration.isDiscretionary = false
        configuration.networkServiceType = .responsiveData
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        return configuration
    }

    func createSendMessagesConfiguration(requestInBackgroundId: String?) -> URLSessionConfiguration {
        guard let requestInBackgroundId = requestInBackgroundId else { return self.createDefaultConfiguration() }
        let config = URLSessionConfiguration.background(withIdentifier: requestInBackgroundId)
        config.allowsCellularAccess = true
        config.isDiscretionary = false
        config.networkServiceType = .responsiveData
        config.sharedContainerIdentifier = DPAGApplicationFacade.preferences.sharedContainerConfig.groupID
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpMaximumConnectionsPerHost = 4
        config.urlCache = nil
        config.urlCredentialStorage = nil
        return config
    }

    func createAutodownloadAttachmentsConfiguration(requestInBackgroundId: String) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.background(withIdentifier: requestInBackgroundId)
        config.allowsCellularAccess = true
        config.isDiscretionary = false
        config.networkServiceType = .background
        config.sharedContainerIdentifier = DPAGApplicationFacade.preferences.sharedContainerConfig.groupID
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpMaximumConnectionsPerHost = 2
        config.urlCache = nil
        config.urlCredentialStorage = nil
        return config
    }

    func createRegularAttachmentsConfiguration(requestInBackgroundId: String) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.background(withIdentifier: requestInBackgroundId)
        config.allowsCellularAccess = true
        config.isDiscretionary = false
        config.networkServiceType = .responsiveData
        config.sharedContainerIdentifier = DPAGApplicationFacade.preferences.sharedContainerConfig.groupID
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpMaximumConnectionsPerHost = 4
        config.urlCache = nil
        config.urlCredentialStorage = nil
        return config
    }

    func createDefaultConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.allowsCellularAccess = true
        configuration.isDiscretionary = false
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        return configuration
    }
}
