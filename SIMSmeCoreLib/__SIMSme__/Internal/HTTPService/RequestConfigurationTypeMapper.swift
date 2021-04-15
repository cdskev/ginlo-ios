//
//  RequestConfigurationTypeMapper.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 10.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

protocol RequestConfigurationTypeMapperProtocol {
    func configurationType(forServiceRequest request: DPAGHttpServiceRequestBase) -> RequestConfigurationType
}

class RequestConfigurationTypeMapper: RequestConfigurationTypeMapperProtocol {
    // MARK: - RequestConfigurationTypeMapperProtocol

    func configurationType(forServiceRequest request: DPAGHttpServiceRequestBase) -> RequestConfigurationType {
        if let requestAttachment = request as? DPAGHttpServiceRequestAttachments {
            return self.configurationType(forAttachmentsServiceRequest: requestAttachment)
        }

        if request is DPAGHttpServiceRequestGetMessages {
            return .getMessages
        }

        if (request as? DPAGHttpServiceRequestSendMessages) != nil {
            return .sendMessages(identifier: "Send messages")
        }

        return .service
    }

    // MARK: - Private

    private func configurationType(forAttachmentsServiceRequest request: DPAGHttpServiceRequestAttachments) -> RequestConfigurationType {
        let contentType = self.requestConfigurationContentType(forMessageContentType: request.contentType)
        let destination = request.destination
        let options = RequestConfigurationAttachmentOptions(autodownload: request.isAutoAttachmentDownload, requestInBackgroundId: request.requestInBackgroundId, contentType: contentType, destination: destination)
        return .attachments(options: options)
    }

    private func requestConfigurationContentType(forMessageContentType messageContentType: DPAGMessageContentType) -> RequestConfigurationAttachmentContentType {
        switch messageContentType {
        case .image:
            return .image
        case .video:
            return .video
        case .voiceRec:
            return .voiceRec
        case .file:
            return .file
        case .plain, .contact, .location, .oooStatusMessage, .textRSS, .avCallInvitation, .controlMsgNG:
            return .defaultType
        }
    }
}
