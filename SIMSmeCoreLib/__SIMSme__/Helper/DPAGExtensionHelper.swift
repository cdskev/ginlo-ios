//
//  DPAGNotificationExtensionHelper.swift
//  SIMSmeCore
//
//  Created by RBU on 08.03.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AFNetworking
import Foundation

private class PassThroughResponseSerializer: AFJSONResponseSerializer {
    override func responseObject(for _: URLResponse?, data: Data?, error _: NSErrorPointer) -> Any? {
        data
    }
}

enum ResponseSerializationType {
    case passThrough
    case defaultType
}

class DPAGExtensionHelper: NSObject {
    private static var roundRobin = 0

    class func initHttpSessionManager(manager: AFHTTPSessionManager, qos: DispatchQoS, serializationType: ResponseSerializationType = .defaultType) {
        let serializer = self.serializer(forSerializationType: serializationType)
        var types = serializer.acceptableContentTypes ?? Set<String>()
        types.insert("text/plain")
        serializer.acceptableContentTypes = types
        manager.responseSerializer = serializer
        self.setCompletionQueue(forManager: manager, qos: qos)
        let securityPolicy = AFSecurityPolicy.default()
        securityPolicy.allowInvalidCertificates = true
        securityPolicy.validatesDomainName = false
        manager.securityPolicy = securityPolicy
    }

    class func setCompletionQueue(forManager manager: AFHTTPSessionManager, qos: DispatchQoS = .default) {
        switch qos {
            case .default:
                var queueName = "de.dpag.simsme.defaultQueue\(DPAGExtensionHelper.roundRobin)"
                DPAGExtensionHelper.roundRobin += 1
                if DPAGExtensionHelper.roundRobin > 4 {
                    DPAGExtensionHelper.roundRobin = 0
                }
                if let currentQueue = OperationQueue.current?.underlyingQueue, currentQueue.label == queueName {
                    queueName = "de.dpag.simsme.defaultQueue\(DPAGExtensionHelper.roundRobin)"
                    DPAGExtensionHelper.roundRobin += 1
                }
                let backgroundQueue = DispatchQueue(label: queueName, qos: qos, attributes: DispatchQueue.Attributes(), autoreleaseFrequency: .inherit, target: nil)
                manager.completionQueue = backgroundQueue
            case .userInitiated:
                let queue = DispatchQueue(label: "de.dpag.simsme.completionQueueUser", qos: qos, attributes: [], autoreleaseFrequency: .inherit, target: nil)
                manager.completionQueue = queue
            default:
                let queue = DispatchQueue(label: "de.dpag.simsme.completionQueue", qos: qos, attributes: [], autoreleaseFrequency: .inherit, target: nil)
                manager.completionQueue = queue
        }
    }

    private class func serializer(forSerializationType type: ResponseSerializationType) -> AFHTTPResponseSerializer & AFURLResponseSerialization {
        switch type {
            case .defaultType:
                return AFJSONResponseSerializer()
            case .passThrough:
                return PassThroughResponseSerializer()
        }
    }
}
