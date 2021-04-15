//
//  DPAGClassPerforming.swift
//  SIMSmeCore
//
//  Created by RBU on 08.03.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

public protocol DPAGClassPerforming: AnyObject {
    func performBlockOnMainThread(_ block: @escaping DPAGCompletion)
    func performBlockInBackground(_ block: @escaping DPAGCompletion)
}

extension DPAGClassPerforming {
    public func performBlockOnMainThread(_ block: @escaping DPAGCompletion) {
        if Thread.isMainThread {
            block()
        } else {
            OperationQueue.main.addOperation(block)
        }
    }

    public func performBlockInBackground(_ block: @escaping DPAGCompletion) {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async(execute: block)
    }
}
