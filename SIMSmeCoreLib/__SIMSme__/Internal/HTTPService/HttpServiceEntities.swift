//
//  HttpServiceEntities.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 11.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AFNetworking
import Foundation

class DPAGHTTPSessionManager: AFHTTPSessionManager {
    var completionHandlers = [DPAGCompletion]()

    func finalizeAllHandlers() {
        self.completionHandlers.forEach {
            $0()
        }
        self.completionHandlers.removeAll()
    }
}

class DPAGHttpServiceRequestBase {
    var path: String?
    private var parametersInternal: [AnyHashable: Any] = [:]
    var parameters: [AnyHashable: Any] {
        get {
            self.parametersInternal
        }
        set {
            self.parametersInternal.merge(newValue) { (v1, _) -> Any in
                v1
            }
        }
    }

    var authenticate: DPAGServerAuthentication = .standard
    var responseBlock: DPAGServiceResponseBlock?
    var timeout: TimeInterval?
}

class DPAGHttpServiceRequest: DPAGHttpServiceRequestBase {
    var parametersCodable: CodableDict? {
        get {
            nil
        }
        set {
            if let parametersCodable = newValue {
                do {
                    let dict = try parametersCodable.dict()

                    self.parameters.merge(dict) { (v1, _) -> Any in
                        v1
                    }
                } catch {
                    DPAGLog(error)
                }
            }
        }
    }

    override init() {
        super.init()
    }

    init(parameters: [AnyHashable: Any], responseBlock: DPAGServiceResponseBlock?) {
        super.init()

        self.parameters = parameters
        self.responseBlock = responseBlock
    }

    init(parametersCodable: CodableDict, responseBlock: DPAGServiceResponseBlock?) {
        super.init()

        self.parametersCodable = parametersCodable
        self.responseBlock = responseBlock
    }
}

enum RequestConfigurationType {
    case attachments(options: RequestConfigurationAttachmentOptions)
    case getMessages
    case sendMessages(identifier: String?)
    case service
}

struct RequestConfigurationAttachmentOptions {
    let autodownload: Bool
    let requestInBackgroundId: String?
    let contentType: RequestConfigurationAttachmentContentType

    /*
     this should be a plain url, no need to pass this block through the whole chain,
     we can just create it at the very end (where the download task is called)
     we should change it later when we get rid of DPAGServiceRequestAttachments
     */
    let destination: ((URL, URLResponse) -> URL)?
}

enum RequestConfigurationAttachmentContentType: String {
    case image
    case voiceRec
    case video
    case file
    case defaultType
}

class DPAGHttpServiceRequestGetMessages: DPAGHttpServiceRequest {}

class DPAGHttpServiceRequestBackground: DPAGHttpServiceRequest {
    var requestInBackgroundId: String?
}

class DPAGHttpServiceRequestSendMessages: DPAGHttpServiceRequestBackground {}

class DPAGHttpServiceRequestAttachments: DPAGHttpServiceRequestBackground {
    var downloadProgressBlock: DPAGProgressBlock?
    var destination: ((URL, URLResponse) -> URL)?
    var isAutoAttachmentDownload: Bool = false
    var contentType: DPAGMessageContentType = .plain
}
