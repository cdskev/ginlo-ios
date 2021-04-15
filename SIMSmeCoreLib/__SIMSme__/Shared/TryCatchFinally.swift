//
//  TryCatchFinally.swift
//  SIMSme
//
//  Created by RBU on 27/01/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

public func tryC(_ try: @escaping () -> Void) -> TryCatchFinally {
    TryCatchFinally(`try`)
}

public class TryCatchFinally {
    let tryFunc: () -> Void
    var catchFunc: (NSException) -> Void = { _ in
    }

    var finallyFunc: () -> Void = {}

    init(_ try: @escaping () -> Void) {
        tryFunc = `try`
    }

    @discardableResult
    public func `catch`(_ catch: @escaping (NSException) -> Void) -> TryCatchFinally {
        // objc bridging needs NSException!, not NSException as we'd like to expose to clients.
        self.catchFunc = { e in
            `catch`(e)
        }
        return self
    }

    public func finally(_ finally: @escaping () -> Void) {
        self.finallyFunc = finally
    }

    deinit {
        tryCatchFinally(self.tryFunc, self.catchFunc, self.finallyFunc)
    }
}
