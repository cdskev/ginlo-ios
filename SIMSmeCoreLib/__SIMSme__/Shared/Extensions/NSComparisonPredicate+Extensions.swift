//
//  NSComparisonPredicate+Extensions.swift
//  SIMSmeCore
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

public extension NSComparisonPredicate {
    convenience init(leftExpression: NSExpression, rightExpression: NSExpression) {
        self.init(leftExpression: leftExpression, rightExpression: rightExpression, modifier: .direct, type: .equalTo, options: [])
    }

    convenience init(leftExpression: NSExpression, rightNotExpression: NSExpression) {
        self.init(leftExpression: leftExpression, rightExpression: rightNotExpression, modifier: .direct, type: .notEqualTo, options: [])
    }
}
