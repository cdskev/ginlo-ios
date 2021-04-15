//
//  NSObject+Extensions.swift
//  SIMSmeCore
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

extension NSObject {
    @objc
    public func performBlockOnMainThread(_ block: @escaping DPAGCompletion) {
        if Thread.isMainThread {
            block()
        } else {
            OperationQueue.main.addOperation(block)
        }
    }

    public func performBlockOnMainThreadAndWait(_ block: @escaping DPAGCompletion) {
        if Thread.isMainThread {
            block()
        } else {
            let semaphore = DispatchSemaphore(value: 0)
            OperationQueue.main.addOperation {
                block()
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .distantFuture)
        }
    }

    @objc
    public func performBlockInBackground(_ block: @escaping DPAGCompletion) {
        DispatchQueue.global(qos: .default).async(execute: block)
    }

    public func performBlockInBackgroundLower(_ block: @escaping DPAGCompletion) {
        DispatchQueue.global(qos: .background).async(execute: block)
    }

    public func performBlockInBackgroundAndWait(_ block: @escaping DPAGCompletion) {
        let semaphore = DispatchSemaphore(value: 0)
        self.performBlockInBackground {
            block()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
    }

    func performAutoTimer(_ clazz: String, method: String, block: DPAGCompletion) {
        block()
    }
}
